extends Control
const Activity=preload("res://after_silence/world/npc_event_activity.gd")
const Puzzle=preload("res://after_silence/core/quiet_puzzle.gd")
const EventProgress=preload("res://after_silence/core/event_progress.gd")
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
var activity
var npc
var center=Vector2(600,580)
var preparing=false
var pending: Dictionary={}
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func enabled() -> bool: return game.state.flag("event_campaign") and not game.in_menu
func owns(id: String) -> bool:
	return enabled() and index<events.size() and id==events[index].npc and phase not in ["travel","finished"]
func capture() -> Dictionary:
	if not enabled(): return game.state.event_state
	if not pending.is_empty(): return pending.duplicate(true)
	var data={"version":3,"index":index,"phase":phase,"activity":{}}
	if phase in ["running","suspended"] and activity!=null: data.activity=activity.checkpoint()
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
	if matching: saved=EventProgress.upgrade(saved,events[index])
	var saved_phase=saved.get("phase","travel") if matching else "travel"
	if saved_phase in ["running","suspended","decision"]: game.state.set_flag("event_action_"+events[index].id)
	prepare()
	if saved_phase in ["running","suspended","decision"]:
		var place=game.journey.places[events[index].location]
		if game.state.zone==place.zone and game.state.residents[events[index].npc].zone==place.zone:
			npc=game.actors[events[index].npc]
			phase="ready"
		else:
			pending=saved.duplicate(true)
			var resident=game.state.residents[events[index].npc]
			game.npcs.request(events[index].npc,resident.zone,game.npcs.position_of(resident))
			game._notify(game.t("Событие сохранено. Вернись к месту встречи через «Путешествие».","The event is saved. Return to the meeting shown in Travel."))
	if phase=="travel": return
	if saved_phase=="running":
		start_activity(saved.activity)
	elif saved_phase=="suspended":
		make_activity(saved.activity);phase="suspended"
	elif saved_phase=="decision": phase="decision";show_decision()
func prepare():
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
	phase="travel"
	preparing=false
	if not game.journey.here(event.location): return
	arrive()
func arrive():
	var event=events[index]
	game.state.set_flag("event_left_"+event.npc,false)
	game.npcs.populate(game)
	npc=game.actors[event.npc]
	if not pending.is_empty() and game.state.residents[event.npc].zone==game.state.zone:
		var saved=pending.duplicate(true);pending={}
		phase="ready"
		if saved.phase=="decision": phase="decision";show_decision()
		elif not saved.get("activity",{}).is_empty():
			make_activity(saved.activity);phase="suspended"
			game._notify(game.t("Событие восстановлено. E — продолжить.","The event is restored. E: continue."))
		game._save(false)
		return
	if game.state.residents[event.npc].zone!=game.state.zone or npc.position.distance_to(center+Vector2(0,-20))>25:
		game.objective.text=game.named(event.npc).split(" · ")[0]+game.t(" в пути"," is on the way")
		return
	npc.target=npc.position;npc.scripted=false
	phase="ready"
	game.state.set_flag("event_unlocked_"+event.id)
func pair(value: Array) -> String: return game.Story.pair(value,game.state.language)
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
	if phase=="ready": start_activity()
	elif phase=="suspended": resume_activity()
	elif phase=="decision": show_decision()
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
	if not is_instance_valid(npc) or phase not in ["ready","running","suspended"]: return
	if game.investigations.barrier(events[index].id):
		game.investigations.followup(events[index].npc)
		return
	game.state.set_flag("event_action_"+events[index].id)
	game._close();game.toast.text=""
	if game.event_window.active: game.event_window.close()
	dispose_activity()
	make_activity(checkpoint)
	phase="running";game.event_window.open();game._save(false)
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
func make_activity(checkpoint: Dictionary={}):
	var definition: Dictionary=events[index].duplicate()
	if not checkpoint.is_empty():
		definition.variant = checkpoint.get("variant", "")
	elif definition.id=="crowd" and game.investigations.decided("quiet_call"):
		definition.variant="quiet_plaza"
	elif game.state.flag("expedition_0330"):
		definition.variant = "field_notes"
	activity=Activity.new(definition)
	if checkpoint.get("mode","")==activity.mode: activity.restore(checkpoint)
	npc.get_meta("caption").hide()
func dispose_activity():
	activity=null
func detach_activity():
	if phase!="running": return
	if game.event_window.active: game.event_window.close()
	phase="suspended"
func resume_activity():
	if phase!="suspended" or activity==null: return
	game._close();phase="running"
	game.event_window.open()
func suspend():
	phase="suspended"
	game._save(false)
func success():
	game.event_window.close();phase="decision"
	match events[index].id:
		"bridge": game.state.set_flag("safe_patrol")
		"crowd": game.state.set_flag("calm_nadia")
	if not game.comfort.reduce_motion:
		npc.modulate=Color("a1e0ca");game.create_tween().tween_property(npc,"modulate",Color.WHITE,.7)
	game._save(false)
	game.audio.scene_cue("memory",game.state.volume);show_decision()
	game.event_window.present_victory()
func show_decision():
	var actions=[]
	for option in events[index].choices: actions.append(game.choice(option[0],option[1],option[2],func():choose(option)))
	var body = ""
	if events[index].id == "shore":
		body = game.t("Соня сбилась на последнем имени. Вера держит список, пока она начинает строку заново. «Если разойдёмся по разным берегам, кто ответит первой?»", "Sonya loses her place on the last name. Vera holds the register while she reads the line again. “If we leave for different shores, who answers first?”")
	game._dialog(events[index].npc+"_decision",pair(events[index].title),body,actions,false)
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
	if index>=events.size():
		game.investigations.install()
		finish()
		return
	prepare()
	game.investigations.install()
	game._notify(option[2] if game.state.language=="en" else option[1])
	game._save(false)
func finish():
	game.event_window.close();index=events.size();phase="finished";game.state.set_flag("events_finished")
	dispose_activity()
	var ending = game.t("На дальнем берегу ответили на свет фонаря. Соня подняла фонарь и услышала ответ уже с другого берега.\n\nВера сдвинулась на край скамьи. «Оставим место?» Соня села рядом. «Да. Завтра я сама приду раньше».","Someone across the water answered the lantern. Sonya raised the lantern and heard the answer from the other bank.\n\nVera moved to the end of the bench. ‘Shall we leave a place?’ Sonya sat beside her. ‘Yes. Tomorrow I'll get here first.’") if game.state.flag("events_final_together") else game.t("На дальнем берегу один за другим погасли огни. Соня дочитала список до конца и сложила его по старым сгибам.\n\n«Я боялась, что дома меня уже не ждут». Вера подала ей сумку. «Пойдём вместе до двери». Соня взяла сумку, а список оставила Вере.","The lights across the water went out one by one. Sonya read the register to the end and folded it along the old creases.\n\n‘I was afraid no one at home would be waiting.’ Vera handed over her bag. ‘I'll walk with you to the door.’ Sonya took the bag and left Vera the register.")
	if game.investigations.decided("keep_trace"):
		ending+="\n"+game.t("Свидетельство осталось на берегу рядом с семейными метками.","The witness record stayed at the shore beside the family tags.")
	elif game.investigations.decided("carry_trace"):
		ending+="\n"+game.t("К утру Вера принесла свидетельство на площадь.","By morning Vera brought the record to the square.")
	if game.investigations.decided("roll_rendezvous"):
		ending+="\n"+game.t("В обеих эпохах прозвучали оба времени встречи.","Both meeting times were heard in both eras.")
	elif game.investigations.decided("roll_relay"):
		ending+="\n"+game.t("Лев записал ответ с дальнего берега.","Lev recorded the reply from the far shore.")
	elif game.investigations.decided("roll_private"):
		ending+="\n"+game.t("Имена остались в конверте у Нади.","The names stayed in Nadia's envelope.")
	var actions=[game.choice("journal","Итоги путешествия","Journey results",journal),game.choice("credits","Титры","Credits",credits),game.choice("menu","В главное меню","Main menu",func():game._save(false);game._main_menu())]
	if game.state.flag("case_chapters"):
		actions.insert(1,game.choice("walk","Вернуться в мир","Return to the area",game._close))
	game._dialog("",game.t("Последний берег","The final shore"),ending,actions,true)
	game._save(false)
func credits():
	var text = game.t("История, мир, графика и звук — команда After Silence.\n\nLittle Adventure — Michael Bertocchi.\nGodot Engine — команда Godot.\nЛистья просеки — Pixel-Boy и AAA.\n\nЛицензии приложены к сборке.","Story, world, art and sound by the After Silence contributors.\n\nLittle Adventure by Michael Bertocchi.\nGodot Engine by the Godot contributors.\nGlade leaves by Pixel-Boy and AAA.\n\nLicenses are included in the release.")
	game._dialog("",game.t("Титры","Credits"),text,[game.choice("back","Вернуться к финалу","Back to the ending",finish),game.choice("menu","В главное меню","Main menu",game._main_menu)],false)

func journal():
	var lines=[]
	if index<events.size(): lines.append(pair(events[index].title)+"\n"+pair(events[index].context))
	for event in events:
		if not game.state.flag("event_done_"+event.id): continue
		for option in event.choices:
			if game.state.flag("event_choice_"+event.id+"_"+option[0]): lines.append("◆ "+pair(event.title)+": "+option[2 if game.state.language=="en" else 1])
	for id in game.state.relations: lines.append(game.named(id)+": "+str(game.state.relations[id]))
	game._dialog("",game.t("Журнал событий","Event journal"),"\n".join(lines),[game.choice("travel","Путешествие","Travel",game.journey.open),game.choice("close","Закрыть","Close",game._close)],false)
func _physics_process(_dt):
	visible=enabled() and not game.modal and not game.event_window.active
	if not enabled():
		if is_instance_valid(npc): npc.scripted=false
		return
	game.journey.update()
	if index>=events.size(): game.objective.text=game.t("Путешествие завершено. J — итоги.","Journey complete. J: results.");return
	if preparing: return
	var event=events[index]
	var investigation: String=game.investigations.objective()
	if not investigation.is_empty():
		game.objective.text=investigation
		return
	if phase in ["running","suspended"] and not is_instance_valid(activity):
		game.event_window.close();phase="ready"
		game._notify(game.t("Событие восстановлено. Можно начать снова.","The event was restored. You can retry."))
	if phase=="travel":
		var place=game.journey.places[event.location]
		game.objective.text=game.t("Иди: ","Go to: ")+pair(place.name) if game.comfort.route_guide else pair(place.name)+" · "+pair(place.route)
		if not game.modal and game.journey.here(event.location): arrive()
		return
	if not is_instance_valid(npc):
		prepare();game._notify(game.t("Встреча восстановлена. Загляни в «Путешествие».","The meeting was restored. Check Travel."));return
	game.objective.text=pair(event.title)+" · "+game.named(event.npc).split(" · ")[0]
	game.objective.visible=not game.modal and not game.event_window.active
	if game.modal or game.in_menu:
		npc.scripted=false
		return
	npc.scripted=false
