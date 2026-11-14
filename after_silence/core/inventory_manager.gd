extends RefCounted
var state
var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/items.json"))
func transfer(id: String, into_storage: bool) -> bool:
	if id not in state.ITEMS: return false
	var source=state.inventory if into_storage else state.storage
	var target=state.storage if into_storage else state.inventory
	if int(source.get(id,0))<=0 or int(target.get(id,0))>=9: return false
	source[id]=int(source[id])-1
	target[id]=int(target.get(id,0))+1
	state.changed.emit()
	return true
func craft_badge() -> bool:
	if state.item("ribbon")<1 or state.item("bandage")<1 or state.item("keepsake")>=9: return false
	state.inventory.ribbon-=1
	state.inventory.bandage-=1
	state.inventory.keepsake=state.item("keepsake")+1
	state.changed.emit()
	return true
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
