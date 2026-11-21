extends RefCounted
## Read-only render resources. Generated hitboxes are provenance; physics uses the existing map and capsule.
const BASE = "res://after_silence/assets/ppae0300/"
const CARDINALS = ["S", "N", "W", "E"]
const DIAGONALS = ["SW", "SE", "NW", "NE"]
const FURNITURE = {
	"table":"dining_table", "desk":"dining_table", "bench":"dining_table", "stool":"wooden_chair",
	"chair":"wooden_chair", "bed":"bed", "books":"bookshelf", "bookshelf":"bookshelf",
	"shelf":"bookshelf", "chest":"storage_chest", "storage":"storage_chest", "toolbox":"storage_chest",
	"stove":"furnace_hearth", "forge":"furnace_hearth", "rug":"woven_rug", "plant":"potted_plant",
	"workbench":"anvil_station", "medicine":"alchemy_bench", "barrel":"wooden_barrel",
}
static var actors: Dictionary = _read_json("actors")
static var manifest: Dictionary = _read_json("manifest")
static var textures: Dictionary = {}
static var animation_cache: Dictionary = {}

static func _read_json(id: String) -> Dictionary:
	var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASE + id + ".json"))
	return loaded if loaded is Dictionary else {}

static func texture(id: String) -> Texture2D:
	if not textures.has(id):
		var path := BASE + id + ".png"
		textures[id] = load(path) if ResourceLoader.exists(path) else null
	return textures[id]

static func actor_frame(id: String, sequence: String, index: int) -> Dictionary:
	var frames: Array = actors.get(id, {}).get(sequence, [])
	if frames.is_empty():
		return {}
	var record: Dictionary = frames[posmod(index, frames.size())]
	var bounds: Array = record.rect
	var pivot: Array = record.pivot
	return {
		"rect": Rect2(bounds[0], bounds[1], bounds[2], bounds[3]),
		"pivot": Vector2(pivot[0], pivot[1]),
	}

static func sprite_frames(id: String) -> SpriteFrames:
	if animation_cache.has(id):
		return animation_cache[id]
	if not actors.has(id):
		return null
	var atlas := texture("actor_" + id)
	var resource := SpriteFrames.new()
	resource.remove_animation("default")
	for sequence in actors[id]:
		var list: Array = actors[id][sequence]
		resource.add_animation(sequence)
		resource.set_animation_speed(sequence, 1000.0 / maxf(1.0, float(list[0].duration)))
		for i in list.size():
			var frame := AtlasTexture.new()
			frame.atlas = atlas
			frame.filter_clip = true
			frame.region = actor_frame(id, sequence, i).rect
			resource.add_frame(sequence, frame)
	animation_cache[id] = resource
	return resource

static func paint_actor(canvas: CanvasItem, id: String, sequence: String, frame: int, at: Vector2, zoom: float, tint: Color = Color.WHITE) -> bool:
	var source := actor_frame(id, sequence, frame)
	if source.is_empty():
		return false
	var target := Rect2((at - Vector2(source.pivot) * zoom).round(), Vector2(source.rect.size) * zoom)
	canvas.draw_texture_rect_region(texture("actor_" + id), target, source.rect, tint, false, true)
	return true

static func material_tile(kind: String, zone: String) -> Texture2D:
	if kind == "grass":
		return texture("grass_" + (zone if zone in ["town", "forest", "orchard", "harbor"] else "town"))
	if kind == "floor":
		return texture("floor_" + (zone if zone.begins_with("home_") or zone in ["shop", "library"] else "default"))
	return texture(kind)

static func prop_key(kind: String, zone: String, variant: int, at: Vector2) -> String:
	if kind == "tree":
		var species := 2 if zone == "orchard" else posmod(variant, 2)
		return "tree_%d_%d_" % [species, posmod(roundi(at.x * 31 + at.y * 61), 3)]
	if kind == "flowers":
		var species: String = ["flower_cluster", "wild_flower", "fern", "low_shrub"][posmod(variant, 4)]
		return species + "_" + str(posmod(variant / 4, 3))
	if kind == "house":
		return "structure_house-" + str(posmod(variant, 4))
	if kind in ["well", "shop_front", "library"]:
		return "structure_" + kind
	if kind in ["stone", "rock"]:
		return "mossy_boulder" if kind == "rock" else "rounded_riverstone"
	return ""

static func panel(id: String, margin: float) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture("ui_" + id)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 6)
		box.set_content_margin(side, margin)
	return box

static func sun(hour: float) -> Dictionary:
	var phases: Array = manifest.get("daylight", [])
	return phases[posmod(floori(hour), phases.size())] if not phases.is_empty() else {}

static func wind(at: Vector2, age: float) -> int:
	var samples: Array = manifest.get("breeze", [])
	if samples.is_empty():
		return 1
	var step := floori(age * 6.0 + at.x * .03 + at.y * .04)
	return clampi(1 + int(samples[posmod(step, samples.size())]), 0, 2)

static func effect(canvas: CanvasItem, id: String, at: Vector2, age: float, zoom: float = 1.0, tint: Color = Color.WHITE) -> void:
	var sprite := texture("fx_" + id)
	if sprite == null:
		return
	var frame := clampi(floori(age / .048), 0, 7)
	var target := Rect2((at - Vector2(24, 30) * zoom).round(), Vector2(48, 48) * zoom)
	canvas.draw_texture_rect_region(sprite, target, Rect2(frame * 48, 0, 48, 48), tint)
