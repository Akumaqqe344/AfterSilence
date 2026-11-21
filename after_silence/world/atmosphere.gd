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
	if zone in ["town","harbor"]: _water_glints()
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

func _water_glints():
	var cell=(position/54).floor()
	for row in range(-4,5):
		for column in range(-6,7):
			var seed_point=Vector2i(cell)+Vector2i(column,row)
			var seed_value=posmod((seed_point.x*73856093)^(seed_point.y*19349663),997)
			var phase=fposmod(age*.42+seed_value*.049,1.0)
			var at=Vector2(seed_point)*54+Vector2(seed_value%49,(seed_value*19)%50)
			var length=6+seed_value%10
			at.x+=roundf(phase*11)
			var tip=at+Vector2(length,0)
			if not Water.blocked(zone,at) or not Water.blocked(zone,tip): continue
			if minf(Water.depth(zone,at),Water.depth(zone,tip))<9: continue
			var p=(at-position).round()
			var alpha=sin(phase*PI)*.48
			draw_rect(Rect2(p,Vector2(length,1)),Color(.78,.86,.73,alpha))
			draw_rect(Rect2(p+Vector2(3,2),Vector2(length*.45,1)),Color(.76,.86,.79,alpha*.46))
