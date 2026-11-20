extends Control
var game
var actions: Array[Button]=[]
var plate: StyleBoxFlat
var badge: StyleBoxFlat
var last_goal=""
var goal_cue=0.0
var arrival=""
var arrival_age=0.0

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	plate=game.ComfortTheme.panel(Color("1b2621ee"))
	badge=game.ComfortTheme.panel(Color("1b2621ee"))
	for entry in [["M","Карта","Map","_district_map"],["J","Журнал","Journal","_journal"],["I","Предметы","Inventory","_inventory"],["Esc","Пауза","Pause","_pause"]]:
		var button=Button.new()
		button.position=Vector2(465+actions.size()*40,323)
		button.size=Vector2(35 if entry[0]!="Esc" else 44,25)
		button.focus_mode=Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size",11)
		button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		var box=game.ComfortTheme.button()
		button.add_theme_stylebox_override("normal",box)
		for name in ["hover","focus","pressed"]:
			var active=game.ComfortTheme.button(true,name=="pressed")
			button.add_theme_stylebox_override(name,active)
		button.set_meta("entry",entry)
		button.pressed.connect(func():game.call(entry[3]))
		add_child(button)
		game.ComfortMotion.wire_button(button,game.comfort)
		actions.append(button)

func announce(zone_label: String):
	arrival=zone_label
	arrival_age=2.6
	queue_redraw()

func _process(dt):
	visible=not game.modal and not game.in_menu and not game.rift.active and not game.event_window.active
	if visible:
		arrival_age=maxf(0,arrival_age-dt)
		if game.objective.text!=last_goal:
			last_goal=game.objective.text
			goal_cue=0.0 if game.comfort.reduce_motion else .85
		goal_cue=maxf(0,goal_cue-dt)
	for button in actions:
		var entry=button.get_meta("entry")
		button.visible=entry[0]!="I" or not game.state.flag("rift_mode") or game.state.flag("event_campaign")
		button.text=entry[0]
		button.tooltip_text=game.t(entry[1],entry[2])
		button.disabled=game.transitions.busy or game.cutscenes.running
	queue_redraw()
func _draw():
	if not game.objective.text.is_empty():
		draw_style_box(plate,Rect2(12,10,359,61))
		draw_rect(Rect2(12,10,2,61),game.ComfortTheme.BRASS)
		var label_tint=game.ComfortTheme.SAGE.lerp(game.ComfortTheme.PEACH,goal_cue/.85)
		draw_string(get_theme_default_font(),Vector2(22,23),game.t("Задание","Objective"),HORIZONTAL_ALIGNMENT_LEFT,-1,9,label_tint)
		if goal_cue>0:
			draw_rect(Rect2(22,68,roundf(113*goal_cue/.85),1),Color(.90,.72,.49,goal_cue/.85))
	draw_style_box(badge,Rect2(566,10,62,20))
	var clock="%02d:%02d"%[int(game.state.clock),int(fmod(game.state.clock,1)*60)]
	draw_string(get_theme_default_font(),Vector2(566,24),clock,HORIZONTAL_ALIGNMENT_CENTER,62,11,game.ComfortTheme.TEXT)
	if arrival_age>0:
		var elapsed=2.6-arrival_age
		var alpha=1.0 if game.comfort.reduce_motion else minf(elapsed/.22,minf(1.0,arrival_age/.46))
		if alpha>0:
			var shift=0.0 if game.comfort.reduce_motion else (1.0-clampf(elapsed/.26,0,1))*-7
			var bounds=Rect2(196,80+roundf(shift),248,29)
			draw_rect(bounds,Color(.10,.15,.12,alpha*.94))
			draw_rect(bounds.grow(-1),Color(.71,.59,.45,alpha),false)
			draw_string(get_theme_default_font(),bounds.position+Vector2(5,18),arrival,HORIZONTAL_ALIGNMENT_CENTER,238,12,Color(.97,.89,.76,alpha))
	if game.state.flag("rift_mode"): return
	for i in range(3):
		var p=Vector2(492+i*11,24)
		var color=Color("b2d9cb") if i<game.state.charges else Color("514b5c")
		draw_circle(p+Vector2(1,1),4,Color("172126"))
		draw_circle(p,3,color)
