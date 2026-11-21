extends Node
## UI diagnostics use separate saves and real viewport input, never user stories.
var game
var checks=0
var failures=[]
var output="res://work/pixel180-ui"
var images=[]

func _ready():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-ui-output="): output=argument.trim_prefix("--qa-ui-output=")
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().create_timer(120).timeout.connect(func():print("UI QA ERROR: watchdog");get_tree().quit(2))
	call_deferred("run")

func check(ok: bool, label: String):
	checks+=1
	if not ok: failures.append(label);print("UI QA ERROR: ",label)

func settle():
	await get_tree().create_timer(.25).timeout
	await get_tree().process_frame
	await get_tree().process_frame

func capture(label: String):
	await settle()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var target=output.path_join(label+".png")
	check(get_viewport().get_texture().get_image().save_png(target)==OK,"screenshot "+label)
	images.append(target)

func tap(key: int, shift: bool=false):
	for pressed in [true,false]:
		var event=InputEventKey.new()
		event.physical_keycode=key;event.keycode=key;event.pressed=pressed;event.shift_pressed=shift
		get_viewport().push_input(event,true)
		await get_tree().process_frame

func click(control: Control):
	await settle()
	var point=control.get_global_transform_with_canvas()*(control.size*.5)
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	get_viewport().push_input(motion,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		get_viewport().push_input(event,true)
	await get_tree().process_frame

func dialog_bounds(label: String, all_visible: bool=false):
	var bounds=Rect2(Vector2.ZERO,game.ui.size)
	check(bounds.encloses(game.card.get_global_rect()),label+" card fits")
	for button in game.buttons.values():
		check(button.size.y>=26,label+" hit height "+button.text)
		check(button.size.x<=game.card.size.x,label+" button width "+button.text)
		if all_visible: check(game.card.get_global_rect().encloses(button.get_global_rect()),label+" visible "+button.text)

func run():
	var initial_window = DisplayServer.window_get_size()
	var run_id=str(Time.get_ticks_usec())
	game.event_saves.path="user://qa_ui_story_"+run_id+".json"
	game.comfort.path="user://qa_ui_comfort_"+run_id+".cfg"
	game.comfort.large_text=false;game.comfort.reduce_motion=false;game.comfort.instant_text=false
	game.state.language="ru";game.ui.theme=game.ComfortTheme.create()
	game._main_menu()
	await settle()
	check(game.modal_backdrop.sky_time>.05,"menu animates with default motion settings")
	check(game.ComfortTheme.FONT.has_char("Я".unicode_at(0)),"font has Cyrillic")
	check(game.ComfortTheme.FONT.get_font_name().contains("Pixelify"),"pixel typeface used throughout the interface")
	check(game.buttons.events_load.disabled,"continue disabled without save")
	check(get_viewport().gui_get_focus_owner()==game.buttons.events_new,"new journey focused")
	check(not game.body.visible and not game.buttons.has("archive"),"front menu has only title and actions")
	check(game.modal_backdrop.COTTAGE.get_size()==Vector2(320,180),"cottage uses a 320 × 180 pixel canvas")
	await tap(KEY_1)
	check(game.buttons.has("events_new"),"numeric shortcut cannot activate disabled continue")
	dialog_bounds("menu",true)
	await capture("01-menu")
	await click(game.buttons.settings)
	check(game.buttons.has("large_text"),"settings opened by mouse")
	await settle()
	dialog_bounds("settings",true)
	await capture("02-settings")
	await click(game.buttons.large_text)
	check(game.comfort.large_text,"large text enabled by mouse")
	check(game.ui.theme.default_font_size==14,"large text theme applied")
	await settle()
	dialog_bounds("large settings",true)
	var slider=game.column.find_child("VolumeSlider",true,false)
	slider.grab_focus()
	var old_value=slider.value
	await tap(KEY_RIGHT if old_value<100 else KEY_LEFT)
	check(slider.value!=old_value,"volume keyboard input")
	var config=ConfigFile.new()
	check(config.load(game.comfort.path)==OK,"preferences file written")
	check(config.get_value("comfort","large_text",false),"large text persisted independently")
	check(is_equal_approx(float(config.get_value("comfort","volume",-1)),game.state.volume),"volume persisted")
	await click(game.buttons.reduce_motion)
	check(game.comfort.reduce_motion,"reduced motion enabled")
	check(not game.modal_backdrop.is_processing(),"menu artwork remains static")
	await click(game.buttons.instant_text)
	await capture("03-comfort-large")
	await tap(KEY_ESCAPE)
	check(game.buttons.has("events_new"),"Esc returns from settings to menu")
	await click(game.buttons.settings)
	game.buttons.archive.grab_focus()
	await tap(KEY_ENTER)
	check(game.buttons.has("rift"),"archive opened from settings by keyboard")
	await capture("04-archive")
	await tap(KEY_ESCAPE)
	check(game.buttons.has("reduce_motion"),"Esc returns from archive to settings")
	await click(game.buttons.reduce_motion)
	await tap(KEY_ESCAPE)
	await click(game.buttons.events_new)
	check(game.departing_home and not game.card.visible,"new journey shows the cottage departure")
	check(not game.event_saves.exists(),"departure creates no save before entering the world")
	await tap(KEY_ESCAPE)
	await tap(KEY_ENTER)
	check(game.departing_home and game.in_menu,"keyboard cannot interrupt or restart the departure")
	await capture("04b-vera-leaves")
	await capture("04c-house-dark")
	await get_tree().create_timer(.8).timeout
	await settle()
	check(not game.in_menu and not game.departing_home,"new journey starts after the departure")
	game._close()
	await capture("05-world")
	await tap(KEY_M)
	await capture("05-district-map")
	var atlas=game.column.get_node_or_null("DistrictMap")
	check(is_instance_valid(atlas) and atlas.district_name()=="Город","M opens the current district map")
	if is_instance_valid(atlas) and DisplayServer.get_name()!="headless":
		check(atlas.bounds.has_point(atlas.project_point(game.player.position)),"player pin projects within map")
	await tap(KEY_M)
	check(not game.modal,"M closes the map")
	await click(game.story_hud.actions[0])
	check(game.buttons.has("places"),"HUD map button opens map with travel link")
	dialog_bounds("district map",true)
	await click(game.buttons.places)
	check(game.buttons.has("square"),"map links to existing travel routes")
	await tap(KEY_ESCAPE)
	check(not game.help_button.get_global_rect().intersects(game.zoom_button.get_global_rect()),"help and zoom do not overlap")
	check(not game.objective.get_global_rect().intersects(game.help_button.get_global_rect()),"objective and help do not overlap")
	check(game.objective.size.x<=240 and game.help_button.size.x<=36,"HUD leaves space for the world")
	await tap(KEY_ESCAPE)
	await settle()
	check(game.buttons.has("resume"),"pause opened by Esc")
	check(game.card.size.x<=390 and game.card.size.y<=274,"pause uses a compact layout")
	dialog_bounds("pause")
	await capture("06-pause")
	game._journal()
	await capture("07-journal")
	dialog_bounds("journal")
	await tap(KEY_ESCAPE)
	game.journey.open()
	await settle()
	var last=game.buttons.close
	last.grab_focus()
	await settle()
	check(game.card.get_global_rect().encloses(last.get_global_rect()),"focus scrolls to last travel action")
	check(game.card_scroll.scroll_vertical>0,"long travel list scrolls")
	await capture("08-travel")
	await tap(KEY_ESCAPE)
	check(not game.modal,"Esc closes travel")
	game._dialog("ui_review",game.t("Вера","Vera"),game.t("Можно остановиться, оглядеться и просто побыть здесь. Когда будешь готова — продолжим путь вместе.","We can stop, look around and stay here for a moment. When you are ready, we will continue together."),[game.choice("close","Продолжим вместе","Let's go together",game._close)],true)
	check(game.body.visible_characters==-1,"instant dialogue preference applied")
	await capture("09-dialogue")
	await tap(KEY_ESCAPE)
	game._main_menu()
	var previous_save=FileAccess.get_sha256(game.event_saves.path)
	await click(game.buttons.events_new)
	check(game.buttons.has("restart"),"existing story asks before replacement")
	await tap(KEY_ESCAPE)
	check(game.buttons.has("events_load") and not game.buttons.events_load.disabled,"cancel replacement keeps saved journey")
	check(FileAccess.get_sha256(game.event_saves.path)==previous_save,"cancel leaves save byte-for-byte intact")
	game.state.language="en";game._settings()
	await capture("10-settings-en")
	dialog_bounds("English settings",true)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_size(Vector2i(960,540))
		await capture("11-small-window")
		dialog_bounds("small window",true)
		await click(game.buttons.controls)
		check(game.buttons.size()==1 and game.buttons.has("back"),"mouse hit testing after resize")
		await tap(KEY_ESCAPE)
		check(game.buttons.has("large_text"),"keyboard back after resize")
		DisplayServer.window_set_size(Vector2i(960,720))
		await capture("12-letterbox-window")
		dialog_bounds("letterbox window",true)
		DisplayServer.window_set_size(Vector2i(1600,900))
		await capture("13-large-window")
		dialog_bounds("large window",true)
	game.in_menu=false
	game.state.set_flag("catalog",false)
	game.state.set_flag("clock_solved",false)
	game.state.set_flag("boss_relay_defeated")
	game.state.set_flag("forest_power",false)
	game._catalog()
	await settle()
	dialog_bounds("catalogue controls",true)
	var board = game.column.get_node("ArchiveBoard")
	await click(board.tools[0])
	await click(board.slots[0])
	check(board.values[0]==0,"catalogue pockets can be operated with the mouse")
	game._clock()
	await settle()
	dialog_bounds("clock controls",true)
	game._relay()
	await settle()
	dialog_bounds("relay controls",true)
	game.events_controller.credits()
	await settle()
	dialog_bounds("credits controls",true)
	game.comfort.reduce_motion=true
	game._main_menu()
	await click(game.buttons.events_new)
	await click(game.buttons.restart)
	check(not game.in_menu and not game.departing_home,"reduced motion starts immediately after confirmation")
	game.comfort.large_text=false;game.comfort.reduce_motion=false;game.comfort.instant_text=false
	game.state.language="ru";game._save_comfort()
	var report={"initial_window":[initial_window.x,initial_window.y],"window_size":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"checks":checks,"failures":failures,"screenshots":images,"automated":true,"version":ProjectSettings.get_setting("application/config/version")}
	var file=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"));file.close()
	print("UI COMFORT QA: ",checks," checks, ",failures.size()," failures")
	game.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(1.5,true,false,true).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
