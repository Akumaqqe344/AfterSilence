extends RefCounted
var busy = false
func transition(owner_node: Node, veil: ColorRect, action: Callable, reduced: bool=false):
	if busy: return
	busy = true
	veil.show()
	var tween = owner_node.create_tween()
	tween.tween_property(veil,"modulate:a",1.0,0.07 if reduced else 0.24).set_trans(Tween.TRANS_SINE)
	await tween.finished
	action.call()
	tween = owner_node.create_tween()
	tween.tween_property(veil,"modulate:a",0.0,0.09 if reduced else 0.30).set_trans(Tween.TRANS_SINE)
	await tween.finished
	veil.hide()
	busy = false
