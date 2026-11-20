extends RefCounted
## Shared palette and control states for the whole desktop interface.
const FONT_FILE=preload("res://after_silence/assets/fonts/Nunito-Regular.ttf")
static var FONT: Font=_weighted_font(485)
static var HEADING: Font=_weighted_font(720)
const INK=Color("141c1a")
const SURFACE=Color("222e2a")
const TEXT=Color("f6efdd")
const MUTED=Color("b7c5b7")
const SAGE=Color("b5c6a3")
const PEACH=Color("efce9f")
const BRASS=Color("c69b6c")
const EDGE=Color("45584c")

static func world_light(zone: String, night: bool, echo: bool) -> Color:
	if echo: return Color("a0a7c8")
	if night: return Color("999bb7")
	if zone=="forest" or zone=="library": return Color("cbd1ba")
	return Color("ded9bf")

static func _weighted_font(weight: int) -> Font:
	var font=FontVariation.new()
	font.base_font=FONT_FILE
	font.variation_opentype={0x77676874: weight}
	return font
static func panel(bg: Color=SURFACE, accent: bool=false) -> StyleBoxFlat:
	var box=StyleBoxFlat.new()
	box.bg_color=bg
	box.border_color=BRASS if accent else EDGE
	box.set_border_width_all(1)
	box.border_width_bottom=1
	box.set_corner_radius_all(3)
	box.set_content_margin_all(12)
	box.shadow_color=Color("080d0b70")
	box.shadow_size=4
	box.shadow_offset=Vector2(0,3)
	box.anti_aliasing=false
	return box

static func button(active: bool=false, pressed: bool=false) -> StyleBoxFlat:
	var box=panel(Color("4a4c36") if pressed else Color("38483a") if active else Color("2b3831"))
	box.border_color=PEACH if active else Color("435448")
	box.content_margin_top=4
	box.content_margin_bottom=4
	box.content_margin_left=10
	box.content_margin_right=10
	box.shadow_size=0
	return box

static func create(large: bool=false) -> Theme:
	var result=Theme.new()
	result.default_font=FONT
	result.default_font_size=14 if large else 11
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
	focus.set_border_width_all(1)
	focus.shadow_size=0
	result.set_stylebox("focus","Button",focus)
	result.set_stylebox("focus","HSlider",focus)
	var disabled=button();disabled.bg_color=Color("252f2a");disabled.border_color=Color("36463d")
	result.set_stylebox("disabled","Button",disabled)
	for state in ["font_hover_color","font_pressed_color","font_focus_color"]:
		result.set_color(state,"Button",TEXT)
	result.set_color("font_disabled_color","Button",Color("a7b0a2"))
	result.set_stylebox("panel","Panel",panel())
	result.set_stylebox("panel","PanelContainer",panel())
	result.set_stylebox("panel","TooltipPanel",panel(INK,true))
	result.set_font_size("font_size","TooltipLabel",11)
	var track=panel(Color("151f1a"));track.set_content_margin_all(0);track.shadow_size=0
	var fill=track.duplicate();fill.bg_color=BRASS;fill.border_color=PEACH
	result.set_stylebox("background","ProgressBar",track)
	result.set_stylebox("fill","ProgressBar",fill)
	var scroll=track.duplicate();scroll.content_margin_left=2;scroll.content_margin_right=2
	var thumb_style=fill.duplicate();thumb_style.bg_color=EDGE;thumb_style.border_color=EDGE
	result.set_stylebox("scroll","VScrollBar",scroll)
	for state in ["grabber","grabber_highlight","grabber_pressed"]:
		result.set_stylebox(state,"VScrollBar",thumb_style)
	var slider_track=track.duplicate()
	slider_track.content_margin_top=3;slider_track.content_margin_bottom=3
	result.set_stylebox("slider","HSlider",slider_track)
	var slider_fill=slider_track.duplicate();slider_fill.bg_color=SAGE
	result.set_stylebox("grabber_area","HSlider",slider_fill)
	result.set_stylebox("grabber_area_highlight","HSlider",slider_fill)
	var thumb_image=Image.new()
	thumb_image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="12"><path d="M2 0h6v2h2v8H8v2H2v-2H0V2h2z" fill="#b5c6a3"/></svg>')
	var thumb=ImageTexture.create_from_image(thumb_image)
	for state in ["grabber","grabber_highlight","grabber_disabled"]:
		result.set_icon(state,"HSlider",thumb)
	result.set_constant("separation","VBoxContainer",6)
	return result
