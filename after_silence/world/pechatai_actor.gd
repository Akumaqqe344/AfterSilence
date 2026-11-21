extends CharacterBody2D
signal footstep(loud: bool)
signal landed
# Pechatai character.js: 180 / 1.65 / 1300 / 1600, normalized eight-way input.
const VERA_IDLE=preload("res://after_silence/assets/remaster0290/vera_idle.png")
const Appearance=preload("res://after_silence/core/npc_appearance.gd")
const SPEED=180.0
const ACCEL=1300.0
const DECEL=1600.0
const STRIDE_CONTACT=64.0
var is_player=false
var enabled=true
var running=false
var facing=0
var diagonal=-1
var phase=0.0
var inspect_time=0.0
var target=Vector2.ZERO
var sheet: Texture2D
var sprite: Sprite2D
var npc_color=Color.WHITE
var scripted=false
var jump_age=1.0
var jump_duration=.44
var jump_peak=28.0
var elevation=0.0
var clips: Dictionary={}
var npc_speed=30.0
var body_height=52.0
var managed_motion=false
var managed_velocity=Vector2.ZERO
var npc_anchor=Vector2(32,92)
var portrait=Rect2(8,0,48,48)
var visual_comfort
var animated_idle=false
var idle_clock=0.0
var vera_idle_age=0.0
var settle_age=0.0
var sprite_step=0.0
var last_shadow_height=-1.0
var last_inspected=false
func _ready():
	collision_layer=2 if is_player else 4
	collision_mask=1
	var collision=CollisionShape2D.new()
	var shape=CapsuleShape2D.new()
	shape.radius=5
	shape.height=12
	collision.shape=shape
	collision.position.y=-3
	add_child(collision)
	sprite=Sprite2D.new()
	sprite.texture=sheet
	sprite.material=preload("res://after_silence/world/surface_textures.gd").material("character",0 if is_player else int(sheet.resource_path.hash()))
	sprite.region_enabled=true
	sprite.centered=false
	sprite.scale=Vector2(.7,.7)
	sprite.modulate=npc_color
	add_child(sprite)
	if not is_player:
		var bounds=sheet.get_image().get_region(Rect2i(0,0,64,96)).get_used_rect()
		var scale_factor=body_height/maxf(1,bounds.size.y)
		sprite.scale=Vector2.ONE*scale_factor
		npc_anchor=Vector2(bounds.position.x+bounds.size.x*.5,bounds.end.y)
		portrait=Rect2(bounds.position,Vector2(bounds.size.x,bounds.size.y*.52))
	if is_player:
		for id in ["walk","run","diagonal-run","jump","jump-diagonal"]: clips[id]=load("res://after_silence/assets/pechatai/player/"+id+".png")
func set_appearance(texture: Texture2D, height: float):
	sheet=texture;body_height=height
	if not is_instance_valid(sprite): return
	sprite.texture=sheet
	var bounds=sheet.get_image().get_region(Rect2i(0,0,64,96)).get_used_rect()
	sprite.scale=Vector2.ONE*body_height/maxf(1,bounds.size.y)
	npc_anchor=Vector2(bounds.position.x+bounds.size.x*.5,bounds.end.y)
	portrait=Rect2(bounds.position,Vector2(bounds.size.x,bounds.size.y*.52))
func jump(long_jump: bool=false) -> bool:
	if not enabled or scripted or jump_age<jump_duration: return false
	jump_duration=.68 if long_jump else .44
	jump_peak=52.0 if long_jump else 28.0
	jump_age=0
	return true
func _physics_process(dt):
	dt=minf(dt,.05)
	var direction=Vector2.ZERO
	if scripted:
		if position.distance_to(target)>3: direction=position.direction_to(target)
	elif enabled:
		if is_player:
			direction=Input.get_vector("as_left","as_right","as_up","as_down")
			if has_meta("click_route"):
				var route: PackedVector2Array=get_meta("click_route")
				if direction!=Vector2.ZERO: route.clear()
				while route.size()>0 and position.distance_to(route[0])<6: route.remove_at(0)
				if route.size()>0: direction=position.direction_to(route[0])
				set_meta("click_route",route)
			running=Input.is_physical_key_pressed(KEY_SHIFT)
		elif position.distance_to(target)>3: direction=position.direction_to(target)
	var speed=SPEED*(1.65 if running else 1.0) if is_player else npc_speed
	if not enabled and not scripted: velocity=Vector2.ZERO
	elif is_player and not scripted:
		var acceleration=(ACCEL if direction!=Vector2.ZERO else DECEL)*dt
		velocity.x=move_toward(velocity.x,direction.x*speed,acceleration)
		velocity.y=move_toward(velocity.y,direction.y*speed,acceleration)
	else: velocity=direction*(92.0 if scripted and is_player else speed)
	if not managed_motion: move_and_slide()
	var motion=managed_velocity if managed_motion else get_real_velocity()
	var moving=motion.length()>4
	if moving:
		var horizontal=absf(motion.x)
		var vertical=absf(motion.y)
		var use_row=facing>=2
		if horizontal>vertical*1.15: use_row=true
		elif vertical>horizontal*1.15: use_row=false
		facing=(3 if motion.x>0 else 2) if use_row else (0 if motion.y>0 else 1)
		diagonal=[2,3,0,1][(0 if motion.x<0 else 1)+(0 if motion.y<0 else 2)] if minf(horizontal,vertical)>maxf(horizontal,vertical)*.28 else -1
		if is_player and jump_age>=jump_duration:
			var previous=int(phase/2.0)
			var next=phase+2.0*motion.length()*dt/STRIDE_CONTACT
			phase=fposmod(next,4.0)
			if int(next/2.0)!=previous: footstep.emit(running)
		elif not is_player:
			phase=fposmod(phase+dt*6.0,4.0)
	var in_air=jump_age<jump_duration
	if enabled or scripted: jump_age=minf(jump_duration,jump_age+dt)
	if is_player and in_air and jump_age>=jump_duration:
		settle_age=.18
		landed.emit()
	settle_age=maxf(0,settle_age-dt)
	var p=jump_age/jump_duration
	elevation=4*p*(1-p)*jump_peak if p<1 else 0.0
	inspect_time=maxf(0,inspect_time-dt)
	var frame=int(phase)%4 if moving else 0
	if animated_idle and not moving:
		if visual_comfort!=null and not visual_comfort.reduce_motion:
			idle_clock=fposmod(idle_clock+dt,12.0)
		frame=idle_frame()
	var row=facing
	var size=Vector2(64,96)
	var anchor=Vector2(32,92)
	if is_player:
		var clip="run" if running else "walk"
		if diagonal>=0 and running: clip="diagonal-run";row=diagonal
		if not moving:
			clip="idle"
			row=4+diagonal if diagonal>=0 else facing
			if visual_comfort!=null and not visual_comfort.reduce_motion:
				vera_idle_age=fposmod(vera_idle_age+dt,4.0)
				frame=5 if vera_idle_age>3.82 else [0,1,2,3,4,3,2,1][int(vera_idle_age*2.5)%8]
			else: frame=0
		else: vera_idle_age=0.0
		if p<1:
			clip="jump-diagonal" if diagonal>=0 else "jump"
			row=diagonal if diagonal>=0 else facing
			frame=0 if p<.12 else 1 if p<.25 else (3 if jump_peak>28 else 2) if p<.76 else 4 if p<.94 else 5
			size=Vector2(96,112)
			anchor=Vector2(48,108)
		sprite.texture=VERA_IDLE if clip=="idle" else clips[clip]
	sprite.region_rect=Rect2(Vector2(frame,row)*size,size)
	sprite.position=(-anchor*.7-Vector2(0,elevation)) if is_player else -npc_anchor*sprite.scale
	if animated_idle and not moving and visual_comfort!=null and not visual_comfort.reduce_motion:
		sprite.position.y-=roundf(.7*sin(idle_clock*1.8))
	if is_player:
		var show_motion=visual_comfort!=null and not visual_comfort.reduce_motion
		var lean=clampf(motion.x/(320 if running else 250)*.047,-.047,.047) if show_motion else 0.0
		sprite.skew=lerpf(sprite.skew,lean,minf(1,dt*13))
		var lift=sin(phase*PI)*1.3 if moving and p>=1 and show_motion else 0.0
		sprite_step=lerpf(sprite_step,lift,minf(1,dt*16))
		if show_motion: sprite.position.y-=roundf(sprite_step-settle_age*7)
	if not is_equal_approx(elevation,last_shadow_height) or last_inspected!=(inspect_time>0):
		last_shadow_height=elevation
		last_inspected=inspect_time>0
		queue_redraw()
func idle_frame() -> int:
	if visual_comfort==null or visual_comfort.reduce_motion: return Appearance.REST_FRAME
	if fposmod(idle_clock,4.0)>3.84: return Appearance.BLINK_FRAME
	var beat=fposmod(idle_clock*(1.08 if body_height<35 else .83),2.4)
	return 6 if beat>.55 and beat<1.1 else 7 if beat>=1.1 and beat<1.6 else Appearance.REST_FRAME

func _draw():
	var shrink=maxf(.4,1-elevation/28*.45)
	draw_set_transform(Vector2.ZERO,0,Vector2(shrink,shrink*.32))
	draw_circle(Vector2.ZERO,10,Color(.06,.1,.11,maxf(.12,.33-elevation/28*.13)))
	draw_set_transform(Vector2.ZERO)
	if inspect_time>0: draw_rect(Rect2(12,-30-elevation,8,10),Color("e3c98e"))
