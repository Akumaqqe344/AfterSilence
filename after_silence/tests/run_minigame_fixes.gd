extends SceneTree
var game
var checks=0
var errors=[]
var output="res://work/0190-fixes"
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok: errors.append(label);print("MINIGAME FIX QA ERROR: ",label)
func tap(code: int,pressed: bool):
	var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
	game.get_viewport().push_input(event,true)
func motion(direction: Vector2):
	for item in [["as_left",maxf(0,-direction.x)],["as_right",maxf(0,direction.x)],["as_up",maxf(0,-direction.y)],["as_down",maxf(0,direction.y)]]:
		if item[1]>0: Input.action_press(item[0],item[1])
		else: Input.action_release(item[0])
func fixture(index: int):
	if is_instance_valid(game.events_controller.activity): game.event_window.close()
	game._new_event_game();game._close()
	game.set_physics_process(false);game.events_controller.set_physics_process(false);game.living.set_physics_process(false)
	var d=game.events_controller;d.index=index
	for i in range(index): game.state.set_flag("event_done_"+d.events[i].id)
	var event=d.events[index];var place=game.journey.places[event.location]
	d.center=Vector2(place.point[0],place.point[1]);game._build_world(place.zone,d.center+Vector2(0,60))
	d.npc=game.actors[event.npc];d.npc.position=d.center;d.npc.target=d.center
	game.state.residents[event.npc].zone=place.zone
	game.npcs.attach(game,event.npc)
	game.npcs.capture(game)
	game.state.set_flag("event_action_"+event.id);d.phase="ready";d.start_activity()
	await process_frame
func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run():
	DirAccess.make_dir_recursive_absolute(output)
	Engine.time_scale=8;Engine.physics_ticks_per_second=480;Engine.max_physics_steps_per_frame=64;Engine.max_fps=240
	create_timer(1200).timeout.connect(func():print("MINIGAME FIX QA ERROR: watchdog");quit(2))
	game=load("res://after_silence/scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.event_saves.path="user://qa_0190_fixes.json"
	check(game._object_name("child").contains("Реб"),"child has translated name")
	var child=game.actors.child
	check(child.body_height==28 and child.scale==Vector2.ONE,"child is genuinely small without scaling collision body")
	check(child.sprite.scale.y*child.sheet.get_image().get_region(Rect2i(0,0,64,96)).get_used_rect().size.y<30,"child drawn height below 30")
	var seen={}
	for id in game.actors:
		var data=game.actors[id].sheet.get_image().get_data().hex_encode().sha256_text()
		check(not seen.has(data),"unique sprite identity "+id);seen[data]=true
	var sector=preload("res://after_silence/core/vision_sector.gd")
	var polygon=sector.polygon(Vector2.ZERO,Vector2.RIGHT,func(_p):return true)
	check(sector.contains_body(polygon,Vector2(100,0),50),"center of cone seen")
	check(sector.contains_body(polygon,Vector2.from_angle(.92)*110,50),"visible torso at cone boundary seen")
	check(not sector.contains_body(polygon,Vector2(-90,0),50),"behind observer not seen")
	var blocked=sector.polygon(Vector2.ZERO,Vector2.RIGHT,func(p):return p.x<60)
	check(not sector.contains_body(blocked,Vector2(100,0),50),"wall blocks same polygon used for detection")
	await fixture(1)
	var a=game.events_controller.activity
	check(a.npc==game.actors.guest and a.extra_actor==null,"observer reuses persistent guest")
	check(game.actors.size()==8,"no duplicated residents in observation")
	check(game.actors.values().filter(func(person):return person.is_visible_in_tree()).size()==1,"only observer shown")
	await shot("01-observer")
	await fixture(8)
	a=game.events_controller.activity
	check(a.followers.size()==3 and a.followers.all(func(person):return person in game.actors.values()),"evacuation reuses persistent residents")
	check(a.followers.map(func(person):return person.sheet).size()==3,"evacuation appearances available")
	await shot("02-evacuation")
	await fixture(10)
	a=game.events_controller.activity;a.set_physics_process(false);game.player.set_physics_process(false)
	game.player.position=a.center+Vector2(-90,0);a.elapsed=1.39;a.last_wave=-1;a.invulnerable=0
	tap(KEY_E,true);await process_frame
	check(a.guarding(),"viewport E press starts guard")
	var hp=a.hp;a.tick(.05)
	check(a.hp==hp,"guard absorbs threatened lane")
	await shot("03-guard")
	tap(KEY_E,false);a.guard=0;a.elapsed=3.59;a.last_wave=0;a.invulnerable=0
	game.player.position=a.center
	a.tick(.05)
	check(a.hp==hp-1,"unprotected lane still deals real damage")
	game.event_window.toggle_pause();tap(KEY_E,true)
	check(not a.repair_hold,"paused input cannot stick guard")
	game.event_window.resume();tap(KEY_E,false)
	await fixture(2)
	a=game.events_controller.activity;var maze=a.maze
	check(maze.in_view and game.world.get_parent()==game and not game.world.visible,"maze replaces household view")
	check(game.event_window.viewport.world_2d!=game.get_world_2d(),"isolated physics world")
	check(maze.sorter.get_children().size()==2 and a.npc==game.actors.sonya,"only Vera and genuine Sonya in maze")
	var initial=maze.phase;tap(KEY_E,true);tap(KEY_E,false)
	check(maze.phase==initial,"distant E does not switch arbitrary doors")
	for i in range(maze.closed.size()): check(maze.model.grid.is_point_solid(maze.Layout.DOORS[i])==maze.closed[i],"door nav state "+str(i))
	var index=1;var door=maze.Layout.DOORS[index]
	game.player.position=maze.model.point(door);maze._set_door(index,false);maze.set_phase(index%2^1)
	check(not maze.closed[index],"door cannot close on player")
	game.player.position=maze.model.point(maze.Layout.START);maze.set_phase(0)
	await shot("04-maze-start")
	game.player.set_physics_process(true);game.player.enabled=true
	var age=0.0;var saved=false
	while a.active and age<180:
		var aim=maze.guidance();var delta=aim-game.player.position
		motion(delta.normalized() if delta.length()>4 else Vector2.ZERO)
		for i in range(maze.closed.size()):
			if maze.closed[i] and game.player.position.distance_to(maze.model.point(maze.Layout.DOORS[i]))<70: tap(KEY_E,true);tap(KEY_E,false);break
		if not saved and age>5:
			saved=true;motion(Vector2.ZERO)
			game.event_window.leave()
			var before=a.checkpoint().maze.duplicate(true)
			check(game.state.position==maze.source_player_position,"story save stores world position, not arena position")
			await game._load_game()
			game.set_physics_process(false);game.events_controller.set_physics_process(false);game.living.set_physics_process(false)
			a=game.events_controller.activity;maze=a.maze
			check(game.events_controller.phase=="suspended","maze save loads suspended")
			check(a.checkpoint().maze.player==before.player and a.checkpoint().maze.sonya==before.sonya,"maze positions survive load")
			game.events_controller.resume_activity();game.player.enabled=true
			await shot("05-maze-resumed")
		await physics_frame;age+=1.0/60
	motion(Vector2.ZERO)
	check(game.events_controller.phase=="decision","escort reaches actual maze exit")
	check(not maze.in_view and game.world.visible,"furniture restored after maze")
	check(game.player.get_parent()==game.world.sorter and game.actors.sonya.get_parent()==game.world.sorter,"actors returned to original world")
	await shot("06-maze-complete")
	print("MINIGAME FIX QA: ",checks," checks, ",errors.size()," failures")
	var file=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"checks":checks,"failures":errors,"maze_seconds":age},"\t"));file.close()
	game.queue_free();await process_frame;await create_timer(1.5,true,false,true).timeout
	quit(0 if errors.is_empty() else 1)
