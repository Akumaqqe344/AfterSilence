extends RefCounted
var busy = false
func transition(owner_node: Node, veil: ColorRect, action: Callable):
	if busy: return
	busy = true
	veil.show()
	var tween = owner_node.create_tween()
	tween.tween_property(veil,"modulate:a",1.0,0.22)
	await tween.finished
	action.call()
	tween = owner_node.create_tween()
	tween.tween_property(veil,"modulate:a",0.0,0.28)
	await tween.finished
	veil.hide()
	busy = false
