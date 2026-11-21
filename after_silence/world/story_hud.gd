extends Control
const Art=preload("res://after_silence/core/ppae_art.gd")
var game
var actions: Array[Button]=[]
var plate: StyleBoxTexture
var badge: StyleBoxTexture
var last_goal=""
var goal_cue=0.0
var arrival=""
var arrival_age=0.0

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	plate=Art.panel("hud",5)
	badge=Art.panel("hud",3)
	for entry in [["M","Карта","Map","_district_map"],["J","Журнал","Journal","_journal"],["I","Предметы","Inventory","_inventory"],["Esc","Пауза","Pause","_pause"]]:
		var button=Button.new()
		button.position=Vector2(498+actions.size()*33,326)
		button.size=Vector2(29 if entry[0]!="Esc" else 32,22)
		button.focus_mode=Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size",11)
		button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal",Art.panel("normal",3))
		for name in ["hover","focus","pressed"]:
			button.add_theme_stylebox_override(name,Art.panel("pressed" if name=="pressed" else "hover",3))
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
	if not game.objective.text.is_empty() and game.objective.visible:
		var height=clampf(game.objective.get_line_height()*game.objective.get_line_count()+5.0,21.0,36.0)
		draw_style_box(plate,Rect2(10,9,249,height))
		var accent=game.ComfortTheme.BRASS.lerp(game.ComfortTheme.PEACH,goal_cue/.85)
		draw_rect(Rect2(10,9,2,height),accent)
	draw_style_box(badge,Rect2(574,10,54,18))
	var clock="%02d:%02d"%[int(game.state.clock),int(fmod(game.state.clock,1)*60)]
	draw_string(get_theme_default_font(),Vector2(574,23),clock,HORIZONTAL_ALIGNMENT_CENTER,54,11,game.ComfortTheme.TEXT)
	if arrival_age>0:
		var elapsed=2.6-arrival_age
		var alpha=1.0 if game.comfort.reduce_motion else minf(elapsed/.22,minf(1.0,arrival_age/.46))
		if alpha>0:
			var shift=0.0 if game.comfort.reduce_motion else (1.0-clampf(elapsed/.26,0,1))*-7
			var bounds=Rect2(225,57+roundf(shift),190,24)
			draw_rect(bounds,Color(.10,.15,.12,alpha*.94))
			draw_rect(bounds.grow(-1),Color(.71,.59,.45,alpha),false)
			draw_string(get_theme_default_font(),bounds.position+Vector2(5,16),arrival,HORIZONTAL_ALIGNMENT_CENTER,180,11,Color(.97,.89,.76,alpha))
	if game.state.flag("rift_mode"): return
	for i in range(3):
		var p=Vector2(492+i*11,24)
		var color=Color("b2d9cb") if i<game.state.charges else Color("514b5c")
		draw_circle(p+Vector2(1,1),4,Color("172126"))
		draw_circle(p,3,color)
