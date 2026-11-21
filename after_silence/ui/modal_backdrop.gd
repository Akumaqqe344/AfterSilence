extends Control
const WALK=preload("res://after_silence/assets/pechatai/player/walk.png")
const IDLE=preload("res://after_silence/assets/remaster0290/vera_idle.png")
const DESIGN=preload("res://after_silence/ui/comfort_theme.gd")
const DUSK=preload("res://after_silence/assets/remaster0290/dusk.png")
const LANTERN=preload("res://after_silence/scenes/menu_lantern.tscn")
var lantern: AnimatedSprite2D
var menu_mode=false
var animation_enabled=false
var finish_mark=false
var sky_time=0.0
var frame_budget=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)
	lantern=LANTERN.instantiate()
	lantern.hide()
	add_child(lantern)

func configure_motion(enabled: bool):
	animation_enabled=(menu_mode or finish_mark) and enabled
	if not menu_mode or not animation_enabled: sky_time=0.0
	set_process(animation_enabled)
	lantern.visible=menu_mode
	if menu_mode and animation_enabled: lantern.play()
	else: lantern.stop();lantern.frame=0
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
	draw_texture_rect(DUSK,Rect2(Vector2.ZERO,size),false)
	for i in range(28):
		var x=196+posmod(i*63,191)
		var y=227+posmod(i*17,45)
		var wave=.5+.5*sin(sky_time*.73+i*1.7)
		var offset=roundf(sin(sky_time*.95+i)*4)
		draw_rect(Rect2(x+offset,y,4+i%8,1),Color(.61,.67,.67,.10+wave*.15))
	for i in range(13):
		var x=543+posmod(i*31,94)
		var y=254+posmod(i*13,34)
		var pulse=.5+.5*sin(sky_time*1.25+i)
		draw_rect(Rect2(x,y,5+i%6,1),Color(.87,.61,.42,.12+pulse*.14))
	var warmth=.06+sin(sky_time*1.5)*.012
	for band in range(3):
		var half=17-band*4
		var top=318+band
		var pool=PackedVector2Array([Vector2(419-half,top+5),Vector2(419-half+6,top),Vector2(419+half-4,top),Vector2(419+half,top+5),Vector2(419+half-5,top+8),Vector2(419-half+5,top+8)])
		draw_colored_polygon(pool,Color(.87,.60,.36,warmth))
	_draw_menu_actor()
	for i in range(9):
		var at=Vector2(389+i*28+roundf(cos(sky_time*.51+i)*8),300+(i*13)%39+roundf(sin(sky_time*.71+i)*8))
		var shine=.5+.5*sin(sky_time*1.4+i*2.1)
		draw_rect(Rect2(at,Vector2(1+i%2,1)),Color(.94,.77,.52,.16+shine*.55))
	for x in range(0,380,3):
		var alpha=1.0-smoothstep(155.0,380.0,float(x))
		draw_rect(Rect2(x,0,3,size.y),Color(.059,.091,.098,alpha*.66))
	draw_rect(Rect2(32,34,23,2),DESIGN.BRASS)

func menu_actor_pose(at: float) -> Vector3i:
	if not animation_enabled: return Vector3i(513,0,0)
	var beat=fposmod(at,12.0)
	if beat<3.2:
		var traveled=56.0*smoothstep(0.0,3.2,beat)
		return Vector3i(roundi(457+traveled),3,int(traveled/3.1)%4)
	if beat<6.0: return Vector3i(513,0,0)
	if beat<9.2:
		var stride=beat-6.0
		var traveled=56.0*smoothstep(0.0,3.2,stride)
		return Vector3i(roundi(513-traveled),2,int(traveled/3.1)%4)
	return Vector3i(457,0,0)

func _draw_menu_actor():
	var pose=menu_actor_pose(sky_time)
	var feet=Vector2(pose.x,roundf(319.0-(pose.x-457)*.013))
	var moving=pose.y!=0
	draw_set_transform(feet,0,Vector2(1,.28))
	draw_circle(Vector2.ZERO,11,Color("141b15a0"))
	draw_set_transform(Vector2.ZERO)
	var lift=0 if not moving else pose.z%2
	var idle_frame=0
	if animation_enabled and not moving: idle_frame=mini(5,int(fposmod(sky_time,3.4)*1.77))
	var region=Rect2((Vector2(pose.z,pose.y) if moving else Vector2(idle_frame,0))*Vector2(64,96),Vector2(64,96))
	draw_texture_rect_region(WALK if moving else IDLE,Rect2(feet-Vector2(18,48+lift),Vector2(36,50)),region,Color("ddddca"))

func _quiet_victory():
	var t=sky_time/.9
	for i in range(12):
		var x=320+(-1 if i%2 else 1)*(245+sin(i*2.4+t*2.0)*32)
		var y=136+i*13-t*35
		var gold=Color("e4bf8d")
		gold.a=(1-t)*.78
		draw_rect(Rect2(Vector2(x,y).round(),Vector2(2+i%2,2+i%2)),gold)
