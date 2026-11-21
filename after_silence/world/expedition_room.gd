extends Node2D
## A local room owns its scenery and collisions. InvestigationDirector owns progress.
## Environmental layers use the same scene-specific approach as NinjaAdventure's EnvironmentArea.
@export var backdrop: Texture2D

const SHEET = preload("res://after_silence/assets/expeditions0330/motion.png")
const LEAF_PATH = "res://after_silence/assets/expeditions0330/ninja_leaf.png"
const ROOM_WALLS = [
	Rect2(0, 0, 640, 88), Rect2(0, 88, 64, 392), Rect2(576, 88, 64, 392),
	Rect2(64, 431, 512, 49)
]
const FIXTURES = {
	"closed_post": [Rect2(110, 135, 102, 33), Rect2(422, 137, 114, 39), Rect2(242, 217, 156, 34), Rect2(94, 269, 74, 25), Rect2(464, 276, 70, 26)],
	"signal_cellar": [Rect2(108, 159, 98, 28), Rect2(438, 159, 96, 28), Rect2(228, 205, 182, 27), Rect2(182, 328, 80, 23), Rect2(366, 328, 80, 23)],
	"listening_archive": [Rect2(96, 132, 116, 34), Rect2(428, 132, 114, 34), Rect2(246, 226, 146, 26), Rect2(96, 279, 88, 21), Rect2(458, 279, 86, 21)]
}
var reduced = false

func mount(world):
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -1
	reduced = world.visual_comfort != null and world.visual_comfort.reduce_motion
	var floor_sprite = Sprite2D.new()
	floor_sprite.texture = backdrop
	floor_sprite.centered = false
	floor_sprite.scale = Vector2(2, 2)
	add_child(floor_sprite)
	if FIXTURES.has(world.zone):
		for walls in [ROOM_WALLS, FIXTURES[world.zone]]:
			for area in walls:
				world.boundary(area)
	match world.zone:
		"closed_post":
			room_light(world, Vector2(324,175), Color("e0aa78"), .23)
			add_motion(Vector2(324, 168), 4, 6)
			add_motion(Vector2(486, 343), 3, 5)
		"signal_cellar":
			add_motion(Vector2(319, 204), 2, 8)
			for at in [Vector2(150, 163), Vector2(489, 163)]:
				add_motion(at, 3, 6)
		"listening_archive":
			room_light(world, Vector2(318,164), Color("bc9ab6"), .24)
			add_motion(Vector2(323, 226), 2, 6)
			add_motion(Vector2(313, 135), 4, 5)
		"tide_station":
			mount_landing(world)
		"bracken_clearing":
			mount_glade(world)

func room_light(world, at: Vector2, shade: Color, energy: float):
	var lamp: PointLight2D = world.add_light(at)
	lamp.color = shade
	lamp.energy = energy

func add_motion(point: Vector2, row: int, speed: float):
	var frames = SpriteFrames.new()
	frames.set_animation_speed("default", speed)
	for frame in range(6):
		var crop = AtlasTexture.new()
		crop.atlas = SHEET
		crop.region = Rect2(frame * 64, row * 32, 64, 32)
		frames.add_frame("default", crop)
	var sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.position = point
	sprite.scale = Vector2(2, 2)
	add_child(sprite)
	if not reduced:
		sprite.play()
		sprite.frame = posmod(int(point.x + point.y), 6)

func mount_landing(world):
	for area in [
		Rect2(0, 0, 640, 90), Rect2(0, 90, 260, 161), Rect2(380, 90, 260, 161),
		Rect2(0, 250, 97, 195), Rect2(543, 250, 97, 195), Rect2(97, 443, 446, 37),
		Rect2(260, 190, 19, 60), Rect2(360, 190, 20, 60), Rect2(108, 287, 70, 27),
		Rect2(464, 288, 62, 19)
	]:
		world.boundary(area)
	for point in [Vector2(150, 104), Vector2(118, 196), Vector2(218, 162), Vector2(480, 108), Vector2(499, 187), Vector2(60, 324), Vector2(580, 334), Vector2(574, 412)]:
		add_motion(point, 0, 6)
	add_motion(Vector2(320, 286), 2, 7)
	add_motion(Vector2(412, 347), 3, 5)
	world.add_light(Vector2(412, 338))
	world.add_light(Vector2(320, 142))
	route_gate(world, Rect2(277, 228, 86, 14), Color("b09b7c"))

func mount_glade(world):
	for area in [
		Rect2(0, 0, 640, 91), Rect2(0, 91, 106, 309), Rect2(538, 91, 102, 309),
		Rect2(0, 427, 640, 53), Rect2(106, 228, 158, 21), Rect2(377, 228, 161, 21),
		Rect2(163, 172, 66, 19), Rect2(406, 164, 63, 19), Rect2(142, 337, 50, 29)
	]:
		world.boundary(area)
	for point in [Vector2(100, 193), Vector2(146, 283), Vector2(499, 283), Vector2(515, 360), Vector2(185, 397), Vector2(452, 398)]:
		add_motion(point, 1, 5)
	add_motion(Vector2(314, 267), 3, 5)
	route_gate(world, Rect2(260, 228, 121, 21), Color("a28f70"))
	add_leaves(world.expedition_route_open)

func add_leaves(route_open: bool):
	if reduced: return
	var leaves = CPUParticles2D.new()
	var strip: Texture2D = load(LEAF_PATH)
	var leaf = AtlasTexture.new()
	leaf.atlas = strip
	leaf.region = Rect2(0, 0, mini(8, strip.get_width()), strip.get_height())
	leaves.texture = leaf
	leaves.position = Vector2(198, 143) if route_open else Vector2(127, 248)
	leaves.amount = 13
	leaves.lifetime = 2.8
	leaves.preprocess = 2.8
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(50, 30)
	leaves.direction = Vector2(1,-.45) if route_open else Vector2(1,.35)
	leaves.spread = 18
	leaves.initial_velocity_min = 18
	leaves.initial_velocity_max = 42
	leaves.gravity = Vector2(3,1)
	leaves.angular_velocity_min = -32
	leaves.angular_velocity_max = 42
	leaves.scale_amount_min = .65
	leaves.scale_amount_max = 1.25
	leaves.color = Color("bcc797")
	add_child(leaves)

func route_gate(world, area: Rect2, edge: Color):
	var gate = Node2D.new()
	gate.name = "RouteGate"
	gate.position = area.position
	add_child(gate)
	for offset in [0, 6]:
		var rail = Polygon2D.new()
		rail.polygon = PackedVector2Array([Vector2(0,offset), Vector2(area.size.x,offset), Vector2(area.size.x,offset+3), Vector2(0,offset+3)])
		rail.color = edge if offset == 0 else edge.darkened(.45)
		gate.add_child(rail)
	if not world.expedition_route_open:
		world.boundary(area)
		return
	if reduced:
		gate.hide()
		return
	var animation = Animation.new()
	animation.length = .52
	var move = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(move, NodePath("RouteGate:position"))
	animation.track_insert_key(move, 0.0, area.position)
	animation.track_insert_key(move, .52, area.position - Vector2(0, 22))
	var fade = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(fade, NodePath("RouteGate:modulate:a"))
	animation.track_insert_key(fade, 0.0, 1.0)
	animation.track_insert_key(fade, .52, 0.0)
	var library = AnimationLibrary.new()
	library.add_animation("lift", animation)
	$RouteAnimation.add_animation_library("", library)
	$RouteAnimation.play("lift")
