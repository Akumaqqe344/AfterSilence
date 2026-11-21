extends RefCounted

const State = preload("res://after_silence/core/world_state.gd")
const MAX_BYTES = 1048576
var path = "user://episode_slot.json"
var last_error = ""
var recovered_from = ""

func save(state) -> bool:
	last_error = ""
	var absolute = ProjectSettings.globalize_path(path)
	var payload = JSON.stringify(state.to_data())
	var envelope = JSON.stringify({"version": 2, "payload": payload, "sha256": payload.sha256_text()})
	var pending = absolute + ".tmp"
	if envelope.to_utf8_buffer().size() > MAX_BYTES:
		last_error = "save size"
		return false
	if not _write(pending, envelope):
		return false
	var backup = absolute + ".bak"
	if FileAccess.file_exists(absolute):
		var previous = _read(absolute)
		if not previous.is_empty() and State.new().restore(previous):
			var backup_pending = backup + ".tmp"
			if not _write(backup_pending, FileAccess.get_file_as_string(absolute)):
				return false
			if DirAccess.rename_absolute(backup_pending, backup) != OK:
				last_error = "backup commit"
				return false
		else:
			var quarantine = absolute + ".unreadable-" + str(Time.get_ticks_usec())
			if DirAccess.copy_absolute(absolute, quarantine) != OK:
				last_error = "preserve unreadable slot"
				return false
	if DirAccess.rename_absolute(pending, absolute) != OK:
		last_error = "save commit"
		return false
	return true

func _write(destination: String, content: String) -> bool:
	var file = FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		last_error = "write: " + str(FileAccess.get_open_error())
		return false
	file.store_string(content)
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK:
		last_error = "flush: " + str(error)
	return error == OK

func _read(candidate: String) -> Dictionary:
	var file = FileAccess.open(candidate, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var envelope = parser.data
	if not envelope is Dictionary or envelope.get("version") != 2:
		return {}
	var payload = envelope.get("payload", "")
	if not payload is String or payload.sha256_text() != envelope.get("sha256", ""):
		return {}
	if parser.parse(payload) != OK or not parser.data is Dictionary:
		return {}
	return parser.data

func load_state(state) -> bool:
	recovered_from = ""
	last_error = ""
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var candidate = path + suffix
		if not FileAccess.file_exists(candidate):
			continue
		var data = _read(candidate)
		if not data.is_empty() and state.restore(data):
			recovered_from = suffix
			return true
	last_error = "invalid or missing save"
	return false

func exists() -> bool:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			return true
	return false
