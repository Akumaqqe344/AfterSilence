extends RefCounted
const Homes=preload("res://after_silence/world/homes.gd")
const PROFILE={"nadia":["town",Vector2(650,540),"home_nadia","lora"],"lev":["town",Vector2(350,500),"home_lev","inventor"],"mara":["library",Vector2(270,490),"home_nadia","scientist"],"pavel":["town",Vector2(900,370),"home_pavel","orest"],"sonya":["town",Vector2(780,650),"home_sonya","ella"],"child":["home_nadia",Vector2(360,330),"home_nadia","ella"],"alina":["forest",Vector2(700,520),"home_sonya","lora"],"guest":["town",Vector2(950,500),"home_pavel","scientist"]}
var state
var pool: Node2D
var bound_game
var requests: Dictionary={}
var navigation=preload("res://after_silence/core/resident_navigation.gd").new()
var routine=preload("res://after_silence/core/routine_schedule.gd").new()
func task(id: String) -> Array:
	if state.flag("weather_rain") and state.clock>=7 and state.clock<20:
		return [7,20,"library",260+PROFILE.keys().find(id)*65,490,"shelter"]
	if id=="pavel" and state.flag("safe_patrol") and (state.clock>=20 or state.clock<7):
		return [20,7,"town",600,600,"guard"]
	if id=="lev" and state.clock>=16 and state.clock<18 and (state.flag("district_orchard") or state.flag("rift_q03_done")):
		return [16,18,"orchard",600,500,"work"]
	if id=="sonya" and state.clock>=15 and state.clock<18 and (state.flag("district_harbor") or state.flag("rift_q05_done")):
		return [15,18,"harbor",600,500,"writing"]
	return routine.current(id,fposmod(state.clock-PROFILE.keys().find(id)*.02,24))
func _init(s): state = s
func behavior(id: String) -> String:
	if (state.echo or state.pressure>=3) and not state.flag("calm_"+id): return "alarm" if id=="pavel" else "fear"
	if id=="nadia" and state.charges<=1: return "help"
	if id=="pavel" and state.flag("safe_patrol") and (state.clock>=20 or state.clock<7): return "search"
	if task(id)[5]=="sleep": return "home"
	return "routine"
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
		if id=="sonya" and not state.flag("returned") and not state.flag("rift_finished") and not state.flag("event_campaign"):
			zone="forest";p=Vector2(1100,280)
		state.residents[id]={"zone":zone,"destination":zone,"x":p.x,"y":p.y,"elapsed":0.0,"wait":3.0,"visits":0}
func position_of(r: Dictionary) -> Vector2:
	return Vector2(r.x,r.y)
func visible_here(id: String, zone: String) -> bool:
	if not state.residents.has(id): return false
	if id in ["child","alina","guest"] and not state.flag("event_campaign"): return false
	if id=="sonya" and not state.flag("returned") and not state.flag("rift_finished") and not state.flag("event_campaign"):
		return zone=="forest" and state.echo
	return state.residents[id].zone==zone
func dispose(game):
	for actor in game.actors.values():
		if is_instance_valid(actor):
			actor.get_parent().remove_child(actor);actor.queue_free()
	game.actors.clear()
	if is_instance_valid(pool): pool.queue_free()
func capture(game):
	for id in game.actors:
		if not is_instance_valid(game.actors[id]) or not state.residents.has(id): continue
		var p=game.actors[id].position
		state.residents[id].x=p.x;state.residents[id].y=p.y
func detach(game):
	capture(game)
	for actor in game.actors.values():
		if is_instance_valid(actor) and actor.get_parent()!=pool: actor.reparent(pool,false)
func nav(zone: String) -> Dictionary:
	if is_instance_valid(bound_game) and is_instance_valid(bound_game.world):
		var world=bound_game.world
		if world.zone==zone and world.echo==state.echo and world.story_mode==state.flag("event_campaign") and world.grid!=null:
			return {"grid":world.grid,"size":world.dimensions,"obstacles":world.obstacles}
	return navigation.geometry(zone,state.echo,state.flag("event_campaign"))
func safe_point(zone: String, p: Vector2) -> Vector2:
	var geometry=nav(zone)
	if navigation.clear_segment(geometry,p,p): return p
	for ring in range(1,20):
		for angle in range(16):
			var q=p+Vector2.from_angle(angle*TAU/16)*ring*16
			if navigation.clear_segment(geometry,q,q): return q
	return p
func populate(game):
	bound_game=game
	initialize()
	if not is_instance_valid(pool):
		pool=Node2D.new();pool.name="PersistentResidents";pool.hide();game.add_child(pool)
	for id in PROFILE:
		if game.actors.has(id) and is_instance_valid(game.actors[id]): continue
		var r=state.residents[id]
		var saved=position_of(r)
		var p=safe_point(r.zone,saved)
		if p.distance_to(saved)>1:
			r.recovery="obstructed legacy position";r.x=p.x;r.y=p.y
			game._notify(game.t("Житель вернулся на ближайшую безопасную точку.","A resident returned to the nearest safe point."))
		game._npc(id,p,"res://after_silence/assets/pechatai/npc/"+PROFILE[id][3]+".png")
		var actor=game.actors[id]
		actor.set_meta("resident_id",id);actor.managed_motion=true
		if id=="child": actor.scale=Vector2.ONE*.8
		attach(game,id)
	for id in game.actors: attach(game,id)
func attach(game,id: String):
	var actor=game.actors[id]
	var present=visible_here(id,state.zone)
	var parent=game.world.sorter if present else pool
	if actor.get_parent()!=parent: actor.reparent(parent,false)
	actor.visible=present;actor.collision_layer=4 if present else 0
	actor.collision_mask=0 if actor.managed_motion else 1
func request(id: String, zone: String, point: Vector2,role: String="story"):
	if role!="combat" and state.residents[id].get("control","")=="returning":
		state.residents[id].control="routine";state.residents[id].erase("return_to")
	requests[id]={"zone":zone,"point":[point.x,point.y]}
	state.residents[id].assignment=requests[id].duplicate(true)
	state.residents[id].destination=zone;state.residents[id].target=[point.x,point.y]
func release(id: String):
	requests.erase(id)
	state.residents[id].erase("assignment")
func begin_combat(game,id: String,zone: String,target: Vector2):
	var r=state.residents[id]
	if r.get("control","")!="combat":
		r.combat_origin=r.get("return_to",{"zone":r.zone,"point":[game.actors[id].position.x,game.actors[id].position.y]}).duplicate(true)
		r.previous_mode=r.get("mode","routine");r.mode="alarm";r.mode_since=state.play_seconds
	r.control="combat";r.combat_phase="approach";r.combat_paused=false;r.erase("return_to")
	game.actors[id].managed_motion=true;game.actors[id].scripted=false
	request(id,zone,target,"combat")
func pause_combat(ids: Array,value: bool):
	for id in ids:
		if state.residents.has(id) and state.residents[id].get("control","")=="combat":
			state.residents[id].combat_paused=value
			state.residents[id].mode="waiting" if value else "combat" if state.residents[id].get("combat_phase","")=="active" else "escort"
func end_combat(game,ids: Array):
	for id in ids:
		if not state.residents.has(id): continue
		var r=state.residents[id]
		if r.get("control","")!="combat": continue
		var origin=r.get("combat_origin",{"zone":r.zone,"point":[r.x,r.y]}).duplicate(true)
		r.control="returning";r.mode="returning";r.return_to=origin;r.combat_paused=false;r.erase("combat_origin");r.erase("combat_phase")
		requests[id]=origin.duplicate(true);r.assignment=origin.duplicate(true)
		if is_instance_valid(game.actors.get(id)):
			game.actors[id].managed_motion=true;game.actors[id].scripted=false;game.actors[id].modulate=Color.WHITE
func yield_to_combat(game,moving_id: String,blocker_position: Vector2):
	if moving_id!="vera" and not game.actors.has(moving_id): return
	var mover=game.player if moving_id=="vera" else game.actors[moving_id]
	var moving_zone=state.zone if moving_id=="vera" else state.residents[moving_id].zone
	for id in game.actors:
		var r=state.residents[id]
		var person=game.actors[id]
		if id==moving_id or r.zone!=moving_zone or r.get("control","routine")=="combat" or person.position.distance_to(blocker_position)>.1: continue
		var sideways=person.position.direction_to(mover.position).orthogonal()
		for direction in [sideways,-sideways,person.position.direction_to(mover.position)*-1]:
			var goal=person.position+direction*48
			if not navigation.clear_segment(nav(r.zone),goal,goal) or navigation.path(nav(r.zone),person.position,goal).is_empty(): continue
			var free=true
			for other in game.actors:
				if other!=id and state.residents[other].zone==r.zone and game.actors[other].position.distance_to(goal)<20: free=false
			if not free: continue
			if r.get("control","")!="yielding": r.yield_origin=r.get("return_to",{"zone":r.zone,"point":[person.position.x,person.position.y]}).duplicate(true)
			r.control="yielding";r.mode="escort";r.combat_paused=false;r.erase("return_to")
			request(id,r.zone,goal,"yield")
			return
func available(game,zone: String) -> bool:
	if state.flag("event_campaign"): return game.journey.zone_allowed(zone)
	return zone not in ["orchard","harbor"] or game.adventure.unlocked(zone)
func seat(game,id: String,zone: String,target: Vector2) -> Vector2:
	var r=state.residents[id]
	var key="%s:%s"%[zone,target]
	var old=r.get("seat",[])
	var candidates=[target]
	if r.get("seat_key","")==key and old.size()==2: candidates.push_front(Vector2(old[0],old[1]))
	for ring in [20,36,48]:
		for i in range(8): candidates.append(target+Vector2.from_angle((i+PROFILE.keys().find(id))*TAU/8)*ring)
	for p in candidates:
		if not navigation.clear_segment(nav(zone),p,p): continue
		var occupied=false
		for other_id in game.actors:
			if other_id==id or state.residents[other_id].zone!=zone: continue
			if game.actors[other_id].position.distance_to(p)<16: occupied=true;break
		if not occupied:
			r.seat_key=key;r.seat=[p.x,p.y]
			return p
	return target
func update(game, dt: float, enabled: bool):
	populate(game)
	dt=clampf(dt,0,.05)
	var combat_running=false
	for resident in state.residents.values():
		if resident.get("control","")=="combat": combat_running=true;break
	for id in PROFILE:
		var actor=game.actors[id]
		var r=state.residents[id]
		if r.get("control","")=="yielding" and not combat_running:
			r.control="returning";r.return_to=r.yield_origin.duplicate(true);r.erase("yield_origin")
			requests[id]=r.return_to.duplicate(true);r.assignment=r.return_to.duplicate(true)
		if r.has("assignment") and not requests.has(id): requests[id]=r.assignment.duplicate(true)
		if not actor.managed_motion:
			r.x=actor.position.x;r.y=actor.position.y
			continue
		actor.managed_velocity=Vector2.ZERO;actor.enabled=enabled;actor.scripted=false
		actor.get_meta("caption").hide()
		if not enabled: continue
		if (combat_running and r.get("control","") not in ["combat","yielding"]) or r.get("combat_paused",false):
			actor.enabled=false;r.mode="waiting";r.route_status="waiting_combat";continue
		var activity=task(id)
		var desired=activity[2]
		var goal=Vector2(activity[3],activity[4])
		var mode=behavior(id)
		if r.get("control","")=="combat": mode="combat" if r.get("combat_phase","")=="active" else "escort"
		elif r.get("control","")=="yielding": mode="escort"
		elif r.get("control","")=="returning": mode="returning"
		r.mode=mode
		if r.get("control","routine")=="routine" and not requests.has(id) and r.zone==state.zone and actor.position.distance_to(game.player.position)<76 and mode not in ["fear","help"]:
			actor.enabled=false
			var delta=game.player.position-actor.position
			actor.facing=(3 if delta.x>0 else 2) if absf(delta.x)>absf(delta.y) else (0 if delta.y>0 else 1)
			continue
		if mode=="fear": desired=PROFILE[id][2];goal=Vector2(320,300)
		if requests.has(id):
			desired=requests[id].zone;goal=Vector2(requests[id].point[0],requests[id].point[1])
		elif r.get("control","")=="returning":
			desired=r.return_to.zone;goal=Vector2(r.return_to.point[0],r.return_to.point[1])
		elif id=="sonya" and not state.flag("returned") and not state.flag("rift_finished") and not state.flag("event_campaign"):
			desired="forest";goal=Vector2(1100,280)
		elif mode=="help" and r.zone==state.zone and actor.position.distance_to(game.player.position)<200:
			goal=game.player.position+Vector2(0,40);desired=r.zone
			if actor.position.distance_to(game.player.position)<85:
				state.charges=3;game.living.remember(id,"help")
				game._notify(game.t("Надя помогла восстановить силы.","Nadia restored your energy."))
		r.destination=desired;r.target=[goal.x,goal.y]
		if not available(game,desired): r.route_status="waiting_closed_zone";continue
		var edge=[]
		if r.zone!=desired:
			edge=navigation.next_portal(r.zone,desired,state.echo)
			if edge.is_empty(): r.route_status="waiting_no_connection";continue
			if not available(game,edge[2]): r.route_status="waiting_closed_zone";continue
			goal=edge[1]
		elif r.get("control","")!="combat": goal=seat(game,id,desired,goal)
		_walk(game,actor,goal,dt,108 if not edge.is_empty() else 60)
		r.x=actor.position.x;r.y=actor.position.y
		if not edge.is_empty() and actor.position.distance_to(goal)<3:
			var landing: Vector2=edge[3]
			if not navigation.clear_segment(nav(edge[2]),landing,landing):
				r.route_status="waiting_blocked_portal";continue
			# Local coordinates change only at a named, reached scene portal.
			r.zone=edge[2];actor.position=landing;actor.target=landing
			r.x=landing.x;r.y=landing.y;r.visits=int(r.get("visits",0))+1
			r.portal=[edge[0],edge[2]];r.route_status="portal"
			clear_route(actor);attach(game,id)
		elif edge.is_empty() and actor.position.distance_to(goal)<3:
			r.route_status="arrived"
			if r.get("control","")=="returning":
				r.control="routine";r.erase("return_to");release(id)
		if visible_here(id,state.zone) and actor.position.distance_to(game.player.position)<100 and not requests.has(id):
			var caption=actor.get_meta("caption")
			caption.text=game.t("Я рядом.","I'm here.");caption.show()
	capture(game)
func clear_route(actor):
	for key in ["route","route_goal","route_retry","blocked_for"]:
		if actor.has_meta(key): actor.remove_meta(key)
func _walk(game,actor,goal: Vector2,dt: float,speed: float):
	var id: String=actor.get_meta("resident_id")
	var r=state.residents[id]
	var geometry=nav(r.zone)
	var route: PackedVector2Array=actor.get_meta("route",PackedVector2Array())
	var previous: Vector2=actor.get_meta("route_goal",Vector2.INF)
	var retry=float(actor.get_meta("route_retry",0))-dt
	if previous.distance_to(goal)>.5 or (route.is_empty() and retry<=0):
		route=navigation.path(geometry,actor.position,goal)
		actor.set_meta("route_goal",goal);retry=1
	actor.set_meta("route_retry",retry)
	while not route.is_empty() and actor.position.distance_to(route[0])<.1: route.remove_at(0)
	if route.is_empty():
		r.route_status="arrived" if actor.position.distance_to(goal)<3 else "waiting_no_path"
		actor.set_meta("route",route);return
	var budget=speed*dt
	var origin=actor.position
	var blockers=[]
	for other_id in game.actors:
		if other_id!=id and state.residents[other_id].zone==r.zone: blockers.append(game.actors[other_id].position)
	if r.get("control","")=="combat" and r.zone==state.zone: blockers.append(game.player.position)
	while budget>.001 and not route.is_empty():
		var next: Vector2=actor.position.move_toward(route[0],budget)
		if not navigation.clear_segment(geometry,actor.position,next):
			route.clear();r.route_status="waiting_obstacle";break
		var blocked=false
		for other in blockers:
			if next.distance_to(other)<12 and next.distance_to(other)<actor.position.distance_to(other)-.01: blocked=true;break
		if blocked:
			var age=float(actor.get_meta("blocked_for",0))+dt
			actor.set_meta("blocked_for",age);r.route_status="waiting_resident"
			if age>1:
				if r.get("control","")=="combat":
					for other in blockers:
						if next.distance_to(other)<12: yield_to_combat(game,id,other)
				route=navigation.path_avoiding(geometry,actor.position,goal,blockers)
				actor.set_meta("blocked_for",0.0)
			break
		actor.set_meta("blocked_for",0.0)
		budget-=actor.position.distance_to(next);actor.position=next
		r.safe=[next.x,next.y];r.route_status="walking"
		if actor.position.distance_to(route[0])<.1: route.remove_at(0)
	actor.target=route[0] if not route.is_empty() else actor.position
	actor.managed_velocity=(actor.position-origin)/maxf(dt,.00001)
	actor.set_meta("route",route)
