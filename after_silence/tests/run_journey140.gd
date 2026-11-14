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
func run():
	create_timer(150).timeout.connect(func():push_error("Journey QA watchdog");quit(2))
	game=load("res://after_silence/scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	await shot("menu")
	game.event_saves.path="user://qa_journey140.json"
	game._new_event_game();game.set_physics_process(false);game.living.set_physics_process(false);game.events_controller.set_physics_process(false)
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
			var base_tint=game.world.modulate
			director.start_activity();var activity=director.activity
			activity.set_physics_process(false);activity.npc.set_physics_process(false);game.player.set_physics_process(false)
			check(game.event_window.active and game.world.get_parent()==game.event_window.viewport,"custom viewport "+event.id)
			game.event_window.toggle_pause();check(game.modal,"window pause")
			game.event_window.resume();check(not game.modal,"window resume")
			for hit in range(5): activity.invulnerable=0;activity.hit()
			activity.tick(.01)
			check(director.phase=="failure" and not game.event_window.active,"defeat exits viewport "+event.id)
			if activity.mode=="epochs": check(game.world.modulate==base_tint,"era tint restored after failure")
			game.body.visible_characters=-1
			game.buttons.retry.pressed.emit();activity=director.activity;activity.set_physics_process(false);activity.npc.set_physics_process(false)
			check(activity.hp==5,"retry "+event.id)
			if activity.mode=="epochs":
				await process_frame
				check(activity.original_tint==base_tint and game.world.modulate==Color("d1c7a2"),"retry preserves base tint and reapplies era")
			activity.invulnerable=10000
			for frame in range(2200):
				if not activity.active: break
				if ending==0 and frame==200: await shot(event.id)
				var t=activity.elapsed
				match activity.mode:
					"rhythm":
						if absf(fmod(t,1.0)-.5)<.025: activity.interact()
					"defense": game.player.position=activity.center+Vector2((int(t/2.2)%3-1)*90,0);activity.interact()
					"dodge": game.player.position=activity.npc.position;activity.interact()
					"stealth": game.player.position=activity.npc.position-activity.look_dir*70
					"escort": game.player.position=activity.route_point(activity.step);activity.npc.position=game.player.position+Vector2(-20,0)
					"switches","epochs","route":
						game.player.position=activity.route_point(activity.step)
						if activity.mode!="route" and int(t*10)%10==0: activity.interact()
					"evacuation":
						for i in range(activity.followers.size()):
							if activity.followers[i].get_meta("rescued",false): continue
							game.player.position=activity.followers[i].position;activity.interact();activity.followers[i].position=activity.route_point(1)
					"repair": game.player.position=activity.npc.position+Vector2(0,35);activity.repair_hold=activity.heat<1.0
				activity.tick(.05)
			check(director.phase=="decision","victory "+event.id)
			check(activity.elapsed>=30 and activity.elapsed<=110,"duration "+event.id)
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
	game._new_event_game();game.set_physics_process(false);game.events_controller.set_physics_process(false)
	var director=game.events_controller
	director.start_activity();director.activity.set_physics_process(false);director.activity.elapsed=17;director.activity.progress=2
	game.event_window.leave()
	check(director.phase=="suspended" and game.world.get_parent()==game,"safe window exit")
	await game._load_game()
	check(director.phase=="suspended" and director.activity.elapsed==17,"suspended save resume")
	director.resume_activity();check(game.event_window.active,"reopen preserved activity")
	game.event_window.close();director.activity.active=false
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
