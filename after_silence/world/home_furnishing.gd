extends Node2D
const Art=preload("res://after_silence/core/ppae_art.gd")

const INK=Color("45352e")
const WOOD=Color("876044")
const RIM=Color("bc8e61")
const METAL=Color("5a6766")
const LINEN=Color("dcc39a")
const PAPER=Color("ead2a5")
var kind=""
var extent=Vector2.ZERO
var tint=Color.WHITE

func solid() -> bool: return kind not in ["rug","window"]

func _draw():
	draw_set_transform(Vector2(-extent.x*.5,-extent.y))
	if solid(): draw_rect(Rect2(3,5,extent.x,extent.y),Color("352b2655"))
	var ppae_kind: String=Art.FURNITURE.get(kind,"")
	if not ppae_kind.is_empty():
		var surface:=Art.texture("interior_"+ppae_kind)
		if surface:
			texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			draw_texture_rect(surface,Rect2(Vector2.ZERO,extent),false,Color.WHITE.lerp(tint,.18))
			return
	match kind:
		"window": _window()
		"rug": _rug()
		"bed": _bed()
		"sofa": _sofa()
		"chair","stool": _seat()
		"plant": _plant()
		"chest","storage","toolbox": _chest()
		"forge","stove": _stove()
		"table","wash","desk","bench": _worktop()
		_: _cabinet()

func _window():
	for i in range(4):
		var start=Vector2(i*8,extent.y-5)
		var points=PackedVector2Array([start,start+Vector2(59,0),start+Vector2(8,78),start+Vector2(-64,78)])
		draw_colored_polygon(points,Color("eac6800e"))
	_box(Rect2(Vector2.ZERO,extent),WOOD)
	draw_rect(Rect2(6,5,extent.x-12,extent.y-12),Color("79918c"))
	draw_rect(Rect2(11,10,extent.x-22,extent.y-21),Color("b4bda0"))
	draw_rect(Rect2(extent.x*.5-2,6,4,extent.y-13),WOOD)
	draw_rect(Rect2(6,22,extent.x-12,3),WOOD)
	draw_rect(Rect2(0,extent.y-5,extent.x,5),RIM)
	for x in [5,extent.x-15]:
		draw_rect(Rect2(x,4,10,35),tint.darkened(.24))
		draw_rect(Rect2(x+2,4,3,35),tint)

func _rug():
	var rug=Rect2(Vector2.ZERO,extent)
	draw_rect(rug,tint.darkened(.48))
	draw_rect(rug.grow(-3),tint.darkened(.09))
	draw_rect(rug.grow(-8),Color("dbc099"),false,2)
	draw_rect(rug.grow(-14),tint.darkened(.14))
	var mid=extent*.5
	for i in range(3):
		var w=13.0+i*10.0
		var points=PackedVector2Array([mid-Vector2(w,0),mid-Vector2(0,w),mid+Vector2(w,0),mid+Vector2(0,w),mid-Vector2(w,0)])
		draw_polyline(points,Color("d1b88c"),2)
	for x in range(6,int(extent.x)-4,6):
		draw_rect(Rect2(x,-4,2,4),Color("a9906d"))
		draw_rect(Rect2(x,extent.y,2,4),Color("a9906d"))

func _box(rect: Rect2,color: Color):
	draw_rect(rect,INK)
	draw_rect(rect.grow(-2),color)
	draw_rect(Rect2(rect.position+Vector2(2,2),Vector2(rect.size.x-4,2)),color.lightened(.18))
	draw_rect(Rect2(rect.position+Vector2(3,rect.size.y-4),Vector2(rect.size.x-6,2)),color.darkened(.19))

func _bed():
	_box(Rect2(Vector2.ZERO,extent),WOOD.darkened(.12))
	_box(Rect2(5,7,extent.x-10,extent.y-19),LINEN.darkened(.09))
	var pillow=(extent.x-24)*.5
	for x in [9.0,13.0+pillow]:
		_box(Rect2(x,10,pillow,24),LINEN)
	_box(Rect2(6,39,extent.x-12,extent.y-50),tint)
	for y in range(48,int(extent.y)-16,12):
		draw_rect(Rect2(9,y,extent.x-18,2),tint.lightened(.18))
		for x in range(15,int(extent.x)-14,14): draw_rect(Rect2(x,y+3,2,3),tint.darkened(.14))
	draw_rect(Rect2(3,extent.y-9,extent.x-6,5),RIM)

func _sofa():
	_box(Rect2(Vector2.ZERO,extent),WOOD)
	_box(Rect2(8,4,extent.x-16,15),tint.darkened(.22))
	var width=(extent.x-20)*.5
	for x in [8.0,12.0+width]: _box(Rect2(x,20,width,16),tint)
	for x in [3,extent.x-10]: _box(Rect2(x,16,7,20),RIM)

func _seat():
	_box(Rect2(Vector2.ZERO,extent),WOOD)
	_box(Rect2(4,7,extent.x-8,extent.y-13),tint)
	draw_rect(Rect2(5,extent.y-6,3,5),RIM)
	draw_rect(Rect2(extent.x-9,extent.y-6,3,5),RIM)

func _plant():
	var pot=Color("ad7255")
	_box(Rect2(7,extent.y-17,extent.x-14,17),pot)
	for i in range(5):
		var x=8+i*5
		draw_line(Vector2(extent.x*.5,extent.y-13),Vector2(x,7+(i*13)%9),Color("657752"),2)
		_box(Rect2(x-3,5+(i*13)%9,8,5),Color("839a65"))

func _stove():
	_box(Rect2(Vector2.ZERO,extent),METAL)
	_box(Rect2(7,7,extent.x-14,extent.y-13),Color("74716b"))
	for x in [13,extent.x-31]:
		_box(Rect2(x,9,18,16),Color("484644"))
		draw_rect(Rect2(x+4,13,10,4),Color("b18660"))
	_box(Rect2(extent.x*.5-10,extent.y-20,20,14),INK)
	draw_rect(Rect2(extent.x*.5-7,extent.y-16,14,3),Color("ca8960"))

func _worktop():
	_box(Rect2(Vector2.ZERO,extent),WOOD)
	_box(Rect2(3,3,extent.x-6,extent.y-13),RIM.darkened(.08))
	draw_rect(Rect2(5,extent.y-9,extent.x-10,3),WOOD.darkened(.2))
	match kind:
		"wash":
			_box(Rect2(24,6,35,18),METAL)
			draw_rect(Rect2(29,10,25,8),Color("8aa39a"))
			draw_rect(Rect2(73,7,11,11),LINEN)
		"bench":
			for i in range(5):
				var x=13+i*17
				draw_rect(Rect2(x,10+(i%2)*4,3,19),METAL)
				draw_rect(Rect2(x-3,12+(i%2)*4,9,4),Color("a6a49a"))
			_box(Rect2(71,34,26,11),INK)
		"desk":
			draw_rect(Rect2(18,6,32,14),PAPER)
			for i in range(3): draw_rect(Rect2(21,8+i*3,20+i%2*3,1),WOOD)
			_box(Rect2(74,6,10,10),METAL)
		_:
			draw_rect(Rect2(20,4,extent.x-40,16),tint)
			_box(Rect2(32,8,12,10),LINEN)

func _chest():
	_box(Rect2(Vector2.ZERO,extent),WOOD)
	_box(Rect2(3,3,extent.x-6,extent.y*.5),RIM.darkened(.12))
	for x in [4,extent.x-8]:
		draw_rect(Rect2(x,3,4,extent.y-6),METAL)
		draw_rect(Rect2(x,6,4,2),Color("a79c81"))
	var latch=extent/2.0
	_box(Rect2(latch-Vector2(5,1),Vector2(10,8)),RIM.lightened(.12))
	draw_rect(Rect2(latch+Vector2(0,2),Vector2(1,3)),INK)

func _cabinet():
	_box(Rect2(Vector2.ZERO,extent),WOOD)
	_box(Rect2(3,3,extent.x-6,extent.y-13),RIM.darkened(.16))
	var span=(extent.x-18)/4.0
	for i in range(4):
		var x=7+i*span
		var color: Color=[tint,LINEN,METAL,RIM][i]
		match kind:
			"medicine","books","tools":
				_box(Rect2(x,7,span-4,extent.y-23),color)
				draw_rect(Rect2(x+4,11,span-12,2),PAPER)
			"wood","boots":
				_box(Rect2(x,7,span-5,extent.y-22),color.darkened(.25))
			"rack":
				draw_rect(Rect2(x+4,6,2,10),PAPER)
			_:
				_box(Rect2(x,7,span-4,extent.y-22),color.darkened(.12))
				draw_rect(Rect2(x+span*.5-3,extent.y-21,5,2),PAPER)
	draw_rect(Rect2(6,extent.y-8,extent.x-12,2),RIM)
