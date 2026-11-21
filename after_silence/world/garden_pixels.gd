extends RefCounted
const STEM=Color("526b43")
const LEAF=[Color("698453"),Color("78915a"),Color("899962")]
const PETALS=[Color("c09385"),Color("d1b57f"),Color("aaa6ba"),Color("c1b595")]

static func bunch(canvas: CanvasItem, at: Vector2, seed_value: int, sway: int=0, count: int=5):
	for i in range(count):
		var seed=posmod(seed_value*31+i*47,97)
		var base=at+Vector2(i*4-(count-1)*2,seed%4)
		var tip=base+Vector2((seed%3)-1+sway,-6-seed%9)
		canvas.draw_line(base,tip,STEM,1)
		canvas.draw_rect(Rect2(base+Vector2(-2,-4),Vector2(3,2)),LEAF[seed%LEAF.size()])
		canvas.draw_rect(Rect2(base+Vector2(0,-7),Vector2(2,2)),LEAF[(seed+1)%LEAF.size()])
		var color: Color=PETALS[(seed_value+i/3)%PETALS.size()]
		canvas.draw_rect(Rect2(tip-Vector2(2,0),Vector2(5,2)),color.darkened(.19))
		canvas.draw_rect(Rect2(tip-Vector2(1,1),Vector2(3,3)),color)
		canvas.draw_rect(Rect2(tip,Vector2(1,1)),Color("e3c791"))

static func planter(canvas: CanvasItem, at: Vector2, seed_value: int,sway: int=0):
	var box=Rect2(at-Vector2(14,6),Vector2(28,13))
	var stone=seed_value%3==1
	var material=Color("837d66") if stone else Color("855f46")
	canvas.draw_rect(Rect2(box.position+Vector2(2,4),box.size),Color("36412b62"))
	canvas.draw_rect(box,Color("534633"))
	canvas.draw_rect(box.grow(-1),material)
	canvas.draw_rect(Rect2(box.position+Vector2(1,1),Vector2(box.size.x-2,2)),material.lightened(.26))
	canvas.draw_rect(Rect2(box.position+Vector2(2,3),Vector2(box.size.x-4,3)),Color("63503d"))
	for x in [-9,-3,4,10]:
		canvas.draw_rect(Rect2(at+Vector2(x,0),Vector2(1,5)),material.darkened(.2))
	bunch(canvas,at-Vector2(0,4),seed_value,sway,6)
