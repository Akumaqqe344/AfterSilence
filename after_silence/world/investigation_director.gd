extends RefCounted
const Catalog=preload("res://after_silence/core/investigation_catalog.gd")
const Marker=preload("res://after_silence/world/investigation_marker.gd")
const Activity=preload("res://after_silence/world/npc_event_activity.gd")
const Survey=preload("res://after_silence/ui/investigation_survey.gd")
const Device = preload("res://after_silence/ui/expedition_device.gd")
const EXTRA_STEPS = preload("res://after_silence/core/expedition_side_stories.gd")
const REACTIONS = preload("res://after_silence/core/expedition_reactions.gd")
const CASE_PREFIX="case_"
const EXIT="case_exit"
const ALLEY="case_bindery_stair"
const BYPASS="case_dry_bypass"
const SHORTCUTS = {
	"case_glade_return": {"zone":"bracken_clearing", "at":Vector2(343,117), "dest":"forest", "arrival":Vector2(728,840), "flag":"bracken_public", "title":["Сухая тропа к выходу","Dry path to the exit"]},
	"case_tide_return": {"zone":"tide_station", "at":Vector2(342,121), "dest":"harbor", "arrival":Vector2(789,605), "flag":"pier_line", "title":["Дальний сход на пристань","Far steps to the pier"]}
}

var game
var entries: Dictionary={}
var steps: Dictionary={}
var owners: Dictionary={}
var tracked=""
var orders: Dictionary={}
var placed: Dictionary={}
var installed_world: Node2D

func _init(owner):
	game=owner
	for base in Catalog.data.chapters+Catalog.data.sides:
		var case = base.duplicate(true)
		case.steps.append_array(EXTRA_STEPS.followups(case.id))
		entries[case.id]=case
		for step in case.steps:
			steps[step.id]=step
			owners[step.id]=case.id

func enabled() -> bool:
	return game.state.flag("event_campaign") and not game.in_menu

func text(pair: Array) -> String:
	return game.t(pair[0],pair[1])

func done(id: String) -> bool:
	return game.state.flag("case_done_"+id)

func seen(id: String) -> bool:
	return game.state.flag("case_read_"+id)

func decided(id: String) -> bool:
	return game.state.flag("case_choice_"+id)

func active_chapter() -> Dictionary:
	if not enabled() or not game.state.flag("case_chapters") or not is_instance_valid(game.events_controller):
		return {}
	var director=game.events_controller
	if director.index>=director.events.size(): return {}
	var event_id: String=director.events[director.index].id
	for definition in Catalog.data.chapters:
		var case: Dictionary = entries[definition.id]
		if case.before==event_id and not done(case.id) and has_expansion(case):
			return case
	return {}

func barrier(event_id: String) -> bool:
	var case=active_chapter()
	return not case.is_empty() and case.before==event_id

func has_expansion(entry: Dictionary) -> bool:
	return not entry.get("expansion", false) or game.state.flag("expedition_0330")

func available(case: Dictionary) -> bool:
	if not enabled() or not has_expansion(case): return false
	if done(case.id): return true
	if not case.before.is_empty():
		return active_chapter().get("id","")==case.id
	return case.after.is_empty() or game.state.flag("event_done_"+case.after)

func visible_steps(case: Dictionary) -> Array:
	var result=[]
	for step in case.steps:
		if not has_expansion(step): continue
		if step.has("if_branch") and not decided(step.if_branch): continue
		if step.has("unless_branch") and decided(step.unless_branch): continue
		result.append(step)
	return result

func next_step(case: Dictionary) -> Dictionary:
	var relevant=visible_steps(case)
	for step in relevant:
		if not seen(step.id): return step
	return relevant.back() if not relevant.is_empty() else {}

func ready_step(step: Dictionary, first: Dictionary) -> bool:
	return step.id == first.get("id", "") or (step.has("group") and step.group == first.get("group", ""))

func _clear_markers() -> void:
	for id in placed:
		var node=placed[id]
		if is_instance_valid(node) and node.get_parent()!=null:
			node.get_parent().remove_child(node)
			node.queue_free()
	if is_instance_valid(installed_world):
		installed_world.interactables=installed_world.interactables.filter(func(spot): return not placed.has(spot.id))
	placed={}

func install() -> void:
	_clear_markers()
	installed_world=game.world
	if not enabled() or not is_instance_valid(installed_world): return
	var zone: String=game.world.zone
	if Catalog.data.rooms.has(zone):
		var room=Catalog.data.rooms[zone]
		_place(EXIT,Catalog.point(room.exit),"door",true,32)
	if zone=="records_annex" and done("copies"):
		_place(ALLEY,Vector2(511,382),"door",true,34)
	if zone=="pump_chamber" and decided("leave_bypass") and game.state.flag("event_done_crowd"):
		_place(BYPASS,Vector2(485,377),"flag",true,36)
	for case in entries.values():
		if not available(case): continue
		var first=next_step(case)
		for step in visible_steps(case):
			if step.zone!=zone: continue
			if done(case.id) and step.kind!="door": continue
			if seen(step.id) and step.kind!="door" and first.get("id","")!=step.id: continue
			var ready: bool=ready_step(step,first) and not seen(step.id) and not done(case.id)
			_place(Catalog.spot(step.id),Catalog.point(step.at),step.art,ready,42)
	if zone=="town":
		if decided("ring_together"): _place("case_reward_lamp",Vector2(639,601),"lamp",false,42)
		if decided("redact"): _place("case_reward_extract",Vector2(804,487),"papers",false,35)
		if done("thread"): _place("case_reward_thread",Vector2(510,616),"ribbon",false,34)
		if decided("carry_trace"): _place("case_reward_record",Vector2(692,621),"stamp",false,43)
	if zone=="forest" and decided("forest_visible"):
		_place("case_reward_forest",Vector2(743,859),"post",false,43)
	if zone=="harbor" and decided("keep_trace"):
		_place("case_reward_shore",Vector2(804,701),"flag",false,39)
	for id in SHORTCUTS:
		var route: Dictionary = SHORTCUTS[id]
		if zone == route.zone and decided(route.flag):
			_place(id, route.at, "flag", false, 34)
	for id in REACTIONS.OBJECTS:
		var object: Dictionary = REACTIONS.OBJECTS[id]
		if zone == object.zone and game.state.flag(object.flag):
			_place(id, object.point, object.art, false, 38)

func _place(id: String, point: Vector2, art: String, ready: bool, extent: float):
	var place: Vector2=game.world.recover(point)
	game.world.spot(id,place,"none")
	var mark=Marker.new()
	mark.kind=art
	mark.position=place
	mark.item_size=Vector2(extent,extent)
	mark.ready_to_read=ready
	mark.reduced=game.comfort.reduce_motion
	game.world.sorter.add_child(mark)
	placed[id]=mark

func hit(at: Vector2) -> String:
	if not enabled(): return ""
	var best=""
	var radius=35.0
	for id in placed:
		var mark=placed[id]
		if not is_instance_valid(mark): continue
		var distance: float=at.distance_to(mark.position)
		if distance<radius:
			best=id
			radius=distance
	return best

func label(id: String) -> String:
	if REACTIONS.OBJECTS.has(id): return text(REACTIONS.OBJECTS[id].title)
	if SHORTCUTS.has(id): return text(SHORTCUTS[id].title)
	var step: Dictionary=steps.get(id.trim_prefix(CASE_PREFIX),{})
	if not step.is_empty(): return text(step.title)
	if id==EXIT: return game.t("Выйти","Leave")
	if id==ALLEY: return game.t("Лестница в переулок","Stair to the alley")
	if id==BYPASS: return game.t("Сухой обход до пристани","Dry bypass to the pier")
	return game.t("Осмотреть след расследования","Inspect the investigation marker")

func locate(zone: String) -> String:
	if Catalog.data.rooms.has(zone): return text(Catalog.data.rooms[zone].name)
	for place in game.journey.places.values():
		if place.zone==zone: return text(place.name)
	if zone=="shop": return game.t("Лавка","Shop")
	return game.t("Город","Town")

func portal_for(from: String, to: String) -> String:
	if Catalog.data.rooms.has(from) and Catalog.data.rooms[from].parent==to: return EXIT
	if Catalog.data.rooms.has(to) and Catalog.data.rooms[to].parent==from:
		return Catalog.spot(Catalog.data.rooms[to].gate)
	return ""

func guide() -> Dictionary:
	var case=active_chapter()
	if entries.has(tracked) and available(entries[tracked]) and not done(tracked):
		case=entries[tracked]
	if case.is_empty(): return {}
	var step=next_step(case)
	if step.is_empty(): return {}
	var zone: String=game.state.zone
	var target: String=Catalog.spot(step.id)
	if zone!=step.zone:
		var edge: Array=game.npcs.navigation.next_portal(zone,step.zone,game.state.echo)
		if edge.is_empty(): return {}
		target=portal_for(zone,edge[2])
		if target.is_empty(): target=game.journey._portal_id(zone,edge[2])
	for spot in game.world.interactables:
		if spot.id==target:
			var title=label(target) if target.begins_with(CASE_PREFIX) else game.journey._portal_label(target)
			return {"point":spot.position,"label":title,"action":true,"id":target,"range":33.0}
	return {}

func objective() -> String:
	var case=active_chapter()
	if case.is_empty(): return ""
	var step=next_step(case)
	if step.is_empty(): return text(case.title)
	return text(step.title)+" · "+(game.t("Дело","Case") if game.state.zone==step.zone else locate(step.zone))

func interact(id: String) -> bool:
	if not id.begins_with(CASE_PREFIX): return false
	if not enabled() or not placed.has(id) or not is_instance_valid(placed[id]): return true
	if game.player.position.distance_to(placed[id].position)>48.0: return true
	if id==EXIT:
		var room: Dictionary=Catalog.data.rooms[game.state.zone]
		game._travel(room.parent,Catalog.point(room.from)+Vector2(0,26))
		return true
	if id==ALLEY:
		game.state.set_flag("case_used_bindery_stair")
		game._travel("town",Vector2(684,242))
		return true
	if id==BYPASS:
		game.state.set_flag("case_used_dry_bypass")
		game._travel("harbor",Vector2(776,691))
		return true
	if SHORTCUTS.has(id):
		var route: Dictionary = SHORTCUTS[id]
		game.state.set_flag("used_" + id)
		game._travel(route.dest, route.arrival)
		return true
	if not steps.has(id.trim_prefix(CASE_PREFIX)):
		_reward(id)
		return true
	var step: Dictionary=steps[id.trim_prefix(CASE_PREFIX)]
	var case: Dictionary=entries[owners[step.id]]
	var first=next_step(case)
	if not seen(step.id) and not ready_step(step, first):
		game._notify(game.t("Сначала: ","First: ")+text(first.title))
		return true
	game.player.inspect_time=.6
	game.audio.touch(game.player.position,game.state.volume)
	match step.kind:
		"door":
			var room: Dictionary=Catalog.data.rooms[step.room]
			game.state.set_flag("case_read_"+step.id)
			game._travel(step.room,Catalog.point(room.entry))
		"question":
			if seen(step.id): _resolution(case)
			else: _question(step)
		"sequence":
			if seen(step.id): _resolution(case)
			else: _sequence(step)
		"survey":
			if seen(step.id): _resolution(case)
			else: _survey(step)
		"trial": open_trial(step.id)
		"device":
			if seen(step.id): _resolution(case)
			else: _device(step)
		"witness":
			if seen(step.id): _resolution(case)
			else: _witness(step)
		_:
			var actions=[]
			if step.kind=="listen":
				actions.append(game.choice("listen","Прослушать сигнал","Replay the signal",func():game.audio.case_signal(step.tones,game.state.volume)))
			if seen(step.id):
				actions.append(game.choice("remember","Вернуться к делу","Return to the case",func():_resolution(case)))
			elif step.id == "roll_signal":
				actions.append(game.choice("remember","Поднять фонарь","Raise the lantern",func():
					game.audio.case_signal([392, 523, 392], game.state.volume)
					_resolve_step(step)))
			else:
				actions.append(game.choice("remember","Записать улику","Record the clue",func():_resolve_step(step)))
			actions.append(game.choice("back","Отойти","Step back",game._close))
			game._dialog("",text(step.title),text(step.body),actions,false)
	return true

func _question(step: Dictionary, wrong: bool=false):
	var actions=[]
	for i in step.options.size():
		var answer: Array=step.options[i]
		actions.append(game.choice("answer_"+str(i),answer[0],answer[1],func():
			if i==int(step.correct): _resolve_step(step)
			else: _question(step,true)))
	actions.append(game.choice("review","Сверить записи","Review the clues",details.bind(owners[step.id])))
	actions.append(game.choice("back","Отойти","Step back",game._close))
	var description=text(step.body)
	if wrong: description+="\n"+game.t("Эта версия не совпадает с уликами. Записи можно перечитать.","This account conflicts with the clues. You can review your notes.")
	game._dialog("",text(step.title),description,actions,false)

func _sequence(step: Dictionary, wrong: bool=false):
	var prefix: Array=orders.get(step.id,[])
	orders[step.id]=prefix
	var actions=[]
	for i in step.options.size():
		if i in prefix: continue
		var option: Array=step.options[i]
		actions.append(game.choice("order_"+str(i),option[0],option[1],_add_order.bind(step,i)))
	if not prefix.is_empty():
		actions.append(game.choice("erase","Сбросить порядок","Clear the order",func():orders.erase(step.id);_sequence(step)))
	actions.append(game.choice("review","Сверить записи","Review the clues",details.bind(owners[step.id])))
	actions.append(game.choice("back","Отойти","Step back",game._close))
	var names=PackedStringArray()
	for mark in prefix: names.append(text(step.options[mark]))
	var description=text(step.body)
	if wrong: description+="\n"+game.t("Порядок не совпал. Сверь его с записями.","That order does not fit. Compare it with your notes.")
	if not names.is_empty(): description+="\n"+game.t("Порядок: ","Order: ")+" → ".join(names)
	game._dialog("",text(step.title),description,actions,false)

func _add_order(step: Dictionary,index: int):
	var prefix: Array=orders.get(step.id,[])
	if index in prefix: return
	prefix.append(index)
	if prefix.size()<step.order.size():
		_sequence(step)
		return
	var correct=true
	for i in prefix.size():
		if prefix[i]!=int(step.order[i]): correct=false
	orders.erase(step.id)
	if correct: _resolve_step(step)
	else: _sequence(step,true)

func _survey(step: Dictionary,angle: int=-1):
	var names=[["Север","North"],["Восток","East"],["Юг","South"],["Запад","West"]]
	var actions=[]
	for i in names.size():
		actions.append(game.choice("look_"+str(i),names[i][0],names[i][1],_survey.bind(step,i)))
	if angle==int(step.correct):
		actions.push_front(game.choice("aligned","Записать совпадение","Record alignment",_resolve_step.bind(step)))
	actions.append(game.choice("back","Отойти","Step back",game._close))
	var clue=game.t("Выбери точку, откуда два луча сходятся на одном знаке.","Choose a viewpoint from which both beams land on the same mark.")
	if angle==int(step.correct): clue=text(step.body)
	game._dialog("",text(step.title),clue,actions,false)
	var diagram=Survey.new()
	diagram.lookout=angle
	diagram.correct=int(step.correct)
	game.column.add_child(diagram)
	game.column.move_child(diagram,2)
	var directions=HBoxContainer.new()
	directions.add_theme_constant_override("separation",6)
	game.column.add_child(directions)
	game.column.move_child(directions,3)
	var views: Array[Button]=[]
	for i in names.size():
		var button: Button=game.buttons["look_"+str(i)]
		button.reparent(directions,false)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.alignment=HORIZONTAL_ALIGNMENT_CENTER
		views.append(button)
	game._wire_dialog_focus()
	for i in views.size():
		views[i].focus_neighbor_left=views[i].get_path_to(views[posmod(i-1,views.size())])
		views[i].focus_neighbor_right=views[i].get_path_to(views[(i+1)%views.size()])
	if angle!=int(step.correct):
		views[maxi(angle,0)].grab_focus()

func open_trial(id: String, fresh: bool=false):
	if not steps.has(id) or seen(id): return
	var step: Dictionary=steps[id]
	if fresh: game.state.case_trials.erase(id)
	var mode="balance" if step.variant=="weights" else "signal_grid"
	var activity=Activity.new({"mode":mode,"variant":step.variant})
	activity.trial.restore(game.state.case_trials.get(id,[]))
	game._close()
	game.event_window.open_investigation(id,activity,text(step.title),text(step.body),func():
		game.event_window.close()
		game.state.case_trials.erase(id)
		_resolve_step(step)
		game.event_window.present_victory())

func _device(step: Dictionary):
	var panel = Device.new()
	var state: Array = game.state.case_trials.get(step.id, [])
	panel.configure(step, state, game.state.language == "ru", game.comfort.reduce_motion)
	game._dialog("", text(step.title), text(step.body), [game.choice("back","Отойти от механизма","Step away",game._close)], false)
	game.column.add_child(panel)
	game.column.move_child(panel, 2)
	panel.changed.connect(func(values: Array, accepted: bool):
		game.state.case_trials[step.id] = values
		if accepted:
			game.audio.ping(game.state.volume)
		else:
			game.audio.touch(game.player.position, game.state.volume)
		game._save(false))
	panel.solved.connect(func():
		game.state.case_trials.erase(step.id)
		_resolve_step(step))
	game._wire_dialog_focus()
	panel.focus_first()

func _witness(step: Dictionary):
	var actions = []
	for option in step.options:
		if not REACTIONS.matches(game.state, option.get("requires", [])): continue
		actions.append(game.choice(option.id, option.title[0], option.title[1], func():
			game.state.set_flag("case_choice_" + option.id)
			_resolve_step(step)
			game._dialog("", game.named("sonya"), text(option.result), [game.choice("close","Вернуться на площадь","Return to the square",game._close)], false)))
	actions.append(game.choice("back","Отойти","Step back",game._close))
	game._dialog("", text(step.title), text(step.body), actions, false)

func _resolve_step(step: Dictionary):
	if not seen(step.id):
		game.state.set_flag("case_read_"+step.id)
		game.audio.ping(game.state.volume)
		if step.id in ["tide_winch", "bracken_lens"]:
			game._build_world(game.state.zone, game.player.position)
	_resolution(entries[owners[step.id]])
	game._save(false)

func _resolution(case: Dictionary):
	if done(case.id):
		details(case.id)
		return
	for step in visible_steps(case):
		if not seen(step.id):
			game._close()
			install()
			game._notify(game.t("Следующая улика: ","Next clue: ")+text(step.title))
			return
	if case.branches.is_empty():
		_complete(case)
		return
	var actions=[]
	for branch in case.branches:
		var caption: Array=branch.title
		actions.append(game.choice(branch.id,caption[0],caption[1],_complete.bind(case,branch)))
	var message=game.t("Реши, кому останется эта запись.","Decide who will keep this record.")
	game._dialog("",text(case.title),message,actions,false)

func _complete(case: Dictionary,branch: Dictionary={}):
	if done(case.id): return
	var record=game.t("Улики сверены. Можно двигаться дальше.","The evidence agrees. You can move on.")
	if not branch.is_empty():
		game.state.set_flag("case_choice_"+branch.id)
		record=text(branch.result)
	game.state.set_flag("case_done_"+case.id)
	if not case.owner.is_empty(): game.npcs.change_relation(case.owner,1)
	if case.before.is_empty(): game.state.tokens=mini(999,game.state.tokens+2)
	game.state.history.append({"speaker":text(case.title),"body":record})
	if tracked==case.id: tracked=""
	install()
	game._save(false)
	game._dialog("",text(case.title),record,[game.choice("close","Вернуться в мир","Return to the area",game._close)],false)

func journal():
	var actions=[]
	var case=active_chapter()
	if not case.is_empty():
		actions.append(game.choice("chapter",text(case.title),text(case.title),details.bind(case.id)))
	for definition in Catalog.data.sides:
		var side: Dictionary = entries[definition.id]
		if not available(side): continue
		var title=("✓ " if done(side.id) else "◇ ")+text(side.title)
		actions.append(game.choice(side.id,title,title,details.bind(side.id)))
	for chapter in Catalog.data.chapters:
		if not done(chapter.id): continue
		var title="✓ "+text(chapter.title)
		actions.append(game.choice(chapter.id,title,title,details.bind(chapter.id)))
	actions.append(game.choice("events","Встречи и решения","Meetings and decisions",game.events_controller.journal))
	actions.append(game.choice("close","Закрыть","Close",game._close))
	game._dialog("",game.t("Доска расследований","Investigation board"),"",actions,false)

func details(id: String):
	var case: Dictionary=entries[id]
	var lines=[text(case.intro)]
	for step in visible_steps(case):
		if seen(step.id): lines.append(text(step.title)+"\n"+text(step.body))
		elif step.id==next_step(case).get("id",""): lines.append(game.t("Дальше: ","Next: ")+text(step.title)+" · "+locate(step.zone))
	var actions=[]
	if not done(id):
		actions.append(game.choice("track","Показать маршрут","Track this case",func():tracked=id;game._close()))
	actions.append(game.choice("back","К доске","Back to the board",journal))
	game._dialog("",text(case.title),"\n\n".join(lines),actions,false)

func followup(npc: String) -> bool:
	if not enabled(): return false
	var case=active_chapter()
	if not case.is_empty() and case.owner==npc:
		var step=next_step(case)
		var message=text(case.intro)
		if not step.is_empty(): message+="\n"+game.t("Дальше: ","Next: ")+text(step.title)
		game._dialog("",game.named(npc),message,[game.choice("case","Открыть дело","Open case",details.bind(case.id)),game.choice("close","Понятно","Got it",game._close)],false)
		return true
	var director=game.events_controller
	if director.owns(npc): return false
	for response in REACTIONS.NPCS.get(npc, []):
		var key = "heard_" + String(response.flag)
		if game.state.flag(response.flag) and not game.state.flag(key):
			game.state.set_flag(key)
			game._save(false)
			if game.actors.has(npc): game.actors[npc].inspect_time = .6
			game._dialog("", game.named(npc) + " · " + text(response.title), text(response.body), [game.choice("close","Продолжить","Continue",game._close)], false)
			return true
	for definition in Catalog.data.sides:
		var side: Dictionary = entries[definition.id]
		if side.owner!=npc or not available(side): continue
		var key="case_npc_"+side.id+("_done" if done(side.id) else "_intro")
		if game.state.flag(key): continue
		game.state.set_flag(key)
		var message=text(side.intro) if not done(side.id) else game.t("Здесь заметили твою помощь.","People here noticed what you did.")
		game._dialog("",game.named(npc),message,[game.choice("case","Открыть запись","Open record",details.bind(side.id)),game.choice("close","Продолжить","Continue",game._close)],false)
		return true
	return false

func _reward(id: String):
	if REACTIONS.OBJECTS.has(id):
		var object: Dictionary = REACTIONS.OBJECTS[id]
		game._dialog("", text(object.title), text(object.body), [game.choice("close","Продолжить","Continue",game._close)], false)
		return
	var descriptions={
		"case_reward_lamp":["Фонарь горит ровно. Сюда приходят ждать друг друга.","The lantern burns steadily. People come here to wait for one another."],
		"case_reward_extract":["Мара вывесила две даты. Имени свидетеля на листе нет.","Mara posted both dates. The witness's name stays off the sheet."],
		"case_reward_thread":["Надя закрепила ответ рядом со скамьёй.","Nadia tied the reply beside the bench."],
		"case_reward_record":["У списка теперь есть дописанная строка со знаком семьи.","A new line on the list carries the family's tag."],
		"case_reward_forest":["По этому знаку можно выйти вместе, даже если огни погаснут.","The marker can guide people out together even when the lights go out."],
		"case_reward_shore":["На последнем столбе остался знак для тех, кто вернётся.","The last post carries a mark for people who return."]
	}
	if descriptions.has(id):
		game._dialog("",game.t("След решения","A choice remembered"),text(descriptions[id]),[game.choice("close","Дальше","Continue",game._close)],false)
