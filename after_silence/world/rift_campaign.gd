extends Control

const PORTRAIT=preload("res://after_silence/assets/pechatai/player/idle.png")
const GRASS=preload("res://after_silence/assets/pechatai/world/grass.png")
const DIRT=preload("res://after_silence/assets/pechatai/world/dirt.png")
const WATER=preload("res://after_silence/assets/pechatai/world/water.png")
const FLOOR=preload("res://after_silence/assets/pechatai/interior/floor.png")
const LEV=preload("res://after_silence/assets/pechatai/npc/inventor.png")
const NADIA=preload("res://after_silence/assets/pechatai/npc/lora.png")
const SONYA=preload("res://after_silence/assets/pechatai/npc/ella.png")
const ARENA=Rect2(64,111,512,207)
const QUESTS=[
	{"title":["Письмо из завтрашнего дня","A letter from tomorrow"],"brief":["Лев получил письмо от себя: к вечеру он исчезнет. Проведи его к почте сквозь меняющиеся улицы.","Lev received a letter from himself: he will vanish tonight. Escort him to the post office through shifting streets."],"mode":"route","choices":[["warn","Предупредить соседей","Warn the neighbors","nadia",1],["mail","Доставить письмо","Deliver the letter","lev",1]]},
	{"title":["Праздник под дождём","Festival in the rain"],"brief":["Площадь помнит праздник, которого никто не видит. Войди в ритм и найди того, кто знает о бедствии.","The square remembers a festival nobody can see. Follow its rhythm and find the guest who knows about the disaster."],"mode":"rhythm","choices":[["public","Остановить гостя при всех","Confront the guest in public","pavel",-1],["quiet","Поговорить наедине","Speak in private","sonya",1],["follow","Проследить за ним","Follow the guest","mara",1]]},
	{"title":["Ночь без дверей","A night without doors"],"brief":["Комнаты меняют эпоху. Включай нужные проходы, пока дом не исчез.","Rooms shift between eras. Open the right passages before the house disappears."],"mode":"switch","choices":[["open","Оставить проход семье","Keep the passage open","sonya",1],["close","Закрыть разлом ради дома","Seal the rift to save the house","nadia",1]]},
	{"title":["Два Льва","Two versions of Lev"],"brief":["Молодой и старый Лев спорят у механизма. Стабилизируй контуры, пока искры не дошли до улицы.","Young and old Lev disagree over the device. Stabilize its circuits before sparks reach the street."],"mode":"switch","choices":[["young","Поддержать молодого","Back the younger Lev","lev",-1],["old","Поддержать старшего","Back the older Lev","pavel",1],["limit","Ограничить мощность","Limit the device's power","lev",2]]},
	{"title":["Человек на мосту","The man on the bridge"],"brief":["Павел держит мост закрытым. Отрази ночные атаки вместе с ним, затем реши судьбу переправы.","Pavel keeps the bridge closed. Defend it together, then decide who controls the crossing."],"mode":"defense","choices":[["open","Открыть мост","Open the bridge","nadia",1],["guard","Оставить общую охрану","Keep a joint watch","lev",1]]},
	{"title":["Мама вернулась","Mother returned"],"brief":["Мальчик перестал узнавать мать после разлома. Повтори знакомый ему ритм воспоминаний.","A boy no longer knows his mother after the rift. Repeat the rhythm of the memories he trusts."],"mode":"rhythm","choices":[["restore","Вернуть доверие матери","Rebuild trust with his mother","nadia",1],["farewell","Дать прошлому попрощаться","Let the past say goodbye","sonya",1],["both","Оставить обеих пока рядом","Keep both here for now","mara",-1]]},
	{"title":["Завтрашний сын","Tomorrow's son"],"brief":["Надя встретила взрослого сына из будущего. Проведи его через сад, пока дорожки меняются.","Nadia met her future son. Guide him across the garden while its paths change."],"mode":"route","choices":[["truth","Сказать Наде правду","Tell Nadia the truth","nadia",1],["meeting","Устроить им встречу","Let them meet","sonya",1],["silence","Сохранить его выбор","Respect his choice","mara",1]]},
	{"title":["Суд над врачом","The healer's trial"],"brief":["Толпа обвиняет Надю. Успокой площадь раньше, чем разлом ответит на крики.","The crowd blames Nadia. Calm the square before the rift answers their shouting."],"mode":"rhythm","choices":[["defend","Остаться с Надей","Stand beside Nadia","nadia",2],["evacuate","Вывести её из толпы","Lead her away","sonya",1],["young","Выслушать молодую Надю","Hear the younger Nadia","mara",1]]},
	{"title":["Поезд без рельсов","The train without tracks"],"brief":["Вагоны принадлежат разным годам. Переключи пути, чтобы люди добрались до безопасного вагона.","The carriages belong to different years. Set the switches so passengers reach the safe carriage."],"mode":"switch","choices":[["present","Вернуть людей в настоящее","Bring everyone to the present","nadia",1],["past","Дать доехать до прошлого","Let them reach the past","mara",1]]},
	{"title":["Осада собственного города","Siege of our own town"],"brief":["Две версии города приняли друг друга за врагов. Защити улицы и останови удары до первой потери.","Two versions of town mistake each other for enemies. Hold the streets and stop the blows before anyone is lost."],"mode":"defense","choices":[["truce","Развести стороны без боя","Separate both sides","sonya",2],["houses","Удержать жилые дома","Defend the homes","nadia",1]]},
	{"title":["Ребёнок в разломе","The child inside the rift"],"brief":["В центре разлома — юная Алина. Её страх меняет улицы. Выдержи всплески, не нападая на неё.","Young Alina is inside the rift. Her fear reshapes the streets. Endure the surges without attacking her."],"mode":"defense","choices":[["trust","Завоевать доверие Алины","Earn Alina's trust","sonya",2],["fight","Подавить разлом силой","Suppress the rift by force","pavel",-1],["bring","Позвать близкого человека","Bring someone she knows","nadia",1]]},
	{"title":["Последний день берега","The shore's last day"],"brief":["Обе эпохи сходятся на площади. Проведи жителей к укрытию и реши, каким станет город.","Both eras converge on the square. Lead the residents to safety and decide what town becomes."],"mode":"route","choices":[["close","Закрыть разлом","Seal the rift","nadia",0],["both","Оставить обе эпохи","Keep both eras","mara",0],["child","Доверить разлом Алине","Trust Alina with the rift","sonya",0],["return","Вернуться ко дню бедствия","Return to the disaster day","lev",0]]}
]

const OUTCOMES={
	"01_warn":["Соседи укрылись до исчезновения улицы.","Neighbors found shelter before the street vanished."],
	"01_mail":["Письмо дошло; Лев знает время исчезновения.","The letter arrived; Lev knows when he vanishes."],
	"02_public":["Толпа запомнила лицо гостя, но он скрылся.","The crowd saw the guest's face, but he escaped."],
	"02_quiet":["Гость рассказал Соне о следующем разломе.","The guest told Sonya about the next rift."],
	"02_follow":["Мара нашла путь, которым уходил гость.","Mara found the guest's escape route."],
	"03_open":["Семья может встретиться через проход.","The family can meet across the passage."],
	"03_close":["Дом перестал менять комнаты местами.","The house stopped shifting its rooms."],
	"04_young":["Молодой Лев ускорил машину, рискуя улицей.","Young Lev sped up the machine, risking the street."],
	"04_old":["Старший Лев погасил опасный контур.","Older Lev shut down the dangerous circuit."],
	"04_limit":["Лев оставил разлому только безопасную мощность.","Lev limited the rift to safe power."],
	"05_open":["Жители снова переходят мост.","Residents cross the bridge again."],
	"05_guard":["Ночная охрана моста стала общей.","The night watch at the bridge is shared."],
	"06_restore":["Мальчик снова узнал голос матери.","The boy recognized his mother's voice again."],
	"06_farewell":["Мать из прошлого успела попрощаться.","The mother from the past said goodbye."],
	"06_both":["Обе матери остались; семье нужно время.","Both mothers stayed; the family needs time."],
	"07_truth":["Надя знает, кем станет её сын.","Nadia knows who her son will become."],
	"07_meeting":["Надя и сын встретились без свидетелей.","Nadia and her son met in private."],
	"07_silence":["Сын сохранил право рассказать всё сам.","Her son kept the right to speak for himself."],
	"08_defend":["Площадь позволила Наде лечить раненых.","The square let Nadia treat the wounded."],
	"08_evacuate":["Надя ушла из толпы невредимой.","Nadia left the crowd unharmed."],
	"08_young":["Молодая Надя назвала забытое имя пациента.","Young Nadia named a forgotten patient."],
	"09_present":["Пассажиры вышли в настоящем.","The passengers arrived in the present."],
	"09_past":["Пассажиры вернулись к незавершённому дню.","The passengers returned to an unfinished day."],
	"10_truce":["Обе версии города сложили оружие.","Both versions of town laid down their weapons."],
	"10_houses":["Дома целы, но спор двух эпох не закончен.","The homes stand, but the two eras still disagree."],
	"11_trust":["Алина услышала Веру и ослабила разлом.","Alina heard Vera and eased the rift."],
	"11_fight":["Разлом подавлен, Алина снова закрылась.","The rift was subdued; Alina withdrew again."],
	"11_bring":["Надя помогла Алине выйти из страха.","Nadia helped Alina face her fear."],
	"12_close":["Проход закрылся; берег стал тихим.","The passage closed; the shore grew quiet."],
	"12_both":["Две эпохи научились делить один город.","Two eras learned to share one town."],
	"12_child":["Алина удержала проход без чужой власти.","Alina held the passage on her own terms."],
	"12_return":["Город получил второй шанс изменить бедствие.","Town received another chance to change the disaster."]
}

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
	title_label.add_theme_font_size_override("font_size",12)
	add_child(title_label)
	brief_label=Label.new()
	brief_label.position=Vector2(66,70)
	brief_label.size=Vector2(510,88)
	brief_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	brief_label.add_theme_font_size_override("font_size",9)
	add_child(brief_label)
	status_label=Label.new()
	status_label.position=Vector2(65,327)
	status_label.size=Vector2(520,24)
	status_label.add_theme_font_size_override("font_size",8)
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
	show_intro()

func clear_actions() -> void:
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()

func add_action(label: String, callback: Callable, available: bool=true) -> void:
	var button=Button.new()
	button.text=label
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size=Vector2(480,28)
	button.add_theme_font_size_override("font_size",9)
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
	brief_label.text=pair(quest.brief)
	status_label.text="ESC · ПАУЗА" if game.state.language=="ru" else "ESC · PAUSE"
	if index>0:
		for previous in QUESTS[index-1].choices:
			if game.state.flag("rift_choice_%02d_%s"%[index,previous[0]]):
				status_label.text=pair(OUTCOMES["%02d_%s"%[index,previous[0]]])
				break
	add_action("▶  НАЧАТЬ СОБЫТИЕ" if game.state.language=="ru" else "▶  START EVENT",start_play)
	queue_redraw()

func start_play() -> void:
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
	wave=0
	lane=1
	guard_age=0
	brief_label.text=""
	status_label.text=instruction()
	queue_redraw()

func instruction() -> String:
	match QUESTS[index].mode:
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
		match QUESTS[index].mode:
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
	brief_label.text="Событие остановлено. Прогресс сохраняется после выбора." if game.state.language=="ru" else "Event paused. Progress is saved after each decision."
	status_label.text=""
	add_action("ПРОДОЛЖИТЬ" if game.state.language=="ru" else "CONTINUE",func():phase=before_pause;show_phase())
	add_action("В ГЛАВНОЕ МЕНЮ" if game.state.language=="ru" else "MAIN MENU",func():game._save(false);active=false;visible=false;game._main_menu())
	queue_redraw()

func _physics_process(dt: float) -> void:
	if not active or phase!="play": return
	dt=minf(dt,.05)
	elapsed+=dt
	remaining-=dt
	invulnerable=maxf(0,invulnerable-dt)
	dodge_cooldown=maxf(0,dodge_cooldown-dt)
	guard_age=maxf(0,guard_age-dt)
	match QUESTS[index].mode:
		"route": update_route(dt)
		"rhythm":
			beat_age+=dt
			if beat_age>=rhythm_duration(): beat_age=0;damage();beat+=1
			if beat>=8: succeed()
		"switch": pass
		"defense": update_defense(dt)
	if remaining<=0 and phase=="play": fail()
	queue_redraw()

func update_route(dt: float) -> void:
	player_pos+=Input.get_vector("as_left","as_right","as_up","as_down")*167.0*dt
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
	if code not in keys or beat_age<rhythm_duration()*.38: return
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
	if lane!=incoming_lane() or guard_age<=0: damage()
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
	if health<=0: fail()

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
	if not available(option[0]): return
	game.state.set_flag("rift_choice_%02d_%s"%[index+1,option[0]])
	game.state.set_flag("rift_q%02d_done"%(index+1))
	if option[3] in game.state.relations: game.npcs.change_relation(option[3],int(option[4]))
	index+=1
	if index>=QUESTS.size():
		game.state.set_flag("rift_final_"+option[0])
		finish()
	else:
		game._save(false)
		show_intro()

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
	draw_rect(Rect2(Vector2.ZERO,size),Color("071015f2"))
	draw_rect(Rect2(17,17,size.x-34,size.y-34),Color("408e88"),false,2)
	draw_rect(Rect2(17,17,74,3),Color("95ded1"))
	if phase!="play": return
	draw_rect(ARENA,Color("10242a"))
	match QUESTS[index].mode:
		"route":
			draw_texture_rect_region(GRASS,ARENA,Rect2(242,120,512,207),Color("9caea7"))
			draw_texture_rect_region(DIRT,Rect2(ARENA.position.x,ARENA.position.y+69,ARENA.size.x,72),Rect2(116,250,512,72),Color("8a9a94"))
			if index==11: draw_texture_rect_region(WATER,Rect2(ARENA.position.x,ARENA.end.y-37,ARENA.size.x,37),Rect2(0,0,512,37),Color("829ca9"))
		"switch": draw_texture_rect_region(FLOOR if index!=8 else DIRT,ARENA,Rect2(0,0,512,207),Color("697e80"))
		"rhythm": draw_texture_rect_region(FLOOR if index==5 else DIRT if index==7 else GRASS,ARENA,Rect2(365,220,512,207),Color("718c91"))
		"defense": draw_texture_rect_region(WATER if index==4 else GRASS if index==10 else DIRT,ARENA,Rect2(180,310,512,207),Color("71888b"))
	draw_rect(ARENA,Color("07151bbb"))
	draw_rect(ARENA,Color("488e88"),false,2)
	var font=get_theme_default_font()
	var accent=Color("9adad0")
	draw_string(font,Vector2(67,95),"%02d / 12   ♥ %d   %02d"%[index+1,health,maxi(0,ceili(remaining))],HORIZONTAL_ALIGNMENT_LEFT,-1,8,accent)
	match QUESTS[index].mode:
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
