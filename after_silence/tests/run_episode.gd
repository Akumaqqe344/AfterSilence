extends SceneTree
func _initialize():
	var runner=load("res://after_silence/tests/episode_driver.gd").new()
	root.add_child.call_deferred(runner)

