extends SceneTree

func _initialize() -> void:
	var runner=load("res://after_silence/tests/rift_driver.gd").new()
	root.add_child.call_deferred(runner)
