extends Node2D
var zone="town"
var echo=false
var anchor: Node2D
var age=0.0
var game
var motes=[]
var lamps=[]
var changing=false
var light_age=0.0
const Water=preload("res://after_silence/world/watercourse.gd")
func _ready():
	z_index=20
	for node in get_parent().get_children():
		if node is PointLight2D: lamps.append({"node":node,"base":node.energy})
func _process(dt):
	if game==null or game.comfort.reduce_motion or game.modal or game.in_menu or game.event_window.active:
		if not motes.is_empty(): motes.clear()
		if changing:
			for lamp in lamps: lamp.node.energy=lamp.base
			changing=false
		queue_redraw()
		return
	changing=true
	age+=dt
	if is_instance_valid(anchor): position=anchor.position
	light_age+=dt
	if light_age>.07:
		light_age=0
		for lamp in lamps:
			var at: Vector2=lamp.node.position
			if at.distance_squared_to(position)<480000:
				lamp.node.energy=lamp.base*(1.0+sin(age*.94+at.x*.016)*.055)
			else: lamp.node.energy=lamp.base
	for mote in motes: mote.age+=dt
	while not motes.is_empty() and motes[0].age>.35: motes.pop_front()
	queue_redraw()

func footstep(running: bool):
	if game==null or game.comfort.reduce_motion or not is_instance_valid(anchor) or anchor.elevation>2: return
	if zone not in ["town","forest","orchard","harbor"]: return
	for i in range(4 if running else 2):
		var offset=Vector2(-7+i*4,2+i%2*2)
		motes.append({"start":anchor.position+offset,"velocity":Vector2(-16+i*9,-12-i%2*9),"age":0.0})
	while motes.size()>28: motes.pop_front()

func landing():
	if game==null or game.comfort.reduce_motion or not is_instance_valid(anchor): return
	for i in range(7):
		var spread=Vector2.from_angle(i*TAU/7)
		motes.append({"start":anchor.position+spread*4,"velocity":spread*23+Vector2(0,-11),"age":0.0})
	while motes.size()>28: motes.pop_front()

func _draw():
	if game==null or game.comfort.reduce_motion or game.modal or game.in_menu or game.event_window.active: return
	var count=34 if zone=="forest" else 16
	for i in range(count):
		var speed=110.0 if zone=="forest" else 7.0
		var p=Vector2(fposmod(i*97.0-age*speed*.2,720)-360,fposmod(i*71.0+age*speed,440)-220)
		if zone=="forest": draw_line(p,p+Vector2(-2,7),Color(.62,.76,.8,.13 if not echo else .22))
		else: draw_rect(Rect2(p.round(),Vector2(1,1)),Color("dfceb64e"))
	if zone in ["town","harbor","orchard"]:
		for i in range(22):
			var cell=(position/32).floor()*32
			var anchor_at=cell+Vector2(posmod(i*67,580)-290,posmod(i*41,300)-150)
			var world=anchor_at+Vector2(roundf(sin(i+age*.72)*7),0)
			if Water.depth(zone,world)<8: continue
			var glint=(world-position).round()
			draw_rect(Rect2(glint,Vector2(5+i%8,1)),Color("a9e1d964"))
			if i%4==0: draw_rect(Rect2(glint+Vector2(2,3),Vector2(4,1)),Color("b3e3e23a"))
	for mote in motes:
		var at=(mote.start-position+mote.velocity*mote.age).round()
		draw_rect(Rect2(at,Vector2(3,2)),Color(.72,.61,.48,(1.0-mote.age/.35)*.7))
	if zone in ["orchard","town","harbor"]:
		var dusk=game.state.clock<7 or game.state.clock>=19
		var drift=7 if dusk else 5 if zone=="orchard" else 0
		for i in range(drift):
			var offset=Vector2(fposmod(i*163.0+age*3.4,680)-340,fposmod(i*83+age*(2+i%4),410)-205)
			offset+=Vector2(roundf(sin(age*.56+i*2.5)*21),roundf(cos(age*.64+i)*8))
			var tint=Color("f6d88c99") if dusk else Color("efcbb48e")
			draw_rect(Rect2(offset.round(),Vector2(2,2) if dusk else Vector2(3,1)),tint)
	if echo:
		for i in range(4): draw_rect(Rect2(-360,-180+i*100+sin(age*.15+i)*25,720,12),Color(.4,.5,.65,.025))
