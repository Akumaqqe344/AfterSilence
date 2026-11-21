extends SceneTree
## Tests map reachability, unlocked shortcuts and save restoration with QA-only slots.
const Data=preload("res://after_silence/core/investigation_catalog.gd")
const Saves=preload("res://after_silence/core/save_manager.gd")
const State=preload("res://after_silence/core/world_state.gd")
const Progress=preload("res://after_silence/core/event_progress.gd")
var game
var checks=0
var failures=0
var output="res://work/story-fixtures"

func _initialize():
	call_deferred("_run")

func _check(ok: bool, name: String):
	checks+=1
	if not ok:
		failures+=1
		push_error(name)

func _run():
	if "--qa" not in OS.get_cmdline_user_args():
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game)
	game.event_saves.path="user://qa_story_fixtures_%s.json"%Time.get_ticks_usec()
	game._new_event_game(true)
	game.comfort.reduce_motion=true
	game.events_controller.set_physics_process(false)
	_check(game.investigations.active_chapter().id=="arrival","new game starts with first investigation")
	game.events_controller.phase="ready"
	game.events_controller.start_activity()
	_check(not game.event_window.active,"NPC does not bypass first case")
	game._close()
	var cases=Data.data.chapters+Data.data.sides
	var ids={}
	var maps={}
	for case in cases:
		_check(not ids.has(case.id),"unique case "+case.id)
		ids[case.id]=true
		for step in case.steps:
			_check(not ids.has(step.id),"unique clue "+step.id)
			ids[step.id]=true
			_check(step.zone in State.ZONES,"known zone "+step.zone)
			if not maps.has(step.zone): maps[step.zone]=[]
			maps[step.zone].append(step)
	for zone in maps:
		var start=Vector2(600,645)
		if Data.data.rooms.has(zone): start=Data.point(Data.data.rooms[zone].entry)
		elif zone.begins_with("home_") or zone=="shop": start=Vector2(320,395)
		elif zone=="library": start=Vector2(480,575)
		elif zone=="forest": start=Vector2(700,940)
		elif zone in ["orchard","harbor"]: start=Vector2(600,740)
		game._build_world(zone,start)
		for step in maps[zone]:
			var point: Vector2=game.world.recover(Data.point(step.at))
			_check(game.world.walkable(point),"walkable clue "+step.id)
			_check(not game.world.path_between(game.player.position,point).is_empty(),"reachable clue "+step.id)
		await process_frame
		if Data.data.rooms.has(zone): await _shot(zone)
	var isolated=Saves.new()
	isolated.path=game.event_saves.path
	game.state.set_flag("event_done_letter")
	game.state.set_flag("event_done_guest")
	game.state.set_flag("case_done_arrival")
	game.state.set_flag("case_read_copies_lamp")
	game.state.set_flag("case_read_reading_door")
	game.state.set_flag("case_read_copies_entry")
	game._build_world("records_annex",Vector2(309,341))
	game.events_controller.start()
	game.investigations.install()
	game._save(false)
	var loaded=State.new()
	_check(isolated.load_state(loaded) and loaded.zone=="records_annex","save stores annex as legitimate player zone")
	_check(loaded.flag("case_read_copies_entry"),"clue survives saved state")
	await game._load_game()
	_check(game.state.zone=="records_annex" and game.investigations.active_chapter().id=="copies","reload returns to same investigation and room")
	_check(game.investigations.next_step(game.investigations.active_chapter()).id=="copies_thread","reload points at next unexamined clue")
	game.state.set_flag("case_done_copies")
	game.investigations.install()
	await _move_case_prop("case_bindery_stair","town")
	game.state.set_flag("event_done_crowd")
	game.state.set_flag("case_choice_leave_bypass")
	game._build_world("pump_chamber",Vector2(320,377))
	await _move_case_prop("case_dry_bypass","harbor")
	game.state.set_flag("event_done_machine")
	game.state.set_flag("case_read_weights_receipt")
	game._build_world("home_lev",Vector2(320,347))
	game.investigations.open_trial("weights_panel")
	var model=game.event_window.displayed.trial
	_check(model.variant=="weights" and model.loads==[2,3,4,7,8],"new weights board has its own load plan")
	game.event_window.puzzle_panel.action_buttons[model.hint()].pressed.emit()
	game.event_window.toggle_pause()
	game.event_window.leave()
	_check(game.state.case_trials.get("weights_panel",[]).size()==1,"leaving optional board persists one move")
	var saved=State.new()
	_check(isolated.load_state(saved) and saved.case_trials.get("weights_panel",[]).size()==1,"optional board progress survives save read")
	game.investigations.open_trial("weights_panel")
	_check(game.event_window.displayed.trial.history.size()==1,"reopening board restores the move")
	game.event_window.close()
	game.state.set_flag("case_choice_quiet_call")
	game.events_controller.index=7
	game.events_controller.npc=game.actors.nadia
	game.events_controller.make_activity()
	_check(game.events_controller.activity.trial.variant=="quiet_plaza","quiet choice changes a main story board")
	var checkpoint={"version":3,"index":7,"phase":"running","activity":game.events_controller.activity.checkpoint()}
	_check(Progress.valid(checkpoint),"branch-specific board checkpoint is accepted")
	print("STORY EXPANSION QA: ",checks," checks, ",failures," failures")
	game.audio.shutdown()
	game.queue_free()
	await process_frame
	await create_timer(.6).timeout
	quit(0 if failures==0 else 1)

func _move_case_prop(id: String, destination: String):
	for object in game.world.interactables:
		if object.id!=id: continue
		game.player.position=object.position
		game.interact(id)
		while game.transitions.busy: await physics_frame
		_check(game.state.zone==destination,"shortcut "+id+" reaches "+destination)
		return
	_check(false,"missing shortcut "+id)

func _shot(name: String):
	if DisplayServer.get_name()=="headless": return
	await create_timer(.18).timeout
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"screenshot "+name)
