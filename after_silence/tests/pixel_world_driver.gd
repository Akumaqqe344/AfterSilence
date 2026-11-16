extends Node
var game
var checks=0
var failures=[]
var output="res://work/pixel180-world"
func _ready():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-pixel-output="): output=argument.trim_prefix("--qa-pixel-output=")
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().create_timer(180).timeout.connect(func():print("PIXEL WORLD QA ERROR: watchdog");get_tree().quit(2))
	call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures.append(label);print("PIXEL WORLD QA ERROR: ",label)
func road_connected(world, start: Vector2, end: Vector2) -> bool:
	var target=world.cell(end)
	var first=world.cell(start)
	var queue=[first];var visited={first:true};var index=0
	while index<queue.size():
		var cell: Vector2i=queue[index];index+=1
		if cell==target: return true
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next=cell+offset
			if visited.has(next) or world.terrain.get_cell_source_id(next)!=1: continue
			if not world.walkable(Vector2(next*16+Vector2i(8,8))): continue
			visited[next]=true;queue.append(next)
	return false
func screenshot(label: String):
	if DisplayServer.get_name()=="headless": return
	await get_tree().create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"screenshot "+label)
func run():
	game.event_saves.path="user://qa_pixel_world.json"
	game._new_event_game();game._close()
	game.set_physics_process(false);game.events_controller.set_physics_process(false);game.living.set_physics_process(false)
	var identities={}
	for id in game.actors: identities[id]=game.actors[id].get_instance_id()
	for echo in [false,true]:
		game.state.echo=echo
		for zone in ["town","orchard","harbor"]:
			game._build_world(zone,Vector2(600,500))
			var world=game.world
			var all_homes=game.Homes.approaches(zone,echo)
			for entry in all_homes:
				var p: Vector2=entry[0]
				var junction: Vector2=entry[3]
				var continuous=true
				var approach=p+Vector2(0,24 if entry[2]=="riverside_rest" else 28)
				for y in range(int(p.y)-12,int(approach.y)+1):
					if world.terrain.get_cell_source_id(world.cell(Vector2(p.x,y)))!=1: continuous=false
				check(continuous,zone+" porch has no grass gap "+entry[2]+str(echo))
				check(road_connected(world,p+Vector2(0,16),Vector2(600,500)),zone+" road network "+entry[2]+str(echo))
				var navigation=game.npcs.navigation
				var geometry=game.npcs.nav(zone)
				var path=navigation.path(geometry,approach,junction)
				check(not path.is_empty(),zone+" walkable approach "+entry[2]+str(echo))
				var safe=true
				for i in range(1,path.size()):
					if not navigation.clear_segment(geometry,path[i-1],path[i]): safe=false
				check(safe,zone+" capsule clearance "+entry[2]+str(echo))
			for id in identities: check(game.actors[id].get_instance_id()==identities[id],"persistent resident "+zone+id)
	game.state.echo=false
	game._build_world("town",Vector2(600,645))
	for id in game.actors: game.state.residents[id].zone="library";game.npcs.attach(game,id)
	for pair in [["lev",Vector2(560,640)],["nadia",Vector2(600,640)]]:
		game.state.residents[pair[0]].zone="town";game.actors[pair[0]].position=pair[1];game.npcs.attach(game,pair[0])
	var goal=Vector2(620,640)
	var clearance=INF
	for i in range(240):
		game.npcs._walk(game,game.actors.lev,goal,.05,60)
		clearance=minf(clearance,game.actors.lev.position.distance_to(game.actors.nadia.position))
	check(game.actors.lev.position.distance_to(goal)<.1,"free goal beside resident reached without deadlock")
	check(clearance>=11.99,"resident detour never overlaps blocker")
	check(game.npcs.navigation.walkable(game.npcs.nav("town"),goal),"temporary reservations restored")
	for kind in ["grass","dirt","floor","water"]:
		var texture=preload("res://after_silence/world/surface_textures.gd").atlas(kind)
		check(texture.get_width()==(80 if kind=="water" else 320),"new material "+kind)
		check(texture==preload("res://after_silence/world/surface_textures.gd").atlas(kind),"cached material "+kind)
	for sample in [["town",Vector2(260,340),"01-home"],["town",Vector2(960,780),"02-workshop-path"],["orchard",Vector2(600,400),"03-orchard"],["harbor",Vector2(600,520),"04-harbor"],["home_nadia",Vector2(320,320),"05-interior"],["library",Vector2(480,400),"06-library"],["forest",Vector2(700,600),"07-forest"]]:
		game._build_world(sample[0],sample[1]);game.camera.position_smoothing_enabled=false;game.camera.reset_smoothing()
		await screenshot(sample[2])
	var file=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"version":ProjectSettings.get_setting("application/config/version"),"diagnostic_fixtures":true},"\t"));file.close()
	print("PIXEL WORLD QA: ",checks," checks, ",failures.size()," failures")
	game.queue_free();await get_tree().process_frame
	await get_tree().create_timer(1.5,true,false,true).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
