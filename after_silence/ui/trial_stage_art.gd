extends RefCounted

const THEMES={
	"letter_press":["493d37","a67f63"],"footprints":["303b48","947c65"],
	"reality":["303b50","80a3ac"],"tubes":["37364f","9ba7cc"],
	"balance":["413b47","b99469"],"pairs":["42344e","ae879f"],
	"seeds":["293f42","8caa83"],"signal_grid":["293a52","c5a570"],
	"railway":["333b4c","b08868"],"lights":["33374e","d0af79"],
	"echo_tuning":["313651","a291c0"],"shelves":["403b49","9faf9b"],
}
static var mats: Dictionary={}

static func accent(kind: String) -> Color:
	return Color(THEMES[kind][1])

static func _texture(kind: String) -> Texture2D:
	if mats.has(kind): return mats[kind]
	var base=Color(THEMES[kind][0])
	var surface=Image.create(96,64,false,Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(96):
			var grain=posmod(x*19+y*31+posmod(x+y*7,13)*9,59)
			var wood=kind in ["tubes","balance","pairs","shelves","letter_press"]
			var band=posmod(y+int(sin(x*.13)*2.0),16)
			var tint=base
			if wood and band==0: tint=base.darkened(.13)
			elif wood and band==1: tint=base.lightened(.045)
			elif grain<4: tint=base.lightened(.06)
			elif grain>54: tint=base.darkened(.045)
			surface.set_pixel(x,y,tint)
	mats[kind]=ImageTexture.create_from_image(surface)
	return mats[kind]

static func draw(canvas: Control, kind: String, divider: int, board_height: int=187) -> void:
	var trim=accent(kind)
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color("1c2824"))
	canvas.draw_rect(Rect2(Vector2(1,1),canvas.size-Vector2(2,2)),Color("43564a"),false)
	canvas.draw_rect(Rect2(8,7,divider-12,board_height),Color("15211b"))
	canvas.draw_texture_rect(_texture(kind),Rect2(11,10,divider-18,board_height-7),true)
	canvas.draw_rect(Rect2(10,9,divider-15,board_height-4),trim.darkened(.38),false)
	canvas.draw_rect(Rect2(divider,10,1,191),trim.darkened(.48))
	canvas.draw_rect(Rect2(divider+9,9,22,2),trim)
