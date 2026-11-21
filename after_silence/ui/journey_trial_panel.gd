extends Control

signal solved
signal changed
const Rules=preload("res://after_silence/core/journey_trials.gd")
const ThemeArt=preload("res://after_silence/ui/comfort_theme.gd")
const Stage=preload("res://after_silence/ui/trial_stage_art.gd")
const Motion=preload("res://after_silence/ui/trial_motion.gd")
const PAPER=Color("e2c698")
const SKY=Color("a5bfdf")
const MINT=Color("acd0b1")
const AMBER=Color("e4bf81")
const INK=Color("222637")
const TITLES={
	"letter_press":["Письмо","The letter"],
	"footprints":["След гостя","The guest's trail"],
	"balance":["Груз на мосту","Bridge load"],
	"signal_grid":["План площади","Square lights"],
	"railway":["Пульт поезда","Railway desk"],
	"echo_tuning":["Эхо Алины","Alina's echo"],
}
const HELP={
	"letter_press":["Поверни обрывки, чтобы собрать письмо.","Turn the fragments to mend the letter."],
	"footprints":["Ищи форму и метку, указанные в улике.","Find the shape and mark in the clue."],
	"balance":["Переложи все грузы. Вес слева и справа должен совпасть.","Load every weight. Balance both sides."],
	"signal_grid":["Числа — длина групп огней. Разделяй группы тёмной клеткой.","Numbers show lit runs. Leave a dark cell between runs."],
	"railway":["Переведи стрелки к нужной станции и нажми «Пуск».","Set the route to the station and press Send."],
	"echo_tuning":["Совмести линии высотой и сдвигом. Нажми «Записать».","Match the waves using height and shift. Press Record."],
}
const TRACE_SHAPES=[["Круглый","Rounded"],["Острый","Pointed"],["Прямой","Square"]]
const TRACE_MARKS=[["крест","cross"],["царапина","scratch"]]
const STATION_NAMES=["A","B","C","D"]
const GRID_AT=Vector2(119,41)
const GRID_STEP=29

var game
var model
var action_buttons: Array[Button]=[]
var clue: Label
var feedback: Label
var undo_button: Button
var reset_button: Button
var focus_before_pause: Control
var paper_icons: Array[Texture2D]=[]
var trace_icons: Array[Texture2D]=[]
var highlighted=-1
var effects: Control
var displayed_echo=Vector2.ZERO
var echo_tween: Tween
var carriage: Tween
var rail_u=0.0
var dispatch_to=-1

func _ready():
	mouse_filter=Control.MOUSE_FILTER_STOP
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var heading=_label(Vector2(386,13),Vector2(181,16),_pair(TITLES[model.kind]))
	heading.add_theme_color_override("font_color",ThemeArt.PEACH)
	_label(Vector2(386,35),Vector2(181,68),_pair(HELP[model.kind]))
	clue=_label(Vector2(386,100),Vector2(180,26),"")
	_tool("Hint",game.t("Подсказка","Hint"),130,_hint)
	undo_button=_tool("Undo",game.t("Отменить ход","Undo move"),157,_undo)
	reset_button=_tool("Reset",game.t("Сначала","Reset"),184,_reset)
	feedback=_label(Vector2(14,194),Vector2(354,19),"")
	feedback.add_theme_color_override("font_color",ThemeArt.PEACH)
	_build_board()
	var tab_order: Array=action_buttons.duplicate()
	tab_order.append_array([get_node("Hint"),undo_button,reset_button])
	for i in tab_order.size():
		var button: Button=tab_order[i]
		button.focus_next=button.get_path_to(tab_order[(i+1)%tab_order.size()])
		button.focus_previous=button.get_path_to(tab_order[posmod(i-1,tab_order.size())])
	effects=Motion.new();effects.game=game;add_child(effects)
	if model.kind=="echo_tuning": displayed_echo=Vector2(model.state[0],model.state[1])
	_refresh()
	focus_board()

func _pair(words: Array) -> String:
	return game.t(words[0],words[1])

func _label(at: Vector2, bounds: Vector2, caption: String) -> Label:
	var label=Label.new()
	label.position=at;label.size=bounds;label.text=caption
	label.add_theme_font_size_override("font_size",12 if game.comfort.large_text else 11)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _tool(id: String, caption: String, y: int, action: Callable) -> Button:
	var button=Button.new()
	button.name=id;button.text=caption;button.position=Vector2(386,y)
	button.add_theme_font_size_override("font_size",12 if game.comfort.large_text else 11)
	Stage.button(button)
	button.pressed.connect(action);add_child(button)
	button.size=Vector2(176,24)
	game.ComfortMotion.wire_button(button,game.comfort)
	return button

func _action(at: Vector2, bounds: Vector2, caption: String, tooltip: String="") -> Button:
	var id=action_buttons.size()
	var button=Button.new()
	button.name="Move%d"%id;button.text=caption;button.tooltip_text=tooltip
	button.position=at;button.size=bounds;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var buttons_before=get_child_count()
	add_child(button)
	move_child(button,maxi(0,buttons_before-4))
	game.ComfortMotion.wire_button(button,game.comfort)
	button.pressed.connect(play.bind(id))
	Stage.button(button)
	action_buttons.append(button)
	return button

func _build_board():
	match model.kind:
		"letter_press":
			_paint_letter()
			for i in range(4):
				var tile=_action(Vector2(109,16)+Vector2(i%2,floori(i/2.0))*Vector2(76,76),Vector2(72,72),"",game.t("Повернуть фрагмент","Rotate fragment"))
				tile.expand_icon=true;tile.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
				tile.add_theme_constant_override("icon_max_width",62)
		"footprints":
			_paint_traces()
			for i in range(6):
				var tile=_action(Vector2(26,34)+Vector2(i%3,floori(i/3.0))*Vector2(111,70),Vector2(99,57),"")
				tile.expand_icon=true;tile.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
				tile.add_theme_constant_override("icon_max_width",49)
		"balance":
			for i in range(5):
				var weight=_action(Vector2.ZERO,Vector2(63,24),str(model.loads[i]),game.t("Переложить груз","Move weight"))
				weight.icon=Stage.icon(12)
				weight.add_theme_constant_override("icon_max_width",17)
		"signal_grid":
			for i in range(25):
				var tile=_action(GRID_AT+Vector2(i%5,floori(i/5.0))*GRID_STEP,Vector2(27,27),"",game.t("Переключить фонарь","Toggle lamp"))
				tile.add_theme_font_size_override("font_size",10)
				tile.add_theme_constant_override("icon_max_width",19)
		"railway":
			for i in range(3): _action(Vector2(18+i*87,147),Vector2(77,30),"",game.t("Перевести стрелку","Set switch"))
			_action(Vector2(278,147),Vector2(88,30),game.t("Пуск","Send"))
		"echo_tuning":
			for i in range(4): _action(Vector2(18+i*61,148),Vector2(54,30),["−","+","−","+"][i],game.t("Высота","Height") if i<2 else game.t("Сдвиг","Shift"))
			_action(Vector2(267,148),Vector2(97,30),game.t("Записать","Record"))

func remember_focus():
	var owner=get_viewport().gui_get_focus_owner()
	if is_instance_valid(owner) and is_ancestor_of(owner): focus_before_pause=owner

func focus_board():
	if is_instance_valid(focus_before_pause): focus_before_pause.grab_focus()
	elif not action_buttons.is_empty(): action_buttons[0].grab_focus()

func play(id: int):
	if game.modal or model.won(): return
	highlighted=-1
	var at=action_buttons[id].get_rect().get_center()
	if model.perform(id):
		game.audio.trial_move(model.kind, true, game.state.volume)
		feedback.text=""
		_refresh()
		_animate_action(id,at)
		if model.won(): solved.emit()
		else: changed.emit()
	else:
		game.audio.trial_move(model.kind, false, game.state.volume)
		effects.stamp(at, model.kind, false)
		feedback.text=game.t("Попробуй другой вариант.","Try another option.")
		match model.kind:
			"footprints": feedback.text=game.t("Сверь форму и след на подошве.","Compare both the shape and the sole marking.")
			"railway": feedback.text=game.t("Поезд ушёл бы на другую станцию.","The train would reach a different station.")
			"echo_tuning": feedback.text=game.t("Совмести высоту и фазу обеих волн.","Align the height and phase of both waves.")
		_refresh()

func _animate_action(id: int,at: Vector2):
	if game.comfort.reduce_motion:
		if model.kind=="echo_tuning": displayed_echo=Vector2(model.state[0],model.state[1])
		return
	var tint=Stage.accent(model.kind).lightened(.25)
	match model.kind:
		"letter_press": effects.turn(at,action_buttons[id].icon)
		"balance": effects.transfer(at,action_buttons[id].get_rect().get_center(),tint)
		"railway":
			if id==3:
				if is_instance_valid(carriage): carriage.kill()
				dispatch_to=model.station()
				rail_u=0
				carriage=create_tween()
				carriage.tween_method(_advance_train,0.0,1.0,.55).set_trans(Tween.TRANS_SINE)
				carriage.tween_callback(func():dispatch_to=-1;queue_redraw())
		"echo_tuning":
			if is_instance_valid(echo_tween): echo_tween.kill()
			var adjusted=Vector2(model.state[0],model.state[1])
			echo_tween=create_tween()
			echo_tween.tween_method(_ease_wave,displayed_echo,adjusted,.24).set_trans(Tween.TRANS_SINE)
	effects.stamp(action_buttons[id].get_rect().get_center(), model.kind, true)

func _advance_train(fraction: float):
	rail_u=fraction;queue_redraw()

func _ease_wave(value: Vector2):
	displayed_echo=value;queue_redraw()

func _restore_motion():
	if is_instance_valid(echo_tween): echo_tween.kill()
	if is_instance_valid(carriage): carriage.kill()
	dispatch_to=-1
	if model.kind=="echo_tuning": displayed_echo=Vector2(model.state[0],model.state[1])

func _hint():
	if game.modal: return
	highlighted=model.hint()
	feedback.text=game.t("Следующий шаг подсвечен.","The next move is highlighted.") if highlighted>=0 else game.t("Отмени ход или начни сначала.","Undo or restart.")
	_refresh()

func _undo():
	if game.modal: return
	model.undo()
	_restore_motion()
	highlighted=-1;feedback.text=""
	_refresh();changed.emit()

func _reset():
	if game.modal: return
	model.reset()
	_restore_motion()
	highlighted=-1;feedback.text=""
	_refresh();changed.emit();focus_board()

func _refresh():
	undo_button.disabled=model.history.is_empty()
	reset_button.disabled=model.history.is_empty()
	for i in range(action_buttons.size()):
		var tile=action_buttons[i]
		var active=false
		match model.kind:
			"letter_press":
				tile.icon=paper_icons[i*4+model.state[i]]
			"footprints":
				if not model.won():
					var trace: Array=model.trace_rows[model.round_index][i]
					tile.icon=trace_icons[trace[0]*2+trace[1]]
					tile.tooltip_text=_trace_label(trace)
			"balance":
				var side: int=model.state[i]
				tile.position=Vector2(44+side*110,42+i*27)
				active=side>0
			"signal_grid":
				active=(model.state[floori(i/5.0)]&(1<<(i%5)))!=0
				tile.icon=Stage.icon(1 if active else 0)
				tile.tooltip_text=game.t("Горит","Lit") if active else game.t("Погашен","Unlit")
			"railway":
				if i<3: tile.text=["I","II","III"][i]+(" ↘" if model.state[i] else " ↗")
		Stage.button(tile,active or i==highlighted)
		if i==highlighted:
			var mark=ThemeArt.button(true)
			mark.border_color=AMBER;mark.set_border_width_all(2)
			tile.add_theme_stylebox_override("normal",mark)
	match model.kind:
		"footprints":
			if not model.won():
				var trace: Array=model.trace_clues[model.round_index]
				clue.text=_trace_label(trace)
		"railway":
			if not model.won(): clue.text=game.t("Станция  ","Station  ")+STATION_NAMES[model.stations[model.round_index]]
		"balance": clue.text="%d  /  %d"%[model.weight(1),model.weight(2)]
	queue_redraw()

func _trace_label(trace: Array) -> String:
	return _pair(TRACE_SHAPES[trace[0]])+" · "+_pair(TRACE_MARKS[trace[1]])

func _paint_traces():
	for shape in range(3):
		for mark in range(2):
			var icon=Image.create(36,36,false,Image.FORMAT_RGBA8)
			var clay=Color("b89a77")
			for y in range(4,24):
				var wide=9
				if shape==0: wide=6 if y<6 else 8 if y<9 else 10
				elif shape==1: wide=mini(10,y-2)
				for x in range(18-wide,18+wide+1):
					var color=clay.darkened(.28) if x==18-wide or (x+y*9)%11==0 else clay
					icon.set_pixel(x,y,color)
			icon.fill_rect(Rect2i(12,26,12,6),clay.darkened(.2))
			icon.fill_rect(Rect2i(14,26,8,1),clay.lightened(.15))
			for x in range(12,24,3): icon.fill_rect(Rect2i(x,29,1,2),clay.darkened(.35))
			if mark==0:
				icon.fill_rect(Rect2i(17,12,2,8),INK)
				icon.fill_rect(Rect2i(14,15,8,2),INK)
			else:
				for i in range(8): icon.fill_rect(Rect2i(13+i,19-i,2,2),INK)
			trace_icons.append(ImageTexture.create_from_image(icon))

func _paint_letter():
	var art=Image.create(72,72,false,Image.FORMAT_RGBA8)
	art.fill(PAPER)
	for y in range(72):
		for x in range(72):
			if (x*47+y*19)%37<3: art.set_pixel(x,y,Color("d4b582"))
	art.fill_rect(Rect2i(3,3,66,2),Color("8a685e"))
	art.fill_rect(Rect2i(3,67,66,2),Color("8a685e"))
	art.fill_rect(Rect2i(3,3,2,66),Color("8a685e"))
	art.fill_rect(Rect2i(67,3,2,66),Color("8a685e"))
	for i in range(8):
		var y=11+i*6
		var end=52+(i*7)%12
		art.fill_rect(Rect2i(10+(i*11)%8,y,end-13,1),Color("7e6b71"))
	art.fill_rect(Rect2i(43,53,17,11),Color("9f5e52"))
	art.fill_rect(Rect2i(46,55,11,7),Color("be7d63"))
	art.fill_rect(Rect2i(49,56,5,4),Color("d09875"))
	for corner in [Vector2i(6,6),Vector2i(62,6),Vector2i(6,62),Vector2i(62,62)]:
		art.fill_rect(Rect2i(corner,Vector2i(3,3)),Color("ad8565"))
	for i in range(4):
		var piece=art.get_region(Rect2i(Vector2i(i%2,floori(i/2.0))*36,Vector2i(36,36)))
		for rot in range(4):
			paper_icons.append(ImageTexture.create_from_image(piece))
			piece.rotate_90(CLOCKWISE)

func _draw():
	Stage.draw(self,model.kind,376)
	match model.kind:
		"letter_press":
			draw_rect(Rect2(98,12,174,166),Color("6a514b"),false,3)
		"footprints":
			for i in range(3): draw_rect(Rect2(26+i*111,20,99,4),Color("9b795f"))
		"balance": _draw_balance()
		"signal_grid": _draw_signals()
		"railway": _draw_rails()
		"echo_tuning": _draw_echo()

func _caption(at: Vector2, value: String, color: Color=Color("fff3e2")):
	draw_string(get_theme_default_font(),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,8,color)

func _draw_balance():
	for i in range(3):
		draw_style_box(Stage.plate("hud"),Rect2(34+i*110,29,84,149))
		draw_rect(Rect2(36+i*110,175,80,3),AMBER if i==0 else MINT)
	_caption(Vector2(45,25),game.t("Запас","Depot"))
	_caption(Vector2(150,25),game.t("Слева","Left"))
	_caption(Vector2(255,25),game.t("Справа","Right"))

func _draw_signals():
	for i in range(5):
		var row=" ".join(Rules.runs(model.signal_rows[i]).map(func(n):return str(n)))
		var col=" ".join(Rules.runs(Rules.column(model.signal_rows,i)).map(func(n):return str(n)))
		_caption(GRID_AT+Vector2(-35,i*GRID_STEP+18),row)
		_caption(GRID_AT+Vector2(i*GRID_STEP+9,-9),col)

func _draw_rails():
	var entry=Vector2(28,80)
	var pivot=Vector2(105,80)
	var junctions=[Vector2(193,43),Vector2(193,109)]
	var rails=Color("697583")
	_track(entry,pivot,MINT)
	for j in range(2):
		_track(pivot,junctions[j],MINT if model.state[0]==j else rails)
		for k in range(2):
			var end=Vector2(302,27+j*66+k*30)
			_track(junctions[j],end,MINT if model.station()==j*2+k else rails)
			var station_color=AMBER if not model.won() and model.stations[model.round_index]==j*2+k else SKY
			draw_rect(Rect2(end-Vector2(4,7),Vector2(27,14)),station_color.darkened(.65))
			_caption(end+Vector2(4,4),STATION_NAMES[j*2+k],station_color)
	if dispatch_to>=0:
		var lane=floori(dispatch_to/2.0)
		var points=[entry,pivot,junctions[lane],Vector2(302,27+lane*66+dispatch_to%2*30)]
		var segment=mini(2,int(rail_u*3))
		entry=points[segment].lerp(points[segment+1],clampf(rail_u*3-segment,0,1)).round()
	draw_rect(Rect2(entry-Vector2(10,9),Vector2(22,14)),Color("725c55"))
	draw_rect(Rect2(entry-Vector2(8,8),Vector2(18,10)),AMBER)
	draw_rect(Rect2(entry-Vector2(7,6),Vector2(7,4)),SKY.darkened(.25))
	draw_rect(Rect2(entry+Vector2(4,-8),Vector2(5,5)),Color("573e37"))
	draw_rect(Rect2(entry+Vector2(7,-3),Vector2(5,3)),Color("fff1b6"))
	for x in [-7,6]: draw_rect(Rect2(entry+Vector2(x,4),Vector2(5,4)),Color("292d37"))

func _track(from: Vector2,to: Vector2,tint: Color):
	draw_line(from,to,Color("303244"),7)
	draw_line(from,to,tint.darkened(.43),4)
	draw_line(from,to,tint,1)
	var span=from.distance_to(to)
	var normal=from.direction_to(to).orthogonal()
	for i in range(1,ceili(span/12)):
		var tie=from.lerp(to,i*12/span).round()
		draw_line((tie+normal*4).round(),(tie-normal*4).round(),Color("a08d79"),1)

func _draw_echo():
	draw_style_box(Stage.plate("hud"),Rect2(17,18,346,110))
	for i in range(10): draw_line(Vector2(24+i*36,24),Vector2(24+i*36,120),Color("44485a"))
	for i in range(4): draw_line(Vector2(20,29+i*27),Vector2(355,29+i*27),Color("44485a"))
	var target: Array=model.echoes[mini(model.round_index,model.echoes.size()-1)]
	_wave(target,Color("7993b6"),4)
	_wave([displayed_echo.x,displayed_echo.y],AMBER,2)
	Stage.stamp(self,15,Vector2(351,138),Vector2(18,18))
	_caption(Vector2(36,139),game.t("Высота","Height"),AMBER)
	_caption(Vector2(169,139),game.t("Сдвиг","Shift"),AMBER)

func _wave(values: Array, color: Color, width: int):
	var path=PackedVector2Array()
	for x in range(22,356,3):
		path.append(Vector2(x,roundf(73+sin(x*.055+values[1]*.58)*(7+values[0]*8))))
	draw_polyline(path,color,width)
