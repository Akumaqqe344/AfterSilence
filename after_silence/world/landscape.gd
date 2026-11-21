extends RefCounted
const Landmarks=preload("res://after_silence/world/district_landmarks.gd")
const Water=preload("res://after_silence/world/watercourse.gd")
static func build(world):
	if world.zone not in ["town","forest","orchard","harbor"]: return
	if world.zone=="town":
		for x in [600,1450]: world.prop("bridge",Vector2(x,Water.river_y(x)+44))
		world.prop("shop_front",Vector2(350,440))
		world.boundary(Rect2(276,372,148,68))
		world.spot("visit_shop",Vector2(350,468),"none")
		world.prop("gazebo",Vector2(1270,950))
		world.boundary(Rect2(1224,916,92,20))
		world.spot("riverside_rest",Vector2(1270,974),"none")
		for entry in preload("res://after_silence/world/homes.gd").exteriors("town",world.echo):
			if not entry[2].begins_with("hamlet_"): continue
			world.prop("house",entry[0],entry[1])
			world.spot(entry[2],entry[0]+Vector2(0,28),"none")
		world.prop("village_board",Vector2(840,470))
		world.spot("village_hints",Vector2(840,494),"none")
	# Water rectangles use the exact same field as the renderer. Adjacent blocked
	# grid cells are merged into horizontal runs to keep physics lightweight.
	for y in range(24,int(world.dimensions.y)-24,16):
		var start=-1
		for x in range(24,int(world.dimensions.x)-8,16):
			var wet=x<int(world.dimensions.x)-24 and Water.blocked(world.zone,Vector2(x+8,y+8))
			if wet and start<0: start=x
			if not wet and start>=0:
				world.boundary(Rect2(start,y,x-start,16));start=-1
	var buildings=[]
	for feature in Landmarks.FEATURES.get(world.zone,[]):
		var patch: Rect2=feature[1]
		buildings.append(patch.grow_individual(17,13,17,65 if feature[0]=="soil" else 30))
	var stages=[]
	if world.story_mode:
		var places=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/locations.json"))
		for place in places.values():
			if place.zone==world.zone: stages.append(Vector2(place.point[0],place.point[1]))
	for prop in world.sorter.get_children():
		if prop.has_meta("building") or prop.kind in ["shop_front","gazebo"]: buildings.append(Rect2(prop.position-Vector2(104,170),Vector2(208,220)))
	# Seeded blue-noise-like sampling: no grid rows, rectangular clearing or
	# perfectly aligned outer tree wall. Trees keep entrances and quests clear.
	for y in range(62,int(world.dimensions.y)-20,68):
		for x in range(45,int(world.dimensions.x)-20,64):
			var seed_value=posmod(x*73856093 ^ y*19349663,997)
			var p=Vector2(x+seed_value%41-20,y+(seed_value/41)%37-18)
			# Rounded clearings leave room for the real event actors and their cues.
			if stages.any(func(center):return ((p-center)/Vector2(330,260)).length()<1): continue
			if world.on_path(p,42) or Water.depth(world.zone,p)>-36: continue
			if buildings.any(func(r):return r.has_point(p)): continue
			if world.obstacles.any(func(r):return r.grow(20).has_point(p)): continue
			if world.interactables.any(func(s):return s.position.distance_to(p)<85): continue
			var dense=world.zone=="forest" or p.x<160 or p.x>world.dimensions.x-190 or p.y<180 or p.y>world.dimensions.y-150
			if not dense and seed_value%100>38: continue
			world.prop("tree",p,seed_value%2)
