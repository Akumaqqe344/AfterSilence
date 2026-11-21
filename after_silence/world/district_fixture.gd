extends Node2D
## The baseline is also the origin of the physical footprint.
const DARK=Color("49392f")
const WOOD=Color("8e6548")
const LIGHT=Color("c19466")
const STONE=Color("899184")
const METAL=Color("586465")
var kind=""
var variant=0

func footprint() -> float:
	return {"stall":52.0,"bench":44.0,"wagon":96.0,"crate":22.0,"barrel":15.0,"trellis":28.0,"marker":14.0,"sign":12.0,"logpile":49.0,"trough":36.0,"barrow":33.0,"buoys":28.0}[kind]

func _draw():
	var width=footprint()
	draw_rect(Rect2(-width*.5-4,-5,width+8,10),Color("29332960"))
	match kind:
		"stall": _stall()
		"bench": _bench()
		"wagon": _wagon()
		"crate": _box(-11,0)
		"barrel": _barrel()
		"trellis": _trellis()
		"marker": _marker()
		"sign": _sign()
		"logpile": _logs()
		"trough": _trough()
		"barrow": _barrow()
		"buoys": _buoys()

func _stall():
	var cloth=Color("b77d66") if variant==0 else Color("6d9990")
	for x in [-24,21]:
		draw_rect(Rect2(x,-52,4,53),DARK)
		draw_rect(Rect2(x+1,-50,1,49),LIGHT)
	draw_rect(Rect2(-25,-25,50,23),DARK)
	draw_rect(Rect2(-24,-20,48,17),WOOD)
	for x in range(-22,24,6):
		draw_rect(Rect2(x,-20,1,17),LIGHT.darkened(.2))
	draw_rect(Rect2(-27,-27,54,5),LIGHT)
	for i in range(4):
		var x=-19+i*11
		draw_rect(Rect2(x,-33,9,6),Color("614932"))
		draw_rect(Rect2(x+1,-34,7,5),Color("bd9b58"))
		draw_rect(Rect2(x+3,-36,3,4),Color("c8896b") if i%2 else Color("a0ab63"))
	for i in range(8):
		var x=-28+i*7
		var stripe=cloth if i%2==0 else Color("d9bc8c")
		draw_rect(Rect2(x,-57,7,12),stripe)
		draw_rect(Rect2(x,-45,7,6-(i%2)),stripe.darkened(.2))
	draw_rect(Rect2(-27,-58,54,2),Color("e5c995"))

func _bench():
	for x in [-20,16]:
		draw_rect(Rect2(x,-19,4,19),DARK)
	draw_rect(Rect2(-22,-20,44,7),WOOD)
	draw_rect(Rect2(-22,-20,44,2),LIGHT)
	draw_rect(Rect2(-24,-10,48,6),DARK)
	draw_rect(Rect2(-24,-11,48,3),LIGHT)

func _wagon():
	draw_rect(Rect2(-50,-43,100,39),DARK)
	draw_rect(Rect2(-47,-39,94,32),Color("6e5850"))
	draw_rect(Rect2(-46,-40,92,6),Color("99705a"))
	draw_rect(Rect2(-35,-35,35,27),Color("544741"))
	draw_rect(Rect2(-30,-33,25,23),Color("927058"))
	for x in [-28,-22,-16,-10]:
		draw_rect(Rect2(x,-32,1,22),Color("c19166"))
	for x in [8,21,34]:
		draw_rect(Rect2(x,-34,3,26),Color("716b64"))
	draw_rect(Rect2(-51,-44,102,5),METAL)
	draw_rect(Rect2(-47,-45,94,2),Color("aaa18c"))
	for x in [-33,29]:
		draw_rect(Rect2(x-5,-9,12,13),Color("383b3a"))
		draw_rect(Rect2(x-3,-6,8,7),METAL)
		draw_rect(Rect2(x,-4,3,3),Color("b0a88c"))

func _box(x: float,y: float):
	draw_rect(Rect2(x,y-19,22,19),DARK)
	draw_rect(Rect2(x+1,y-18,20,16),WOOD)
	draw_rect(Rect2(x+1,y-18,20,3),LIGHT)
	draw_line(Vector2(x+3,y-14),Vector2(x+18,y-4),LIGHT.darkened(.16),2)
	draw_rect(Rect2(x+2,y-4,18,2),LIGHT.darkened(.15))

func _barrel():
	draw_rect(Rect2(-8,-21,16,21),DARK)
	draw_rect(Rect2(-7,-19,14,18),WOOD)
	for x in [-5,-1,3]: draw_rect(Rect2(x,-18,1,16),LIGHT)
	for y in [-16,-6]: draw_rect(Rect2(-8,y,16,2),METAL)
	draw_rect(Rect2(-6,-21,12,3),LIGHT)

func _trellis():
	for x in [-13,11]:
		draw_rect(Rect2(x,-39,3,39),DARK)
		draw_rect(Rect2(x,-38,1,38),LIGHT)
	for y in [-38,-29,-20,-11]:
		draw_rect(Rect2(-15,y,30,2),LIGHT)
		for i in range(4):
			var x=-10+i*6-y%5
			draw_rect(Rect2(x,y-4,6,6),Color("657b4d"))
			draw_rect(Rect2(x+1,y-4,4,3),Color("a9a463"))
			if (i+y+variant)%3==0: draw_rect(Rect2(x+4,y-1,3,3),Color("c58c65"))

func _marker():
	var height=15+variant*8
	draw_rect(Rect2(-8,-height+4,16,height-3),Color("525f57"))
	draw_rect(Rect2(-6,-height+1,10,height-3),STONE)
	draw_rect(Rect2(-4,-height+1,8,3),Color("a6a68c"))
	draw_rect(Rect2(-8,-5,13,4),Color("748254"))
	draw_rect(Rect2(-3,-height+6,4,7),Color("697961"))
	draw_rect(Rect2(-2,-height+7,2,5),Color("afb193"))

func _sign():
	draw_rect(Rect2(-2,-15,4,15),DARK)
	draw_rect(Rect2(-1,-14,1,13),LIGHT)
	draw_rect(Rect2(-8,-19,16,9),DARK)
	draw_rect(Rect2(-7,-18,14,7),Color("b69264"))
	draw_rect(Rect2(-5,-17,9,1),Color("ebcf95"))
	draw_rect(Rect2(-4,-14,7,1),Color("72563e"))

func _logs():
	for i in range(3):
		var p=Vector2(-24+i*4,-6-i*7)
		draw_rect(Rect2(p,Vector2(48-i*8,7)),DARK)
		draw_rect(Rect2(p+Vector2(1,1),Vector2(46-i*8,4)),WOOD)
		draw_rect(Rect2(p+Vector2(40-i*8,1),Vector2(5,4)),LIGHT)
		draw_rect(Rect2(p+Vector2(43-i*8,2),Vector2(1,2)),WOOD)

func _trough():
	draw_rect(Rect2(-19,-17,38,18),DARK)
	draw_rect(Rect2(-17,-16,34,11),LIGHT)
	draw_rect(Rect2(-14,-14,28,8),Color("67867e"))
	draw_rect(Rect2(-10,-12,10,1),Color("a3b59a"))
	draw_rect(Rect2(-16,-5,32,4),WOOD)

func _barrow():
	draw_rect(Rect2(-15,-15,28,12),METAL)
	draw_rect(Rect2(-14,-15,26,2),Color("a4a088"))
	draw_rect(Rect2(-10,-12,20,5),Color("887e60"))
	draw_line(Vector2(10,-5),Vector2(22,0),WOOD,2)
	draw_rect(Rect2(-15,-5,6,8),DARK)
	draw_rect(Rect2(-13,-3,3,4),LIGHT)

func _buoys():
	for i in range(3):
		var x=-12+i*9
		draw_rect(Rect2(x,-16+i%2*4,8,13),DARK)
		draw_rect(Rect2(x+1,-15+i%2*4,6,10),Color("aa7462") if i%2==0 else Color("799087"))
		draw_rect(Rect2(x+1,-11+i%2*4,6,2),Color("d8bc91"))
	draw_line(Vector2(-13,-4),Vector2(15,-2),LIGHT,2)
