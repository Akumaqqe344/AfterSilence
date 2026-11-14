extends RefCounted
var state
func _init(s): state = s
func record(id: String, speaker: String, body: String) -> void:
	state.history.append({"id": id, "speaker": speaker, "body": body})
	if state.history.size() > 100: state.history.pop_front()
	if not id in state.seen: state.seen.append(id)
	if state.seen.size()>100: state.seen.pop_front()
func was_seen(id: String) -> bool:
	return id in state.seen
