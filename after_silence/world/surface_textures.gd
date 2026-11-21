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
	var key=kind+":"+zone if kind in ["grass","floor"] else kind
	if cache.has(key): return cache[key]
	var extent=80 if kind=="water" else 320
	var image=Image.create(extent,extent,false,Image.FORMAT_RGBA8)
	var palette={"grass":["839363","7b8b5e","8b9a6d","6e8456","a0a675"],"dirt":["aa926a","a68e66","b29a70","8e7a59","c2ab80"],"floor":["967454","9d7c5c","a98b65","775b46","b89a73"],"water":["517877","557d78","648d85","4a716a","8ca998"]}[kind]
	if kind=="grass":
		palette= {
			"forest":["677e55","657b53","70875b","5b734e","8e9e68"],
			"orchard":["8f9a60","8a955d","98a369","7e8a55","a7ae73"],
			"harbor":["9b9a70","96956d","a4a277","8d8d65","b0ad80"]
		}.get(zone,palette)
	if kind=="floor":
		palette={
			"home_nadia":["a38765","a68863","b19672","826a50","bea27b"],
			"home_lev":["82705c","89745d","9a8367","695644","a99173"],
			"home_pavel":["887764","937f69","9e8d76","6c5f53","aa977e"],
			"home_sonya":["a48266","a88870","b4977c","856b56","bea18a"]
		}.get(zone,palette)
	var colors=[]
	for hex in palette: colors.append(Color(hex))
	for y in range(extent):
		for x in range(extent):
			var hash_value=posmod((x*73856093)^(y*19349663),997)
			var color: Color=colors[0]
			if kind=="floor":
				var row=y/16
				var joint=posmod(x+row*21,64)
				color=colors[1 if (row+int((x+row*21)/64))%3==0 else 0]
				if y%16==0 or joint==0: color=colors[3]
				elif y%16==1: color=colors[4]
				elif y%5==0 and (joint+row*3)%19<6: color=colors[2]
			elif kind=="water":
				var ripple=posmod(x+(y/6)*17,40)
				color=colors[1 if y%13<5 else 0]
				if y%6==0 and ripple<11: color=colors[2]
				if y%6==1 and ripple>2 and ripple<10: color=colors[3]
				if y%17==4 and ripple<5: color=colors[4]
			else:
				if hash_value<80: color=colors[1]
				elif hash_value<130: color=colors[2]
				if kind=="grass" and hash_value==7:
					color=colors[3]
				if kind=="dirt" and hash_value<10: color=colors[4]
			image.set_pixel(x,y,color)
	cache[key]=ImageTexture.create_from_image(image)
	return cache[key]
