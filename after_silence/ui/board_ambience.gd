extends Control

var game
var tint=Color.WHITE
var time=0.0
var draw_age=0.0

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_process(false)

func begin(accent: Color):
	tint=accent
	time=0.0;draw_age=0.0
	set_process(not game.comfort.reduce_motion)
	queue_redraw()

func _process(dt):
	if game.modal: return
	time=fmod(time+dt,30.0)
	draw_age+=dt
	if draw_age>=1.0/24:
		draw_age=0
		queue_redraw()

func _draw():
	draw_rect(Rect2(15,61,577,1),Color(tint.r,tint.g,tint.b,.49))
	draw_rect(Rect2(15,61,81,2),tint)
	draw_rect(Rect2(545,5,45,41),Color("192a34"))
	draw_rect(Rect2(545,5,45,41),tint.darkened(.21),false)
	for x in [12,588]:
		for y in [61,282]:
			draw_rect(Rect2(x,y,7,1),tint)
			draw_rect(Rect2(x,y,1,4),tint)
	if game.comfort.reduce_motion: return
	for i in range(8):
		var x=27+fposmod(i*83+time*(7+i%2*3),536)
		var y=69+sin(time*.85+i*1.9)*2
		var light=Color(tint.r,tint.g,tint.b,.28+i%3*.13)
		draw_rect(Rect2(roundf(x),roundf(y),2,1+i%2),light)
	var sheen=16+fposmod(time*57,568)
	draw_rect(Rect2(roundf(sheen),61,12,1),Color("fff0cf88"))
