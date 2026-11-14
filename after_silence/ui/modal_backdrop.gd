extends Control

const PORTRAIT=preload("res://after_silence/assets/pechatai/player/idle.png")
const INK=Color("070d11")
const TEAL=Color("69c5bf")

var menu_mode=false
var english=false
var age=0.0
var tick=0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	age+=delta
	var next_tick=int(age*12.0)
	if next_tick!=tick:
		tick=next_tick
		queue_redraw()

func _draw() -> void:
	var bounds=Rect2(Vector2.ZERO,size)
	draw_rect(bounds,INK)
	var frame=Rect2(9,9,size.x-18,size.y-18)
	draw_rect(frame,Color("24413f"),false,1.0)
	draw_rect(Rect2(9,9,47,2),TEAL)
	draw_rect(Rect2(size.x-72,size.y-11,63,2),TEAL.darkened(.4))
	var portrait_bounds=Rect2(size.x-(275 if menu_mode else 245),33,230 if menu_mode else 200,size.y-61)
	var source=Rect2(4,2,56,61)
	draw_texture_rect_region(PORTRAIT,portrait_bounds,source,Color(.45,.78,.75,.72 if menu_mode else .28))
	var scan=Color(.02,.09,.10,.18)
	for y in range(0,int(size.y),4):
		draw_rect(Rect2(0,y,size.x,1),scan)
	var base=tick*17
	for i in range(9):
		var index=base+i*53
		var y=22+posmod(index*37, int(size.y)-44)
		var width=16+posmod(index*29,116)
		var x=size.x-width-13-posmod(index*19,196)
		draw_rect(Rect2(x,y,width,1 if i%3 else 2),Color(.32,.78,.75,.09 if i%3 else .21))
	if menu_mode:
		draw_rect(Rect2(344,34,1,size.y-68),Color("315450"))
		var band_y=65+posmod(tick*41,185)
		draw_rect(Rect2(382,band_y,196,2),Color(.56,.92,.88,.22))
	else:
		draw_rect(Rect2(34,64,size.x-68,1),Color("315450"))
	var footer="ПАМЯТЬ / ЭПИЗОД I" if menu_mode else "ПОСЛЕ ТИШИНЫ / АРХИВ"
	if english:
		footer="MEMORY / EPISODE I" if menu_mode else "AFTER SILENCE / ARCHIVE"
	draw_string(get_theme_default_font(),Vector2(25,size.y-17),footer,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("75928b"))
