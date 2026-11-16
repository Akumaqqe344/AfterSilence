extends Control
var game
var viewport: SubViewport
var frame: Panel
var title: Label
var goal: Label
var progress: ProgressBar
var health: Label
var controls_hint: Label
var pause_panel: Panel
var pause_shade: ColorRect
var active=false
var previous_zoom=Vector2.ONE
var previous_offset=Vector2.ZERO
var previous_position=Vector2.ZERO
var container: SubViewportContainer
const NAMES={"escort":["Сопровождение","Escort"],"rhythm":["Ритм воспоминаний","Memory rhythm"],"stealth":["Наблюдение","Observation"],"switches":["Механизм","Mechanism"],"epochs":["Две эпохи","Two eras"],"defense":["Защита","Defense"],"route":["Безопасный путь","Safe route"],"evacuation":["Эвакуация","Evacuation"],"dodge":["Наблюдатель","The Watcher"],"repair":["Восстановление","Restoration"]}
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index=30;mouse_filter=Control.MOUSE_FILTER_STOP
	var shade=ColorRect.new();shade.color=Color("20242df5");shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	frame=Panel.new();frame.position=Vector2(16,12);frame.size=Vector2(608,336)
	frame.add_theme_stylebox_override("panel",game.style(Color("1b3830"),true));add_child(frame)
	title=Label.new();title.position=Vector2(16,8);title.add_theme_font_size_override("font_size",15);title.modulate=game.ComfortTheme.PEACH;frame.add_child(title)
	goal=Label.new();goal.position=Vector2(16,31);goal.size=Vector2(576,41);goal.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;goal.add_theme_font_size_override("font_size",13 if game.comfort.large_text else 12);frame.add_child(goal)
	container=SubViewportContainer.new();container.position=Vector2(16,76);container.size=Vector2(576,216);frame.add_child(container)
	viewport=SubViewport.new();viewport.size=Vector2i(576,216);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.world_2d=game.get_world_2d();container.add_child(viewport)
	progress=ProgressBar.new();progress.position=Vector2(16,300);progress.size=Vector2(300,12);progress.show_percentage=false;frame.add_child(progress)
	progress.add_theme_font_size_override("font_size",1)
	progress.set_deferred("size",Vector2(248,10))
	health=Label.new();health.position=Vector2(280,296);health.add_theme_font_size_override("font_size",12);frame.add_child(health)
	var pause=Button.new();pause.text=game.t("Пауза · Esc","Pause · Esc");pause.position=Vector2(474,295);pause.size=Vector2(118,26);pause.add_theme_font_size_override("font_size",12);pause.pressed.connect(toggle_pause);frame.add_child(pause)
	controls_hint=Label.new();controls_hint.position=Vector2(16,319);controls_hint.add_theme_font_size_override("font_size",11)
	controls_hint.text=game.t("WASD / стрелки — идти · E — действие · Пробел — прыжок","WASD / arrows: move · E: action · Space: jump");frame.add_child(controls_hint)
	pause_shade=ColorRect.new();pause_shade.color=Color(0.08,0.09,0.13,.72);pause_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(pause_shade);pause_shade.hide()
	pause_panel=Panel.new();pause_panel.position=Vector2(150,91);pause_panel.size=Vector2(340,178);pause_panel.add_theme_stylebox_override("panel",game.style(Color("203e32"),true));add_child(pause_panel)
	for entry in [["Продолжить","Resume",resume],["Повторить","Retry",retry],["Сохранить и выйти","Save and leave",leave]]:
		var button=Button.new();button.text=game.t(entry[0],entry[1]);button.position=Vector2(16,16+pause_panel.get_child_count()*50);button.size=Vector2(308,42);button.pressed.connect(entry[2]);pause_panel.add_child(button)
	pause_panel.hide();hide()
func move_world(parent: Node):
	var activity=game.events_controller.activity
	if is_instance_valid(activity): activity.moving_world=true
	game.world.reparent(parent,false)
	if is_instance_valid(activity): activity.moving_world=false
	game.camera.reset_smoothing()
func open():
	if active: return
	active=true;pause_panel.hide();pause_shade.hide();show()
	previous_zoom=game.camera.zoom;previous_offset=game.camera.offset;previous_position=game.camera.position
	if is_instance_valid(game.living.camera_tween): game.living.camera_tween.kill()
	game.camera.zoom=Vector2.ONE*.75;game.camera.offset=Vector2(0,-80)
	move_world(viewport)
	var activity=game.events_controller.activity
	if is_instance_valid(activity) and activity.mode=="tactics":
		viewport.size=Vector2i(576,176);container.size=Vector2(576,176)
		game.camera.zoom=Vector2.ONE*.7;game.camera.offset=Vector2.ZERO;game.camera.position=activity.center-game.player.position
		activity.tactics.set_paused(false)
		controls_hint.text=game.t("Стрелки: цель · E: подтвердить · Tab / Enter: действия · Esc: пауза","Arrows: target · E: confirm · Tab / Enter: actions · Esc: pause")
	else:
		viewport.size=Vector2i(576,216);container.size=Vector2(576,216)
		controls_hint.text=game.t("WASD / стрелки — идти · E — действие · Пробел — прыжок","WASD / arrows: move · E: action · Space: jump")
	if is_instance_valid(activity) and activity.mode=="epochs": activity.set_epoch(activity.epoch)
	modulate.a=0;create_tween().tween_property(self,"modulate:a",1,.2)
func close():
	if not active: return
	active=false
	move_world(game)
	var activity=game.events_controller.activity
	if is_instance_valid(activity) and activity.mode=="epochs":
		game.world.modulate=activity.original_tint
		activity.clear_gate_navigation()
		for gate in activity.gates: gate.set_deferred("disabled",true)
	game.camera.zoom=previous_zoom;game.camera.offset=previous_offset;game.camera.position=previous_position;game.camera.reset_smoothing()
	pause_panel.hide();pause_shade.hide();hide()
	game.objective.show();game.hint.show();game.toast.show()
func toggle_pause():
	if not active: return
	var activity=game.events_controller.activity
	if is_instance_valid(activity) and activity.mode=="tactics": activity.tactics.set_paused(true)
	game.modal=true;pause_shade.show();pause_panel.show();pause_panel.get_child(0).grab_focus()
func resume():
	game._close();pause_panel.hide();pause_shade.hide()
	var activity=game.events_controller.activity
	if is_instance_valid(activity) and activity.mode=="tactics": activity.tactics.set_paused(false)
func retry():
	resume();close();game.events_controller.start_activity()
func leave():
	resume();close()
	game.events_controller.suspend()
func _input(event):
	var current=game.events_controller.activity
	if active and not game.modal and is_instance_valid(current) and current.mode=="tactics":
		if event is InputEventKey and current.tactics.key_input(event):
			get_viewport().set_input_as_handled();return
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			var local_position=container.get_global_transform_with_canvas().affine_inverse()*event.position
			if Rect2(Vector2.ZERO,Vector2(viewport.size)).has_point(local_position):
				current.tactics.mouse_input(local_position);get_viewport().set_input_as_handled();return
	if active and event is InputEventKey and event.physical_keycode==KEY_E:
		var activity=game.events_controller.activity
		if is_instance_valid(activity):
			activity.repair_hold=event.pressed
			if event.pressed and not event.echo and not game.modal: activity.interact()
		get_viewport().set_input_as_handled();return
	if active and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		if pause_panel.visible: resume()
		else: toggle_pause()
		get_viewport().set_input_as_handled()
func _process(_dt):
	if not active: return
	var director=game.events_controller
	if not is_instance_valid(director.activity): close();return
	var activity=director.activity
	var event=director.events[director.index]
	title.text=(game.t("Тактика","Tactics") if activity.mode=="tactics" else director.pair(NAMES[activity.mode]))+" · "+director.pair(event.title)
	if activity.mode!="tactics": goal.text=activity.rule if activity.rule!="" else director.pair(event.rule)
	progress.max_value=activity.goal();progress.value=activity.progress
	health.text=game.t("Стойкость · ","Health · ")+"%d / 5"%activity.hp
	if activity.mode in ["escort","defense","evacuation","dodge"]: health.text+=" · %02d:%02d"%[int(maxf(0,110-activity.elapsed))/60,int(maxf(0,110-activity.elapsed))%60]
	game.objective.hide();game.hint.hide();game.toast.hide()
func _exit_tree():
	if active and is_instance_valid(game) and not game.is_queued_for_deletion() and is_instance_valid(game.world) and game.world.get_parent()==viewport: move_world(game)
