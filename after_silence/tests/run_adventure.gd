extends SceneTree
var game
var checks=0
var failures=0
func check(value: bool,label: String):
	checks+=1
	if not value: failures+=1;push_error(label)
func _initialize(): call_deferred("run")
func run():
	game=load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.rift_saves.path="user://qa_adventure080.json"
	game._new_rift_game()
	game.rift.active=false;game.rift.visible=false;game.rift.phase="travel"
	var system=game.adventure
	check(not system.unlocked("orchard"),"orchard initially gated")
	check(not system.unlocked("harbor"),"harbor initially gated")
	game.state.set_flag("rift_q03_done")
	check(system.unlocked("orchard"),"story unlock")
	game.state.set_flag("rift_q03_done",false)
	game._build_world("town",Vector2(600,600))
	for i in range(3):
		check(system.handle("collect_herbs_"+str(i)),"herb interaction")
	check(system.count(system.data.requests[0])==3,"collection complete")
	check(system.unlocked("orchard"),"collection unlocks settlement")
	var relation=game.state.relations.nadia
	system.handle("collect_herbs_0")
	check(game.state.relations.nadia==relation,"no duplicate reward")
	game._build_world("orchard",Vector2(600,700))
	check(game.world.path_between(Vector2(600,700),Vector2(280,340)).size()>0,"door reachable")
	system.handle("district_house_0")
	await create_timer(.7).timeout
	check(game.state.zone=="home_nadia","enter district home")
	system.handle("leave_home")
	await create_timer(.7).timeout
	check(game.state.zone=="orchard","return to correct settlement")
	check(game.player.position.distance_to(Vector2(280,355))<30,"return to correct door")
	for i in range(3): system.handle("collect_tools_"+str(i))
	check(system.unlocked("harbor"),"tools unlock harbor")
	game._build_world("harbor",Vector2(600,700))
	for i in range(3): system.handle("collect_letters_"+str(i))
	check(game.state.flag("district_friends"),"harbor request complete")
	system.handle("hotspot_lamp")
	await process_frame
	check(game.world.has_node("InteractiveLamp"),"lamp light enabled")
	system.handle("hotspot_lamp")
	await process_frame
	check(not game.world.has_node("InteractiveLamp"),"lamp light freed")
	game.state.clock=11
	check(game.npcs.task("nadia")[2]=="library","morning research schedule")
	game.state.clock=18
	check(game.npcs.task("nadia")[5]=="meeting","evening meeting schedule")
	game.state.clock=22
	check(game.npcs.task("nadia")[2]=="home_nadia","night schedule")
	var restored=load("res://after_silence/core/world_state.gd").new()
	check(restored.restore(game.state.to_data()),"state restore")
	check(restored.flag("district_harbor") and restored.flag("collect_letters_2"),"unlock and collection persisted")
	check(load("res://after_silence/core/quest_catalog.gd").data.quests[3].mode=="circuit","JSON controls mechanic")
	if "--qa-visual" in OS.get_cmdline_user_args():
		game._close()
		system.expanded=true
		await create_timer(.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/adventure080.png")
	game.audio.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.3).timeout
	print("ADVENTURE QA: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
