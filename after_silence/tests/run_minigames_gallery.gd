extends SceneTree
## Renders each existing board through the game with separate QA saves.
var game
var output="res://work/minigame-gallery"
var shots=0
var failures=0
var checks=0

func _initialize():
	call_deferred("_run")

func _run():
	if "--qa" not in OS.get_cmdline_user_args():
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gallery="): output=arg.trim_prefix("--gallery=")
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game)
	game.event_saves.path="user://qa_minigame_gallery_%d.json"%Time.get_ticks_usec()
	game.rift_saves.path="user://qa_minigame_gallery_rift.json"
	game.state.language="ru"
	game.comfort.reduce_motion=false
	for i in game.events_controller.events.size():
		game._new_event_game()
		game._close()
		var director=game.events_controller
		director.index=i
		var event=director.events[i]
		var place=game.journey.places[event.location]
		director.center=Vector2(place.point[0],place.point[1])
		game._build_world(place.zone,director.center+Vector2(0,60))
		director.npc=game.actors[event.npc]
		director.phase="ready"
		if not director.talk(event.npc) or not game.event_window.active:
			failures+=1
			continue
		await _capture("journey_%02d_%s"%[i+1,event.id])
		if i==0:
			var model=director.activity.trial
			for attempt in model.MOVE_LIMIT:
				if model.won(): break
				var action: int=model.hint()
				if action<0: break
				game.event_window.puzzle_panel.action_buttons[action].pressed.emit()
			_check(director.phase=="decision","letter reaches the original result")
			if DisplayServer.get_name()!="headless":
				DirAccess.make_dir_recursive_absolute(output.path_join("animation"))
				for frame in 10:
					await _capture("animation/seal_%02d"%frame,.065)
		game.event_window.close()
	game._new_rift_game()
	for i in game.rift.QUESTS.size():
		game.rift.index=i
		game.rift.show_intro()
		game.rift.start_play()
		game.rift.set_physics_process(false)
		await _capture("rift_%02d_%s"%[i+1,game.rift.play_mode()])
	game.rift.easy_mode=false
	for i in 3: game.rift.damage()
	_check(game.rift.phase=="fail","limited-health rift battle reaches retry")
	var checkpoint=load("res://after_silence/core/minigame_checkpoint.gd")
	var saved: Dictionary=checkpoint.capture(game.rift)
	_check(saved.get("phase","")=="fail" and checkpoint.apply(game.rift,saved),"rift retry survives checkpoint round-trip")
	await _escape()
	_check(game.rift.phase=="pause","Esc pauses the defeat screen")
	await _escape()
	_check(game.rift.phase=="fail","Esc restores the defeat screen")
	await _capture("rift_retry")
	game.rift.actions.get_child(0).pressed.emit()
	_check(game.rift.phase=="play" and game.rift.health==3,"rift retry restores health and starts again")
	game.rift.active=false
	game.rift.hide()
	game._build_world("town",Vector2(600,645))
	for id in ["relay","watcher"]:
		game._begin_boss(id)
		game.battle.set_physics_process(false)
		await _capture("boss_"+id)
		await _escape()
		_check(game.battle.frozen and game.battle.end_panel.visible,"boss pause "+id)
		await _escape()
		_check(not game.battle.frozen,"boss resume "+id)
		for hit in 3:
			game.battle.invulnerable=0
			game.battle._hit()
		_check(game.battle.defeated and game.battle.player_hp==0,"boss defeat "+id)
		await _capture("boss_"+id+"_retry")
		game.battle.continue_button.pressed.emit()
		_check(not game.battle.frozen and game.battle.player_hp==3,"boss retry "+id)
		await _escape()
		game.battle.leave_button.pressed.emit()
		_check(not game.battle.active and game.player.enabled,"boss returns to world "+id)
	game.state.set_flag("catalog",false)
	game._catalog()
	await _capture("archive_catalog")
	game._clock()
	await _capture("archive_clock")
	game.state.set_flag("forest_power",false)
	game.state.set_flag("boss_relay_defeated",true)
	game._relay()
	await _capture("archive_relay")
	print("MINIGAMES GALLERY: ",shots," frames, ",checks," checks, ",failures," failures")
	game.queue_free()
	await process_frame
	await create_timer(1.0).timeout
	quit(0 if failures==0 else 1)

func _capture(name: String, settle: float=.27):
	if DisplayServer.get_name()=="headless": return
	await create_timer(settle).timeout
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK: shots+=1
	else: failures+=1

func _check(ok: bool, label: String):
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func _escape():
	for pressed in [true,false]:
		var event:=InputEventKey.new()
		event.physical_keycode=KEY_ESCAPE
		event.keycode=KEY_ESCAPE
		event.pressed=pressed
		root.push_input(event,true)
		await process_frame
