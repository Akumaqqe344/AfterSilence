extends RefCounted
const STAGES=preload("res://after_silence/assets/minigames0310/stages.png")
const OBJECTS=preload("res://after_silence/assets/minigames0310/objects.png")
const BoardSkin=preload("res://after_silence/core/ppae_art.gd")
const MODES=["letter_press","footprints","reality","tubes","balance","pairs","seeds","signal_grid","railway","lights","echo_tuning","shelves"]

const THEMES={
	"letter_press":["493d37","a67f63"],"footprints":["303b48","947c65"],
	"reality":["303b50","80a3ac"],"tubes":["37364f","9ba7cc"],
	"balance":["413b47","b99469"],"pairs":["42344e","ae879f"],
	"seeds":["293f42","8caa83"],"signal_grid":["293a52","c5a570"],
	"railway":["333b4c","b08868"],"lights":["33374e","d0af79"],
	"echo_tuning":["313651","a291c0"],"shelves":["403b49","9faf9b"],
}
static var icons: Dictionary={}
static var plates: Dictionary={}

static func accent(kind: String) -> Color:
	return Color(THEMES[kind][1])

static func surface(canvas: CanvasItem, kind: String, bounds: Rect2):
	var i=MODES.find(kind)
	var crop=Rect2((i%3)*112,floori(i/3.0)*80,112,80)
	canvas.draw_texture_rect_region(STAGES,bounds,crop,Color.WHITE,false,true)

static func icon(i: int) -> AtlasTexture:
	if not icons.has(i):
		var cell=AtlasTexture.new()
		cell.atlas=OBJECTS
		cell.region=Rect2((i%8)*24,floori(i/8.0)*24,24,24)
		cell.filter_clip=true
		icons[i]=cell
	return icons[i]

static func stamp(canvas: CanvasItem, i: int, at: Vector2, extent: Vector2, tint: Color=Color.WHITE):
	var region = Rect2((i%8)*24,floori(i/8.0)*24,24,24)
	canvas.draw_texture_rect_region(OBJECTS,Rect2((at-extent*.5).round(),extent),region,tint,false,true)

static func button(control: Button, active: bool=false):
	for pair in [["normal","hover" if active else "normal"],["hover","hover"],["pressed","pressed"],["disabled","disabled"]]:
		control.add_theme_stylebox_override(pair[0],plate(pair[1]))

static func plate(name: String) -> StyleBoxTexture:
	if not plates.has(name): plates[name]=BoardSkin.panel(name,3)
	return plates[name]

static func draw(canvas: Control, kind: String, divider: int, board_height: int=187) -> void:
	var trim=accent(kind)
	canvas.draw_style_box(plate("panel"),Rect2(Vector2.ZERO,canvas.size))
	canvas.draw_rect(Rect2(8,7,divider-12,board_height),Color("211c26"))
	surface(canvas,kind,Rect2(11,10,divider-18,board_height-7))
	canvas.draw_rect(Rect2(10,9,divider-15,board_height-4),trim.darkened(.38),false)
	canvas.draw_rect(Rect2(divider,10,1,191),trim.darkened(.48))
	canvas.draw_rect(Rect2(divider+9,9,22,2),trim)
