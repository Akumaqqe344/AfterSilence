extends RefCounted

const REST=Color.WHITE
const HOVER=Color(1.13,1.075,1.025,1.0)
const PRESS=Color(.85,.90,.88,1.0)

static func wire_button(button: Button, comfort):
	button.mouse_entered.connect(func():_button_state(button,comfort))
	button.mouse_exited.connect(func():_button_state(button,comfort))
	button.focus_entered.connect(func():_button_state(button,comfort))
	button.focus_exited.connect(func():_button_state(button,comfort))
	button.button_down.connect(func():_button_state(button,comfort,true))
	button.button_up.connect(func():_button_state(button,comfort))

static func _button_state(button: Button, comfort, down: bool=false):
	if not button.is_inside_tree(): return
	if button.has_meta("tone_tween"):
		var prior=button.get_meta("tone_tween")
		if is_instance_valid(prior): prior.kill()
	if comfort.reduce_motion or button.disabled:
		button.self_modulate=REST
		return
	var highlighted=button.is_hovered() or button.has_focus()
	var target=PRESS if down else HOVER if highlighted else REST
	var duration=.07 if down else .13 if highlighted else .20
	var change=button.create_tween()
	button.set_meta("tone_tween",change)
	change.tween_property(button,"self_modulate",target,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func enter(node: Control, comfort, offset: Vector2=Vector2.ZERO, duration: float=.24) -> Tween:
	var destination=node.position
	node.modulate.a=1
	if comfort.reduce_motion: return null
	node.position=destination+offset
	node.modulate.a=.30
	var movement=node.create_tween().set_parallel(true)
	movement.tween_property(node,"position",destination,duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	movement.tween_property(node,"modulate:a",1.0,duration*.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return movement
