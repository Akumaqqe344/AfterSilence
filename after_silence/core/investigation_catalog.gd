extends RefCounted
const SOURCE="res://after_silence/data/investigations.json"
static var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))

static func point(raw: Array) -> Vector2:
	return Vector2(raw[0],raw[1])

static func spot(id: String) -> String:
	return "case_"+id
