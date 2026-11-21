extends Node2D
const ATLAS=preload("res://after_silence/assets/investigations0320/clues.png")
const ITEMS=["notice","ribbon","clock","lamp","door","papers","stamp","desk","gear","rope","gauge","cup","flag","whistle","ticket","post","stone","scope"]
var kind="notice"
var ready_to_read=false
var item_size:=Vector2(42,42)
var reduced=false
var focus=false
var age=0.0

func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(not reduced and ready_to_read)

func _process(delta: float):
	var shown=get_viewport_rect().grow(30).has_point(get_global_transform_with_canvas()*Vector2.ZERO)
	if not shown: return
	age+=delta
	queue_redraw()

func _draw():
	var index=ITEMS.find(kind)
	if index<0: return
	var crop=Rect2((index%6)*24,floori(index/6.0)*24,24,24)
	var tint=Color.WHITE if ready_to_read else Color("c1bdc4")
	draw_rect(Rect2(-11,-2,22,4),Color("28222a73"))
	draw_texture_rect_region(ATLAS,Rect2(-item_size.x/2,-item_size.y+2,item_size.x,item_size.y),crop,tint,false,true)
	if ready_to_read:
		var top=roundf(-item_size.y-6+sin(age*2.7)*1.2)
		draw_rect(Rect2(-2,top,4,4),Color("eacb98"),false,1)
	if focus: draw_rect(Rect2(-item_size.x/2-2,-item_size.y-1,item_size.x+4,item_size.y+4),Color("b6c7a0"),false,1)
