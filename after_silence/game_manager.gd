extends Node2D
const State=preload("res://after_silence/core/world_state.gd")
const Saves=preload("res://after_silence/core/save_manager.gd")
const Evidence=preload("res://after_silence/core/evidence_manager.gd")
const Inventory=preload("res://after_silence/core/inventory_manager.gd")
const Quests=preload("res://after_silence/core/quest_manager.gd")
const Dialogues=preload("res://after_silence/core/dialogue_manager.gd")
const NPCs=preload("res://after_silence/core/npc_state_controller.gd")
const Audio=preload("res://after_silence/core/audio_manager.gd")
const Transitions=preload("res://after_silence/core/scene_transition_manager.gd")
const World=preload("res://after_silence/world/world_view.gd")
const Landmarks=preload("res://after_silence/world/district_landmarks.gd")
const Actor=preload("res://after_silence/world/pechatai_actor.gd")
const Enemy=preload("res://after_silence/world/pursuer.gd")
const Story=preload("res://after_silence/story.gd")
const Homes=preload("res://after_silence/world/homes.gd")
const Review=preload("res://after_silence/story_review.gd")
const Cutscenes=preload("res://after_silence/core/cutscene_director.gd")
const Atmosphere=preload("res://after_silence/world/atmosphere.gd")
const Achievements=preload("res://after_silence/core/achievements.gd")
const BossBattle=preload("res://after_silence/world/boss_battle.gd")
const Rift=preload("res://after_silence/world/rift_campaign.gd")


const ComfortTheme=preload("res://after_silence/ui/comfort_theme.gd")
const ComfortMotion=preload("res://after_silence/ui/comfort_motion.gd")
const PixelArt=preload("res://after_silence/core/ppae_art.gd")
const JourneyMenuButton=preload("res://after_silence/ui/menu_button.gd")
var comfort=preload("res://after_silence/ui/comfort_preferences.gd").new()
var modal_back: Callable
var state=State.new()
var saves=Saves.new()
var archive_saves: RefCounted
var rift_saves=Saves.new()
var event_saves=Saves.new()
var events_controller
var journey=preload("res://after_silence/world/journey.gd").new(self)
var investigations=preload("res://after_silence/world/investigation_director.gd").new(self)
var expanded_new_game=true
var expedition_new_game=true
var event_window
var route_guide: Control
var story_hud: Control
var evidence
var inventory
var quests
var dialogues
var npcs
var audio
var transitions=Transitions.new()
var world
var player
var camera: Camera2D
var wide_camera=false
var living
var adventure
var zoom_button: Button
var help_button: Button
var enemy
var battle: Control
var rift: Control


var actors: Dictionary={}
var ui: Control
var shade: ColorRect
var veil: ColorRect
var card: PanelContainer
var card_scroll: ScrollContainer
var column: VBoxContainer
var modal_backdrop: Control
var modal_tween: Tween
var toast_tween: Tween

var body: RichTextLabel
var objective: Label
var status: Label
var hint: Label
var toast: Label
var buttons: Dictionary={}
var modal=true
var in_menu=true
var departing_home=false
var type_progress=0.0
var autosave_age=0.0
var shift_cooldown=0.0
const ArchivePanel = preload("res://after_silence/ui/archive_board.gd")
const ArchiveModel = preload("res://after_silence/core/archive_trials.gd")
var selected_evidence=""
var dirty=false
var loading_save=false
var cutscenes=Cutscenes.new()
var expedition=preload("res://after_silence/world/expedition_ui.gd").new(self)
var talkkit_pilot
var shop=preload("res://after_silence/world/village_shop.gd").new(self)
var objectives
func t(ru: String,en: String) -> String:
	return en if state.language=="en" else ru
func named(id: String) -> String:
	var characters=preload("res://after_silence/world/npc_event_director.gd").CHARACTERS
	if characters.has(id): return t(characters[id][0],characters[id][1])
	return Story.pair(Story.NAMES.get(id,[id,id]),state.language)
func _ready():
	get_tree().auto_accept_quit=false
	RenderingServer.set_default_clear_color(Color("182e32"))
	archive_saves=saves
	rift_saves.path="user://rift_slot.json"
	event_saves.path="user://events_slot.json"
	if "--qa" in OS.get_cmdline_user_args(): event_saves.path="user://qa_events_slot.json"
	if "--qa" in OS.get_cmdline_user_args(): saves.path="user://qa_episode.json"
	if "--qa" in OS.get_cmdline_user_args(): rift_saves.path="user://qa_rift_slot.json"
	if "--qa" in OS.get_cmdline_user_args(): comfort.path="user://qa_comfort.cfg"
	comfort.load_preferences()
	if comfort.available:
		state.language=comfort.language
		state.volume=comfort.volume
		if comfort.fullscreen and "--qa" not in OS.get_cmdline_user_args(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	for id in ["as_left","as_right","as_up","as_down"]:
		if not InputMap.has_action(id): InputMap.add_action(id)
	for item in [["as_left",KEY_A,KEY_LEFT],["as_right",KEY_D,KEY_RIGHT],["as_up",KEY_W,KEY_UP],["as_down",KEY_S,KEY_DOWN]]:
		for key in [item[1],item[2]]:
			var event=InputEventKey.new()
			event.physical_keycode=key
			InputMap.action_add_event(item[0],event)
	_setup_services()
	_setup_ui()
	adventure=load("res://after_silence/world/adventure_system.gd").new()
	adventure.game=self
	ui.add_child(adventure)
	living=load("res://after_silence/world/living_world.gd").new()
	living.game=self
	ui.add_child(living)
	talkkit_pilot=preload("res://after_silence/world/talkkit_pilot.gd").new()
	talkkit_pilot.game=self
	add_child(talkkit_pilot)
	events_controller=preload("res://after_silence/world/npc_event_director.gd").new()
	events_controller.game=self
	ui.add_child(events_controller)
	event_window=preload("res://after_silence/world/event_window.gd").new()
	event_window.game=self
	ui.add_child(event_window)
	_build_world("town",Vector2(600,630))
	_main_menu()
	if "--qa-pixel-export" in OS.get_cmdline_user_args():
		var pixel_runner=load("res://after_silence/tests/pixel_world_driver.gd").new()
		pixel_runner.game=self
		get_tree().root.add_child.call_deferred(pixel_runner)
	if "--qa-ui-export" in OS.get_cmdline_user_args():
		var ui_runner=load("res://after_silence/tests/ui_comfort_driver.gd").new()
		ui_runner.game=self
		get_tree().root.add_child.call_deferred(ui_runner)
	if "--qa-events-export" in OS.get_cmdline_user_args():
		var event_runner=load("res://after_silence/tests/events_export_driver.gd").new()
		event_runner.game=self
		get_tree().root.add_child.call_deferred(event_runner)
	if "--qa-input-export" in OS.get_cmdline_user_args():
		var input_runner=load("res://after_silence/tests/input_playthrough_driver.gd").new()
		input_runner.game=self
		get_tree().root.add_child.call_deferred(input_runner)
	if "--qa-puzzles-export" in OS.get_cmdline_user_args() and "--qa" in OS.get_cmdline_user_args():
		var puzzle_runner=load("res://after_silence/tests/quiet_puzzles_driver.gd").new()
		puzzle_runner.game=self
		get_tree().root.add_child.call_deferred(puzzle_runner)
	if "--qa-wayfinding" in OS.get_cmdline_user_args() and "--qa" in OS.get_cmdline_user_args():
		var guide_runner=load("res://after_silence/tests/wayfinding_driver.gd").new()
		guide_runner.game=self
		get_tree().root.add_child.call_deferred(guide_runner)
	if "--qa-export" in OS.get_cmdline_user_args():
		var runner=load("res://after_silence/tests/episode_driver.gd").new()
		runner.game=self
		get_tree().root.add_child.call_deferred(runner)
	if "--qa-rift-export" in OS.get_cmdline_user_args():
		var rift_runner=load("res://after_silence/tests/rift_driver.gd").new()
		rift_runner.game=self
		get_tree().root.add_child.call_deferred(rift_runner)
	if "--qa-living-export" in OS.get_cmdline_user_args():
		var living_runner=load("res://after_silence/tests/living_export_driver.gd").new()
		living_runner.game=self
		get_tree().root.add_child.call_deferred(living_runner)
func _setup_services():
	if is_instance_valid(event_window): event_window.close()
	if is_instance_valid(events_controller):
		events_controller.dispose_activity()
		events_controller.npc=null
	objectives=preload("res://after_silence/core/objective_tracker.gd").new(state)
	objectives.quest_completed.connect(func(id):
		for quest in objectives.data.quests:
			if quest.id==id: _notify(t("Готово: ","Completed: ")+Story.pair(quest.title,state.language)))
	evidence=Evidence.new(state)
	inventory=Inventory.new(state)
	quests=Quests.new(state)
	dialogues=Dialogues.new(state)
	if npcs!=null: npcs.dispose(self)
	npcs=NPCs.new(state)
	npcs.restore_retired_assignments()
	if not state.changed.is_connected(_mark_dirty): state.changed.connect(_mark_dirty)
	if not is_instance_valid(audio):
		audio=Audio.new()
		add_child(audio)
	audio.set_mix(comfort.music_volume,comfort.effects_volume)
func _mark_dirty():
	dirty=true
	for id in Achievements.evaluate(state):
		if is_instance_valid(toast): _notify(t("Достижение: ","Achievement: ")+Story.pair(Achievements.ENTRIES[id],state.language))
func style(bg: Color, accent: bool=false) -> StyleBoxFlat:
	# Existing callers keep their world-specific tint; surfaces share spacing.
	return ComfortTheme.panel(bg.lerp(ComfortTheme.SURFACE,.78),accent)
func choice_style(active: bool, pressed: bool=false) -> StyleBoxFlat:
	return ComfortTheme.button(active,pressed)


func _setup_ui():
	var layer=CanvasLayer.new()
	add_child(layer)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.theme=ComfortTheme.create(comfort.large_text)
	story_hud=load("res://after_silence/world/story_hud.gd").new()
	story_hud.game=self
	story_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(story_hud)
	route_guide=preload("res://after_silence/world/route_guide.gd").new()
	route_guide.game=self
	route_guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(route_guide)
	objective=Label.new()
	objective.position=Vector2(17,13)
	objective.size=Vector2(235,34)
	objective.max_lines_visible=2
	objective.add_theme_constant_override("line_spacing",-2)
	objective.add_theme_font_size_override("font_size",13 if comfort.large_text else 11)
	objective.add_theme_color_override("font_outline_color",Color("172126"))
	objective.add_theme_constant_override("outline_size",0)
	objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(objective)
	help_button=Button.new()
	help_button.text="? H"
	help_button.tooltip_text=t("Помощь с текущей задачей","Help with your current goal")
	help_button.position=Vector2(554,32)
	help_button.size=Vector2(34,22)
	help_button.add_theme_font_size_override("font_size",11)
	help_button.pressed.connect(_quest_help)
	ui.add_child(help_button)
	help_button.size=Vector2(34,22)
	status=Label.new()
	status.hide()
	status.position=Vector2(17,49)
	status.add_theme_font_size_override("font_size",11)
	status.add_theme_color_override("font_color",Color("f2c79c"))
	status.add_theme_color_override("font_outline_color",Color("241f1d"))
	status.add_theme_constant_override("outline_size",3)
	ui.add_child(status)
	hint=Label.new()
	hint.position=Vector2(24,327)
	hint.size=Vector2(592,23)
	hint.add_theme_font_size_override("font_size",13 if comfort.large_text else 11)
	hint.add_theme_color_override("font_outline_color",Color("172126"))
	hint.add_theme_constant_override("outline_size",3)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(hint)
	toast=Label.new()
	toast.position=Vector2(90,278)
	toast.size=Vector2(460,40)
	toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_font_size_override("font_size",11)
	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(toast)
	shade=ColorRect.new()
	shade.color=Color.TRANSPARENT
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	modal_backdrop=load("res://after_silence/ui/modal_backdrop.gd").new()
	modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(modal_backdrop)
	card=PanelContainer.new()
	card.add_theme_stylebox_override("panel",style(Color(.025,.047,.052,.91)))
	shade.add_child(card)
	card_scroll=ScrollContainer.new()
	card_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	card_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.follow_focus=true
	card_scroll.scroll_deadzone=8
	card.add_child(card_scroll)
	column=VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",8)
	card_scroll.add_child(column)
	veil=ColorRect.new()
	veil.color=Color("071319")
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	veil.modulate.a=0
	veil.hide()
	ui.add_child(veil)
	battle=BossBattle.new()
	battle.visible=false
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle.won.connect(_boss_won)
	battle.left.connect(func():living.restore_camera();_close())
	battle.struck.connect(func(): audio.ping(state.volume))
	battle.hurt.connect(func(): audio.ping(state.volume))

	ui.add_child(battle)
	rift=Rift.new()
	rift.visible=false
	rift.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(rift)


	var loading=Label.new()
	loading.text=t("Город вспоминает…","The town remembers…")
	loading.position=Vector2(200,170)
	veil.add_child(loading)
func choice(id: String,ru: String,en: String,action: Callable) -> Dictionary:
	return {"id":id,"label":t(ru,en),"run":action}
func _dialog(id: String,title: String,text: String,actions: Array,animated: bool=true,main_layout: bool=false,compact: bool=false):
	modal=true
	modal_back=Callable()
	shade.show()
	card.show()
	buttons.clear()
	if is_instance_valid(modal_tween): modal_tween.kill()
	modal_backdrop.menu_mode=in_menu
	modal_backdrop.finish_mark=id.ends_with("_decision")
	modal_backdrop.configure_motion(not comfort.reduce_motion)
	var card_size=Vector2(257,244) if main_layout else Vector2(388,272) if compact else Vector2(518,298)
	var target=Vector2(43,82) if main_layout else (Vector2(640,360)-card_size)*.5
	card.position=target
	card.size=card_size
	var panel_style: StyleBox=PixelArt.panel("panel",12)
	if main_layout:
		panel_style=StyleBoxEmpty.new()
	else:
		panel_style.content_margin_left=16
		panel_style.content_margin_right=16
	card.add_theme_stylebox_override("panel",panel_style)
	card.modulate.a=1
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var header=Label.new()
	header.text=title
	header.add_theme_color_override("font_color",ComfortTheme.PEACH)
	header.add_theme_font_override("font",ComfortTheme.HEADING)
	header.add_theme_font_size_override("font_size",32 if main_layout else 20)
	header.autowrap_mode=TextServer.AUTOWRAP_OFF if main_layout else TextServer.AUTOWRAP_WORD_SMART
	var portrait_id=id.split("_")[0]
	if id=="intro": portrait_id="vera"
	if not main_layout and (portrait_id in actors or portrait_id=="vera"):
		var row=HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		var portrait_frame=PanelContainer.new()
		portrait_frame.add_theme_stylebox_override("panel",ComfortTheme.panel(Color("46574f")))
		var portrait=TextureRect.new()
		var atlas=AtlasTexture.new()
		atlas.atlas=player.sheet if portrait_id=="vera" else actors[portrait_id].sheet
		atlas.region=player.portrait if portrait_id=="vera" else actors[portrait_id].portrait
		portrait.texture=atlas
		portrait.custom_minimum_size=Vector2(40,40)
		portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_frame.add_child(portrait)
		row.add_child(portrait_frame)
		header.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(header)
		column.add_child(row)
	else: column.add_child(header)
	if main_layout:
		var rule=HSeparator.new()
		rule.custom_minimum_size=Vector2(84,6)
		rule.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		var ink=StyleBoxLine.new()
		ink.color=Color("a7745f")
		rule.add_theme_stylebox_override("separator",ink)
		column.add_child(rule)
	body=RichTextLabel.new()
	body.bbcode_enabled=false
	body.text=text
	body.fit_content=true
	body.scroll_active=false
	body.custom_minimum_size=Vector2(0,24)
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("default_color",ComfortTheme.TEXT)
	body.add_theme_font_size_override("normal_font_size",15 if comfort.large_text else 13)
	column.add_child(body)
	body.visible=not text.is_empty()
	var seen=dialogues.was_seen(id)
	if id!="": dialogues.record(id,title,text)
	body.visible_characters=0 if animated and not seen and not comfort.instant_text else -1
	type_progress=0
	for i in range(actions.size()):
		var item=actions[i]
		var button: Button
		if main_layout:
			var menu_button=JourneyMenuButton.new()
			menu_button.action_id=item.id
			menu_button.primary=item.id==("events_load" if event_saves.exists() else "events_new")
			button=menu_button
		else:
			button=Button.new()
		button.text=item.label
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size=Vector2(0,30 if main_layout else 26)
		button.add_theme_font_size_override("font_size",(16 if comfort.large_text else 15) if main_layout else (14 if comfort.large_text else 13))
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		button.pressed.connect(func():
			if departing_home or button.disabled: return
			if body.visible_characters>=0 and body.visible_characters<body.get_total_character_count():
				body.visible_characters=-1
				return
			audio.ping(state.volume)
			item.run.call())
		column.add_child(button)
		buttons[item.id]=button
		if item.id in ["back","close"]: modal_back=item.run
		if not main_layout and item.id in ["resume","start"] and i==0:
			button.add_theme_stylebox_override("normal",ComfortTheme.button(true))
		ComfortMotion.wire_button(button,comfort)
	_wire_dialog_focus()
	card_scroll.scroll_vertical=0
	modal_tween=ComfortMotion.enter(card,comfort,Vector2(-14,0) if main_layout else Vector2(0,10),.33)
	if main_layout and is_instance_valid(modal_tween):
		var delay=.025
		for button in buttons.values():
			button.modulate.a=.55
			modal_tween.tween_property(button,"modulate:a",1.0,.16).set_delay(delay)
			delay+=.025

func _wire_dialog_focus():
	var enabled=[]
	for button in buttons.values():
		if not button.disabled:
			enabled.append(button)
	if enabled.is_empty(): return
	for i in range(enabled.size()):
		var button=enabled[i]
		var previous=button.get_path_to(enabled[posmod(i-1,enabled.size())])
		var next=button.get_path_to(enabled[(i+1)%enabled.size()])
		button.focus_neighbor_top=previous
		button.focus_neighbor_bottom=next
		button.focus_previous=previous
		button.focus_next=next
	enabled[0].grab_focus()

func _story(id: String,actions: Array=[]):
	var d=Story.SCENES[id] if id in Story.SCENES else Review.SCENES[id]
	if actions.is_empty(): actions=[choice("close","Продолжить","Continue",_close)]
	var text=d[3] if state.language=="en" else d[2]
	if id in ["public","sealed"]:
		text+="\n\n"+t("Имя Сони остаётся в закрытой копии: обещание защищает её от наблюдателя.","Sonya's name stays in the sealed copy: your promise protects her from the observer.") if state.flag("protect_sonya") else "\n\n"+t("Соня названа в открытом свидетельстве. Она держится подальше от площади и больше не доверяет Вере.","Sonya is named in the public testimony. She avoids the square and no longer trusts Vera.")
		if state.flag("ribbon_returned"): text+="\n"+t("Красная лента на запястье Сони напоминает: Вера вернулась за ней.","The red ribbon on Sonya's wrist records that Vera came back for her.")
	_dialog(id,d[1] if state.language=="en" else d[0],text,actions)
func _close():
	if in_menu: return
	modal=false
	shade.hide()
	var focus=get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus): focus.release_focus()
	if is_instance_valid(player): player.enabled=true
	_save(false)
func _main_menu():
	in_menu=true
	_dialog("",t("После тишины","After Silence"),"",[
		choice("events_load","Продолжить","Continue",func():saves=event_saves;_load_game()),
		choice("events_new","Новое путешествие","New journey",_confirm_new_event),
		choice("settings","Настройки","Settings",_settings),
		choice("quit","Выйти","Quit",func():get_tree().quit())],false,true)
	buttons["events_load"].disabled=not event_saves.exists()
	_wire_dialog_focus()
func _confirm_new_event():
	if not event_saves.exists():
		_depart_home()
		return
	_dialog("",t("Начать сначала?","Begin again?"),t("Новое путешествие заменит текущее автосохранение.","A new journey replaces the current autosave."),[choice("back","Назад","Back",_main_menu),choice("restart","Начать новое путешествие","Begin a new journey",_depart_home)],false)
func _depart_home():
	if departing_home: return
	if not comfort.reduce_motion:
		departing_home=true
		if is_instance_valid(modal_tween): modal_tween.kill()
		card.hide()
		await modal_backdrop.play_departure()
		departing_home=false
	_new_event_game(expanded_new_game, expedition_new_game)
func _archive_menu():
	in_menu=true
	_dialog("",t("Архив","Archive"),"",[choice("load","Продолжить разлом","Continue rift",_continue_rift),choice("rift","Начать разлом заново","Restart rift",_new_rift_game),choice("archive_load","Продолжить архив","Continue archive",_continue_archive),choice("new","Начать архив заново","Restart archive",_new_game),choice("back","Назад","Back",_settings)],false)
func _new_event_game(expanded: bool=false, expeditions: bool=false):
	var lang=state.language
	var volume=state.volume
	state=State.new();state.language=lang;state.volume=volume
	saves=event_saves
	_setup_services()
	state.set_flag("event_campaign");state.set_flag("rift_mode")
	state.set_flag("case_chapters",expanded)
	state.set_flag("expedition_0330",expanded and expeditions)
	investigations.tracked=""
	state.set_flag("nadia_met");state.set_flag("catalog");state.set_flag("clock_solved")
	in_menu=false;modal=false;shade.hide();adventure.expanded=false
	if event_window.active: event_window.close()
	_build_world("town",Vector2(600,645))
	events_controller.start()
	investigations.install()
	_save(false)
func _continue_rift():
	saves=rift_saves
	_load_game()
func _continue_archive():
	saves=archive_saves
	_load_game()
func _new_rift_game():
	saves=rift_saves
	var lang=state.language
	var volume=state.volume
	state=State.new()
	state.language=lang
	state.volume=volume
	_setup_services()
	state.set_flag("rift_mode")
	in_menu=false
	modal=false
	shade.hide()
	_build_world("town",Vector2(600,600))
	rift.start(self)
	_save(false)

func _new_game():
	saves=archive_saves
	var lang=state.language
	var volume=state.volume
	state=State.new()
	state.language=lang
	state.volume=volume
	_setup_services()
	in_menu=false
	modal=false
	shade.hide()
	await _travel("town",Vector2(600,690))
	camera.offset=Vector2(25,-45)
	await cutscenes.play(self,"arrival",[{"kind":"sound"},{"kind":"move","actor":"vera","target":Vector2(600,630)},{"kind":"camera","offset":Vector2.ZERO,"duration":.5}])
	_story("intro")
func _load_game():
	if loading_save or transitions.busy: return
	if not saves.load_state(state):
		_dialog("",t("Нет читаемого сохранения","No readable save"),t("Основной и резервный файлы не прошли проверку. Они не удалены.","Neither the main nor backup file passed validation. They were not deleted."),[choice("menu","В меню","Main menu",_main_menu)],false)
		return
	if comfort.available:
		state.language=comfort.language
		state.volume=comfort.volume
	_setup_services()
	loading_save=true
	var checkpoint=state.minigame.duplicate(true)
	var event_checkpoint=state.event_state.duplicate(true)
	in_menu=false
	modal=false
	shade.hide()
	await _travel(state.zone,state.position,false)
	state.minigame=checkpoint
	state.event_state=event_checkpoint
	if state.flag("event_campaign"):
		investigations.tracked=""
		events_controller.start(true)
		investigations.install()
	elif state.flag("rift_mode") and not state.flag("rift_finished"): rift.start(self)
	loading_save=false
	var recovered = not saves.recovered_from.is_empty()
	_save(false)
	if recovered:
		_notify(t("История восстановлена из резервного файла.","Your story was recovered from a backup file."))

func _save(notify: bool=true):
	if loading_save or in_menu or not is_instance_valid(player): return
	npcs.capture(self)
	if state.flag("event_campaign") and is_instance_valid(events_controller) and not events_controller.preparing: state.event_state=events_controller.capture()
	state.minigame=preload("res://after_silence/core/minigame_checkpoint.gd").capture(rift) if rift.active else {}
	if not state.flag("event_campaign"): objectives.refresh()
	state.position=player.position
	if saves.save(state):
		dirty=false
		if notify: _notify(t("История сохранена","Story saved"))
	else: _notify(t("Не удалось сохранить. Предыдущая копия сохранена.","Save failed. The previous copy remains intact."))
func _travel(id: String,p: Vector2,persist: bool=true):
	if transitions.busy: return
	modal=false
	shade.hide()
	if persist and id!=state.zone and is_instance_valid(player): audio.door(player.position,state.volume)
	await transitions.transition(self,veil,func(): _build_world(id,p),comfort.reduce_motion)
	if state.flag("event_campaign"):
		var destination=""
		for place in journey.places.values():
			if place.zone==id: destination=journey.pair(place.name);break
		if investigations.Catalog.data.rooms.has(id): destination=investigations.locate(id)
		if not destination.is_empty(): story_hud.announce(destination)
	if persist: _save(false)
	if id in Homes.IDS: _notify(Story.pair(Homes.NAMES[Homes.IDS.find(id)],state.language))
func _build_world(id: String,p: Vector2):
	if is_instance_valid(events_controller): events_controller.detach_activity()
	npcs.detach(self)
	if is_instance_valid(living): living.restore_camera(0.0)
	if is_instance_valid(player) and player.has_meta("click_route"): player.remove_meta("click_route")
	if is_instance_valid(player):
		player.get_parent().remove_child(player)
	if not is_instance_valid(world):
		world=World.new()
		add_child(world)
	world.story_mode=state.flag("event_campaign")
	world.visual_comfort=comfort
	world.expedition_route_open = (id == "tide_station" and investigations.seen("tide_winch")) or (id == "bracken_clearing" and investigations.seen("bracken_lens"))
	world.build(id,state.echo)
	state.zone=id
	state.set_flag("explored_"+id)
	if not is_instance_valid(player):
		player=Actor.new()
		player.is_player=true
		player.art_id="vera"
		player.visual_comfort=comfort
		player.sheet=load("res://after_silence/assets/pechatai/player/walk.png")
		player.footstep.connect(_footstep)
		player.landed.connect(func():audio.landing(player.position,state.volume))
		camera=Camera2D.new()
		camera.position_smoothing_enabled=true
		camera.position_smoothing_speed=6
		player.add_child(camera)
		zoom_button=Button.new()
		zoom_button.text="± Z"
		zoom_button.position=Vector2(594,32)
		zoom_button.size=Vector2(34,22)
		zoom_button.add_theme_font_size_override("font_size",11)
		zoom_button.tooltip_text=t("Приблизить или отдалить камеру","Zoom the camera in or out")
		zoom_button.pressed.connect(_toggle_zoom)
		ui.add_child(zoom_button)
		zoom_button.size=Vector2(34,22)
	world.sorter.add_child(player)
	player.position=world.recover(p)
	player.enabled=true
	camera.limit_left=0
	camera.limit_top=0
	camera.limit_right=int(world.dimensions.x)
	camera.limit_bottom=int(world.dimensions.y)
	camera.reset_smoothing()
	var atmosphere=Atmosphere.new()
	atmosphere.zone=id
	atmosphere.echo=state.echo
	atmosphere.anchor=player
	atmosphere.game=self
	world.add_child(atmosphere)
	player.footstep.connect(atmosphere.footstep)
	player.landed.connect(atmosphere.landing)
	world.modulate=ComfortTheme.world_light(id,state.clock>=20 or state.clock<7,state.echo)
	npcs.populate(self)
	enemy=null
	if id=="forest":
		enemy=Enemy.new()
		enemy.world=world
		enemy.player=player
		enemy.position=world.recover(Vector2(990,180))
		enemy.last_seen=player.position
		enemy.caught.connect(_caught)
		world.sorter.add_child(enemy)
	audio.set_scene(state.echo,state.volume,state.zone)
	if is_instance_valid(adventure): adventure.populate()
	if id=="town" and rift.phase=="travel" and state.flag("rift_mode") and not state.flag("rift_finished") and rift.index<rift.STOPS.size():
		world.spot("rift_next",rift.STOPS[rift.index],"trace")
	if is_instance_valid(events_controller): events_controller.refresh_mementos()
	investigations.install()
func _npc(id: String,p: Vector2,path: String,color: Color=Color.WHITE):
	var actor=Actor.new()
	actor.art_id=id
	var appearance=preload("res://after_silence/core/npc_appearance.gd")
	actor.animated_idle=appearance.PROFILES.has(id)
	actor.visual_comfort=comfort
	actor.idle_clock=posmod(id.hash(),380)/100.0
	actor.sheet=appearance.sheet(id) if actor.animated_idle else load(path)
	actor.body_height=appearance.height(id)
	actor.npc_color=color
	actor.position=p
	actor.target=actor.position
	actor.set_meta("home",actor.position)
	world.sorter.add_child(actor)
	actors[id]=actor
	var caption=Label.new()
	caption.theme=ui.theme
	caption.position=Vector2(-75,-85)
	caption.size=Vector2(150,28)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",8)
	caption.add_theme_color_override("font_outline_color",Color("172126"))
	caption.add_theme_constant_override("outline_size",4)
	caption.hide()
	actor.add_child(caption)
	actor.set_meta("caption",caption)
func _physics_process(dt):
	var board_open=is_instance_valid(event_window) and event_window.active
	if is_instance_valid(help_button): help_button.visible=not modal and not in_menu and not rift.active and not battle.active and not board_open
	if is_instance_valid(zoom_button): zoom_button.visible=not modal and not in_menu and not rift.active and not battle.active and not board_open
	if is_instance_valid(objective): objective.visible=not modal and not in_menu and not rift.active and not battle.active and not board_open
	shift_cooldown=maxf(0,shift_cooldown-dt)
	if modal and is_instance_valid(body) and body.visible_characters>=0:
		type_progress+=dt*42
		body.visible_characters=int(type_progress)
		if body.visible_characters>=body.get_total_character_count(): body.visible_characters=-1
	if not is_instance_valid(player): return
	var enabled=not modal and not in_menu and not transitions.busy and not cutscenes.running and not battle.active and not rift.active and not adventure.expanded and not board_open
	player.enabled=enabled
	audio.set_listening(not in_menu and not rift.active)
	audio.duck_score = modal or board_open
	if is_instance_valid(enemy):
		enemy.active=enabled and state.flag("sonya_met") and not state.flag("returned")
		enemy.visible=state.flag("sonya_met") and not state.flag("returned")
		enemy.pressure=state.pressure
	npcs.update(self,dt,enabled)
	var danger=enabled and is_instance_valid(enemy) and enemy.active and enemy.position.distance_squared_to(player.position)<57600
	if danger and not status.visible: status.text=t("Преследователь рядом","The watcher is close")
	status.visible=danger
	if not enabled: return
	state.clock=fposmod(state.clock+dt/60,24)
	state.play_seconds+=dt
	autosave_age+=dt
	if autosave_age>20:
		autosave_age=0
		_save(false)
	objective.text=Story.pair(quests.objective(),state.language)
	if not state.flag("event_campaign") and rift.phase=="travel" and state.flag("rift_mode") and not state.flag("rift_finished") and rift.index<rift.STOPS.size():
		var delta=rift.STOPS[rift.index]-player.position
		var direction="→" if delta.x>40 else "←" if delta.x< -40 else "↓" if delta.y>0 else "↑"
		objective.text=t("К огоньку ","Follow the light ")+direction+"  "+str(int(delta.length()/16))+t(" шагов • E"," steps • E")
		if state.zone!="town": objective.text=t("Вернитесь в город, чтобы продолжить историю","Return to town to continue the story")
	var target=quests.target_npc()
	if state.residents.has(target):
		var zone=state.residents[target].zone
		if zone in Homes.IDS and zone!=state.zone: objective.text=t("Найдите ","Find ")+named(target)+" · "+Story.pair(Homes.NAMES[Homes.IDS.find(zone)],state.language)
	var night=state.clock>=20 or state.clock<7
	var tint=ComfortTheme.world_light(state.zone,night,state.echo)
	world.modulate=world.modulate.lerp(tint,minf(1,dt*2))
	var nearby=_nearest()
	world.focus_hotspot(nearby)
	hint.text=t("E — ","E — ")+_object_name(nearby) if nearby!="" else ""
	hint.size=Vector2(220,35)
	if nearby!="":
		var p=actors[nearby].position if actors.has(nearby) else player.position
		for spot in world.interactables:
			if spot.id==nearby: p=spot.position
		hint.position=((world.get_global_transform_with_canvas()*p)+Vector2(-110,18)).clamp(Vector2(8,58),Vector2(410,305))
func _notify(text: String):
	toast.text=text
	if is_instance_valid(toast_tween): toast_tween.kill()
	toast.modulate.a=1.0 if comfort.reduce_motion else 0.0
	toast_tween=create_tween()
	if not comfort.reduce_motion: toast_tween.tween_property(toast,"modulate:a",1.0,.18)
	toast_tween.tween_interval(3.0)
	if not comfort.reduce_motion: toast_tween.tween_property(toast,"modulate:a",0.0,.42)
	toast_tween.tween_callback(func():toast.text="")
func _footstep(loud: bool):
	var surface="earth"
	var position_on_ground: Vector2=player.position
	if world.paths.is_empty() or preload("res://after_silence/world/watercourse.gd").crossing_at(state.zone,position_on_ground):
		surface="wood"
	else:
		for feature in Landmarks.FEATURES.get(state.zone,[]):
			if not feature[1].has_point(position_on_ground): continue
			if feature[0] in ["stone","rune"]: surface="stone"
			elif feature[0]=="plank": surface="wood"
			break
	audio.footstep(position_on_ground,surface,loud,state.volume)
	if is_instance_valid(enemy): enemy.hear(player.position,loud and not state.flag("soft_steps"))
func _nearest() -> String:
	if rift.phase=="travel" and not state.flag("rift_finished") and rift.index<rift.STOPS.size() and state.zone=="town" and player.position.distance_to(rift.STOPS[rift.index])<52: return "rift_next"
	for spot in world.interactables:
		if spot.position.distance_to(player.position)<28 and (spot.id in Homes.IDS or spot.id in ["to_library","to_forest","to_town","leave_home","leave_shop","visit_shop","visit_orchard","visit_harbor","district_return"]):
			return spot.id
	var event_actor=""
	if state.flag("event_campaign") and is_instance_valid(events_controller) and events_controller.phase in ["observe","ready","suspended","decision"]:
		var actor=events_controller.npc
		if is_instance_valid(actor) and actor.is_visible_in_tree() and actor.position.distance_to(player.position)<55:
			var event: Dictionary=events_controller.events[events_controller.index]
			if not investigations.barrier(event.id): return event.npc
			event_actor=event.npc
	var case_spot=investigations.hit(player.position)
	if not case_spot.is_empty(): return case_spot
	if not event_actor.is_empty(): return event_actor
	var result=""
	var distance=55.0
	for id in actors:
		if not npcs.visible_here(id,state.zone): continue
		var d=actors[id].position.distance_to(player.position)
		if d<distance: distance=d;result=id
	for spot in world.interactables:
		if not can_interact(spot.id): continue
		var d=spot.position.distance_to(player.position)
		if d<distance: distance=d;result=spot.id
	return result
func can_interact(id: String) -> bool:
	if state.flag("event_campaign") and is_instance_valid(event_window) and event_window.active: return false
	if state.flag("event_campaign") and (id.begins_with("collect_") or id in ["rift_next","hotspot_lamp"]): return false
	if id in ["hotspot_window","hotspot_furniture"] and state.flag("examined_"+state.zone+"_"+id): return false
	if not state.flag("rift_mode"): return true
	return id not in ["photo","poster","ledger","clock","diagram","testimony","signature","medical","relay","mirror","catalog","library_light","ribbon","trace","shelter","home_memory"]
func _object_name(id: String) -> String:
	if id.begins_with("case_"): return investigations.label(id)
	if state.flag("event_campaign") and events_controller.owns(id):
		return events_controller.pair(events_controller.events[events_controller.index].title)
	if id.begins_with("landmark_"):
		var site: Dictionary=Landmarks.SITES.get(id.trim_prefix("landmark_"),{})
		if not site.is_empty(): return Story.pair(site.name,state.language)
	if actors.has(id): return named(id)
	if id=="village_hints": return adventure.label(id)
	if id.begins_with("hamlet_house_"): return adventure.label(id)
	if id in ["visit_shop","leave_shop","shop_counter","riverside_rest"]: return adventure.label(id)
	if id=="home_storage": return t("Домашний сундук","Home chest")
	if id=="bandage": return t("Перевязка","Dressing")
	if id=="keepsake": return t("Памятный знак","Keepsake")
	if id.begins_with("personal_") or id.begins_with("cache_") or id=="clinic_rest": return living.label(id)
	if is_instance_valid(adventure) and (id.begins_with("collect_") or id.begins_with("visit_") or id.begins_with("district_") or id.begins_with("hotspot_")): return adventure.label(id)
	if id=="rift_next": return t("Начать задание","Start event")
	if id in Homes.IDS: return t("войти: ","enter: ")+Story.pair(Homes.NAMES[Homes.IDS.find(id)],state.language)
	if id=="leave_home": return t("выйти на улицу","leave the house")
	if id=="home_memory": return t("осмотреть записи хозяина","read the resident's notes")
	if id in Story.NAMES: return named(id)
	if id=="survival": return t("Жива после рассвета","Alive after dawn")
	var extras={"fuse":["предохранитель","fuse"],"lens":["линза памяти","memory lens"],"key":["ключ от архива","archive key"],"date":["Момент отключения","The signal cut"],"coverup":["Переписанный список","The rewritten list"],"witness":["Живой свидетель","A living witness"]}
	if id in extras: return Story.pair(extras[id],state.language)
	var labels={"to_library":["войти в библиотеку","enter the library"],"to_town":["вернуться в город","return to town"],"to_forest":["пойти в лес","enter the forest"],"catalog":["каталог","catalogue"],"clock":["часы","clock"],"mirror":["зеркало","mirror"],"relay":["аварийное реле","emergency relay"],"library_light":["светильник","light socket"],"well":["отдохнуть у воды","rest at the well"],"trace":["след присутствия","trace of presence"],"shelter":["каменное укрытие","stone shelter"],"ribbon":["красная лента","red ribbon"]}
	if id in Story.CLUES: return Story.CLUES[id][1] if state.language=="en" else Story.CLUES[id][0]
	return Story.pair(labels.get(id,[id,id]),state.language)
func _input(_event: InputEvent) -> void:
	if departing_home: get_viewport().set_input_as_handled()

func _unhandled_key_input(event):
	if not event.is_pressed() or event.is_echo(): return
	if transitions.busy: return
	if rift.active: return
	if state.flag("event_campaign") and event_window.active:
		return

	if battle.active:
		if event.physical_keycode==KEY_SPACE: battle.jump()
		elif event.physical_keycode==KEY_E: battle.counter()
		return

	if cutscenes.running: return
	if modal:
		if event.physical_keycode==KEY_M and column.has_node("DistrictMap"):
			_close()
			return
		if event.physical_keycode==KEY_E and is_instance_valid(body): body.visible_characters=-1
		elif event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_9:
			var index=int(event.physical_keycode-KEY_1)
			if index<buttons.size() and not buttons.values()[index].disabled:
				buttons.values()[index].pressed.emit()
		elif event.physical_keycode==KEY_ESCAPE:
			if modal_back.is_valid():
				modal_back.call()
				return
			if in_menu: return
			_close()
		return
	match event.physical_keycode:
		KEY_M: _district_map()
		KEY_T: if state.flag("event_campaign"): journey.open()
		KEY_G: if state.flag("event_campaign"): _toggle_route_guide()
		KEY_H: _quest_help()
		KEY_Z: _toggle_zoom()
		KEY_E: interact(_nearest())
		KEY_J: _journal()
		KEY_I: _inventory()
		KEY_TAB: if not state.flag("rift_mode"): _shift()
		KEY_SPACE: player.jump(Input.is_physical_key_pressed(KEY_SHIFT))
		KEY_ESCAPE: _pause()
func _district_map():
	if not is_instance_valid(world) or not is_instance_valid(player): return
	var atlas=preload("res://after_silence/ui/district_map.gd").new()
	atlas.game=self
	var actions=[choice("close","Закрыть карту","Close map",_close)]
	if state.flag("event_campaign"):
		actions.push_front(choice("places","Места и маршруты","Places & directions",_travel_window))
	_dialog("",t("Карта · ","Map · ")+atlas.district_name(),"",actions,false)
	column.add_child(atlas)
	column.move_child(atlas,1)
	var footer=HBoxContainer.new()
	footer.add_theme_constant_override("separation",8)
	column.add_child(footer)
	for button in buttons.values():
		button.reparent(footer,false)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_wire_dialog_focus()

func _travel_window():
	if state.flag("event_campaign"): journey.open()
func _toggle_zoom():
	if not is_instance_valid(camera): return
	camera.position=Vector2.ZERO
	wide_camera=not wide_camera
	living.restore_camera(.22)
func _toggle_route_guide():
	comfort.route_guide=not comfort.route_guide
	_save_comfort()

func _quest_help():
	if state.flag("event_campaign"): journey.open();return
	_dialog("",t("Куда идти?","Where to go?"),shop.hint()+"\n"+t("Золотая отметка на карте — следующее событие. E — действие.","The gold map marker is the next event. E: interact."),[choice("map","Показать карту","Show map",func():_close();adventure.expanded=true),choice("close","Понятно","Got it",_close)],false)
func interact(id: String):
	if investigations.interact(id): return
	if id.begins_with("landmark_"):
		var site: Dictionary=Landmarks.SITES.get(id.trim_prefix("landmark_"),{})
		if not site.is_empty() and site.zone==state.zone and player.position.distance_to(site.point)<55.0:
			_notify(Story.pair(site.note,state.language))
			if not state.flag(id):
				state.set_flag(id)
				_save(false)
		return
	if state.flag("event_campaign"):
		var destinations={"to_library":"library","to_forest":"forest","home_lev":"home_lev","home_sonya":"home_sonya"}
		if destinations.has(id) and not journey.zone_allowed(destinations[id]):
			_notify(t("Путь пока закрыт. T — причина открытия.","This route is closed. T shows how it opens."));return
	if is_instance_valid(adventure) and adventure.handle(id): return
	if id=="rift_next": rift.arrive();return
	if id=="": return
	if id in Homes.IDS:
		_travel(id,Vector2(320,395));return
	if id=="leave_home":
		_travel("town",Homes.door(state.zone,state.echo));return
	if id=="home_memory":
		if state.flag("rift_mode"):
			return
		var index=Homes.IDS.find(state.zone)
		var notes=[t("На столе Нади карточки без фамилий. Она оставляет место для того, что ещё нельзя утверждать наверняка.","Nadia keeps unsigned charts, leaving room for what cannot yet be known."),t("Лев аккуратно подписал две цепи: насос и колокол. На полях — время следующего осмотра проводки.","Lev labelled two circuits: pump and bell. A wiring inspection is scheduled in the margin."),t("В доме Павла часы идут вперёд, но лист с датой собрания перевёрнут. Чернила на краях ещё видны.","Pavel's clock keeps moving, but the meeting record lies face down. Ink remains along its edges."),t("Соня оставила чашку и чистый лист. Здесь можно написать свою историю, когда появятся слова.","Sonya left a cup beside a blank page, waiting for words of her own.")]
		state.set_flag("visited_"+state.zone)
		_dialog("note_"+state.zone,Story.pair(Homes.NAMES[index],state.language),notes[index],[choice("close","Закрыть","Close",_close)]);return
	player.inspect_time=.6
	audio.touch(player.position,state.volume)
	if id in actors: _talk(id);return
	if state.flag("rift_mode") and id not in ["to_library","to_forest","to_town","well"]:
		return

	if id in Story.CLUES and id!="clock":
		if id=="signature" and not state.echo:
			_dialog("",_object_name(id),t("Страница кажется чистой. Под косым светом проступает вдавленный след подписи.","The page seems blank. Slanting light reveals an impression of a signature."),[choice("close","Назад","Back",_close)])
			return
		state.add_clue(id)
		_clue(id)
		return
	match id:
		"to_library":
			if state.flag("rift_finished") or state.flag("nadia_met"): _travel("library",Vector2(480,575))
			else: _notify(t("Сначала поговорите с Надей у колодца.","Speak to Nadia by the well first."))
		"to_forest":
			if state.flag("rift_finished") or state.flag("catalog") and state.flag("clock_solved"): _travel("forest",Vector2(700,940))
			else: _notify(t("Лесная дорога возвращает к площади. Найдите список и восстановите время события.","The trail returns to the square. Find the list and restore the time."))
		"to_town":
			if state.zone=="forest" and state.flag("sonya_met"): state.set_flag("returned")
			_travel("town",Vector2(600,760) if state.zone=="forest" else Vector2(600,250))
		"catalog": _catalog()
		"clock": state.add_clue("clock");_clock()
		"relay": _relay()
		"mirror": _shift()
		"library_light": _light_socket()
		"well":
			state.charges=3
			state.clock=fposmod(state.clock+1,24)
			state.pressure=maxi(0,state.pressure-1)
			_notify(t("Час у воды. Силы восстановлены; город продолжил свой день.","An hour by the water. Your strength returns; the town's day moves on."))
		"ribbon":
			if not state.flag("ribbon_taken"):
				state.give("ribbon")
				state.set_flag("ribbon_taken")
			_notify(t("Лентой можно смягчить шаги или сохранить её для Сони.","Use the ribbon to soften your steps, or keep it for Sonya."))
		"trace":
			_dialog("trace",t("След присутствия","Trace of presence"),t("В пыли два ряда следов: маленькие ноги уходят от затвора. Вторые следы возвращаются обратно. Утверждение «все остались внизу» не совпадает с тем, что сохранил пол.","Two sets of footprints: small feet leave the sluice. The other set returns. The claim that everyone stayed below disagrees with what the floor remembers."),[choice("close","Запомнить","Remember",func():state.set_flag("trace_found");_close())])
		"shelter": _notify(t("Внутри каменного круга след гаснет. Подождите и прервите видимость.","The stone circle hides your trace. Wait and break line of sight."))
	_save(false)
func _clue(id: String):
	var c=Story.CLUES[id]
	_dialog("clue_"+id,c[1] if state.language=="en" else c[0],c[3] if state.language=="en" else c[2],[choice("journal","Сопоставить в журнале","Connect in journal",_journal),choice("close","Продолжить","Continue",_close)])
func _rift_talk(id: String):
	var lines={
		"nadia":[t("После суда врачей больше не прогоняют от площади.","After the trial, physicians are welcome at the square."),t("Я помню, как ты осталась рядом.","I remember you stayed beside me.")],
		"lev":[t("Механизм остановлен. Письмо всё ещё у меня.","The device is stable. I still have the letter."),t("Ограниченная мощность дала нам время.","The limited output gave us time.")],
		"mara":[t("В архиве теперь две версии событий.","The archive now keeps both accounts."),t("Следить было правильнее, чем обвинять.","Following was wiser than accusing.")],
		"pavel":[t("Мост открыт. Ночь больше не повторяется.","The bridge is open. That night no longer repeats."),t("Мы охраняем мост вместе.","We guard the bridge together.")],
		"sonya":[t("Алина больше не одна в разломе.","Alina is no longer alone inside the rift."),t("Я записала её историю без чужих догадок.","I recorded her story without guesses.")]
	}
	var special=state.flag({"nadia":"rift_choice_08_defend","lev":"rift_choice_04_limit","mara":"rift_choice_02_follow","pavel":"rift_choice_05_guard","sonya":"rift_choice_11_trust"}.get(id,""))
	_dialog("rift_talk_"+id,named(id),lines.get(id,[t("Город снова меняется, но люди помнят друг друга.","Town still changes, but its people remember one another.")])[1 if special else 0],[choice("close","Продолжить","Continue",_close)],false)
func _talk(id: String):
	if investigations.followup(id): return
	if is_instance_valid(events_controller) and events_controller.talk(id): return
	if living.talk(id): return
	if state.flag("rift_mode"): _rift_talk(id);return
	if state.flag("ending") and id=="nadia":
		_story("nadia_public" if state.flag("ending_public") else "nadia_sealed");return
	if state.flag("returned") and not state.flag("ending"):
		if id=="nadia" and not state.flag("nadia_review"):
			_story("nadia_records",[choice("records","Сохраню её слова отдельно от своих догадок","I will keep her words separate from my guesses",func():state.set_flag("nadia_review");state.add_clue("medical");npcs.change_relation(id,1);_story("nadia_receipt"))]);return
		if id=="lev" and not state.flag("lev_review"):
			_story("lev_account",[choice("statement","Записать и ответственность, и распоряжение","Record both responsibility and instruction",func():state.set_flag("lev_review");state.set_flag("lev_informed");npcs.change_relation(id,1);_story("lev_statement"))]);return
		if id=="mara" and not state.flag("mara_review"):
			_story("mara_account",[choice("copy","Попросить второй экземпляр без готового ответа","Ask for the second copy without a ready answer",func():state.set_flag("mara_review");npcs.change_relation(id,1);_story("mara_release"))]);return
	if id=="nadia":
		if not state.flag("nadia_met"):
			_story("nadia_intro",[choice("promise","Обещаю искать правду, а не удобный ответ","I promise to seek truth, not comfort",func():state.set_flag("nadia_met");state.set_flag("promise");npcs.change_relation(id,1);state.give("key");_close()),choice("cautious","Я пока ничего не могу обещать","I cannot promise anything yet",func():state.set_flag("nadia_met");state.give("key");_close())])
		else: _story("nadia_again")
	elif id=="lev":
		if not state.flag("fuse_given"):
			_story("lev_intro",[choice("fuse","Взять предохранитель и пообещать рассказать о находках","Take the fuse and promise to share findings",func():state.set_flag("fuse_given");state.give("fuse");npcs.change_relation(id,1);_close()),choice("later","Пока не брать","Not yet",_close)])
		else: _story("lev_again",[choice("share","Показать переписанный список","Share the rewritten list",func():
			if "ledger" in state.evidence and not state.flag("lev_informed"): state.set_flag("lev_informed");npcs.change_relation(id,1)
			_close()),choice("close","До встречи","Goodbye",_close)])
	elif id=="mara":
		state.set_flag("mara_met")
		_story("mara_lens" if state.flag("catalog") else "mara_intro")
	elif id=="sonya":
		if state.flag("sonya_met"): _story("sonya_after");return
		if not state.flag("forest_power"):
			_notify(t("Шум реле заглушает голос. Сначала восстановите питание.","The relay drowns out her voice. Restore power first."));return
		_story("sonya",[choice("protect","Твоё имя останется между нами","Your name stays between us",func():state.set_flag("protect_sonya");npcs.change_relation(id,2);_start_chase()),choice("name","Городу нужен свидетель с именем","The town needs a named witness",func():npcs.change_relation(id,-2);_start_chase())])
	elif id=="pavel":
		if state.flag("ending"): _story("public" if state.flag("ending_public") else "sealed");return
		if not state.flag("returned") or not "witness" in state.links or not "coverup" in state.links or not "survival" in state.links or not state.flag("lev_review") or not state.flag("mara_review"):
			_story("pavel_before");return
		if not state.flag("boss_watcher_defeated"): _begin_boss("watcher");return

		_story("pavel_truth",[choice("public","Оставить оба списка на площади","Publish both versions of the list",func():_ending(true)),choice("seal","Запереть список. Сохранить сегодняшний покой","Seal the list. Preserve today's peace",func():_ending(false))])
func _begin_boss(id: String):
	living.focus("boss")
	modal=false
	shade.hide()
	battle.reduced_motion=comfort.reduce_motion
	battle.start(id,state.language=="en")
func _boss_won(id: String,flawless: bool):
	state.set_flag("boss_"+id+"_defeated")
	if id=="relay" and flawless: state.set_flag("boss_relay_flawless")
	if id=="relay": _relay()
	else: _talk("pavel")

func _start_chase():
	if state.item("ribbon")>0 and state.flag("ribbon_kept"):
		state.give("ribbon",-1)
		state.set_flag("ribbon_returned")
		npcs.change_relation("sonya",2)
	state.add_clue("testimony")
	if not state.flag("sonya_met"):
		state.set_flag("sonya_met")
		if is_instance_valid(enemy):
			enemy.position=world.recover(Vector2(990,180))
			enemy.last_seen=player.position
	_close()
func _caught():
	player.modulate=Color("d48c93")
	create_tween().tween_property(player,"modulate",Color.WHITE,.8)
	state.pressure=mini(5,state.pressure+1)
	state.charges=maxi(0,state.charges-1)
	state.set_flag("caught_once")
	player.position=world.recover(Vector2(700,850))
	enemy.position=world.recover(Vector2(1040,280))
	_story("caught")
func _ending(public: bool):
	state.set_flag("ending_public",public)
	state.set_flag("ending")
	state.echo=not public
	npcs.change_relation("pavel",-2 if public else 1)
	npcs.change_relation("nadia",2 if public else -1)
	_build_world("town",Vector2(600,600))
	_story("public" if public else "sealed",[choice("walk","Вернуться на площадь","Return to the square",_close),choice("menu","В главное меню","Main menu",func():_save(false);_main_menu())])
	_save(false)
func _shift():
	if state.item("lens")==0: _notify(t("Зеркало не отвечает. Откройте каталог библиотеки.","The mirror is silent. Open the library catalogue."));return
	if shift_cooldown>0: _notify(t("Дайте отражению успокоиться.","Let the reflection settle."));return
	if state.charges<=0: _notify(t("Нужен отдых у городского колодца.","Rest at the town well first."));return
	state.charges-=1
	state.echo=not state.echo
	shift_cooldown=8
	modal=false
	shade.hide()
	_travel(state.zone,player.position)
func _catalog():
	if state.flag("catalog"):
		_clue("ledger")
		return
	var description = t("Вложите карточки в папку в порядке учебной тревоги. На площади сохранилась афиша с этой считалкой.", "File the cards in the order of the drill. The square still has the poster with its rhyme.")
	if "poster" in state.evidence:
		description += "\n" + t("Строка с афиши: «Дождь. Колокол. Тишина».", "The poster reads “Rain. Bell. Silence.”")
	_open_archive_board("catalog",t("Каталог эвакуации","Evacuation catalogue"),description)

func _clock():
	if state.flag("clock_solved"):
		_clue("clock")
		return
	var linked = "date" in state.links
	var description = t("Свяжите афишу и часы в журнале. Без этого времени на циферблате будет недостаточно.", "Connect the poster and clock in the journal. The time alone won't establish what happened.")
	if linked:
		description = t("Афиша называет 02:17. Часы остановили при отключении сигнала. Введите время, которое подтверждают оба свидетельства.", "The poster gives 02:17. The clock stopped at the signal cut. Enter the time supported by both records.")
	_open_archive_board("clock",t("Остановленные часы","The stopped clock"),description,[choice("journal","Открыть журнал","Open the journal",_journal)])

func _relay():
	if state.flag("forest_power"):
		_notify(t("Насос работает тихо.","The pump runs quietly."))
		return
	if not state.flag("boss_relay_defeated"):
		_begin_boss("relay")
		return
	_open_archive_board("relay",t("Аварийное реле","Emergency relay"),t("Соедините источник слева с обеими ветвями насоса. Колокол оставьте без питания. Проверка не расходует предохранитель.","Connect the supply at left to both pump branches. Leave the bell unpowered. Testing uses no fuse."))

func _open_archive_board(kind: String, heading: String, description: String, actions: Array = []):
	actions.append(choice("close","Отойти","Step away",_close))
	_dialog("",heading,description,actions,false)
	var board = ArchivePanel.new()
	board.kind = kind
	board.game = self
	board.values = ArchiveModel.checkpoint(kind,state.archive_boards.get(kind))
	column.add_child(board)
	column.move_child(board,2)
	board.changed.connect(func(values: Array):
		state.archive_boards[kind] = values
		audio.trial_move("railway" if kind=="relay" else "letter_press",true,state.volume)
		_save(false))
	board.checked.connect(func(): audio.trial_move("railway",ArchiveModel.solved(kind,board.values),state.volume))
	board.confirmed.connect(_confirm_archive_board.bind(kind,board))
	for control in buttons.values():
		control.focus_next = NodePath()
		control.focus_previous = NodePath()
	if not board.tools.is_empty(): board.tools.front().grab_focus()

func _confirm_archive_board(kind: String, board):
	var accepted = ArchiveModel.solved(kind,board.values)
	var feedback = t("Проверьте порядок по афише.","Compare the order with the poster.")
	if kind == "clock":
		accepted = accepted and "date" in state.links
		feedback = t("Сначала свяжите афишу и часы в журнале.","Connect the poster and clock in the journal first.") if not "date" in state.links else t("Сверьте часы и минуты с записью.","Check both hours and minutes against the record.")
	elif kind == "relay":
		feedback = t("Нужны обе ветви насоса при отключённом колоколе.","Connect both pump branches with the bell unpowered.")
		if accepted and not inventory.install_fuse("forest_power"):
			accepted = false
			feedback = t("Нужен предохранитель Льва или деталь из библиотечного светильника.","You need Lev's fuse or the one from the library light.")
	if not accepted:
		board.message(feedback,false)
		audio.trial_move("railway",false,state.volume)
		return
	state.archive_boards.erase(kind)
	audio.scene_cue("memory",state.volume)
	match kind:
		"catalog":
			state.set_flag("catalog")
			state.add_clue("ledger")
			state.give("lens")
			_clue("ledger")
		"clock":
			state.set_flag("clock_solved")
			_dialog("clock_restored","02:17",t("Колокол отзывается одним ударом. Лесная дорога открылась. Запись отмечает отключение сигнала. В описи этот момент ошибочно приняли за время гибели.","A bell rings once. The forest road is open. The record marks the signal cut. The register mistook that moment for a time of death."),[choice("close","Продолжить","Continue",_close)])
		"relay":
			_dialog("power",t("Тихий запуск","Quiet start"),t("Насос включился. Колокол молчит. В отголоске кто-то выходит из восточного укрытия.","The pump starts. The bell stays quiet. In the echo, someone leaves the eastern shelter."),[choice("close","Продолжить","Continue",_close)])
	_save(false)

func _light_socket():
	var installed=state.flag("library_light")
	_dialog("",t("Свет библиотеки","Library light"),t("Это гнездо и лесное реле используют одну деталь. Свет помогает читать обычные страницы, но не проявляет чернила отголоска.","This socket and the forest relay use the same part. The light helps with ordinary pages, but cannot reveal echo ink."),[choice("fuse","Извлечь предохранитель" if installed else "Поставить предохранитель","Remove fuse" if installed else "Install fuse",func():
		if installed: inventory.remove_library_fuse()
		elif not inventory.install_fuse("library_light"): _notify(t("Нужна деталь Льва.","You need Lev's part."))
		_close()),choice("close","Назад","Back",_close)],false)
func _journal():
	if state.flag("event_campaign"):
		if state.flag("case_chapters"): investigations.journal()
		else: events_controller.journal()
		return
	if state.flag("rift_mode"):
		var completed=0
		var event_lines=[]
		var quest_steps=quests.steps()
		for event_index in range(Rift.QUESTS.size()):
			var step=quest_steps[event_index]
			if step[0]: completed+=1
			event_lines.append(("◆  " if step[0] else "◇  ")+t(step[1],step[2]))
			if step[0]:
				for option in Rift.QUESTS[event_index].choices:
					var outcome_id="%02d_%s"%[event_index+1,option[0]]
					if state.flag("rift_choice_"+outcome_id): event_lines.append("    "+Story.pair(Rift.OUTCOMES[outcome_id],state.language))
		var progress=t("СОБЫТИЯ ","EVENTS ")+str(completed)+"/12\n\n"+"\n".join(event_lines)
		progress+="\n\n"+objectives.journal(state.language)
		_dialog("",t("История разлома","The rift story"),progress,[choice("routines","Жители и время","Residents and time",expedition.routines),choice("achievements","Достижения","Achievements",_achievements),choice("close","На карту","Return",_close)],false)
		return
	var names=PackedStringArray()
	for id in state.links: names.append(_object_name(id))
	var text=t("ЦЕЛЬ · ","OBJECTIVE · ")+Story.pair(quests.objective(),state.language)+"\n\n"
	for step in quests.steps(): text+=("◆  " if step[0] else "◇  ")+t(step[1],step[2])+"\n"
	text+="\n"+t("Связи: ","Connections: ")+", ".join(names)+"\n"+t("Выберите две разные улики: сначала одну, затем вторую.","Choose one clue, then another.")
	var actions=[]
	for id in state.evidence: actions.append(choice(id,_object_name(id),_object_name(id),func():_select_clue(id)))
	actions.append(choice("history","История разговоров","Dialogue history",_history))
	actions.append(choice("achievements","Достижения","Achievements",_achievements))

	actions.append(choice("close","На карту","Return",_close))
	_dialog("",t("Журнал расследования","Investigation journal"),text,actions,false)
func _achievements():
	var lines=[]
	for id in Achievements.ENTRIES:
		var label=Story.pair(Achievements.ENTRIES[id],state.language)
		lines.append(("◆  " if id in state.achievements else "◇  ")+label)
	var count=state.achievements.size()
	_dialog("",t("Достижения","Achievements"),t("Открыто: ","Unlocked: ")+str(count)+"/"+str(Achievements.ENTRIES.size())+"\n\n"+"\n".join(lines),[choice("back","В журнал","Journal",_journal)],false)

func _select_clue(id: String):
	if selected_evidence=="": selected_evidence=id;_clue_with_links(id);return
	var first=selected_evidence
	selected_evidence=""
	var connection=evidence.connect_clues(first,id)
	_notify(t("Связь найдена: ","Connection found: ")+_object_name(connection) if connection!="" else t("Эти свидетельства пока не объясняют друг друга.","These clues do not yet explain one another."))
	_journal()
func _clue_with_links(id: String):
	var c=Story.CLUES[id]
	_dialog("",_object_name(id),c[3] if state.language=="en" else c[2],[choice("choose","Выбрать вторую улику","Choose second clue",_journal),choice("cancel","Отменить выбор","Cancel selection",func():selected_evidence="";_journal())],false)
func _history():
	var lines=[]
	for entry in state.history:
		if entry is Dictionary: lines.append(str(entry.get("speaker",""))+": "+str(entry.get("body","")))
	_dialog("",t("Разговоры","Conversation log"),"\n\n".join(lines),[choice("back","В журнал","Journal",_journal)],false)
func _inventory():
	expedition.inventory()
func _item(id: String):
	if id=="bandage":
		if state.item(id)>0 and state.charges<3:
			state.give(id,-1);state.charges=3;_save(false);_inventory()
		else: _notify(t("Силы уже полные.","Energy is already full."))
	elif id=="keepsake": _notify(t("Павел ищет такой знак для ночного дозора.","Pavel needs this token for night patrol."))
	elif id=="lens": _shift()
	elif id=="ribbon":
		_dialog("",t("Красная лента","Red ribbon"),t("Обернуть лентой металлические пряжки? Она уменьшит слышимость бега, но Соня больше не получит её как знак обещания.","Wrap the ribbon around your buckles? Running becomes quieter, but you cannot give it to Sonya as a token of your promise."),[choice("use","Смягчить шаги","Soften footsteps",func():state.give("ribbon",-1);state.set_flag("soft_steps");_close()),choice("keep","Оставить для Сони","Keep for Sonya",func():state.set_flag("ribbon_kept");_close())])
	else: _notify(t("Используйте предмет у подходящего объекта.","Use this item at the matching object."))
func _pause():
	_dialog("",t("Пауза","Pause"),"",[choice("resume","Продолжить","Resume",_close),choice("save","Сохранить","Save",func():_save();_close()),choice("load","Загрузить","Load",_load_game),choice("settings","Настройки","Settings",_settings),choice("menu","В меню","Main menu",func():_save(false);_main_menu())],false,false,true)
	var slot_button=Button.new()
	slot_button.text=t("Три слота сохранения","Three save slots")
	slot_button.custom_minimum_size=Vector2(0,32)
	slot_button.pressed.connect(expedition.slots)
	column.add_child(slot_button)
	buttons["slots"]=slot_button
	_wire_dialog_focus()
func _settings():
	var actions=[choice("back","Готово · Esc","Done · Esc",func():
		if in_menu: _main_menu()
		else: _pause())]
	if in_menu: actions.push_front(choice("archive","Архив","Archive",_archive_menu))
	_dialog("",t("Настройки","Settings"),"",actions,false)
	var mixer = HBoxContainer.new()
	mixer.add_theme_constant_override("separation",10)
	column.add_child(mixer)
	column.move_child(mixer,2)
	var slider = _add_mix_slider(mixer,"VolumeSlider",t("Общая","Master"),"volume")
	_add_mix_slider(mixer,"MusicSlider",t("Музыка","Music"),"music_volume")
	_add_mix_slider(mixer,"EffectsSlider",t("Эффекты","Effects"),"effects_volume")
	var grid=GridContainer.new()
	grid.name="ComfortOptions"
	grid.columns=2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	var entries=[
		["lang",t("Язык · Русский","Language · English"),func():state.language="en" if state.language=="ru" else "ru";_save_comfort();_settings();buttons["lang"].grab_focus()],
		["fullscreen",t("Окно / полный экран","Window / fullscreen"),func():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN);_save_comfort()],
		["large_text",t("Крупный текст","Larger text"),func():_toggle_comfort("large_text")],
		["reduce_motion",t("Меньше анимаций","Reduced motion"),func():_toggle_comfort("reduce_motion")],
		["instant_text",t("Текст сразу","Instant dialogue"),func():_toggle_comfort("instant_text")],
		["controls",t("Как играть","How to play"),_controls_help]]
	for entry in entries:
		var button=Button.new()
		button.name=entry[0];button.text=entry[1]
		if entry[0] in ["large_text","reduce_motion","instant_text"]:
			button.text=("✓  " if comfort.get(entry[0]) else "○  ")+button.text
		button.custom_minimum_size=Vector2(0,26)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		button.pressed.connect(entry[2])
		grid.add_child(button)
		ComfortMotion.wire_button(button,comfort)
		buttons[entry[0]]=button
	column.add_child(grid)
	column.move_child(grid,3)
	for button in buttons.values():
		button.focus_neighbor_top=NodePath();button.focus_neighbor_bottom=NodePath()
		button.focus_previous=NodePath();button.focus_next=NodePath()
	slider.grab_focus()

func _add_mix_slider(mixer: HBoxContainer, node_name: String, caption: String, key: String) -> HSlider:
	var group = VBoxContainer.new()
	group.add_theme_constant_override("separation",1)
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mixer.add_child(group)
	var label = Label.new()
	var amount = state.volume if key=="volume" else comfort.get(key)
	label.text = caption + " · %d%%" % roundi(amount*100)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_child(label)
	var slider = HSlider.new()
	slider.name = node_name
	slider.tooltip_text = caption
	slider.max_value = 100
	slider.step = 5
	slider.value = roundi(amount*100)
	slider.custom_minimum_size.y = 17
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float):
		if key=="volume":
			state.volume=value/100.0
			audio.set_scene(state.echo,state.volume,state.zone)
		else:
			comfort.set(key,value/100.0)
			audio.set_mix(comfort.music_volume,comfort.effects_volume)
		label.text = caption + " · %d%%" % roundi(value)
		_save_comfort())
	group.add_child(slider)
	return slider

func _save_comfort():
	comfort.language=state.language;comfort.volume=state.volume
	comfort.fullscreen=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
	if comfort.save_preferences()!=OK:
		_notify(t("Не удалось сохранить настройки.","Could not save preferences."))
	help_button.text="? H"

func _toggle_comfort(key: String):
	comfort.set(key,not comfort.get(key))
	_save_comfort()
	ui.theme=ComfortTheme.create(comfort.large_text)
	objective.add_theme_font_size_override("font_size",13 if comfort.large_text else 11)
	hint.add_theme_font_size_override("font_size",13 if comfort.large_text else 11)
	_settings()
	buttons[key].grab_focus()

func _controls_help():
	_dialog("",t("Управление","Controls"),t("WASD или стрелки — идти\nE — поговорить или действовать\nПробел — прыжок · Shift — бег\nM — карта · T — места · J — журнал · I — предметы\nEsc — пауза или возврат\n\nВ лабиринте: WASD, стрелки или мышь.\nВ головоломке: мышь или Tab и Enter.","WASD or arrows — move\nE — talk or interact\nSpace — jump · Shift — run\nM — map · T — places · J — journal · I — items\nEsc — pause or go back\n\nMaze: WASD, arrows, or mouse.\nPuzzles: mouse, or Tab and Enter."),[choice("back","К настройкам","Back to settings",_settings)],false)

func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		_save(false)
		if is_instance_valid(event_window) and event_window.active: event_window.close()
		get_tree().quit()
