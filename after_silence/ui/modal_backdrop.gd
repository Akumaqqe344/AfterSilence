extends Control
const PORTRAIT=preload("res://after_silence/assets/pechatai/player/idle.png")
const DESIGN=preload("res://after_silence/ui/comfort_theme.gd")
var menu_mode=false
var english=false
var journey_mode=false
var reduce_motion=false
var age=0.0
var tick=0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not menu_mode or reduce_motion: return
	age+=delta
	var next_tick=int(age*4.0)
	if next_tick!=tick:
		tick=next_tick
		queue_redraw()

func _star(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at-Vector2(1,3),Vector2(2,6)),color)
	draw_rect(Rect2(at-Vector2(3,1),Vector2(6,2)),color)

func _plant(at: Vector2, flip: float=1.0) -> void:
	draw_line(at,at+Vector2(4*flip,-32),Color("80b59d"),2)
	for i in range(3):
		var p=at+Vector2(3*flip,-8-i*8)
		draw_rect(Rect2(p+Vector2(-11,-4),Vector2(10,4)),Color("a1c6a7"))
		draw_rect(Rect2(p+Vector2(2,-7),Vector2(9,4)),Color("689b8a"))
	draw_rect(Rect2(at+Vector2(-9,0),Vector2(21,5)),Color("e7b397"))
	draw_rect(Rect2(at+Vector2(-6,5),Vector2(15,10)),Color("be8e7b"))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),DESIGN.INK)
	draw_rect(Rect2(10,10,size.x-20,size.y-20),Color("65716f"),false)
	draw_rect(Rect2(10,10,46,2),DESIGN.SAGE)
	draw_rect(Rect2(size.x-56,size.y-12,46,2),DESIGN.PEACH)
	if menu_mode:
		draw_style_box(DESIGN.panel(Color("354b4c")),Rect2(379,31,230,279))
		draw_circle(Vector2(548,78),23,Color("f4d8a9"))
		draw_circle(Vector2(557,71),22,Color("354b4c"))
		for i in range(10):
			var x=400+posmod(i*47,185)
			var y=51+posmod(i*31,86)
			var light=0.60+0.16*sin(age*.65+i) if not reduce_motion else .7
			_star(Vector2(x,y),Color(0.93,0.88,0.72,light))
		for i in range(6):
			var x=392+i*34
			var y=174-posmod(i*13,27)
			draw_rect(Rect2(x,y,29,80),Color("293d42"))
			for floor in range(3):
				draw_rect(Rect2(x+6,y+12+floor*15,5,7),Color("c6ac80"))
				draw_rect(Rect2(x+18,y+12+floor*15,5,7),Color("8f9e88"))
		draw_rect(Rect2(391,233,206,47),Color("435b52"))
		draw_texture_rect_region(PORTRAIT,Rect2(448,139,112,122),Rect2(4,2,56,61))
		_plant(Vector2(413,246))
		_plant(Vector2(578,246),-1)
		var caption="A little light stays with you" if english else "Маленький свет всегда рядом"
		draw_string(get_theme_default_font(),Vector2(398,294),caption,HORIZONTAL_ALIGNMENT_LEFT,200,7,DESIGN.TEXT)
	else:
		_plant(Vector2(613,331),-1)
	var footer="Take your time · Tab to choose · Enter to open" if english else "Не спеши · Tab — выбрать · Enter — открыть"
	draw_string(get_theme_default_font(),Vector2(28,size.y-20),footer,HORIZONTAL_ALIGNMENT_LEFT,580,6,DESIGN.MUTED)
