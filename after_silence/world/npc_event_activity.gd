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
func start(owner,kind: String,actor,origin: Vector2):
	game=owner;mode=kind;npc=actor;center=origin
	npc.scripted=true
	if mode=="evacuation":
		for i in range(3):
			var follower=game.Actor.new()
			follower.sheet=load("res://after_silence/assets/pechatai/npc/"+["lora","inventor","orest"][i]+".png")
			follower.position=game.world.recover(center+Vector2(-170+i*120,-80))
			follower.enabled=false;follower.scripted=true
			game.world.sorter.add_child(follower);followers.append(follower)
func checkpoint() -> Dictionary:
	var people=[]
	for person in followers: people.append({"position":[person.position.x,person.position.y],"rescued":person.get_meta("rescued",false)})
	return {"mode":mode,"elapsed":elapsed,"progress":progress,"hp":hp,"step":step,"alert":alert,"heat":heat,"recruited":recruited.duplicate(),"followers":people,"npc":[npc.position.x,npc.position.y]}
func restore(data: Dictionary):
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
func route_point(i: int) -> Vector2:
	var points=[Vector2(0,-100),Vector2(155,-100),Vector2(0,140),Vector2(0,0)]
	if game.state.zone=="forest": points=[Vector2(0,0),Vector2(160,0),Vector2(0,160),Vector2(0,280)]
	elif game.state.zone=="library": points=[Vector2(0,110),Vector2(120,0),Vector2(0,-130),Vector2(-110,0)]
	return game.world.recover(center+points[posmod(i,4)])
func move_actor(actor,goal: Vector2,dt: float,speed: float=72):
	actor.scripted=true;actor.npc_speed=speed
	var path=game.world.path_between(actor.position,goal)
	actor.target=path[1] if path.size()>1 else goal
	if actor==npc and actor.target.distance_to(actor.position)>2: look_dir=(actor.target-actor.position).normalized()
func _physics_process(dt):
	if not active or not game.state.flag("event_campaign") or game.modal or game.in_menu or game.transitions.busy: return
	tick(minf(dt,.05))
func tick(dt: float):
	if not active: return
	elapsed+=dt;guard=maxf(0,guard-dt);invulnerable=maxf(0,invulnerable-dt)
	var player=game.player
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
			var direction=look_dir
			var delta=player.position-npc.position
			var seen=delta.length()<160 and direction.normalized().dot(delta.normalized())>.55 and game.world.sees(npc.position,player.position)
			alert=clampf(alert+dt*(1 if seen else -.65),0,3)
			if not seen and delta.length()<210: progress+=dt
			if alert>=2.5: hit();alert=0
		"switches","route":
			if mode=="route" and player.position.distance_to(route_point(step))<34: progress+=1;step+=1
		"defense","dodge":
			var wave=int(elapsed/2.2)
			if wave!=last_wave and fmod(elapsed,2.2)>1.4:
				last_wave=wave
				var lane=posmod(wave,3)
				var attack_x=center.x+(lane-1)*90
				if mode=="dodge":
					if absf(player.position.x-attack_x)<30: hit()
				else:
					if absf(player.position.x-attack_x)<48 and player.position.distance_to(npc.position)<180 and guard>0: progress+=1
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
func goal() -> float:
	return {"escort":4,"rhythm":30,"stealth":30,"switches":8,"route":8,"defense":14,"evacuation":3,"dodge":5,"repair":24}.get(mode,1)
func interact():
	if not active or game.modal: return
	var p=game.player.position
	match mode:
		"rhythm":
			if absf(fmod(elapsed,1.0)-.5)<.28 and step<=int(elapsed): progress+=1;step=int(elapsed)+1;game.audio.ping(game.state.volume)
			else: hit()
		"switches":
			if p.distance_to(route_point(step))<65: progress+=1;step+=1;game.audio.ping(game.state.volume)
		"defense": guard=.7
		"dodge":
			var opening=int(elapsed/6.6)+1
			if int(elapsed/2.2)%3==2 and fmod(elapsed,2.2)>1.5 and p.distance_to(npc.position)<100 and step!=opening: progress+=1;step=opening
		"evacuation":
			for i in range(followers.size()):
				if not followers[i].get_meta("rescued",false) and p.distance_to(followers[i].position)<65 and i not in recruited: recruited.append(i)
func _input(event):
	if event is InputEventKey and event.physical_keycode==KEY_E and not event.pressed: repair_hold=false
	if not active or game.modal: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E:
		repair_hold=true
		interact();get_viewport().set_input_as_handled()
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
	if is_instance_valid(npc): npc.scripted=false;npc.modulate=Color.WHITE
	for actor in followers:
		if is_instance_valid(actor): actor.queue_free()
func _draw():
	if not active: return
	var font=game.ui.theme.default_font
	var tint=Color("89d8ca")
	if mode in ["escort","route","switches"]:
		var p=route_point(step)
		draw_rect(Rect2(p-Vector2(15,10),Vector2(30,20)),tint,false,2)
		if mode=="switches": draw_texture_rect(preload("res://after_silence/assets/art100/relay.png"),Rect2(p-Vector2(16,44),Vector2(32,40)),false)
	if mode=="rhythm":
		var ready=absf(fmod(elapsed,1.0)-.5)<.28
		draw_arc(npc.position+Vector2(0,-75),14+fmod(elapsed,1.0)*15,0,TAU,24,tint if ready else Color("e283a0"),2)
		draw_string(font,npc.position+Vector2(-5,-72),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,10,tint)
	if mode=="stealth":
		var direction=look_dir.angle()
		var points=PackedVector2Array([npc.position])
		for i in range(17):
			var ray=Vector2.from_angle(direction-.9+i*1.8/16.0)
			var end=npc.position
			for distance in range(8,161,8):
				var point=npc.position+ray*distance
				if not game.world.walkable(point): break
				end=point
			points.append(end)
		draw_colored_polygon(points,Color(.9,.35,.5,.2))
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
