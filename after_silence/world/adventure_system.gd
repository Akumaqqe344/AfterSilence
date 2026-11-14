extends Control
var game
var expanded=false
var routes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/district_routes.json"))
var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/activities.json"))

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func unlocked(zone: String) -> bool:
	if game.state.flag("event_campaign"): return game.journey.zone_allowed(zone)
	return not game.state.flag("rift_mode") or game.state.flag("rift_finished") or game.state.flag("district_"+zone) or game.state.flag("rift_q03_done" if zone=="orchard" else "rift_q05_done")

func populate():
	var world=game.world
	if game.state.flag("event_campaign"):
		if world.zone=="town":
			world.spot("visit_orchard",Vector2(1710,500),"none")
			world.spot("visit_harbor",Vector2(600,1200),"none")
		elif world.zone in ["orchard","harbor"]: world.spot("district_return",Vector2(600,740),"none")
		if is_instance_valid(game.living): game.living.populate()
		return
	for request in data.requests:
		if request.zone!=world.zone: continue
		for i in range(request.points.size()):
			var id="collect_"+request.id+"_"+str(i)
			if not game.state.flag(id): world.spot(id,Vector2(request.points[i][0],request.points[i][1]),request.kind)
	if world.zone=="town":
		world.spot("visit_orchard",Vector2(1710,500),"trace")
		world.spot("visit_harbor",Vector2(600,1200),"trace")
	elif world.zone in ["orchard","harbor"]:
		world.spot("district_return",Vector2(600,740),"trace")
		world.spot("district_rest",Vector2(600,460),"none")
	var inside=world.zone in game.Homes.IDS or world.zone in ["library","shop"]
	world.spot("hotspot_lamp",Vector2(420,400) if world.zone in game.Homes.IDS or world.zone=="shop" else Vector2(720,472),"lamp" if inside else "street_lamp")
	if world.zone=="town":
		# One existing noticeboard carries the directions; no second board in the road.
		world.spot("hotspot_sign",Vector2(780,480),"none")
	elif world.zone in ["orchard","harbor"]:
		world.spot("hotspot_sign",Vector2(666,690),"signpost")
	sync_lamp()
	if is_instance_valid(game.living): game.living.populate()

func sync_lamp():
	var light=game.world.get_node_or_null("InteractiveLamp")
	var anchor=Vector2.ZERO
	for prop in game.world.sorter.get_children():
		if prop.get_meta("hotspot_id","")=="hotspot_lamp":
			anchor=prop.position+prop.light_anchor()
			prop.lit=game.state.flag("lamp_"+game.state.zone)
			prop.queue_redraw()
	if game.state.flag("lamp_"+game.state.zone):
		if not is_instance_valid(light):
			game.world.add_light(anchor)
			game.world.get_child(-1).name="InteractiveLamp"
	elif is_instance_valid(light):
		game.world.remove_child(light)
		light.queue_free()

func count(request: Dictionary) -> int:
	var value=0
	for i in range(request.points.size()):
		if game.state.flag("collect_"+request.id+"_"+str(i)): value+=1
	return value

func handle(id: String) -> bool:
	if id=="village_hints": game.journey.open() if game.state.flag("event_campaign") else game._quest_help();return true
	if id.begins_with("hamlet_house_"):
		var i=int(id.trim_prefix("hamlet_house_"))
		if i<0 or i>4: return true
		if game.state.flag("event_campaign") and not game.journey.zone_allowed(game.Homes.IDS[i%4]):
			game._notify(game.t("Путь пока закрыт. T — причина открытия.","This route is closed. T shows how it opens."));return true
		game.state.set_flag("hamlet_return_"+str(i))
		game._travel(game.Homes.IDS[i%4],Vector2(320,395));return true
	if id=="leave_home":
		var homes=[Vector2(1250,760),Vector2(1550,760),Vector2(1550,320),Vector2(360,1210),Vector2(950,1210)]
		for i in range(homes.size()):
			if game.state.flag("hamlet_return_"+str(i)):
				game.state.set_flag("hamlet_return_"+str(i),false)
				game._travel("town",homes[i]);return true
	if id=="visit_shop": game._travel("shop",Vector2(320,395));return true
	if id=="leave_shop": game._travel("town",Vector2(350,500));return true
	if id=="shop_counter": game.shop.open();return true
	if id=="riverside_rest":
		game.state.charges=3
		game._notify(game.t("Тихая вода. Можно перевести дух.","Quiet water. Take a breath."));return true
	if is_instance_valid(game.living) and game.living.handle(id): return true
	if id.begins_with("district_house_"):
		var index=int(id.trim_prefix("district_house_"))
		if index<0 or index>2: return true
		if game.state.flag("event_campaign") and not game.journey.zone_allowed(game.Homes.IDS[index]):
			game._notify(game.t("Путь пока закрыт. T — причина открытия.","This route is closed. T shows how it opens."));return true
		game.state.set_flag("visit_"+game.state.zone+"_"+str(index))
		game._travel(game.Homes.IDS[index],Vector2(320,395));return true
	if id=="leave_home":
		for zone in ["orchard","harbor"]:
			for i in range(3):
				var flag="visit_"+zone+"_"+str(i)
				if game.state.flag(flag):
					game.state.set_flag(flag,false)
					game._travel(zone,Vector2([280,600,920][i],355));return true
	if id.begins_with("visit_"):
		var zone=id.trim_prefix("visit_")
		if unlocked(zone) and routes.has(zone): game._travel(zone,Vector2(routes[zone].from_town[0],routes[zone].from_town[1]))
		else: game._dialog("",game.t("Дорога закрыта","Road closed"),game.t("Помоги жителям или продолжи историю.","Help the residents or continue the story."),[game.choice("close","Хорошо","OK",game._close)],false)
		return true
	if id=="district_return":
		var p=routes[game.state.zone].return_town
		game._travel("town",Vector2(p[0],p[1]));return true
	if id=="district_rest":
		game.state.charges=3
		game._notify(game.t("Отдохнули. Силы восстановлены.","Rested. Energy restored."));return true
	if id.begins_with("collect_"):
		for request in data.requests:
			for i in range(request.points.size()):
				if id!="collect_"+request.id+"_"+str(i): continue
				if game.state.flag(id): return true
				game.state.set_flag(id)
				game.world.interactables=game.world.interactables.filter(func(spot): return spot.id!=id)
				for prop in game.world.sorter.get_children():
					if prop.has_meta("hotspot_id") and prop.get_meta("hotspot_id")==id: prop.queue_free()
				var complete=count(request)==request.points.size()
				if complete:
					game.state.tokens=mini(999,game.state.tokens+2)
					game.state.set_flag("district_"+request.reward)
					game.npcs.change_relation(request.npc,1)
					game.living.remember(request.npc,"collection")
				game.audio.ping(game.state.volume)
				game._notify(game.t(request.title[0],request.title[1])+" %d/%d"%[count(request),request.points.size()]+(game.t(" • выполнено!"," • complete!") if complete else ""))
				game._save(false)
				return true
	if id=="hotspot_lamp":
		game.state.set_flag("lamp_"+game.state.zone,not game.state.flag("lamp_"+game.state.zone))
		sync_lamp()
		game._notify(game.t("Фонарь включён","Lantern on") if game.state.flag("lamp_"+game.state.zone) else game.t("Фонарь выключен","Lantern off"))
		game._save(false);return true
	if id=="hotspot_sign":
		var text=game.t("Сад — восточная дорога. Пристань — южная. M: карта.","Orchard: east road. Harbor: south road. M: map.")
		game._dialog("",game.t("Указатель","Signpost"),text,[game.choice("close","Идём!","Let's go!",game._close)],false)
		return true
	return false

func label(id: String) -> String:
	if id=="village_hints": return game.t("Доска подсказок","Hint board")
	if id.begins_with("hamlet_house_"): return game.t("Зайти в гости","Visit home")
	if id in ["visit_shop","leave_shop","shop_counter","riverside_rest"]:
		return game.t({"visit_shop":"Войти в лавку","leave_shop":"На площадь","shop_counter":"Купить припасы","riverside_rest":"Отдохнуть у реки"}[id],{"visit_shop":"Enter shop","leave_shop":"To the square","shop_counter":"Buy supplies","riverside_rest":"Rest by the river"}[id])
	if id in ["hotspot_window","hotspot_furniture"]: return game.living.label(id)
	if id=="home_storage": return game.t("Домашний сундук","Home chest")
	if id.begins_with("personal_") or id.begins_with("cache_") or id=="clinic_rest": return game.living.label(id)
	if id.begins_with("district_house_"): return game.t("Войти в дом","Enter home")
	if id.begins_with("collect_"): return game.t("Подобрать предмет","Pick up item")
	return game.t({"visit_orchard":"В садовый посёлок","visit_harbor":"На пристань","district_return":"В город","district_rest":"Отдохнуть","hotspot_lamp":"Переключить фонарь","hotspot_sign":"Прочитать указатель"}.get(id,id),id)

func _process(_dt):
	visible=not game.in_menu and not game.modal and not game.rift.active and not game.battle.active
	queue_redraw()

func _unhandled_input(event):
	if game.state.flag("event_campaign"): return
	if not visible: return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and not expanded:
		game.camera.position-=event.relative/game.camera.zoom
		game.camera.position=game.camera.position.round()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_M:
		expanded=not expanded
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var point=get_global_mouse_position()
		if Rect2(500,72,130,94).has_point(point): expanded=not expanded;return
		if expanded: expanded=false;return
		var world_point=game.world.get_global_transform_with_canvas().affine_inverse()*point
		for spot in game.world.interactables:
			if not game.can_interact(spot.id): continue
			if spot.position.distance_to(world_point)<22 and game.player.position.distance_to(spot.position)<60:
				game.interact(spot.id);get_viewport().set_input_as_handled();return
		game.player.set_meta("click_route",game.world.path_between(game.player.position,world_point))

func _draw():
	if game.state.flag("event_campaign"): return
	if not visible: return
	var rect=Rect2(60,55,520,245) if expanded else Rect2(500,72,130,94)
	draw_rect(rect,Color("102a2cf2"))
	draw_rect(rect,Color("92b7a4"),false,1)
	var scale=rect.size/game.world.dimensions
	var water=preload("res://after_silence/world/watercourse.gd")
	if game.state.zone in ["town","harbor"]:
		for y in range(0,int(game.world.dimensions.y),32):
			for x in range(0,int(game.world.dimensions.x),32):
				if water.depth(game.state.zone,Vector2(x+16,y+16))>0: draw_rect(Rect2(rect.position+Vector2(x,y)*scale,Vector2(32,32)*scale),Color("367d87"))
	for road in game.world.paths: draw_line(rect.position+road[0]*scale,rect.position+road[1]*scale,Color("c8a56a"),3 if expanded else 1)
	for building in game.world.sorter.get_children():
		if building.has_meta("building"):
			draw_rect(Rect2(rect.position+(building.position-Vector2(60,90))*scale,Vector2(120,90)*scale),Color("92a6b6"))
	for spot in game.world.interactables:
		if not game.can_interact(spot.id): continue
		var color=Color("efcc7d") if spot.id.begins_with("visit_") or spot.id=="rift_next" else Color("84bc99")
		draw_rect(Rect2(rect.position+spot.position*scale-Vector2(2,2),Vector2(4,4)),color)
	for actor in game.actors.values(): draw_circle(rect.position+actor.position*scale,3 if expanded else 1.5,Color("e79bc0"))
	draw_circle(rect.position+game.player.position*scale,4 if expanded else 2,Color.WHITE)
	var font=get_theme_default_font()
	draw_string(font,rect.position+Vector2(5,12),game.state.zone+" [M]",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color.WHITE)
	if expanded:
		for rumor in game.living.data.rumors:
			if rumor.zone==game.state.zone and game.state.flag("rumor_"+rumor.npc):
				draw_circle(rect.position+Vector2(rumor.point[0],rumor.point[1])*scale,5,Color("ffd980"))
				draw_string(font,rect.position+Vector2(8,rect.size.y-30),game.t(rumor.text[0],rumor.text[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("ffd980"))
				break
		draw_string(font,rect.position+Vector2(6,rect.size.y-12),game.t("Белый: ты • розовый: жители • золотой круг: слух","White: you • pink: residents • gold circle: rumor"),HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("cfdbbb"))
		return
	var y=190
	for request in data.requests:
		if request.zone==game.state.zone:
			draw_string(font,Vector2(12,y),game.t(request.title[0],request.title[1])+" %d/%d"%[count(request),request.points.size()],HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("efcc7d"));y+=16
