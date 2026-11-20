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
var sky_time=0.0
var frame_budget=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)

func configure_motion(enabled: bool):
	animation_enabled=menu_mode and enabled
	if not animation_enabled: sky_time=0.0
	set_process(animation_enabled)
	queue_redraw()

func _process(dt):
	if not is_visible_in_tree(): return
	sky_time=fmod(sky_time+dt,120.0)
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
	draw_rect(Rect2(10,10,size.x-20,size.y-20),Color("65716f"),false)
	draw_rect(Rect2(10,10,46,2),DESIGN.SAGE)
	draw_rect(Rect2(size.x-56,size.y-12,46,2),DESIGN.PEACH)
	if menu_mode:
		_dusk_postcard()
	else:
		_plant(Vector2(613,331),-1)
	var footer="Take your time · Tab to choose · Enter to open" if english else "Не спеши · Tab — выбрать · Enter — открыть"
	draw_string(get_theme_default_font(),Vector2(28,size.y-20),footer,HORIZONTAL_ALIGNMENT_LEFT,580,6,DESIGN.MUTED)

func _dusk_postcard():
	var frame=Rect2(372,25,248,295)
	draw_style_box(DESIGN.panel(Color("362f49"),true),frame)
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
	_plant(Vector2(589,267),-1)
	var bob=roundf(sin(sky_time*2.4)) if animation_enabled else 0
	draw_rect(Rect2(484,281,48,5),Color("222d3b"))
	draw_texture_rect_region(PORTRAIT,Rect2(481,201+bob,54,83),Rect2(5,8,56,86))
	for i in range(9):
		var at=Vector2(roundf(390+i*25+cos(sky_time*.63+i*2)*10),roundf(229+(i*13)%35+sin(sky_time*.84+i)*7))
		draw_rect(Rect2(at-Vector2.ONE,Vector2(4,4)),Color("dcb98346"))
		draw_rect(Rect2(at,Vector2(2,2)),Color("f0d29d"))
	draw_rect(Rect2(378,294,236,20),Color("282737"))
	var caption="A little light stays with you" if english else "Маленький свет всегда рядом"
	draw_string(get_theme_default_font(),Vector2(388,307),caption,HORIZONTAL_ALIGNMENT_LEFT,219,7,DESIGN.TEXT)
