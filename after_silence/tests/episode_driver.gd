extends Node
var root: Window
var process_frame: Signal
var physics_frame: Signal
var game
var failures: Array[String]=[]
var checks=0
var samples: Array[float]=[]
var output_dir="res://work"
var profiles: Array=[]
func _ready():
	root=get_tree().root
	process_frame=get_tree().process_frame
	physics_frame=get_tree().physics_frame
	if not OS.has_feature("editor"): output_dir=OS.get_executable_path().get_base_dir().path_join("qa")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	call_deferred("run")
func create_timer(seconds: float) -> SceneTreeTimer:
	return get_tree().create_timer(seconds)
func get_node_count() -> int:
	return get_tree().get_node_count()
func quit(code: int):
	get_tree().quit(code)
func check(ok: bool, message: String):
	checks+=1
	if not ok:
		failures.append(message)
		push_error("QA: "+message)
func press(id: String):
	check(game.buttons.has(id),"button available: "+id)
	if game.buttons.has(id):
		game.body.visible_characters=-1
		game.buttons[id].pressed.emit()

func win_battle(id: String):
	check(game.battle.active and game.battle.boss_id==id,"boss started: "+id)
	check(not game.battle.counter(),"counter requires opening: "+id)
	for i in range(3):
		game.battle.phase="exposed"
		game.battle.player_pos=Vector2(320,185)
		check(game.battle.counter(),"boss counter "+str(i+1)+": "+id)
	check(game.state.flag("boss_"+id+"_defeated"),"boss defeated: "+id)

func wait_world():
	await create_timer(0.7).timeout
func profile(label: String):
	if DisplayServer.get_name()=="headless": return
	var times: Array[float]=[]
	var count=720 if "--profile-long" in OS.get_cmdline_user_args() else 120
	var begin=Time.get_ticks_usec()
	for i in range(count):
		var frame=Time.get_ticks_usec()
		await process_frame
		times.append((Time.get_ticks_usec()-frame)/1000.0)
	var elapsed=(Time.get_ticks_usec()-begin)/1000000.0
	times.sort()
	profiles.append({"scene":label,"frames":count,"fps":count/elapsed,"frame_p95_ms":times[int(count*.95)-1],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0})
func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	if game.modal: game.body.visible_characters=-1
	await create_timer(.32 if game.modal else .04).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))
func route_to(id: String):
	var destination=Vector2.ZERO
	for spot in game.world.interactables:
		if spot.id==id: destination=spot.position
	check(destination!=Vector2.ZERO,"destination exists: "+id)
	var path=game.world.path_between(game.player.position,destination+Vector2(0,24))
	check(not path.is_empty(),"reachable interaction: "+game.state.zone+"/"+id)
func run():
	if not is_instance_valid(game):
		game=load("res://after_silence/scenes/main.tscn").instantiate()
		root.add_child(game)
	await process_frame
	game.saves.path="user://qa_full_episode.json"
	check(game.modal_backdrop.menu_mode,"main menu layout")
	await shot("menu")
	press("settings")
	check(game.buttons.has("large_text") and game.buttons.has("back"),"settings layout")
	await shot("settings")
	press("back")

	press("settings")
	press("archive")
	press("new")
	await wait_world()
	await create_timer(1.5).timeout
	check(game.state.zone=="town","new game town")
	press("close")
	await shot("town")
	await verify_homes()
	var origin=game.player.position
	Input.action_press("as_right")
	await create_timer(.4).timeout
	Input.action_release("as_right")
	check(game.player.position.x>origin.x+20,"real physics movement")
	await create_timer(.15).timeout
	check(game.player.velocity.length()<1,"Pechatai deceleration reaches rest")
	Input.action_press("as_right")
	Input.action_press("as_down")
	await create_timer(.2).timeout
	check(game.player.velocity.length()<=181,"diagonal input is normalized")
	check(game.player.diagonal==1,"diagonal selects DownRight atlas row")
	Input.action_release("as_right")
	Input.action_release("as_down")
	await create_timer(.15).timeout
	check(game.player.jump(),"Pechatai short jump starts")
	await create_timer(.1).timeout
	check(game.player.elevation>5,"jump has parabolic elevation")
	check(not game.player.jump(),"jump cannot restart in air")
	await create_timer(.5).timeout
	check(game.player.elevation==0,"jump lands on ground")
	for actor in game.actors.values():
		check(actor.portrait.size.y>8 and actor.portrait.end.y<=actor.sheet.get_height(),"NPC portrait follows occupied pixels")
	game._talk("nadia")
	await shot("dialogue")
	var paused_position=game.player.position
	Input.action_press("as_right")
	await create_timer(.15).timeout
	Input.action_release("as_right")
	check(game.player.position.distance_to(paused_position)<1,"dialogue freezes movement")
	check(not game.player.jump(),"dialogue blocks jumping")
	press("promise")
	check(game.state.item("key")==1 and game.state.flag("promise"),"promise and key")
	game._talk("lev")
	press("fuse")
	game.interact("photo")
	press("close")
	game.interact("poster")
	press("close")
	route_to("to_library")
	game.interact("to_library")
	await wait_world()
	check(game.state.zone=="library","library travel")
	for id in ["catalog","clock","diagram","signature","library_light","to_town"]: route_to(id)
	game._talk("mara")
	press("close")
	game.interact("catalog")
	for id in ["book_0","book_1","book_2"]: press(id)
	check(game.state.flag("catalog") and game.state.item("lens")==1,"catalogue puzzle via UI")
	press("close")
	game.interact("clock")
	check(game.buttons.has("hour"),"clock exposes puzzle rather than only clue")
	press("close")
	game._journal()
	press("achievements")
	check(game.body.text.contains("Открыто") and game.state.achievements.size()>0,"achievement screen and progress")
	await shot("achievements")
	press("back")

	press("poster")
	press("choose")
	press("clock")
	check("date" in game.state.links,"journal date inference via UI")
	press("close")
	game.interact("clock")
	for i in range(2): press("hour")
	for i in range(3): press("five")
	for i in range(2): press("minute")
	press("set")
	check(game.state.flag("clock_solved"),"clock solved 02:17")
	press("close")
	game.interact("diagram")
	press("close")
	game.interact("library_light")
	press("fuse")
	check(game.state.item("fuse")==0 and game.state.flag("library_light"),"fuse alternate use")
	game.interact("library_light")
	press("fuse")
	check(game.state.item("fuse")==1 and not game.state.flag("library_light"),"recover fuse avoids softlock")
	var normal_obstacles=game.world.obstacles.duplicate()
	game._shift()
	await wait_world()
	check(game.state.echo and game.state.charges==2,"limited reality shift")
	check(game.world.obstacles!=normal_obstacles,"reality changes geometry")
	game.interact("signature")
	press("close")
	check("signature" in game.state.evidence,"echo-only signature")
	await shot("library_echo")
	await profile("library_echo")
	game.player.position=Vector2(550,550)
	game._save(false)
	var saved=game.player.position
	game.player.position=Vector2(700,550)
	game._pause()
	press("load")
	await wait_world()
	check(game.player.position.distance_to(saved)<1,"pause load preserves saved position")
	game.interact("to_town")
	await wait_world()
	game.interact("to_forest")
	await wait_world()
	check(game.state.zone=="forest","forest travel")
	for id in ["relay","mirror","shelter","to_town"]: route_to(id)
	game.interact("relay")
	win_battle("relay")

	press("lever_0")
	press("lever_2")
	press("power")
	check(game.state.flag("forest_power") and game.state.item("fuse")==0,"relay solved and fuse consumed")
	press("close")
	await shot("forest_echo")
	game._talk("sonya")
	press("protect")
	await create_timer(.06).timeout
	check(game.state.flag("sonya_met") and "testimony" in game.state.evidence,"witness choice starts chase")
	check(game.enemy.active,"pursuer activated")
	var forest_position=game.player.position
	game.player.position=game.enemy.sanctuary
	await profile("forest_active_pursuer")
	game.player.position=forest_position
	game.enemy.position=Vector2(700,600)
	game.enemy.hear(Vector2(720,600),true)
	check(game.enemy.behavior=="investigate","pursuer hears footsteps")
	game.player.position=game.enemy.sanctuary
	game.enemy.lost_time=12
	game.enemy._physics_process(.016)
	check(game.enemy.behavior=="patrol","shelter breaks pursuit and enemy loses target")
	game.player.position=Vector2(710,600)
	game.enemy.direction=Vector2.RIGHT
	await physics_frame
	await process_frame
	check(game.modal,"contact opens recovery scene")
	if game.buttons.has("close"): press("close")
	game.interact("to_town")
	await wait_world()
	check(game.state.flag("returned"),"chase exit keeps story progress")
	game._talk("nadia")
	press("records")
	press("close")
	game._talk("lev")
	press("statement")
	press("close")
	game.interact("to_library")
	await wait_world()
	game._talk("mara")
	press("copy")
	press("close")
	game.interact("to_town")
	await wait_world()
	for pair in [["photo","ledger"],["testimony","signature"],["medical","clock"]]:
		game._journal()
		press(pair[0])
		press("choose")
		press(pair[1])
		press("close")
	check(game.state.links.size()==4,"four evidence inferences")
	game._talk("pavel")
	win_battle("watcher")

	press("public")
	await wait_world()
	check(game.state.flag("ending_public") and game.quests.stage()==7,"public ending")
	check(game.body.text.contains("Имя Сони остаётся"),"promise affects ending text")
	await shot("ending")
	press("walk")
	game._ending(false)
	await wait_world()
	check(game.state.flag("ending") and not game.state.flag("ending_public") and game.state.echo,"sealed ending changes world")
	game.body.visible_characters=-1
	game._close()
	game.state.language="en"
	game._journal()
	check(game.body.text.contains("Episode complete"),"English localization")
	press("close")
	game.player.position=Vector2(600,600)
	var begin=Time.get_ticks_usec()
	for i in range(180):
		var frame=Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec()-frame)/1000.0)
	var elapsed=(Time.get_ticks_usec()-begin)/1000000.0
	samples.sort()
	print("EPISODE_QA checks=",checks," failures=",failures.size()," FPS=",180.0/elapsed," frame_p95_ms=",samples[170]," nodes=",get_node_count()," render=",DisplayServer.get_name())
	var report={"checks":checks,"failures":failures,"fps":180.0/elapsed,"frame_p95_ms":samples[170],"renderer":DisplayServer.get_name()}
	report.profiles=profiles
	var output=FileAccess.open(output_dir.path_join("episode_qa_"+DisplayServer.get_name()+".json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "))
	output.close()
	game.audio.shutdown()
	await create_timer(.1).timeout
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
func verify_homes():
	var Homes=load("res://after_silence/world/homes.gd")
	for id in Homes.IDS:
		route_to(id)
		game.player.position=Homes.door(id,game.state.echo)
		check(game._nearest()==id,"house door can be selected: "+id)
		game.interact(id)
		await wait_world()
		check(game.state.zone==id,"entered "+id)
		check(game.world.path_between(game.player.position,Vector2(470,260)).size()>0,"room furniture leaves a passage")
		var before=game.player.position
		Input.action_press("as_up")
		await create_timer(.25).timeout
		Input.action_release("as_up")
		await create_timer(.15).timeout
		check(game.player.position.y<before.y-15,"room responds without Esc")
		game.interact("home_memory")
		press("close")
		if id=="home_lev":
			game._save(false)
			var saved=game.player.position
			game.player.position=Vector2(420,380)
			await game._load_game()
			check(game.state.zone==id and game.player.position.distance_to(saved)<1,"load restores interior and position")
			await shot("home_workshop")
		game.interact("leave_home")
		await wait_world()
		check(game.state.zone=="town" and game.player.position.distance_to(Homes.door(id,game.state.echo))<2,"exit returns to matching door")
	# Active resident walks through its door; same resident is visible indoors.
	game.state.clock=21
	game.player.position=Vector2(600,630)
	game.actors.nadia.position=Homes.door("home_nadia",false)
	game.npcs.update(game,.02,true)
	check(game.state.residents.nadia.zone=="home_nadia","NPC enters home at night")
	game.interact("home_nadia")
	await wait_world()
	check(game.actors.has("nadia"),"resident can be found indoors")
	game.player.position=Vector2(400,380)
	game.actors.nadia.position=Vector2(410,380)
	game.npcs.update(game,.02,true)
	check(not game.actors.nadia.enabled,"NPC stops and faces nearby player")
	game._save(false)
	await game._load_game()
	check(game.state.residents.nadia.zone=="home_nadia","resident home survives save and load")
	await shot("home_nadia")
	game.state.clock=8
	game.actors.nadia.position=Vector2(320,422)
	game.player.position=Vector2(450,300)
	game.npcs.update(game,.02,true)
	check(game.state.residents.nadia.zone=="town","NPC leaves home in morning")
	game.interact("leave_home")
	await wait_world()
	# Re-establish daytime workplaces before exercising the main story.
	for id in game.npcs.PROFILE:
		var data=game.npcs.PROFILE[id]
		var r=game.state.residents[id]
		r.zone=data[0];r.x=data[1].x;r.y=data[1].y;r.elapsed=0
	game._build_world("town",Vector2(600,630))
	await process_frame
