extends Node2D
## Small porch details are anchored in world space and follow the local wind.
const Water=preload("res://after_silence/world/watercourse.gd")
const Garden=preload("res://after_silence/world/garden_pixels.gd")
var world
var comfort
var season=0
var zone="town"
var sway_time=0.0
var sway=0
var spacing=51.0

func _ready():
	if world==null:
		set_process(comfort!=null)
		return
	set_process(false)
	for child in world.sorter.get_children():
		if child.kind!="house": continue
		var garden=get_script().new()
		garden.zone=world.zone
		garden.comfort=world.visual_comfort
		garden.season=child.variant
		garden.spacing=clampf(child.size.x*.34,48.0,65.0)
		garden.position=child.position+Vector2(0,12)
		world.sorter.add_child(garden)

func _process(delta: float):
	var on_screen=get_viewport_rect().grow(110).has_point(get_global_transform_with_canvas().origin)
	if not on_screen: return
	sway_time=fposmod(sway_time+delta,TAU)
	var next=0 if comfort.reduce_motion else roundi(sin(sway_time+(position.x+position.y)*.012))
	if sway!=next:
		sway=next
		queue_redraw()

func _draw():
	if world!=null: return
	for side in [-1,1]:
		var at=Vector2(side*spacing,-4)
		if Water.depth(zone,position+at)>-20: continue
		if (season+side)%3==0:
			Garden.bunch(self,at+Vector2(3,2),posmod(season+side,9),sway,5)
		else:
			Garden.planter(self,at,posmod(season+side,9),sway)
	for i in range(3):
		var p=Vector2(-18+i*12,-9+absi(i-1))
		draw_rect(Rect2(p,Vector2(12,8)),Color("746b56"))
		draw_rect(Rect2(p+Vector2(1,0),Vector2(10,2)),Color("a49774"))
