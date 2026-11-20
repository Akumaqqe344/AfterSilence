extends Node2D
## Small persistent signs of a completed story scene, outside the collision grid.
var kind: String

func _draw() -> void:
	var outlines=Color("423849")
	var wood=Color("9d7965")
	var sage=Color("a3bc89")
	var peach=Color("e1aa89")
	var sky=Color("acc6dc")
	draw_rect(Rect2(-19,1,38,3),Color("433b4940"))
	if kind=="seeds":
		draw_rect(Rect2(-18,-7,36,8),outlines)
		draw_rect(Rect2(-16,-7,32,5),wood)
		for i in range(6):
			var x=-13+i*5
			var y=-13-i%3
			draw_rect(Rect2(x,-12,1,6),sage)
			draw_rect(Rect2(x-1,y,3,3),[peach,sky,Color("dfc98f")][i%3])
		return
	draw_rect(Rect2(-12,-10,24,11),outlines)
	draw_rect(Rect2(-13,-11,26,4),wood)
	draw_rect(Rect2(-10,-7,3,7),wood.darkened(.23))
	draw_rect(Rect2(7,-7,3,7),wood.darkened(.23))
	match kind:
		"tubes":
			for i in range(3):
				draw_rect(Rect2(-9+i*6,-19,5,8),outlines)
				draw_rect(Rect2(-8+i*6,-16,3,4),[peach,sage,sky][i])
		"pairs","shelves":
			for i in range(3):
				draw_rect(Rect2(-10+i*7,-16,6,6),[peach,sage,sky][i])
				draw_rect(Rect2(-9+i*7,-15,2,2),outlines)
		"lights":
			draw_rect(Rect2(-8,-21,16,10),outlines)
			for i in range(3):
				draw_rect(Rect2(-6+i*5,-18,2,4),Color("e9c893"))
