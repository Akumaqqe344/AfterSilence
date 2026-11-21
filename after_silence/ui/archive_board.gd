extends VBoxContainer

signal changed(values: Array)
signal confirmed
signal checked
const Model = preload("res://after_silence/core/archive_trials.gd")
const Stage = preload("res://after_silence/ui/trial_stage_art.gd")
const CARDS = [["Дождь","Rain"],["Колокол","Bell"],["Тишина","Silence"]]
const PORTS = [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]
const INK = Color("e3c99e")
const LIVE = Color("b8d5a0")
const DARK = Color("242d34")

var kind: String
var game
var values: Array
var selected = -1
var tested = false
var tools: Array[Button] = []
var slots: Array[Button] = []
var heading: Label
var status: Label
var art: Control
var footer: HBoxContainer

func _ready():
	name = "ArchiveBoard"
	add_theme_constant_override("separation", 3)
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(heading)
	match kind:
		"catalog": build_catalog()
		"clock": build_clock()
		"relay": build_relay()
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status)
	footer = HBoxContainer.new()
	add_child(footer)
	if kind == "relay":
		make_button(game.t("Проверить цепь", "Test circuit"), footer, test_circuit)
	make_button(game.t("Сбросить", "Reset"), footer, reset_board)
	make_button(game.t("Подтвердить", "Confirm"), footer, func(): confirmed.emit())
	refresh()

func make_button(title: String, row: Container, action: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 26
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	Stage.button(button)
	row.add_child(button)
	return button

func build_catalog():
	var cards = HBoxContainer.new()
	add_child(cards)
	for i in CARDS.size():
		tools.append(make_button(game.t(CARDS[i][0], CARDS[i][1]),cards,select_card.bind(i)))
	var pockets = HBoxContainer.new()
	add_child(pockets)
	for i in 3:
		slots.append(make_button("",pockets,place_card.bind(i)))

func select_card(i: int):
	selected = i
	refresh()

func place_card(index: int):
	if selected == -1:
		message(game.t("Сначала возьмите карточку.", "Choose a card first."),false)
		return
	var old = values.find(selected)
	if old >= 0: values[old] = -1
	values[index] = selected
	selected = -1
	update_board()

func build_clock():
	make_canvas(64)
	var digits = HBoxContainer.new()
	add_child(digits)
	for i in 2:
		var field = VBoxContainer.new()
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		digits.add_child(field)
		var label = Label.new()
		label.text = game.t("Часы", "Hours") if i == 0 else game.t("Минуты", "Minutes")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.add_child(label)
		var spin = SpinBox.new()
		spin.min_value = 0
		spin.max_value = 23 if i == 0 else 59
		spin.update_on_text_changed = false
		spin.value = values[i]
		spin.get_line_edit().select_all_on_focus = true
		spin.value_changed.connect(set_time.bind(i))
		field.add_child(spin)

func set_time(value: float, index: int):
	values[index] = int(value)
	update_board()

func build_relay():
	make_canvas(72)
	var row = HBoxContainer.new()
	add_child(row)
	var labels = [["Верхний", "Upper"], ["Распределитель", "Distributor"], ["Нижний", "Lower"]]
	for i in 3:
		tools.append(make_button(game.t(labels[i][0], labels[i][1]), row, rotate_connector.bind(i)))

func make_canvas(height: float):
	art = Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size.y = height
	art.draw.connect(draw_instrument)
	add_child(art)

func rotate_connector(i: int):
	values[i] = (values[i] + 1) % 4
	tested = false
	update_board()

func test_circuit():
	tested = true
	refresh()
	checked.emit()

func reset_board():
	values = Model.DEFAULTS[kind].duplicate()
	selected = -1
	tested = false
	if kind == "clock":
		var row = get_child(2)
		for i in 2: row.get_child(i).get_child(1).set_value_no_signal(0)
	update_board()

func refresh():
	match kind:
		"catalog":
			heading.text = game.t("Карточки · места в папке", "Cards · folder pockets")
			for i in 3:
				var caption = "%d · " % (i+1)
				var mark: int = values[i]
				caption += game.t("пусто", "empty") if mark < 0 else game.t(CARDS[mark][0], CARDS[mark][1])
				slots[i].text = caption
				Stage.button(tools[i], selected == i)
			status.text = game.t("Выберите карточку, затем её место.", "Choose a card, then its pocket.")
		"clock":
			heading.text = "%02d:%02d" % values
			status.text = game.t("Введите число или измените его стрелками.", "Type a number or use the arrows.")
		"relay":
			heading.text = game.t("Контакты от источника к нагрузкам", "Connections from supply to loads")
			status.text = game.t("Поворачивайте контакты и проверяйте цепь.", "Rotate the contacts and test the circuit.")
			if tested:
				var paths = Model.circuits(values)
				status.text = game.t("Насос", "Pump") + " %d/2   ·   " % (int(paths.upper)+int(paths.lower)) + game.t("Колокол", "Bell") + (" ●" if paths.alarm else " ○")
	if is_instance_valid(art): art.queue_redraw()

func update_board():
	refresh()
	changed.emit(values.duplicate())

func message(value: String, accepted: bool):
	status.text = value
	status.modulate = LIVE if accepted else Color("efb9a1")

func draw_instrument():
	art.draw_style_box(Stage.plate("hud"),Rect2(Vector2.ZERO,art.size))
	if kind == "clock":
		var center = art.size * .5
		art.draw_circle(center,25,DARK)
		art.draw_arc(center,28,0,TAU,36,INK,2.0)
		for i in 12:
			var normal = Vector2.UP.rotated(i*TAU/12)
			art.draw_line(center+normal*21,center+normal*25,INK,2)
		art.draw_line(center,center+Vector2.UP.rotated((values[0]%12+values[1]/60.0)*TAU/12)*14,INK,3)
		art.draw_line(center,center+Vector2.UP.rotated(values[1]*TAU/60)*21,LIVE,2)
		return
	var mid = art.size * .5
	var start = mid + Vector2(-52,0)
	var ends = [mid+Vector2(50,-23),mid+Vector2(50,0),mid+Vector2(50,23)]
	var paths = Model.circuits(values)
	art.draw_line(start,mid,INK if paths.input else INK.darkened(.5),2)
	for i in 3:
		var node = mid + Vector2(0,(i-1)*23)
		var live = [paths.upper,paths.alarm,paths.lower][i]
		if i != 1:
			art.draw_line(mid,node,INK.darkened(.55),2)
		art.draw_line(node,ends[i],INK.darkened(.55),2)
		art.draw_circle(node,10,DARK)
		var mask = Model.pin_mask(i,values[i])
		for direction in 4:
			if mask & (1<<direction):
				art.draw_line(node,node+PORTS[direction]*9,INK,3)
		art.draw_circle(ends[i],5,(Color("dd9276") if i==1 else LIVE) if live else Color("645d5a"))
		art.draw_string(get_theme_default_font(),ends[i]+Vector2(9,5),[game.t("Насос I","Pump I"),game.t("Колокол","Bell"),game.t("Насос II","Pump II")][i],HORIZONTAL_ALIGNMENT_LEFT,-1,11,INK)
	art.draw_circle(start,5,INK)
