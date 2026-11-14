extends SceneTree
var checks=0
var failures=0
var game
func check(value: bool, message: String):
	checks+=1
	if not value: failures+=1;push_error(message)
func _initialize(): call_deferred("run")
func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/merge110-"+name+".png")
func run():
	game=load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.rift_saves.path="user://qa_merge110.json"
	game._new_rift_game()
	game.set_physics_process(false)
	game.living.set_physics_process(false)
	game.rift.set_physics_process(false)
	game.battle.set_physics_process(false)
	var state=game.state
	var schedule=game.npcs.routine
	for id in game.npcs.PROFILE:
		check(schedule.current(id,0)[5]=="sleep","midnight "+id)
		check(schedule.current(id,23.99)[5]=="sleep","overnight "+id)
		check(schedule.current(id,7)[5]!="sleep","morning "+id)
		check(absf(schedule.next(id,23).hours-8)<.01,"next day "+id)
	state.give("ribbon");state.give("bandage")
	check(game.inventory.craft_badge(),"craft badge")
	check(state.item("ribbon")==0 and state.item("bandage")==0 and state.item("keepsake")==1,"recipe consumes exact ingredients")
	check(not game.inventory.craft_badge(),"no free crafting")
	check(game.inventory.transfer("keepsake",true),"deposit")
	check(state.item("keepsake")==0 and state.storage.keepsake==1,"deposit counts")
	check(game.inventory.transfer("keepsake",false),"withdraw")
	check(not game.inventory.transfer("unknown",true),"unknown item rejected")
	for index in [0,1,2,3,4,5,6,7,8,9,10,11]:
		game.rift.index=index
		game.rift.active=true
		game.rift.start_play()
		game.rift.elapsed=3
		var cp=preload("res://after_silence/core/minigame_checkpoint.gd").capture(game.rift)
		check(not cp.is_empty(),"capture "+str(index))
		cp=JSON.parse_string(JSON.stringify(cp))
		game.rift.elapsed=0
		check(preload("res://after_silence/core/minigame_checkpoint.gd").apply(game.rift,cp),"restore "+str(index))
		check(game.rift.elapsed==3,"elapsed restored "+str(index))
	game.rift.index=0
	game.rift.start_play()
	game.rift.elapsed=4
	game._save(false)
	var restored=game.State.new()
	check(game.saves.load_state(restored),"save/load")
	check(restored.minigame.elapsed==4,"checkpoint on disk")
	await game._load_game()
	check(game.rift.active and game.rift.phase=="play" and game.rift.elapsed==4,"actual load resumes minigame")
	var old=state.to_data()
	old.erase("schema");old.erase("storage");old.erase("minigame")
	check(restored.restore(old) and restored.storage.is_empty() and restored.minigame.is_empty(),"v2 migration")
	var invalid=state.to_data();invalid.minigame={"phase":"broken"}
	check(not restored.restore(invalid),"invalid checkpoint rejected")
	game._save(false)
	var bad=FileAccess.open(game.saves.path,FileAccess.WRITE)
	bad.store_string("broken");bad.close()
	check(game.saves.load_state(restored),"backup recovery")
	game._save(false)
	game.rift.active=false;game.rift.hide();game._close()
	state.set_flag("rumor_nadia");state.set_flag("nadia_meeting")
	game.objectives.refresh()
	check(state.flag("objective_tomorrow"),"event quest")
	for i in range(3): state.set_flag("collect_herbs_"+str(i))
	game.objectives.refresh()
	check(state.flag("objective_garden") and state.flag("district_orchard"),"quest unlock")
	state.clock=23
	check(game.objectives.meets({"hours":[20,7]}),"overnight condition")
	state.clock=12
	check(not game.objectives.meets({"hours":[20,7]}),"day excludes night")
	game._build_world("home_lev",Vector2(320,395))
	check(game.world.interactables.any(func(s):return s.id=="home_storage"),"storage hotspot")
	game.expedition.storage()
	await shot("storage")
	game._close();game.expedition.inventory()
	await shot("inventory")
	game._close();game.expedition.slots()
	check(game.buttons.has("save1") and game.buttons.has("save2") and game.buttons.has("save3"),"three slots")
	game.buttons.save2.pressed.emit()
	check(game.saves.path.ends_with("_2.json") and FileAccess.file_exists(game.saves.path),"write second slot")
	game.buttons.save3.pressed.emit()
	check(game.saves.path.ends_with("_3.json") and FileAccess.file_exists(game.saves.path),"write third slot")
	await shot("slots")
	game._close()
	game.talkkit_pilot.play()
	await process_frame
	check(game.talkkit_pilot.talk.state!=NPCTalkKit.State.IDLE,"TalkKit is playing")
	check(game.modal,"TalkKit locks world")
	game.talkkit_pilot.talk.advance()
	await shot("talkkit")
	game.talkkit_pilot.talk.advance()
	game.talkkit_pilot.talk.advance()
	await process_frame
	check(game.buttons.has("yes"),"TalkKit blocking choice")
	game._close()
	for id in ["relay","watcher"]:
		game.battle.start(id,false)
		check(game.battle.ai.get_child_count()==3,"Beehave phase branches")
		for i in range(20): game.battle._physics_process(.05)
		check(game.battle.phase=="attack","Beehave windup transition "+id)
		game.battle.phase="exposed"
		game.battle.player_pos=Vector2(320,148)
		check(game.battle.counter(),"counter "+id)
		check(game.battle.combat_stage()==1,"phase two "+id)
		game.battle.active=false;game.battle.hide()
	game._close()
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.25).timeout
	print("MERGE 0.11 QA: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
