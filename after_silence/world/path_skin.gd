extends Node2D
const Water=preload("res://after_silence/world/watercourse.gd")
const Garden=preload("res://after_silence/world/garden_pixels.gd")
const Art=preload("res://after_silence/core/ppae_art.gd")
var world

func _ready() -> void:
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED

func _draw():
	_meadow()
	# Paint each layer across all segments so intersections merge into one road.
	var colors=[Color("8d8063"),Color("ab916a")]
	for layer in range(colors.size()):
		for path in world.paths:
			var radius: float=path[2]+5-layer*4
			draw_line(path[0],path[1],colors[layer],radius*2)
			draw_circle(path[0],radius,colors[layer])
			draw_circle(path[1],radius,colors[layer])
	var material:=Art.texture("dirt")
	for path in world.paths:
		var a: Vector2=path[0]
		var b: Vector2=path[1]
		var angle=a.angle_to_point(b)
		var points:=PackedVector2Array()
		var uvs:=PackedVector2Array()
		for i in range(18):
			var end:=b if i<9 else a
			var offset:=float(i%9)/8.0*PI-PI*.5+(0.0 if i<9 else PI)
			var at: Vector2=(end+Vector2.from_angle(angle+offset)*(path[2]-2.0)).round()
			points.append(at)
			uvs.append(at/material.get_size())
		draw_polygon(points,PackedColorArray([Color("ffffffce")]),uvs,material)
	for y in range(35,int(world.dimensions.y)-24,9):
		for x in range(35,int(world.dimensions.x)-24,9):
			var seed_value=posmod(x*73856093 ^ y*19349663,101)
			if seed_value>23: continue
			var p=Vector2(x+seed_value%7,y+seed_value%5)
			if world.on_path(p,-7):
				var tint=Color("9e906b") if seed_value<13 else Color("c6b38a")
				draw_rect(Rect2(p,Vector2(1+seed_value%3,1)),tint)
				if seed_value<5: draw_rect(Rect2(p+Vector2(1,-1),Vector2(2,1)),Color("d4bc91"))

func _meadow():
	var palettes={
		"town":[Color("a2aa714e"),Color("687e514f")],
		"orchard":[Color("b9b77960"),Color("73844d4e")],
		"harbor":[Color("c2b18872"),Color("7d8e6555")],
		"forest":[Color("9ca8734c"),Color("435b4560")]
	}
	var colors: Array=palettes[world.zone]
	for y in range(65,int(world.dimensions.y)-28,73):
		for x in range(67,int(world.dimensions.x)-35,87):
			var seed_value=posmod(x*73856093 ^ y*19349663,101)
			var center=Vector2(x+seed_value%51-25,y+seed_value%39-19)
			if world.on_path(center,11) or Water.depth(world.zone,center)>-25: continue
			var width=28+seed_value%31
			var height=12+seed_value%23
			var tint: Color=colors[seed_value%2]
			tint.a*=.46
			for step in [.82,1.0,1.13]:
				var contour=PackedVector2Array()
				for i in range(18):
					var angle=TAU*i/18
					var edge=step*(1.0+.12*sin(seed_value+i*2.7))
					contour.append((center+Vector2(cos(angle)*width,sin(angle)*height)*edge).round())
				draw_colored_polygon(contour,tint)
			for i in range(4):
				var at=center+Vector2(posmod((seed_value+i*19)*37,55)-27,posmod((seed_value+i*7)*17,33)-16)
				if world.on_path(at,4) or Water.depth(world.zone,at)>-16: continue
				var green=Color("697b50") if world.zone!="forest" else Color("50694c")
				draw_line(at,at+Vector2(-2,-4),green,1)
				draw_line(at,at+Vector2(1,-6),green,1)
				if (seed_value+i)%11<2: Garden.bunch(self,at,posmod(seed_value+i,12),0,3)
