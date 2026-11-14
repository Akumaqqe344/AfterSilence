extends RefCounted
const State = preload("res://after_silence/core/world_state.gd")
var path = "user://episode_slot.json"
var last_error = ""
func save(state) -> bool:
	var payload = JSON.stringify(state.to_data())
	var envelope = JSON.stringify({"version": 2, "payload": payload, "sha256": payload.sha256_text()})
	var tmp = path + ".tmp"
	var file = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		last_error = "write: " + str(FileAccess.get_open_error())
		return false
	file.store_string(envelope)
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK: return false
	var absolute = ProjectSettings.globalize_path(path)
	var backup = absolute + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			if DirAccess.remove_absolute(backup) != OK: return false
		if DirAccess.rename_absolute(absolute, backup) != OK: return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), absolute) != OK:
		if FileAccess.file_exists(backup): DirAccess.rename_absolute(backup, absolute)
		last_error = "rename"
		return false
	return true
func load_state(state) -> bool:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var file = FileAccess.open(candidate, FileAccess.READ)
		if file == null or file.get_length() > 1048576: continue
		var parser=JSON.new()
		var parse_error=parser.parse(file.get_as_text())
		file.close()
		if parse_error!=OK: continue
		var envelope=parser.data
		if not envelope is Dictionary or envelope.get("version") != 2: continue
		var payload = envelope.get("payload", "")
		if not payload is String or payload.sha256_text() != envelope.get("sha256", ""): continue
		if parser.parse(payload)!=OK: continue
		var data=parser.data
		if data is Dictionary and state.restore(data): return true
	last_error = "invalid or missing save"
	return false
func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
