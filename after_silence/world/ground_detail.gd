extends Node2D
var zone="town"
var distorted=false
var dimensions=Vector2.ZERO
var water=preload("res://after_silence/world/surface_textures.gd").atlas("water")
var rug=preload("res://after_silence/assets/art100/rug.png")
const Water=preload("res://after_silence/world/watercourse.gd")
func draw_shore():
	for y in range(16,int(dimensions.y),4):
		for x in range(16,int(dimensions.x),4):
			var p=Vector2(x+2,y+2)
			var depth=Water.depth(zone,p)
			if depth< -16: continue
			var rect=Rect2(x,y,4,4)
			if depth< -8: draw_rect(rect,Color("83916a") if depth< -12 else Color("919971"))
			elif depth<0:
				draw_rect(rect,Color("c9b184") if depth< -3 else Color("a89170"))
				if posmod(x*117+y*77,19)==0: draw_rect(Rect2(p,Vector2(2,1)),Color("e1c796"))
			else:
				draw_texture_rect_region(water,rect,Rect2(posmod(x,80),posmod(y,80),4,4))
				if depth<3: draw_rect(Rect2(x,y,4,1),Color("9fbca5"))
				elif depth>13 and posmod(x*39+y*81,59)==0: draw_rect(Rect2(x,y,4,1),Color("a7b49a55"))
			if depth< -6 and posmod(x*13+y*7,41)==0:
				draw_line(p,p+Vector2(-2,-9),Color("526e3c"),2)
				draw_line(p+Vector2(3,0),p+Vector2(4,-12),Color("7e9858"),1)
				draw_rect(Rect2(p+Vector2(3,-13),Vector2(2,5)),Color("a57d56"))
func _draw():
	if zone in ["town","harbor"]: draw_shore()
	if zone.begins_with("home_") or zone=="shop":
		for rect in [Rect2(0,0,640,64),Rect2(0,64,64,416),Rect2(576,64,64,416),Rect2(64,448,512,32)]: draw_rect(rect,Color("172126"))
		if zone.begins_with("home_"):
			draw_rect(Rect2(80,81,480,19),Color("ae8b6b"))
			draw_rect(Rect2(80,99,480,3),Color("866349"))
			for x in range(84,556,18): draw_rect(Rect2(x,83,1,16),Color("927255"))
			draw_rect(Rect2(288,428,64,19),Color("634e42"))
			draw_rect(Rect2(288,428,64,3),Color("ac8968"))
		for rect in [Rect2(64,64,512,16),Rect2(64,80,16,352),Rect2(560,80,16,352),Rect2(80,432,208,16),Rect2(352,432,208,16)]:
			draw_rect(rect,Color("574b45"))
			draw_rect(Rect2(rect.position,Vector2(rect.size.x,3)),Color("bb9b79"))
		return
	if zone=="library":
		draw_rect(Rect2(80,75,800,20),Color("574b45"))
		draw_rect(Rect2(80,95,800,36),Color("a09178"))
		for x in range(100,880,32): draw_line(Vector2(x,98),Vector2(x,127),Color("817660"))
		for x in [80,864]: draw_rect(Rect2(x,95,16,515),Color("574b45"))
		for x in [96,525]: draw_rect(Rect2(x,610,339,16),Color("574b45"))
		draw_texture_rect(rug,Rect2(432,380,96,64),false)
		return
func paint_ellipse(center: Vector2,radius: Vector2,color: Color):
	draw_set_transform(center,0,radius)
	draw_circle(Vector2.ZERO,1,color)
	draw_set_transform(Vector2.ZERO)
