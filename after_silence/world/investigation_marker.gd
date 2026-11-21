extends Node2D
const ATLAS=preload("res://after_silence/assets/investigations0320/clues.png")
const EXTRA_ATLAS = preload("res://after_silence/assets/expeditions0330/props.png")
const EXTRA_ITEMS = ["lock", "reel", "letter", "bell", "winch", "radio"]
const ITEMS=["notice","ribbon","clock","lamp","door","papers","stamp","desk","gear","rope","gauge","cup","flag","whistle","ticket","post","stone","scope"]
var kind="notice"
var ready_to_read=false
var item_size:=Vector2(42,42)
var reduced=false
var focus=false
var age=0.0
var player: Node2D
var behind_marker = false

func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(is_instance_valid(player) or (not reduced and ready_to_read))

func _process(delta: float):
	var shown=get_viewport_rect().grow(30).has_point(get_global_transform_with_canvas()*Vector2.ZERO)
	if not shown: return
	var overlaps = is_instance_valid(player) and absf(player.position.x-position.x)<item_size.x*.45 and player.position.y<position.y and player.position.y>position.y-item_size.y
	if overlaps != behind_marker:
		behind_marker = overlaps
		queue_redraw()
	if ready_to_read and not reduced:
		age=fposmod(age+delta,TAU/2.7)
		queue_redraw()

func _draw():
	var sheet = ATLAS
	var index=ITEMS.find(kind)
	if index<0:
		sheet = EXTRA_ATLAS
		index = EXTRA_ITEMS.find(kind)
	if index<0: return
	var crop=Rect2((index%6)*24,floori(index/6.0)*24,24,24)
	var tint=Color.WHITE if ready_to_read else Color("c1bdc4")
	if behind_marker: tint.a = .43
	draw_rect(Rect2(-8,-1,16,3),Color("28222a73"))
	draw_texture_rect_region(sheet,Rect2(-item_size.x/2,-item_size.y+2,item_size.x,item_size.y),crop,tint,false,true)
	if ready_to_read:
		var top=roundf(-item_size.y-6+sin(age*2.7)*1.2)
		var star = Vector2(0,top)
		draw_line(star-Vector2(2,0),star+Vector2(2,0),Color("edce9d"),1)
		draw_line(star-Vector2(0,2),star+Vector2(0,2),Color("edce9d"),1)
	if focus: draw_rect(Rect2(-item_size.x/2-2,-item_size.y-1,item_size.x+4,item_size.y+4),Color("b6c7a0"),false,1)
