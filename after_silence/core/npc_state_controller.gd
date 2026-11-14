extends RefCounted
const Homes=preload("res://after_silence/world/homes.gd")
const PROFILE={"nadia":["town",Vector2(650,540),"home_nadia","lora"],"lev":["town",Vector2(350,500),"home_lev","inventor"],"mara":["library",Vector2(270,490),"home_nadia","scientist"],"pavel":["town",Vector2(900,370),"home_pavel","orest"],"sonya":["town",Vector2(780,650),"home_sonya","ella"]}
var state
func _init(s): state = s
func destination(id: String, home: Vector2, time: float) -> Vector2:
	var offset = {"nadia":0.0,"lev":1.0,"mara":2.0,"pavel":3.0,"sonya":4.0}.get(id,0.0)
	var phase = int((time + offset*.2) / 6.0) % 3
	if state.flag("ending_public") and id == "pavel": return home + Vector2(-40, 20)
	if id=="sonya" and state.flag("protect_sonya"): return home+Vector2(-25,20)
	return home + [Vector2.ZERO, Vector2(32,0), Vector2(0,28)][phase]
func change_relation(id: String, delta: int) -> void:
	if id in state.relations:
		state.relations[id] = clampi(state.relations[id] + delta, -5, 5)
		state.changed.emit()
func initialize():
	for id in PROFILE:
		if state.residents.has(id): continue
		var data=PROFILE[id]
		var zone=data[0]
		var p=data[1]
		if state.clock>=20 or state.clock<7: zone=data[2];p=Vector2(280+PROFILE.keys().find(id)*22,320)
		state.residents[id]={"zone":zone,"destination":zone,"x":p.x,"y":p.y,"elapsed":0.0,"wait":3.0,"visits":0}
func position_of(r: Dictionary) -> Vector2:
	return Vector2(r.x,r.y)
func visible_here(id: String, zone: String) -> bool:
	if id=="sonya" and not state.flag("returned"): return zone=="forest" and state.echo
	return state.residents[id].zone==zone
func populate(game):
	initialize()
	for id in PROFILE:
		if not visible_here(id,game.state.zone) or game.actors.has(id): continue
		var p=position_of(state.residents[id])
		if id=="sonya" and not state.flag("returned"): p=Vector2(1100,280)
		game._npc(id,p,"res://after_silence/assets/pechatai/npc/"+PROFILE[id][3]+".png")
func update(game, dt: float, enabled: bool):
	initialize()
	if not enabled:
		for actor in game.actors.values():
			actor.enabled=false
			actor.get_meta("caption").hide()
		return
	var night=state.clock>=20 or state.clock<7
	for id in PROFILE:
		if id=="sonya" and not state.flag("returned"):
			if game.actors.has(id): _wander(game,id,Vector2(1100,280),dt)
			continue
		var r=state.residents[id]
		var desired=PROFILE[id][2] if night else PROFILE[id][0]
		if r.get("destination",r.zone)!=desired:
			r.elapsed=0.0
			r.destination=desired
		r.elapsed+=dt
		if r.zone!=game.state.zone:
			if r.zone!=desired and r.elapsed>25:
				r.zone=desired
				var p=Vector2(320,350) if night else PROFILE[id][1]
				r.x=p.x;r.y=p.y;r.elapsed=0.0
			continue
		if not game.actors.has(id): continue
		var actor=game.actors[id]
		r.x=actor.position.x;r.y=actor.position.y
		if r.zone==desired:
			_wander(game,id,Vector2(320,300) if night else PROFILE[id][1],dt)
			continue
		var goal=Vector2(320,422) if r.zone in Homes.IDS else Vector2(480,590) if r.zone=="library" else Vector2(600,180) if desired=="library" else Homes.door(PROFILE[id][2],state.echo)
		if actor.position.distance_to(goal)<22:
			var next_zone="town" if r.zone!="town" else desired
			var p=Homes.door(r.zone,state.echo) if r.zone in Homes.IDS else Vector2(600,210) if r.zone=="library" else Vector2(320,395) if desired in Homes.IDS else Vector2(480,575)
			r.zone=next_zone;r.x=p.x;r.y=p.y;r.elapsed=0
			game.actors.erase(id)
			actor.queue_free()
		else: _walk(game,actor,goal,dt,108)
	populate(game)
func _wander(game,id: String, center: Vector2, dt: float):
	var actor=game.actors[id]
	var r=state.residents[id]
	r.wait-=dt
	if r.wait<=0:
		r.visits+=1
		r.wait=3.0+PROFILE.keys().find(id)*.7
		var goal=center+[Vector2.ZERO,Vector2(32,0),Vector2(0,28),Vector2(-24,8)][int(r.visits)%4]
		actor.set_meta("wander_goal",game.world.recover(goal))
	_walk(game,actor,actor.get_meta("wander_goal",game.world.recover(center)),dt,30)
func _walk(game,actor,goal: Vector2,dt: float,speed: float):
	var caption=actor.get_meta("caption")
	caption.visible=actor.position.distance_to(game.player.position)<115 and fmod(state.play_seconds,15)<3
	if caption.visible:
		var id=game.actors.find_key(actor)
		var lines={"nadia":["Не потеряйте записи.","Keep your notes safe."],"lev":["Сначала отключим ток.","Power off first."],"mara":["Проверим второй экземпляр.","Check the second copy."],"pavel":["Я выслушаю свидетелей.","I will hear the witnesses."],"sonya":["Не называйте меня вслух.","Please keep my name quiet."]}
		caption.text=lines[id][1] if state.language=="en" else lines[id][0]
	actor.npc_speed=speed
	actor.enabled=actor.position.distance_to(game.player.position)>76
	if not actor.enabled:
		var d=game.player.position-actor.position
		actor.facing=(3 if d.x>0 else 2) if absf(d.x)>absf(d.y) else (0 if d.y>0 else 1)
		return
	var age=float(actor.get_meta("route_age",0))-dt
	var route: PackedVector2Array=actor.get_meta("route",PackedVector2Array())
	if age<=0:
		route=game.world.path_between(actor.position,goal)
		age=1.0
	while route.size()>0 and actor.position.distance_to(route[0])<6: route.remove_at(0)
	actor.target=route[0] if route.size()>0 else actor.position
	actor.set_meta("route",route)
	actor.set_meta("route_age",age)
