extends Node2D
## Small porch details are anchored in world space and follow the local wind.
const Water=preload("res://after_silence/world/watercourse.gd")
const PETALS=[Color("cf8f82"),Color("b7a4c2"),Color("f0c78b"),Color("bccc99")]
var world
var comfort
var season=0
var zone="town"
var sway_time=0.0
var sway=0

func _ready():
	if world==null:
		set_process(comfort!=null)
		return
	set_process(false)
	for child in world.sorter.get_children():
		if not child.has_meta("building"): continue
		var garden=get_script().new()
		garden.zone=world.zone
		garden.comfort=world.visual_comfort
		garden.season=posmod(child.variant,PETALS.size())
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
		var at=Vector2(side*51,-6)
		if Water.depth(zone,position+at)<=-20: _planter(at)
	draw_rect(Rect2(-13,-10,26,10),Color("514637"))
	draw_rect(Rect2(-12,-9,24,8),Color("927655"))
	draw_rect(Rect2(-10,-8,20,1),Color("c49b6c"))
	for x in range(-8,10,4):
		draw_rect(Rect2(x,-6,2,3),Color("b48b60"))

func _planter(at: Vector2):
	draw_rect(Rect2(at+Vector2(-14,2),Vector2(28,5)),Color("353e2860"))
	draw_rect(Rect2(at+Vector2(-12,-6),Vector2(24,11)),Color("554735"))
	draw_rect(Rect2(at+Vector2(-11,-5),Vector2(22,9)),Color("886043"))
	draw_rect(Rect2(at+Vector2(-11,-5),Vector2(22,1)),Color("d1a475"))
	for x in [-7,0,7]:
		draw_rect(Rect2(at+Vector2(x,-3),Vector2(1,5)),Color("b0845c"))
	for i in range(5):
		var stem=at+Vector2(-8+i*4,-6)
		var bloom=stem+Vector2(sway,-5-(i*7)%4)
		var color: Color=PETALS[(season+i/3)%PETALS.size()]
		draw_line(stem,bloom,Color("54724d"),1)
		draw_rect(Rect2(stem+Vector2(-2,-4),Vector2(2,2)),Color("779466"))
		draw_rect(Rect2(bloom+Vector2(-2,0),Vector2(5,2)),color.darkened(.2))
		draw_rect(Rect2(bloom+Vector2(-1,-1),Vector2(3,3)),color)
		draw_rect(Rect2(bloom,Vector2(1,1)),Color("eed9a0"))
