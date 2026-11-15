extends RefCounted
# Snapshots come from the same geometry as the rendered world. No remote physics
# bodies are added to the player's World2D.
const World = preload("res://after_silence/world/world_view.gd")
const Homes = preload("res://after_silence/world/homes.gd")
var cache: Dictionary = {}

func geometry(zone: String, echo: bool, story: bool) -> Dictionary:
	var key = "%s:%s:%s" % [zone, echo, story]
	if not cache.has(key):
		var world = World.new()
		world.story_mode = story
		world.build(zone, echo)
		cache[key] = {"grid": world.grid, "size": world.dimensions, "obstacles": world.obstacles.duplicate()}
		world.free()
	return cache[key]

func walkable(nav: Dictionary, point: Vector2) -> bool:
	var cell = Vector2i(floori(point.x / 16), floori(point.y / 16))
	return nav.grid.is_in_boundsv(cell) and not nav.grid.is_point_solid(cell)

func clear_segment(nav: Dictionary, a: Vector2, b: Vector2) -> bool:
	var count = maxi(1, ceili(a.distance_to(b) / 3.0))
	for i in range(count + 1):
		var p = a.lerp(b, float(i) / count)
		if not walkable(nav, p): return false
		for obstacle in nav.obstacles:
			if obstacle.grow(5).has_point(p): return false
	return true

func path(nav: Dictionary, a: Vector2, b: Vector2) -> PackedVector2Array:
	# An invalid target is a route error, not permission to move it through a wall.
	if not walkable(nav, a) or not walkable(nav, b): return PackedVector2Array()
	var result: PackedVector2Array = nav.grid.get_point_path(Vector2i(a / 16), Vector2i(b / 16))
	if not result.is_empty():
		result[0] = a
		result.append(b)
	return result

func portals(echo: bool) -> Array:
	var result = [
		["town", Vector2(600,170), "library", Vector2(480,590)],
		["town", Vector2(600,850), "forest", Vector2(700,990)],
		["town", Vector2(1710,500), "orchard", Vector2(600,740)],
		["town", Vector2(600,1200), "harbor", Vector2(600,740)],
		["town", Vector2(350,468), "shop", Vector2(320,422)]
	]
	for id in Homes.IDS: result.append(["town", Homes.door(id,echo), id, Vector2(320,422)])
	var reverse = []
	for edge in result: reverse.append([edge[2],edge[3],edge[0],edge[1]])
	return result + reverse

func next_portal(from: String, to: String, echo: bool) -> Array:
	var queue = [[from, []]]
	var visited = {from: true}
	var edges = portals(echo)
	while not queue.is_empty():
		var item = queue.pop_front()
		for edge in edges:
			if edge[0] != item[0] or visited.has(edge[2]): continue
			var first = edge if item[1].is_empty() else item[1]
			if edge[2] == to: return first
			visited[edge[2]] = true
			queue.append([edge[2], first])
	return []
