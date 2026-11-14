extends Control
var game
var actions: Array[Button]=[]
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for entry in [["J","Журнал","Journal","_journal"],["I","Предметы","Inventory","_inventory"],["Tab","Отголосок","Echo","_shift"],["Esc","Пауза","Pause","_pause"]]:
		var button=Button.new()
		button.position=Vector2(516+actions.size()*29,331)
		button.size=Vector2(26,20)
		button.add_theme_font_size_override("font_size",8)
		var box=StyleBoxFlat.new()
		box.bg_color=Color(.08,.12,.14,.48)
		box.set_content_margin_all(2)
		button.add_theme_stylebox_override("normal",box)
		for name in ["hover","focus","pressed"]:
			var active=box.duplicate()
			active.bg_color=Color(.22,.3,.3,.8)
			active.border_color=Color("b2c2aa")
			active.set_border_width_all(1)
			button.add_theme_stylebox_override(name,active)
		button.set_meta("entry",entry)
		button.pressed.connect(func():game.call(entry[3]))
		add_child(button)
		actions.append(button)
func _process(_dt):
	visible=not game.modal and not game.in_menu
	for button in actions:
		var entry=button.get_meta("entry")
		button.text=entry[0]
		button.tooltip_text=game.t(entry[1],entry[2])
		button.disabled=game.transitions.busy or game.cutscenes.running
	queue_redraw()
func _draw():
	var clock="%02d:%02d"%[int(game.state.clock),int(fmod(game.state.clock,1)*60)]
	draw_string(get_theme_default_font(),Vector2(540,23),clock,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e3decd"))
	for i in range(3):
		var p=Vector2(586+i*15,20)
		var color=Color("b2d9cb") if i<game.state.charges else Color("514b5c")
		draw_circle(p+Vector2(1,1),4,Color("172126"))
		draw_circle(p,3,color)
