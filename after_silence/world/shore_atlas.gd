extends RefCounted
## The raster follows the same world coordinates as Watercourse and is reused across visits.
const Water=preload("res://after_silence/world/watercourse.gd")
const Surfaces=preload("res://after_silence/world/surface_textures.gd")
const Art=preload("res://after_silence/core/ppae_art.gd")
const BOUNDS={
	"town":[Rect2i(16,928,1776,192),Rect2i(944,48,272,200)],
	"harbor":[Rect2i(908,528,292,372)]
}
static var cache: Dictionary={}

static func layers(zone: String) -> Array:
	if cache.has(zone): return cache[zone]
	var result=[]
	var water=Surfaces.atlas("water").get_image()
	for bounds in BOUNDS.get(zone,[]):
		var layers:=_raster(zone,bounds,water)
		result.append([bounds.position,layers[0],layers[1]])
	cache[zone]=result
	return result

static func _raster(zone: String,bounds: Rect2i,water: Image) -> Array:
	var image=Image.create(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8)
	var mask=Image.create(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8)
	var sand:=Art.texture("sand").get_image()
	var reeds: PackedVector2Array=[]
	for y in range(0,bounds.size.y,4):
		for x in range(0,bounds.size.x,4):
			var p=bounds.position+Vector2i(x,y)
			var depth=Water.depth(zone,Vector2(p)+Vector2(2,2))
			if depth< -16: continue
			var tile=Rect2i(x,y,4,4)
			var fleck=posmod(p.x*117+p.y*77,19)==0
			if depth< -8:
				image.fill_rect(tile,Color("859169") if depth< -12 else Color("929570"))
			elif depth<0:
				image.blit_rect(sand,Rect2i(posmod(p.x,16),posmod(p.y,16),4,4),Vector2i(x,y))
				if depth>=-3: image.fill_rect(Rect2i(x,y+2,4,2),Color("938465"))
				if fleck: image.fill_rect(Rect2i(x+1,y+2,2,1),Color("e1c796"))
			else:
				mask.fill_rect(tile,Color(clampf(depth/56.0,0,1),0,0,1))
				image.blit_rect(water,Rect2i(posmod(p.x,80),posmod(p.y,80),4,4),Vector2i(x,y))
				if depth<3: image.fill_rect(Rect2i(x,y,4,1),Color("a2b89e"))
				elif depth<9: image.fill_rect(Rect2i(x,y,4,1),Color("739589"))
				elif depth>13 and fleck: image.fill_rect(Rect2i(x,y,3,1),Color("8da798"))
			if depth< -6 and posmod(p.x*13+p.y*7,41)==0 and y>=13 and x+7<bounds.size.x:
				reeds.append(Vector2(x+2,y+2))
	for reed in reeds:
		var x=int(reed.x);var y=int(reed.y)
		image.fill_rect(Rect2i(x-1,y-8,1,8),Color("546b47"))
		image.fill_rect(Rect2i(x+3,y-11,1,11),Color("829459"))
		image.fill_rect(Rect2i(x+3,y-12,2,4),Color("a57d56"))
	return [ImageTexture.create_from_image(image),ImageTexture.create_from_image(mask)]
