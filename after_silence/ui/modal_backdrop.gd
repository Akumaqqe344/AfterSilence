extends Control
const PORTRAIT=preload("res://after_silence/assets/pechatai/player/idle.png")
const DESIGN=preload("res://after_silence/ui/comfort_theme.gd")
const HOME=preload("res://after_silence/assets/art100/house-1.png")
const SHOP=preload("res://after_silence/assets/art120/shop_front.png")
const TREE=preload("res://after_silence/assets/art100/tree-2.png")
const LAMP=preload("res://after_silence/assets/props091/way_lamp.png")
var menu_mode=false
var english=false
var journey_mode=false
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
	if menu_mode: _panorama()
	else: _dialog_backdrop()
	draw_rect(Rect2(10,10,size.x-20,size.y-20),Color("82989787"),false)
	for corner in [Vector2(10,10),Vector2(size.x-56,size.y-12)]:
		draw_rect(Rect2(corner,Vector2(46,2)),DESIGN.BRASS)
	if menu_mode:
		_dusk_postcard()
	if finish_mark and animation_enabled and sky_time<.9: _quiet_victory()
	var footer="Take your time · Tab to choose · Enter to open" if english else "Не спеши · Tab — выбрать · Enter — открыть"
	draw_string(get_theme_default_font(),Vector2(28,size.y-20),footer,HORIZONTAL_ALIGNMENT_LEFT,580,6,DESIGN.MUTED)

func _panorama():
	for y in range(0,360,12):
		var tint=Color("26354a").lerp(Color("52605c"),float(y)/360.0)
		draw_rect(Rect2(0,y,640,12),tint)
	for i in range(20):
		var x=posmod(i*47+int(sky_time*2),623)
		var y=50+posmod(i*29,118)
		draw_rect(Rect2(x,y,mini(19+i%11,640-x),1),Color("b0a3ab49"))
	for i in range(48):
		var height=225+roundi(sin(float(i)*.19)*31)+posmod(i*53,27)
		var x=i*14
		draw_rect(Rect2(x,height,14,360-height),Color("354b52"))
	for i in range(8):
		var x=9+i*81
		draw_texture_rect(TREE,Rect2(x,179+posmod(i*57,57),85,122),false,Color("465c667f"))
	for i in range(10):
		var x=13+i*34
		draw_rect(Rect2(x,0,34,360),Color(.085,.13,.18,lerpf(.66,.18,i/9.0)))
	draw_rect(Rect2(0,320,640,40),Color("1626309c"))

func _dialog_backdrop():
	for y in range(0,360,16):
		draw_rect(Rect2(0,y,640,16),Color("1d3039").lerp(Color("304047"),float(y)/360.0))
	for x in [19,611]:
		draw_rect(Rect2(x,43,2,269),Color("74958e4b"))
		for i in range(5):
			var at=Vector2(x+1,50+i*51)
			draw_colored_polygon(PackedVector2Array([at+Vector2(0,-3),at+Vector2(3,0),at+Vector2(0,3),at-Vector2(3,0)]),Color("9ab3a177"))
	_plant(Vector2(613,331),-1)

func _quiet_victory():
	var t=sky_time/.9
	for i in range(14):
		var side=1 if i%2==0 else -1
		var x=320+side*(237+sin(i*2.4+t*2.0)*16)
		var y=113+i*10-t*45
		var gold=Color("e4bf8d")
		gold.a=(1-t)*.78
		draw_rect(Rect2(Vector2(x,y).round(),Vector2(2+i%2,2+i%2)),gold)

func _dusk_postcard():
	var frame=Rect2(364,17,264,311)
	draw_style_box(DESIGN.panel(Color("304752"),true),frame)
	draw_rect(Rect2(369,22,254,301),Color("101f2d94"))
	for x in [370,618]:
		for y in [24,318]:
			draw_rect(Rect2(x,y,5,3),Color("d0ac83"))
	for band in range(15):
		var amount=band/14.0
		draw_rect(Rect2(378,31+band*9,236,9),Color("292a46").lerp(Color("8e6068"),amount))
		for x in range(382+band%2*5,610,11):
			if (x+band*17)%7<3: draw_rect(Rect2(x,38+band*9,2,1),Color(1,.84,.64,.13))
	draw_circle(Vector2(548,79),30,Color("c6967a36"))
	draw_circle(Vector2(548,79),24,Color("edc89665"))
	draw_circle(Vector2(548,79),18,Color("f2d5a4"))
	draw_rect(Rect2(537,72,12,2),Color("dcb891"))
	draw_rect(Rect2(549,86,10,2),Color("dcb891"))
	for i in range(16):
		var at=Vector2(389+posmod(i*43,215),43+posmod(i*23,60))
		if at.distance_to(Vector2(548,79))<33: continue
		if i%5==0: _star(at,Color("a9a6bf"))
		else: draw_rect(Rect2(at,Vector2(1,1)),Color("d4b9ae"))
	for i in range(6):
		var x=roundf(393+posmod(i*47+int(sky_time*(2+i%2)),185))
		var y=100+i%3*11
		draw_rect(Rect2(x,y,25,2),Color("ad92987d"))
		draw_rect(Rect2(x+9,y+3,14,1),Color("f0bca158"))
	for i in range(29):
		var height=143+roundi(sin(i*.32)*7)+posmod(i*19,11)
		draw_rect(Rect2(378+i*8,height,8,197-height),Color("42405a"))
	draw_rect(Rect2(378,162,236,132),Color("334a55"))
	draw_texture_rect(TREE,Rect2(378,124,68,87),false,Color("7e9b9c"))
	draw_texture_rect(HOME,Rect2(410,128,103,84),false,Color("c7ae9b"))
	draw_texture_rect(SHOP,Rect2(523,152,70,56),false,Color("a7aaa8"))
	draw_texture_rect(TREE,Rect2(566,126,46,80),false,Color("809da2"))
	draw_rect(Rect2(378,206,236,61),Color("314756"))
	for i in range(29):
		var x=382+posmod(i*27+int(sky_time*(2+i%3)),222)
		var y=210+posmod(i*17,55)
		var tint=Color("b1b9b24f") if x<500 else Color("d6b39163")
		draw_rect(Rect2(x,y,mini(3+i%9,614-x),1),tint)
	draw_rect(Rect2(378,266,236,28),Color("394b4d"))
	draw_rect(Rect2(378,266,236,2),Color("b49474"))
	draw_texture_rect(LAMP,Rect2(395,191,41,78),false,Color("dbc5a6"))
	var glow_at=Vector2(423,226)
	for i in range(4):
		var strength=.055+sin(sky_time*1.3)*.009
		draw_circle(glow_at,22-i*4,Color(.91,.68,.35,strength))
	_plant(Vector2(589,267),-1)
	var bob=roundf(sin(sky_time*2.4)) if animation_enabled else 0
	draw_rect(Rect2(484,281,48,5),Color("222d3b"))
	draw_texture_rect_region(PORTRAIT,Rect2(481,201+bob,54,83),Rect2(5,8,56,86))
	for i in range(9):
		var at=Vector2(roundf(390+i*25+cos(sky_time*.63+i*2)*10),roundf(229+(i*13)%35+sin(sky_time*.84+i)*7))
		draw_rect(Rect2(at-Vector2.ONE,Vector2(4,4)),Color("dcb98346"))
		draw_rect(Rect2(at,Vector2(2,2)),Color("f0d29d"))
	draw_rect(Rect2(378,294,236,20),Color("282737"))
	var caption="A light in the town" if english else "Огонёк в городе"
	draw_string(get_theme_default_font(),Vector2(388,307),caption,HORIZONTAL_ALIGNMENT_LEFT,219,7,DESIGN.TEXT)
