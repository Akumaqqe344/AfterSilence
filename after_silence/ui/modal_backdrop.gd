extends Control

const Art = preload("res://after_silence/core/ppae_art.gd")
const COTTAGE = preload("res://after_silence/assets/remaster0290/menu_cottage.png")
const SCENE_SIZE := Vector2(640, 360)
const DOOR := Rect2(480, 184, 53, 89)
const THRESHOLD := Vector2(506, 273)
const STAIRS := Vector2(496, 301)
const PATH_END := Vector2(553, 345)
const DEPARTURE_DURATION := 1.12
const FADE_OUT := Color("131521")
const PANES := [
	Rect2(407, 194, 17, 18), Rect2(428, 194, 17, 18),
	Rect2(407, 216, 17, 18), Rect2(428, 216, 17, 18),
]

var menu_mode := false
var animation_enabled := false
var finish_mark := false
var sky_time := 0.0
var frame_budget := 0.0
var departure_elapsed := -1.0
var window_glow: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, .48, 1.0])
	gradient.colors = PackedColorArray([Color("f5b46e52"), Color("e68d4321"), Color("e68d4300")])
	window_glow = GradientTexture2D.new()
	window_glow.gradient = gradient
	window_glow.width = 48
	window_glow.height = 48
	window_glow.fill = GradientTexture2D.FILL_RADIAL
	window_glow.fill_from = Vector2(.5, .5)
	window_glow.fill_to = Vector2(1, .5)
	visibility_changed.connect(func(): set_process(animation_enabled and is_visible_in_tree()))
	set_process(false)

func configure_motion(enabled: bool) -> void:
	departure_elapsed = -1.0
	sky_time = 0.0
	frame_budget = 0.0
	animation_enabled = (menu_mode or finish_mark) and enabled
	set_process(animation_enabled)
	queue_redraw()

func play_departure() -> void:
	_advance_departure(0.0)
	var movement := create_tween()
	movement.tween_method(_advance_departure, 0.0, DEPARTURE_DURATION, DEPARTURE_DURATION)
	await movement.finished

func _advance_departure(value: float) -> void:
	departure_elapsed = value
	queue_redraw()

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	sky_time = fmod(sky_time + dt, 120.0)
	if not menu_mode and sky_time >= .9:
		set_process(false)
		queue_redraw()
		return
	frame_budget += dt
	if frame_budget >= 1.0 / 24.0:
		frame_budget = 0.0
		queue_redraw()

func _draw() -> void:
	if menu_mode:
		_draw_cottage()
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("101714bc"))
	if finish_mark and animation_enabled and sky_time < .9:
		_quiet_victory()

func _draw_cottage() -> void:
	var elapsed := departure_elapsed
	var zoom := 1.0 + .045 * smoothstep(0.0, .85, elapsed)
	draw_set_transform(Vector2(517, 292) * (1.0 - zoom), 0.0, Vector2.ONE * zoom)
	draw_texture_rect(COTTAGE, Rect2(Vector2.ZERO, SCENE_SIZE), false)
	var warmth := 1.0 - smoothstep(.29, .70, elapsed)
	if warmth > 0.0:
		var pulse := 1.0 + sin(sky_time * 1.7) * .04
		_draw_windows(warmth * pulse)
	var opening := smoothstep(.04, .24, elapsed) * (1.0 - smoothstep(.48, .70, elapsed))
	if opening > 0.0:
		_draw_door(opening, warmth)
	if elapsed > .17:
		_draw_vera(elapsed)
	if animation_enabled:
		_draw_fireflies()
	draw_set_transform(Vector2.ZERO)
	if elapsed > .79:
		draw_rect(Rect2(Vector2.ZERO, size), Color(FADE_OUT, smoothstep(.79, DEPARTURE_DURATION, elapsed)))

func _draw_windows(warmth: float) -> void:
	draw_texture_rect(window_glow, Rect2(362, 148, 127, 135), false, Color(1, 1, 1, warmth))
	for i in PANES.size():
		var pane: Rect2 = PANES[i]
		var glass := Color("e9a258") if i < 2 else Color("c47c44")
		draw_rect(pane, Color(glass, .84 * warmth))
		draw_rect(Rect2(pane.position + Vector2(2, 2), Vector2(11, 4)), Color("f8bc70", .50 * warmth))
		draw_rect(Rect2(pane.position + Vector2(0, pane.size.y - 2), Vector2(pane.size.x, 2)), Color("7f4430", .58 * warmth))
		draw_rect(Rect2(pane.position + Vector2(3, 8), Vector2(2, 6)), Color("a86743", .40 * warmth))

func _draw_door(opening: float, warmth: float) -> void:
	draw_rect(DOOR, Color("17141b").lerp(Color("79523a"), warmth))
	draw_rect(Rect2(484, 189, 39, 78), Color("27202a").lerp(Color("a76b47"), warmth))
	for i in 6:
		var y := 195 + 11 * i
		draw_rect(Rect2(484, y, 39, 1), Color("2c2030", .55))
		draw_rect(Rect2(486 + (i * 9) % 27, y + 3, 6 + (i * 7) % 11, 2), Color("e6a367", .38 * warmth))
	draw_rect(Rect2(484, 267, 47, 6), Color("453647").lerp(Color("d39a60"), warmth))
	if warmth > 0.0:
		draw_colored_polygon(PackedVector2Array([Vector2(488, 272), Vector2(525, 272), Vector2(543, 301), Vector2(472, 301)]), Color("ec9b5d", warmth * opening * .17))
	var top := DOOR.position
	var end := DOOR.end
	var inner_x := roundf(lerpf(end.x, top.x + 8.0, opening))
	var rise := roundf(11.0 * opening)
	var corners := PackedVector2Array([top, Vector2(inner_x, top.y + rise), Vector2(inner_x, end.y - rise), Vector2(top.x, end.y)])
	var uvs := PackedVector2Array([top / SCENE_SIZE, Vector2(end.x, top.y) / SCENE_SIZE, end / SCENE_SIZE, Vector2(top.x, end.y) / SCENE_SIZE])
	draw_polygon(corners, PackedColorArray([Color.WHITE]), uvs, COTTAGE)
	draw_rect(Rect2(inner_x, top.y + rise, 1, DOOR.size.y - 2.0 * rise), Color("ad7960", warmth * .5))

func _draw_vera(elapsed: float) -> void:
	var step_down := smoothstep(.17, .58, elapsed)
	var walk_away := smoothstep(.54, 1.06, elapsed)
	var feet := THRESHOLD.lerp(STAIRS, step_down).lerp(PATH_END, walk_away).round()
	var frame := int(maxf(0.0, elapsed - .17) * 16.0) % 4
	var appear := smoothstep(.17, .29, elapsed)
	var scale_factor := lerpf(.56, .90, step_down + (1.0 - step_down) * walk_away)
	var sequence := "walk_E" if elapsed >= .62 else "walk_S"
	draw_rect(Rect2(feet + Vector2(-7, -2), Vector2(14, 4)), Color("17171d", appear * .53))
	Art.paint_actor(self,"vera",sequence,frame,feet,scale_factor,Color("e7d4c4",appear))

func _draw_fireflies() -> void:
	for i in 7:
		var at := Vector2(340 + i * 42 + sin(sky_time * .7 + i) * 11, 303 + (i * 13) % 33 + cos(sky_time * 1.2 + i) * 5)
		var alpha := .22 + .36 * pow(.5 + .5 * sin(sky_time * 1.1 + i * 2.0), 3.0)
		draw_rect(Rect2((at / 2.0).round() * 2.0, Vector2(2, 2)), Color("dfbc85", alpha))

func _quiet_victory() -> void:
	var t := sky_time / .9
	for i in 12:
		var x := 320 + (-1 if i % 2 else 1) * (245 + sin(i * 2.4 + t * 2.0) * 32)
		var y := 136 + i * 13 - t * 35
		var gold := Color("e4bf8d", (1.0 - t) * .78)
		draw_rect(Rect2(Vector2(x, y).round(), Vector2(2 + i % 2, 2 + i % 2)), gold)
