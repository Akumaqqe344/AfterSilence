extends Control
const QuietPanel=preload("res://after_silence/ui/quiet_puzzle_panel.gd")
const RealityPanel=preload("res://after_silence/ui/reality_maze_panel.gd")
const TrialPanel=preload("res://after_silence/ui/journey_trial_panel.gd")
const StageArt=preload("res://after_silence/ui/trial_stage_art.gd")
const Ambience=preload("res://after_silence/ui/board_ambience.gd")
var game
var frame: Panel
var title: Label
var goal: Label
var progress: ProgressBar
var progress_label: Label
var controls_hint: Label
var pause_panel: Panel
var pause_shade: ColorRect
var active=false
var event_portrait: TextureRect
var puzzle_panel: Control
var decoration: Control
var entrance: Tween
var pause_motion: Tween
var bar_motion: Tween

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index=30;mouse_filter=Control.MOUSE_FILTER_STOP
	var shade=ColorRect.new();shade.color=Color("131e1aed");shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	frame=Panel.new();frame.position=Vector2(16,12);frame.size=Vector2(608,336)
	frame.add_theme_stylebox_override("panel",game.ComfortTheme.panel(Color("222f29"),true));add_child(frame)
	decoration=Ambience.new();decoration.game=game
	decoration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);frame.add_child(decoration)
	title=Label.new();title.position=Vector2(16,8);title.add_theme_font_override("font",game.ComfortTheme.HEADING);title.add_theme_font_size_override("font_size",17);title.modulate=game.ComfortTheme.PEACH;frame.add_child(title)
	event_portrait=TextureRect.new();event_portrait.position=Vector2(549,6);event_portrait.size=Vector2(37,39)
	event_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;event_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	event_portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;frame.add_child(event_portrait)
	goal=Label.new();goal.position=Vector2(16,32);goal.size=Vector2(530,41);goal.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;frame.add_child(goal)
	progress=ProgressBar.new();progress.position=Vector2(16,300);progress.size=Vector2(300,12);progress.show_percentage=false;frame.add_child(progress)
	progress.add_theme_font_size_override("font_size",1)
	progress.set_deferred("size",Vector2(248,10))
	progress_label=Label.new();progress_label.position=Vector2(280,296);progress_label.add_theme_font_size_override("font_size",11);frame.add_child(progress_label)
	var pause=Button.new();pause.text=game.t("Пауза · Esc","Pause · Esc");pause.position=Vector2(474,295);pause.size=Vector2(118,26);pause.add_theme_font_size_override("font_size",11);pause.pressed.connect(toggle_pause);frame.add_child(pause)
	game.ComfortMotion.wire_button(pause,game.comfort)
	controls_hint=Label.new();controls_hint.position=Vector2(16,319);controls_hint.add_theme_font_size_override("font_size",10)
	frame.add_child(controls_hint)
	pause_shade=ColorRect.new();pause_shade.color=Color(0.08,0.09,0.13,.72);pause_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(pause_shade);pause_shade.hide()
	pause_panel=Panel.new();pause_panel.position=Vector2(150,91);pause_panel.size=Vector2(340,178);pause_panel.add_theme_stylebox_override("panel",game.style(Color("203e32"),true));add_child(pause_panel)
	for entry in [["Продолжить","Resume",resume],["Повторить","Retry",retry],["Сохранить и выйти","Save and leave",leave]]:
		var button=Button.new();button.text=game.t(entry[0],entry[1]);button.position=Vector2(16,16+pause_panel.get_child_count()*50);button.size=Vector2(308,42);button.pressed.connect(entry[2]);pause_panel.add_child(button)
		game.ComfortMotion.wire_button(button,game.comfort)
	pause_panel.hide();hide()

func open():
	if active: return
	var director=game.events_controller
	var activity=director.activity
	if activity==null: return
	var event=director.events[director.index]
	active=true;pause_panel.hide();pause_shade.hide();show()
	decoration.begin(StageArt.accent(activity.mode))
	if is_instance_valid(entrance): entrance.kill()
	entrance=game.ComfortMotion.enter(frame,game.comfort)
	title.text=director.pair(event.title)
	goal.text=game.named(event.npc)+" · "+director.pair(event.context)
	event_portrait.texture=preload("res://after_silence/core/npc_appearance.gd").portrait(director.index)
	progress.max_value=activity.goal()
	if activity.reality!=null:
		puzzle_panel=RealityPanel.new()
		puzzle_panel.model=activity.reality;puzzle_panel.resident=director.npc
		controls_hint.text=game.t("Мышь / WASD / стрелки · Esc: пауза","Mouse / WASD / arrows · Esc: pause")
	elif activity.trial!=null:
		puzzle_panel=TrialPanel.new()
		puzzle_panel.model=activity.trial
		controls_hint.text=game.t("Мышь или Tab и Enter · Esc: пауза","Mouse or Tab and Enter · Esc: pause")
	else:
		puzzle_panel=QuietPanel.new()
		puzzle_panel.model=activity.puzzle
		controls_hint.text=game.t("Мышь или Tab / стрелки, Enter · Esc: пауза","Mouse or Tab / arrows, Enter · Esc: pause")
	puzzle_panel.game=game
	puzzle_panel.position=Vector2(16,76);puzzle_panel.size=Vector2(576,216)
	puzzle_panel.solved.connect(director.success)
	puzzle_panel.changed.connect(_changed)
	frame.add_child(puzzle_panel)
	_refresh()
	game.objective.hide();game.hint.hide();game.toast.hide()

func _refresh(animate: bool=false):
	var activity=game.events_controller.activity
	if is_instance_valid(bar_motion): bar_motion.kill()
	if animate and not game.comfort.reduce_motion:
		bar_motion=create_tween()
		bar_motion.tween_property(progress,"value",activity.progress(),.21).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else: progress.value=activity.progress()
	var prefix=game.t("Проходы ","Passages ") if activity.reality!=null else game.t("Готово ","Done ")
	progress_label.text=prefix+"%d/%d"%[activity.progress(),activity.goal()]

func _changed():
	_refresh(true)
	game._save(false)

func close():
	if not active: return
	active=false
	decoration.set_process(false)
	for animation in [entrance,pause_motion,bar_motion]:
		if is_instance_valid(animation): animation.kill()
	if is_instance_valid(puzzle_panel):
		frame.remove_child(puzzle_panel)
		puzzle_panel.queue_free();puzzle_panel=null
	pause_panel.hide();pause_shade.hide();hide()
	game.objective.show();game.hint.show();game.toast.show()

func toggle_pause():
	if not active or pause_panel.visible: return
	puzzle_panel.remember_focus()
	game.modal=true;pause_shade.show();pause_panel.show();pause_panel.get_child(0).grab_focus()
	if is_instance_valid(pause_motion): pause_motion.kill()
	pause_panel.position=Vector2(150,91)
	pause_motion=game.ComfortMotion.enter(pause_panel,game.comfort,Vector2(0,6),.20)

func resume():
	if is_instance_valid(pause_motion): pause_motion.kill()
	game._close();pause_panel.hide();pause_shade.hide()
	if is_instance_valid(puzzle_panel): puzzle_panel.focus_board()

func retry():
	resume();close();game.events_controller.start_activity()

func leave():
	resume();close();game.events_controller.suspend()

func _input(event):
	if active and event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_ESCAPE or event.keycode==KEY_ESCAPE):
		if pause_panel.visible: resume()
		else: toggle_pause()
		get_viewport().set_input_as_handled()
