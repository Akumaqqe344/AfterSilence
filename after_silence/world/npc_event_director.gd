extends Control
const Activity=preload("res://after_silence/world/npc_event_activity.gd")
const Puzzle=preload("res://after_silence/core/quiet_puzzle.gd")
const Reality=preload("res://after_silence/core/reality_maze.gd")
const CHARACTERS={"child":["Ребёнок Нади","Nadia's child","ella"],"alina":["Алина","Alina","lora"],"guest":["Гость","Guest","scientist"]}
const PUZZLE_MEMORIES={
	"machine":["В мастерской снова прохладно. Теперь слышно, как тикают часы.","The workshop is cool again. I can hear the clock now."],
	"memory":["Я оставил тебе открытку с солнцем.","I saved the card with the sun for you."],
	"garden":["Если я забуду дорогу домой, цветы подскажут.","If I forget the way home, the flowers will show me."],
	"collision":["Теперь оба города видят свет из окон библиотеки.","Both towns can see the light in the library windows now."],
	"shore":["У каждой семьи нашлась своя метка. Никого не потеряли.","Every family found its tag. Nobody was left behind."],
}
var events: Array=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/npc_events.json")).events
var game
var index=0
var phase="travel"
var observed=0.0
var activity
var npc
var center=Vector2(600,580)
var status: Label
var preparing=false
var pending: Dictionary={}
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	status=Label.new();status.position=Vector2(490,42);status.add_theme_font_size_override("font_size",8);add_child(status)
func enabled() -> bool: return game.state.flag("event_campaign") and not game.in_menu
func owns(id: String) -> bool:
	return enabled() and index<events.size() and id==events[index].npc and phase not in ["travel","finished"]
func capture() -> Dictionary:
	if not enabled(): return game.state.event_state
	if not pending.is_empty(): return pending.duplicate(true)
	var data={"version":3,"index":index,"phase":phase,"activity":{}}
	if phase in ["running","suspended"] and is_instance_valid(activity) and is_instance_valid(activity.npc): data.activity=activity.checkpoint()
	return data
func migrate(saved: Dictionary):
	if saved.get("version",1)>=2: return
	var old_ids=["letter","song","watch","machine","shelter","path","evacuate","watcher","restore"]
	var count=0
	for id in old_ids:
		if game.state.flag("event_done_"+id): count+=1
		else: break
	if game.state.flag("events_finished"): count=events.size()
	for i in range(mini(count,events.size())): game.state.set_flag("event_done_"+events[i].id)
	saved.clear();saved.merge({"version":2,"index":count,"phase":"travel","activity":{}})
func start(resume=false):
	pending={}
	if game.event_window.active: game.event_window.close()
	var saved=game.state.event_state.duplicate(true) if resume else {"version":2}
	migrate(saved)
	index=0
	while index<events.size() and game.state.flag("event_done_"+events[index].id): index+=1
	if index>=events.size(): finish();return
	var matching=int(saved.get("index",index))==index
	var saved_phase=saved.get("phase","travel") if matching else "travel"
	if saved_phase in ["running","suspended","decision","failure"] and matching: game.state.set_flag("event_action_"+events[index].id)
	prepare(false)
	if saved_phase=="action" and matching:
		if game.state.zone==game.journey.places[events[index].location].zone: phase="action";populate_preparation()
		else: pending=saved.duplicate(true)
	if saved_phase in ["running","suspended","decision","failure"] and matching:
		var place=game.journey.places[events[index].location]
		if game.state.zone==place.zone and game.state.residents[events[index].npc].zone==place.zone:
			npc=game.actors[events[index].npc]
			phase="observe"
		else:
			pending=saved.duplicate(true)
			var resident=game.state.residents[events[index].npc]
			game.npcs.request(events[index].npc,resident.zone,game.npcs.position_of(resident))
			game._notify(game.t("Событие сохранено. Вернись к месту встречи через «Путешествие».","The event is saved. Return to the meeting shown in Travel."))
	if phase=="travel": return
	if saved_phase in ["running","suspended"] and not saved.get("activity",{}).is_empty():
		start_activity(saved.activity)
		if saved_phase=="suspended":
			game.event_window.close();activity.active=false;phase="suspended"
			if activity.mode=="tactics": activity.tactics.set_paused(true)
	elif saved_phase=="decision": phase="decision";show_decision()
	elif saved_phase=="failure": failure()
func prepare(context=true):
	preparing=true
	if game.event_window.active: game.event_window.close()
	dispose_activity()
	game.rift.active=false;game.rift.hide();game.rift.phase="inactive"
	var event=events[index]
	var place=game.journey.places[event.location]
	var point=place.point
	center=Vector2(point[0],point[1])
	game.npcs.populate(game)
	game.npcs.request(event.npc,place.zone,center+Vector2(0,-20))
	npc=game.actors[event.npc]
	npc.managed_motion=true
	phase="travel";observed=0
	preparing=false
	populate_preparation()
	if not game.journey.here(event.location): return
	arrive(context)
func arrive(context=true):
	var event=events[index]
	game.state.set_flag("event_left_"+event.npc,false)
	game.npcs.populate(game)
	npc=game.actors[event.npc]
	if not pending.is_empty() and game.state.residents[event.npc].zone==game.state.zone:
		var saved=pending.duplicate(true);pending={}
		phase="observe"
		if saved.phase=="decision": phase="decision";show_decision()
		elif saved.phase=="failure": failure()
		elif not saved.get("activity",{}).is_empty():
			make_activity(saved.activity);activity.end_view();activity.active=false;phase="suspended"
			if activity.mode=="tactics": activity.tactics.set_paused(true)
			game._notify(game.t("Событие восстановлено. E — продолжить.","The event is restored. E: continue."))
		elif saved.phase=="action": phase="action";populate_preparation()
		game._save(false)
		return
	if game.state.residents[event.npc].zone!=game.state.zone or npc.position.distance_to(center+Vector2(0,-20))>25:
		game.objective.text=game.named(event.npc)+game.t(" идёт к месту встречи. Можно подождать."," is walking to the meeting. You can wait.")
		return
	npc.target=npc.position;npc.scripted=false
	phase="observe";observed=0
	game.state.set_flag("event_unlocked_"+event.id)
	game.objective.modulate.a=0;game.create_tween().tween_property(game.objective,"modulate:a",1,.35)
	if context:
		var greeting=pair(event.context)
		if game.state.relations.get(event.npc,0)>0: greeting+="\n"+game.t("Спасибо, что была рядом раньше.","Thank you for being there before.")
		game._dialog(event.npc+"_context",game.named(event.npc),greeting,[game.choice("watch","Посмотреть","Observe",game._close)],true)
func pair(value: Array) -> String: return game.Story.pair(value,game.state.language)
func npc_state() -> String:
	if phase=="observe": return "angry" if events[index].id in ["crowd","machine"] else "afraid" if events[index].npc in ["child","alina"] else "busy"
	return {"ready":"ready_to_talk","running":"helping","suspended":"waiting","decision":"returned","travel":"walking","failure":"afraid","finished":"idle"}.get(phase,"left")
func talk(id: String) -> bool:
	if not enabled(): return false
	if index>=events.size():
		tell_puzzle_memory(id)
		return true
	if id!=events[index].npc or phase=="travel":
		if tell_puzzle_memory(id): return true
		var key="event_smalltalk_"+id+"_"+str(index)
		if not game.state.flag(key):
			game.state.set_flag(key);game._notify(game.t("Загляни в «Путешествие»: там ждут друзья.","Travel shows where your friends are waiting."))
		return true
	if phase=="observe": game._notify(game.named(id)+game.t(" пока занят. Понаблюдай рядом."," is busy. Observe nearby."));return true
	if phase=="ready":
		game._dialog(id+"_event",game.named(id),pair(events[index].rule),[game.choice("help","Помочь","Help",begin_preparation),game.choice("wait","Подожду немного","I will wait",game._close)],true)
	elif phase=="action": game._notify(pair(events[index].world_action))
	elif phase=="suspended":
		game._dialog(id+"_resume",game.named(id),game.t("Продолжим с того места, где остановились?","Shall we continue where we stopped?"),[game.choice("resume","Продолжить","Continue",resume_activity),game.choice("later","Позже","Later",game._close)],true)
	elif phase=="decision": show_decision()
	elif phase=="failure": failure()
	return true
func tell_puzzle_memory(id: String) -> bool:
	for i in range(events.size()-1,-1,-1):
		var event=events[i]
		var key="event_reflection_"+event.id
		if event.npc!=id or not PUZZLE_MEMORIES.has(event.id): continue
		if not game.state.flag("event_done_"+event.id) or game.state.flag(key): continue
		game.state.set_flag(key)
		game._dialog(id+"_reflection_"+event.id,game.named(id),pair(PUZZLE_MEMORIES[event.id]),[game.choice("close","Закрыть","Close",game._close)],false)
		return true
	return false
func start_activity(checkpoint: Dictionary={}):
	if not is_instance_valid(npc) or phase not in ["ready","observe","action","failure","running","suspended"]: return
	if not game.state.flag("event_action_"+events[index].id):
		begin_preparation();return
	game._close();game.toast.text=""
	if game.event_window.active: game.event_window.close()
	dispose_activity()
	make_activity(checkpoint)
	phase="running";game.event_window.open();game._save(false)
func preparation_point() -> Vector2:
	return game.npcs.safe_point(game.journey.places[events[index].location].zone,center+Vector2(90,45))
func clear_preparation():
	if not is_instance_valid(game.world): return
	game.world.interactables=game.world.interactables.filter(func(spot):return spot.id!="event_preparation")
	for prop in game.world.sorter.get_children():
		if prop.get_meta("hotspot_id","")=="event_preparation": prop.hide();prop.queue_free()
func populate_preparation():
	clear_preparation()
	if not enabled() or index>=events.size(): return
	var event=events[index]
	if game.state.zone!=game.journey.places[event.location].zone or game.state.flag("event_action_"+event.id): return
	game.world.spot("event_preparation",preparation_point(),"note")
func refresh_mementos():
	if not enabled() or not is_instance_valid(game.world): return
	var art=preload("res://after_silence/world/quiet_memento.gd")
	for event in events:
		if event.mode not in Puzzle.SIZES or not game.state.flag("event_done_"+event.id): continue
		var place=game.journey.places[event.location]
		if place.zone!=game.state.zone: continue
		var node_name="Memento_"+event.id
		if game.world.sorter.has_node(node_name): continue
		var prop=art.new()
		prop.name=node_name;prop.kind=event.mode
		prop.position=game.npcs.safe_point(place.zone,Vector2(place.point[0],place.point[1])+Vector2(90,45))
		game.world.sorter.add_child(prop)
func begin_preparation():
	if index>=events.size() or game.state.flag("event_done_"+events[index].id): return
	if game.state.flag("event_action_"+events[index].id): start_activity();return
	phase="action";game._close();populate_preparation()
	game._notify(pair(events[index].world_action));game._save(false)
func complete_preparation() -> bool:
	if phase!="action" or index>=events.size() or game.state.zone!=game.journey.places[events[index].location].zone: return false
	if game.player.position.distance_to(preparation_point())>60: return false
	game.state.set_flag("event_action_"+events[index].id)
	clear_preparation();start_activity();return true
func make_activity(checkpoint: Dictionary={}):
	activity=Activity.new();game.world.add_child(activity)
	var kind=events[index].mode
	var legacy=Puzzle.LEGACY.get(events[index].id,"")
	if kind=="reality": legacy=Reality.LEGACY.get(events[index].id,"")
	if legacy!="" and checkpoint.get("mode","")==legacy: kind=legacy
	# Preserve an already active 0.15 defense scene; new attempts use tactics.
	if (kind=="tactics" or (kind=="reality" and legacy=="tactics")) and checkpoint.get("mode","")=="defense": kind="defense"
	activity.start(game,kind,npc,center)
	if kind=="defense": activity.rule=game.t("E — прикрыть опасную полосу рядом с другом.","E: guard the threatened lane beside your friend.")
	if not checkpoint.is_empty(): activity.restore(checkpoint)
	activity.completed.connect(success);activity.defeated.connect(failure)
	npc.get_meta("caption").hide()
func dispose_activity(preserve_residents=false):
	if not is_instance_valid(activity): activity=null;return
	var previous=activity
	if preserve_residents and previous.mode=="tactics" and is_instance_valid(previous.tactics): previous.tactics.released=true
	activity=null;previous.active=false
	if previous.is_inside_tree(): previous.get_parent().remove_child(previous)
	previous.queue_free()
func detach_activity():
	if not is_instance_valid(activity) or activity.get_parent()!=game.world: return
	if game.event_window.active: game.event_window.close()
	activity.active=false
	if phase not in ["decision","failure"]: phase="suspended"
	if activity.mode=="tactics": activity.tactics.set_paused(true)
	else:
		npc.managed_motion=true;npc.scripted=false
		game.npcs.request(events[index].npc,game.state.zone,npc.position)
	activity.moving_world=true
	activity.reparent(game.npcs.pool,false);activity.hide()
	activity.moving_world=false
func attach_activity(zone: String):
	if not is_instance_valid(activity) or index>=events.size() or game.journey.places[events[index].location].zone!=zone: return
	activity.moving_world=true
	activity.reparent(game.world,false);activity.show()
	activity.moving_world=false
	if activity.mode=="epochs":
		activity.gate_grid=game.world.grid
		for gate in activity.gates: gate.set_deferred("disabled",true)
func resume_activity():
	game._close();phase="running";activity.active=true
	if activity.mode=="tactics": activity.tactics.set_paused(false)
	game.event_window.open()
func suspend():
	if is_instance_valid(activity): activity.active=false
	if is_instance_valid(activity) and activity.mode=="tactics": activity.tactics.set_paused(true)
	elif is_instance_valid(npc):
		npc.scripted=false;npc.managed_motion=true
		game.npcs.request(events[index].npc,game.state.zone,npc.position)
	if is_instance_valid(activity):
		for person in activity.followers:
			if is_instance_valid(person): person.scripted=false
	phase="suspended"
	if not is_instance_valid(activity) or (not activity.board_mode() and activity.mode not in ["tactics","epochs"]):
		game.player.position=game.world.recover(npc.position+Vector2(0,65))
	game._save(false)
func success():
	game.event_window.close();phase="decision"
	if is_instance_valid(activity) and activity.reality!=null:
		match events[index].id:
			"bridge": game.state.set_flag("safe_patrol")
			"crowd": game.state.set_flag("calm_nadia")
	if not game.comfort.reduce_motion:
		npc.modulate=Color("a1e0ca");game.create_tween().tween_property(npc,"modulate",Color.WHITE,.7)
	game._save(false)
	game.audio.scene_cue("memory",game.state.volume);show_decision()
func show_decision():
	var actions=[]
	for option in events[index].choices: actions.append(game.choice(option[0],option[1],option[2],func():choose(option)))
	game._dialog(events[index].npc+"_decision",pair(events[index].title),game.t("Получилось. Как поступим дальше?","We did it. What should we do next?"),actions,true)
func choose(option: Array):
	if phase!="decision": return
	var event=events[index]
	if option not in event.choices or game.state.flag("event_done_"+event.id): return
	game.state.set_flag("event_done_"+event.id)
	game.state.set_flag("event_choice_"+event.id+"_"+option[0])
	game.state.set_flag("place_changed_"+event.location)
	refresh_mementos()
	game.npcs.change_relation(option[3],int(option[4]));game.living.remember(event.npc,"help")
	game.state.tokens=mini(999,game.state.tokens+1)
	game.state.history.append({"speaker":pair(event.title),"body":option[2] if game.state.language=="en" else option[1]})
	if index==events.size()-1: game.state.set_flag("events_final_"+option[0])
	phase="travel";game._close()
	npc.managed_motion=true;npc.scripted=false;npc.modulate=Color.WHITE
	game.npcs.release(event.npc)
	game.state.set_flag("event_left_"+event.npc,false)
	index+=1
	if index>=events.size(): finish();return
	prepare(false)
	var result=(option[2] if game.state.language=="en" else option[1])+"\n"+game.named(option[3])+" +"+str(option[4])+"\n"+pair(event.next)
	game._dialog("",game.t("Твой выбор помог","Your choice helped"),result,[game.choice("continue","Продолжить путь","Continue the journey",game._close),game.choice("places","Путешествие","Travel",game.journey.open)],true)
	game._save(false)
func failure():
	game.event_window.close();phase="failure"
	if is_instance_valid(activity): activity.active=false
	game._dialog(events[index].npc+"_retry",game.t("Попробуем ещё раз","Try again"),game.t("Ты уже знаешь путь. Попробуем спокойно.","You know the way now. Let's try calmly."),[game.choice("retry","Повторить","Retry",func():
			start_activity()),game.choice("leave","Вернуться в мир","Return to the world",func():game._close();phase="ready";npc.managed_motion=true)],true)
func finish():
	game.event_window.close();index=events.size();phase="finished";game.state.set_flag("events_finished")
	dispose_activity()
	var ending=game.t("Оба времени остались рядом. Никто не один.","Both eras remain together. Nobody is alone.") if game.state.flag("events_final_together") else game.t("Жители вернулись домой. Берег сохранил их память.","The residents returned home. The shore remembers them.")
	game._dialog("",game.t("Последний берег","The final shore"),ending,[game.choice("journal","Итоги путешествия","Journey results",journal),game.choice("menu","В главное меню","Main menu",func():game._save(false);game._main_menu())],true)
	game._save(false)
func journal():
	var lines=[]
	if index<events.size(): lines.append(pair(events[index].title)+" · "+npc_state())
	for event in events:
		if not game.state.flag("event_done_"+event.id): continue
		for option in event.choices:
			if game.state.flag("event_choice_"+event.id+"_"+option[0]): lines.append("◆ "+pair(event.title)+": "+option[2 if game.state.language=="en" else 1])
	for id in game.state.relations: lines.append(game.named(id)+": "+str(game.state.relations[id]))
	game._dialog("",game.t("Журнал событий","Event journal"),"\n".join(lines),[game.choice("travel","Путешествие","Travel",game.journey.open),game.choice("close","Закрыть","Close",game._close)],false)
func _physics_process(dt):
	visible=enabled() and not game.modal and not game.event_window.active
	if not enabled():
		if is_instance_valid(npc): npc.scripted=false
		return
	game.journey.update()
	if index>=events.size(): game.objective.text=game.t("Путешествие завершено. J — итоги.","Journey complete. J: results.");return
	if preparing: return
	var event=events[index]
	if phase in ["running","suspended"] and not is_instance_valid(activity):
		game.event_window.close();phase="ready"
		game._notify(game.t("Событие восстановлено. Можно начать снова.","The event was restored. You can retry."))
	if phase=="travel":
		game.objective.text=pair(game.journey.places[event.location].name)+" · "+pair(game.journey.places[event.location].route)
		if not game.modal and game.journey.here(event.location): arrive()
		return
	if phase=="action":
		game.objective.text=pair(event.world_action)+game.t(" · E у отмеченного предмета."," · E at the marked object.")
		return
	if not is_instance_valid(npc):
		prepare(false);game._notify(game.t("Встреча восстановлена. Загляни в «Путешествие».","The meeting was restored. Check Travel."));return
	game.objective.text=game.named(event.npc)+" · "+pair(event.rule if phase=="running" else event.context)
	game.objective.visible=not game.modal and not game.event_window.active
	status.text="%d / %d"%[index+1,events.size()]
	if game.modal or game.in_menu:
		npc.scripted=false
		if is_instance_valid(activity):
			for person in activity.followers:
				if is_instance_valid(person): person.scripted=false
		return
	if phase in ["observe","ready"]:
		npc.scripted=false
		if game.player.position.distance_to(npc.position)<160: observed+=dt
		var trust_delay=1.5 if game.state.relations.get(event.npc,0)>0 else 3.0
		if observed>=trust_delay and phase=="observe": phase="ready";game._notify(game.named(event.npc)+" · E")
		var caption=npc.get_meta("caption");caption.show()
		caption.text=game.t({"busy":"Сейчас закончу…","angry":"Дай мне минутку…","afraid":"Побудь рядом…","ready_to_talk":"Поговорим?"}.get(npc_state(),"Я подожду."),npc_state())
