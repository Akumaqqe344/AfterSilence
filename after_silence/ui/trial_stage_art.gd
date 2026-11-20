extends RefCounted

const THEMES={
	"letter_press":["453249","966c65"],"footprints":["303b48","947c65"],
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
	var surface=Image.create(64,48,false,Image.FORMAT_RGBA8)
	for y in range(48):
		for x in range(64):
			var grain=posmod(x*19+y*31+posmod(x+y*7,13)*9,59)
			var inset=((y%12==0) or (y%12==1 and x%5<3)) and kind in ["tubes","balance","pairs","shelves","letter_press"]
			var tint=base.darkened(.15) if inset else base.lightened(.07) if grain<4 else base.darkened(.06) if grain>54 else base
			surface.set_pixel(x,y,tint)
	mats[kind]=ImageTexture.create_from_image(surface)
	return mats[kind]

static func draw(canvas: Control, kind: String, divider: int, board_height: int=187) -> void:
	var trim=accent(kind)
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color("1d2d39"))
	canvas.draw_rect(Rect2(Vector2(1,1),canvas.size-Vector2(2,2)),Color("647c80"),false)
	canvas.draw_rect(Rect2(8,7,divider-12,board_height),Color("17262e"))
	canvas.draw_texture_rect(_texture(kind),Rect2(11,10,divider-18,board_height-7),true)
	canvas.draw_rect(Rect2(10,9,divider-15,board_height-4),trim.darkened(.38),false)
	canvas.draw_rect(Rect2(divider,10,1,191),trim.darkened(.48))
	canvas.draw_rect(Rect2(divider+3,10,1,191),Color("303344"))
	canvas.draw_rect(Rect2(divider+9,7,canvas.size.x-divider-17,4),trim.darkened(.31))
	canvas.draw_rect(Rect2(divider+9,canvas.size.y-8,canvas.size.x-divider-17,1),trim.darkened(.44))
	for y in [11,board_height-4]:
		for x in [12,divider-13]:
			canvas.draw_rect(Rect2(x,y,3,3),trim)
			canvas.draw_rect(Rect2(x+1,y+1,1,1),Color("e1ccc1"))
