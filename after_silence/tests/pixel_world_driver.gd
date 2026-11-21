extends Node
const Landmarks=preload("res://after_silence/world/district_landmarks.gd")
const Water=preload("res://after_silence/world/watercourse.gd")
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
	for zone in ["town","orchard","forest","harbor"]:
		game._build_world(zone,Vector2(600,600))
		var nav=game.npcs.navigation
		var geometry=game.npcs.nav(zone)
		for id in Landmarks.for_zone(zone):
			var point: Vector2=Landmarks.SITES[id].point
			check(nav.clear_segment(geometry,point,point),"free landmark "+id)
			check(not nav.path(geometry,game.player.position,point).is_empty(),"reachable landmark "+id)
			game.player.position=point
			game.interact("landmark_"+id)
			check(game.state.flag("landmark_"+id),"discovered landmark "+id)
		if zone=="harbor":
			var end: Vector2=Landmarks.SITES.pier.point
			check(Water.depth(zone,end)>0 and nav.clear_segment(geometry,Vector2(980,end.y),end),"walkable deck over water")
			check(not nav.clear_segment(geometry,end,end+Vector2(65,0)),"deep water blocks beyond pier")
			await get_tree().physics_frame
			await get_tree().physics_frame
			var deck_start=Vector2(980,end.y)
			check(not game.player.test_move(Transform2D(0,deck_start),end-deck_start),"live capsule crosses the deck")
			check(game.player.test_move(Transform2D(0,end),Vector2(65,0)),"live capsule cannot walk off the pier")
	game._build_world("town",Vector2(600,645))
	var lev=game.actors.lev
	var prior_motion: bool=game.comfort.reduce_motion
	game.comfort.reduce_motion=false
	lev.idle_clock=3.91
	check(lev.idle_frame()==5,"resident uses a dedicated blink frame")
	game.comfort.reduce_motion=true
	check(lev.idle_frame()==4,"resident rests with reduced motion")
	game.comfort.reduce_motion=prior_motion
	var sheet: Image=lev.sheet.get_image()
	var rest=sheet.get_region(Rect2i(256,0,64,96))
	var blink=sheet.get_region(Rect2i(320,0,64,96))
	check(rest.get_data()!=blink.get_data(),"rest and blink have distinct artwork")
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
	game.ui.hide()
	for sample in [["town",Vector2(260,340),"01-home"],["town",Vector2(623,587),"02-market"],["orchard",Vector2(600,628),"03-orchard"],["harbor",Vector2(842,649),"04-harbor"],["home_nadia",Vector2(320,320),"05-interior"],["library",Vector2(480,400),"06-library"],["forest",Vector2(838,551),"07-forest"],["town",Vector2(1040,114),"08-pond"],["harbor",Vector2(1070,752),"09-pier"]]:
		game._build_world(sample[0],sample[1]);game.camera.position_smoothing_enabled=false;game.camera.reset_smoothing()
		await screenshot(sample[2])
	game.ui.show()
	game.toast.text=""
	game.comfort.reduce_motion=false
	game._district_map()
	await get_tree().create_timer(.43).timeout
	var atlas: Control=game.column.get_node("DistrictMap")
	var title: Control=game.column.get_child(0)
	check(atlas.get_global_rect().position.y>=title.get_global_rect().end.y,"animated map stays below its title")
	await screenshot("10-harbor-map")
	game._close()
	var file=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"version":ProjectSettings.get_setting("application/config/version"),"diagnostic_fixtures":true},"\t"));file.close()
	print("PIXEL WORLD QA: ",checks," checks, ",failures.size()," failures")
	game.queue_free();await get_tree().process_frame
	await get_tree().create_timer(1.5,true,false,true).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
