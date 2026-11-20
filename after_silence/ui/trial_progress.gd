extends Range
## A continuous fill with step marks, drawn on pixel boundaries.
var accent=Color("e1b879"):
	set(color):
		accent=color
		queue_redraw()

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	step=0
	value_changed.connect(func(_value):queue_redraw())

func _draw():
	var track=Rect2(Vector2.ZERO,size.floor())
	draw_rect(track,Color("536455"))
	draw_rect(track.grow(-1),Color("15201b"))
	var inside=track.grow(-3)
	var filled=roundf(inside.size.x*ratio)
	if filled>0:
		draw_rect(Rect2(inside.position,Vector2(filled,inside.size.y)),accent)
		draw_rect(Rect2(inside.position,Vector2(filled,1)),accent.lightened(.38))
		draw_rect(Rect2(inside.position+Vector2(0,inside.size.y-1),Vector2(filled,1)),accent.darkened(.31))
		draw_rect(Rect2(inside.position+Vector2(filled-1,0),Vector2(1,inside.size.y)),Color("fff4d7"))
	if max_value>1 and max_value<=16:
		for mark in range(1,int(max_value)):
			var x=inside.position.x+roundf(inside.size.x*mark/max_value)
			var mark_color=Color("293528a0") if x<inside.position.x+filled else Color("526250")
			draw_rect(Rect2(x,inside.position.y,1,inside.size.y),mark_color)
