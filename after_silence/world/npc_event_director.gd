extends Control
const DATA=preload("res://after_silence/core/event_progress.gd")
const Activity=preload("res://after_silence/world/npc_event_activity.gd")
var events: Array=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/npc_events.json")).events
var game
var index=0
var phase="observe"
var observed=0.0
var activity
var npc
var center=Vector2(600,600)
var status: Label
var preparing=false
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	status=Label.new();status.position=Vector2(12,58);status.add_theme_font_size_override("font_size",8)
	add_child(status)
func enabled() -> bool: return game.state.flag("event_campaign") and not game.in_menu
func capture() -> Dictionary:
	if not enabled(): return game.state.event_state
	var data={"index":index,"phase":phase,"activity":{}}
	if phase=="running" and is_instance_valid(activity): data.activity=activity.checkpoint()
	return data
func start(resume=false):
	var saved=game.state.event_state.duplicate(true) if resume else {}
	index=int(saved.get("index",0));phase=saved.get("phase","observe")
	while index<events.size() and game.state.flag("event_done_"+events[index].id): index+=1;phase="observe"
	if index>=events.size(): finish();return
	var saved_phase=phase
	prepare(false)
	phase=saved_phase
	if phase=="running" and not saved.get("activity",{}).is_empty():
		start_activity()
		activity.restore(saved.activity)
	elif phase=="decision": show_decision()
	elif phase=="failure": failure()
	else: phase="observe"
func prepare(context=true):
	preparing=true
	if is_instance_valid(activity): activity.queue_free();activity=null
	var event=events[index]
	center={"town":Vector2(600,600),"forest":Vector2(700,520),"library":Vector2(480,430)}[event.zone]
	game.rift.active=false;game.rift.hide();game.rift.phase="inactive"
	game._build_world(event.zone,center+Vector2(0,65))
	if not game.actors.has(event.npc): game._npc(event.npc,center+Vector2(-55,-25),"res://after_silence/assets/pechatai/npc/"+game.npcs.PROFILE[event.npc][3]+".png")
	npc=game.actors[event.npc]
	npc.position=game.world.recover(center+Vector2(0,-20));npc.target=npc.position;npc.scripted=true
	phase="observe";observed=0;preparing=false
	game.state.set_flag("event_unlocked_"+event.id)
	npc.modulate.a=0
	game.create_tween().tween_property(npc,"modulate:a",1,.35)
	game.objective.modulate.a=0
	game.create_tween().tween_property(game.objective,"modulate:a",1,.35)
	if context:
		game._dialog("",pair(event.title),pair(event.context),[game.choice("watch","Посмотреть","Observe",game._close)],false)
func pair(value: Array) -> String: return game.Story.pair(value,game.state.language)
func npc_state() -> String:
	if phase=="observe": return "arguing" if index==3 else "scared" if index==7 else "busy"
	if phase=="ready": return "asks_help" if index in [0,4,6] else "ready"
	if phase=="running": return "helping"
	if phase=="decision": return "returned"
	return "left"
func talk(id: String) -> bool:
	if not enabled(): return false
	if index>=events.size(): return true
	if id!=events[index].npc:
		game._notify(game.t("Сейчас поговори с ","Speak now with ")+game.named(events[index].npc));return true
	if phase=="observe":
		game._notify(pair(events[index].context));return true
	if phase=="ready":
		game._dialog("",game.named(id),pair(events[index].rule),[game.choice("help","Помочь","Help",start_activity),game.choice("wait","Ещё понаблюдать","Observe more",game._close)],false)
	return true
func start_activity():
	game._close()
	game.toast.text=""
	if is_instance_valid(activity): activity.queue_free()
	activity=Activity.new();game.world.add_child(activity)
	activity.start(game,events[index].mode,npc,center)
	npc.get_meta("caption").hide()
	activity.completed.connect(success)
	activity.defeated.connect(failure)
	phase="running"
	game._save(false)
func success():
	phase="decision"
	npc.modulate=Color("a1e0ca")
	game.create_tween().tween_property(npc,"modulate",Color.WHITE,.7)
	game.audio.scene_cue("memory",game.state.volume)
	show_decision()
func show_decision():
	var actions=[]
	for option in events[index].choices:
		actions.append(game.choice(option[0],option[1],option[2],func():choose(option)))
	game._dialog("",pair(events[index].title),game.t("Получилось. Что решит Вера?","You did it. What will Vera choose?"),actions,false)
func choose(option: Array):
	if phase!="decision": return
	var event=events[index]
	game.state.set_flag("event_done_"+event.id)
	game.state.set_flag("event_choice_"+event.id+"_"+option[0])
	game.npcs.change_relation(option[3],int(option[4]))
	game.living.remember(event.npc,"help")
	game.state.tokens=mini(999,game.state.tokens+1)
	game.state.history.append({"speaker":pair(event.title),"body":option[2] if game.state.language=="en" else option[1]})
	phase="observe"
	game._close()
	var departure=game.create_tween()
	departure.tween_property(npc,"modulate:a",0,.25)
	await departure.finished
	index+=1
	if index>=events.size(): finish();return
	prepare()
	game._notify(pair(event.next))
	game._save(false)
func failure():
	phase="failure"
	if is_instance_valid(activity): activity.active=false
	game._dialog("",game.t("Попробуем ещё раз","Try again"),game.t("Все в безопасности. Повтори действие, следя за предупреждениями.","Everyone is safe. Retry and watch the warnings."),[game.choice("retry","Повторить","Retry",func():
		game.player.position=game.world.recover(center+Vector2(0,65));npc.position=game.world.recover(center+Vector2(0,-20));start_activity()),game.choice("menu","Сохранить и выйти","Save and exit",func():game._save(false);game._main_menu())],false)
func finish():
	index=events.size();phase="finished"
	game.state.set_flag("events_finished")
	if is_instance_valid(activity): activity.queue_free();activity=null
	game._dialog("",game.t("Город помнит","The town remembers"),game.t("Девять событий завершены. Жители сохранили память благодаря тебе.","Nine events completed. You helped the residents preserve their memories."),[game.choice("journal","Итоги","Results",journal),game.choice("menu","В главное меню","Main menu",func():game._save(false);game._main_menu())],false)
	game._save(false)
func journal():
	var lines=[]
	if index<events.size():
		lines.append(pair(events[index].title)+" · "+game.t({"observe":"Наблюдение","ready":"Разговор","running":"Действие","decision":"Решение","failure":"Повтор"}.get(phase,phase),phase))
	for event in events:
		if not game.state.flag("event_done_"+event.id): continue
		for option in event.choices:
			if game.state.flag("event_choice_"+event.id+"_"+option[0]): lines.append("◆ "+pair(event.title)+": "+option[2 if game.state.language=="en" else 1])
	for id in game.state.relations: lines.append(game.named(id)+": "+str(game.state.relations[id]))
	game._dialog("",game.t("Журнал событий","Event journal"),"\n".join(lines),[game.choice("close","Закрыть","Close",game._close)],false)
func _physics_process(dt):
	visible=enabled() and not game.modal
	if not enabled():
		if is_instance_valid(npc): npc.scripted=false
		if is_instance_valid(activity):
			for person in activity.followers:
				if is_instance_valid(person): person.scripted=false
		return
	if index>=events.size():
		game.objective.text=game.t("История завершена. J — итоги.","Story complete. J: results.")
		game.objective.visible=not game.modal
		return
	if preparing: return
	game.objective.text=game.named(events[index].npc)+" · "+pair(events[index].rule if phase=="running" else events[index].context)
	game.objective.visible=not game.modal and not game.in_menu
	status.text="%d / %d"%[index+1,events.size()]
	if is_instance_valid(activity) and phase=="running": status.text+=" · %02d:%02d · %d/5"%[int(activity.elapsed)/60,int(activity.elapsed)%60,activity.hp]
	if not is_instance_valid(npc): return
	if game.modal or game.in_menu:
		npc.scripted=false
		if is_instance_valid(activity):
			for person in activity.followers:
				if is_instance_valid(person): person.scripted=false
		return
	if phase in ["observe","ready"]:
		npc.target=game.world.recover(center+Vector2(sin(observed*1.2)*12,-20))
		npc.npc_speed=35;npc.scripted=true
		if game.player.position.distance_to(npc.position)<160: observed+=dt
		if observed>=3 and phase=="observe": phase="ready";game._notify(game.named(events[index].npc)+" · E")
		var caption=npc.get_meta("caption")
		caption.show();caption.text=game.t({"busy":"Занят…","arguing":"Нет, сначала иначе!","scared":"Мне страшно…","ready":"Поговорим?","asks_help":"Поможешь?"}.get(npc_state(),""),npc_state())
		npc.sprite.position.x+=sin(observed*8)*.35 if npc_state() in ["scared","arguing"] else 0
