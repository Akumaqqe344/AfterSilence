extends RefCounted
signal changed
const ZONES = ["town", "library", "forest"]
const ITEMS = ["fuse", "lens", "key", "ribbon"]
const CLUES = ["photo", "poster", "ledger", "clock", "diagram", "testimony", "signature", "medical"]
var flags: Dictionary = {}
var inventory: Dictionary = {}
var evidence: Array = []
var links: Array = []
var relations: Dictionary = {"nadia": 0, "lev": 0, "mara": 0, "pavel": 0, "sonya": 0}
var history: Array = []
var seen: Array = []
var zone = "town"
var position = Vector2(600, 630)
var echo = false
var charges = 3
var pressure = 0
var clock = 8.0
var play_seconds = 0.0
var language = "ru"
var volume = 0.45
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
	return {"flags": flags.duplicate(true), "inventory": inventory.duplicate(), "evidence": evidence.duplicate(), "links": links.duplicate(), "relations": relations.duplicate(), "history": history.duplicate(true), "seen": seen.duplicate(), "zone": zone, "position": [position.x, position.y], "echo": echo, "charges": charges, "pressure": pressure, "clock": clock, "play_seconds": play_seconds, "language": language, "volume": volume}
func restore(d: Dictionary) -> bool:
	if not d.get("zone", "") in ZONES: return false
	var p = d.get("position", [])
	if not p is Array or p.size() != 2: return false
	if not (p[0] is float or p[0] is int) or not (p[1] is float or p[1] is int): return false
	if not is_finite(float(p[0])) or not is_finite(float(p[1])): return false
	for key in ["flags", "inventory", "relations"]:
		if not d.get(key, {}) is Dictionary: return false
	for key in ["evidence", "links", "history", "seen"]:
		if not d.get(key, []) is Array: return false
	for group in ["inventory", "relations"]:
		for value in d.get(group, {}).values():
			if not (value is int or value is float) or not is_finite(float(value)): return false
	for key in ["charges", "pressure", "clock", "play_seconds", "volume"]:
		var value=d.get(key,0)
		if not (value is int or value is float) or not is_finite(float(value)): return false
	flags.clear()
	for key in d.get("flags", {}):
		if key is String and key.length() < 80 and d.flags[key] is bool: flags[key] = d.flags[key]
	inventory.clear()
	for id in ITEMS:
		if d.get("inventory",{}).has(id): inventory[id] = clampi(int(d.inventory[id]), 0, 9)
	evidence = d.get("evidence", []).filter(func(v): return v in CLUES)
	links = d.get("links", []).filter(func(v): return v in ["date", "coverup", "witness", "survival"])
	for id in relations: relations[id] = clampi(int(d.get("relations", {}).get(id, 0)), -5, 5)
	history = d.get("history", []).slice(-100)
	seen = d.get("seen", []).filter(func(v): return v is String and v.length() < 80).slice(-100)
	zone = d.zone
	position = Vector2(clampf(float(p[0]), 32, 1500), clampf(float(p[1]), 32, 1100))
	echo = d.get("echo", false) == true
	charges = clampi(int(d.get("charges", 3)), 0, 3)
	pressure = clampi(int(d.get("pressure", 0)), 0, 5)
	clock = fposmod(float(d.get("clock", 8)), 24.0)
	play_seconds = maxf(0, float(d.get("play_seconds", 0)))
	language = "en" if d.get("language") == "en" else "ru"
	volume = clampf(float(d.get("volume", 0.45)), 0, 1)
	changed.emit()
	return true
