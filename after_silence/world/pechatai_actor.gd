extends CharacterBody2D
signal footstep(loud: bool)
signal landed
# Pechatai character.js: 180 / 1.65 / 1300 / 1600, normalized eight-way input.
const SPEED=180.0
const ACCEL=1300.0
const DECEL=1600.0
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
var step_time=0.0
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
var settle_age=0.0
var sprite_step=0.0
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
		for id in ["walk","run","idle","diagonal-run","jump","jump-diagonal"]: clips[id]=load("res://after_silence/assets/pechatai/player/"+id+".png")
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
		facing=(3 if motion.x>0 else 2) if absf(motion.x)>absf(motion.y) else (0 if motion.y>0 else 1)
		diagonal=([2,3,0,1][(0 if motion.x<0 else 1)+(0 if motion.y<0 else 2)] if absf(motion.x)>4 and absf(motion.y)>4 else -1)
		phase+=dt*(12 if running else 8)*minf(1.5,motion.length()/(297 if running else 180)) if is_player else dt*6
		step_time+=dt
		if is_player and step_time>(.25 if running else .42): step_time=0;footstep.emit(running)
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
	var row=facing
	var size=Vector2(64,96)
	var anchor=Vector2(32,92)
	if is_player:
		var clip="run" if running else "walk"
		if diagonal>=0: clip="diagonal-run";row=diagonal
		if not moving:
			clip="idle"
			var index=4+diagonal if diagonal>=0 else facing
			frame=index%4
			row=int(index/4)
		if p<1:
			clip="jump-diagonal" if diagonal>=0 else "jump"
			row=diagonal if diagonal>=0 else facing
			frame=0 if p<.12 else 1 if p<.25 else (3 if jump_peak>28 else 2) if p<.76 else 4 if p<.94 else 5
			size=Vector2(96,112)
			anchor=Vector2(48,108)
		sprite.texture=clips[clip]
	sprite.region_rect=Rect2(Vector2(frame,row)*size,size)
	sprite.position=(-anchor*.7-Vector2(0,elevation)) if is_player else -npc_anchor*sprite.scale
	if is_player:
		var show_motion=visual_comfort!=null and not visual_comfort.reduce_motion
		var lean=clampf(motion.x/(320 if running else 250)*.047,-.047,.047) if show_motion else 0.0
		sprite.skew=lerpf(sprite.skew,lean,minf(1,dt*13))
		var lift=sin(phase*PI)*1.3 if moving and p>=1 and show_motion else 0.0
		sprite_step=lerpf(sprite_step,lift,minf(1,dt*16))
		if show_motion: sprite.position.y-=roundf(sprite_step-settle_age*7)
	queue_redraw()
func _draw():
	var shrink=maxf(.4,1-elevation/28*.45)
	draw_set_transform(Vector2.ZERO,0,Vector2(shrink,shrink*.32))
	draw_circle(Vector2.ZERO,10,Color(.06,.1,.11,maxf(.12,.33-elevation/28*.13)))
	draw_set_transform(Vector2.ZERO)
	if inspect_time>0: draw_rect(Rect2(12,-30-elevation,8,10),Color("e3c98e"))
