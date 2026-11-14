extends RefCounted
const PAIRS = {"date": ["poster", "clock"], "coverup": ["photo", "ledger"], "witness": ["testimony", "signature"], "survival":["medical","clock"]}
var state
func _init(s): state = s
func connect_clues(a: String, b: String) -> String:
	if a == b or not a in state.evidence or not b in state.evidence: return ""
	for id in PAIRS:
		if a in PAIRS[id] and b in PAIRS[id]:
			if not id in state.links:
				state.links.append(id)
				state.changed.emit()
			return id
	return ""
