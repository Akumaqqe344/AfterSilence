extends Control
const Tiles=preload("res://after_silence/assets/investigations0320/metal.png")
const Clues=preload("res://after_silence/assets/investigations0320/clues.png")
var lookout=-1
var correct=2
const POINTS=[Vector2(158,17),Vector2(257,47),Vector2(158,79),Vector2(60,47)]

func _ready():
	custom_minimum_size=Vector2(316,94)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw():
	var shift=Vector2(floorf((size.x-316)*.5),0)
	draw_set_transform(shift)
	draw_rect(Rect2(0,0,316,94),Color("23252d"))
	draw_texture_rect(Tiles,Rect2(4,4,308,86),true,Color("8a9b9d"))
	draw_rect(Rect2(4,4,308,86),Color("a59781"),false,1)
	for i in range(4):
		var at: Vector2=POINTS[i]
		draw_rect(Rect2(at-Vector2(8,8),Vector2(16,16)),Color("3a4b4e"))
		draw_rect(Rect2(at-Vector2(8,8),Vector2(16,16)),Color("d5bc91") if i==lookout else Color("8d9d92"),false,1)
		draw_string(get_theme_default_font(),at+Vector2(-4,4),["↑","→","↓","←"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ebd6b3"))
	var stone=Vector2(158,47)
	draw_texture_rect_region(Clues,Rect2(stone-Vector2(12,12),Vector2(24,24)),Rect2(96,48,24,24))
	if lookout<0: return
	var from: Vector2=POINTS[lookout]
	var center=stone+Vector2(0,-2)
	var left=center if lookout==correct else center+Vector2(-21,-9)
	var right=center if lookout==correct else center+Vector2(20,10)
	draw_line(from,left,Color("edd2a1"),1)
	draw_line(from,right,Color("98c1b5"),1)
	for at in [left,right]:
		draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),Color("e8ce9e" if lookout==correct else "a0a8a5"),false,1)
