extends Control

const PORTRAIT=preload("res://after_silence/assets/pechatai/player/idle.png")
const GRASS=preload("res://after_silence/assets/art100/grass.png")
const DIRT=preload("res://after_silence/assets/art100/dirt.png")
const WATER=preload("res://after_silence/assets/art100/water.png")
const FLOOR=preload("res://after_silence/assets/art100/floor.png")
const LEV=preload("res://after_silence/assets/pechatai/npc/inventor.png")
const NADIA=preload("res://after_silence/assets/pechatai/npc/lora.png")
const SONYA=preload("res://after_silence/assets/pechatai/npc/ella.png")
const Catalog=preload("res://after_silence/core/quest_catalog.gd")
const ARENA=Rect2(64,111,512,207)
const Guardian=preload("res://after_silence/world/pixel_guardian.gd")
static var STOPS: Array=Catalog.points()
static var SHORT: Array=Catalog.summaries()
var easy_mode=true
var board: Array=[]
var picked: Array=[]
var matched: Array=[]
var reveal_time=0.0
var click_target=Vector2.ZERO
static var QUESTS: Array=Catalog.data.quests

static var OUTCOMES: Dictionary=Catalog.data.outcomes

var game
var active=false
var index=0
var phase="intro"
var before_pause="intro"
var title_label: Label
var brief_label: Label
var status_label: Label
var actions: VBoxContainer
var player_pos=Vector2(92,215)
var escort_pos=Vector2(118,255)
var rescued=0
var switch_round=0
var elapsed=0.0
var remaining=0.0
var health=3
var invulnerable=0.0
var dodge_cooldown=0.0
var beat=0
var beat_age=0.0
var mask=0
var wave=0
var lane=1
var guard_age=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	set_process_input(true)
	title_label=Label.new()
	title_label.position=Vector2(65,32)
	title_label.size=Vector2(520,28)
	title_label.add_theme_font_size_override("font_size",18)
	add_child(title_label)
	brief_label=Label.new()
	brief_label.position=Vector2(66,70)
	brief_label.size=Vector2(510,88)
	brief_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	brief_label.add_theme_font_size_override("font_size",13)
	add_child(brief_label)
	status_label=Label.new()
	status_label.position=Vector2(65,327)
	status_label.size=Vector2(520,24)
	status_label.add_theme_font_size_override("font_size",12)
	add_child(status_label)
	actions=VBoxContainer.new()
	actions.position=Vector2(66,183)
	actions.size=Vector2(510,136)
	actions.add_theme_constant_override("separation",4)
	add_child(actions)
	visible=false

func pair(value: Array) -> String:
	return value[1] if game.state.language=="en" else value[0]

func start(owner) -> void:
	game=owner
	active=true
	visible=true
	index=0
	while index<QUESTS.size() and game.state.flag("rift_q%02d_done"%(index+1)): index+=1
	if index>=QUESTS.size(): finish();return
	if preload("res://after_silence/core/minigame_checkpoint.gd").apply(self,game.state.minigame): return
	if index>0: begin_travel()
	else: show_intro()

func play_mode() -> String:
	return QUESTS[index].mode

func begin_travel():
	active=false
	visible=false
	phase="travel"
	game._close()
	game._build_world("town",Vector2(600,600) if index==1 else STOPS[index-1]+Vector2(0,36))
	game.objective.text=game.t("Иди к огоньку • E: ","Follow the light • E: ")+pair(QUESTS[index].title)
	game._save(false)

func arrive():
	active=true
	visible=true
	show_intro()

func clear_actions() -> void:
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()

func add_action(label: String, callback: Callable, available: bool=true) -> void:
	var button=Button.new()
	button.text=label
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size=Vector2(480,32)
	button.add_theme_font_size_override("font_size",13)
	button.disabled=not available
	button.pressed.connect(callback)
	actions.add_child(button)
	if available and actions.get_child_count()==1: call_deferred("focus_first_action")

func focus_first_action() -> void:
	for button in actions.get_children():
		if not button.disabled and button.is_visible_in_tree():
			button.grab_focus()
			return

func show_intro() -> void:
	phase="intro"
	clear_actions()
	var quest=QUESTS[index]
	title_label.text="%02d / 12  %s"%[index+1,pair(quest.title)]
	brief_label.text=SHORT[index] if game.state.language=="ru" else pair(quest.brief).split(". ")[0]+"."
	status_label.text="ESC · ПАУЗА" if game.state.language=="ru" else "ESC · PAUSE"
	if index>0:
		for previous in QUESTS[index-1].choices:
			if game.state.flag("rift_choice_%02d_%s"%[index,previous[0]]):
				status_label.text=pair(OUTCOMES["%02d_%s"%[index,previous[0]]])
				break
	add_action("▶  НАЧАТЬ СОБЫТИЕ" if game.state.language=="ru" else "▶  START EVENT",start_play)
	queue_redraw()

func start_play() -> void:
	game.state.minigame.clear()
	game.living.focus("boss" if play_mode()=="defense" else "memory")
	phase="play"
	clear_actions()
	elapsed=0
	remaining=24.0 if index==11 else 20.0 if index==0 else 16.0
	health=3
	invulnerable=0
	dodge_cooldown=0
	player_pos=Vector2(92,215)
	escort_pos=Vector2(118,255)
	rescued=0
	switch_round=0
	beat=0
	beat_age=0
	mask=0
	board=[1,2,3,4,1,2,3,4] if play_mode()=="memory" else [1,3,2,1] if play_mode()=="circuit" else [0,0,0,0,0,0]
	picked.clear()
	matched.clear()
	reveal_time=0.0
	click_target=Vector2.ZERO
	wave=0
	lane=1
	guard_age=0
	brief_label.text=""
	status_label.text=instruction()
	queue_redraw()

func instruction() -> String:
	match play_mode():
		"memory": return "Найди одинаковые картинки • мышь или 1–8" if game.state.language=="ru" else "MATCH PAIRS • CLICK OR 1–8"
		"circuit": return "Поверни провода в одну линию • мышь или 1–4" if game.state.language=="ru" else "ROTATE WIRES INTO A LINE • CLICK OR 1–4"
		"herbs": return "Собери зелёные листья • мышь или 1–6" if game.state.language=="ru" else "PICK GREEN LEAVES • CLICK OR 1–6"
		"route": return "WASD · ПУТЬ   ПРОБЕЛ · УКЛОНЕНИЕ" if game.state.language=="ru" else "WASD · MOVE   SPACE · DODGE"
		"rhythm": return "НАЖИМАЙ ПОКАЗАННУЮ КЛАВИШУ В РИТМЕ" if game.state.language=="ru" else "PRESS THE SHOWN KEY ON THE BEAT"
		"switch": return "1–4 · ПЕРЕКЛЮЧИТЬ   E · ПРОВЕРИТЬ" if game.state.language=="ru" else "1–4 · TOGGLE   E · CONFIRM"
		_: return "W/S · ПОЛОСА   ПРОБЕЛ · ЗАЩИТА" if game.state.language=="ru" else "W/S · LANE   SPACE · GUARD"

func rhythm_duration() -> float:
	return {1:1.15,5:1.55,7:1.05}.get(index,1.45)

func rhythm_key() -> int:
	var patterns={1:[KEY_W,KEY_D,KEY_A,KEY_S,KEY_D,KEY_W,KEY_S,KEY_A],5:[KEY_W,KEY_W,KEY_A,KEY_S,KEY_S,KEY_D,KEY_A,KEY_D],7:[KEY_A,KEY_D,KEY_W,KEY_S,KEY_D,KEY_A,KEY_S,KEY_W]}
	return patterns.get(index,[KEY_W,KEY_A,KEY_S,KEY_D,KEY_W,KEY_A,KEY_S,KEY_D])[mini(beat,7)]

func _input(event: InputEvent) -> void:
	if active and phase=="play" and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var point=get_local_mouse_position()
		if ARENA.has_point(point):
			match play_mode():
				"memory","circuit","herbs":
					for cell in range(board.size()):
						if cell_rect(cell).has_point(point): board_input(cell);break
				"route": click_target=point
				"rhythm": rhythm_input(rhythm_key())
				"defense": lane=clampi(int((point.y-139)/56),0,2);guard_age=1.8
				"switch":
					for bit in range(4):
						if Rect2(109+bit*113,172,76,76).has_point(point): mask^=1<<bit
					if mask==switch_target():
						switch_round+=1;mask=0
						if switch_round>=switch_targets().size(): succeed()
			get_viewport().set_input_as_handled()
		return
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode==KEY_ESCAPE:
		if phase=="pause": phase=before_pause;show_phase()
		else: before_pause=phase;phase="pause";show_pause()
		get_viewport().set_input_as_handled()
		return
	if phase=="intro" and event.physical_keycode==KEY_E:
		start_play()
		get_viewport().set_input_as_handled()
	elif phase=="play":
		match play_mode():
			"memory","circuit","herbs":
				if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_8: board_input(int(event.physical_keycode-KEY_1))
			"route":
				if event.physical_keycode==KEY_SPACE and dodge_cooldown<=0: invulnerable=.45;dodge_cooldown=1.2
			"rhythm": rhythm_input(event.physical_keycode)
			"switch":
				if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_4: mask^=1<<int(event.physical_keycode-KEY_1)
				elif event.physical_keycode==KEY_E:
					if mask==switch_target():
						switch_round+=1
						mask=0
						if switch_round>=switch_targets().size(): succeed()
					else: damage()
			"defense":
				if event.physical_keycode==KEY_W or event.physical_keycode==KEY_UP: lane=maxi(0,lane-1)
				elif event.physical_keycode==KEY_S or event.physical_keycode==KEY_DOWN: lane=mini(2,lane+1)
				elif event.physical_keycode==KEY_SPACE: guard_age=.52
		get_viewport().set_input_as_handled()
		queue_redraw()

func show_phase() -> void:
	if phase=="intro": show_intro()
	elif phase=="play": clear_actions();brief_label.text="";status_label.text=instruction()
	elif phase=="decision": show_decision()
	else: show_intro()

func show_pause() -> void:
	clear_actions()
	brief_label.text="Пауза. При выходе сохранится и эта мини-игра." if game.state.language=="ru" else "Paused. This minigame is saved when you leave."
	status_label.text=""
	add_action("ПРОДОЛЖИТЬ" if game.state.language=="ru" else "CONTINUE",func():phase=before_pause;show_phase())
	add_action("В ГЛАВНОЕ МЕНЮ" if game.state.language=="ru" else "MAIN MENU",func():game._save(false);active=false;visible=false;game._main_menu())
	queue_redraw()

func _physics_process(dt: float) -> void:
	if not active or phase!="play": return
	dt=minf(dt,.05)
	elapsed+=dt
	if not easy_mode: remaining-=dt
	invulnerable=maxf(0,invulnerable-dt)
	dodge_cooldown=maxf(0,dodge_cooldown-dt)
	guard_age=maxf(0,guard_age-dt)
	if reveal_time>0:
		reveal_time-=dt
		if reveal_time<=0: picked.clear()
	match play_mode():
		"route": update_route(dt)
		"rhythm":
			beat_age+=dt
			if beat_age>=rhythm_duration():
				beat_age=0;damage()
				if not easy_mode: beat+=1
			if beat>=8: succeed()
		"switch": pass
		"defense": update_defense(dt)
	if remaining<=0 and phase=="play": fail()
	queue_redraw()

func update_route(dt: float) -> void:
	var motion=Input.get_vector("as_left","as_right","as_up","as_down")
	if motion!=Vector2.ZERO: click_target=Vector2.ZERO
	if click_target!=Vector2.ZERO: player_pos=player_pos.move_toward(click_target,167.0*dt)
	else: player_pos+=motion*167.0*dt
	player_pos=player_pos.clamp(ARENA.position+Vector2(14,16),ARENA.end-Vector2(14,16))
	if index==0:
		escort_pos=escort_pos.move_toward(player_pos,120.0*dt)
	if index==6:
		for gate in range(3):
			var x=220+gate*112
			var safe_y=[165.0,260.0,188.0][gate]
			if player_pos.x>x and player_pos.x<x+16 and absf(player_pos.y-safe_y)>30:
				player_pos.x=x-17
				if invulnerable<=0:
					damage()
					invulnerable=.8
	if index==11:
		for person in range(3):
			var location=Vector2(190+person*130,165 if person%2==0 else 265)
			if rescued&(1<<person)==0 and player_pos.distance_to(location)<38: rescued|=1<<person
	for i in range(3):
		var hazard=Vector2(190+i*116,210+sin(elapsed*(2.1+i*.34)+i*2.2)*72)
		if player_pos.distance_to(hazard)<23 and invulnerable<=0:
			damage()
			invulnerable=.8
	if player_pos.x>=ARENA.end.x-23 and (index!=0 or escort_pos.x>=ARENA.end.x-70) and (index!=11 or rescued==7): succeed()

func rhythm_input(code: int) -> void:
	var keys=[KEY_W,KEY_A,KEY_S,KEY_D]
	if code not in keys or (not easy_mode and beat_age<rhythm_duration()*.38): return
	if code==rhythm_key():
		beat+=1
		if beat>=8: succeed();return
	else: damage()
	beat_age=0

func switch_targets() -> Array:
	return {2:[10,5],3:[5,10],8:[9,6,3]}.get(index,[10])

func switch_target() -> int:
	return switch_targets()[mini(switch_round,switch_targets().size()-1)]

func update_defense(dt: float) -> void:
	beat_age+=dt
	if beat_age<1.45: return
	beat_age=0
	if lane!=incoming_lane() or guard_age<=0:
		damage()
		if easy_mode: return
	wave+=1
	if wave>=defense_waves(): succeed()

func defense_waves() -> int:
	return {4:6,9:8,10:7}.get(index,6)

func incoming_lane() -> int:
	var patterns={4:[1,0,2,1,2,0],9:[0,2,1,0,1,2,0,2],10:[2,1,0,2,0,1,2]}
	var pattern=patterns.get(index,[1,0,2,1,2,0])
	return pattern[mini(wave,pattern.size()-1)]

func damage() -> void:
	health-=1
	if easy_mode:
		health=maxi(1,health)
		return
	if health<=0: fail()

func cell_rect(cell: int) -> Rect2:
	var columns=4 if play_mode()!="herbs" else 3
	var width=100 if columns==4 else 130
	return Rect2(100+(cell%columns)*width,140+int(cell/columns)*80,width-12,68)

func board_input(cell: int):
	if phase!="play" or cell<0 or cell>=board.size(): return
	match play_mode():
		"memory":
			if reveal_time>0 or cell in matched or cell in picked: return
			picked.append(cell)
			if picked.size()==2:
				if board[picked[0]]==board[picked[1]]:
					matched.append_array(picked);picked.clear()
					if matched.size()==8: succeed()
				else: reveal_time=1.0
		"circuit":
			board[cell]=(board[cell]+1)%4
			if board.all(func(turn): return turn%2==0): succeed()
		"herbs":
			if cell%2==0: board[cell]=1
			if board[0]+board[2]+board[4]==3: succeed()
	game.audio.ping(game.state.volume)
	queue_redraw()

func draw_board():
	var font=get_theme_default_font()
	for cell in range(board.size()):
		var rect=cell_rect(cell)
		draw_rect(rect,Color("354b4a"))
		draw_rect(rect,Color("9bb59b"),false,2)
		var center=rect.get_center()
		draw_string(font,rect.position+Vector2(5,13),str(cell+1),HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("f0dbaa"))
		if play_mode()=="memory":
			if cell not in picked and cell not in matched:
				draw_rect(Rect2(center-Vector2(15,15),Vector2(30,30)),Color("6c8582"))
			else:
				var portraits=[LEV,NADIA,SONYA,PORTRAIT]
				draw_texture_rect_region(portraits[board[cell]-1],Rect2(center-Vector2(22,25),Vector2(44,50)),Rect2(0,0,64,64))
		elif play_mode()=="circuit":
			var horizontal=board[cell]%2==0
			draw_rect(Rect2(center-Vector2(32,5) if horizontal else center-Vector2(5,23),Vector2(64,10) if horizontal else Vector2(10,46)),Color("d9ac73"))
			draw_rect(Rect2(center-Vector2(5,5),Vector2(10,10)),Color("f4d897"))
		else:
			if board[cell]==0:
				var color=Color("a2cf79") if cell%2==0 else Color("b986a7")
				draw_rect(Rect2(center+Vector2(-2,0),Vector2(4,22)),Color("9b815a"))
				for offset in [Vector2(-17,-10),Vector2(1,-18),Vector2(-13,4)]: draw_rect(Rect2(center+offset,Vector2(17,12)),color)
			else: draw_string(font,center+Vector2(-8,5),"OK",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("bce3ac"))

func fail() -> void:
	phase="fail"
	clear_actions()
	brief_label.text="Разлом отбросил Веру. Попробуй ещё раз: рисунок опасности повторяется." if game.state.language=="ru" else "The rift pushed Vera back. Try again: the danger follows a pattern."
	status_label.text=""
	add_action("ПОВТОРИТЬ" if game.state.language=="ru" else "RETRY",start_play)
	queue_redraw()

func succeed() -> void:
	if phase!="play": return
	phase="decision"
	show_decision()

func support() -> int:
	var score=0
	for quest_index in range(QUESTS.size()):
		var quest=QUESTS[quest_index]
		for option in quest.choices:
			if game.state.flag("rift_choice_%02d_%s"%[quest_index+1,option[0]]): score+=maxi(0,option[4])
	return score

func available(id: String) -> bool:
	if easy_mode and index in [9,10]: return true
	if index==9 and id=="truce": return health==3
	if index==10 and id=="trust": return health==3
	if index!=11: return true
	if id=="child": return game.state.flag("rift_choice_11_trust") and support()>=5
	if id=="both": return game.state.flag("rift_choice_04_limit") and support()>=4
	return true

func show_decision() -> void:
	phase="decision"
	clear_actions()
	brief_label.text="Город изменился. Выбери, что Вера сохранит после этого события." if game.state.language=="ru" else "Town has changed. Choose what Vera will preserve from this event."
	status_label.text=""
	for option in QUESTS[index].choices:
		var can_choose=available(option[0])
		var label=option[2] if game.state.language=="en" else option[1]
		add_action(label if can_choose else label+"  [◇]",func():choose(option),can_choose)
	queue_redraw()

func choose(option: Array) -> void:
	if phase!="decision" or index>=QUESTS.size(): return
	if option not in QUESTS[index].choices or game.state.flag("rift_q%02d_done"%(index+1)): return
	game.living.restore_camera()
	if not available(option[0]): return
	game.state.set_flag("rift_choice_%02d_%s"%[index+1,option[0]])
	game.state.set_flag("rift_q%02d_done"%(index+1))
	game.state.tokens=mini(999,game.state.tokens+1)
	if option[3] in game.state.relations: game.npcs.change_relation(option[3],int(option[4]))
	index+=1
	if index>=QUESTS.size():
		game.state.set_flag("rift_final_"+option[0])
		finish()
	else:
		game._save(false)
		begin_travel()

func finish() -> void:
	active=false
	visible=false
	game.state.set_flag("rift_finished")
	game.state.echo=game.state.flag("rift_final_both") or game.state.flag("rift_final_child")
	game._build_world("town",Vector2(600,600))
	game._save(false)
	game._dialog("rift_epilogue",game.t("После разлома","After the rift"),epilogue(),[game.choice("close","Вернуться в город","Return to town",game._close)],false)

func epilogue() -> String:
	var result="Город помнит разные версии одного дня. " if game.state.language=="ru" else "Town remembers different versions of the same day. "
	if game.state.flag("rift_choice_01_warn"): result+="Семья у почты выжила. " if game.state.language=="ru" else "The family by the post office survived. "
	if game.state.flag("rift_choice_11_trust"): result+="Алина больше не держит разлом одна. " if game.state.language=="ru" else "Alina no longer holds the rift alone. "
	result+=("Вера закрыла проход." if game.state.language=="ru" else "Vera sealed the passage.") if game.state.flag("rift_final_close") else ("Обе эпохи остались рядом." if game.state.language=="ru" else "Both eras remain together.") if game.state.flag("rift_final_both") else ("Алина научилась удерживать проход." if game.state.language=="ru" else "Alina learned to hold the passage.") if game.state.flag("rift_final_child") else ("Они изменили день бедствия." if game.state.language=="ru" else "They changed the disaster day.")
	return result

func _draw() -> void:
	if not active: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("292d38fa"))
	draw_style_box(game.ComfortTheme.panel(),Rect2(17,17,size.x-34,size.y-34))
	draw_rect(Rect2(32,18,60,2),game.ComfortTheme.SAGE)
	if phase!="play": return
	draw_rect(ARENA,Color("10242a"))
	match play_mode():
		"memory","circuit","herbs": draw_texture_rect(FLOOR,ARENA,true,Color("697e80"))
		"route":
			draw_texture_rect(GRASS,ARENA,true,Color("9caea7"))
			draw_texture_rect(DIRT,Rect2(ARENA.position.x,ARENA.position.y+69,ARENA.size.x,72),true,Color("8a9a94"))
			if index==11: draw_texture_rect(WATER,Rect2(ARENA.position.x,ARENA.end.y-37,ARENA.size.x,37),true,Color("829ca9"))
		"switch": draw_texture_rect(FLOOR if index!=8 else DIRT,ARENA,true,Color("697e80"))
		"rhythm": draw_texture_rect(FLOOR if index==5 else DIRT if index==7 else GRASS,ARENA,true,Color("718c91"))
		"defense": draw_texture_rect(WATER if index==4 else GRASS if index==10 else DIRT,ARENA,true,Color("71888b"))
	draw_rect(ARENA,Color("07151bbb"))
	draw_rect(ARENA,Color("488e88"),false,2)
	var font=get_theme_default_font()
	var accent=Color("9adad0")
	if play_mode() in ["memory","circuit","herbs"]: draw_board()
	draw_string(font,Vector2(67,95),"%02d / 12   ♥ %d   %02d"%[index+1,health,maxi(0,ceili(remaining))],HORIZONTAL_ALIGNMENT_LEFT,-1,8,accent)
	match play_mode():
		"route":
			if index==6:
				for gate in range(3):
					var x=220+gate*112
					var safe_y=[165.0,260.0,188.0][gate]
					draw_rect(Rect2(x,ARENA.position.y,12,safe_y-30-ARENA.position.y),Color("ae7184"))
					draw_rect(Rect2(x,safe_y+30,12,ARENA.end.y-safe_y-30),Color("ae7184"))
			if index==11:
				for person in range(3):
					var location=Vector2(190+person*130,165 if person%2==0 else 265)
					if rescued&(1<<person)==0:
						draw_rect(Rect2(location-Vector2(21,20),Vector2(42,43)),Color("e5dba3"),false,2)
						draw_texture_rect_region([NADIA,LEV,SONYA][person],Rect2(location-Vector2(17,25),Vector2(34,38)),Rect2(0,0,64,64))
			for i in range(3):
				var hazard=Vector2(190+i*116,210+sin(elapsed*(2.1+i*.34)+i*2.2)*72)
				draw_rect(Rect2(hazard-Vector2(20,20),Vector2(40,40)),Color("e5aaa6"),false,2)
				draw_rect(Rect2(hazard-Vector2(13,13),Vector2(26,26)),Color("ad577c"))
				draw_rect(Rect2(hazard-Vector2(5,5),Vector2(10,10)),Color("f6c8a7"))
			draw_rect(Rect2(ARENA.end.x-25,ARENA.position.y+9,9,ARENA.size.y-18),Color("82d4aa"))
			if index==0: draw_texture_rect_region(LEV,Rect2(escort_pos-Vector2(18,28),Vector2(36,42)),Rect2(0,0,64,64))
			draw_texture_rect_region(PORTRAIT,Rect2(player_pos-Vector2(19,28),Vector2(38,42)),Rect2(4,2,56,61),Color.WHITE if invulnerable<=0 else Color("7ce4e0"))
			if index==11: draw_string(font,Vector2(464,162),"%d / 3"%[int(bool(rescued&1))+int(bool(rescued&2))+int(bool(rescued&4))],HORIZONTAL_ALIGNMENT_LEFT,-1,9,accent)
		"rhythm":
			if index==1:
				for rain in range(12):
					var x=96+rain*40
					draw_line(Vector2(x,120),Vector2(x-5,136),Color("7bbdbb96"),1)
			if index==5:
				draw_texture_rect_region(NADIA,Rect2(105,195,47,65),Rect2(0,0,64,64))
				draw_texture_rect_region(SONYA,Rect2(472,204,39,54),Rect2(0,0,64,64))
			if index==7:
				for person in range(4): draw_texture_rect_region([LEV,NADIA,SONYA,LEV][person],Rect2(110+person*132,250,30,43),Rect2(0,0,64,64),Color("a9c4b7"))
			var keys=["W","A","S","D"]
			var letter=keys[[KEY_W,KEY_A,KEY_S,KEY_D].find(rhythm_key())]
			draw_string(font,Vector2(284,230),letter,HORIZONTAL_ALIGNMENT_LEFT,-1,55,Color("f7dfab"))
			draw_rect(Rect2(105,282,430,8),Color("2f5053"))
			draw_rect(Rect2(105,282,430*minf(1,beat_age/rhythm_duration()),8),Color("8ccfbd"))
			draw_rect(Rect2(105+430*.38,279,2,14),Color("f7dfab"))
			draw_string(font,Vector2(105,162),"%d / 8"%beat,HORIZONTAL_ALIGNMENT_LEFT,-1,11,accent)
		"switch":
			draw_string(font,Vector2(110,156),"%d / %d"%[switch_round+1,switch_targets().size()],HORIZONTAL_ALIGNMENT_LEFT,-1,9,accent)
			if index==8:
				for rail in [281.0,293.0]: draw_line(Vector2(100,rail),Vector2(530,rail),Color("b9baa1"),3)
			for i in range(4):
				var x=109+i*113
				var on=mask&(1<<i)!=0
				var wanted=switch_target()&(1<<i)!=0
				draw_rect(Rect2(x,172,76,76),Color("5ac0ac") if on else Color("29464d"))
				draw_rect(Rect2(x,172,76,76),Color("bedbd1"),false,2)
				if index==2:
					draw_rect(Rect2(x+14,181,47,58),Color("d1b7a0"),false,2)
					draw_rect(Rect2(x+52,211,5,5),Color("e7d58b"))
				elif index==3:
					draw_line(Vector2(x+4,241),Vector2(x+72,177),Color("e4ba87"),3)
				elif index==8:
					draw_rect(Rect2(x+6,178,64,53),Color("d9c5a3"),false,2)
				draw_string(font,Vector2(x+28,219),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("071015"))
				draw_circle(Vector2(x+38,274),5,Color("b5e39d") if wanted else Color("b86f85"))
		"defense":
			if index==10: draw_texture_rect_region(SONYA,Rect2(304,117,31,35),Rect2(0,0,64,64),Color("c0d9cf"))
			for i in range(3):
				var y=139+i*56
				draw_rect(Rect2(86,y,468,45),Color("42505b") if i==incoming_lane() else Color("193238"))
				draw_rect(Rect2(86,y,468,45),Color("597c7a"),false,1)
				if i==lane: draw_circle(Vector2(145,y+22),15,Color("b7e2c9") if guard_age>0 else Color("84b5aa"))
				if i==incoming_lane(): draw_circle(Vector2(495-330*minf(1,beat_age/1.45),y+22),12,Color("d88595"))
			draw_string(font,Vector2(405,99),"%d / %d"%[wave,defense_waves()],HORIZONTAL_ALIGNMENT_LEFT,-1,8,accent)
			Guardian.paint(self,Vector2(512,157),0 if index==4 else 1 if index==9 else 2,guard_age>0)
