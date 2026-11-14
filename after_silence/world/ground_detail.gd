extends Node2D
var zone="town"
var distorted=false
var dimensions=Vector2.ZERO
func _draw():
	if zone=="library":
		draw_rect(Rect2(80,75,800,20),Color("574b45"))
		draw_rect(Rect2(80,95,800,36),Color("a09178"))
		for x in range(100,880,32): draw_line(Vector2(x,98),Vector2(x,127),Color("817660"))
		for x in [80,864]: draw_rect(Rect2(x,95,16,515),Color("574b45"))
		for x in [96,525]: draw_rect(Rect2(x,610,339,16),Color("574b45"))
		draw_rect(Rect2(395,330,170,245),Color("51464b"))
		draw_rect(Rect2(401,336,158,233),Color("7c605b"))
		for y in range(342,562,14): draw_line(Vector2(407,y),Vector2(553,y),Color("886c60"))
		return
	var grass=Color("526c4d") if not distorted else Color("445d64")
	for y in range(40,int(dimensions.y)-30,37):
		for x in range(40,int(dimensions.x)-30,49):
			var p=Vector2(x+posmod(y*13,35),y+posmod(x,23))
			if (x+y)%5==0: continue
			draw_line(p,p+Vector2(-2,-3),grass)
			draw_line(p,p+Vector2(2,-4),grass.lightened(.1))
	if zone=="town":
		paint_ellipse(Vector2(1080,150),Vector2(100,65),Color("759289"))
		paint_ellipse(Vector2(1080,150),Vector2(93,58),Color("375c66") if not distorted else Color("384c66"))
		for i in range(9): draw_line(Vector2(1010+i*16,140+posmod(i*7,33)),Vector2(1020+i*16,140+posmod(i*7,33)),Color("7dada7"))
func paint_ellipse(center: Vector2,radius: Vector2,color: Color):
	draw_set_transform(center,0,radius)
	draw_circle(Vector2.ZERO,1,color)
	draw_set_transform(Vector2.ZERO)
