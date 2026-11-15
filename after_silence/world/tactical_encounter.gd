extends Node2D
const Rules=preload("res://after_silence/core/tactical_battle.gd")
const PITCH=32.0
var board=Rules.new()
var game
var activity
var encounter_id=""
var definition: Dictionary={}
var origin=Vector2.ZERO
var stage="assembling"
var age=0.0
var move_age=0.0
var move_index=1
var ai_age=0.0
var paused=false
var released=false
var completed=false
var bar: HBoxContainer
var controls: Dictionary={}
var action="move"
var cursor=Vector2i(4,3)
var previous_turn=""
var note=""
var ai: SelectorComposite
var blackboard: Blackboard
var player_route=PackedVector2Array()
var resume_goal=Vector2.INF
var resume_age=0.0
func world_point(cell: Vector2i) -> Vector2: return origin+Vector2(cell)*PITCH
func ids() -> Array:
	var result=[]
	for id in board.units:
		if id!="vera": result.append(id)
	return result
func actor(id: String): return game.player if id=="vera" else game.actors.get(id)
func start(owner,parent_activity,id: String):
	game=owner;activity=parent_activity;encounter_id=id
	var catalog=JSON.parse_string(FileAccess.get_file_as_string(Rules.CATALOG_PATH))
	definition=catalog.encounters[id]
	origin=Vector2(floori(activity.center.x/16)*16+8,floori(activity.center.y/16)*16+8)-Vector2(128,96)
	var nav=game.npcs.nav(game.state.zone)
	var tiles=[]
	var links=[]
	var points=[]
	for y in range(7):
		for x in range(9):
			var p=Vector2i(x,y)
			if game.npcs.navigation.clear_segment(nav,world_point(p),world_point(p)):
				points.append(p);tiles.append([x,y])
	for a in points:
		for direction in Rules.DIRECTIONS:
			var b: Vector2i=a+direction
			if b in points and game.npcs.navigation.clear_segment(nav,world_point(a),world_point(b)): links.append([[a.x,a.y],[b.x,b.y]])
	# Retain only the component containing the player's approach to the encounter.
	points.sort_custom(func(a,b):return world_point(a).distance_squared_to(game.player.position)<world_point(b).distance_squared_to(game.player.position))
	if points.is_empty(): stage="invalid";return
	var reachable={board.key(points[0]):true}
	var queue=[points[0]]
	while not queue.is_empty():
		var current: Vector2i=queue.pop_front()
		for edge in links:
			if board.point(edge[0])!=current or reachable.has(board.key(board.point(edge[1]))): continue
			reachable[board.key(board.point(edge[1]))]=true;queue.append(board.point(edge[1]))
	points=points.filter(func(p):return reachable.has(board.key(p)))
	tiles=tiles.filter(func(p):return reachable.has(board.key(board.point(p))))
	links=links.filter(func(e):return reachable.has(board.key(board.point(e[0]))) and reachable.has(board.key(board.point(e[1]))))
	var participants=[definition.ally]
	for enemy in definition.enemies: participants.append(enemy[0])
	var free=points.filter(func(p):
		for id_here in game.actors:
			if id_here in participants or game.state.residents[id_here].zone!=game.state.zone: continue
			if world_point(p).distance_to(game.actors[id_here].position)<20: return false
		return true)
	if free.size()<4: stage="invalid";return
	free.sort_custom(func(a,b):return world_point(a).distance_squared_to(game.player.position)<world_point(b).distance_squared_to(game.player.position))
	var vera: Vector2i=free.pop_front()
	free.sort_custom(func(a,b):return world_point(a).distance_squared_to(activity.npc.position)<world_point(b).distance_squared_to(activity.npc.position))
	var ally: Vector2i=free.pop_front()
	var roster=[{"id":"vera","side":"party","role":"wanderer","cell":[vera.x,vera.y]},{"id":definition.ally,"side":"party","role":definition.ally_class,"cell":[ally.x,ally.y]}]
	for enemy in definition.enemies:
		free.sort_custom(func(a,b):return board.distance(a,vera)>board.distance(b,vera) if board.distance(a,vera)!=board.distance(b,vera) else board.key(a)<board.key(b))
		var cell: Vector2i=free.pop_front()
		roster.append({"id":enemy[0],"side":"enemy","role":enemy[1],"cell":[cell.x,cell.y]})
	if not board.configure(tiles,links,roster): stage="invalid";return
	for npc_id in ids(): game.npcs.begin_combat(game,npc_id,game.state.zone,world_point(board.location(npc_id)))
	cursor=board.location("vera")
	make_ui()
	make_ai()
func make_ai():
	ai=SelectorComposite.new();ai.name="TacticalClassAwareAI"
	blackboard=Blackboard.new();add_child(blackboard)
	for kind in ["help","attack","move","defend","end"]:
		var leaf=preload("res://after_silence/core/tactical_ai_leaf.gd").new()
		leaf.action_kind=kind;leaf.name=kind;ai.add_child(leaf)
	add_child(ai)
func make_ui():
	bar=HBoxContainer.new();bar.position=Vector2(16,260);bar.size=Vector2(576,32);bar.add_theme_constant_override("separation",4)
	game.event_window.frame.add_child(bar)
	for entry in [["move","Идти","Move"],["attack","Атака · 2","Attack · 2"],["defend","Защита · 1","Guard · 1"],["help","Помочь · 2","Help · 2"],["end","Конец хода","End turn"],["retreat","Отойти","Retreat"]]:
		var button=Button.new();button.text=game.t(entry[1],entry[2]);button.custom_minimum_size=Vector2(91,30);button.add_theme_font_size_override("font_size",8)
		var kind: String=entry[0]
		button.pressed.connect(func():
			if kind in ["move","attack","help"]:
				action=kind
				if kind!="move":
					for other in board.order:
						if board.can_target("vera",other,kind): cursor=board.location(other);break
				note=game.t("Стрелки: цель · E: выполнить","Arrows: target · E: confirm");queue_redraw()
			else: perform(kind))
		bar.add_child(button)
		for style_name in ["normal","hover","pressed","focus","disabled"]:
			var style=button.get_theme_stylebox(style_name).duplicate()
			style.content_margin_left=4;style.content_margin_right=4
			button.add_theme_stylebox_override(style_name,style)
		controls[kind]=button
func set_paused(value: bool):
	paused=value;game.npcs.pause_combat(ids(),value)
	game.player.scripted=false;game.player.velocity=Vector2.ZERO
	game.player.collision_mask=1 if value else 5
	if not value and stage=="battle" and not completed:
		var expected=world_point(board.location("vera"))
		var on_path=game.player.position.distance_to(expected)<4
		if board.phase=="moving" and board.pending.id=="vera":
			var a=world_point(board.point(board.pending.path[move_index-1]))
			var b=world_point(board.point(board.pending.path[move_index]))
			on_path=Geometry2D.get_closest_point_to_segment(game.player.position,a,b).distance_to(game.player.position)<4
			expected=a
		if not on_path:
			resume_goal=expected;resume_age=0;player_route=PackedVector2Array();game.npcs.pause_combat(ids(),true)
func tick(dt: float):
	if completed or paused: return
	age=minf(9999,age+dt)
	game.player.enabled=false
	game.camera.position=activity.center-game.player.position
	if stage=="invalid": fail(game.t("Не удалось подготовить проход. Можно повторить.","The passage could not be prepared. You can retry."));return
	activity.hp=board.units.vera.hp
	if board.phase in ["defeat","retreated"]: finish(false);return
	if resume_goal!=Vector2.INF:
		resume_age+=dt;move_player(resume_goal,dt)
		note=game.t("Возвращаемся на позицию перед продолжением.","Returning to position before continuing.")
		if game.player.position.distance_to(resume_goal)<3:
			resume_goal=Vector2.INF;player_route=PackedVector2Array()
			game.player.scripted=false;game.player.velocity=Vector2.ZERO
			game.npcs.pause_combat(ids(),false);note=""
		elif resume_age>15: fail(game.t("Позиция недоступна. Освободи проход и повтори.","The position is blocked. Clear the passage and retry."))
		refresh();queue_redraw();return
	if not is_instance_valid(game.actors.get(definition.ally)): game.npcs.populate(game)
	if stage=="assembling":
		var ready=true
		for unit_id in board.order:
			var person=actor(unit_id)
			if not is_instance_valid(person): ready=false;continue
			var goal=world_point(board.location(unit_id))
			if unit_id=="vera":
				move_player(goal,dt)
			if game.state.zone!=game.state.residents.get(unit_id,{"zone":game.state.zone}).zone or person.position.distance_to(goal)>3: ready=false
		if ready:
			game.player.scripted=false;game.player.velocity=Vector2.ZERO;stage="battle";age=0
			for id in ids(): game.state.residents[id].combat_phase="active"
		elif age>45: fail(game.t("Кто-то не смог подойти. Освободи проход и повтори.","Someone could not approach. Clear the passage and retry."))
		refresh();return
	if board.phase=="moving":
		move_age+=dt
		var id: String=board.pending.id
		var goal=world_point(board.point(board.pending.path[move_index]))
		if id=="vera": move_player(goal,dt)
		else: game.npcs.request(id,game.state.zone,goal,"combat")
		if actor(id).position.distance_to(goal)<3:
			if id=="vera": game.player.scripted=false;game.player.velocity=Vector2.ZERO
			move_index+=1;move_age=0;player_route=PackedVector2Array()
			if move_index>=board.pending.path.size(): board.finish_move()
		elif move_age>12: fail(game.t("Проход занят. Попробуй другой подход.","The passage is blocked. Try another approach."))
	elif board.phase=="active":
		if board.units[board.active_id()].ap<=0: board.next_turn()
		if board.active_id()!="vera":
			ai_age+=dt
			if ai_age>.22:
				ai_age=0;ai.tick(self,blackboard);ai.after_run(self,blackboard)
	if board.phase=="victory":
		finish(true);return
	if board.phase in ["defeat","retreated"]:
		finish(false);return
	activity.hp=board.units.vera.hp
	activity.progress=0
	for unit in board.units.values():
		if unit.side=="enemy" and unit.hp<=0: activity.progress+=1
	for unit_id in ids():
		var person=actor(unit_id)
		if is_instance_valid(person): person.modulate=Color("777a7b") if board.units[unit_id].hp<=0 else Color.WHITE
	refresh();queue_redraw()
func move_player(goal: Vector2,_dt: float):
	if player_route.is_empty():
		for id in game.actors:
			if id not in board.units and game.state.residents[id].zone==game.state.zone and game.actors[id].position.distance_to(goal)<14: game.npcs.yield_to_combat(game,"vera",game.actors[id].position)
		var reserved=[]
		for npc_id in game.actors:
			if game.state.residents[npc_id].zone!=game.state.zone: continue
			var center=Vector2i(game.actors[npc_id].position/16)
			for y in range(-1,2):
				for x in range(-1,2):
					var cell=center+Vector2i(x,y)
					var cell_point=Vector2(cell)*16+Vector2(8,8)
					if Rect2(game.actors[npc_id].position-Vector2(10,12),Vector2(20,24)).has_point(cell_point) and game.world.grid.is_in_boundsv(cell) and not game.world.grid.is_point_solid(cell) and cell!=Vector2i(game.player.position/16) and cell!=Vector2i(goal/16):
						reserved.append(cell);game.world.grid.set_point_solid(cell,true)
		player_route=game.world.path_between(game.player.position,goal)
		for cell in reserved: game.world.grid.set_point_solid(cell,false)
		if player_route.size()>1 and game.world.sees(game.player.position,player_route[1]): player_route.remove_at(0)
		if not player_route.is_empty(): player_route.append(goal)
	while not player_route.is_empty() and game.player.position.distance_to(player_route[0])<3: player_route.remove_at(0)
	game.player.scripted=true;game.player.target=player_route[0] if not player_route.is_empty() else goal
func perform(kind: String,target=null):
	if completed or paused: return
	if kind=="retreat":
		if board.phase in ["victory","defeat","retreated"]: return
		board.phase="retreated";board.pending={}
		board.log.append({"actor":"vera","action":"retreat","round":board.round_number})
		finish(false);return
	if stage!="battle": return
	var id=board.active_id()
	var result=board.command(id,kind,target)
	note="" if result.ok else result.reason
	if result.ok and board.phase=="moving":
		move_age=0;move_index=1;player_route=PackedVector2Array()
		var moving_id: String=board.pending.id
		if moving_id!="vera": game.npcs.request(moving_id,game.state.zone,world_point(board.point(board.pending.path[move_index])),"combat")
	refresh();queue_redraw()
func confirm():
	if stage!="battle" or board.phase!="active" or board.active_id()!="vera" or game.modal: return
	if action=="move": perform("move",cursor)
	else:
		for id in board.order:
			if board.location(id)==cursor: perform(action,id);return
		note=game.t("Здесь нет цели.","There is no target here.")
func key_input(event: InputEventKey) -> bool:
	if not event.pressed or event.echo: return false
	var directions={KEY_LEFT:Vector2i.LEFT,KEY_RIGHT:Vector2i.RIGHT,KEY_UP:Vector2i.UP,KEY_DOWN:Vector2i.DOWN}
	if directions.has(event.physical_keycode):
		cursor=(cursor+directions[event.physical_keycode]).clamp(Vector2i.ZERO,Vector2i(8,6));queue_redraw();return true
	if event.physical_keycode==KEY_E: confirm();return true
	return false
func mouse_input(position_in_viewport: Vector2):
	var world=game.event_window.viewport.get_canvas_transform().affine_inverse()*position_in_viewport
	cursor=Vector2i(roundi((world.x-origin.x)/PITCH),roundi((world.y-origin.y)/PITCH))
	confirm()
func refresh():
	if not is_instance_valid(bar): return
	var player_turn=stage=="battle" and board.phase=="active" and board.active_id()=="vera" and not game.modal and not paused and resume_goal==Vector2.INF
	for kind in controls: controls[kind].disabled=not player_turn if kind!="retreat" else completed or board.phase in ["victory","defeat","retreated"]
	var current=board.active_id()
	var health=[]
	for id in ids(): health.append(game.named(id).split(" · ")[0]+": "+str(board.units[id].hp)+"/"+str(board.units[id].max_hp))
	game.event_window.goal.text=game.t("Участники подходят к месту учения.","The participants are approaching.") if stage=="assembling" else game.t("Ход: ","Turn: ")+game.named(current)+" · "+game.t("Действия: ","Actions: ")+str(board.units[current].ap)+" · "+game.t("Круг ","Round ")+str(board.round_number)+"\n"+(note if note!="" else " · ".join(health))
	if player_turn and previous_turn!="vera": controls.move.grab_focus()
	previous_turn=current if player_turn else ""
func finish(victory: bool):
	if completed: return
	completed=true
	release()
	if victory:
		game.state.set_flag("combat_won_"+encounter_id);game.state.set_flag(definition.reward)
		game.npcs.change_relation(definition.ally,1)
		activity.win()
	else: activity.lose()
func fail(message: String):
	note=message;game._notify(message);finish(false)
func release():
	if released or not is_instance_valid(game): return
	released=true
	game.player.scripted=false;game.player.velocity=Vector2.ZERO
	game.player.collision_mask=1
	game.npcs.end_combat(game,ids())
func checkpoint() -> Dictionary:
	return {"version":1,"encounter":encounter_id,"origin":[origin.x,origin.y],"stage":stage,"age":age,"move_age":move_age,"move_index":move_index,"paused":paused,"board":board.capture()}
static func valid(data: Dictionary) -> bool:
	if data.get("version")!=1 or data.get("encounter") not in ["bridge","crowd"] or data.get("stage") not in ["assembling","battle"]: return false
	if not data.get("origin") is Array or data.origin.size()!=2: return false
	for n in data.origin:
		if not (n is int or n is float) or not is_finite(float(n)) or n<24 or n>2000: return false
	for k in ["age","move_age"]:
		var n=data.get(k)
		if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>10000: return false
	if not data.get("paused") is bool or not data.get("board") is Dictionary: return false
	if not Rules.valid(data.board) or not Rules.integer(data.get("move_index"),1,4): return false
	var catalog=JSON.parse_string(FileAccess.get_file_as_string(Rules.CATALOG_PATH)).encounters[data.encounter]
	var expected=["vera",catalog.ally]
	for enemy in catalog.enemies: expected.append(enemy[0])
	if data.board.units.size()!=expected.size(): return false
	for id in data.board.units:
		if id not in expected: return false
	if data.board.units.vera.role!="wanderer" or data.board.units[catalog.ally].role!=catalog.ally_class or data.board.units[catalog.ally].side!="party": return false
	for enemy in catalog.enemies:
		if data.board.units[enemy[0]].role!=enemy[1] or data.board.units[enemy[0]].side!="enemy": return false
	if data.origin[0]+8*PITCH>1768 or data.origin[1]+6*PITCH>1256: return false
	if data.board.get("phase")=="moving" and data.move_index>=data.board.pending.get("path",[]).size(): return false
	return true
func restore(data: Dictionary) -> bool:
	if not valid(data) or data.encounter!=encounter_id: return false
	if not board.restore(data.board): return false
	origin=Vector2(data.origin[0],data.origin[1]);stage=data.stage;age=float(data.age);move_age=float(data.move_age);move_index=int(data.move_index);paused=bool(data.paused)
	var geometry=game.npcs.nav(game.state.zone)
	for p in data.board.tiles:
		var point=world_point(board.point(p))
		if not game.npcs.navigation.clear_segment(geometry,point,point): return false
	for edge in data.board.links:
		if not game.npcs.navigation.clear_segment(geometry,world_point(board.point(edge[0])),world_point(board.point(edge[1]))): return false
	for id in ids():
		var r=game.state.residents[id]
		if r.get("control","")!="combat": game.npcs.begin_combat(game,id,r.zone,game.npcs.position_of(r))
		r.combat_phase="active" if stage=="battle" else "approach"
		game.npcs.request(id,game.state.zone,world_point(board.location(id)),"combat")
		if board.phase=="moving" and board.pending.id==id: game.npcs.request(id,game.state.zone,world_point(board.point(board.pending.path[move_index])),"combat")
	game.npcs.pause_combat(ids(),paused)
	cursor=board.location("vera");refresh()
	return true
func _draw():
	if not is_instance_valid(game) or board.units.is_empty(): return
	for k in board.cells:
		var xy=k.split(":");var cell=Vector2i(int(xy[0]),int(xy[1]))
		var rect=Rect2(world_point(cell)-Vector2.ONE*15,Vector2.ONE*30)
		draw_rect(rect,Color(.25,.38,.38,.22));draw_rect(rect,Color(.52,.61,.56,.4),false,1)
		if cell==cursor: draw_rect(rect,Color("dfc89b"),false,2)
	var font=game.ui.theme.default_font
	for id in board.order:
		var unit=board.units[id]
		var p=actor(id).position if is_instance_valid(actor(id)) else world_point(board.location(id))
		var color=Color("b78991") if unit.side=="enemy" else Color("91b7b1")
		draw_arc(p,11,0,TAU,16,color,2)
		draw_rect(Rect2(p+Vector2(-15,8),Vector2(30,12)),Color("182e32"))
		draw_string(font,p+Vector2(-12,17),str(unit.hp)+"/"+str(unit.max_hp),HORIZONTAL_ALIGNMENT_LEFT,-1,8,color)
func _exit_tree():
	if is_instance_valid(activity) and activity.moving_world: return
	if is_instance_valid(game) and not game.is_queued_for_deletion(): release()
	if is_instance_valid(bar) and is_instance_valid(game) and not game.is_queued_for_deletion():
		bar.hide();bar.get_parent().remove_child(bar);bar.queue_free()
