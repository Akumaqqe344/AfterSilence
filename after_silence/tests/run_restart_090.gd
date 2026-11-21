extends SceneTree
## Two independent processes share only an isolated QA profile. State setup is a fixture.

var game
var failures: Array[String] = []
var checks = 0
var output = ""

func _initialize():
	run.call_deferred()

func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message)

func run():
	var action = ""
	var fixture = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): action=arg.trim_prefix("--mode=")
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--fixture="): fixture=arg.trim_prefix("--fixture=")
	if not action in ["write","read","legacy"] or output.is_empty() or not "--qa" in OS.get_cmdline_user_args():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.comfort.reduce_motion = true
	if action=="legacy":
		await legacy(fixture)
	elif action=="write":
		write_checkpoints()
	else:
		await restore_checkpoints()
	var stats = {"mode":action,"checks":checks,"failures":failures}
	var file = FileAccess.open(output.path_join("restart-"+action+".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(stats,"  "))
	file.close()
	print("RESTART ",action,": ",checks," checks, ",failures.size()," failures")
	game.audio.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func use_slot(id: String):
	game.event_saves.path = "user://qa_090_restart_"+id+".json"
	game.saves = game.event_saves

func write_checkpoints():
	use_slot("trial")
	game._new_event_game(false)
	game.events_controller.phase = "ready"
	game.events_controller.start_activity()
	check(game.event_window.active,"main minigame active before shutdown")
	game.event_window.puzzle_panel.action_buttons[0].pressed.emit()
	game._save(false)
	check(game.state.event_state.get("activity",{}).get("moves",[])==[0],"running minigame wrote first move")
	use_slot("device")
	game._new_event_game(true,true)
	game._build_world("tide_station",Vector2(320,335))
	game.state.case_trials["tide_winch"] = [1,1,0]
	game.state.case_orders["audio_order"] = [1,2]
	game.state.set_flag("case_choice_archive_joint")
	game._dialog("","QA","dialogue",[],false)
	game._save(false)
	check(game.modal and game.event_saves.exists(),"checkpoint written during dialogue")
	use_slot("final")
	game._new_event_game(true,true)
	for event in game.events_controller.events:
		if event.id!="shore": game.state.set_flag("event_done_"+event.id)
	for id in ["crossing","evening_roll","return_address"]: game.state.set_flag("case_done_"+id)
	game.state.set_flag("case_choice_roll_private")
	game._build_world("harbor",Vector2(784,673))
	game.events_controller.start()
	game._save(false)
	check(game.events_controller.index==11 and not game.state.flag("events_finished"),"before-final checkpoint saved")

func restore_checkpoints():
	use_slot("trial")
	await game._load_game()
	check(game.state.flag("event_campaign"),"main campaign restored")
	check(game.state.event_state.get("activity",{}).get("moves",[])==[0],"minigame move survives OS process restart")
	use_slot("device")
	await game._load_game()
	check(game.state.zone=="tide_station" and game.player.position.distance_to(Vector2(320,335))<3,"correct room after restart")
	check(game.state.case_trials.get("tide_winch",[])==[1,1,0],"partial winch restored")
	check(game.state.case_orders.get("audio_order",[])==[1,2],"partial chronology restored")
	check(game.state.flag("case_choice_archive_joint") and not game.world.expedition_route_open,"signed choice and closed platform restored")
	use_slot("final")
	await game._load_game()
	check(game.events_controller.index==11 and not game.state.flag("events_finished"),"final remains playable")
	check(game.investigations.active_chapter().is_empty(),"completed required investigations stay completed")
	check(game.state.flag("case_choice_roll_private") and game.state.flag("case_done_return_address"),"pre-final and optional results retained")

func legacy(fixture: String):
	var previous = preload("res://after_silence/core/save_manager.gd").new()
	var state = preload("res://after_silence/core/world_state.gd").new()
	previous.path = fixture
	check(not fixture.is_empty() and previous.load_state(state),"0.33.0 EXE output loads unmodified")
	if failures.is_empty():
		check(state.flag("event_campaign") and state.flag("events_finished"),"campaign and ending retained")
		check(state.flag("expedition_0330") and state.flag("case_done_evening_roll"),"expansion and roll-call retained")
