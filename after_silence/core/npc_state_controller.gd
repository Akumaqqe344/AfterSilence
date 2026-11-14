extends RefCounted
var state
func _init(s): state = s
func destination(id: String, home: Vector2, time: float) -> Vector2:
	var offset = {"nadia":0.0,"lev":1.0,"mara":2.0,"pavel":3.0,"sonya":4.0}.get(id,0.0)
	var phase = int((time + offset*.2) / 6.0) % 3
	if state.flag("ending_public") and id == "pavel": return home + Vector2(-40, 20)
	if id=="sonya" and state.flag("protect_sonya"): return home+Vector2(-25,20)
	return home + [Vector2.ZERO, Vector2(32,0), Vector2(0,28)][phase]
func change_relation(id: String, delta: int) -> void:
	if id in state.relations:
		state.relations[id] = clampi(state.relations[id] + delta, -5, 5)
		state.changed.emit()
