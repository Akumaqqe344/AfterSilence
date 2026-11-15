extends Node

const Rift=preload("res://after_silence/world/rift_campaign.gd")
const State=preload("res://after_silence/core/world_state.gd")
const Saves=preload("res://after_silence/core/save_manager.gd")
var game
var checks=0
var errors: Array[String]=[]

func _ready() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks+=1
	if not value:
		errors.append(label)
		push_error("RIFT QA: "+label)

func screenshot(name: String) -> void:
	if not "--qa-visual" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	await get_tree().create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("res://work/"+name+".png")

func run() -> void:
	if not is_instance_valid(game):
		game=load("res://after_silence/scenes/main.tscn").instantiate()
		get_tree().root.add_child(game)
	await get_tree().process_frame
	game.rift_saves.path="user://qa_rift_campaign.json"
	game.archive_saves.path="user://qa_archive_preserve.json"
	var old_story=State.new()
	old_story.set_flag("archive_sentinel")
	check(game.archive_saves.save(old_story),"archive slot prepared")
	check(game.buttons.has("events_new"),"NPC campaign in main menu")
	check(game.buttons.has("archive"),"old campaign in archive menu")
	for event_index in range(Rift.QUESTS.size()):
		for option in Rift.QUESTS[event_index].choices:
			check(Rift.OUTCOMES.has("%02d_%s"%[event_index+1,option[0]]),"event %02d outcome %s"%[event_index+1,option[0]])
	await screenshot("rift_menu")
	game._new_rift_game()
	check(not game.audio.ambient.playing,"no looping ambient drone")
	await get_tree().process_frame
	check(get_viewport().gui_get_focus_owner()==game.rift.actions.get_child(0),"intro button has keyboard focus")
	await screenshot("rift_intro")
	var untouched_archive=State.new()
	check(game.archive_saves.load_state(untouched_archive) and untouched_archive.flag("archive_sentinel"),"new campaign preserves archive save")
	check(game.rift.active and game.rift.index==0,"new campaign starts")
	check(game.quests.stage()==1,"first quest in journal")
	var choices=["warn","follow","open","limit","guard","restore","truth","defend","present","truce","trust","child"]
	for i in range(Rift.QUESTS.size()):
		var r=game.rift
		if i>0:
			check(r.phase=="travel" and not r.active,"walk between events")
			check(game.world.path_between(game.player.position,Rift.STOPS[i]).size()>0,"event reachable")
			if i==7:
				game._build_world("library",Vector2(480,580))
				game._build_world("town",Vector2(600,600))
				check(game.world.interactables.any(func(spot): return spot.id=="rift_next"),"objective survives leaving town")
				game._toggle_zoom()
				await screenshot("adventure_map")
				check(game.camera.zoom.x<1.0,"zoom out works")
				game._toggle_zoom()
			game.interact("rift_next")
		check(r.index==i and r.phase=="intro","event %02d intro"%(i+1))
		r.start_play()
		if i==3: await screenshot("adventure_circuit")
		if i==5: await screenshot("adventure_memory")
		if i==7: await screenshot("adventure_herbs")
		if i==0: await screenshot("rift_route")
		if i==1: await screenshot("rift_rhythm")
		if i==2: await screenshot("rift_switch")
		if i==4: await screenshot("rift_defense")
		if i==11: await screenshot("rift_finale")
		check(r.phase=="play","event %02d playable"%(i+1))
		match r.play_mode():
			"memory":
				for pair_index in range(4):
					r.board_input(pair_index);r.board_input(pair_index+4)
			"circuit":
				for cell in range(4):
					while r.board[cell]%2!=0: r.board_input(cell)
			"herbs":
				r.board_input(1)
				check(r.board[1]==0,"unsafe herb stays in garden")
				for cell in [0,2,4]: r.board_input(cell)
			"route":
				var start=r.player_pos
				Input.action_press("as_right")
				r.update_route(.1)
				Input.action_release("as_right")
				check(r.player_pos.x>start.x,"route %02d moves"%(i+1))
				r.player_pos=Vector2(190,210+sin(r.elapsed*2.1)*72)
				r.invulnerable=0
				r.update_route(0.0)
				check(r.health==2,"route %02d hazard"%(i+1))
				if i==0:
					r.player_pos=Vector2(575,215)
					r.update_route(0.0)
					check(r.phase=="play","escort must reach exit")
					r.escort_pos=Vector2(530,215)
				if i==6:
					r.invulnerable=0
					r.player_pos=Vector2(225,240)
					r.update_route(0.0)
					check(r.player_pos.x<220,"garden gate blocks wrong route")
				if i==11:
					for person in range(3):
						r.player_pos=Vector2(190+person*130,165 if person%2==0 else 265)
						r.update_route(0.0)
					check(r.rescued==7,"evacuation reaches all residents")
				r.player_pos=Vector2(575,215)
				r.update_route(0.0)
			"rhythm":
				for beat in range(8):
					r.beat_age=r.rhythm_duration()*.65
					r.rhythm_input(r.rhythm_key())
			"switch":
				for round_index in range(r.switch_targets().size()):
					for bit in range(4):
						if r.switch_target()&(1<<bit):
							var event=InputEventKey.new()
							event.physical_keycode=KEY_1+bit
							event.pressed=true
							r._input(event)
					var confirm=InputEventKey.new()
					confirm.physical_keycode=KEY_E
					confirm.pressed=true
					r._input(confirm)
			"defense":
				for wave in range(r.defense_waves()):
					r.lane=r.incoming_lane()
					r.guard_age=.5
					r.update_defense(1.45)
		check(r.phase=="decision","event %02d completed by mechanics"%(i+1))
		if i in [9,10]:
			r.health=2
			check(r.available(choices[i]),"easy mode preserves peaceful choice after mistakes")
			r.health=3
		check(r.available(choices[i]),"event %02d expected choice available"%(i+1))
		for option in Rift.QUESTS[i].choices:
			if option[0]==choices[i]:
				r.choose(option)
				break
		check(game.state.flag("rift_q%02d_done"%(i+1)),"event %02d persisted"%(i+1))
		if i==5:
			r.active=false
			r.visible=false
			game._main_menu()
			game._load_game()
			await get_tree().create_timer(.7).timeout
			check(game.rift.phase=="travel" and game.rift.index==6,"reload resumes travel to event seven")
			check(game.quests.stage()==7,"journal resumes event seven")
	await get_tree().process_frame
	check(game.state.flag("rift_finished"),"story finished")
	check(game.state.flag("rift_final_child"),"earned child ending")
	var completed=game.state.flags.duplicate()
	game.rift.choose(Rift.QUESTS[11].choices[0])
	check(game.state.flags==completed,"completed finale rejects repeated choice")
	check(game.state.echo,"child ending changes world")
	check(game.state.achievements.has("rift_all"),"completion achievement")
	check(game.actors.has("sonya"),"Sonya is in the final town")
	var persisted=State.new()
	check(game.saves.load_state(persisted),"finished campaign save loads")
	check(persisted.flag("rift_final_child"),"ending survives save")
	for suffix in ["",".bak",".tmp"]:
		var qa_file=game.archive_saves.path+suffix
		if FileAccess.file_exists(qa_file): DirAccess.remove_absolute(ProjectSettings.globalize_path(qa_file))
	game.audio.shutdown()
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(.25).timeout
	print("RIFT QA: %d checks, %d failures"%[checks,errors.size()])
	get_tree().quit(0 if errors.is_empty() else 1)
