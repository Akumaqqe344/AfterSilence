extends Node2D
var zone="town"
var distorted=false
var dimensions=Vector2.ZERO
const Shore=preload("res://after_silence/world/shore_atlas.gd")
const Art=preload("res://after_silence/core/ppae_art.gd")
const WATER_SHADER=preload("res://after_silence/world/ppae_water.gdshader")
var rug=preload("res://after_silence/assets/art100/rug.png")
var water_materials: Array[ShaderMaterial]=[]
var water_time:=0.0

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for layer in Shore.layers(zone):
		var surface:=Sprite2D.new()
		surface.texture=layer[2]
		surface.centered=false
		surface.position=Vector2(layer[0])
		var waves:=ShaderMaterial.new()
		waves.shader=WATER_SHADER
		waves.set_shader_parameter("waves",Art.texture("liquid"))
		waves.set_shader_parameter("field_origin",surface.position)
		waves.set_shader_parameter("field_size",surface.texture.get_size())
		surface.material=waves
		add_child(surface)
		water_materials.append(waves)
	set_process(not water_materials.is_empty())

func _process(delta: float) -> void:
	var parent=get_parent()
	if parent.visual_comfort!=null and parent.visual_comfort.reduce_motion: return
	water_time=fposmod(water_time+delta,16.0)
	for waves in water_materials: waves.set_shader_parameter("water_age",water_time)
func _draw():
	if zone in ["town","harbor"]:
		for layer in Shore.layers(zone): draw_texture(layer[1],Vector2(layer[0]))
	if zone.begins_with("home_") or zone=="shop":
		for rect in [Rect2(0,0,640,64),Rect2(0,64,64,416),Rect2(576,64,64,416),Rect2(64,448,512,32)]: draw_rect(rect,Color("172126"))
		if zone.begins_with("home_"):
			draw_rect(Rect2(80,81,480,19),Color("ae8b6b"))
			draw_rect(Rect2(80,99,480,3),Color("866349"))
			for x in range(84,556,18): draw_rect(Rect2(x,83,1,16),Color("927255"))
			draw_rect(Rect2(288,428,64,19),Color("634e42"))
			draw_rect(Rect2(288,428,64,3),Color("ac8968"))
		for rect in [Rect2(64,64,512,16),Rect2(64,80,16,352),Rect2(560,80,16,352),Rect2(80,432,208,16),Rect2(352,432,208,16)]:
			draw_rect(rect,Color("574b45"))
			draw_rect(Rect2(rect.position,Vector2(rect.size.x,3)),Color("bb9b79"))
		return
	if zone=="library":
		draw_rect(Rect2(80,75,800,20),Color("574b45"))
		draw_rect(Rect2(80,95,800,36),Color("a09178"))
		for x in range(100,880,32): draw_line(Vector2(x,98),Vector2(x,127),Color("817660"))
		for x in [80,864]: draw_rect(Rect2(x,95,16,515),Color("574b45"))
		for x in [96,525]: draw_rect(Rect2(x,610,339,16),Color("574b45"))
		draw_texture_rect(rug,Rect2(432,380,96,64),false)
		return
func paint_ellipse(center: Vector2,radius: Vector2,color: Color):
	draw_set_transform(center,0,radius)
	draw_circle(Vector2.ZERO,1,color)
	draw_set_transform(Vector2.ZERO)
