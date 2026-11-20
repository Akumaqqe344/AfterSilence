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
func guide_target() -> Dictionary:
	var director=game.events_controller
	if not director.enabled() or director.index>=director.events.size(): return {}
	var event=director.events[director.index]
	var place=places[event.location]
	var label=pair(place.name)
	var zone=game.state.zone
	if zone!=place.zone:
		var edge: Array=game.npcs.navigation.next_portal(zone,place.zone,game.state.echo)
		if edge.is_empty() or not zone_allowed(edge[2]): return {}
		var portal=_portal_id(zone,edge[2])
		for spot in game.world.interactables:
			if spot.id==portal:
				return {"point":spot.position,"label":_portal_label(portal),"action":true,"id":portal,"range":28.0}
		return {}
	if director.phase=="action":
		return {"point":director.preparation_point(),"label":game.t("Предмет для задания","Quest item"),"action":true,"id":"event_preparation","range":55.0}
	if director.phase!="travel" and is_instance_valid(director.npc):
		var ready=director.phase in ["ready","suspended","decision"]
		return {"point":director.npc.position,"label":game.named(event.npc).split(" · ")[0],"action":ready,"id":event.npc,"range":52.0}
	var point=Vector2(place.point[0],place.point[1])
	return {"point":point,"label":label,"action":false,"id":event.location,"range":65.0}
func _portal_id(from: String,to: String) -> String:
	if from=="town":
		return {"library":"to_library","forest":"to_forest","orchard":"visit_orchard","harbor":"visit_harbor","shop":"visit_shop"}.get(to,to)
	if from in ["orchard","harbor"]: return "district_return"
	if from in game.Homes.IDS: return "leave_home"
	if from=="shop": return "leave_shop"
	return "to_town"
func _portal_label(id: String) -> String:
	if id in game.Homes.IDS: return pair(game.Homes.NAMES[game.Homes.IDS.find(id)])
	match id:
		"to_library": return game.t("Вход в библиотеку","Library entrance")
		"to_forest": return game.t("Тропа в лес","Forest trail")
		"visit_orchard": return game.t("Дорога в сад","Orchard road")
		"visit_harbor": return game.t("Дорога к пристани","Harbor road")
		_: return game.t("Выход в город","Exit to town")
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
		if resident.zone==place.zone and Vector2(resident.x,resident.y).distance_to(Vector2(place.point[0],place.point[1]))<220: names.append(game.named(npc_id))
	var director=game.events_controller
	if director.index<director.events.size() and director.events[director.index].location==id and director.phase!="travel":
		var active_name=game.named(director.events[director.index].npc)
		if active_name not in names: names.append(active_name)
	text+="\n"+game.t("Сейчас здесь: ","Here now: ")+(game.t("тихо","quiet") if names.is_empty() else ", ".join(names))
	if director.index<director.events.size() and director.events[director.index].location==id: text+="\n"+game.t("Событие: ","Event: ")+pair(director.events[director.index].title)
	if game.state.flag("place_changed_"+id): text+="\n"+game.t("Твои решения изменили это место.","Your choices changed this place.")
	if not game.state.history.is_empty(): text+="\n"+game.t("Последний выбор: ","Last choice: ")+str(game.state.history.back().get("body",""))
	game._dialog("",pair(place.name),text,[game.choice("back","Все места","All places",open),game.choice("close","Вернуться в мир","Return to the world",game._close)],false)
