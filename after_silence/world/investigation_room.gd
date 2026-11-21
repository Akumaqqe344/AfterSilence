extends Node2D
const PAPER=preload("res://after_silence/assets/investigations0320/paper.png")
const METAL=preload("res://after_silence/assets/investigations0320/metal.png")
const FIXTURES=preload("res://after_silence/assets/investigations0320/fixtures.png")
const Furnishing=preload("res://after_silence/world/home_furnishing.gd")
@export var industrial=false

func mount(world):
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index=-2
	for wall in [Rect2(0,0,640,88),Rect2(0,88,64,392),Rect2(576,88,64,392),Rect2(64,432,512,48)]:
		world.boundary(wall)
	if not industrial:
		world.boundary(Rect2(272,151,84,23))
	var furniture=[
		["shelf",Rect2(82,126,74,57)],["books",Rect2(444,119,103,59)],
		[Rect2(0,0,80,27),Rect2(241,213,155,46)],["chair",Rect2(123,283,32,26)],
		["storage",Rect2(475,298,70,45)],["rug",Rect2(225,332,186,90)]
	]
	if industrial:
		furniture=[
			["rack",Rect2(88,126,81,54)],["toolbox",Rect2(439,128,103,66)],
			[Rect2(0,32,80,27),Rect2(229,200,164,51)],["barrel",Rect2(110,295,47,34)],
			["storage",Rect2(489,298,58,62)]
		]
	for entry in furniture:
		var area: Rect2=entry[1]
		if entry[0] is Rect2:
			var sprite=Sprite2D.new()
			var region: Rect2=entry[0]
			sprite.texture=FIXTURES
			sprite.region_enabled=true
			sprite.region_rect=region
			sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale=area.size/region.size
			sprite.position=Vector2(area.get_center().x,area.end.y)
			sprite.offset=Vector2(0,-region.size.y*.5)
			world.sorter.add_child(sprite)
			world.boundary(area)
			continue
		var node=Furnishing.new()
		node.kind=entry[0]
		node.position=Vector2(area.get_center().x,area.end.y)
		node.extent=area.size
		node.tint=Color("8c9e8b") if industrial else Color("b3907b")
		world.sorter.add_child(node)
		if node.solid(): world.boundary(area)
		else: node.z_index=-1

func _draw():
	draw_rect(Rect2(0,0,640,480),Color("25232a"))
	draw_texture_rect(METAL if industrial else PAPER,Rect2(64,87,512,349),true)
	var trim=Color("98a99d") if industrial else Color("be9877")
	for wall in [Rect2(63,86,514,6),Rect2(63,90,5,345),Rect2(572,90,5,345),Rect2(64,428,224,5),Rect2(352,428,224,5)]:
		draw_rect(wall,trim)
	draw_rect(Rect2(292,426,56,10),Color("776a61"))
	if industrial:
		for y in [105,113]:
			draw_rect(Rect2(72,y,495,4),Color("687e78"))
			for x in range(96,565,75): draw_rect(Rect2(x,y-3,8,9),Color("b39976"))
		draw_texture_rect_region(FIXTURES,Rect2(255,359,130,42),Rect2(82,69,70,23))
		for x in [177,427]:
			draw_rect(Rect2(x,123,8,64),Color("324742"))
			draw_rect(Rect2(x+2,123,3,63),Color("7d8171"))
	else:
		for x in [182,280,378]:
			draw_rect(Rect2(x,94,35,15),Color("595954"))
			draw_rect(Rect2(x+3,95,29,11),Color("b5aaa0"))
		draw_texture_rect_region(FIXTURES,Rect2(262,110,98,66),Rect2(0,64,49,33))
