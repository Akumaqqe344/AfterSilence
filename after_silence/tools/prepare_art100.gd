extends SceneTree
const BASE="res://after_silence/assets/art100/"
func _initialize():
	var environment=[
		["tree-0",50,55,100,110],["tree-1",44,58,88,116],["tree-2",50,55,100,110],["bush",30,22,60,44],
		["house-0",88,80,176,160],["house-1",88,80,176,160],["house-2",88,80,176,160],["house-3",88,80,176,160],
		["flowers",20,14,40,28],["rock",28,22,56,44],["well",40,40,80,80],["street_lamp",12,36,24,72],
		["trace",18,32,36,64],["poster",26,26,52,52],["chest",24,18,48,36],["bridge",32,42,64,84]]
	var inside=[
		["shelf",38,42,76,84],["desk",40,32,80,64],["bed",34,52,68,104],["table",36,30,72,60],
		["chair",20,28,40,56],["workbench",44,40,88,80],["mirror",24,44,48,88],["clock",22,42,44,84],
		["plant",20,24,40,48],["rug",48,32,96,64],["window",28,28,56,56],["relay",24,28,48,56],
		["book",12,14,24,28],["letter",12,9,24,18],["medicine",16,16,32,32],["plan",18,14,36,28]]
	var catalog={"version":1,"props":{}}
	split_sheet("environment-source.png",environment,catalog)
	split_sheet("interior-source.png",inside,catalog)
	var items=[["photo",12,12,24,24],["medal",10,10,20,20],["tools",14,14,28,28],["key",8,14,16,28],["ribbon",12,12,24,24],["herb",12,12,24,24],["lamp",12,16,24,32],["bandage",12,10,24,20]]
	split_sheet("items-source.png",items,catalog,2)
	var ground=Image.load_from_file(BASE+"terrain-source.png")
	var names=["grass","dirt","floor","water"]
	for i in range(4):
		var rect=Rect2i(int(i%2*ground.get_width()/2.0),int(i/2*ground.get_height()/2.0),int(ground.get_width()/2.0),int(ground.get_height()/2.0))
		var tile=ground.get_region(rect)
		tile.resize(80,80,Image.INTERPOLATE_NEAREST)
		snap_pixels(tile,false)
		assert(tile.save_png(BASE+names[i]+".png")==OK)
	var file=FileAccess.open(BASE+"catalog.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog,"  "))
	file.close()
	print("ART100: 40 props and 4 terrain textures prepared")
	quit()
func snap_pixels(image: Image, alpha: bool):
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c=image.get_pixel(x,y)
			c.a=(1.0 if c.a>=.6 else 0.0) if alpha else 1.0
			# Restrained color steps remove high-resolution shading between pixels.
			c.r=roundf(c.r*31)/31;c.g=roundf(c.g*31)/31;c.b=roundf(c.b*31)/31
			image.set_pixel(x,y,c)
func split_sheet(filename: String, entries: Array, catalog: Dictionary, rows: int=4):
	var sheet=Image.load_from_file(BASE+filename)
	assert(sheet!=null and not sheet.is_empty())
	for i in range(entries.size()):
		var l=int(i%4*sheet.get_width()/4.0)
		var r=int((i%4+1)*sheet.get_width()/4.0)
		var t=int(i/4*sheet.get_height()/float(rows))
		var b=int((i/4+1)*sheet.get_height()/float(rows))
		var image=sheet.get_region(Rect2i(l,t,r-l,b-t))
		snap_pixels(image,true)
		remove_stray_fragments(image)
		var used=image.get_used_rect()
		assert(used.has_area())
		image=image.get_region(used)
		var entry=entries[i]
		image.resize(entry[1],entry[2],Image.INTERPOLATE_NEAREST)
		assert(image.save_png(BASE+entry[0]+".png")==OK)
		catalog.props[entry[0]]={"file":entry[0]+".png","size":[entry[3],entry[4]]}
func remove_stray_fragments(image: Image):
	# Generative atlases can cross a cell edge by a few pixels. Keep the actual
	# sprite components, not isolated fragments from the neighboring cell.
	var width=image.get_width()
	var height=image.get_height()
	var visited=PackedByteArray()
	visited.resize(width*height)
	var groups=[]
	var largest=0
	for y in range(height):
		for x in range(width):
			var start=y*width+x
			if visited[start] or image.get_pixel(x,y).a==0: continue
			var stack=[start]
			var component=[]
			visited[start]=1
			while not stack.is_empty():
				var index=int(stack.pop_back())
				component.append(index)
				var px=index%width
				var py=index/width
				for dy in range(-1,2):
					for dx in range(-1,2):
						var nx=px+dx
						var ny=py+dy
						if nx<0 or ny<0 or nx>=width or ny>=height: continue
						var neighbor=ny*width+nx
						if visited[neighbor] or image.get_pixel(nx,ny).a==0: continue
						visited[neighbor]=1;stack.append(neighbor)
			largest=maxi(largest,component.size())
			groups.append(component)
	for group in groups:
		if group.size()>=maxi(8,int(largest*.05)): continue
		for index in group: image.set_pixel(index%width,index/width,Color.TRANSPARENT)
