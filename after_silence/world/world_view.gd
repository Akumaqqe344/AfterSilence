extends Node2D
const Prop = preload("res://after_silence/world/prop.gd")
const Ground = preload("res://after_silence/world/ground_detail.gd")
var dimensions = Vector2(1280,960)
var sorter: Node2D
var terrain: TileMapLayer
var grid: AStarGrid2D
var obstacles: Array[Rect2] = []
var interactables: Array = []
var zone = "town"
var echo = false
var paths: Array=[]
var glow_texture: Texture2D
func build(id: String, distorted: bool):
	zone = id
	echo = distorted
	for child in get_children(): child.queue_free()
	obstacles.clear()
	interactables.clear()
	dimensions = {"town":Vector2(1280,960),"library":Vector2(960,720),"forest":Vector2(1504,1120)}[id]
	paths=[]
	if id=="town":
		paths=[[Vector2(600,170),Vector2(600,850),24.0],[Vector2(260,500),Vector2(1050,500),24.0]]
		for x in [260,960]:
			paths.append([Vector2(x,300),Vector2(x,740),18.0])
		paths.append([Vector2(600,170),Vector2(600,120),24.0])
	elif id=="forest":
		paths=[[Vector2(700,990),Vector2(700,520),22.0],[Vector2(510,520),Vector2(1100,520),22.0],[Vector2(1100,520),Vector2(1100,280),16.0]]
	terrain = TileMapLayer.new()
	terrain.tile_set = make_tiles()
	add_child(terrain)
	sorter = Node2D.new()
	sorter.y_sort_enabled = true
	add_child(sorter)
	for y in range(int(dimensions.y/16)):
		for x in range(int(dimensions.x/16)):
			var tile = 2 if id=="library" else 0
			if id!="library" and on_path(Vector2(x*16+8,y*16+8)): tile=1
			terrain.set_cell(Vector2i(x,y),tile,Vector2i(x%20,y%20))
	var detail=Ground.new()
	detail.zone=id
	detail.distorted=echo
	detail.dimensions=dimensions
	add_child(detail)
	detail.z_index=-1
	terrain.z_index=-2
	if id=="town": boundary(Rect2(986,92,188,116))
	boundary(Rect2(0,0,dimensions.x,24))
	boundary(Rect2(0,dimensions.y-24,dimensions.x,24))
	boundary(Rect2(0,0,24,dimensions.y))
	boundary(Rect2(dimensions.x-24,0,24,dimensions.y))
	if id=="town": build_town()
	elif id=="library": build_library()
	else: build_forest()
	decorate()
	add_light(Vector2(480,390) if id=="library" else Vector2(750,560) if id=="forest" else Vector2(600,445))
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0,0,int(dimensions.x/16),int(dimensions.y/16))
	grid.cell_size = Vector2(16,16)
	grid.offset = Vector2(8,8)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for r in obstacles:
		var a = Vector2i(r.position/16)
		var b = Vector2i(r.end/16)
		for y in range(maxi(0,a.y-1),mini(int(dimensions.y/16),b.y+2)):
			for x in range(maxi(0,a.x-1),mini(int(dimensions.x/16),b.x+2)):
				if r.grow(5).has_point(Vector2(x*16+8,y*16+8)): grid.set_point_solid(Vector2i(x,y))
func make_tiles() -> TileSet:
	var tiles=TileSet.new()
	tiles.tile_size=Vector2i(16,16)
	for i in range(3):
		var texture=load("res://after_silence/assets/pechatai/"+["world/grass","world/dirt","interior/floor"][i]+".png")
		var image=texture.get_image()
		image.resize(320,320,Image.INTERPOLATE_NEAREST)
		var source=TileSetAtlasSource.new()
		source.texture=ImageTexture.create_from_image(image)
		source.texture_region_size=Vector2i(16,16)
		for y in range(20):
			for x in range(20): source.create_tile(Vector2i(x,y))
		tiles.add_source(source,i)
	return tiles
func boundary(r: Rect2):
	obstacles.append(r)
	var body=StaticBody2D.new()
	body.position=r.get_center()
	var shape=CollisionShape2D.new()
	var rect=RectangleShape2D.new()
	rect.size=r.size
	shape.shape=rect
	body.add_child(shape)
	add_child(body)
func prop(kind: String, p: Vector2, variant: int=0):
	var node=Prop.new()
	node.kind=kind
	node.position=p
	node.variant=variant
	if kind=="tree":
		node.tex=load("res://after_silence/assets/pechatai/world/tree-"+str(posmod(variant,3))+".png")
		node.size=Vector2(100,110)
		node.tint=Color("9fa5bc") if echo else Color.WHITE
	elif kind=="house":
		node.tex=load("res://after_silence/assets/pechatai/world/house-"+str(variant%4)+".png")
		node.size=Vector2(176,160)
	elif kind=="library":
		node.tex=load("res://after_silence/assets/pechatai/world/house-2.png")
		node.size=Vector2(176,170)
	elif kind in ["flowers","rock","well","stone"]:
		var file="sanctuary" if kind=="well" else "rock" if kind=="stone" else kind
		node.tex=load("res://after_silence/assets/pechatai/world/"+file+".png")
		node.size=Vector2(60,40) if kind in ["rock","stone"] else Vector2(100,70) if kind=="well" else Vector2(40,20)
	elif kind in ["shelf","mirror","lamp","desk","rug","plant","window","clock"]:
		var file="bookshelf" if kind=="shelf" else kind
		node.tex=load("res://after_silence/assets/pechatai/interior/"+file+".png")
		node.size=node.tex.get_size()*2
		if kind=="clock": node.size=Vector2(38,62)
	sorter.add_child(node)
	if kind=="house": boundary(Rect2(p+Vector2(-74,-68),Vector2(148,68)))
	elif kind=="shelf": boundary(Rect2(p+Vector2(-38,-16),Vector2(76,16)))
	elif kind=="tree": boundary(Rect2(p+Vector2(-6,-5),Vector2(12,9)))
	elif kind in ["relay","clock","mirror","stone","well"]: boundary(Rect2(p+Vector2(-14,-10),Vector2(28,12)))
	return node
func on_path(p: Vector2) -> bool:
	for segment in paths:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,segment[0],segment[1]))<=segment[2]: return true
	return false
func add_light(p: Vector2):
	if not glow_texture:
		var image=Image.create(64,64,false,Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var strength=maxf(0,1.0-Vector2(x-32,y-32).length()/32)
				image.set_pixel(x,y,Color(1,1,1,strength*strength))
		glow_texture=ImageTexture.create_from_image(image)
	var light=PointLight2D.new()
	light.texture=glow_texture
	light.position=p
	light.texture_scale=3
	light.color=Color("97bfd0") if echo else Color("f1ce8b")
	light.energy=.7 if echo else .35
	add_child(light)
func decorate():
	if zone=="library": return
	for y in range(80,int(dimensions.y)-50,64):
		for x in range(150,int(dimensions.x)-100,92):
			var p=Vector2(x+posmod(y,31),y+posmod(x,17))
			if not on_path(p) and posmod(x+y,7)<3: prop("flowers",p)
	if zone=="town":
		prop("library",Vector2(600,145))
		boundary(Rect2(526,72,148,73))
		for p in [Vector2(420,320),Vector2(780,320),Vector2(430,730),Vector2(790,790),Vector2(1080,570),Vector2(180,560)]: prop("tree",p,int(p.x)%3)
func spot(id: String,p: Vector2,kind: String="note"):
	interactables.append({"id":id,"position":p})
	if kind!="none": prop(kind,p)
func build_town():
	for i in range(4):
		var p=[Vector2(260,300),Vector2(960,300),Vector2(260,740),Vector2(960,740)][i]
		if echo: p+=Vector2(40 if i%2 else -40,32)
		prop("house",p,i)
	for y in range(90,920,76):
		for x in [90,1150]: prop("tree",Vector2(x,y))
	prop("well",Vector2(600,445))
	spot("photo",Vector2(510,490))
	spot("poster",Vector2(780,480))
	spot("well",Vector2(600,490),"none")
	spot("to_library",Vector2(600,170),"trace")
	spot("to_forest",Vector2(600,850),"trace")
	spot("ribbon",Vector2(1020,780))
func build_library():
	for r in [Rect2(80,75,800,16),Rect2(80,90,16,520),Rect2(864,90,16,520),Rect2(80,610,355,16),Rect2(525,610,355,16)]: boundary(r)
	for p in [Vector2(200,230),Vector2(350,230),Vector2(650,230),Vector2(780,230),Vector2(200,410),Vector2(780,410)]:
		if echo and p.x==350: p+=Vector2(80,95)
		prop("shelf",p)
	spot("catalog",Vector2(350,280),"note")
	prop("desk",Vector2(650,550))
	boundary(Rect2(614,530,72,20))
	prop("window",Vector2(480,130))
	prop("lamp",Vector2(370,470))
	prop("plant",Vector2(820,575))
	spot("clock",Vector2(650,330),"clock")
	spot("diagram",Vector2(780,460))
	spot("mirror",Vector2(480,390),"mirror")
	spot("library_light",Vector2(200,480),"relay")
	spot("signature",Vector2(650,470))
	spot("to_town",Vector2(480,590),"trace")
func build_forest():
	for y in range(85,1060,60):
		for x in range(90,1440,62):
			if abs(x-700)<75 or abs(y-520)<65 or (x>950 and y<390) or (abs(x-510)<70 and y>420 and y<560): continue
			prop("tree",Vector2(x+(9 if y%3 else -6),y),x+y)
	if not echo: boundary(Rect2(900,120,32,280))
	else:
		prop("stone",Vector2(870,400))
		spot("trace",Vector2(1080,300),"trace")
	spot("relay",Vector2(510,500),"relay")
	spot("mirror",Vector2(750,560),"mirror")
	spot("shelter",Vector2(990,520),"stone")
	spot("to_town",Vector2(700,990),"trace")
func cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/16),floori(p.y/16))
func walkable(p: Vector2) -> bool:
	var c=cell(p)
	return grid.is_in_boundsv(c) and not grid.is_point_solid(c)
func recover(p: Vector2) -> Vector2:
	if walkable(p): return p
	for ring in range(1,20):
		for angle in range(16):
			var q=p+Vector2.from_angle(angle*TAU/16)*ring*16
			if walkable(q): return q
	return Vector2(600,500) if zone=="town" else Vector2(480,580) if zone=="library" else Vector2(700,940)
func path_between(a: Vector2,b: Vector2) -> PackedVector2Array:
	var start=cell(recover(a))
	var end=cell(recover(b))
	return grid.get_point_path(start,end)
func sees(a: Vector2,b: Vector2) -> bool:
	var n=maxi(1,int(a.distance_to(b)/8))
	for i in range(1,n):
		if not walkable(a.lerp(b,float(i)/n)): return false
	return true
