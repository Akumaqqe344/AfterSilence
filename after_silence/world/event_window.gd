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
var hidden_people: Array=[]
var event_portrait: TextureRect
var portrait_index=-1
var puzzle_panel: Control
const NAMES={"escort":["Сопровождение","Escort"],"rhythm":["Ритм воспоминаний","Memory rhythm"],"stealth":["Наблюдение","Observation"],"switches":["Механизм","Mechanism"],"epochs":["Две эпохи","Two eras"],"defense":["Защита","Defense"],"route":["Безопасный путь","Safe route"],"evacuation":["Эвакуация","Evacuation"],"dodge":["Наблюдатель","The Watcher"],"repair":["Восстановление","Restoration"]}
const LEGACY_RULES={
	"stealth":["Держись за спиной. Не входи в красный сектор.","Stay behind. Avoid the red vision cone."],
	"epochs":["Проведи Соню к выходу. E рядом с дверью переключает её.","Guide Sonya to the exit. E near a door switches it."],
	"repair":["Держи E рядом со Львом. Отпускай, когда шкала красная.","Hold E near Lev. Release when the gauge turns red."],
	"rhythm":["Нажми E, когда кольцо становится бирюзовым.","Press E when the ring turns teal."],
	"escort":["Иди рядом с другом и обходи вспышки.","Stay with your friend and avoid the flashes."],
	"route":["Пройди безопасные проходы по порядку.","Follow safe passages in order."],
	"evacuation":["Нажми E рядом с жителем. Проведи всех в безопасную зону.","Press E near a resident and lead everyone to safety."]}
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index=30;mouse_filter=Control.MOUSE_FILTER_STOP
	var shade=ColorRect.new();shade.color=Color("20242df5");shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	frame=Panel.new();frame.position=Vector2(16,12);frame.size=Vector2(608,336)
	frame.add_theme_stylebox_override("panel",game.style(Color("1b3830"),true));add_child(frame)
	title=Label.new();title.position=Vector2(16,8);title.add_theme_font_size_override("font_size",10);title.modulate=game.ComfortTheme.PEACH;frame.add_child(title)
	event_portrait=TextureRect.new();event_portrait.position=Vector2(548,3);event_portrait.size=Vector2(36,36)
	event_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;event_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	event_portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;frame.add_child(event_portrait)
	goal=Label.new();goal.position=Vector2(16,31);goal.size=Vector2(530,41);goal.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;goal.add_theme_font_size_override("font_size",8 if game.comfort.large_text else 8);frame.add_child(goal)
	container=SubViewportContainer.new();container.position=Vector2(16,76);container.size=Vector2(576,216);frame.add_child(container)
	viewport=SubViewport.new();viewport.size=Vector2i(576,216);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.world_2d=game.get_world_2d();container.add_child(viewport)
	progress=ProgressBar.new();progress.position=Vector2(16,300);progress.size=Vector2(300,12);progress.show_percentage=false;frame.add_child(progress)
	progress.add_theme_font_size_override("font_size",1)
	progress.set_deferred("size",Vector2(248,10))
	health=Label.new();health.position=Vector2(280,296);health.add_theme_font_size_override("font_size",8);frame.add_child(health)
	var pause=Button.new();pause.text=game.t("Пауза · Esc","Pause · Esc");pause.position=Vector2(474,295);pause.size=Vector2(118,26);pause.add_theme_font_size_override("font_size",8);pause.pressed.connect(toggle_pause);frame.add_child(pause)
	controls_hint=Label.new();controls_hint.position=Vector2(16,319);controls_hint.add_theme_font_size_override("font_size",8)
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
	var activity=game.events_controller.activity
	if is_instance_valid(activity) and activity.board_mode():
		modulate.a=1
		container.hide()
		if activity.reality!=null:
			puzzle_panel=preload("res://after_silence/ui/reality_maze_panel.gd").new()
			puzzle_panel.model=activity.reality;puzzle_panel.resident=activity.npc
		else:
			puzzle_panel=preload("res://after_silence/ui/quiet_puzzle_panel.gd").new()
			puzzle_panel.model=activity.puzzle
		puzzle_panel.game=game
		puzzle_panel.position=container.position;puzzle_panel.size=Vector2(576,216)
		puzzle_panel.solved.connect(activity.win)
		puzzle_panel.changed.connect(func(): game._save(false))
		frame.add_child(puzzle_panel)
		controls_hint.text=game.t("Мышь / WASD / стрелки · Esc: пауза","Mouse / WASD / arrows · Esc: pause") if activity.reality!=null else game.t("Мышь или Tab / стрелки, Enter · Esc: пауза","Mouse or Tab / arrows, Enter · Esc: pause")
		return
	container.show()
	if is_instance_valid(game.living.camera_tween): game.living.camera_tween.kill()
	game.camera.zoom=Vector2.ONE*.75;game.camera.offset=Vector2(0,-80)
	if is_instance_valid(activity) and activity.mode!="tactics":
		activity.begin_view()
		for person in game.actors.values():
			if person not in activity.participants:
				person.set_meta("minigame_hidden",true);person.hide();person.collision_layer=0;hidden_people.append(person)
	if is_instance_valid(activity) and activity.mode=="epochs": activity.maze.open(viewport)
	else:
		viewport.world_2d=game.get_world_2d();move_world(viewport)
	if is_instance_valid(activity) and activity.mode=="tactics":
		viewport.size=Vector2i(576,176);container.size=Vector2(576,176)
		game.camera.zoom=Vector2.ONE*.7;game.camera.offset=Vector2.ZERO;game.camera.position=activity.center-game.player.position
		activity.tactics.set_paused(false)
		controls_hint.text=game.t("Стрелки: цель · E: подтвердить · Tab / Enter: действия · Esc: пауза","Arrows: target · E: confirm · Tab / Enter: actions · Esc: pause")
	else:
		viewport.size=Vector2i(576,216);container.size=Vector2(576,216)
		controls_hint.text=game.t("WASD / стрелки — идти · E — действие · Пробел — прыжок","WASD / arrows: move · E: action · Space: jump")
	if not game.comfort.reduce_motion:
		modulate.a=0;create_tween().tween_property(self,"modulate:a",1,.2)
func close():
	if not active: return
	active=false
	if is_instance_valid(puzzle_panel):
		frame.remove_child(puzzle_panel)
		puzzle_panel.queue_free()
		puzzle_panel=null
	var activity=game.events_controller.activity
	if is_instance_valid(activity) and activity.mode!="tactics": activity.end_view()
	if game.world.get_parent()==viewport: move_world(game)
	viewport.world_2d=game.get_world_2d()
	for person in hidden_people:
		if is_instance_valid(person):
			person.remove_meta("minigame_hidden");game.npcs.attach(game,person.get_meta("resident_id"))
	hidden_people.clear()
	game.camera.zoom=previous_zoom;game.camera.offset=previous_offset;game.camera.position=previous_position;game.camera.reset_smoothing()
	pause_panel.hide();pause_shade.hide();hide()
	game.objective.show();game.hint.show();game.toast.show()
func toggle_pause():
	if not active: return
	if is_instance_valid(puzzle_panel): puzzle_panel.remember_focus()
	var activity=game.events_controller.activity
	if is_instance_valid(activity) and activity.mode=="tactics": activity.tactics.set_paused(true)
	elif is_instance_valid(activity): activity.pause_actors()
	game.modal=true;pause_shade.show();pause_panel.show();pause_panel.get_child(0).grab_focus()
func resume():
	game._close();pause_panel.hide();pause_shade.hide()
	var activity=game.events_controller.activity
	if is_instance_valid(activity) and activity.mode=="tactics": activity.tactics.set_paused(false)
	if is_instance_valid(puzzle_panel): puzzle_panel.focus_board()
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
	if active and event is InputEventKey and (event.physical_keycode==KEY_E or (event.physical_keycode==0 and event.keycode==KEY_E)):
		var activity=game.events_controller.activity
		if is_instance_valid(activity):
			activity.action_input(event)
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
	if portrait_index!=director.index:
		portrait_index=director.index;event_portrait.texture=preload("res://after_silence/core/npc_appearance.gd").portrait(portrait_index)
	if activity.reality!=null:
		title.text=director.pair(event.title)
		goal.text=game.named(event.npc)+" · "+director.pair(event.context)
		progress.max_value=activity.goal();progress.value=activity.reality.stage
		health.text=game.t("Проходы ","Passages ")+"%d/%d"%[activity.reality.stage,activity.goal()]
		game.objective.hide();game.hint.hide();game.toast.hide()
		return
	if activity.puzzle!=null:
		title.text=director.pair(event.title)
		goal.text=game.named(event.npc)+" · "+director.pair(event.context)
		progress.max_value=activity.puzzle.goal();progress.value=activity.puzzle.progress()
		health.text=game.t("Готово ","Done ")+"%d/%d"%[activity.puzzle.progress(),activity.puzzle.goal()]
		game.objective.hide();game.hint.hide();game.toast.hide()
		return
	title.text=(game.t("Тактика","Tactics") if activity.mode=="tactics" else game.t("Лабиринт Сони","Sonya's maze") if activity.mode=="epochs" else director.pair(NAMES[activity.mode]))+" · "+director.pair(event.title)
	if activity.mode in ["dodge","defense"]: controls_hint.text=game.t("WASD: идти · Удерживай E: защита · Esc: пауза","WASD: move · Hold E: guard · Esc: pause")
	elif activity.mode=="epochs": controls_hint.text=game.t("WASD: идти · E: переключить двери · Не оставляй Соню","WASD: move · E: switch doors · Stay with Sonya")
	if activity.mode!="tactics":
		var rule=LEGACY_RULES.get(activity.mode,event.rule) if activity.mode!=event.mode else event.rule
		goal.text=activity.rule if activity.rule!="" else director.pair(rule)
	progress.max_value=activity.goal();progress.value=activity.progress
	health.text=game.t("Стойкость · ","Health · ")+"%d / 5"%activity.hp
	if activity.mode=="epochs": health.text=game.t("Соня рядом","Sonya is close") if game.player.position.distance_to(activity.npc.position)<90 else game.t("Подожди Соню","Wait for Sonya")
	if activity.mode in ["escort","defense","evacuation","dodge"]: health.text+=" · %02d:%02d"%[int(maxf(0,110-activity.elapsed))/60,int(maxf(0,110-activity.elapsed))%60]
	game.objective.hide();game.hint.hide();game.toast.hide()
func _exit_tree():
	if active and is_instance_valid(game) and not game.is_queued_for_deletion() and is_instance_valid(game.world) and game.world.get_parent()==viewport: move_world(game)
