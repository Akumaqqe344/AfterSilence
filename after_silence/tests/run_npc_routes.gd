extends SceneTree
var game
var checks=0
var errors: Array=[]
var rows: Array=[]
func _initialize(): call_deferred("run")
func check(ok: bool,id: String,zone: String,target: Vector2,reason: String):
	checks+=1
	if ok: return
	var message="NPC ROUTE ERROR: npc=%s zone=%s target=%s reason=%s"%[id,zone,target,reason]
	errors.append(message);print(message)
func identity() -> Dictionary:
	var result={}
	for id in game.actors: result[id]=game.actors[id].get_instance_id()
	return result
func simulate(seconds: float):
	for frame in range(ceili(seconds/.05)): game.npcs.update(game,.05,true)
func run():
	create_timer(240).timeout.connect(func():print("NPC ROUTE ERROR: npc=all zone=all target=(0,0) reason=watchdog");quit(2))
	game=load("res://after_silence/scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.event_saves.path="user://qa_npc_routes.json"
	game._new_event_game();game._close()
	game.set_physics_process(false);game.events_controller.set_physics_process(false);game.living.set_physics_process(false)
	var catalog=game.npcs.routine.entries
	var ids=identity()
	check(ids.size()==8,"all","town",Vector2.ZERO,"not eight persistent actors")
	for echo in [false,true]:
		game.state.echo=echo
		for story in [true,false]:
			game.state.set_flag("event_campaign",story)
			for id in catalog:
				for entry in catalog[id]:
					var zone: String=entry[2]
					var target=Vector2(entry[3],entry[4])
					var nav=game.npcs.nav(zone)
					var start=Vector2(320,422) if zone.begins_with("home_") else Vector2(480,590) if zone=="library" else Vector2(700,990) if zone=="forest" else Vector2(600,740) if zone in ["orchard","harbor"] else Vector2(600,645)
					var route=game.npcs.navigation.path(nav,start,target)
					check(not route.is_empty(),id,zone,target,"no AStar path from room entrance")
					var valid=true
					for i in range(route.size()):
						if not game.npcs.navigation.walkable(nav,route[i]): valid=false
						if i>0 and not game.npcs.navigation.clear_segment(nav,route[i-1],route[i]): valid=false
					check(valid,id,zone,target,"route crosses wall or water")
					rows.append({"npc":id,"zone":zone,"target":[target.x,target.y],"echo":echo,"campaign":story,"points":route.size(),"valid":valid and not route.is_empty()})
	# Every portal and every event destination is checked using rendered geometry.
	game.state.echo=false;game.state.set_flag("event_campaign")
	for edge in game.npcs.navigation.portals(false):
		for item in [[edge[0],edge[1]],[edge[2],edge[3]]]:
			check(game.npcs.navigation.clear_segment(game.npcs.nav(item[0]),item[1],item[1]),"portal",item[0],item[1],"blocked portal endpoint")
	for event in game.events_controller.events:
		var place=game.journey.places[event.location]
		var target=Vector2(place.point[0],place.point[1])+Vector2(0,-20)
		check(game.npcs.navigation.clear_segment(game.npcs.nav(place.zone),target,target),event.npc,place.zone,target,"blocked meeting")
	# Zone rebuilds retain exact Actor identities and offscreen residents keep walking.
	game.npcs.requests.clear()
	for r in game.state.residents.values(): r.erase("assignment")
	for id in game.actors: game.npcs.request(id,game.state.residents[id].zone,game.actors[id].position)
	for zone in ["library","home_nadia","forest","town"]:
		game._build_world(zone,Vector2(600,600))
		check(identity()==ids,"all",zone,Vector2.ZERO,"Actor replaced at zone boundary")
	for event in game.events_controller.events: game.state.set_flag("event_done_"+event.id)
	game.state.set_flag("events_finished");game.state.set_flag("returned")
	# Walk each resident from their genuine current room to every schedule target.
	for id in catalog:
		for entry in catalog[id]:
			var zone: String=entry[2]
			var target=Vector2(entry[3],entry[4])
			game.npcs.request(id,zone,target)
			simulate(3)
			game.npcs.capture(game)
			var saved=game.state.to_data()
			var state=game.State.new()
			check(state.restore(saved),id,zone,target,"save rejected in transit")
			if state.restore(saved):
				check(state.residents[id].zone==game.state.residents[id].zone and game.npcs.position_of(state.residents[id]).distance_to(game.actors[id].position)<.01,id,zone,target,"wrong room/position after restore")
			# Recreate the service from the validated save and continue the route.
			game.state=state;game._setup_services();game.npcs.populate(game)
			for frame in range(6000):
				game.npcs.update(game,.05,true)
				var r=game.state.residents[id]
				if r.zone==zone and game.actors[id].position.distance_to(target)<50 and r.route_status=="arrived": break
			var r=game.state.residents[id]
			check(r.zone==zone and game.actors[id].position.distance_to(target)<50 and r.route_status=="arrived",id,r.zone,target,"route did not finish after load: "+str(r.get("route_status",""))+" at "+str(game.actors[id].position))
			# Park at a distinct nearby reachable point to avoid sharing a schedule seat.
			var park=game.npcs.safe_point(zone,target+Vector2(36,32))
			game.npcs.request(id,zone,park);simulate(2)
	# Closed gates must wait without rewriting position or room.
	game.state.set_flag("events_finished",false);game.state.set_flag("event_done_memory",false)
	var before=game.actors.lev.position;var room=game.state.residents.lev.zone
	game.npcs.request("lev","orchard",Vector2(600,500));simulate(2)
	check(game.state.residents.lev.zone==room and game.actors.lev.position==before,"lev",room,Vector2(600,500),"closed district bypass")
	check(game.state.residents.lev.route_status=="waiting_closed_zone","lev",room,Vector2(600,500),"closed zone not explained")
	game.npcs.release("nadia");game.state.charges=1;game.state.clock=8
	var nadia=game.state.residents.nadia
	game._build_world(nadia.zone,game.actors.nadia.position+Vector2(0,35))
	game.npcs.update(game,.05,true)
	check(game.state.charges==3,"nadia",nadia.zone,game.actors.nadia.position,"nearby conversation stop suppressed healing")
	var report={"checks":checks,"failures":errors.size(),"errors":errors,"routes":rows,"renderer":DisplayServer.get_name()}
	var file=FileAccess.open("res://work/npc-route-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("NPC ROUTE QA: %d checks, %d failures"%[checks,errors.size()])
	quit(1 if not errors.is_empty() else 0)
