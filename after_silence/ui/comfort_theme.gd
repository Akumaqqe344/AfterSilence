extends RefCounted
## Shared palette and control states for the whole desktop interface.
const FONT_FILE=preload("res://after_silence/assets/fonts/PressStart2P-Regular.ttf")
static var FONT: Font=_make_font()
const INK=Color("262637")
const SURFACE=Color("38364b")
const TEXT=Color("fff3e2")
const MUTED=Color("c6cccf")
const SAGE=Color("b5d4bd")
const PEACH=Color("efbe9e")

static func world_light(zone: String, night: bool, echo: bool) -> Color:
	if echo: return Color("a0a7c8")
	if night: return Color("999bb7")
	if zone=="forest" or zone=="library": return Color("cbd1ba")
	return Color("ded9bf")

static func _make_font() -> Font:
	var font=FONT_FILE.duplicate()
	font.antialiasing=TextServer.FONT_ANTIALIASING_NONE
	font.hinting=TextServer.HINTING_NONE
	return font
static func panel(bg: Color=SURFACE, accent: bool=false) -> StyleBoxFlat:
	var box=StyleBoxFlat.new()
	box.bg_color=bg
	box.border_color=SAGE if accent else Color("626c73")
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(8)
	box.shadow_color=Color(0.07,0.08,0.12,0.3)
	box.shadow_size=2
	box.shadow_offset=Vector2(0,2)
	box.anti_aliasing=false
	return box

static func button(active: bool=false, pressed: bool=false) -> StyleBoxFlat:
	var box=panel(Color("5a625f") if pressed else Color("4e585c") if active else Color("414055"))
	box.border_color=SAGE if active else Color("68727b")
	box.content_margin_top=4
	box.content_margin_bottom=4
	box.content_margin_left=8
	box.content_margin_right=8
	box.shadow_size=0
	return box

static func create(large: bool=false) -> Theme:
	var result=Theme.new()
	result.default_font=FONT
	result.default_font_size=10 if large else 8
	for type in ["Label","Button","CheckButton","CheckBox","RichTextLabel"]:
		result.set_color("font_color",type,TEXT)
	result.set_color("default_color","RichTextLabel",TEXT)
	result.set_constant("line_separation","RichTextLabel",3)
	result.set_constant("line_spacing","Label",2)
	result.set_stylebox("normal","Button",button())
	result.set_stylebox("hover","Button",button(true))
	result.set_stylebox("pressed","Button",button(true,true))
	var focus=panel(Color.TRANSPARENT,true)
	focus.set_content_margin_all(0)
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
	result.set_font_size("font_size","TooltipLabel",8)
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
	thumb_image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="12"><path d="M2 0h6v2h2v8H8v2H2v-2H0V2h2z" fill="#a9d8bf"/></svg>')
	var thumb=ImageTexture.create_from_image(thumb_image)
	for state in ["grabber","grabber_highlight","grabber_disabled"]:
		result.set_icon(state,"HSlider",thumb)
	result.set_constant("separation","VBoxContainer",6)
	return result
