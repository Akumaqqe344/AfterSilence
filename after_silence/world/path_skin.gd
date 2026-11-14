extends Node2D
var world
func _draw():
	# Sparse, uneven grass and earth pixels instead of periodic fence-like teeth.
	for y in range(24,int(world.dimensions.y)-24,4):
		for x in range(24,int(world.dimensions.x)-24,4):
			var point=Vector2(x,y)
			if not world.on_path(point): continue
			var seed_value=posmod(x*73856093 ^ y*19349663,101)
			for offset in [Vector2(-4,0),Vector2(4,0),Vector2(0,-4),Vector2(0,4)]:
				if world.on_path(point+offset): continue
				if seed_value<55:
					draw_rect(Rect2(point+offset*.35,Vector2(2,1)),Color("a08c56"))
				if seed_value<19:
					draw_rect(Rect2(point+offset*.65+Vector2(seed_value%3,0),Vector2(1,2)),Color("6e954b"))
			if seed_value<2: draw_rect(Rect2(point+Vector2(1,1),Vector2(2,1)),Color("c4a166"))
