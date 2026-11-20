extends Node2D
signal completed
signal defeated
var game
var mode="escort"
var center=Vector2.ZERO
var elapsed=0.0
var progress=0.0
var hp=5
var step=0
var alert=0.0
var heat=0.0
var guard=0.0
var last_wave=-1
var active=true
var npc
var followers: Array=[]
var recruited: Array=[]
var invulnerable=0.0
var rule=""
var repair_hold=false
var look_dir=Vector2.RIGHT
var moving_world=false
var epoch=0
var gates: Array=[]
var gate_base: Dictionary={}
var gate_grid: AStarGrid2D
var zone=""
var original_tint=Color.WHITE
var extra_actor
var initiator
var tactics
var participants: Array=[]
var origins: Dictionary={}
var in_view=false
var view_checkpoint: Dictionary={}
var maze
var puzzle
var reality
var vision_points=PackedVector2Array()
func start(owner,kind: String,actor,origin: Vector2):
	game=owner;mode=kind;center=origin;zone=game.state.zone;initiator=actor;npc=actor
	original_tint=game.world.modulate
	if mode=="reality":
		reality=preload("res://after_silence/core/reality_maze.gd").new(game.events_controller.events[game.events_controller.index].id)
		return
	var puzzles=preload("res://after_silence/core/quiet_puzzle.gd")
	if puzzles.SIZES.has(mode):
		puzzle=puzzles.new(mode)
		return
	if mode=="tactics":
		tactics=preload("res://after_silence/world/tactical_encounter.gd").new()
		add_child(tactics);tactics.start(game,self,game.events_controller.events[game.events_controller.index].id)
		return
	if mode=="stealth": npc=game.actors.guest
	take_participant(npc)
	if mode=="stealth": npc.position=game.world.recover(center+Vector2(0,-30));npc.target=npc.position
	if mode=="epochs":
		maze=preload("res://after_silence/world/sonya_maze.gd").new()
		maze.game=game;maze.activity=self;maze.process_mode=Node.PROCESS_MODE_DISABLED;add_child(maze)
		rule=game.t("Проведи Соню к выходу. Двери меняются сами; E рядом с дверью — переключить.","Guide Sonya to the exit. Doors cycle; E near a door switches them.")
	if mode=="dodge":
		rule=game.t("Удерживай E — защита. Во время открытия подойди к Алине и нажми E.","Hold E to guard. During an opening, approach Alina and press E.")
	if mode=="evacuation":
		var ids=["nadia","lev","child"] if game.events_controller.events[game.events_controller.index].id=="train" else ["nadia","child","mara"]
		for i in range(ids.size()):
			var follower=game.actors[ids[i]]
			take_participant(follower)
			follower.position=game.world.recover(center+Vector2(-170+i*120,-80))
			follower.target=follower.position;follower.set_meta("rescued",false);followers.append(follower)
	in_view=true

func take_participant(person):
	var id: String=person.get_meta("resident_id")
	if not origins.has(id):
		origins[id]={"position":[person.position.x,person.position.y],"zone":game.state.residents[id].zone,"managed":person.managed_motion,"mask":person.collision_mask}
	if person not in participants: participants.append(person)
	person.set_meta("activity_owner",get_instance_id());person.managed_motion=false;person.enabled=false;person.scripted=true
	person.collision_mask=1;person.target=person.position
	if person.get_parent()!=game.world.sorter: person.reparent(game.world.sorter,false)
	person.show()
	var event=game.events_controller.events[game.events_controller.index].id
	person.set_appearance(preload("res://after_silence/core/npc_appearance.gd").sheet(id,event),preload("res://after_silence/core/npc_appearance.gd").height(id))

func begin_view():
	if mode=="tactics" or board_mode(): return
	if not in_view:
		var saved=view_checkpoint.duplicate(true);view_checkpoint.clear()
		for person in participants:
			take_participant(person)
		in_view=true
		if not saved.is_empty(): restore(saved)

func end_view():
	if mode=="tactics" or not in_view: return
	view_checkpoint=checkpoint()
	if is_instance_valid(maze): maze.close()
	in_view=false;repair_hold=false;guard=0
	for person in participants:
		if not is_instance_valid(person): continue
		var id: String=person.get_meta("resident_id")
		var origin=origins[id]
		person.position=Vector2(origin.position[0],origin.position[1]);person.target=person.position
		person.scripted=false;person.managed_motion=origin.managed;person.collision_mask=origin.mask
		person.remove_meta("activity_owner")
		person.set_appearance(preload("res://after_silence/core/npc_appearance.gd").sheet(id),preload("res://after_silence/core/npc_appearance.gd").height(id))
		game.npcs.attach(game,id)

func pause_actors():
	repair_hold=false;guard=0
	for person in participants:
		if is_instance_valid(person): person.scripted=false;person.velocity=Vector2.ZERO

func action_input(event: InputEventKey):
	var key=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if key!=KEY_E: return
	repair_hold=event.pressed and not game.modal
	if event.pressed and not event.echo and not game.modal: interact()

func guarding() -> bool:
	return mode in ["defense","dodge"] and (repair_hold or guard>0)

func checkpoint() -> Dictionary:
	if not in_view and not view_checkpoint.is_empty(): return view_checkpoint.duplicate(true)
	var people=[]
	for person in followers: people.append({"position":[person.position.x,person.position.y],"rescued":person.get_meta("rescued",false)})
	var data={"epoch":epoch,"mode":mode,"elapsed":elapsed,"progress":progress,"hp":hp,"step":step,"alert":alert,"heat":heat,"recruited":recruited.duplicate(),"followers":people,"npc":[npc.position.x,npc.position.y]}
	if mode=="tactics": data.tactics=tactics.checkpoint()
	if puzzle!=null: data.moves=puzzle.checkpoint()
	if reality!=null: data.reality=reality.capture()
	if mode=="epochs" and is_instance_valid(maze): data.maze=maze.capture()
	return data
func restore(data: Dictionary):
	if reality!=null:
		reality.restore(data.get("reality"))
		return
	if puzzle!=null:
		puzzle.restore(data.get("moves",[]))
		return
	if mode=="tactics":
		if not tactics.restore(data.get("tactics",{})): tactics.stage="invalid"
		return
	if not in_view:
		view_checkpoint=data.duplicate(true)
		return
	for key in ["elapsed","progress","alert","heat"]: set(key,float(data.get(key,0)))
	hp=int(data.get("hp",5));step=int(data.get("step",0))
	recruited=data.get("recruited",[]).map(func(n):return int(n))
	var p=data.get("npc",[center.x,center.y])
	npc.position=game.world.recover(Vector2(p[0],p[1]))
	var people=data.get("followers",[])
	for i in range(mini(people.size(),followers.size())):
		followers[i].position=game.world.recover(Vector2(people[i].position[0],people[i].position[1]))
		followers[i].set_meta("rescued",people[i].rescued)
		followers[i].visible=not people[i].rescued
	last_wave=int(elapsed/2.2)-1
	if mode=="epochs" and data.has("maze"): maze.restore(data.maze)
func set_epoch(value: int):
	if is_instance_valid(maze):
		epoch=posmod(value,2);maze.set_phase(epoch);return
	epoch=value%2
	clear_gate_navigation()
	for i in range(gates.size()): gates[i].set_deferred("disabled",i==epoch)
	for i in range(gates.size()):
		if i==epoch: continue
		var bounds=game.World.foot_bounds(Rect2(gates[i].get_parent().position-Vector2(6,40),Vector2(12,80)))
		for cell in gate_base:
			if bounds.has_point(Vector2(cell)*16+Vector2(8,8)): game.world.grid.set_point_solid(cell,true)
	game.world.modulate=Color("99b7af") if epoch else Color("d1c7a2")
func clear_gate_navigation():
	if gate_grid==null: return
	for cell in gate_base: gate_grid.set_point_solid(cell,gate_base[cell])
func route_point(i: int) -> Vector2:
	var points=[Vector2(0,-100),Vector2(155,-100),Vector2(0,140),Vector2(0,0)]
	if game.state.zone=="forest": points=[Vector2(0,0),Vector2(160,0),Vector2(0,160),Vector2(0,280)]
	elif game.state.zone=="library": points=[Vector2(0,110),Vector2(120,0),Vector2(0,-130),Vector2(-110,0)]
	elif game.state.zone.begins_with("home_"): points=[Vector2(0,-100),Vector2(140,-100),Vector2(-140,0),Vector2(0,50)]
	return game.world.recover(center+points[posmod(i,4)])
func move_actor(actor,goal: Vector2,dt: float,speed: float=72):
	actor.scripted=true;actor.npc_speed=speed
	var path: PackedVector2Array=actor.get_meta("activity_route",PackedVector2Array())
	var old: Vector2=actor.get_meta("activity_goal",Vector2.INF)
	var age=float(actor.get_meta("activity_route_age",0))-dt
	if old.distance_to(goal)>20 or age<=0:
		path=game.world.path_between(actor.position,goal)
		if path.size()>1 and game.world.sees(actor.position,path[1]): path.remove_at(0)
		if not path.is_empty(): path.append(goal)
		actor.set_meta("activity_goal",goal);age=.75
	while not path.is_empty() and actor.position.distance_to(path[0])<6: path.remove_at(0)
	actor.target=path[0] if not path.is_empty() else actor.position
	actor.set_meta("activity_route",path);actor.set_meta("activity_route_age",age)
	if actor==npc and actor.target.distance_to(actor.position)>2: look_dir=(actor.target-actor.position).normalized()
func _physics_process(dt):
	if game.modal and is_instance_valid(extra_actor): extra_actor.scripted=false
	if not active or not game.state.flag("event_campaign") or game.modal or game.in_menu or game.transitions.busy: return
	if not is_instance_valid(npc):
		active=false;game.events_controller.prepare(false)
		game._notify(game.t("Встреча восстановлена. Поговори с другом.","The meeting was restored. Talk to your friend."));return
	tick(minf(dt,.05))
func tick(dt: float):
	if not active or board_mode(): return
	if mode=="tactics":
		tactics.tick(dt);return
	elapsed+=dt;guard=maxf(0,guard-dt);invulnerable=maxf(0,invulnerable-dt)
	if mode=="epochs" and is_instance_valid(maze):
		maze.tick(dt)
		if maze.finished(): progress=1;win()
		queue_redraw();return
	var player=game.player
	var limits=Rect2(center-Vector2(235,145),Vector2(470,330))
	if not limits.has_point(player.position): player.position=game.world.recover(player.position.clamp(limits.position,limits.end))
	match mode:
		"escort":
			if npc.position.distance_to(player.position)<135:
				move_actor(npc,player.position+Vector2(-22,10),dt)
				if player.position.distance_to(route_point(step))<50:
					progress+=1;step+=1
		"rhythm":
			npc.target=npc.position
			if int(elapsed)!=last_wave: last_wave=int(elapsed);game.audio.ping(game.state.volume)
			if int(elapsed)>step+1: step=int(elapsed);hit()
		"stealth":
			move_actor(npc,route_point(int(elapsed/5)),dt,48)
			var delta=player.position-npc.position
			vision_points=preload("res://after_silence/core/vision_sector.gd").polygon(npc.position,look_dir,game.world.walkable)
			var seen=preload("res://after_silence/core/vision_sector.gd").contains_body(vision_points,player.position,50)
			alert=clampf(alert+dt*(1 if seen else -.65),0,3)
			if not seen and delta.length()<210: progress+=dt
			if alert>=2.5: hit();alert=0
		"switches","epochs","route":
			if mode=="route" and player.position.distance_to(route_point(step))<34: progress+=1;step+=1
		"defense","dodge":
			if mode=="dodge" and repair_hold: _counter_opening()
			var wave=int(elapsed/2.2)
			if wave!=last_wave and fmod(elapsed,2.2)>1.4:
				last_wave=wave
				var lane=posmod(wave,3)
				var attack_x=center.x+(lane-1)*90
				if mode=="dodge":
					if absf(player.position.x-attack_x)<30 and not guarding(): hit()
				else:
					if absf(player.position.x-attack_x)<48 and player.position.distance_to(npc.position)<180 and guarding(): progress+=1
					else: hit()
		"evacuation":
			for i in range(followers.size()):
				if i in recruited:
					move_actor(followers[i],player.position+Vector2(-25-i*12,18),dt,95)
					if followers[i].position.distance_to(route_point(1))<60: progress+=1;recruited.erase(i);followers[i].position=center+Vector2(0,-150);followers[i].hide();followers[i].set_meta("rescued",true)
		"repair":
			var working=(repair_hold or Input.is_physical_key_pressed(KEY_E)) and player.position.distance_to(npc.position)<90
			heat=clampf(heat+dt*(.55 if working else -.85),0,1.6)
			if working and heat<1.2: progress+=dt
			if heat>=1.4: hit();heat=.5
	if mode in ["escort","route","switches","evacuation"]:
		var danger=center+Vector2(sin(elapsed*.7)*180,cos(elapsed*.9)*85)
		if player.position.distance_to(danger)<22 and fmod(elapsed,3)>1.2: hit()
	if hp<=0: lose();return
	if elapsed>=30 and progress>=goal(): win();return
	if elapsed>=110: lose()
	queue_redraw()
func board_mode() -> bool:
	return puzzle!=null or reality!=null

func goal() -> float:
	if reality!=null: return reality.order.size()
	if puzzle!=null: return puzzle.goal()
	if mode=="epochs" and is_instance_valid(maze): return 1
	if mode=="tactics": return 2
	return {"escort":4,"rhythm":30,"stealth":30,"switches":8,"epochs":8,"route":8,"defense":14,"evacuation":3,"dodge":5,"repair":24}.get(mode,1)
func interact():
	if not active or game.modal or board_mode(): return
	if mode=="tactics": tactics.confirm();return
	var p=game.player.position
	match mode:
		"rhythm":
			if absf(fmod(elapsed,1.0)-.5)<.28 and step<=int(elapsed): progress+=1;step=int(elapsed)+1;game.audio.ping(game.state.volume)
			else: hit()
		"switches":
			if p.distance_to(route_point(step))<65: progress+=1;step+=1;game.audio.ping(game.state.volume)
		"epochs":
			if is_instance_valid(maze): maze.interact()
		"defense": guard=.7
		"dodge":
			guard=.8;_counter_opening()
		"evacuation":
			for i in range(followers.size()):
				if not followers[i].get_meta("rescued",false) and p.distance_to(followers[i].position)<65 and i not in recruited: recruited.append(i)
func _input(event):
	if game.event_window.active: return
	if not active or game.modal: return
	if event is InputEventKey: action_input(event)
func _counter_opening():
	var opening=int(elapsed/6.6)+1
	if int(elapsed/2.2)%3==2 and fmod(elapsed,2.2)>1.5 and game.player.position.distance_to(npc.position)<100 and step!=opening: progress+=1;step=opening
func hit():
	if invulnerable>0 or game.player.elevation>6: return
	hp-=1;invulnerable=1.0
	game.player.modulate=Color("e79bc0")
	game.create_tween().tween_property(game.player,"modulate",Color.WHITE,.3)
func lose():
	if not active: return
	active=false;defeated.emit()
func win():
	if not active: return
	active=false;completed.emit()
func _exit_tree():
	if moving_world: return
	if not is_instance_valid(game) or game.is_queued_for_deletion(): return
	end_view()
	clear_gate_navigation()
	if is_instance_valid(initiator): initiator.scripted=false
	if is_instance_valid(extra_actor): extra_actor.queue_free()
	if is_instance_valid(game) and is_instance_valid(game.world) and game.world.zone==zone: game.world.modulate=original_tint
	if is_instance_valid(npc): npc.scripted=false;npc.modulate=Color.WHITE
func _draw():
	if not active: return
	if mode=="tactics" or board_mode(): return
	if mode=="epochs": return
	var font=game.ui.theme.default_font
	var tint=Color("89d8ca")
	if mode in ["escort","route","switches","epochs"]:
		var p=route_point(step)
		draw_rect(Rect2(p-Vector2(15,10),Vector2(30,20)),tint,false,2)
		if mode=="switches": draw_texture_rect(preload("res://after_silence/assets/art100/relay.png"),Rect2(p-Vector2(16,44),Vector2(32,40)),false)
	if mode=="epochs":
		for i in range(2): draw_rect(Rect2(center+Vector2(-71 if i==0 else 59,-115),Vector2(12,80)),Color(.8,.55,.4,.2 if i==epoch else .9))
	if mode=="rhythm":
		var ready=absf(fmod(elapsed,1.0)-.5)<.28
		draw_arc(npc.position+Vector2(0,-75),14+fmod(elapsed,1.0)*15,0,TAU,24,tint if ready else Color("e283a0"),2)
		draw_string(font,npc.position+Vector2(-5,-72),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,10,tint)
	if mode=="stealth":
		if vision_points.size()>2: draw_colored_polygon(vision_points,Color(.9,.35,.5,.2))
	if guarding():
		draw_circle(game.player.position+Vector2(0,-22),23,Color(.48,.85,.8,.15))
		draw_arc(game.player.position+Vector2(0,-22),23,0,TAU,24,tint,2)
		draw_string(font,game.player.position+Vector2(-4,-50),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,8,tint)
	if mode in ["defense","dodge"]:
		if mode=="dodge": preload("res://after_silence/world/pixel_guardian.gd").paint(self,center+Vector2(0,-118),1,int(elapsed/2.2)%3==2)
		var lane=posmod(int(elapsed/2.2),3)
		var x=center.x+(lane-1)*90
		var warning=fmod(elapsed,2.2)<1.4
		draw_rect(Rect2(x-25,center.y-120,50,240),Color(1,.5,.5,.15 if warning else .5))
	if mode in ["escort","route","switches","evacuation"]:
		var danger=center+Vector2(sin(elapsed*.7)*180,cos(elapsed*.9)*85)
		draw_arc(danger,22,0,TAU,16,Color("e283a0") if fmod(elapsed,3)>1.2 else Color("c0a879"),2)
	if mode=="evacuation": draw_rect(Rect2(route_point(1)-Vector2(45,35),Vector2(90,70)),tint,false,2)
	if mode=="repair":
		draw_rect(Rect2(npc.position+Vector2(-40,-90),Vector2(80,8)),Color("283e43"))
		draw_rect(Rect2(npc.position+Vector2(-40,-90),Vector2(80*heat/1.6,8)),tint if heat<1.2 else Color("e283a0"))
