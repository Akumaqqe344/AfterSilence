extends Control
const PORTRAIT=preload("res://after_silence/assets/pechatai/player/idle.png")
const DESIGN=preload("res://after_silence/ui/comfort_theme.gd")
const HOME=preload("res://after_silence/assets/art100/house-1.png")
const SHOP=preload("res://after_silence/assets/art120/shop_front.png")
const TREE=preload("res://after_silence/assets/art100/tree-2.png")
const LAMP=preload("res://after_silence/assets/props091/way_lamp.png")
var menu_mode=false
var animation_enabled=false
var finish_mark=false
var sky_time=0.0
var frame_budget=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)

func configure_motion(enabled: bool):
	animation_enabled=(menu_mode or finish_mark) and enabled
	if not menu_mode or not animation_enabled: sky_time=0.0
	set_process(animation_enabled)
	queue_redraw()

func _process(dt):
	if not is_visible_in_tree(): return
	sky_time=fmod(sky_time+dt,120.0)
	if not menu_mode and sky_time>.9: set_process(false);queue_redraw();return
	frame_budget+=dt
	if frame_budget>=1.0/24.0:
		frame_budget=0
		queue_redraw()

func _draw() -> void:
	if menu_mode:
		_panorama()
	else:
		draw_rect(Rect2(Vector2.ZERO,size),Color("101714bc"))
	if finish_mark and animation_enabled and sky_time<.9:
		_quiet_victory()

func _panorama():
	for y in range(0,360,3):
		var height=float(y)/360.0
		var sky=Color("263638").lerp(Color("b78b69"),smoothstep(0.0,.62,height))
		draw_rect(Rect2(0,y,640,3),sky)
	var sun=Vector2(496,104)
	for radius in [48,39,31]:
		draw_circle(sun,radius,Color("f3c18c18"))
	draw_circle(sun,26,Color("f5cf96"))
	for i in range(7):
		var p=Vector2(279+posmod(i*89+int(sky_time*(2+i%3)),390),53+posmod(i*47,106))
		draw_rect(Rect2(p,Vector2(35+i*5,2)),Color("f5d1a433"))
		draw_rect(Rect2(p+Vector2(12,3),Vector2(28+i*4,1)),Color("f5d1a43c"))
	_hills(168,23,.068,Color("666f59"))
	_hills(186,18,.039,Color("4a6052"))
	_hills(209,17,.057,Color("364b43"))
	for i in range(12):
		var x=300+i*31
		draw_texture_rect(TREE,Rect2(x,163+posmod(i*31,30),35,53),false,Color("516958"))
	draw_rect(Rect2(0,223,640,137),Color("344f4d"))
	for i in range(81):
		var x=posmod(i*187+int(sky_time*(1+i%3)),645)
		var y=227+posmod(i*43,88)
		var tint=Color("edc28b6b") if absf(x-sun.x)<(y-201)*.58 else Color("a7b29c42")
		draw_rect(Rect2(x,y,4+i%16,1),tint)
	_hills(284,10,.052,Color("3c4e3e"))
	draw_line(Vector2(322,304),Vector2(640,297),Color("8f855d"),3)
	draw_line(Vector2(318,309),Vector2(640,302),Color("ad9166"),4)
	draw_texture_rect(TREE,Rect2(289,164,108,154),false,Color("71836b"))
	draw_texture_rect(HOME,Rect2(417,160,153,122),false,Color("e1c2a4"))
	draw_texture_rect(SHOP,Rect2(542,194,102,82),false,Color("c6ad8e"))
	draw_texture_rect(LAMP,Rect2(389,215,35,76),false,Color("ecd1aa"))
	for radius in [22,15,9]:
		draw_circle(Vector2(406,241),radius,Color("f2bf7825"))
	var bob=roundf(sin(sky_time*2)) if animation_enabled else 0
	draw_texture_rect_region(PORTRAIT,Rect2(492,246+bob,43,66),Rect2(5,8,56,86))
	for i in range(12):
		var at=Vector2(332+i*26+roundf(cos(sky_time*.71+i)*7),291+(i*13)%43+roundf(sin(sky_time*.57+i)*6))
		draw_rect(Rect2(at,Vector2(2,2)),Color("edc685"))
	for i in range(32):
		var x=312+posmod(i*83,328)
		var y=318+posmod(i*47,42)
		draw_line(Vector2(x,y),Vector2(x+2,y-3-i%5),Color("879777"),1)
	for x in range(0,408,4):
		var alpha=1.0-smoothstep(198.0,408.0,float(x))
		draw_rect(Rect2(x,0,4,360),Color(.075,.106,.091,alpha*.97))
	draw_rect(Rect2(32,34,23,2),DESIGN.BRASS)

func _hills(height: float, amplitude: float, frequency: float, color: Color):
	for x in range(0,640,4):
		var y=roundf(height+sin(x*frequency)*amplitude*.35+sin(x*frequency*.31)*amplitude)
		draw_rect(Rect2(x,y,4,360-y),color)

func _quiet_victory():
	var t=sky_time/.9
	for i in range(10):
		var x=320+(-1 if i%2 else 1)*(245+sin(i*2.4+t*2.0)*32)
		var y=136+i*13-t*35
		var gold=Color("e4bf8d")
		gold.a=(1-t)*.78
		draw_rect(Rect2(Vector2(x,y).round(),Vector2(2+i%2,2+i%2)),gold)
