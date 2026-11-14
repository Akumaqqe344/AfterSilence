extends RefCounted
var state
func _init(s): state = s
func install_fuse(target: String) -> bool:
	if not target in ["library_light", "forest_power"] or state.flag(target): return false
	if not state.give("fuse", -1): return false
	state.set_flag(target)
	return true
func remove_library_fuse() -> bool:
	if not state.flag("library_light"): return false
	state.set_flag("library_light", false)
	return state.give("fuse")
