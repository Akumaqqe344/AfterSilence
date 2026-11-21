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
var draw_age=0.0
const DRAW_INTERVAL=1.0/30.0
const Water=preload("res://after_silence/world/watercourse.gd")
const Art=preload("res://after_silence/core/ppae_art.gd")
var scenery_age:=0.0
var exterior:=false
var tint_hour:=-1
func _ready():
	z_index=20
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	exterior=zone in ["town","forest","orchard","harbor"]
	for node in get_parent().get_children():
		if node is PointLight2D: lamps.append({"node":node,"base":node.energy})
func _process(dt):
	_update_scenery(dt)
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
				lamp.node.energy=snappedf(lamp.base*(1.0+sin(age*.94+at.x*.016)*.048),.008)
			else: lamp.node.energy=lamp.base
	for mote in motes: mote.age+=dt
	while not motes.is_empty() and motes[0].age>.384: motes.pop_front()
	draw_age+=dt
	if draw_age>=DRAW_INTERVAL:
		draw_age=fmod(draw_age,DRAW_INTERVAL)
		queue_redraw()

func _update_scenery(dt: float) -> void:
	if game==null or not is_instance_valid(anchor): return
	scenery_age+=dt
	if scenery_age<.16: return
	scenery_age=0.0
	var environment=get_parent()
	var hour:=floori(game.state.clock)
	var profile:=Art.sun(hour)
	if profile.is_empty(): return
	if tint_hour!=hour:
		tint_hour=hour
		var tone:=Color(profile.ambient.ambientColorHex)
		var base: Color=game.ComfortTheme.world_light(zone,hour>=20 or hour<7,echo)
		environment.modulate=base.lerp(tone,.32 if exterior else .12)
		for facade in environment.facades:
			facade.window_light=.76 if hour>=19 or hour<7 else 0.0
			facade.queue_redraw()
	if not exterior: return
	var solar: Dictionary=profile.shadow
	var shadow:=Vector3(float(solar.dirX)*21.0*float(solar.lengthMultiplier),float(solar.dirY)*21.0*float(solar.lengthMultiplier),float(solar.shadowAlpha)/420.0)
	for prop in environment.scenery:
		if anchor.position.distance_squared_to(prop.position)>360000.0: continue
		var pose:=1 if game.comfort.reduce_motion or game.modal or game.in_menu else Art.wind(prop.position,age)
		prop.sway(pose,shadow)

func footstep(running: bool):
	if game==null or game.comfort.reduce_motion or not is_instance_valid(anchor) or anchor.elevation>2: return
	if zone not in ["town","forest","orchard","harbor"]: return
	motes.append({"start":anchor.position,"kind":"step","zoom":.9 if running else .65,"age":0.0})
	while motes.size()>8: motes.pop_front()

func landing():
	if game==null or game.comfort.reduce_motion or not is_instance_valid(anchor): return
	motes.append({"start":anchor.position,"kind":"land","zoom":.85,"age":0.0})
	while motes.size()>8: motes.pop_front()

func _draw():
	if game==null or game.comfort.reduce_motion or game.modal or game.in_menu or game.event_window.active: return
	if zone=="forest": _weather("forest",.46 if echo else .32)
	if echo and exterior: _weather("echo",.43)
	var count=0 if not exterior or zone=="forest" else 12
	for i in range(count):
		var speed=7.0
		var p=Vector2(fposmod(i*97.0-age*speed*.2,720)-360,fposmod(i*71.0+age*speed,440)-220)
		draw_rect(Rect2(p.round(),Vector2(1,1)),Color("dfceb64e"))
	if zone in ["town","harbor"]: _water_glints()
	for mote in motes:
		Art.effect(self,mote.kind,mote.start-position,mote.age,mote.zoom,Color("d0b7949f"))
	if zone in ["orchard","town","harbor"]:
		var dusk=game.state.clock<7 or game.state.clock>=19
		var drift=7 if dusk else 5 if zone=="orchard" else 0
		for i in range(drift):
			var offset=Vector2(fposmod(i*163.0+age*3.4,680)-340,fposmod(i*83+age*(2+i%4),410)-205)
			offset+=Vector2(roundf(sin(age*.56+i*2.5)*21),roundf(cos(age*.64+i)*8))
			var tint=Color("f6d88c99") if dusk else Color("efcbb48e")
			Art.effect(self,"mote",offset,fposmod(age+i*.1,.384),.46,tint)
	if not exterior:
		for lamp in lamps:
			var from_light: Vector2=lamp.node.position-position
			if from_light.length_squared()<100000.0:
				Art.effect(self,"ember",from_light,fposmod(age*.71,.384),.38,Color("dab38b64"))

func _weather(id: String, opacity: float) -> void:
	var frame:=posmod(floori(age*8.0),4)
	var offset:=Vector2(roundf(sin(age*.46)*9.0),roundf(fposmod(age*22.0,20.0)))
	draw_texture_rect_region(Art.texture("weather_"+id),Rect2(Vector2(-387,-241)+offset,Vector2(774,482)),Rect2(frame*320,0,320,180),Color(1,1,1,opacity))

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
