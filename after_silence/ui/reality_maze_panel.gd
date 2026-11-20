extends Control

signal solved
signal changed
const Model=preload("res://after_silence/core/reality_maze.gd")
const Stage=preload("res://after_silence/ui/trial_stage_art.gd")
const CELL=28
const ORIGIN=Vector2(29,10)
const COLORS=[Color("ecb184"),Color("add4b0"),Color("bbabe1")]
const DIRECTIONS={
	KEY_W:Vector2i.UP, KEY_UP:Vector2i.UP, KEY_S:Vector2i.DOWN, KEY_DOWN:Vector2i.DOWN,
	KEY_A:Vector2i.LEFT, KEY_LEFT:Vector2i.LEFT, KEY_D:Vector2i.RIGHT, KEY_RIGHT:Vector2i.RIGHT,
}
var game
var model
var resident
var notes_visible=false
var hint_visible=false
var feedback: Label
var clue: Label
var focus_before_pause: Control
var route: Array[Vector2i]=[]
var walk_delay=0.0
var direction=1
var display_tile=Vector2.ZERO
var move_tween: Tween
var room_tween: Tween
var room_tint=0.0
var guide_path: Array[Vector2i]=[]

func _ready():
	focus_mode=Control.FOCUS_ALL
	mouse_filter=Control.MOUSE_FILTER_STOP
	var heading=Label.new()
	heading.text=game.t("Знаки на записке","Signs on the note")
	heading.position=Vector2(309,13);add_child(heading)
	clue=Label.new()
	clue.position=Vector2(309,38);clue.size=Vector2(253,19)
	clue.add_theme_font_size_override("font_size",13);add_child(clue)
	var instructions=Label.new()
	instructions.text=game.t("Запомни порядок знаков.\nДвери меняют места.\nОшиблась? Комната отразится.","Remember the order.\nDoors change places.\nA wrong turn mirrors the room.")
	instructions.position=Vector2(309,63);instructions.size=Vector2(253,55)
	instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(instructions)
	_add_button("Clue",game.t("Записка","Note"),Vector2(309,123),_note)
	_add_button("Hint",game.t("Подсказка","Hint"),Vector2(438,123),_hint)
	_add_button("Reset",game.t("Сначала","Restart"),Vector2(309,157),_reset)
	feedback=Label.new()
	feedback.position=Vector2(309,192);feedback.size=Vector2(250,16)
	feedback.add_theme_font_size_override("font_size",8);add_child(feedback)
	notes_visible=model.stage==0 and not model.reflected
	display_tile=Vector2(model.tile)
	_refresh();focus_board()

func _add_button(id: String, caption: String, at: Vector2, action: Callable):
	var button=Button.new()
	button.name=id;button.position=at;button.size=Vector2(120,28)
	button.text=caption;button.pressed.connect(action);add_child(button)

func remember_focus():
	var focused=get_viewport().gui_get_focus_owner()
	if focused==self or (is_instance_valid(focused) and is_ancestor_of(focused)): focus_before_pause=focused

func focus_board():
	if is_instance_valid(focus_before_pause): focus_before_pause.grab_focus()
	else: grab_focus()

func _note():
	if game.modal: return
	notes_visible=not notes_visible;_refresh()

func _hint():
	if game.modal: return
	hint_visible=not hint_visible;_refresh()

func _reset():
	if game.modal: return
	model.reset();route.clear();hint_visible=false;notes_visible=true
	if is_instance_valid(move_tween): move_tween.kill()
	display_tile=Vector2(model.tile)
	feedback.text=game.t("Ты снова у входа.","Back at the entrance.")
	_refresh();changed.emit();grab_focus()

func _gui_input(event):
	if game.modal or model.won(): return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var target=Vector2i(((event.position-ORIGIN)/CELL).floor())
		if Rect2i(0,0,9,7).has_point(target):
			route=model.route(target);walk_delay=0
			grab_focus();accept_event()
	if event is InputEventKey and event.pressed:
		var key=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		var move: Vector2i=DIRECTIONS.get(key,Vector2i.ZERO)
		if move!=Vector2i.ZERO:
			route.clear();accept_event();_step(model.tile+move,true)

func _process(delta):
	if game.modal or route.is_empty(): return
	walk_delay-=delta
	if walk_delay<=0:
		walk_delay=.06 if not game.comfort.reduce_motion else .015
		_step(route.pop_front(),route.is_empty())

func _step(next: Vector2i, save_walk: bool):
	var previous: Vector2i=model.tile
	var outcome: String=model.move(next)
	if outcome.is_empty(): return
	var delta=next-previous
	direction=0 if delta.y>0 else 1 if delta.y<0 else 2 if delta.x<0 else 3
	if is_instance_valid(move_tween): move_tween.kill()
	if outcome=="walk" and not game.comfort.reduce_motion:
		move_tween=create_tween()
		move_tween.tween_method(_move_art,display_tile,Vector2(model.tile),.14).set_trans(Tween.TRANS_SINE)
	else: display_tile=Vector2(model.tile)
	if outcome!="walk":
		route.clear();notes_visible=false;hint_visible=false
		feedback.text=game.t("Комната отразилась.","The room mirrored.") if outcome=="reflect" else game.t("Проход открылся.","The passage opened.")
		game.audio.ping(game.state.volume)
		if not game.comfort.reduce_motion:
			if is_instance_valid(room_tween): room_tween.kill()
			room_tint=.38
			room_tween=create_tween()
			room_tween.tween_method(_shade_room,.38,0.0,.34)
	_refresh()
	if model.won(): solved.emit()
	elif outcome!="walk" or save_walk: changed.emit()

func _refresh():
	guide_path.clear()
	if hint_visible and not model.won(): guide_path=model.route(model.destination())
	var signs=PackedStringArray()
	for i in range(model.order.size()):
		signs.append("✓" if i<model.stage else Model.SIGILS[model.order[i]] if notes_visible else "·")
	clue.text="   ".join(signs)
	queue_redraw()

func _move_art(value: Vector2):
	display_tile=value;queue_redraw()

func _shade_room(value: float):
	room_tint=value;queue_redraw()

func _draw():
	var walls=Color("40334f") if model.reflected else Color("33434f")
	Stage.draw(self,"reality",294,204)
	for y in range(7):
		for x in range(9):
			var at=Vector2i(x,y)
			var box=Rect2(ORIGIN+Vector2(at)*CELL,Vector2.ONE*CELL)
			if model.walkable(at):
				var floor_color=Color("675269") if model.reflected else Color("4a6267")
				draw_rect(box,floor_color.lightened(.045 if (x+y)%2==0 else 0))
				draw_rect(Rect2(box.position,Vector2(CELL,1)),floor_color.lightened(.13))
				draw_rect(Rect2(box.position+Vector2(5,22),Vector2(8,1)),floor_color.darkened(.12))
			else:
				draw_rect(box,walls)
				draw_rect(Rect2(box.position+Vector2(1,2),Vector2(CELL-2,3)),walls.lightened(.16))
				draw_rect(Rect2(box.position+Vector2(0,24),Vector2(CELL,4)),walls.darkened(.27))
				for i in range(2): draw_rect(Rect2(box.position+Vector2(4+(x+y+i*11)%17,10+i*7),Vector2(8,1)),walls.lightened(.12))
	for i in range(Model.PORTALS.size()):
		var center=ORIGIN+(Vector2(Model.PORTALS[i])+Vector2(.5,.5))*CELL
		var tint=COLORS[model.sigil(i)]
		draw_rect(Rect2(center-Vector2(11,8),Vector2(22,20)),tint.darkened(.48))
		draw_rect(Rect2(center-Vector2(8,11),Vector2(16,17)),tint.darkened(.48))
		draw_rect(Rect2(center-Vector2(7,7),Vector2(14,19)),Color("222331"))
		draw_string(get_theme_default_font(),center+Vector2(-5,5),Model.SIGILS[model.sigil(i)],HORIZONTAL_ALIGNMENT_LEFT,-1,10,tint)
		if hint_visible and Model.PORTALS[i]==model.destination():
			draw_rect(Rect2(center-Vector2(13,13),Vector2(26,26)),Color("f3d598"),false,2)
	var previous=Vector2(model.tile)
	for cell in guide_path:
		var ray=(Vector2(cell)-previous).normalized()
		var at=ORIGIN+((Vector2(cell)+previous)*.5+Vector2(.5,.5))*CELL
		draw_polyline(PackedVector2Array([at-ray*3+ray.orthogonal()*4,at+ray*3,at-ray*3-ray.orthogonal()*4]),Color("f4d895"),2)
		previous=Vector2(cell)
	var focus=(ORIGIN+display_tile*CELL).round()
	draw_rect(Rect2(focus+Vector2(2,2),Vector2(CELL-4,CELL-4)),Color("a9d8bf"),false)
	if is_instance_valid(resident):
		_draw_person(resident,focus+Vector2(21,24),14,0,Color("ddd1f2"))
	_draw_person(game.player,focus+Vector2(11,23),22,direction,Color.WHITE)
	if room_tint>0.0:
		draw_rect(Rect2(ORIGIN,Vector2(9,7)*CELL),Color(.40,.34,.55,room_tint))

func _draw_person(actor,feet: Vector2,height: int,facing: int,tint: Color):
	if actor.sheet==null: return
	var source=Rect2(10,facing*96+25,44,65)
	draw_texture_rect_region(actor.sheet,Rect2(feet-Vector2(7,height),Vector2(14,height)),source,tint)
