extends Button
## The menu uses engraved icons and a brass marker for the selected action.

const GLYPHS = {
	"events_load": ["#....", "##...", "###..", "####.", "###..", "##...", "#...."],
	"events_new": ["..#..", ".#.#.", "#...#", "#...#", "#...#", "#..##", "#####"],
	"settings": ["..#..", ".###.", "##.##", "#...#", "##.##", ".###.", "..#.."],
	"quit": ["...#.", "....#", "#####", "....#", "...#.."],
}
var action_id: String
var primary := false

func _ready() -> void:
	refresh_skin()
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	var engraving := Control.new()
	engraving.mouse_filter = Control.MOUSE_FILTER_IGNORE
	engraving.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	engraving.draw.connect(func(): _engrave(engraving))
	add_child(engraving)
	draw.connect(engraving.queue_redraw)

func refresh_skin() -> void:
	add_theme_stylebox_override("normal", _plate(Color("30272ddd") if primary else Color("191c2699"), Color("8d6854") if primary else Color("424451")))
	add_theme_stylebox_override("hover", _plate(Color("39303c"), Color("b89168")))
	add_theme_stylebox_override("pressed", _plate(Color("271e28"), Color("f3c88f")))
	add_theme_stylebox_override("disabled", _plate(Color("15192488"), Color("30333e")))
	add_theme_stylebox_override("focus", _plate(Color.TRANSPARENT, Color("efbb83")))
	add_theme_color_override("font_disabled_color", Color("9394a4"))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		add_theme_color_override(state, Color("f0dec5") if primary else Color("e7dfdb"))
	queue_redraw()

func _plate(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.border_width_top = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 2
	box.corner_radius_bottom_right = 2
	box.set_content_margin_all(6)
	box.content_margin_left = 34
	box.content_margin_right = 23
	box.anti_aliasing = false
	return box

func _engrave(canvas: Control) -> void:
	var selected := not disabled and (has_focus() or is_hovered())
	var color := Color("676a7b") if disabled else Color("f2c68f") if selected or primary else Color("ad8990")
	var rows: Array = GLYPHS[action_id]
	var top := floorf((size.y - rows.size()) * .5)
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				canvas.draw_rect(Rect2(13 + x, top + y, 1, 1), color)
	var middle := floorf(size.y * .5)
	canvas.draw_rect(Rect2(25, middle - 5, 1, 10), Color(color, .34))
	if selected or primary:
		canvas.draw_rect(Rect2(0, 5, 2, size.y - 10), color)
	if selected:
		for i in 3:
			canvas.draw_rect(Rect2(size.x - 13 + i, middle - 2 + i, 1, 5 - i * 2), color)
