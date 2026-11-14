extends Control
const Activity=preload("res://after_silence/world/npc_event_activity.gd")
const CHARACTERS={"child":["Ребёнок Нади","Nadia's child","ella"],"alina":["Алина","Alina","lora"],"guest":["Гость","Guest","scientist"]}
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
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	status=Label.new();status.position=Vector2(12,58);status.add_theme_font_size_override("font_size",8);add_child(status)
func enabled() -> bool: return game.state.flag("event_campaign") and not game.in_menu
func owns(id: String) -> bool:
	return enabled() and index<events.size() and id==events[index].npc and phase not in ["travel","finished"]
func capture() -> Dictionary:
	if not enabled(): return game.state.event_state
	var data={"version":2,"index":index,"phase":phase,"activity":{}}
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
	if game.event_window.active: game.event_window.close()
	var saved=game.state.event_state.duplicate(true) if resume else {"version":2}
	migrate(saved)
	index=0
	while index<events.size() and game.state.flag("event_done_"+events[index].id): index+=1
	if index>=events.size(): finish();return
	var matching=int(saved.get("index",index))==index
	var saved_phase=saved.get("phase","travel") if matching else "travel"
	if saved_phase in ["running","suspended","decision","failure"]:
		var place=game.journey.places[events[index].location]
		if game.state.zone==place.zone: game.player.position=game.world.recover(Vector2(place.point[0],place.point[1])+Vector2(0,65))
	prepare(false)
	if phase=="travel": return
	if saved_phase in ["running","suspended"] and not saved.get("activity",{}).is_empty():
		start_activity()
		activity.restore(saved.activity)
		if saved_phase=="suspended": game.event_window.close();activity.active=false;phase="suspended"
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
	phase="travel";npc=null;observed=0
	preparing=false
	if not game.journey.here(event.location): return
	arrive(context)
func arrive(context=true):
	var event=events[index]
	game.state.set_flag("event_left_"+event.npc,false)
	if game.state.residents.has(event.npc): game.state.residents[event.npc].zone=game.state.zone
	if game.actors.has(event.npc) and not is_instance_valid(game.actors[event.npc]): game.actors.erase(event.npc)
	if not game.actors.has(event.npc):
		var sheet=CHARACTERS[event.npc][2] if CHARACTERS.has(event.npc) else game.npcs.PROFILE[event.npc][3]
		game._npc(event.npc,center,"res://after_silence/assets/pechatai/npc/"+sheet+".png")
	npc=game.actors[event.npc]
	if event.npc=="child": npc.scale=Vector2.ONE*.8
	npc.position=game.world.recover(center+Vector2(0,-20));npc.target=npc.position;npc.scripted=true
	phase="observe";observed=0
	game.state.set_flag("event_unlocked_"+event.id)
	npc.modulate.a=0;game.create_tween().tween_property(npc,"modulate:a",1,.35)
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
	if index>=events.size(): return true
	if id!=events[index].npc or phase=="travel":
		var key="event_smalltalk_"+id+"_"+str(index)
		if not game.state.flag(key):
			game.state.set_flag(key);game._notify(game.t("Загляни в «Путешествие»: там ждут друзья.","Travel shows where your friends are waiting."))
		return true
	if phase=="observe": game._notify(game.named(id)+game.t(" пока занят. Понаблюдай рядом."," is busy. Observe nearby."));return true
	if phase=="ready":
		game._dialog(id+"_event",game.named(id),pair(events[index].rule),[game.choice("help","Помочь","Help",start_activity),game.choice("wait","Подожду немного","I will wait",game._close)],true)
	elif phase=="suspended":
		game._dialog(id+"_resume",game.named(id),game.t("Продолжим с того места, где остановились?","Shall we continue where we stopped?"),[game.choice("resume","Продолжить","Continue",resume_activity),game.choice("later","Позже","Later",game._close)],true)
	return true
func start_activity():
	game._close();game.toast.text=""
	if game.event_window.active: game.event_window.close()
	dispose_activity()
	activity=Activity.new();game.world.add_child(activity)
	activity.start(game,events[index].mode,npc,center)
	activity.completed.connect(success);activity.defeated.connect(failure)
	npc.get_meta("caption").hide()
	phase="running";game.event_window.open();game._save(false)
func dispose_activity():
	if not is_instance_valid(activity): activity=null;return
	var previous=activity
	activity=null;previous.active=false
	if previous.is_inside_tree(): previous.get_parent().remove_child(previous)
	previous.queue_free()
func resume_activity():
	game._close();phase="running";activity.active=true;game.event_window.open()
func suspend():
	if is_instance_valid(activity): activity.active=false
	if is_instance_valid(npc): npc.scripted=false
	if is_instance_valid(activity):
		for person in activity.followers:
			if is_instance_valid(person): person.scripted=false
	phase="suspended"
	game.player.position=game.world.recover(npc.position+Vector2(0,65))
	game._save(false)
func success():
	game.event_window.close();phase="decision"
	npc.modulate=Color("a1e0ca");game.create_tween().tween_property(npc,"modulate",Color.WHITE,.7)
	game.audio.scene_cue("memory",game.state.volume);show_decision()
func show_decision():
	var actions=[]
	for option in events[index].choices: actions.append(game.choice(option[0],option[1],option[2],func():choose(option)))
	game._dialog(events[index].npc+"_decision",pair(events[index].title),game.t("Получилось. Как поступим дальше?","We did it. What should we do next?"),actions,true)
func choose(option: Array):
	if phase!="decision": return
	var event=events[index]
	game.state.set_flag("event_done_"+event.id)
	game.state.set_flag("event_choice_"+event.id+"_"+option[0])
	game.state.set_flag("place_changed_"+event.location)
	game.npcs.change_relation(option[3],int(option[4]));game.living.remember(event.npc,"help")
	game.state.tokens=mini(999,game.state.tokens+1)
	game.state.history.append({"speaker":pair(event.title),"body":option[2] if game.state.language=="en" else option[1]})
	if index==events.size()-1: game.state.set_flag("events_final_"+option[0])
	phase="travel";game._close()
	var leaving=npc
	var departure=game.create_tween();departure.tween_property(leaving,"modulate:a",0,.25)
	await departure.finished
	game.state.set_flag("event_left_"+event.npc)
	game.actors.erase(event.npc)
	if is_instance_valid(leaving): leaving.queue_free()
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
		game.player.position=game.world.recover(center+Vector2(0,65));npc.position=game.world.recover(center+Vector2(0,-20));start_activity()),game.choice("leave","Вернуться в мир","Return to the world",func():game._close();phase="ready")],true)
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
		npc.target=game.world.recover(center+Vector2(sin(observed*1.2)*12,-20));npc.npc_speed=35;npc.scripted=true
		if game.player.position.distance_to(npc.position)<160: observed+=dt
		var trust_delay=1.5 if game.state.relations.get(event.npc,0)>0 else 3.0
		if observed>=trust_delay and phase=="observe": phase="ready";game._notify(game.named(event.npc)+" · E")
		var caption=npc.get_meta("caption");caption.show()
		caption.text=game.t({"busy":"Сейчас закончу…","angry":"Дай мне минутку…","afraid":"Побудь рядом…","ready_to_talk":"Поговорим?"}.get(npc_state(),"Я подожду."),npc_state())
