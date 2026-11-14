extends RefCounted
const DATA=preload("res://after_silence/core/quest_catalog.gd")
var entries: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/npc_routines.json")).residents

func current(id: String, hour: float) -> Array:
	var result: Array=[]
	var best=25.0
	for entry in entries.get(id,[]):
		var age=fposmod(hour-float(entry[0]),24.0)
		if age<best: best=age;result=entry
	return result

func next(id: String, hour: float) -> Dictionary:
	var result={}
	var best=25.0
	for entry in entries.get(id,[]):
		var delay=fposmod(float(entry[0])-hour,24.0)
		if delay<=.00001: delay=24.0
		if delay<best: best=delay;result={"hours":delay,"entry":entry}
	return result
