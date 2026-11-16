extends RefCounted
## Shared palette and control states for the whole desktop interface.
const FONT_FILE=preload("res://after_silence/assets/fonts/Nunito-Regular.ttf")
static var FONT: Font=_make_font()
const INK=Color("292d38")
const SURFACE=Color("343946")
const TEXT=Color("fff3e2")
const MUTED=Color("c6cccf")
const SAGE=Color("a9d8bf")
const PEACH=Color("f3bd9d")

static func _make_font() -> Font:
	var font=FontVariation.new()
	font.base_font=FONT_FILE
	# Godot's FontVariation dictionary uses integer OpenType axis tags.
	font.variation_opentype={0x77676874:600.0} # wght
	return font

static func panel(bg: Color=SURFACE, accent: bool=false) -> StyleBoxFlat:
	var box=StyleBoxFlat.new()
	box.bg_color=bg
	box.border_color=SAGE if accent else Color("626c73")
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(12)
	box.shadow_color=Color(0.07,0.08,0.12,0.3)
	box.shadow_size=5
	box.shadow_offset=Vector2(0,3)
	box.anti_aliasing=false
	return box

static func button(active: bool=false, pressed: bool=false) -> StyleBoxFlat:
	var box=panel(Color("536b65") if pressed else Color("46574f") if active else Color("3c4350"))
	box.border_color=SAGE if active else Color("68727b")
	box.content_margin_top=5
	box.content_margin_bottom=5
	box.content_margin_left=12
	box.content_margin_right=12
	box.shadow_size=0
	return box

static func create(large: bool=false) -> Theme:
	var result=Theme.new()
	result.default_font=FONT
	result.default_font_size=15 if large else 13
	for type in ["Label","Button","CheckButton","CheckBox","RichTextLabel"]:
		result.set_color("font_color",type,TEXT)
	result.set_color("default_color","RichTextLabel",TEXT)
	result.set_constant("line_separation","RichTextLabel",4)
	result.set_constant("line_spacing","Label",2)
	result.set_stylebox("normal","Button",button())
	result.set_stylebox("hover","Button",button(true))
	result.set_stylebox("pressed","Button",button(true,true))
	var focus=panel(Color.TRANSPARENT,true)
	focus.set_border_width_all(2)
	focus.shadow_size=0
	result.set_stylebox("focus","Button",focus)
	result.set_stylebox("focus","HSlider",focus)
	var disabled=button();disabled.bg_color=Color("343b46");disabled.border_color=Color("525b65")
	result.set_stylebox("disabled","Button",disabled)
	for state in ["font_hover_color","font_pressed_color","font_focus_color"]:
		result.set_color(state,"Button",TEXT)
	result.set_color("font_disabled_color","Button",Color("a0aab4"))
	result.set_stylebox("panel","Panel",panel())
	result.set_stylebox("panel","PanelContainer",panel())
	result.set_stylebox("panel","TooltipPanel",panel(INK,true))
	result.set_font_size("font_size","TooltipLabel",13)
	var track=panel(Color("222934"));track.set_content_margin_all(0);track.shadow_size=0
	var fill=track.duplicate();fill.bg_color=SAGE;fill.border_color=SAGE
	result.set_stylebox("background","ProgressBar",track)
	result.set_stylebox("fill","ProgressBar",fill)
	var scroll=track.duplicate();scroll.content_margin_left=3;scroll.content_margin_right=3
	result.set_stylebox("scroll","VScrollBar",scroll)
	for state in ["grabber","grabber_highlight","grabber_pressed"]:
		result.set_stylebox(state,"VScrollBar",fill)
	var slider_track=track.duplicate()
	slider_track.content_margin_top=3;slider_track.content_margin_bottom=3
	result.set_stylebox("slider","HSlider",slider_track)
	var slider_fill=slider_track.duplicate();slider_fill.bg_color=SAGE
	result.set_stylebox("grabber_area","HSlider",slider_fill)
	result.set_stylebox("grabber_area_highlight","HSlider",slider_fill)
	var thumb_image=Image.new()
	thumb_image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14"><circle cx="7" cy="7" r="6" fill="#a9d8bf" stroke="#fff3e2" stroke-width="2"/></svg>')
	var thumb=ImageTexture.create_from_image(thumb_image)
	for state in ["grabber","grabber_highlight","grabber_disabled"]:
		result.set_icon(state,"HSlider",thumb)
	result.set_constant("separation","VBoxContainer",8)
	return result
