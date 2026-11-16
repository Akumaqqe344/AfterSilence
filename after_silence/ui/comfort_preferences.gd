extends RefCounted
## Global comfort preferences deliberately live outside story saves.
var path="user://comfort.cfg"
var large_text=false
var reduce_motion=false
var instant_text=false
var fullscreen=false
var language="ru"
var volume=0.5
var available=false

func load_preferences() -> void:
	var config=ConfigFile.new()
	if config.load(path)!=OK: return
	large_text=_read_bool(config,"large_text")
	reduce_motion=_read_bool(config,"reduce_motion")
	instant_text=_read_bool(config,"instant_text")
	fullscreen=_read_bool(config,"fullscreen")
	language=str(config.get_value("comfort","language","ru"))
	if language not in ["ru","en"]: language="ru"
	var stored_volume=config.get_value("comfort","volume",0.5)
	volume=clampf(float(stored_volume),0.0,1.0) if stored_volume is float or stored_volume is int else 0.5
	if not is_finite(volume): volume=0.5
	available=true

func _read_bool(config: ConfigFile, key: String) -> bool:
	var value=config.get_value("comfort",key,false)
	return value if value is bool else false

func save_preferences() -> Error:
	var config=ConfigFile.new()
	for key in ["large_text","reduce_motion","instant_text","fullscreen","language","volume"]:
		config.set_value("comfort",key,get(key))
	var error=config.save(path)
	if error==OK: available=true
	return error
