extends SceneTree

var failures=0
var checks=0

func _initialize(): call_deferred("run")

func problem(id: String, zone: String, target: Vector2, reason: String):
	failures+=1
	print("NPC ROUTE ERROR: npc=%s zone=%s target=%s reason=%s" % [id,zone,target,reason])

func run():
	var game=load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.event_saves.path="user://qa_npc_routes.json"
	game._new_event_game()
	game.set_physics_process(false)
	game.events_controller.set_physics_process(false)
	var schedule=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/npc_routines.json"))
	for id in schedule.residents:
		for item in schedule.residents[id]:
			var zone: String=item[2]
			var target=Vector2(item[3],item[4])
			var entry=Vector2(320,395) if zone.begins_with("home_") else Vector2(480,575) if zone=="library" else Vector2(600,645)
			game._build_world(zone,entry)
			checks+=1
			var route=game.world.path_between(entry,target)
			if route.is_empty():
				problem(id,zone,target,"no path")
				continue
			if game.world.recover(target).distance_to(target)>32:
				problem(id,zone,target,"destination obstructed")
				continue
			for point in route:
				if not game.world.walkable(point):
					problem(id,zone,target,"path crosses obstacle")
					break
	game.audio.shutdown()
	game.queue_free()
	await process_frame
	print("NPC ROUTE QA: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
