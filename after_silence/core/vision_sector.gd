extends RefCounted
const RANGE=160.0
const HALF_ANGLE=.9
static func polygon(origin: Vector2,direction: Vector2,walkable: Callable) -> PackedVector2Array:
	var result=PackedVector2Array([origin])
	var angle=direction.angle()
	for i in range(65):
		var ray=Vector2.from_angle(angle-HALF_ANGLE+float(i)*HALF_ANGLE*2/64)
		var end=origin
		for distance in range(2,161,2):
			var point=origin+ray*distance
			if not walkable.call(point): break
			end=point
		result.append(end)
	return result
static func contains_body(sector: PackedVector2Array,feet: Vector2,height: float) -> bool:
	# Test the visible torso/head as well as the feet. Rendering and detection
	# share precisely this polygon, including occlusion and both boundary rays.
	for point in [Vector2(0,-3),Vector2(-4,-10),Vector2(4,-10),Vector2(-4,-height*.45),Vector2(4,-height*.45),Vector2(0,-height*.8)]:
		if Geometry2D.is_point_in_polygon(feet+point,sector): return true
	return false
