extends Node2D
var zone="town"
var distorted=false
var dimensions=Vector2.ZERO
var water=preload("res://after_silence/assets/pechatai/world/water.png")
var rug=preload("res://after_silence/assets/pechatai/interior/rug.png")
func _draw():
	if zone=="library":
		draw_rect(Rect2(80,75,800,20),Color("574b45"))
		draw_rect(Rect2(80,95,800,36),Color("a09178"))
		for x in range(100,880,32): draw_line(Vector2(x,98),Vector2(x,127),Color("817660"))
		for x in [80,864]: draw_rect(Rect2(x,95,16,515),Color("574b45"))
		for x in [96,525]: draw_rect(Rect2(x,610,339,16),Color("574b45"))
		draw_texture_rect(rug,Rect2(395,330,170,200),false)
		return
	if zone=="town":
		paint_ellipse(Vector2(1080,150),Vector2(100,65),Color("759289"))
		paint_ellipse(Vector2(1080,150),Vector2(93,58),Color("375c66") if not distorted else Color("384c66"))
		var points=PackedVector2Array()
		var uv=PackedVector2Array()
		for i in range(32):
			var unit=Vector2.from_angle(TAU*i/32)
			points.append(Vector2(1080,150)+unit*Vector2(93,58))
			uv.append((unit+Vector2.ONE)*.5)
		draw_polygon(points,PackedColorArray([Color.WHITE]),uv,water)
		for i in range(9): draw_line(Vector2(1010+i*16,140+posmod(i*7,33)),Vector2(1020+i*16,140+posmod(i*7,33)),Color("7dada7"))
func paint_ellipse(center: Vector2,radius: Vector2,color: Color):
	draw_set_transform(center,0,radius)
	draw_circle(Vector2.ZERO,1,color)
	draw_set_transform(Vector2.ZERO)
