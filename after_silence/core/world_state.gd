extends RefCounted
signal changed
const ZONES = ["town", "library", "forest","home_nadia","home_lev","home_pavel","home_sonya","orchard","harbor","shop"]
const ITEMS = ["fuse", "lens", "key", "ribbon", "bandage", "keepsake"]
const CLUES = ["photo", "poster", "ledger", "clock", "diagram", "testimony", "signature", "medical"]
var flags: Dictionary = {}
var inventory: Dictionary = {}
var evidence: Array = []
var links: Array = []
var relations: Dictionary = {"nadia": 0, "lev": 0, "mara": 0, "pavel": 0, "sonya": 0,"child":0,"alina":0,"guest":0}
var history: Array = []
var seen: Array = []
var achievements: Array = []
var zone = "town"
var position = Vector2(600, 630)
var echo = false
var charges = 3
var pressure = 0
var clock = 8.0
var play_seconds = 0.0
var language = "ru"
var volume = 0.45
var residents: Dictionary={}
var last_memories: Dictionary={}
var away_times: Dictionary={}
var storage: Dictionary={}
var minigame: Dictionary={}
var tokens=3
var event_state: Dictionary={}
func flag(id: String) -> bool:
	return flags.get(id, false) == true
func set_flag(id: String, value: bool = true) -> void:
	flags[id] = value
	changed.emit()
func add_clue(id: String) -> bool:
	if not id in CLUES or id in evidence: return false
	evidence.append(id)
	changed.emit()
	return true
func item(id: String) -> int:
	return int(inventory.get(id, 0))
func give(id: String, count: int = 1) -> bool:
	if not id in ITEMS or item(id) + count < 0: return false
	inventory[id] = clampi(item(id) + count, 0, 9)
	changed.emit()
	return true
func to_data() -> Dictionary:
	return {"event_state":event_state.duplicate(true),"tokens":tokens,"schema":3,"storage":storage.duplicate(),"minigame":minigame.duplicate(true),"last_memories":last_memories.duplicate(),"away_times":away_times.duplicate(),"residents":residents.duplicate(true), "flags": flags.duplicate(true), "inventory": inventory.duplicate(), "evidence": evidence.duplicate(), "links": links.duplicate(), "relations": relations.duplicate(), "history": history.duplicate(true), "seen": seen.duplicate(), "achievements":achievements.duplicate(), "zone": zone, "position": [position.x, position.y], "echo": echo, "charges": charges, "pressure": pressure, "clock": clock, "play_seconds": play_seconds, "language": language, "volume": volume}
func restore(d: Dictionary) -> bool:
	var saved_event=d.get("event_state",{})
	if not saved_event is Dictionary or not preload("res://after_silence/core/event_progress.gd").valid(saved_event): return false
	var saved_tokens=d.get("tokens",3)
	if not (saved_tokens is int or saved_tokens is float) or not is_finite(float(saved_tokens)) or saved_tokens<0 or saved_tokens>999: return false
	var schema=d.get("schema",2)
	if not (schema is int or schema is float) or not is_finite(float(schema)) or schema!=int(schema) or int(schema) not in [2,3]: return false
	if not d.get("storage",{}) is Dictionary or not d.get("minigame",{}) is Dictionary: return false
	var saved_storage={}
	for id in d.get("storage",{}):
		var count=d.storage[id]
		if id not in ITEMS or not (count is int or count is float) or not is_finite(float(count)) or count<0 or count>9: return false
		saved_storage[id]=int(count)
	var saved_game=d.get("minigame",{}).duplicate(true)
	if not preload("res://after_silence/core/minigame_checkpoint.gd").valid(saved_game): return false
	if not d.get("last_memories",{}) is Dictionary or not d.get("away_times",{}) is Dictionary: return false
	var saved_memories={}
	for id in relations:
		if not d.get("last_memories",{}).has(id): continue
		var value=d.get("last_memories",{}).get(id,"")
		if not value is String or value.length()>64: return false
		saved_memories[id]=value
	var saved_times={}
	for id in ["orchard_delivery","harbor_lights"]:
		if not d.get("away_times",{}).has(id): continue
		var value=d.get("away_times",{}).get(id,0)
		if not (value is int or value is float) or not is_finite(float(value)): return false
		saved_times[id]=clampf(float(value),0,3600)
	var memory=d.get("residents",{})
	if not memory is Dictionary: return false
	var restored={}
	for id in memory:
		if id not in relations: continue
		var r=memory[id]
		if not r is Dictionary or not r.get("zone","") in ZONES: return false
		if not r.has("x") or not r.has("y"): return false
		for key in ["x","y","elapsed","wait","visits"]:
			var value=r.get(key,0)
			if not (value is int or value is float) or not is_finite(float(value)): return false
		restored[id]={"zone":r.zone,"x":clampf(float(r.x),24,1500),"y":clampf(float(r.y),24,1100),"elapsed":clampf(float(r.get("elapsed",0)),0,1000),"wait":clampf(float(r.get("wait",3)),0,20),"visits":int(clampf(float(r.get("visits",0)),0,100000))}
		restored[id].destination=r.get("destination",r.zone) if r.get("destination",r.zone) in ZONES else r.zone
		for key in ["mode","previous_mode"]:
			if r.has(key): restored[id][key]=r[key] if r[key] in ["routine","fear","alarm","help","search","home"] else "routine"
		if r.has("mode_since"):
			if not (r.mode_since is int or r.mode_since is float) or not is_finite(float(r.mode_since)): return false
			restored[id].mode_since=maxf(0,float(r.mode_since))
		if r.has("last_seen"):
			if not r.last_seen is Array or r.last_seen.size()!=2: return false
			for n in r.last_seen:
				if not (n is float or n is int) or not is_finite(float(n)): return false
			restored[id].last_seen=r.last_seen.duplicate()
	if not d.get("zone", "") in ZONES: return false
	var p = d.get("position", [])
	if not p is Array or p.size() != 2: return false
	if not (p[0] is float or p[0] is int) or not (p[1] is float or p[1] is int): return false
	if not is_finite(float(p[0])) or not is_finite(float(p[1])): return false
	for key in ["flags", "inventory", "relations"]:
		if not d.get(key, {}) is Dictionary: return false
	for key in ["evidence", "links", "history", "seen", "achievements"]:
		if not d.get(key, []) is Array: return false
	for group in ["inventory", "relations"]:
		for value in d.get(group, {}).values():
			if not (value is int or value is float) or not is_finite(float(value)): return false
	for key in ["charges", "pressure", "clock", "play_seconds", "volume"]:
		var value=d.get(key,0)
		if not (value is int or value is float) or not is_finite(float(value)): return false
	residents=restored
	storage=saved_storage
	tokens=int(saved_tokens)
	event_state=saved_event.duplicate(true)
	minigame=saved_game
	last_memories=saved_memories
	away_times=saved_times
	flags.clear()
	for key in d.get("flags", {}):
		if key is String and key.length() < 80 and d.flags[key] is bool: flags[key] = d.flags[key]
	inventory.clear()
	for id in ITEMS:
		if d.get("inventory",{}).has(id): inventory[id] = int(clampf(float(d.inventory[id]), 0, 9))
	evidence = d.get("evidence", []).filter(func(v): return v in CLUES)
	links = d.get("links", []).filter(func(v): return v in ["date", "coverup", "witness", "survival"])
	for id in relations: relations[id] = int(clampf(float(d.get("relations", {}).get(id, 0)), -5, 5))
	history = d.get("history", []).slice(-100)
	seen = d.get("seen", []).filter(func(v): return v is String and v.length() < 80).slice(-100)
	achievements = d.get("achievements", []).filter(func(v): return v is String and v in preload("res://after_silence/core/achievements.gd").ENTRIES)
	zone = d.zone
	position = Vector2(clampf(float(p[0]), 32, 1500), clampf(float(p[1]), 32, 1100))
	echo = d.get("echo", false) == true
	charges = int(clampf(float(d.get("charges", 3)), 0, 3))
	pressure = int(clampf(float(d.get("pressure", 0)), 0, 5))
	clock = fposmod(float(d.get("clock", 8)), 24.0)
	play_seconds = maxf(0, float(d.get("play_seconds", 0)))
	language = "en" if d.get("language") == "en" else "ru"
	volume = clampf(float(d.get("volume", 0.45)), 0, 1)
	changed.emit()
	return true
