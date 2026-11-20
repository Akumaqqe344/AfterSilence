extends RefCounted
## Original seeded pixel materials; cached across navigation world snapshots.
static var cache: Dictionary={}
static func material(kind: String, variant: int) -> ShaderMaterial:
	var category=3 if kind=="character" else 0 if kind in ["tree","flowers","plant"] else 1 if kind in ["house","library","shop_front","gazebo","shelf","table","desk","chair","bed","workbench"] else 2
	var key="material_%d_%d"%[category,posmod(variant,4)]
	if not cache.has(key):
		var shader_material=ShaderMaterial.new()
		shader_material.shader=preload("res://after_silence/world/surface_detail.gdshader")
		shader_material.set_shader_parameter("material_kind",category)
		shader_material.set_shader_parameter("variation",float(posmod(variant,4)*31))
		cache[key]=shader_material
	return cache[key]

static func atlas(kind: String, zone: String="") -> Texture2D:
	var key=kind+":"+zone if kind=="grass" else kind
	if cache.has(key): return cache[key]
	var extent=80 if kind=="water" else 320
	var image=Image.create(extent,extent,false,Image.FORMAT_RGBA8)
	var palette={"grass":["829360","7f905d","899a66","768853","9eaa75"],"dirt":["ad966d","aa936a","b19a71","94815d","c2ac81"],"floor":["9d7953","a47e58","b18a60","785d47","bf966b"],"water":["507e7c","527f7e","67928b","477371","8eb0a0"]}[kind]
	if kind=="grass":
		palette= {
			"forest":["677e55","657b53","70875b","5b734e","8e9e68"],
			"orchard":["8f9a60","8a955d","98a369","7e8a55","a7ae73"],
			"harbor":["9b9a70","96956d","a4a277","8d8d65","b0ad80"]
		}.get(zone,palette)
	var colors=[]
	for hex in palette: colors.append(Color(hex))
	for y in range(extent):
		for x in range(extent):
			var hash_value=posmod((x*73856093)^(y*19349663),997)
			var color: Color=colors[0]
			if kind=="floor":
				var row=y/12
				var joint=posmod(x+int(row)*23,64)
				color=colors[1 if int(row)%2==0 else 0]
				if y%12==0 or joint==0: color=colors[3]
				elif y%12==1: color=colors[4]
				elif hash_value<55 and y%3==0: color=colors[2]
			elif kind=="water":
				var ripple=posmod(x+int(sin(y*.23)*5),20)
				color=colors[1 if y%16<8 else 0]
				if y%9==0 and ripple<8: color=colors[2]
				if y%19==0 and ripple<5: color=colors[4]
			else:
				if hash_value<80: color=colors[1]
				elif hash_value<130: color=colors[2]
				if kind=="grass" and hash_value==7:
					color=colors[3]
				if kind=="dirt" and hash_value<10: color=colors[4]
			image.set_pixel(x,y,color)
	cache[key]=ImageTexture.create_from_image(image)
	return cache[key]
