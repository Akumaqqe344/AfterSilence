extends RefCounted
var game
var places: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/locations.json"))
func _init(owner): game=owner
func pair(value: Array) -> String: return game.Story.pair(value,game.state.language)
func unlocked(id: String) -> bool:
	if not places.has(id): return false
	return places[id].requires=="" or game.state.flag("event_done_"+places[id].requires) or game.state.flag("events_finished")
func reason(id: String) -> String:
	if unlocked(id): return game.t("Путь открыт.","The route is open.")
	var name=places[id].requires
	for event in game.events_controller.events:
		if event.id==name: name=pair(event.title);break
	return game.t("Сначала: ","First: ")+name
func here(id: String) -> bool:
	if not places.has(id) or game.state.zone!=places[id].zone: return false
	var p=places[id].point
	return game.player.position.distance_to(Vector2(p[0],p[1]))<180
func current() -> String:
	var nearest="square";var distance=INF
	for id in places:
		if places[id].zone!=game.state.zone: continue
		var p=places[id].point
		var d=game.player.position.distance_to(Vector2(p[0],p[1]))
		if d<distance: distance=d;nearest=id
	return nearest
func update():
	for id in places:
		if here(id) and not game.state.flag("place_visited_"+id): game.state.set_flag("place_visited_"+id)
func zone_allowed(zone: String) -> bool:
	if zone in ["town","shop"]: return true
	for id in places:
		if places[id].zone==zone and unlocked(id): return true
	return false
func open():
	var actions=[]
	var selected=current()
	for id in places:
		var marker="◈ " if id==selected else "◆ " if game.state.flag("place_visited_"+id) else "◇ "
		var label=marker+pair(places[id].name)+(game.t(" · закрыто"," · closed") if not unlocked(id) else "")
		actions.append(game.choice(id,label,label,func():details(id)))
	actions.append(game.choice("close","Вернуться в мир · Esc","Return · Esc",game._close))
	game._dialog("",game.t("Путешествие","Travel"),game.t("Ты здесь: ","You are here: ")+pair(places[selected].name)+"\n"+game.t("Выбери место, чтобы узнать дорогу. Переходи через мир.","Select a place for directions. Travel through the world."),actions,false)
	if game.buttons.has(selected): game.buttons[selected].grab_focus()
func details(id: String):
	var place=places[id]
	var text=pair(place.description)+"\n"+reason(id)+"\n"+game.t("Путь: ","Route: ")+pair(place.route)
	var names=[]
	for npc_id in game.state.residents:
		var resident=game.state.residents[npc_id]
		if resident.zone==place.zone and not game.state.flag("event_left_"+npc_id) and Vector2(resident.x,resident.y).distance_to(Vector2(place.point[0],place.point[1]))<220: names.append(game.named(npc_id))
	var director=game.events_controller
	if director.index<director.events.size() and director.events[director.index].location==id and director.phase!="travel":
		var active_name=game.named(director.events[director.index].npc)
		if active_name not in names: names.append(active_name)
	text+="\n"+game.t("Сейчас здесь: ","Here now: ")+(game.t("тихо","quiet") if names.is_empty() else ", ".join(names))
	if director.index<director.events.size() and director.events[director.index].location==id: text+="\n"+game.t("Событие: ","Event: ")+pair(director.events[director.index].title)
	if game.state.flag("place_changed_"+id): text+="\n"+game.t("Твои решения изменили это место.","Your choices changed this place.")
	if not game.state.history.is_empty(): text+="\n"+game.t("Последний выбор: ","Last choice: ")+str(game.state.history.back().get("body",""))
	game._dialog("",pair(place.name),text,[game.choice("back","Все места","All places",open),game.choice("close","Вернуться в мир","Return to the world",game._close)],false)
