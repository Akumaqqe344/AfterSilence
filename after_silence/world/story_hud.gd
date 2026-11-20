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
	plate=game.ComfortTheme.panel(Color("233641ef"))
	badge=game.ComfortTheme.panel(Color("293e48ef"),true)
	for entry in [["T","Путешествие","Travel","_travel_window"],["J","Журнал","Journal","_journal"],["I","Предметы","Inventory","_inventory"],["Esc","Пауза","Pause","_pause"]]:
		var button=Button.new()
		button.position=Vector2(462+actions.size()*40,326)
		button.size=Vector2(36 if entry[0]!="Esc" else 46,23)
		button.add_theme_font_size_override("font_size",8)
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
		button.visible=(not game.state.flag("rift_mode") or entry[0] in ["J","Esc"]) or (entry[0]=="T" and game.state.flag("event_campaign"))
		if entry[0]=="T": button.visible=game.state.flag("event_campaign")
		if game.state.flag("event_campaign") and entry[0]=="I": button.visible=true
		button.text=entry[0]
		button.tooltip_text=game.t(entry[1],entry[2])
		button.disabled=game.transitions.busy or game.cutscenes.running
	queue_redraw()
func _draw():
	draw_style_box(plate,Rect2(12,10,378,44))
	draw_rect(Rect2(15,15,2,34),game.ComfortTheme.BRASS)
	var label_tint=game.ComfortTheme.SAGE.lerp(game.ComfortTheme.PEACH,goal_cue/.85)
	draw_string(get_theme_default_font(),Vector2(20,21),game.t("СЛЕДУЮЩИЙ ШАГ","NEXT STEP"),HORIZONTAL_ALIGNMENT_LEFT,-1,6,label_tint)
	if goal_cue>0:
		draw_rect(Rect2(21,48,roundf(98*goal_cue/.85),1),Color(.90,.72,.49,goal_cue/.85))
	draw_style_box(badge,Rect2(566,10,62,20))
	draw_string(get_theme_default_font(),Vector2(14,342),game.t("WASD: идти · E: действие","WASD: move · E: interact"),HORIZONTAL_ALIGNMENT_LEFT,-1,6,game.ComfortTheme.MUTED)
	var clock="%02d:%02d"%[int(game.state.clock),int(fmod(game.state.clock,1)*60)]
	draw_string(get_theme_default_font(),Vector2(577,24),clock,HORIZONTAL_ALIGNMENT_LEFT,-1,8,game.ComfortTheme.TEXT)
	if arrival_age>0:
		var elapsed=2.6-arrival_age
		var alpha=1.0 if game.comfort.reduce_motion else minf(elapsed/.22,minf(1.0,arrival_age/.46))
		if alpha>0:
			var shift=0.0 if game.comfort.reduce_motion else (1.0-clampf(elapsed/.26,0,1))*-7
			var bounds=Rect2(196,69+roundf(shift),248,29)
			draw_rect(bounds,Color(.115,.188,.23,alpha*.94))
			draw_rect(bounds.grow(-1),Color(.71,.59,.45,alpha),false)
			draw_string(get_theme_default_font(),bounds.position+Vector2(5,18),arrival,HORIZONTAL_ALIGNMENT_CENTER,238,8,Color(.97,.89,.76,alpha))
	if game.state.flag("rift_mode"): return
	for i in range(3):
		var p=Vector2(492+i*11,24)
		var color=Color("b2d9cb") if i<game.state.charges else Color("514b5c")
		draw_circle(p+Vector2(1,1),4,Color("172126"))
		draw_circle(p,3,color)
