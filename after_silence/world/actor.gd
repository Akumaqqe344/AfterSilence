extends CharacterBody2D
signal footstep(loud: bool)
var is_player = false
var enabled = true
var running = false
var facing = 0
var phase = 0.0
var idle_time = 0.0
var inspect_time = 0.0
var target = Vector2.ZERO
var sprite: Sprite2D
var sheet: Texture2D
var npc_color = Color.WHITE
var step_time = 0.0
var scripted=false
func _ready():
	collision_layer = 2 if is_player else 4
	collision_mask = 1
	var shape = CollisionShape2D.new()
	var capsule = CapsuleShape2D.new()
	capsule.radius = 5
	capsule.height = 12
	shape.shape = capsule
	shape.position.y = -3
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = sheet
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.centered = false
	sprite.modulate = npc_color
	add_child(sprite)
func _physics_process(dt):
	var direction = Vector2.ZERO
	if scripted:
		if position.distance_to(target)>3: direction=position.direction_to(target)
	elif enabled:
		if is_player:
			direction = Input.get_vector("as_left","as_right","as_up","as_down")
			running = Input.is_physical_key_pressed(KEY_SHIFT)
		elif position.distance_to(target) > 3:
			direction = position.direction_to(target)
	velocity = direction * (142 if running and is_player else 92 if is_player else 26)
	move_and_slide()
	if direction.length() > 0:
		if absf(direction.x) > absf(direction.y): facing = 3 if direction.x > 0 else 2
		else: facing = 0 if direction.y > 0 else 1
		phase += dt * (10 if running else 6)
		idle_time = 0
		step_time += dt
		if is_player and step_time > (0.25 if running else 0.42):
			step_time = 0
			footstep.emit(running)
	else: idle_time += dt
	inspect_time = maxf(0, inspect_time-dt)
	if sheet:
		if is_player:
			var frame = int(phase)%4 if direction.length()>0 else 0
			sprite.region_rect = Rect2(frame*32,facing*48,32,48)
			sprite.position = Vector2(-16,-45 + (1 if idle_time>1.2 and sin(idle_time*2)>0.7 else 0))
		else:
			var frames = maxi(1,int(sheet.get_width()/32))
			sprite.region_rect = Rect2((int(phase)%mini(frames,4) if direction.length()>0 else 0)*32,0,32,48)
			sprite.position = Vector2(-16,-45+(1 if idle_time>1.2 and sin(idle_time*2)>0.7 else 0))
	queue_redraw()
func _draw():
	draw_ellipse_shadow()
	if inspect_time > 0:
		draw_rect(Rect2(9,-24,8,10),Color("e3c98e"))
		draw_line(Vector2(10,-20),Vector2(16,-20),Color("695c5d"))
func draw_ellipse_shadow():
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.32))
	draw_circle(Vector2.ZERO,9,Color(0.06,0.10,0.11,0.35))
	draw_set_transform(Vector2.ZERO)
