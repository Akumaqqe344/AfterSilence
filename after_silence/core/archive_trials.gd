extends RefCounted
## Archive bench checkpoints. Existing story flags still own completion and rewards.

const NORTH = 1
const EAST = 2
const SOUTH = 4
const WEST = 8
const DEFAULTS = {"catalog":[-1,-1,-1], "clock":[0,0], "relay":[0,0,0]}
const RANGES = {"catalog":[3,3,3], "clock":[24,60], "relay":[4,4,4]}
const CONNECTORS = [NORTH | EAST, NORTH | EAST | SOUTH, SOUTH | WEST]

static func checkpoint(kind: String, raw: Variant) -> Array:
	if not DEFAULTS.has(kind):
		return []
	var fallback: Array = DEFAULTS[kind].duplicate()
	if not raw is Array or raw.size() != fallback.size():
		return fallback
	var clean = []
	for i in raw.size():
		var value: Variant = raw[i]
		var minimum = -1 if kind == "catalog" else 0
		if not (value is int or value is float) or not is_finite(float(value)):
			return fallback
		if value != int(value) or value < minimum or value >= RANGES[kind][i]:
			return fallback
		clean.append(int(value))
	return clean

static func pin_mask(index: int, turns: int) -> int:
	var mask: int = CONNECTORS[index]
	for turn in turns:
		mask = ((mask << 1) | (mask >> 3)) & 15
	return mask

static func circuits(values: Array) -> Dictionary:
	var top = pin_mask(0, values[0])
	var center = pin_mask(1, values[1])
	var bottom = pin_mask(2, values[2])
	var live = (center & WEST) != 0
	return {
		"input":live,
		"upper":live and (center & NORTH) != 0 and (top & SOUTH) != 0 and (top & EAST) != 0,
		"alarm":live and (center & EAST) != 0,
		"lower":live and (center & SOUTH) != 0 and (bottom & NORTH) != 0 and (bottom & EAST) != 0
	}

static func solved(kind: String, values: Array) -> bool:
	match kind:
		"catalog": return values == [0,1,2]
		"clock": return values == [2,17]
		"relay":
			var path = circuits(values)
			return path.upper and path.lower and not path.alarm
	return false
