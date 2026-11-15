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


var state=State.new()
var saves=Saves.new()
var archive_saves: RefCounted
var rift_saves=Saves.new()
var event_saves=Saves.new()
var events_controller
var journey=preload("res://after_silence/world/journey.gd").new(self)
var event_window
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
var type_progress=0.0
var modal_age=0.0
var hint_age=0.0
var autosave_age=0.0
var shift_cooldown=0.0
var catalog_sequence: Array=[]
var clock_hour=0
var clock_minute=0
var relay_mask=0
var selected_evidence=""
var dirty=false
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
	if "--qa-events-export" in OS.get_cmdline_user_args():
		var event_runner=load("res://after_silence/tests/events_export_driver.gd").new()
		event_runner.game=self
		get_tree().root.add_child.call_deferred(event_runner)
	if "--qa-input-export" in OS.get_cmdline_user_args():
		var input_runner=load("res://after_silence/tests/input_playthrough_driver.gd").new()
		input_runner.game=self
		get_tree().root.add_child.call_deferred(input_runner)
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
	if not state.changed.is_connected(_mark_dirty): state.changed.connect(_mark_dirty)
	if not is_instance_valid(audio):
		audio=Audio.new()
		add_child(audio)
func _mark_dirty():
	dirty=true
	for id in Achievements.evaluate(state):
		if is_instance_valid(toast): _notify(t("Достижение: ","Achievement: ")+Story.pair(Achievements.ENTRIES[id],state.language))
func style(bg: Color, accent: bool=false) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=bg
	s.border_color=Color("67c5bd") if accent else Color("315550")
	s.set_border_width_all(1)
	s.border_width_left=3 if accent else 1
	s.set_content_margin_all(5)
	s.anti_aliasing=false
	return s
func choice_style(active: bool, pressed: bool=false) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=Color("58b2aa") if pressed else Color("327d78") if active else Color.TRANSPARENT
	s.border_color=Color("8fe3d6") if active else Color.TRANSPARENT
	s.border_width_left=3 if active else 0
	s.set_content_margin_all(5)
	s.anti_aliasing=false
	return s

func _setup_ui():
	var layer=CanvasLayer.new()
	add_child(layer)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme=Theme.new()
	var font=load("res://after_silence/assets/fonts/PressStart2P-Regular.ttf")
	font.antialiasing=TextServer.FONT_ANTIALIASING_NONE
	theme.default_font=font
	theme.default_font_size=10
	theme.set_color("font_color","Label",Color("dce9e3"))
	theme.set_stylebox("normal","Button",choice_style(false))
	theme.set_stylebox("hover","Button",choice_style(true))
	theme.set_stylebox("focus","Button",choice_style(true))
	theme.set_stylebox("pressed","Button",choice_style(true,true))
	theme.set_color("font_color","Button",Color("e2eeea"))
	theme.set_color("font_hover_color","Button",Color.WHITE)
	theme.set_color("font_focus_color","Button",Color.WHITE)
	ui.theme=theme
	var hud=load("res://after_silence/world/story_hud.gd").new()
	hud.game=self
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(hud)
	objective=Label.new()
	objective.position=Vector2(12,12)
	objective.size=Vector2(480,44)
	objective.add_theme_font_size_override("font_size",8)
	objective.add_theme_color_override("font_outline_color",Color("172126"))
	objective.add_theme_constant_override("outline_size",4)
	objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(objective)
	help_button=Button.new()
	help_button.text="? [H]"
	help_button.position=Vector2(560,38)
	help_button.pressed.connect(_quest_help)
	ui.add_child(help_button)
	status=Label.new()
	status.hide()
	status.position=Vector2(138,55)
	status.add_theme_font_size_override("font_size",11)
	ui.add_child(status)
	hint=Label.new()
	hint.position=Vector2(24,327)
	hint.size=Vector2(592,23)
	hint.add_theme_font_size_override("font_size",8)
	hint.add_theme_color_override("font_outline_color",Color("172126"))
	hint.add_theme_constant_override("outline_size",4)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(hint)
	toast=Label.new()
	toast.position=Vector2(40,270)
	toast.size=Vector2(560,36)
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
	card.add_child(card_scroll)
	column=VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",7)
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
func _dialog(id: String,title: String,text: String,actions: Array,animated: bool=true,main_layout: bool=false):
	modal=true
	shade.show()
	buttons.clear()
	if is_instance_valid(modal_tween): modal_tween.kill()
	modal_backdrop.menu_mode=main_layout
	modal_backdrop.english=state.language=="en"
	modal_backdrop.journey_mode=state.flag("event_campaign") and not main_layout

	modal_backdrop.age=0
	modal_backdrop.tick=0
	modal_backdrop.queue_redraw()
	var target=Vector2(30,34) if main_layout else Vector2(34,32)
	card.position=target+Vector2(0,9)
	card.size=Vector2(320,281) if main_layout else Vector2(572,294)
	var panel_style=style(Color("19372e") if state.flag("event_campaign") and not main_layout else Color(.025,.047,.052,.91))
	if main_layout:
		panel_style.bg_color=Color.TRANSPARENT
		panel_style.set_border_width_all(0)
	card.add_theme_stylebox_override("panel",panel_style)

	card.modulate.a=0
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var header=Label.new()
	header.text=title
	header.add_theme_color_override("font_color",Color("c7ebe5"))
	header.add_theme_font_size_override("font_size",18 if main_layout else 15)
	header.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var portrait_id=id.split("_")[0]
	if id=="intro": portrait_id="vera"
	if not main_layout and (portrait_id in actors or portrait_id=="vera"):
		var row=HBoxContainer.new()
		var portrait=TextureRect.new()
		var atlas=AtlasTexture.new()
		atlas.atlas=player.sheet if portrait_id=="vera" else actors[portrait_id].sheet
		atlas.region=player.portrait if portrait_id=="vera" else actors[portrait_id].portrait
		portrait.texture=atlas
		portrait.custom_minimum_size=Vector2(64,64) if state.flag("event_campaign") else Vector2(42,42)
		portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(portrait)
		header.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(header)
		column.add_child(row)
	else: column.add_child(header)
	body=RichTextLabel.new()
	body.bbcode_enabled=false
	body.text=text
	body.fit_content=true
	body.scroll_active=false
	body.custom_minimum_size=Vector2(0,20 if main_layout else 24)
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("default_color",Color("a9c6bd"))
	body.add_theme_font_size_override("normal_font_size",10)
	column.add_child(body)
	var seen=dialogues.was_seen(id)
	if id!="": dialogues.record(id,title,text)
	body.visible_characters=0 if animated and not seen else -1
	type_progress=0
	modal_age=0
	for i in range(actions.size()):
		var item=actions[i]
		var button=Button.new()
		button.text=item.label
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size=Vector2(0,31 if main_layout else 32)
		button.add_theme_font_size_override("font_size",10)
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func():
			if body.visible_characters>=0 and body.visible_characters<body.get_total_character_count():
				body.visible_characters=-1
				return
			audio.ping(state.volume)
			item.run.call())
		column.add_child(button)
		buttons[item.id]=button
	if seen and animated and not state.flag("event_campaign"):
		var skip=Label.new()
		skip.text=t("Уже прочитано · текст показан целиком","Previously read · full text shown")
		column.add_child(skip)
	if not actions.is_empty(): buttons[actions[0].id].grab_focus()
	card_scroll.scroll_vertical=0
	modal_tween=create_tween().set_parallel(true)
	modal_tween.tween_property(card,"position",target,.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	modal_tween.tween_property(card,"modulate:a",1.0,.22)
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
	_dialog("",t("ПОСЛЕ ТИШИНЫ","AFTER SILENCE"),t("ПУТЕШЕСТВИЕ / 12 СОБЫТИЙ","THE JOURNEY / 12 EVENTS"),[choice("events_load","Продолжить","Continue",func():saves=event_saves;_load_game()),choice("events_new","Новое путешествие","New journey",_new_event_game),choice("archive","Архив прежних историй","Previous stories",_archive_menu),choice("settings","Настройки","Settings",_settings),choice("quit","Выход","Exit",func():get_tree().quit())],false,true)
	if not event_saves.exists(): buttons["events_new"].grab_focus()
func _archive_menu():
	in_menu=true
	_dialog("",t("АРХИВ","ARCHIVE"),t("ПРЕЖНИЕ СОХРАНЕНИЯ","PREVIOUS SAVES"),[choice("load","Продолжить разлом","Continue rift",_continue_rift),choice("rift","Начать разлом заново","Restart rift",_new_rift_game),choice("archive_load","Продолжить архив","Continue archive",_continue_archive),choice("new","Начать архив заново","Restart archive",_new_game),choice("back","Назад","Back",_main_menu)],false,true)
func _new_event_game():
	var lang=state.language
	var volume=state.volume
	state=State.new();state.language=lang;state.volume=volume
	saves=event_saves
	_setup_services()
	state.set_flag("event_campaign");state.set_flag("rift_mode")
	state.set_flag("nadia_met");state.set_flag("catalog");state.set_flag("clock_solved")
	in_menu=false;modal=false;shade.hide();adventure.expanded=false
	if event_window.active: event_window.close()
	_build_world("town",Vector2(600,645))
	events_controller.start()
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
	if not saves.load_state(state):
		_dialog("",t("Нет читаемого сохранения","No readable save"),t("Основной и резервный файлы не прошли проверку. Они не удалены.","Neither the main nor backup file passed validation. They were not deleted."),[choice("menu","В меню","Main menu",_main_menu)],false)
		return
	_setup_services()
	var checkpoint=state.minigame.duplicate(true)
	var event_checkpoint=state.event_state.duplicate(true)
	in_menu=false
	modal=false
	shade.hide()
	await _travel(state.zone,state.position)
	state.minigame=checkpoint
	state.event_state=event_checkpoint
	if state.flag("event_campaign"): events_controller.start(true)
	elif state.flag("rift_mode") and not state.flag("rift_finished"): rift.start(self)
	_save(false)

func _save(notify: bool=true):
	if in_menu or not is_instance_valid(player): return
	npcs.capture(self)
	if state.flag("event_campaign") and is_instance_valid(events_controller) and not events_controller.preparing: state.event_state=events_controller.capture()
	state.minigame=preload("res://after_silence/core/minigame_checkpoint.gd").capture(rift) if rift.active else {}
	if not state.flag("event_campaign"): objectives.refresh()
	state.position=player.position
	if saves.save(state):
		dirty=false
		if notify: _notify(t("История сохранена","Story saved"))
	else: _notify(t("Не удалось сохранить. Предыдущая копия сохранена.","Save failed. The previous copy remains intact."))
func _travel(id: String,p: Vector2):
	if transitions.busy: return
	modal=false
	shade.hide()
	await transitions.transition(self,veil,func(): _build_world(id,p))
	_save(false)
	if id in Homes.IDS: _notify(Story.pair(Homes.NAMES[Homes.IDS.find(id)],state.language))
func _build_world(id: String,p: Vector2):
	if is_instance_valid(events_controller): events_controller.detach_activity()
	npcs.detach(self)
	if is_instance_valid(living): living.restore_camera()
	if is_instance_valid(player) and player.has_meta("click_route"): player.remove_meta("click_route")
	if is_instance_valid(player):
		player.get_parent().remove_child(player)
	if not is_instance_valid(world):
		world=World.new()
		add_child(world)
	world.story_mode=state.flag("event_campaign")
	world.build(id,state.echo)
	state.zone=id
	state.set_flag("explored_"+id)
	if not is_instance_valid(player):
		player=Actor.new()
		player.is_player=true
		player.sheet=load("res://after_silence/assets/pechatai/player/walk.png")
		player.footstep.connect(_footstep)
		camera=Camera2D.new()
		camera.position_smoothing_enabled=true
		camera.position_smoothing_speed=6
		player.add_child(camera)
		zoom_button=Button.new()
		zoom_button.text="− / +  Камера [Z]"
		zoom_button.position=Vector2(440,38)
		zoom_button.pressed.connect(_toggle_zoom)
		ui.add_child(zoom_button)
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
	world.add_child(atmosphere)
	world.modulate=Color("7b93b3") if state.echo else Color("b5c6b6")
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
	if is_instance_valid(events_controller): events_controller.attach_activity(id)
func _npc(id: String,p: Vector2,path: String,color: Color=Color.WHITE):
	var actor=Actor.new()
	actor.sheet=load(path)
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
	caption.add_theme_font_size_override("font_size",10)
	caption.add_theme_color_override("font_outline_color",Color("172126"))
	caption.add_theme_constant_override("outline_size",4)
	caption.hide()
	actor.add_child(caption)
	actor.set_meta("caption",caption)
func _physics_process(dt):
	if is_instance_valid(help_button): help_button.visible=not modal and not in_menu and not rift.active and not battle.active
	if is_instance_valid(zoom_button): zoom_button.visible=not modal and not in_menu and not rift.active
	if is_instance_valid(objective): objective.visible=not modal and not in_menu and not rift.active
	shift_cooldown=maxf(0,shift_cooldown-dt)
	if modal and is_instance_valid(body) and body.visible_characters>=0:
		type_progress+=dt*42
		body.visible_characters=int(type_progress)
		if body.visible_characters>=body.get_total_character_count(): body.visible_characters=-1
	if not is_instance_valid(player): return
	var enabled=not modal and not in_menu and not transitions.busy and not cutscenes.running and not battle.active and not rift.active and not adventure.expanded
	player.enabled=enabled
	if is_instance_valid(enemy):
		enemy.active=enabled and state.flag("sonya_met") and not state.flag("returned")
		enemy.visible=state.flag("sonya_met") and not state.flag("returned")
		enemy.pressure=state.pressure
	npcs.update(self,dt,enabled)
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
	var tint=Color("7b93b3") if state.echo else Color("7b889f") if night else Color("b5c6b6")
	world.modulate=world.modulate.lerp(tint,minf(1,dt*2))
	status.text=t("Отголоски: ","Echoes: ")+str(state.charges)+"/3 · "+t("Улики: ","Clues: ")+str(state.evidence.size())+"/"+str(State.CLUES.size())+" · "+("%02d:%02d"%[int(state.clock),int(fmod(state.clock,1)*60)])
	var nearby=_nearest()
	for prop in world.sorter.get_children():
		if not prop.has_meta("hotspot_id"): continue
		var focus=prop.get_meta("hotspot_id")==nearby
		if prop.focused!=focus: prop.focused=focus;prop.queue_redraw()
	hint.text=t("E — ","E — ")+_object_name(nearby) if nearby!="" else ""
	hint.size=Vector2(220,35)
	if nearby!="":
		var p=actors[nearby].position if actors.has(nearby) else player.position
		for spot in world.interactables:
			if spot.id==nearby: p=spot.position
		hint.position=((world.get_global_transform_with_canvas()*p)+Vector2(-110,18)).clamp(Vector2(8,72),Vector2(410,305))
	if is_instance_valid(enemy) and enemy.active and enemy.position.distance_to(player.position)<240:
		status.text+=" · "+t("Кто-то рядом. Ищите каменное укрытие.","Something is close. Find the stone shelter.")
	hint_age=maxf(0,hint_age-dt)
	if hint_age<=0: toast.text=""
func _notify(text: String):
	toast.text=text
	if is_instance_valid(toast_tween): toast_tween.kill()
	toast.modulate.a=0
	toast_tween=create_tween()
	toast_tween.tween_property(toast,"modulate:a",1,.18)
	toast_tween.tween_interval(2.8)
	toast_tween.tween_property(toast,"modulate:a",0,.6)
	hint_age=4
func _footstep(loud: bool):
	if is_instance_valid(enemy): enemy.hear(player.position,loud and not state.flag("soft_steps"))
func _nearest() -> String:
	if rift.phase=="travel" and not state.flag("rift_finished") and rift.index<rift.STOPS.size() and state.zone=="town" and player.position.distance_to(rift.STOPS[rift.index])<52: return "rift_next"
	for spot in world.interactables:
		if spot.position.distance_to(player.position)<28 and (spot.id in Homes.IDS or spot.id in ["to_library","to_forest","to_town","leave_home","leave_shop","visit_shop","visit_orchard","visit_harbor","district_return"]):
			return spot.id
	if state.flag("event_campaign") and is_instance_valid(events_controller) and events_controller.phase in ["observe","ready","suspended","decision","failure"]:
		var actor=events_controller.npc
		if is_instance_valid(actor) and actor.is_visible_in_tree() and actor.position.distance_to(player.position)<55:
			return events_controller.events[events_controller.index].npc
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
func _unhandled_key_input(event):
	if not event.is_pressed() or event.is_echo(): return
	if transitions.busy: return
	if rift.active: return
	if state.flag("event_campaign") and event_window.active:
		if event.physical_keycode==KEY_SPACE: player.jump(Input.is_physical_key_pressed(KEY_SHIFT))
		elif event.physical_keycode in [KEY_T,KEY_J,KEY_H,KEY_I]: event_window.toggle_pause()
		return

	if battle.active:
		if event.physical_keycode==KEY_SPACE: battle.jump()
		elif event.physical_keycode==KEY_E: battle.counter()
		return

	if cutscenes.running: return
	if modal:
		if event.physical_keycode==KEY_E and is_instance_valid(body): body.visible_characters=-1
		elif event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_9:
			var index=int(event.physical_keycode-KEY_1)
			if index<buttons.size(): buttons.values()[index].pressed.emit()
		elif event.physical_keycode==KEY_ESCAPE and not in_menu:
			_close()
			if state.flag("event_campaign") and events_controller.phase=="failure":
				events_controller.phase="ready"
				if is_instance_valid(events_controller.npc): events_controller.npc.managed_motion=true
		return
	match event.physical_keycode:
		KEY_T: if state.flag("event_campaign"): journey.open()
		KEY_H: _quest_help()
		KEY_Z: _toggle_zoom()
		KEY_E: interact(_nearest())
		KEY_J: _journal()
		KEY_I: _inventory()
		KEY_TAB: if not state.flag("rift_mode"): _shift()
		KEY_SPACE: player.jump(Input.is_physical_key_pressed(KEY_SHIFT))
		KEY_ESCAPE: _pause()
func _travel_window():
	if state.flag("event_campaign"): journey.open()
func _toggle_zoom():
	if not is_instance_valid(camera): return
	camera.position=Vector2.ZERO
	wide_camera=not wide_camera
	camera.zoom=Vector2.ONE*(0.65 if wide_camera else 1.0)
func _quest_help():
	if state.flag("event_campaign"): journey.open();return
	_dialog("",t("Куда идти?","Where to go?"),shop.hint()+"\n"+t("Золотая отметка на карте — следующее событие. E — действие.","The gold map marker is the next event. E: interact."),[choice("map","Показать карту","Show map",func():_close();adventure.expanded=true),choice("close","Понятно","Got it",_close)],false)
func interact(id: String):
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
	audio.ping(state.volume)
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
	if state.flag("catalog"): _clue("ledger");return
	var labels=[["Дождь","Rain"],["Колокол","Bell"],["Тишина","Silence"]]
	var options=[]
	for i in range(3): options.append(choice("book_"+str(i),labels[i][0],labels[i][1],func():_catalog_select(i)))
	options.append(choice("reset","Сбросить порядок","Reset order",func():catalog_sequence.clear();_catalog()))
	options.append(choice("close","Отойти","Step away",_close))
	var sequence=PackedStringArray()
	for index in catalog_sequence: sequence.append(Story.pair(labels[index],state.language))
	_dialog("",t("Каталог эвакуации","Evacuation catalogue"),t("Три защёлки откликаются на считалку с афиши. Выберите книги по порядку. Сейчас: ","Three latches follow the rhyme on the poster. Choose books in order. Current: ")+" → ".join(sequence),options,false)
func _catalog_select(index: int):
	catalog_sequence.append(index)
	if catalog_sequence.size()==3:
		if catalog_sequence==[0,1,2]:
			state.set_flag("catalog")
			state.add_clue("ledger")
			state.give("lens")
			_clue("ledger")
		else:
			state.pressure=mini(5,state.pressure+1)
			catalog_sequence.clear()
			_notify(t("Защёлки вернулись на место. Вспомните афишу.","The latches reset. Remember the poster."))
			_catalog()
	else: _catalog()
func _clock():
	if state.flag("clock_solved"): _clue("clock");return
	_dialog("",t("Восстановить момент","Restore the moment"),t("Сначала свяжите афишу и часы в журнале. Затем выставьте время.\n","First connect the poster and clock in the journal, then set the time.\n")+("%02d:%02d"%[clock_hour,clock_minute]),[choice("hour","Час +1","Hour +1",func():clock_hour=(clock_hour+1)%24;_clock()),choice("minute","Минута +1","Minute +1",func():clock_minute=(clock_minute+1)%60;_clock()),choice("five","Минуты +5","Minutes +5",func():clock_minute=(clock_minute+5)%60;_clock()),choice("set","Зафиксировать","Set",_set_clock),choice("close","Назад","Back",_close)],false)
func _set_clock():
	if clock_hour==2 and clock_minute==17 and "date" in state.links:
		state.set_flag("clock_solved")
		_dialog("clock_restored",t("02:17","02:17"),t("Колокол отзывается одним ударом. Лесная дорога больше не замыкается на площадь. Запись говорит об отключении сигнала, а не о моменте смерти.","A bell rings once. The forest road no longer loops back to the square. The record marks a signal cut, not a death."),[choice("close","Продолжить","Continue",_close)])
	else:
		state.pressure=mini(5,state.pressure+1)
		_notify(t("Механизм не совпал со свидетельствами.","The mechanism does not match the evidence."))
		_clock()
func _relay():
	if state.flag("forest_power"): _notify(t("Насос работает тихо.","The pump runs quietly."));return
	if not state.flag("boss_relay_defeated"): _begin_boss("relay");return

	var options=[]
	for i in range(3): options.append(choice("lever_"+str(i),t("Рычаг ","Lever ")+str(i+1)+(" ●" if relay_mask&(1<<i) else " ○"),"Lever "+str(i+1)+(" ON" if relay_mask&(1<<i) else " OFF"),func():relay_mask=relay_mask^(1<<i);_relay()))
	options.append(choice("power","Вставить предохранитель и подать питание","Insert fuse and power on",_power_relay))
	options.append(choice("close","Назад","Back",_close))
	_dialog("",t("Аварийное реле","Emergency relay"),t("Средний контур питает колокол. Не поднимайте тревогу. Схема осталась в библиотеке.","The middle circuit powers the bell. Do not raise the alarm. The diagram is in the library."),options,false)
func _power_relay():
	if relay_mask!=5:
		state.pressure=mini(5,state.pressure+1)
		_notify(t("Сработал колокол. Первый и третий контуры питают насос.","The bell rang. The first and third circuits power the pump."))
		if is_instance_valid(enemy): enemy.hear(player.position,true)
		_relay()
	elif inventory.install_fuse("forest_power"):
		_dialog("power",t("Тихий запуск","Quiet start"),t("Насос ожил. В отголоске на востоке кто-то выходит из убежища.","The pump awakens. In the echo, someone leaves the eastern shelter."),[choice("close","Продолжить","Continue",_close)])
	else: _notify(t("Нет предохранителя: спросите Льва или извлеките его из света библиотеки.","No fuse: ask Lev or remove it from the library light."))
func _light_socket():
	var installed=state.flag("library_light")
	_dialog("",t("Свет библиотеки","Library light"),t("Это гнездо и лесное реле используют одну деталь. Свет помогает читать обычные страницы, но не проявляет чернила отголоска.","This socket and the forest relay use the same part. The light helps with ordinary pages, but cannot reveal echo ink."),[choice("fuse","Извлечь предохранитель" if installed else "Поставить предохранитель","Remove fuse" if installed else "Install fuse",func():
		if installed: inventory.remove_library_fuse()
		elif not inventory.install_fuse("library_light"): _notify(t("Нужна деталь Льва.","You need Lev's part."))
		_close()),choice("close","Назад","Back",_close)],false)
func _journal():
	if state.flag("event_campaign"): events_controller.journal();return
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
	_dialog("",t("Пауза","Pause"),t("Город подождёт.","The town will wait."),[choice("resume","Продолжить","Resume",_close),choice("save","Сохранить","Save",func():_save();_close()),choice("load","Загрузить","Load",_load_game),choice("settings","Настройки","Settings",_settings),choice("menu","В меню","Main menu",func():_save(false);_main_menu())],false)
	var slot_button=Button.new()
	slot_button.text=t("Три слота сохранения","Three save slots")
	slot_button.custom_minimum_size=Vector2(0,32)
	slot_button.pressed.connect(expedition.slots)
	column.add_child(slot_button)
	buttons["slots"]=slot_button
func _settings():
	_dialog("",t("Настройки","Settings"),t("Язык, звук и окно. Изменения записываются при сохранении истории.","Language, audio and window. Settings are stored with your story."),[choice("lang","Русский / English","English / Русский",func():state.language="en" if state.language=="ru" else "ru";_settings()),choice("quiet","Звук −","Volume −",func():state.volume=maxf(0,state.volume-.1);audio.set_scene(state.echo,state.volume,state.zone);_settings()),choice("loud","Звук +","Volume +",func():state.volume=minf(1,state.volume+.1);audio.set_scene(state.echo,state.volume,state.zone);_settings()),choice("fullscreen","Полный экран / окно","Fullscreen / window",func():DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)),choice("back","Назад","Back",func():
		if in_menu: _main_menu()
		else: _pause())],false)
func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		_save(false)
		if is_instance_valid(event_window) and event_window.active: event_window.close()
		get_tree().quit()
