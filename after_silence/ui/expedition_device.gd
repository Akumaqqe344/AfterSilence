extends VBoxContainer

signal changed(values: Array, accepted: bool)
signal solved

const SHEET = preload("res://after_silence/assets/expeditions0330/mechanisms.png")
var step: Dictionary
var dials: Array[int] = [0, 0, 0]
var winch = false
var russian = false
var reduced = false
var art: TextureRect
var caption: Label
var controls: HBoxContainer
var buttons: Array[Button] = []
var finished = false

func configure(definition: Dictionary, checkpoint: Array, use_russian: bool, reduce_motion: bool):
	step = definition
	winch = step.device == "winch"
	russian = use_russian
	reduced = reduce_motion
	if checkpoint.size() == 3:
		for i in dials.size():
			dials[i] = clampi(int(checkpoint[i]), 0, 2)
		if winch:
			dials[0] = mini(1, dials[0])
			dials[1] = mini(1, dials[1])

func _ready():
	add_theme_constant_override("separation", 5)
	art = TextureRect.new()
	art.custom_minimum_size = Vector2(0, 64)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(art)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(caption)
	controls = HBoxContainer.new()
	add_child(controls)
	for i in range(4):
		var button = Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(act.bind(i))
		controls.add_child(button)
		buttons.append(button)
	update_board()

func translate(ru: String, en: String) -> String:
	return ru if russian else en

func focus_first():
	buttons.front().grab_focus()

func update_board(message: String = ""):
	var atlas = AtlasTexture.new()
	atlas.atlas = SHEET
	var index: int = dials[2] if winch else dials[0]
	if finished: index = 3
	atlas.region = Rect2(index * 112, 40 if winch else 0, 112, 40)
	if winch or finished:
		art.texture = atlas
	else:
		var atlas_image = SHEET.get_image()
		var face = atlas_image.get_region(atlas.region)
		for i in range(dials.size()):
			var x = 14 + i * 31
			face.blit_rect(atlas_image, Rect2i(x + dials[i] * 112, 8, 23, 24), Vector2i(x, 8))
		art.texture = ImageTexture.create_from_image(face)
	if winch:
		buttons[0].text = translate("Тормоз ✓", "Brake ✓") if dials[0] == 0 else translate("Отпустить", "Released")
		buttons[1].text = translate("Выбрать канат", "Take up slack") if dials[1] == 0 else translate("Канат натянут", "Line taut")
		buttons[2].text = translate("Отметка %d ↻", "Mark %d ↻") % (dials[2] + 1)
		buttons[3].text = translate("Зафиксировать", "Set brake")
	else:
		for i in range(3):
			buttons[i].text = step.dials[i][dials[i]][0 if russian else 1] + " ↻"
		buttons[3].text = translate("Передать", "Transmit")
	caption.text = message if not message.is_empty() else (translate("Тормоз · Канат · Подъём", "Brake · Line · Lift") if winch else translate("Адрес · Прорезь · Назначение", "Address · Notch · Destination"))

func act(index: int):
	if finished: return
	var status = ""
	if index == 3:
		var target: Array = [1, 1, 1] if winch else step.target.map(func(n): return int(n))
		finished = dials == target
		if not finished:
			status = translate("Механизм не удерживается на этой отметке.", "The mechanism will not hold at this setting.") if winch else translate("Окошко выдачи не открылось. Сверьтесь с жетоном.", "The issue window stayed shut. Check the token.")
	elif not winch:
		dials[index] = (dials[index] + 1) % 3
	else:
		match index:
			0:
				dials[0] = 1 - dials[0]
			1:
				if dials[0] != 0:
					dials[1] = 1
				else:
					status = translate("Сначала отпустите тормоз.", "Release the brake first.")
			2:
				if dials[0] == 1 and dials[1] == 1:
					dials[2] = (dials[2] + 1) % 3
				else:
					status = translate("Для подъёма нужен натянутый канат.", "The lift needs a taut line.")
	update_board(status)
	if not reduced:
		art.modulate = Color("e0b291") if not status.is_empty() else Color("e8f8cf")
		create_tween().tween_property(art, "modulate", Color.WHITE, .2)
	changed.emit(dials.duplicate(), finished or status.is_empty())
	if finished:
		caption.text = translate("Механизм сработал.", "The mechanism engaged.")
		for button in buttons:
			button.disabled = true
		# Leave a readable confirmation before restoring world control.
		if not reduced: await get_tree().create_timer(.28, false).timeout
		solved.emit()
