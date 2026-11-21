extends Control
var game
var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/living_world.json"))
var age=0.0
var camera_tween: Tween
var focus_left=0.0
var scene_kind=""
var rain_age=0.0

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func meets(rule: Dictionary) -> bool:
	for flag in rule.get("flags",[]):
		if not game.state.flag(flag): return false
	for flag in rule.get("not_flags",[]):
		if game.state.flag(flag): return false
	for id in rule.get("relation",{}):
		if game.state.relations.get(id,0)<rule.relation[id]: return false
	for id in rule.get("items",{}):
		if game.state.item(id)<rule.items[id]: return false
	if rule.has("hours"):
		var start=float(rule.hours[0])
		var end=float(rule.hours[1])
		var now=game.state.clock
		if not (now>=start and now<end if start<end else now>=start or now<end): return false
	return true

func remember(npc: String, event: String):
	var flag="memory_"+npc+"_"+event
	if not game.state.flag(flag): game.state.set_flag(flag)
	game.state.last_memories[npc]=event

func populate():
	var zone=game.state.zone
	if data.homes.has(zone):
		game.world.spot("home_storage",Vector2(224,391),"none")
		for obj in data.homes[zone].objects:
			var id="personal_"+str(obj[0])
			var area: Rect2=game.Homes.surface(zone,obj[0])
			if not area.has_area():
				game.world.spot(id,Vector2(obj[5],obj[6]),id)
				continue
			var x=area.get_center().x
			game.world.spot(id,Vector2(x,area.end.y+17),"none")
			var detail=game.world.prop(id,Vector2(x,area.position.y+minf(24.0,area.size.y-3)))
			detail.size*=minf(1.0,24.0/maxf(detail.size.x,detail.size.y))
			detail.set_meta("hotspot_id",id)
	if zone in ["town","orchard","harbor"]:
		game.world.spot("cache_supplies",Vector2(840,580) if zone=="town" else Vector2(800,540),"chest")
	if zone=="orchard" and game.state.flag("delivery_arrived"):
		game.world.spot("cache_delivery",Vector2(600,550),"chest")
	if zone=="harbor" and game.state.flag("harbor_lit"):
		for x in [280,600,920]: game.world.add_light(Vector2(x,380))
	if zone=="town" and game.state.flag("town_power"):
		game.world.add_light(Vector2(600,500))
	if zone=="town" and game.state.flag("clinic_ready"):
		game.world.spot("clinic_rest",Vector2(660,580),"plant")

func label(id: String) -> String:
	if id=="hotspot_window": return game.t("Осмотреть окно","Inspect window")
	if id=="hotspot_furniture": return game.t("Осмотреть полку","Inspect shelf")
	if id.begins_with("cache_"): return game.t("Открыть тайник","Open stash")
	if id=="clinic_rest": return game.t("Попросить перевязку","Ask for a dressing")
	for home in data.homes.values():
		for obj in home.objects:
			if id=="personal_"+obj[0]: return game.t(obj[1],obj[2])
	return id

func handle(id: String) -> bool:
	if id=="home_storage": game.expedition.storage();return true
	if id in ["hotspot_window","hotspot_furniture"]:
		var mark="examined_"+game.state.zone+"_"+id
		if not game.state.flag(mark):
			game.state.set_flag(mark)
			game._dialog("",label(id),game.t("В окне видна дорога домой.","The road home is visible through the window.") if id=="hotspot_window" else game.t("Хозяин бережно хранит вещи своих друзей.","The owner keeps friends' belongings safe."),[game.choice("close","Запомнить","Remember",game._close)],false)
		return true
	if id=="clinic_rest":
		game.state.charges=3
		remember("nadia","help")
		game._notify(game.t("Надя помогла. Силы восстановлены.","Nadia helped. Energy restored."));return true
	if id.begins_with("cache_"):
		var key=id+"_"+game.state.zone
		if game.state.flag(key): return true
		game.state.set_flag(key)
		game.state.give("keepsake")
		game.state.give("bandage")
		game.state.give("ribbon")
		game._notify(game.t("Найдены перевязка и памятный знак!","Found a dressing and a keepsake!"))
		remember("lev","stash");game._save(false);return true
	if data.homes.has(game.state.zone):
		var home=data.homes[game.state.zone]
		for obj in home.objects:
			if id!="personal_"+obj[0]: continue
			if game.state.flag("examined_"+game.state.zone+"_"+obj[0]): return true
			remember(home.owner,obj[0])
			game.state.set_flag("examined_"+game.state.zone+"_"+obj[0])
			focus("memory")
			game._dialog("",game.t(obj[1],obj[2]),game.t(obj[3],obj[4]),[game.choice("close","Запомнить","Remember",game._close)],false)
			return true
	return false

func talk(id: String) -> bool:
	if id not in game.state.relations: return false
	# Archive story interactions retain their original quest progression.
	if not game.state.flag("rift_mode"): return false
	var rumor={}
	for entry in data.rumors:
		if entry.npc==id: rumor=entry;break
	game.state.set_flag("rumor_"+id)
	var greeting=""
	if game.state.flag("talk_again_"+id): greeting=game.t("Рада новой встрече!","Glad to meet again!")+"\n"
	elif game.state.flag("talk_first_"+id): game.state.set_flag("talk_again_"+id)
	game.state.set_flag("talk_first_"+id)
	var text=game.t(rumor.text[0],rumor.text[1])
	text=greeting+text
	var memory=game.state.last_memories.get(id,"")
	if memory!="":
		text=game.t("Я помню твою помощь. Спасибо!","I remember your help. Thank you!")+"\n"+text if memory in ["help","collection","power","bridge","clinic"] else game.t("Ты заглядывала к моим вещам. У каждой своя история.","You looked at my things. Each has a story.")+"\n"+text
	var mode=game.npcs.behavior(id)
	if mode in ["fear","alarm"]: text=game.t("Мне тревожно. Побудь рядом?","I am worried. Stay with me?")
	var actions=[game.choice("help","Поддержать","Reassure",func():
		if not game.state.flag("reassured_"+id): game.npcs.change_relation(id,1);game.state.set_flag("reassured_"+id)
		remember(id,"help");game.state.set_flag("calm_"+id);game._close())]
	for request in data.requests:
		if request.npc==id and not game.state.flag(request.effect):
			if meets(request.requires):
				actions.append(game.choice(request.id,"Помочь ночному дозору","Help the night watch",func():
					if meets(request.requires) and not game.state.flag(request.effect):
						game.state.give(request.take,-1);game.state.set_flag(request.effect);remember(id,"help")
					game._close();game._save(false)))
			else: text+="\n"+game.t("Для дозора: ночью, дружба и памятный знак.","For patrol: night, friendship and a keepsake.")
	actions.append(game.choice("story","О нашей истории","About our story",func():game._rift_talk(id)))
	if id=="nadia": actions.append(game.choice("meeting","О завтрашнем дне","About tomorrow",game.talkkit_pilot.play))
	actions.append(game.choice("close","До встречи","Goodbye",game._close))
	focus("talk")
	game._dialog("",game.named(id),text,actions,false)
	return true

func focus(kind: String):
	if not is_instance_valid(game.camera): return
	if is_instance_valid(camera_tween): camera_tween.kill()
	focus_left=2.4
	scene_kind=kind
	camera_tween=create_tween()
	camera_tween.tween_property(game.camera,"zoom",Vector2.ONE*1.12,.45).set_trans(Tween.TRANS_SINE)
	game.audio.scene_cue(kind,game.state.volume)

func restore_camera(duration: float=.5):
	if is_instance_valid(camera_tween): camera_tween.kill()
	focus_left=0
	scene_kind=""
	if is_instance_valid(game.camera):
		var target=Vector2.ONE*(.65 if game.wide_camera else 1.0)
		if game.comfort.reduce_motion or duration<=0.0:
			game.camera.zoom=target
		else:
			camera_tween=create_tween()
			camera_tween.tween_property(game.camera,"zoom",target,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func tick(dt: float):
	var state=game.state
	var raining=int(state.play_seconds/180.0)%3==1
	if state.flag("weather_rain")!=raining: state.set_flag("weather_rain",raining)
	for event in data.events:
		if state.zone==event.zone: state.away_times[event.id]=0.0
		elif not state.flag(event.effect) and meets(event.requires):
			state.away_times[event.id]=float(state.away_times.get(event.id,0))+dt
			if state.away_times[event.id]>=event.absence:
				state.set_flag(event.effect)
				game._notify(game.t(event.text[0],event.text[1]))
	var rebuild=false
	for outcome in data.outcomes:
		if not state.flag(outcome.effect) and meets(outcome.requires):
			state.set_flag(outcome.effect);remember(outcome.npc,outcome.memory);rebuild=true
	if rebuild:
		game._build_world(state.zone,game.player.position)
		game._notify(game.t("Твои поступки изменили город!","Your actions changed the town!"))

func _physics_process(dt: float):
	if not is_instance_valid(game.player): return
	if game.state.flag("event_campaign"):
		visible=false
		return
	if focus_left>0:
		focus_left-=dt
		if focus_left<=0: restore_camera()
	var enabled=not game.in_menu and not game.modal and not game.rift.active and not game.battle.active and not game.transitions.busy and not game.cutscenes.running
	visible=not game.in_menu and not game.modal and not game.rift.active and not game.battle.active
	if enabled:
		tick(dt)
		rain_age+=dt
		if game.rift.phase=="travel" and game.state.zone=="town" and game.rift.index<game.rift.STOPS.size():
			var marker="scene_approach_%02d"%game.rift.index
			if not game.state.flag(marker) and game.player.position.distance_to(game.rift.STOPS[game.rift.index])<135:
				game.state.set_flag(marker);focus("memory")
	queue_redraw()

func _draw():
	if not visible: return
	if game.state.flag("weather_rain") and game.state.zone not in game.Homes.IDS and game.state.zone!="library":
		for i in range(38):
			var p=Vector2(fposmod(i*71-rain_age*44,640),fposmod(i*37+rain_age*140,360))
			draw_line(p,p+Vector2(-2,5),Color(.6,.8,.9,.35),1)
	if game.adventure.expanded: return
	var night=game.state.clock>=20 or game.state.clock<7
	draw_string(get_theme_default_font(),Vector2(12,229),game.t("Ночь","Night") if night else game.t("День","Day"),HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("b6d5cf"))
	if game.state.flag("weather_rain"): draw_string(get_theme_default_font(),Vector2(12,243),game.t("Дождь • жители ищут укрытие","Rain • residents seek shelter"),HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("b6d5cf"))
