extends RefCounted
## Original four-direction pixel rigs. Columns 4 and 5 are resting and blinking.
const REST_FRAME=4
const BLINK_FRAME=5
const EVENTS=["letter","guest","epochs","machine","bridge","memory","garden","crowd","train","collision","alina","shore"]
const OWNERS=["lev","guest","sonya","lev","pavel","child","child","nadia","pavel","mara","alina","sonya"]
const PROFILES={
	"lev":["674634","8e663e","deb57e","short"],
	"guest":["b6a58b","645675","cbb48c","hood"],
	"sonya":["81493d","8f6273","e3aa9b","braid"],
	"pavel":["443832","426470","d3a46e","short"],
	"child":["775039","548d87","c0b271","child"],
	"nadia":["574035","668357","e4bd82","bob"],
	"mara":["b7a992","577680","e2bd88","bun"],
	"alina":["303737","647750","a1aa7b","long"]}
static var cache={}
static func height(id: String) -> float: return 28.0 if id=="child" else 52.0
static func portrait(index: int) -> AtlasTexture:
	var texture=load("res://after_silence/assets/portraits0190/event_portraits.png")
	var result=AtlasTexture.new();result.atlas=texture
	var cell=texture.get_size()/Vector2(4,3)
	result.region=Rect2(Vector2(index%4,index/4)*cell,cell)
	return result
static func sheet(id: String, event: String="") -> Texture2D:
	var key=id+":"+event
	if cache.has(key): return cache[key]
	var profile=PROFILES.get(id,PROFILES.guest)
	var hair=Color(profile[0]);var coat=Color(profile[1]);var trim=Color(profile[2])
	if event=="garden": coat=Color("bd9c50");trim=Color("73945b")
	if event=="machine": coat=Color("535650");trim=Color("a9946b")
	if event=="train": coat=Color("b28b50");trim=Color("d2c8ad")
	if event=="shore": coat=Color("5e768f");trim=Color("a8b9bc")
	var image=Image.create(384,384,false,Image.FORMAT_RGBA8)
	for direction in range(4):
		for frame in range(6):
			_paint(image,Vector2i(frame*64,direction*96),direction,frame,id,profile[3],hair,coat,trim,event)
	cache[key]=ImageTexture.create_from_image(image)
	return cache[key]
static func rect(image: Image, origin: Vector2i, x: int,y: int,w: int,h: int,color: Color):
	image.fill_rect(Rect2i(origin+Vector2i(x,y),Vector2i(w,h)),color)
static func oval(image: Image,origin: Vector2i,center: Vector2i,radius: Vector2i,color: Color):
	for y in range(-radius.y,radius.y+1):
		for x in range(-radius.x,radius.x+1):
			if pow(float(x)/radius.x,2)+pow(float(y)/radius.y,2)<=1.05: image.set_pixelv(origin+center+Vector2i(x,y),color)
static func _paint(image: Image,o: Vector2i,d: int,f: int,id: String,style: String,hair: Color,coat: Color,trim: Color,event: String):
	var ink=Color("312b2a");var skin=Color("ce9b77");var light=Color("f3cb9c")
	var child=id=="child"
	var swing=[0,-2,0,2,0,0][f];var head_y=60 if child else 51
	var top=72 if child else 64
	var side=d>=2;var back=d==1;var facing=-1 if d==2 else 1
	# Feet move in opposite phases; the baseline remains fixed for collisions.
	for leg in range(2):
		var shift=swing if leg==0 else -swing
		var x=27+leg*7+(shift if side else 0)
		rect(image,o,x,81,5,7,ink)
		rect(image,o,x+1,81,3,5,Color("a29a7d") if child else Color("655d54"))
		rect(image,o,x-1,86+(0 if side else absi(shift)/2),7,3,ink)
		rect(image,o,x,86+(0 if side else absi(shift)/2),5,1,trim)
	# Coat, shirt, seams and sleeves.
	rect(image,o,22 if not side else 25,top,20 if not side else 14,83-top,ink)
	rect(image,o,24 if not side else 27,top+1,16 if not side else 10,81-top,coat)
	rect(image,o,26,top+2,2,79-top,coat.lightened(.18))
	rect(image,o,37 if not side else 34,top+3,2,77-top,coat.darkened(.25))
	rect(image,o,26,80,12,2,coat.darkened(.18))
	rect(image,o,30,top+1,4,4,trim)
	if not back:
		rect(image,o,32,top+5,1,76-top,coat.darkened(.25))
		for y in range(top+5,79,4): rect(image,o,33,y,1,1,trim)
	if style in ["braid","bob","long","bun"]:
		rect(image,o,22,78,20,6,ink);rect(image,o,24,78,16,4,coat)
	if child:
		rect(image,o,25,80,14,3,Color("5b6c68"))
		rect(image,o,25,top+1,14,2,trim)
	for arm in range(2):
		if side and arm==0: continue
		var x=(20 if arm==0 else 40) if not side else (24 if facing<0 else 37)
		var dy=swing if arm==0 else -swing
		rect(image,o,x,top+2+dy,4,9,ink)
		rect(image,o,x+1,top+3+dy,2,6,coat)
		rect(image,o,x+1,top+8+dy,2,3,skin)
	# Hair silhouette and rounded chibi face.
	oval(image,o,Vector2i(32,head_y),Vector2i(12 if not side else 10,13),ink)
	oval(image,o,Vector2i(32,head_y-1),Vector2i(11 if not side else 9,12),hair)
	if not back:
		oval(image,o,Vector2i(32+(facing*3 if side else 0),head_y+3),Vector2i(8 if not side else 7,8),skin)
		oval(image,o,Vector2i(32+(facing*3 if side else 0),head_y+1),Vector2i(7 if not side else 6,5),light)
		for eye in ([32+facing*6] if side else [28,36]):
			if f==BLINK_FRAME:
				rect(image,o,eye,head_y+4,2,1,ink)
			else:
				rect(image,o,eye,head_y+2,2,3,ink)
				rect(image,o,eye,head_y+2,1,1,Color("fff0c5"))
		rect(image,o,31+facing if side else 31,head_y+8,3,1,Color("945d53"))
		rect(image,o,36 if side else 25,head_y+6,2,1,Color("cc8d75"))
		rect(image,o,24 if not side else 29,head_y-4,12,4,hair)
		rect(image,o,24 if not side else 29,head_y,5,4,hair)
	for i in range(4): rect(image,o,22+i*5,head_y-11+(i%2)*2,5,3,hair.lightened(.1))
	if style=="child":
		for i in range(3): rect(image,o,25+i*5,head_y-15+i%2,4,5,hair)
	if style in ["long","braid"]:
		for i in range(5): rect(image,o,21 if style=="long" else 41-(i%2),head_y+i*4,4,5,hair.darkened(.05 if i%2 else 0))
	if style=="bob": rect(image,o,20,head_y,4,14,hair);rect(image,o,40,head_y,4,14,hair)
	if style=="bun":
		oval(image,o,Vector2i(25,head_y-12),Vector2i(5,5),hair)
		rect(image,o,23,head_y-8,6,2,trim)
	if style=="hood":
		rect(image,o,19,head_y-8,3,23,coat);rect(image,o,42,head_y-8,3,23,coat)
	_outfit(image,o,id,top,head_y,trim,side,back,facing)
	if event=="machine":
		rect(image,o,23,head_y-8,18,2,trim)
		for x in [25,34]: rect(image,o,x,head_y-10,5,4,ink);rect(image,o,x+1,head_y-9,3,2,trim)
	if event=="train": rect(image,o,27,top+8,8,2,trim);rect(image,o,30,top+5,2,8,trim)
	if event=="garden": rect(image,o,39,head_y-10,5,3,trim)

static func _outfit(image: Image,o: Vector2i,id: String,top: int,head_y: int,trim: Color,side: bool,back: bool,facing: int):
	var chest=32+2*facing if side else 32
	match id:
		"lev":
			if not back:
				rect(image,o,chest-4,top+6,9,10,Color("614a3b"))
				rect(image,o,chest-2,top+8,6,1,trim.darkened(.19))
				rect(image,o,chest+2,top+10,2,5,Color("a29279"))
		"pavel":
			rect(image,o,chest-5,top,10,3,trim)
			rect(image,o,chest+2,top+3,3,7,trim.darkened(.17))
		"nadia","mara":
			if not back:
				rect(image,o,chest-5,top+6,3,3,trim)
				rect(image,o,chest-4,top+6,1,1,Color("fff1c0"))
			rect(image,o,chest-5,top+13,10,2,trim.darkened(.28))
		"sonya":
			rect(image,o,39,head_y+10,5,3,trim)
			rect(image,o,42,head_y+13,2,4,trim.darkened(.18))
		"alina":
			rect(image,o,23,head_y-6,4,3,trim)
			rect(image,o,24,head_y-7,2,5,trim)
			rect(image,o,24,head_y-6,1,1,Color("f3d69d"))
		"child":
			rect(image,o,chest-4,top+4,2,7,Color("d7b27d"))
			rect(image,o,chest-5,top+8,6,4,Color("997253"))
		"guest":
			rect(image,o,chest-4,top+2,8,1,trim)
			if not back: rect(image,o,chest,top+3,2,3,trim)
