extends Node2D
const Garden=preload("res://after_silence/world/garden_pixels.gd")
const Ppae=preload("res://after_silence/core/ppae_art.gd")
var kind = "tree"
var tex: Texture2D
var tint = Color.WHITE
var size = Vector2(48,72)
var variant = 0
var lit=true
var focused=false
var wind_key=""
var wind_pose=1
var solar_shadow=Vector3.ZERO
var glass: Texture2D
var window_light=0.0

func sway(next: int, shadow: Vector3) -> void:
	if wind_pose==next and solar_shadow==shadow: return
	wind_pose=next
	solar_shadow=shadow
	tex=Ppae.texture(wind_key+str(next))
	queue_redraw()
func light_anchor() -> Vector2:
	if kind=="street_lamp": return Vector2(0,-size.y*.78)
	if kind=="trace": return Vector2(size.x*.29,-size.y*.54)
	return Vector2(0,-size.y*.75)
func _draw():
	if kind=="flowers" and not tex:
		Garden.bunch(self,Vector2.ZERO,variant,0,4+variant%3)
		return
	if tex:
		if not wind_key.is_empty() and solar_shadow.z>0.0:
			var tip=Vector2(solar_shadow.x,solar_shadow.y)
			var shade=Color(.14,.17,.16,solar_shadow.z)
			draw_set_transform(tip*.45,tip.angle(),Vector2(maxf(12.0,tip.length()*.68),6.0))
			draw_circle(Vector2.ZERO,1.0,shade)
			draw_set_transform(Vector2.ZERO)
		var color=tint
		if not lit and kind in ["lamp","street_lamp","trace"]: color*=Color(.48,.55,.62)
		var root_offset=roundf(size.y*4.0/tex.get_height()) if not wind_key.is_empty() or kind in ["flowers","stone","rock"] else 0.0
		var bounds:=Rect2(-floor(size.x/2),-size.y+root_offset,size.x,size.y)
		draw_texture_rect(tex,bounds,false,color)
		if glass and window_light>0.0: draw_texture_rect(glass,bounds,false,Color(1,1,1,window_light))
		if focused: draw_rect(Rect2(-floor(size.x/2)-2,-size.y-2,size.x+4,size.y+4),Color("bce3ac"),false,1)
		return
	if kind == "house":
		draw_rect(Rect2(-74,-72,148,72),Color("b59b78")*tint)
		draw_rect(Rect2(-77,-16,154,16),Color("666b69"))
		for x in range(-70,72,24): draw_rect(Rect2(x,-13,20,9),Color("8f9182"))
		draw_colored_polygon(PackedVector2Array([Vector2(-86,-72),Vector2(0,-126),Vector2(86,-72)]),Color("515e5b") if variant%2==0 else Color("725355"))
		for y in range(-100,-71,9): draw_line(Vector2(-(-72-y)*1.5,y),Vector2((-72-y)*1.5,y),Color("a39174"),2)
		for x in [-52,32]:
			draw_rect(Rect2(x,-57,22,24),Color("514e4c"))
			draw_rect(Rect2(x+3,-54,16,18),Color("dfb873"))
			draw_line(Vector2(x+11,-54),Vector2(x+11,-36),Color("67584b"),2)
		draw_rect(Rect2(-15,-46,30,46),Color("584c48"))
		draw_rect(Rect2(-11,-42,22,42),Color("93735b"))
		draw_rect(Rect2(-22,-1,44,8),Color("b8b39b"))
	elif kind == "shelf":
		draw_rect(Rect2(-38,-58,76,58),Color("514948"))
		for row in range(3):
			for col in range(9): draw_rect(Rect2(-33+col*7,-52+row*17,5,13),[Color("867c65"),Color("758b81"),Color("a47c73")][(row+col)%3])
			draw_rect(Rect2(-37,-37+row*17,74,3),Color("b09a78"))
	elif kind == "well":
		draw_circle(Vector2(0,-10),27,Color("6f7b79"))
		draw_circle(Vector2(0,-13),18,Color("233e48"))
		draw_arc(Vector2(0,-13),23,0,TAU,20,Color("b1baa3"),5)
	elif kind == "relay":
		draw_rect(Rect2(-23,-44,46,44),Color("404f51"))
		draw_rect(Rect2(-19,-40,38,31),Color("9aab99"))
		for i in range(3): draw_rect(Rect2(-13+i*10,-34,5,18),Color("d9b66e"))
	elif kind == "mirror":
		draw_rect(Rect2(-17,-52,34,52),Color("ab9c7c"))
		draw_rect(Rect2(-13,-48,26,42),Color("728b9c")*tint)
		draw_line(Vector2(-10,-14),Vector2(9,-42),Color("c4d9d0"),2)
	elif kind == "clock":
		draw_rect(Rect2(-19,-62,38,62),Color("695648"))
		draw_circle(Vector2(0,-43),14,Color("d8c89a"))
		draw_line(Vector2(0,-43),Vector2(0,-54),Color("4b454b"),2)
		draw_line(Vector2(0,-43),Vector2(9,-39),Color("4b454b"),2)
		draw_line(Vector2(0,-24),Vector2(0,-8),Color("d8b777"),2)
	elif kind == "stone":
		draw_colored_polygon(PackedVector2Array([Vector2(-23,0),Vector2(-30,-19),Vector2(-8,-34),Vector2(22,-25),Vector2(29,0)]),Color("677979"))
		draw_line(Vector2(-23,-19),Vector2(-8,-29),Color("afbcad"),3)
	elif kind == "trace":
		draw_rect(Rect2(-3,-38,6,38),Color("624d3a"))
		draw_rect(Rect2(-3,-38,25,4),Color("a58b5c"))
		draw_rect(Rect2(12,-34,2,7),Color("405752"))
		draw_rect(Rect2(6,-27,16,19),Color("354c48"))
		draw_rect(Rect2(9,-24,10,12),Color("f2ce7a"))
		draw_rect(Rect2(12,-22,4,8),Color("ffebad"))
	elif kind in ["photo","poster","catalog","schematic"]:
		var paper=Color("c1aa7c") if kind=="schematic" else Color("dfd6b6")
		draw_rect(Rect2(-12,-22,24,22),Color("5b4c3e"))
		draw_rect(Rect2(-10,-20,20,18),paper)
		if kind=="photo":
			draw_rect(Rect2(-7,-17,14,10),Color("648b85"))
			draw_rect(Rect2(-2,-16,5,6),Color("cbaa85"))
			draw_rect(Rect2(-4,-10,9,3),Color("5d6552"))
		elif kind=="schematic":
			for x in [-6,0,6]:
				draw_rect(Rect2(x,-17,2,10),Color("667e77"))
				draw_rect(Rect2(x,-15,5,2),Color("667e77"))
		else:
			for y in [-17,-12,-7]: draw_rect(Rect2(-7,y,14,2),Color("8c6b54"))
	elif kind=="ribbon":
		for i in range(5): draw_rect(Rect2(-11+i*4,-15+posmod(i,2)*3,6,5),Color("be778e"))
	elif kind=="key":
		draw_rect(Rect2(-10,-17,9,9),Color("d1b66f"))
		draw_rect(Rect2(-7,-14,3,3),Color("5e654b"))
		draw_rect(Rect2(-2,-14,14,3),Color("d1b66f"))
		draw_rect(Rect2(6,-14,3,7),Color("d1b66f"))
	else:
		draw_rect(Rect2(-7,-11,14,11),Color("d9c293"))
		draw_line(Vector2(-4,-7),Vector2(4,-7),Color("73605b"),1)
