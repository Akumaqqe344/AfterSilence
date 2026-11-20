extends Node2D
const Layout=preload("res://after_silence/core/sonya_maze_layout.gd")
var model=Layout.new()
var game
var activity
var sorter=Node2D.new()
var phase=0
var age=0.0
var closed: Array=[]
var shapes: Array=[]
var in_view=false
var source_player_position=Vector2.ZERO
var source_sonya_position=Vector2.ZERO
var original_limits=[]
var route_age=0.0
var suspended: Dictionary={}
var player_parent
var sonya_parent
func _ready():
	sorter.y_sort_enabled=true;add_child(sorter)
	for y in range(Layout.SIZE.y):
		for x in range(Layout.SIZE.x):
			var cell=Vector2i(x,y)
			if not model.floor_cells.has(cell): _body(Rect2(Vector2(cell)*Layout.CELL,Vector2.ONE*Layout.CELL))
	for i in range(Layout.DOORS.size()):
		var shape=_body(door_rect(i));shapes.append(shape);closed.append(false)
	set_phase(0)
func _body(rect: Rect2) -> CollisionShape2D:
	var body=StaticBody2D.new();body.position=rect.get_center()
	var shape=CollisionShape2D.new();var rectangle=RectangleShape2D.new();rectangle.size=rect.size
	shape.shape=rectangle;body.add_child(shape);add_child(body)
	return shape
func door_rect(i: int) -> Rect2:
	return Rect2(Vector2(Layout.DOORS[i])*Layout.CELL,Vector2.ONE*Layout.CELL)
func open(viewport: SubViewport):
	if in_view: return
	in_view=true
	source_player_position=game.player.position;source_sonya_position=activity.npc.position
	player_parent=game.player.get_parent();sonya_parent=activity.npc.get_parent()
	original_limits=[game.camera.limit_left,game.camera.limit_top,game.camera.limit_right,game.camera.limit_bottom]
	viewport.world_2d=World2D.new()
	reparent(viewport,false)
	process_mode=Node.PROCESS_MODE_INHERIT
	for person in [game.player,activity.npc]:
		person.set_meta("arena_control",true);person.reparent(sorter,false)
	game.player.position=model.point(Layout.START)
	activity.npc.position=model.point(Layout.START)+Vector2(0,13)
	game.player.velocity=Vector2.ZERO;game.player.collision_mask=1
	game.camera.limit_left=0;game.camera.limit_top=0;game.camera.limit_right=Layout.SIZE.x*Layout.CELL;game.camera.limit_bottom=Layout.SIZE.y*Layout.CELL
	game.camera.position=Vector2.ZERO;game.camera.offset=Vector2.ZERO;game.camera.zoom=Vector2.ONE*.85
	game.camera.reset_smoothing();game.world.hide()
	if not suspended.is_empty():
		game.player.position=Vector2(suspended.player[0],suspended.player[1])
		activity.npc.position=Vector2(suspended.sonya[0],suspended.sonya[1])
		phase=int(suspended.phase);age=float(suspended.age)
		for i in range(closed.size()): _set_door(i,suspended.closed[i])
		suspended.clear()
	set_phase(phase)
func close():
	if not in_view: return
	suspended=capture();in_view=false
	game.player.reparent(player_parent if is_instance_valid(player_parent) else game.world.sorter,false)
	activity.npc.reparent(sonya_parent if is_instance_valid(sonya_parent) else game.world.sorter,false)
	game.player.position=source_player_position;activity.npc.position=source_sonya_position
	for person in [game.player,activity.npc]: person.remove_meta("arena_control");person.velocity=Vector2.ZERO
	game.camera.limit_left=original_limits[0];game.camera.limit_top=original_limits[1];game.camera.limit_right=original_limits[2];game.camera.limit_bottom=original_limits[3]
	process_mode=Node.PROCESS_MODE_DISABLED
	reparent(activity,false);game.world.show()
func capture() -> Dictionary:
	if not in_view and not suspended.is_empty(): return suspended.duplicate(true)
	return {"version":1,"phase":phase,"age":age,"closed":closed.duplicate(),"player":[game.player.position.x,game.player.position.y],"sonya":[activity.npc.position.x,activity.npc.position.y]}
func restore(data: Dictionary):
	if Layout.valid(data): suspended=data.duplicate(true)
func _set_door(i: int,value: bool):
	closed[i]=value;shapes[i].set_deferred("disabled",not value)
	model.grid.set_point_solid(Layout.DOORS[i],value)
func set_phase(value: int):
	phase=posmod(value,2)
	for i in range(closed.size()):
		var should_close=i%2!=phase
		if should_close and in_view and [game.player,activity.npc].any(func(person):return door_rect(i).grow(14).has_point(person.position)): continue
		_set_door(i,should_close)
	queue_redraw()
func interact():
	if not in_view: return
	for i in range(closed.size()):
		if game.player.position.distance_to(model.point(Layout.DOORS[i]))<100:
			age=0;set_phase(1-phase);game.audio.ping(game.state.volume);return
func tick(dt: float):
	if not in_view: return
	age+=dt;route_age-=dt
	if age>=6: age=fmod(age,6);set_phase(1-phase)
	else: set_phase(phase)
	var person=activity.npc
	person.enabled=false;person.scripted=true;person.npc_speed=100
	if person.position.distance_to(game.player.position)>190:
		person.target=person.position
	else:
		if route_age<=0:
			var path=model.path(person.position,game.player.position)
			if path.size()>1: path.remove_at(0)
			person.set_meta("maze_route",path);route_age=.15
		var path: PackedVector2Array=person.get_meta("maze_route",PackedVector2Array())
		while not path.is_empty() and person.position.distance_to(path[0])<7: path.remove_at(0)
		person.target=path[0] if not path.is_empty() and person.position.distance_to(game.player.position)>25 else person.position
		person.set_meta("maze_route",path)
	queue_redraw()
func finished() -> bool:
	var exit=model.point(Layout.EXIT)
	return game.player.position.distance_to(exit)<24 and activity.npc.position.distance_to(exit)<42
func guidance() -> Vector2:
	if game.player.position.distance_to(activity.npc.position)>75: return game.player.position
	var path=model.path(game.player.position,model.point(Layout.EXIT),true)
	while not path.is_empty() and game.player.position.distance_to(path[0])<9: path.remove_at(0)
	return path[0] if not path.is_empty() else model.point(Layout.EXIT)
func path_between(a: Vector2,b: Vector2) -> PackedVector2Array: return model.path(a,b)
func _draw():
	var extent=Vector2(Layout.SIZE*Layout.CELL)
	draw_texture_rect(preload("res://after_silence/world/surface_textures.gd").atlas("floor"),Rect2(Vector2.ZERO,extent),true,Color("9aa6a1"))
	for y in range(Layout.SIZE.y):
		for x in range(Layout.SIZE.x):
			if model.floor_cells.has(Vector2i(x,y)): continue
			var rect=Rect2(Vector2(x,y)*Layout.CELL,Vector2.ONE*Layout.CELL)
			draw_rect(rect,Color("35434a"));draw_rect(Rect2(rect.position,Vector2(Layout.CELL,5)),Color("718080"))
			draw_rect(Rect2(rect.position+Vector2(1,8),Vector2(Layout.CELL-2,1)),Color("536565"))
			draw_line(rect.position+Vector2(18,9),rect.position+Vector2(18,25),Color("25363c"),1)
			draw_line(rect.position+Vector2(0,27),rect.end-Vector2(0,13),Color("25363c"),1)
	for i in range(closed.size()):
		var rect=door_rect(i)
		if closed[i]: draw_rect(rect,Color("b78f68"))
		else: draw_rect(rect,Color("779b8d"),false,2)
		if closed[i]:
			for x in range(5,Layout.CELL,8): draw_rect(Rect2(rect.position+Vector2(x,2),Vector2(3,Layout.CELL-4)),Color("5f554b"))
	var exit=model.point(Layout.EXIT)
	draw_rect(Rect2(exit-Vector2(17,17),Vector2(34,34)),Color("a7d6bd"),false,3)
	draw_string(game.ui.theme.default_font,exit+Vector2(-14,3),game.t("ВЫХ","EXIT"),HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("eff1c8"))
