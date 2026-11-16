extends Node
# Drives the shipped input/UI paths. It never writes story flags, actor positions,
# health, progress, elapsed time or victory state.
var game
var checks=0
var errors: Array=[]
var results: Array=[]
var shots: Array=[]
var seconds=0.0
var tag=""
var nav_path=PackedVector2Array()
var nav_target=Vector2.INF
var nav_zone=""
var nav_age=0.0
var screenshot_dir="res://work/playthrough"
var output_dir="res://work"
func _ready(): call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok: errors.append(tag+": "+label);print("PLAYTHROUGH ERROR: ",tag,": ",label)
func key(code: int,pressed: bool=true):
	var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func tap(code: int):
	key(code);await get_tree().process_frame
	key(code,false);await get_tree().process_frame
	await get_tree().physics_frame
func motion(direction: Vector2):
	for item in [["as_right",maxf(0,direction.x)],["as_left",maxf(0,-direction.x)],["as_down",maxf(0,direction.y)],["as_up",maxf(0,-direction.y)]]:
		if item[1]>0: Input.action_press(item[0],item[1])
		else: Input.action_release(item[0])
func dt() -> float: return get_physics_process_delta_time()
func steer(point: Vector2):
	nav_age-=dt()
	if nav_zone!=game.state.zone or nav_target.distance_to(point)>20 or nav_age<=0:
		nav_path=game.world.path_between(game.player.position,point)
		if nav_path.size()>1 and game.world.sees(game.player.position,nav_path[1]): nav_path.remove_at(0)
		if not nav_path.is_empty(): nav_path.append(point)
		nav_target=point;nav_zone=game.state.zone;nav_age=.75
	while not nav_path.is_empty() and game.player.position.distance_to(nav_path[0])<6: nav_path.remove_at(0)
	var aim=nav_path[0] if not nav_path.is_empty() else point
	var delta=aim-game.player.position
	motion(delta.normalized() if delta.length()>3 else Vector2.ZERO)
func button(control: Button):
	if not is_instance_valid(control) or not control.is_visible_in_tree() or control.disabled:
		check(false,"button unavailable");return
	motion(Vector2.ZERO)
	var typing=game.modal and control in game.buttons.values() and game.body.visible_characters>=0 and game.body.visible_characters<game.body.get_total_character_count()
	control.grab_focus()
	await tap(KEY_ENTER)
	# First activation completes a typewritten line, if one was still revealing.
	if typing and is_instance_valid(control) and control.is_visible_in_tree() and control.has_focus(): await tap(KEY_ENTER)
func choose(id: String):
	check(game.buttons.has(id),"button "+id)
	if game.buttons.has(id): await button(game.buttons[id])
func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var path=screenshot_dir.path_join(tag+"-"+name+".png")
	get_tree().root.get_texture().get_image().save_png(path);shots.append(path)
func dismiss():
	if game.modal and game.buttons.has("watch"): await choose("watch")
func walk(point: Vector2,radius: float=18,timeout: float=90) -> bool:
	var age=0.0
	while game.player.position.distance_to(point)>radius and age<timeout:
		if game.modal:
			await dismiss()
			if game.modal: motion(Vector2.ZERO);await get_tree().physics_frame;age+=dt();continue
		steer(point)
		await get_tree().physics_frame;age+=dt()
	motion(Vector2.ZERO)
	await get_tree().physics_frame
	var ok=game.player.position.distance_to(point)<=radius+3
	if not ok: print("WALK BLOCK: ",game.state.zone," from=",game.player.position," to=",point)
	return ok
func travel(zone: String) -> bool:
	for hop in range(4):
		if game.state.zone==zone: return true
		var edge=game.npcs.navigation.next_portal(game.state.zone,zone,game.state.echo)
		if edge.is_empty(): return false
		if not await walk(edge[1],6): return false
		await tap(KEY_E)
		var age=0.0
		while (game.state.zone!=edge[2] or game.transitions.busy) and age<8:
			await get_tree().physics_frame;age+=dt()
		await dismiss()
		if game.state.zone!=edge[2]:
			print("TRAVEL BLOCK: edge=",edge," zone=",game.state.zone," player=",game.player.position," nearest=",game._nearest()," modal=",game.modal," buttons=",game.buttons.keys())
			return false
	return game.state.zone==zone
func main_menu():
	motion(Vector2.ZERO)
	await tap(KEY_ESCAPE)
	if game.modal and game.buttons.has("menu"): await choose("menu")
	if not game.in_menu and game.buttons.has("menu"): await choose("menu")
func exercise_recovery() -> bool:
	var director=game.events_controller
	await get_tree().create_timer(2).timeout
	await tap(KEY_ESCAPE)
	check(game.modal and game.event_window.pause_panel.visible,"Esc pauses activity")
	await tap(KEY_ESCAPE)
	check(not game.modal and game.event_window.active,"Esc resumes activity")
	await tap(KEY_ESCAPE)
	await button(game.event_window.pause_panel.get_child(2))
	check(director.phase=="suspended" and not game.event_window.active,"save and return to world")
	var identity=director.npc.get_instance_id()
	var checkpoint=director.activity.elapsed
	check(await travel("home_nadia"),"enter house with suspended activity")
	check(is_instance_valid(director.activity) and director.npc.get_instance_id()==identity,"activity and NPC persist outside event zone")
	await tap(KEY_ESCAPE);await choose("load")
	while game.transitions.busy: await get_tree().physics_frame
	await get_tree().process_frame
	check(director.phase=="travel" and not director.pending.is_empty(),"load outside event zone preserves checkpoint")
	check(await travel("town"),"return from house")
	check(await walk(director.npc.position+Vector2(0,30),12),"return to event NPC")
	check(director.phase=="suspended" and is_instance_valid(director.activity) and absf(director.activity.elapsed-checkpoint)<.1,"restore event after returning from another room")
	if director.phase!="suspended" or not is_instance_valid(director.activity): return false
	await tap(KEY_E);await choose("resume")
	check(game.event_window.active,"resume after load")
	motion(Vector2.ZERO)
	await get_tree().create_timer(112).timeout
	check(director.phase=="failure" and not game.event_window.active,"real defeat")
	if director.phase!="failure": return false
	check(game.buttons.retry.has_focus(),"retry receives focus")
	await shot("defeat")
	await choose("retry")
	check(game.event_window.active and director.activity.hp==5,"retry through UI")
	return game.event_window.active
func tactical_input(tactics,command: Dictionary):
	if command.is_empty(): return
	await button(tactics.controls[command.kind])
	if command.kind not in ["move","attack","help"]: return
	var target: Vector2i=command.target if command.kind=="move" else tactics.board.location(command.target)
	for i in range(20):
		if not is_instance_valid(tactics) or tactics.cursor==target: break
		var delta=target-tactics.cursor
		await tap(KEY_RIGHT if delta.x>0 else KEY_LEFT if delta.x<0 else KEY_DOWN if delta.y>0 else KEY_UP)
	await tap(KEY_E)
func mouse_click(control: Button):
	await get_tree().process_frame;await get_tree().process_frame
	var position=control.get_global_transform_with_canvas()*(control.size*.5)
	await mouse_at(position)
func mouse_at(position: Vector2):
	var motion_event=InputEventMouseMotion.new();motion_event.position=position;motion_event.global_position=position
	game.get_viewport().push_input(motion_event,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.global_position=position;event.pressed=pressed
		game.get_viewport().push_input(event,true)
		await get_tree().process_frame
func tactical_load():
	var director=game.events_controller
	var before=director.activity.tactics.board.capture()
	await tap(KEY_ESCAPE)
	check(game.modal and game.event_window.pause_panel.visible,"tactical pause")
	await button(game.event_window.pause_panel.get_child(2))
	check(director.phase=="suspended","tactical save and return")
	await tap(KEY_ESCAPE);await choose("load")
	while game.transitions.busy: await get_tree().physics_frame
	await get_tree().process_frame
	check(director.phase=="suspended" and director.activity.mode=="tactics","tactical load suspended")
	check(director.activity.tactics.board.capture()==before,"tactical AP and pending movement restored")
	if not await walk(director.npc.position+Vector2(0,30),12): return false
	await tap(KEY_E);await choose("resume")
	check(game.event_window.active,"tactical resume through dialogue")
	return game.event_window.active
func play_event(index: int) -> bool:
	var director=game.events_controller
	var event=director.events[index]
	var place=game.journey.places[event.location]
	if not await travel(place.zone): check(false,"travel "+event.id);return false
	if not await walk(Vector2(place.point[0],place.point[1])+Vector2(0,60),24):
		check(false,"meeting approach "+event.id);return false
	var age=0.0
	while director.phase in ["travel","observe"] and age<180:
		await dismiss()
		await get_tree().physics_frame;age+=dt()
	check(director.phase=="ready","ready "+event.id)
	if director.phase!="ready": return false
	if not await walk(director.npc.position+Vector2(0,30),15): return false
	await tap(KEY_E)
	await choose("help")
	check(director.phase=="action" or game.state.flag("event_action_"+event.id),"dialogue precedes world action "+event.id)
	if director.phase=="action":
		if not await walk(director.preparation_point(),12): check(false,"reachable world action "+event.id);return false
		await tap(KEY_E)
	check(game.state.flag("event_action_"+event.id),"world action persisted "+event.id)
	check(game.event_window.active,"viewport "+event.id)
	if not game.event_window.active: return false
	if tag=="together" and index==0:
		if not await exercise_recovery(): return false
	var activity=director.activity
	var age_play=0.0
	var last_press=-1
	var sampled=false
	var tactical_saved=false
	var tactical_mouse=false
	while director.phase=="running" and age_play<112:
		activity=director.activity
		var t=activity.tactics.age if activity.mode=="tactics" else activity.elapsed
		if t>8 and not sampled:
			sampled=true
			await shot("playing-"+event.id)
		var aim=game.player.position
		var interact=false
		if activity.mode=="tactics":
			var tactics=activity.tactics
			if tag=="together" and index==4 and not tactical_saved and tactics.stage=="battle" and tactics.board.phase=="moving":
				tactical_saved=true
				if not await tactical_load(): return false
				continue
			if tactics.stage=="battle" and tactics.resume_goal==Vector2.INF and tactics.board.phase=="active" and tactics.board.active_id()=="vera":
				if not tactical_mouse:
					tactical_mouse=true
					var ap=tactics.board.units.vera.ap
					await mouse_click(tactics.controls.attack)
					if tactics.action!="attack" or tactics.board.units.vera.ap!=ap:
						print("TACTICAL MOUSE DETAIL: action=",tactics.action," ap=",tactics.board.units.vera.ap," expected=",ap," button=",tactics.controls.attack.get_global_rect()," canvas=",tactics.controls.attack.get_global_transform_with_canvas()," mouse=",game.event_window.get_global_mouse_position())
					check(tactics.action=="attack" and tactics.board.units.vera.ap==ap,"mouse selects tactical action without spending AP")
					var target=tactics.board.location(tactics.definition.enemies[0][0])
					var viewport_point=game.event_window.viewport.get_canvas_transform()*tactics.world_point(target)
					var root_point=game.event_window.container.get_global_transform_with_canvas()*viewport_point
					await mouse_at(root_point)
					check(tactics.cursor==target and tactics.board.units.vera.ap==ap,"mouse targets unit in viewport without an illegal attack")
				var command={}
				for kind in ["help","attack","move","defend","end"]:
					command=tactics.board.plan("vera",kind)
					if not command.is_empty(): break
				await tactical_input(tactics,command)
			await get_tree().physics_frame;age_play+=dt()
			continue
		match activity.mode:
			"escort","route","switches","epochs":
				aim=activity.route_point(activity.step)
				interact=activity.mode in ["switches","epochs"] and game.player.position.distance_to(aim)<48
				if activity.mode=="escort" and game.player.position.distance_to(activity.npc.position)>100: aim=activity.npc.position+Vector2(12,12)
			"rhythm":
				aim=activity.npc.position+Vector2(0,45)
				interact=absf(fmod(t,1.0)-.5)<.06 and last_press!=int(t)
			"stealth":
				aim=activity.npc.position-activity.look_dir*85
			"repair":
				aim=activity.npc.position+Vector2(0,35)
				key(KEY_E,activity.heat<.95)
			"defense":
				aim=activity.center+Vector2((int(t/2.2)%3-1)*90,35)
				interact=fmod(t,2.2)>1.0
			"dodge":
				aim=activity.npc.position+Vector2(0,60)
				interact=int(t/2.2)%3==2 and fmod(t,2.2)>1.5
			"evacuation":
				aim=activity.route_point(1)
				for i in range(activity.followers.size()):
					if activity.followers[i].get_meta("rescued",false): continue
					if i not in activity.recruited: aim=activity.followers[i].position;interact=game.player.position.distance_to(aim)<60;break
		steer(aim)
		if interact:
			key(KEY_E);key(KEY_E,false)
			if activity.mode=="rhythm": last_press=int(t)
		# Jumping is a normal player action; no damage protection is injected.
		if activity.mode in ["escort","route","switches","evacuation","dodge"] and game.player.jump_age>=game.player.jump_duration: key(KEY_SPACE);key(KEY_SPACE,false)
		await get_tree().physics_frame;age_play+=dt()
	motion(Vector2.ZERO);key(KEY_E,false)
	check(director.phase=="decision","victory "+event.id+" hp="+str(activity.hp)+" progress="+str(activity.progress)+" elapsed="+str(activity.elapsed)+" player="+str(game.player.position)+" npc="+str(activity.npc.position)+" target="+str(activity.npc.target))
	if director.phase!="decision" and activity.mode=="tactics":
		var controller=activity.tactics
		print("TACTICAL CASE: stage=",controller.stage," phase=",controller.board.phase," round=",controller.board.round_number," note=",controller.note," pending=",controller.board.pending," return=",controller.resume_goal)
		for id in game.actors: print("TACTICAL RESIDENT: ",id," at=",game.actors[id].position," control=",game.state.residents[id].get("control","routine")," route=",game.state.residents[id].get("route_status",""))
	if director.phase!="decision": return false
	await shot(event.id)
	for control in game.buttons.values():
		check(not control.text.begins_with("01") and not control.text.begins_with("02"),"choice without technical number")
	var option=event.choices[(1 if tag=="home" else 0) if index==11 else 0]
	await choose(option[0])
	if game.buttons.has("continue") and game.modal: await choose("continue")
	check(game.state.flag("event_done_"+event.id),"completed "+event.id)
	return true
func campaign(ending: String):
	tag=ending
	await choose("events_new")
	if game.buttons.has("restart"): await choose("restart")
	check(not game.in_menu and game.state.flag("event_campaign"),"clean new game")
	var ok=true
	for i in range(game.events_controller.events.size()):
		print("PLAYTHROUGH EVENT: ",tag," ",i+1)
		if not await play_event(i): ok=false;break
	check(ok and game.state.flag("events_finished") and game.state.flag("events_final_"+ending) and game.modal,"final screen")
	results.append({"campaign":"events","ending":ending,"passed":ok and game.state.flag("events_finished"),"flags":game.state.flags.duplicate(),"history":game.state.history.size()})
	await shot("ending")
	if game.modal and game.buttons.has("menu"): await choose("menu")
	return ok
func archive(ending: String) -> bool:
	tag="rift-"+ending
	await choose("archive");await choose("rift")
	var r=game.rift
	var picks=["warn","follow","open","limit","guard","restore","truth","defend","present","truce","trust",ending]
	for index in range(12):
		print("PLAYTHROUGH ARCHIVE: ",ending," ",index+1)
		if index>0:
			if not await walk(r.STOPS[index]+Vector2(0,20),20): check(false,"archive travel");return false
			await tap(KEY_E)
		check(r.phase=="intro","archive intro "+str(index))
		if r.phase!="intro": return false
		await tap(KEY_E)
		var age=0.0
		while r.phase=="play" and age<150:
			var mode=r.play_mode()
			match mode:
				"memory":
					for p in range(4):
						if p not in r.matched: await tap(KEY_1+p);await tap(KEY_5+p);break
				"circuit":
					for cell in range(4):
						if r.board[cell]%2: await tap(KEY_1+cell);break
				"herbs":
					for cell in [0,2,4]:
						if r.board[cell]==0: await tap(KEY_1+cell);break
				"rhythm":
					if r.beat_age>r.rhythm_duration()*.5: await tap(r.rhythm_key())
				"switch":
					for bit in range(4):
						if (r.mask^(r.switch_target()))&(1<<bit): await tap(KEY_1+bit)
					await tap(KEY_E)
				"defense":
					if r.lane>r.incoming_lane(): await tap(KEY_W)
					elif r.lane<r.incoming_lane(): await tap(KEY_S)
					if r.beat_age>1.05: await tap(KEY_SPACE)
				"route":
					var goal=Vector2(562,215)
					if index==11:
						for person in range(3):
							if not (r.rescued&(1<<person)): goal=Vector2(190+person*130,165 if person%2==0 else 265);break
					if index==6:
						for gate in range(3):
							if r.player_pos.x<220+gate*112+24: goal=Vector2(250+gate*112,[165,260,188][gate]);break
					motion((goal-r.player_pos).normalized() if goal.distance_to(r.player_pos)>5 else Vector2.ZERO)
					await tap(KEY_SPACE)
			await get_tree().physics_frame;age+=dt()
		motion(Vector2.ZERO)
		check(r.phase=="decision","archive victory "+str(index))
		if r.phase!="decision": return false
		var quest=r.QUESTS[index]
		var selected=-1
		for i in range(quest.choices.size()):
			if quest.choices[i][0]==picks[index]: selected=i;break
		check(selected>=0,"archive choice exists")
		if selected<0: return false
		await button(r.actions.get_child(selected))
	check(game.state.flag("rift_finished") and game.state.flag("rift_final_"+ending) and game.modal,"archive final screen")
	await shot("ending")
	results.append({"campaign":"rift","ending":ending,"passed":game.state.flag("rift_finished"),"history":game.state.history.size()})
	await choose("close")
	await tap(KEY_ESCAPE);await choose("menu")
	return true
func run():
	Engine.time_scale=8;Engine.physics_ticks_per_second=480;Engine.max_physics_steps_per_frame=64;Engine.max_fps=240
	if not OS.has_feature("editor"):
		output_dir=OS.get_executable_path().get_base_dir().path_join("qa-input")
		screenshot_dir=output_dir.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(screenshot_dir))
	get_tree().create_timer(3600).timeout.connect(func():check(false,"watchdog");finish())
	if not is_instance_valid(game):
		game=load("res://after_silence/scenes/main.tscn").instantiate();get_tree().root.add_child(game)
	await get_tree().process_frame
	var qa_prefix="user://qa_input_"+("source" if OS.has_feature("editor") else "export")+"_"+DisplayServer.get_name()+"_"
	game.event_saves.path=qa_prefix+"events.json";game.rift_saves.path=qa_prefix+"rift.json";game.archive_saves.path=qa_prefix+"episode.json"
	var args=OS.get_cmdline_user_args()
	if "--archive-only" not in args:
		for ending in ["together","home"]:
			if not await campaign(ending): finish();return
	if "--events-only" not in args:
		for ending in ["close","both","child","return"]:
			if not await archive(ending): finish();return
	finish()
func finish():
	motion(Vector2.ZERO)
	var report={"checks":checks,"failures":errors,"results":results,"screenshots":shots,"renderer":DisplayServer.get_name(),"method":"input-driven automated playthrough; not a human playtest"}
	var out=output_dir.path_join("input-playthrough-report"+("-archive" if "--archive-only" in OS.get_cmdline_user_args() else "")+".json")
	var f=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("INPUT PLAYTHROUGH: ",checks," checks, ",errors.size()," failures; endings=",results.size())
	game.audio.shutdown();game.queue_free()
	await get_tree().process_frame;await get_tree().process_frame
	await get_tree().create_timer(.25,true,false,true).timeout
	get_tree().quit(0 if errors.is_empty() else 1)
