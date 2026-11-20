extends RefCounted
const CELL=40
const SIZE=Vector2i(21,15)
const START=Vector2i(1,1)
const EXIT=Vector2i(19,13)
const DOORS=[Vector2i(10,1),Vector2i(19,4),Vector2i(8,5),Vector2i(3,8),Vector2i(12,9),Vector2i(17,12)]
var floor_cells: Dictionary={}
var grid: AStarGrid2D
var open_grid: AStarGrid2D
func _init():
	for segment in [[Vector2i(1,1),Vector2i(19,1)],[Vector2i(19,1),Vector2i(19,5)],[Vector2i(3,5),Vector2i(19,5)],[Vector2i(3,5),Vector2i(3,9)],[Vector2i(3,9),Vector2i(17,9)],[Vector2i(17,9),Vector2i(17,13)],[Vector2i(17,13),Vector2i(19,13)],[Vector2i(5,1),Vector2i(5,3)],[Vector2i(2,3),Vector2i(5,3)],[Vector2i(10,3),Vector2i(10,5)],[Vector2i(10,3),Vector2i(15,3)],[Vector2i(15,3),Vector2i(15,5)],[Vector2i(7,9),Vector2i(7,11)],[Vector2i(7,11),Vector2i(12,11)],[Vector2i(12,11),Vector2i(12,13)],[Vector2i(8,13),Vector2i(12,13)]]:
		var p: Vector2i=segment[0];var end: Vector2i=segment[1]
		var delta=(end-p).sign()
		floor_cells[p]=true
		while p!=end: p+=delta;floor_cells[p]=true
	grid=_make_grid();open_grid=_make_grid()
func _make_grid() -> AStarGrid2D:
	var result=AStarGrid2D.new();result.region=Rect2i(Vector2i.ZERO,SIZE)
	result.cell_size=Vector2(CELL,CELL);result.offset=Vector2.ONE*CELL*.5
	result.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;result.update()
	for y in range(SIZE.y):
		for x in range(SIZE.x): result.set_point_solid(Vector2i(x,y),not floor_cells.has(Vector2i(x,y)))
	return result
func point(cell: Vector2i) -> Vector2: return Vector2(cell)*CELL+Vector2.ONE*CELL*.5
func cell(p: Vector2) -> Vector2i: return Vector2i(floori(p.x/CELL),floori(p.y/CELL))
func path(a: Vector2,b: Vector2,all_open: bool=false) -> PackedVector2Array:
	var source=open_grid if all_open else grid
	var first=cell(a);var last=cell(b)
	if not source.is_in_boundsv(first) or not source.is_in_boundsv(last) or source.is_point_solid(first) or source.is_point_solid(last): return PackedVector2Array()
	var result=source.get_point_path(first,last)
	if result.is_empty(): return result
	result[0]=a;result.append(b)
	return result
static func valid(data: Dictionary) -> bool:
	if data.get("version",0)!=1 or data.get("phase",-1) not in [0,1]: return false
	var age=data.get("age",-1)
	if not (age is float or age is int) or not is_finite(float(age)) or age<0 or age>3600: return false
	for key in ["player","sonya"]:
		var p=data.get(key)
		if not p is Array or p.size()!=2: return false
		for i in range(2):
			if not (p[i] is float or p[i] is int) or not is_finite(float(p[i])) or p[i]<0 or p[i]>SIZE[i]*CELL: return false
	var states=data.get("closed",[])
	if not states is Array or states.size()!=DOORS.size(): return false
	for state in states:
		if not state is bool: return false
	return true
