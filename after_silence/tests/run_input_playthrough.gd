extends SceneTree
func _initialize(): root.add_child.call_deferred(load("res://after_silence/tests/input_playthrough_driver.gd").new())
