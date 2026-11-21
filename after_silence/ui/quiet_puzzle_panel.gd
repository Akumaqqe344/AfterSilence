extends Control

signal solved
signal changed
const Tile=preload("res://after_silence/ui/puzzle_tile.gd")
const Puzzle=preload("res://after_silence/core/quiet_puzzle.gd")
const ThemeArt=preload("res://after_silence/ui/comfort_theme.gd")
const Stage=preload("res://after_silence/ui/trial_stage_art.gd")
const Motion=preload("res://after_silence/ui/trial_motion.gd")
const COLORS_RU=["Янтарь","Шалфей","Небо","Сирень","Солнце","Вода"]
const COLORS_EN=["Amber","Sage","Sky","Lilac","Sun","Water"]
const SIDES={
	"tubes":["Выбери пробирку, затем такую же или пустую.","Choose a tube, then a matching or empty one."],
	"pairs":["Соедини одинаковые знаки на открытках.","Pair equal signs on the cards."],
	"seeds":["Выбери семя и грядку с таким знаком. Нажми на росток, чтобы полить.","Pick a seed and its matching plot. Click the sprout to water it."],
	"lights":["Поменяй местами соседние огни. Собери три одинаковых в ряд.","Swap neighboring lights. Make a line of three matching ones."],
	"shelves":["Собери тройки меток для семей на берегу.","Group matching tags in threes for the families."],
}

var game
var model
var tiles: Array[Button]=[]
var selection: Array=[]
var marked: Array=[]
var feedback: Label
var undo_button: Button
var reset_button: Button
var hint_button: Button
var focus_before_pause: Control
var effects: Control

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var instructions=Label.new()
	instructions.position=Vector2(411,12)
	instructions.size=Vector2(149,70)
	instructions.add_theme_font_size_override("font_size",12 if game.comfort.large_text else 11)
	instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	instructions.text=game.t(SIDES[model.mode][0],SIDES[model.mode][1])
	add_child(instructions)
	hint_button=_button(game.t("Подсказка","Hint"),89,_hint)
	undo_button=_button(game.t("Отменить ход","Undo move"),120,_undo)
	reset_button=_button(game.t("С начала","Reset"),151,_reset)
	feedback=Label.new()
	feedback.position=Vector2(20,195)
	feedback.size=Vector2(536,16)
	feedback.add_theme_color_override("font_color",ThemeArt.PEACH)
	feedback.text=""
	add_child(feedback)
	var count: int=Puzzle.SIZES[model.mode]
	var columns=5 if model.mode=="tubes" else 3 if model.mode=="seeds" else 4
	var tile_size=Vector2(64,130) if model.mode=="tubes" else Vector2(92,50)
	var gap=Vector2(8,7)
	var left=roundf((410-(columns*tile_size.x+(columns-1)*gap.x))*.5)
	for i in range(count):
		var tile=Tile.new()
		tile.name="PuzzleTile%d"%i
		tile.kind=model.mode
		tile.position=Vector2(left,23)+Vector2(i%columns,int(i/columns))*(tile_size+gap)
		tile.size=tile_size
		tile.pressed.connect(_pick.bind(i))
		add_child(tile)
		game.ComfortMotion.wire_button(tile,game.comfort)
		tiles.append(tile)
	for i in range(count):
		var tile=tiles[i]
		tile.focus_neighbor_right=tile.get_path_to(tiles[i+1] if i%columns<columns-1 else hint_button)
		if i%columns>0: tile.focus_neighbor_left=tile.get_path_to(tiles[i-1])
		if i>=columns: tile.focus_neighbor_top=tile.get_path_to(tiles[i-columns])
		if i+columns<count: tile.focus_neighbor_bottom=tile.get_path_to(tiles[i+columns])
	hint_button.focus_neighbor_left=hint_button.get_path_to(tiles[columns-1])
	undo_button.focus_neighbor_left=undo_button.get_path_to(tiles[mini(count-1,columns*2-1)])
	reset_button.focus_neighbor_left=reset_button.get_path_to(tiles.back())
	# Board cells come before tools in the tab order.
	var tab_order: Array=tiles.duplicate()
	tab_order.append_array([hint_button,undo_button,reset_button])
	for i in range(tab_order.size()):
		var button: Button=tab_order[i]
		button.focus_next=button.get_path_to(tab_order[(i+1)%tab_order.size()])
		button.focus_previous=button.get_path_to(tab_order[posmod(i-1,tab_order.size())])
	_refresh()
	effects=Motion.new();effects.game=game;add_child(effects)
	focus_board()

func _draw():
	Stage.draw(self,model.mode,401)

func _button(caption: String, y: int, action: Callable) -> Button:
	var button=Button.new()
	button.text=caption
	button.position=Vector2(411,y)
	button.add_theme_font_size_override("font_size",12 if game.comfort.large_text else 11)
	button.pressed.connect(action)
	add_child(button)
	button.size=Vector2(149,26)
	game.ComfortMotion.wire_button(button,game.comfort)
	return button

func focus_board() -> void:
	if is_instance_valid(focus_before_pause):
		focus_before_pause.grab_focus()
	elif not tiles.is_empty():
		tiles[0].grab_focus()

func remember_focus() -> void:
	var focused=get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and is_ancestor_of(focused): focus_before_pause=focused

func _pick(i: int) -> void:
	if model.won() or game.modal: return
	marked=[]
	if i in selection:
		selection.erase(i)
		_refresh()
		return
	if selection.is_empty() and not model.can_start(i): return
	if model.mode=="seeds" and i<3:
		selection=[i]
		feedback.text=game.t("Выбери грядку с таким знаком.","Choose a plot with this sign.")
		_refresh()
		return
	if model.mode=="seeds" and model.board[i] in [0,1,2]:
		selection=[]
	_accept(selection+[i])

func _accept(next: Array) -> void:
	if next.size()<model.steps(selection):
		selection=next
		_refresh()
		return
	selection=[]
	var accepted: bool=model.submit(next)
	if accepted:
		game.audio.ping(game.state.volume)
		feedback.text=game.t("Получилось.","That worked.")
		if not game.comfort.reduce_motion:
			var color=Stage.accent(model.mode).lightened(.28)
			for i in next:
				effects.burst(tiles[i].position+tiles[i].size*.5,color)
				tiles[i].animate_change()
			if model.mode=="tubes":
				effects.transfer(tiles[next[0]].get_rect().get_center(),tiles[next[1]].get_rect().get_center(),color)
	else:
		feedback.text=game.t("Попробуй другой ход.","Try another move.")
	_refresh()
	if model.won(): solved.emit()
	elif accepted: changed.emit()

func _hint() -> void:
	if game.modal: return
	selection=[]
	marked=model.hint()
	feedback.text=game.t("Выбери подсвеченные знаки.","Choose the highlighted signs.")
	if marked.is_empty():
		feedback.text=game.t("Отмени ход или начни заново.","Undo a move or start again.")
	elif model.mode=="tubes":
		feedback.text=game.t("Пробирка %d → %d","Tube %d → %d")%[marked[0]+1,marked[1]+1]
	elif model.mode=="seeds" and marked.size()==1:
		feedback.text=game.t("Нажми на росток, чтобы полить.","Click the sprout to water it.")
	_refresh()

func _undo() -> void:
	if game.modal: return
	model.undo()
	selection=[]
	marked=[]
	feedback.text=game.t("Ход отменён.","Move undone.")
	_refresh()
	changed.emit()

func _reset() -> void:
	if game.modal: return
	model.reset()
	selection=[]
	marked=[]
	feedback.text=game.t("Можно начать снова.","Ready for a fresh start.")
	_refresh()
	changed.emit()

func _refresh() -> void:
	for i in range(tiles.size()):
		var tile=tiles[i]
		tile.tone=model.color_at(i)
		tile.picked=i in selection
		tile.suggested=i in marked
		if model.mode=="tubes":
			tile.stack=model.board[i]
			tile.text=str(i+1)
			tile.alignment=HORIZONTAL_ALIGNMENT_LEFT
		elif model.mode=="seeds":
			tile.stage=-1 if i<3 else 0 if model.board[i]==-1 else 1 if model.board[i]<3 else 2
			if tile.stage==0: tile.tone=Puzzle.SEEDS[i-3]
		var tone: int=tile.tone
		tile.tooltip_text=game.t(COLORS_RU[tone],COLORS_EN[tone]) if tone>=0 else game.t("Пусто","Empty")
		tile.queue_redraw()
	undo_button.disabled=model.history.is_empty()
	reset_button.disabled=model.history.is_empty()
