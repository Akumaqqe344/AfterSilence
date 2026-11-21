extends SceneTree
const ZONES={"town":Vector2(598,627),"forest":Vector2(744,563),"orchard":Vector2(610,628),"harbor":Vector2(1060,750),"library":Vector2(482,426),"home_nadia":Vector2(320,350),"home_lev":Vector2(320,350),"shop":Vector2(320,330)}
func _initialize():
	call_deferred("_run")
func _run():
	if "--qa" not in OS.get_cmdline_user_args():
		push_error("Start the benchmark with -- --qa.")
		quit(1)
		return
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var start=Time.get_ticks_usec()
	var game=load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var result={"ready_ms":(Time.get_ticks_usec()-start)/1000.0,"zones":{}}
	game.event_saves.path="user://qa_polish_performance.json"
	game._new_event_game()
	game._close()
	game.events_controller.set_physics_process(false)
	for zone in ZONES:
		start=Time.get_ticks_usec()
		game._build_world(zone,ZONES[zone])
		await process_frame
		var load_ms=(Time.get_ticks_usec()-start)/1000.0
		for frame in range(12): await process_frame
		var deltas:Array[float]=[]
		var last=Time.get_ticks_usec()
		for frame in range(80):
			await process_frame
			var now=Time.get_ticks_usec()
			deltas.append((now-last)/1000.0)
			last=now
		deltas.sort()
		result.zones[zone]={"load_ms":load_ms,"p50_ms":deltas[39],"p95_ms":deltas[75],"fps":80000.0/deltas.reduce(func(a,b):return a+b,0.0),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"static_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0}
	print("POLISH_PROFILE "+JSON.stringify(result))
	game.audio.shutdown()
	game.queue_free();await process_frame;quit()
