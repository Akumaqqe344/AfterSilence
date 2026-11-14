extends CharacterBody2D
signal caught
var world
var player
var active = false
var behavior = "patrol"
var last_seen = Vector2.ZERO
var direction = Vector2.DOWN
var route = PackedVector2Array()
var route_time = 0.0
var lost_time = 0.0
var age = 0.0
var pressure = 0
var sanctuary = Vector2(990,520)
func _ready():
	collision_layer=8
	collision_mask=1
	var collision=CollisionShape2D.new()
	var shape=CircleShape2D.new()
	shape.radius=6
	collision.shape=shape
	add_child(collision)
func hear(p: Vector2,loud: bool):
	if active and position.distance_to(p)<(235 if loud else 80):
		last_seen=p
		behavior="investigate"
		lost_time=0
func _physics_process(dt):
	if not active or not is_instance_valid(player) or not is_instance_valid(world): return
	age+=dt
	var delta=player.position-position
	var hidden=player.position.distance_to(sanctuary)<58
	var visible=not hidden and delta.length()<250+pressure*12 and direction.dot(delta.normalized())>0.1 and world.sees(position,player.position)
	if visible:
		last_seen=player.position
		lost_time=0
		behavior="chase"
	else:
		lost_time+=dt
		if lost_time>5: behavior="search"
		if lost_time>11: behavior="patrol"
	var goal=last_seen
	if behavior=="patrol": goal=Vector2(720+sin(age*.12)*180,450+cos(age*.12)*140)
	elif behavior=="search": goal=last_seen+Vector2.from_angle(age*.8)*65
	if hidden and position.distance_to(sanctuary)<85: goal=Vector2(840,400)
	route_time-=dt
	if route_time<=0:
		route=world.path_between(position,goal)
		route_time=.35
	while route.size()>0 and position.distance_to(route[0])<8: route.remove_at(0)
	velocity=Vector2.ZERO
	if route.size()>0:
		direction=position.direction_to(route[0])
		velocity=direction*(90+pressure*3 if behavior=="chase" else 62)
	move_and_slide()
	if not hidden and position.distance_to(player.position)<14:
		active=false
		caught.emit()
	queue_redraw()
func _draw():
	draw_circle(Vector2(0,-13),15,Color(0.14,0.13,0.22,.35))
	draw_colored_polygon(PackedVector2Array([Vector2(-10,0),Vector2(-8,-26),Vector2(0,-36),Vector2(8,-26),Vector2(10,0)]),Color("252b3d"))
	draw_rect(Rect2(-6,-25,3,2),Color("ced8bf"))
	draw_rect(Rect2(3,-25,3,2),Color("ced8bf"))
