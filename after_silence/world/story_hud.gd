extends Control
var game
var actions: Array[Button]=[]
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for entry in [["J","Журнал","Journal","_journal"],["I","Предметы","Inventory","_inventory"],["TAB","Отголосок","Echo","_shift"],["ESC","Пауза","Pause","_pause"]]:
		var button=Button.new()
		button.position=Vector2(116+actions.size()*104,323)
		button.size=Vector2(100,30)
		button.add_theme_font_size_override("font_size",11)
		button.set_meta("entry",entry)
		button.pressed.connect(func():game.call(entry[3]))
		add_child(button)
		actions.append(button)
func _process(_dt):
	for button in actions:
		var entry=button.get_meta("entry")
		button.text=entry[0]+"  "+game.t(entry[1],entry[2])
		button.disabled=game.modal or game.in_menu or game.transitions.busy or game.cutscenes.running
	queue_redraw()
func panel(rect: Rect2):
	draw_rect(Rect2(rect.position+Vector2(3,3),rect.size),Color("141720bb"))
	draw_rect(rect,Color("282336ec"))
	draw_rect(rect,Color("8b7664"),false,2)
	draw_line(rect.position+Vector2(3,3),rect.position+Vector2(rect.size.x-3,3),Color("d8bd85"))
func _draw():
	panel(Rect2(8,8,110,69))
	panel(Rect2(126,8,506,69))
	if is_instance_valid(game.player):
		draw_texture_rect_region(game.player.sheet,Rect2(16,12,32,48),Rect2(0,0,64,96))
	for i in range(3):
		var p=Vector2(63+i*17,31)
		var color=Color("b2d9cb") if i<game.state.charges else Color("514b5c")
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-7),p+Vector2(5,0),p+Vector2(0,7),p+Vector2(-5,0)]),color)
		if i<game.state.charges: draw_line(p+Vector2(0,-5),p+Vector2(-3,0),Color("eff3db"))
