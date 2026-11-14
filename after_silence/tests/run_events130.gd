extends SceneTree
var game
var checks=0
var failures=0
var renders=0
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize(): call_deferred("run")
func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	if is_instance_valid(game.events_controller): game.events_controller._physics_process(0)
	if is_instance_valid(game.events_controller.npc):
		game.events_controller.npc.velocity=Vector2.ZERO
		game.events_controller.npc._physics_process(0)
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/events130-"+name+".png")
func run():
	create_timer(45).timeout.connect(func():push_error("NPC event QA watchdog");quit(2))
	game=load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game);await process_frame
	await shot("menu")
	game.event_saves.path="user://qa_events130.json"
	game._new_event_game()
	game.set_physics_process(false);game.living.set_physics_process(false)
	var director=game.events_controller
	director.set_physics_process(false)
	check(game.state.flag("event_campaign"),"new campaign flag")
	check(game.saves!=game.rift_saves and game.saves!=game.archive_saves,"separate campaign slot")
	check(game.world.interactables.all(func(s):return s.id not in ["rift_next","hotspot_lamp"] and not str(s.id).begins_with("collect_")),"no mandatory lights or gathering")
	check(not game.can_interact("rift_next") and not game.can_interact("hotspot_lamp"),"legacy lights disabled")
	check(not game.adventure.expanded,"no active map")
	var map_key=InputEventKey.new();map_key.physical_keycode=KEY_M;map_key.pressed=true
	game.adventure._unhandled_input(map_key)
	check(not game.adventure.expanded,"M does not open legacy map")
	check(director.phase=="observe","starts by observing")
	game.player.position=director.npc.position+Vector2(0,60)
	director._physics_process(3.2)
	check(director.phase=="ready","proximity observation readies NPC")
	director.talk("lev")
	check(game.buttons.has("help"),"short activity context")
	await shot("npc")
	game._close()
	for index in range(director.events.size()):
		director.index=index;director.prepare(false);director.start_activity()
		var activity=director.activity
		activity.set_physics_process(false)
		activity.npc.set_physics_process(false)
		game.player.set_physics_process(false)
		var mode=activity.mode
		check(activity.goal()>0,"goal "+mode)
		for injury in range(5): activity.invulnerable=0;activity.hit()
		activity.tick(.01)
		check(director.phase=="failure" and game.buttons.has("retry"),"loss and retry "+mode)
		game.buttons.retry.pressed.emit()
		activity=director.activity;activity.set_physics_process(false);activity.npc.set_physics_process(false)
		check(activity.hp==5 and activity.elapsed==0,"retry resets "+mode)
		activity.invulnerable=10000
		for frame in range(2200):
			if not activity.active: break
			if frame==300 or (mode=="evacuation" and frame==0): await shot(mode)
			var t=activity.elapsed
			match mode:
				"rhythm":
					if absf(fmod(t,1.0)-.5)<.025: activity.interact()
				"defense":
					game.player.position=activity.center+Vector2((int(t/2.2)%3-1)*90,0);activity.interact()
				"dodge":
					game.player.position=activity.npc.position;activity.interact()
				"stealth":
					var direction=(activity.npc.target-activity.npc.position).normalized()
					game.player.position=activity.npc.position-direction*70
				"escort":
					game.player.position=activity.route_point(activity.step);activity.npc.position=game.player.position+Vector2(-20,0)
				"switches","route":
					game.player.position=activity.route_point(activity.step)
					if mode=="switches" and int(t*10)%10==0: activity.interact()
				"evacuation":
					for i in range(activity.followers.size()):
						if activity.followers[i].get_meta("rescued",false): continue
						game.player.position=activity.followers[i].position;activity.interact();activity.followers[i].position=activity.route_point(1)
				"repair":
					game.player.position=activity.npc.position+Vector2(0,35)
					activity.repair_hold=activity.heat<1.0
			activity.tick(.05)
		check(director.phase=="decision","victory through gameplay "+mode)
		check(activity.elapsed>=30 and activity.elapsed<=110,"duration bounds "+mode)
		var snapshot=JSON.parse_string(JSON.stringify(activity.checkpoint()))
		check(preload("res://after_silence/core/event_progress.gd").valid({"index":index,"phase":"running","activity":snapshot}),"checkpoint schema "+mode)
		var saved_progress=activity.progress
		activity.progress=0;activity.restore(snapshot)
		check(is_equal_approx(activity.progress,saved_progress),"checkpoint round trip "+mode)
		activity.active=false;director.phase="decision"
		var relation=game.state.relations[director.events[index].choices[0][3]]
		await director.choose(director.events[index].choices[0])
		check(game.state.flag("event_done_"+director.events[index].id),"quest outcome "+mode)
		check(game.state.relations[director.events[index].choices[0][3]]>relation,"relationship consequence "+mode)
		if index<director.events.size()-1: game._close()
	check(game.state.flag("events_finished"),"finite story ends")
	await shot("final")
	director.index=6;director.prepare(false);director.start_activity()
	director.activity.set_physics_process(false)
	var evac=director.activity.checkpoint()
	evac.recruited=[0];evac.followers[1].rescued=true;evac.progress=1
	director.activity.restore(JSON.parse_string(JSON.stringify(evac)))
	check(0 in director.activity.recruited and not director.activity.followers[1].visible,"evacuee checkpoint restores recruited IDs and rescued visibility")
	# A real save/load preserves an in-progress activity and does not touch archives.
	game._new_event_game();director=game.events_controller;director.set_physics_process(false)
	director.start_activity();director.activity.set_physics_process(false)
	director.activity.elapsed=12;director.activity.progress=2
	game._pause();director._physics_process(.05);director.activity._physics_process(.5)
	check(director.activity.elapsed==12 and not director.npc.scripted,"pause freezes activity and NPC")
	game._close()
	game._save(false)
	await game._load_game()
	check(director.phase=="running" and is_equal_approx(director.activity.elapsed,12),"resume activity checkpoint")
	check(director.activity.progress==2,"resume progress")
	var before=game.state.to_data();var bad=before.duplicate(true);bad.event_state={"index":999,"phase":"running"}
	check(not game.state.restore(bad),"invalid event save rejected")
	director.activity.active=false
	game.audio.shutdown();game.queue_free()
	await process_frame;await process_frame;await create_timer(.3).timeout
	print("NPC EVENTS QA: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
