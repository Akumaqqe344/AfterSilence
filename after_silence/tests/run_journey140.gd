extends SceneTree
var game
var checks=0
var failures=0
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize(): call_deferred("run")
func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	game.events_controller._physics_process(0)
	if game.modal and is_instance_valid(game.body): game.body.visible_characters=-1
	if is_instance_valid(game.events_controller.npc): game.events_controller.npc._physics_process(0)
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/journey140-"+name+".png")
func fixture_at(index: int):
	var director=game.events_controller
	if game.event_window.active: game.event_window.close()
	director.index=index
	var place=game.journey.places[director.events[index].location]
	game._build_world(place.zone,Vector2(place.point[0],place.point[1])+Vector2(0,65))
	director.prepare(false)
	game._close()
	for frame in range(3000):
		if director.phase!="travel": break
		game.npcs.update(game,.05,true)
		director._physics_process(0)
	game._close()
func fulfill_action():
	var director=game.events_controller
	director.begin_preparation()
	game.player.position=director.preparation_point()
	director.complete_preparation()
func run():
	Engine.time_scale=8;Engine.physics_ticks_per_second=480;Engine.max_physics_steps_per_frame=64;Engine.max_fps=240
	create_timer(1200).timeout.connect(func():push_error("Journey QA watchdog");quit(2))
	game=load("res://after_silence/scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	await shot("menu")
	game.event_saves.path="user://qa_journey140.json"
	game._new_event_game();game.set_physics_process(false);game.living.set_physics_process(false);game.events_controller.set_physics_process(false)
	fixture_at(0)
	check(game.journey.unlocked("square") and not game.journey.unlocked("rift"),"location gates")
	game.interact("home_lev");check(game.state.zone=="town" and not game.transitions.busy,"main workshop gate")
	game.interact("hamlet_house_1");check(game.state.zone=="town" and not game.transitions.busy,"village workshop gate")
	game.interact("district_house_1");check(game.state.zone=="town" and not game.transitions.busy,"district workshop gate")
	game.events_controller.npc.queue_free();await process_frame
	game.events_controller._physics_process(0)
	check(is_instance_valid(game.events_controller.npc),"missing NPC safely restored")
	game._close()
	var original=game.player.position
	game.journey.open();check(game.modal and game.buttons.has("rift"),"travel keyboard and mouse buttons")
	await shot("travel")
	game.buttons.rift.pressed.emit();check(game.body.text.contains("начала") or game.body.text.contains("First"),"closed reason")
	check(game.player.position==original,"travel is not a level picker")
	var esc=InputEventKey.new();esc.physical_keycode=KEY_ESCAPE;esc.pressed=true;game._unhandled_key_input(esc)
	check(not game.modal,"Esc releases travel window")
	var actor=game.player
	actor.enabled=true;actor.scripted=true;actor.target=game.world.recover(Vector2(600,940))
	var elapsed=0.0
	# Follow the actual navigation path with the existing CharacterBody2D.
	var path=game.world.path_between(actor.position,actor.target)
	for point in path:
		actor.target=point
		var timeout=0.0
		while actor.position.distance_to(point)>7 and timeout<1:
			await physics_frame;timeout+=1.0/60;elapsed+=1.0/60
	check(actor.position.distance_to(Vector2(600,940))<35,"physical walk from square toward bridge")
	actor.scripted=false
	for ending in [0,1]:
		game._new_event_game();game.set_physics_process(false);game.events_controller.set_physics_process(false)
		var director=game.events_controller
		for index in range(director.events.size()):
			fixture_at(index)
			var event=director.events[index]
			check(game.journey.here(event.location),"arrive "+event.id)
			check(game.journey.unlocked(event.location),"unlock "+event.id)
			game.player.position=director.npc.position+Vector2(0,60)
			director._physics_process(3.2);check(director.phase=="ready","NPC ready "+event.id)
			director.talk(event.npc);check(game.buttons.has("help"),"NPC conversation "+event.id)
			if ending==0 and index==0: await shot("conversation")
			fulfill_action();var activity=director.activity
			check(game.event_window.active and is_instance_valid(game.event_window.puzzle_panel),"board opens "+event.id)
			game.event_window.toggle_pause();check(game.modal,"window pause")
			game.event_window.resume();check(not game.modal,"window resume")
			if activity.puzzle!=null:
				var panel=game.event_window.puzzle_panel
				for attempt in range(80):
					if director.phase!="running": break
					var move: Array=activity.puzzle.hint()
					if move.is_empty(): break
					for tile in move: panel.tiles[tile].pressed.emit()
				check(activity.puzzle.won() and director.phase=="decision","puzzle victory "+event.id)
			elif activity.reality!=null:
				var panel=game.event_window.puzzle_panel
				var maze=activity.reality
				while director.phase=="running":
					var route: Array=maze.route(maze.destination())
					if route.is_empty(): break
					for cell in route: panel._step(cell,false)
				check(maze.won() and director.phase=="decision","reality maze victory "+event.id)
			if ending==0 and index==11: await shot("final-choice")
			var option=event.choices[ending if index==11 else 0]
			var relation=game.state.relations[option[3]]
			await director.choose(option)
			check(game.state.flag("event_done_"+event.id) and game.state.flag("place_changed_"+event.location),"world outcome "+event.id)
			check(game.state.relations[option[3]]>relation,"relationship outcome "+event.id)
			if index<11:
				check(director.phase in ["travel","observe"],"next stage available")
				game._close()
		check(game.state.flag("events_final_"+("together" if ending==0 else "home")),"distinct final choice")
		if ending==0: await shot("final")
		game._close()
	await verify_checkpoint()
func verify_checkpoint():
	game._new_event_game();game.set_physics_process(false);game.events_controller.set_physics_process(false)
	fixture_at(0)
	var director=game.events_controller
	fulfill_action()
	var model=director.activity.reality
	for tile in model.route(model.destination()): model.move(tile)
	var checkpoint=model.capture()
	game.event_window.leave()
	check(director.phase=="suspended" and game.world.get_parent()==game,"safe window exit")
	await game._load_game()
	check(director.phase=="suspended" and director.activity.reality.capture()==checkpoint,"suspended save resume")
	director.resume_activity();check(game.event_window.active,"reopen preserved activity")
	game.event_window.leave()
	var retained=director.activity
	var resident=director.npc
	await game._travel("home_nadia",Vector2(320,395))
	check(is_instance_valid(retained) and director.activity==retained and director.npc==resident,"suspended activity survives leaving zone")
	await game._load_game()
	check(director.phase=="travel" and not director.pending.is_empty(),"checkpoint retained when loading outside event zone")
	await game._travel("town",Vector2(600,645))
	director._physics_process(0)
	retained=director.activity
	check(is_instance_valid(retained) and director.phase=="suspended","suspended board returns in the event world")
	director.resume_activity()
	check(game.event_window.active and retained.reality.capture()==checkpoint,"suspended activity resumes after house visit")
	game.event_window.leave()
	var old=game.state.to_data();old.event_state={"index":2,"phase":"observe","activity":{}}
	old.flags["event_done_letter"]=true;old.flags["event_done_song"]=true
	check(game.state.restore(old),"v0.13 save accepted")
	director.start(true);check(game.state.flag("event_done_guest"),"v0.13 progress migration")
	check(not game.can_interact("hotspot_lamp") and not game.can_interact("rift_next"),"no mandatory lights")
	game._close()
	game.state.set_flag("event_done_epochs")
	await game._travel("home_lev",Vector2(320,395))
	check(game.state.zone=="home_lev" and game.world.walkable(game.player.position),"unlocked workshop safe entry")
	game.interact("leave_home")
	await create_timer(.8).timeout
	check(game.state.zone=="town" and game.world.walkable(game.player.position),"workshop exit returns to world")
	for id in game.journey.places:
		var place=game.journey.places[id]
		game._build_world(place.zone,Vector2(place.point[0],place.point[1])+Vector2(0,65))
		check(not game.world.path_between(game.player.position,Vector2(place.point[0],place.point[1])).is_empty(),"reachable event location "+id)
	game.audio.shutdown();game.event_window.close();game.queue_free()
	await process_frame;await process_frame;await create_timer(.3).timeout
	print("JOURNEY 0.14 QA: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
