extends Control
var game
var actions: Array[Button]=[]
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for entry in [["T","Путешествие","Travel","_travel_window"],["J","Журнал","Journal","_journal"],["I","Предметы","Inventory","_inventory"],["Esc","Пауза","Pause","_pause"]]:
		var button=Button.new()
		button.position=Vector2(12+actions.size()*155,322)
		button.size=Vector2(150,29)
		button.add_theme_font_size_override("font_size",12)
		button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		var box=game.ComfortTheme.button()
		button.add_theme_stylebox_override("normal",box)
		for name in ["hover","focus","pressed"]:
			var active=game.ComfortTheme.button(true,name=="pressed")
			button.add_theme_stylebox_override(name,active)
		button.set_meta("entry",entry)
		button.pressed.connect(func():game.call(entry[3]))
		add_child(button)
		actions.append(button)
func _process(_dt):
	visible=not game.modal and not game.in_menu and not game.rift.active and not game.event_window.active
	for button in actions:
		var entry=button.get_meta("entry")
		button.visible=(not game.state.flag("rift_mode") or entry[0] in ["J","Esc"]) or (entry[0]=="T" and game.state.flag("event_campaign"))
		if entry[0]=="T": button.visible=game.state.flag("event_campaign")
		if game.state.flag("event_campaign") and entry[0]=="I": button.visible=true
		button.text=entry[0]+" · "+game.t(entry[1],entry[2])
		button.tooltip_text=game.t(entry[1],entry[2])
		button.disabled=game.transitions.busy or game.cutscenes.running
	queue_redraw()
func _draw():
	draw_style_box(game.ComfortTheme.panel(Color("292d38e8")),Rect2(12,10,468,57))
	draw_string(get_theme_default_font(),Vector2(22,24),game.t("СЛЕДУЮЩИЙ ШАГ","NEXT STEP"),HORIZONTAL_ALIGNMENT_LEFT,-1,10,game.ComfortTheme.SAGE)
	draw_style_box(game.ComfortTheme.panel(Color("292d38e8")),Rect2(534,10,94,25))
	var clock="%02d:%02d"%[int(game.state.clock),int(fmod(game.state.clock,1)*60)]
	draw_string(get_theme_default_font(),Vector2(562,28),clock,HORIZONTAL_ALIGNMENT_LEFT,-1,13,game.ComfortTheme.TEXT)
	if game.state.flag("rift_mode"): return
	for i in range(3):
		var p=Vector2(492+i*11,24)
		var color=Color("b2d9cb") if i<game.state.charges else Color("514b5c")
		draw_circle(p+Vector2(1,1),4,Color("172126"))
		draw_circle(p,3,color)
