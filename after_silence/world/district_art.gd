extends Node2D

const DETAILS=preload("res://after_silence/assets/remaster0290/ground_details.png")
const Water=preload("res://after_silence/world/watercourse.gd")
const Art=preload("res://after_silence/core/ppae_art.gd")
const STONES=[Color("a99e80"),Color("b6a586"),Color("a2987c"),Color("bba888"),Color("a9a38b")]
const BOARDS=[Color("9e7652"),Color("ad825b"),Color("b48a63"),Color("99714e")]
const LEAVES=[Color("75864c"),Color("9e9f54"),Color("a0a963"),Color("b6a362")]
static var tile_cache: Dictionary={}
var features: Array
var zone=""
var show_pier=false

func _draw():
	for feature in features:
		draw_texture_rect(_texture(feature[0],Vector2i(feature[1].size)),feature[1],false)
	if show_pier: _pier()
	match zone:
		"town":
			for x in [656,711]:
				draw_rect(Rect2(x-2,519,4,28),Color("594937"))
				draw_rect(Rect2(x-1,520,1,23),Color("a18358"))
				draw_rect(Rect2(x-4,545,8,3),Color("76654f"))
		"forest":
			_detail(Vector2(751,474),1)
			_detail(Vector2(893,457),1)
			_detail(Vector2(879,586),0)
			_detail(Vector2(766,622),1)
		"harbor":
			_detail(Vector2(966,767),1)
			draw_texture_rect_region(DETAILS,Rect2(1095,752,28,24),Rect2(56,0,28,24))

func _detail(at: Vector2,tile: int):
	var id: String=["mushroom_cluster_1","surface_pebbles","water_reed_2"][tile]
	draw_texture_rect(Art.texture(id),Rect2(at-Vector2(14,25),Vector2(28,27)),false)

func _pier():
	var dock=Water.PIER
	draw_rect(Rect2(dock.position+Vector2(0,5),dock.size),Color("2338348a"))
	draw_texture_rect(_texture("plank",Vector2i(dock.size)),dock,false)
	for y in [dock.position.y+3,dock.end.y-7]:
		draw_rect(Rect2(dock.position.x,y,dock.size.x,4),Color("6a513d"))
		draw_rect(Rect2(dock.position.x,y,dock.size.x,1),Color("c3996d"))
		for x in range(int(dock.position.x)+11,int(dock.end.x),35):
			draw_rect(Rect2(x,y-3,4,9),Color("523f32"))
			draw_rect(Rect2(x,y-4,4,3),Color("c49d72"))
	draw_rect(Rect2(dock.end.x-5,dock.position.y+4,5,dock.size.y-8),Color("816044"))
	for y in range(int(dock.position.y)+9,int(dock.end.y)-8,8):
		draw_rect(Rect2(dock.end.x-4,y,2,2),Color("ccb191"))
	var rope=dock.end-Vector2(20,17)
	for ring in range(3):
		draw_rect(Rect2(rope-Vector2(8-ring*2,4-ring),Vector2(16-ring*4,8-ring*2)),Color("d5b483"),false,1)
	draw_line(rope+Vector2(6,3),rope+Vector2(12,7),Color("d5b483"),1)

static func _texture(kind: String,dimensions: Vector2i) -> Texture2D:
	var key=kind+str(dimensions)
	if tile_cache.has(key): return tile_cache[key]
	var size_px=(Vector2(dimensions)/2.0).ceil()
	var image=Image.create(int(size_px.x),int(size_px.y),false,Image.FORMAT_RGBA8)
	var plaza: Image=Art.texture("plaza").get_image() if kind=="stone" else null
	var width=image.get_width()
	var height=image.get_height()
	for y in range(height):
		for x in range(width):
			var edge=mini(mini(x,width-x-1),mini(y,height-y-1))
			var trim=absi(posmod(x*23+y*37,7)-3)
			if kind in ["stone","rune"] and edge<trim: continue
			if kind=="stone":
				var corner=mini(x,width-x-1)+mini(y,height-y-1)
				if corner<width/9+trim: continue
			var value=posmod((x*73856093)^(y*19349663),997)
			match kind:
				"stone": image.set_pixel(x,y,plaza.get_pixel(x%64,y%48))
				"soil": image.set_pixel(x,y,_soil(x,y,width,height,value))
				"rail": image.set_pixel(x,y,_rail(x,y,height,value))
				"plank": image.set_pixel(x,y,_plank(x,y,height,value))
				"rune": image.set_pixel(x,y,_ruin(x,y,width,height,value))
	tile_cache[key]=ImageTexture.create_from_image(image)
	return tile_cache[key]

static func _stone(x: int,y: int,grain: int) -> Color:
	var row=y/7
	var offset=posmod(row*9,14)
	var column=(x+offset)/14
	var mortar=y%7==0 or (x+offset)%14==0
	if mortar: return Color("80765e")
	var stone: Color=STONES[posmod(row*17+column*37,STONES.size())]
	if y%7==1 or (x+offset)%14==1: return stone.lightened(.12)
	if y%7==6 or grain<38: return stone.darkened(.1)
	return stone

static func _soil(x: int,y: int,width: int,height: int,grain: int) -> Color:
	# Central cross-path leaves room to walk between the four raised beds.
	if absi(height/2-y)<8 or absi(width/2-x)<5: return Color("a08e64") if grain<50 else Color("ab996c")
	if x<2 or y<2 or x>=width-2 or y>=height-2: return Color("756c46")
	var row=x%12
	if row<2: return Color("a18157")
	if row<4: return Color("70573f")
	if row<8 and (y+((x/12)%2)*5)%11<6:
		var leaf: Color=LEAVES[(y/11+x/12)%LEAVES.size()]
		if grain<450: return leaf
		if grain>954: return Color("d2a66a")
	return Color("614c3a") if grain<95 else Color("77583f")

static func _rail(x: int,y: int,height: int,grain: int) -> Color:
	if y==4 or y==height-5: return Color("b2aca0")
	if y in [5,height-6]: return Color("55565a")
	if x%9<3 and y>1 and y<height-2: return Color("695244") if x%9>0 else Color("a18162")
	return Color("81796c") if grain<120 else Color("8f8774")

static func _plank(x: int,y: int,height: int,grain: int) -> Color:
	if y==0 or y==height-1: return Color("705742")
	var plank: Color=BOARDS[(x/5)%BOARDS.size()]
	if x%5==0: return plank.darkened(.23)
	if x%5==1: return plank.lightened(.12)
	if y%23==5 and x%5==3: return Color("5b4636")
	return plank.darkened(.075) if grain<43 else plank

static func _ruin(x: int,y: int,width: int,height: int,grain: int) -> Color:
	var offset=(Vector2(x,y)-Vector2(width*.5,height*.5))/Vector2(width*.5,height*.5)
	var band=offset.length()
	if band>.95: return Color.TRANSPARENT
	if band>.62 and band<.82:
		return _stone(x,y,grain).lerp(Color("6b7d5b"),.56)
	if band<.24 or (absi(x-width/2)<2 and band<.62):
		return _stone(x,y,grain).lerp(Color("6b7d5b"),.33)
	return Color("7e8a5d65") if grain<240 else Color("576d5140")
