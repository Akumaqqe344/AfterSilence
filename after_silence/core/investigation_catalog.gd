extends RefCounted
const SOURCE="res://after_silence/data/investigations.json"
const EXPEDITIONS = "res://after_silence/data/expeditions_0330.json"
static var data: Dictionary = load_cases()

static func load_cases() -> Dictionary:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var expansion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPEDITIONS))
	base.rooms.merge(expansion.rooms)
	base.chapters.append_array(expansion.chapters)
	base.sides.append_array(expansion.sides)
	return base

static func point(raw: Array) -> Vector2:
	return Vector2(raw[0],raw[1])

static func spot(id: String) -> String:
	return "case_"+id
