extends SceneTree
## Capture matching gameplay frames and map fingerprints with isolated QA saves.

const Zones=["town","forest","orchard","harbor","library","shop","home_nadia","home_lev","home_pavel","home_sonya"]
const Views=[
	["01-hub","town",Vector2(600,645)], ["02-town","town",Vector2(385,490)],
	["03-forest","forest",Vector2(740,550)], ["04-orchard","orchard",Vector2(610,495)],
	["05-harbor","harbor",Vector2(980,690)], ["06-river","town",Vector2(1200,978)],
	["07-library","library",Vector2(477,418)], ["08-home","home_sonya",Vector2(320,266)],
	["09-shop","shop",Vector2(320,285)],
]
var game
var output="res://work/ppae-preview"
var failures:=0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ppae-output="): output=arg.trim_prefix("--ppae-output=")
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game)
	game.event_saves.path="user://qa_ppae_capture_%s.json"%Time.get_ticks_usec()
	game.comfort.reduce_motion=false
	game.state.language="ru"
	game._new_event_game()
	game._close()
	game.set_physics_process(false)
	game.events_controller.set_physics_process(false)
	game.living.set_physics_process(false)
	var maps={}
	for echo in [false,true]:
		game.state.echo=echo
		for zone in Zones:
			game._build_world(zone,Vector2(600,645))
			maps[zone+":"+str(echo)]=_geometry().sha256_text()
			await process_frame
	game.set_physics_process(true)
	game.state.echo=false
	game.state.clock=10.0
	for view in Views:
		game._build_world(view[1],view[2])
		await _shoot(view[0])
	game.state.clock=21.0
	game._build_world("town",Vector2(600,645))
	await _shoot("10-hub-night")
	game.state.clock=10.0
	for running in [false,true]:
		game._build_world("town",Vector2(600,692))
		var shift:=InputEventKey.new()
		shift.keycode=KEY_SHIFT
		shift.physical_keycode=KEY_SHIFT
		shift.pressed=running
		Input.parse_input_event(shift)
		Input.action_press("as_up")
		for i in range(6):
			await create_timer(.055).timeout
			await _shoot(("12-run" if running else "11-walk")+"-%02d"%i,false)
		Input.action_release("as_up")
		shift.pressed=false
		Input.parse_input_event(shift)
	var report:=FileAccess.open(output.path_join("geometry.json"),FileAccess.WRITE)
	if report:
		report.store_string(JSON.stringify(maps,"\t"))
		report.close()
	else:
		failures+=1
	print("PPAE VISUAL QA: ",maps.size()," map states, ",failures," failures")
	game.queue_free()
	await process_frame
	await create_timer(1.0).timeout
	quit(1 if failures else 0)

func _shoot(label: String, settle: bool=true) -> void:
	if DisplayServer.get_name()=="headless": return
	if settle: await create_timer(.16).timeout
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join(label+".png"))!=OK:
		failures+=1

func _geometry() -> String:
	var map=game.world
	var cells:=PackedByteArray()
	var floor_types:=PackedByteArray()
	for y in range(map.grid.region.size.y):
		for x in range(map.grid.region.size.x):
			var cell:=Vector2i(x,y)
			cells.append(int(map.grid.is_point_solid(cell)))
			floor_types.append(map.terrain.get_cell_source_id(cell))
	var residents={}
	for id in game.actors:
		var actor=game.actors[id]
		if actor.get_parent()==map.sorter: residents[id]=actor.position
	return var_to_str([map.dimensions,map.paths,map.obstacles,map.interactables,cells,floor_types,residents,game.player.position])
