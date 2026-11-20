extends SceneTree

func _initialize():
	root.add_child.call_deferred(preload("res://after_silence/tests/quiet_puzzles_driver.gd").new())
