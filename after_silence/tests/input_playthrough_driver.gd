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
var timing: Dictionary={}
var optional_timing: Dictionary={}
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
func walk(point: Vector2,radius: float=18,timeout: float=90) -> bool:
	var age=0.0
	while game.player.position.distance_to(point)>radius and age<timeout:
		if game.modal:
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
		if game.state.zone!=edge[2]:
			print("TRAVEL BLOCK: edge=",edge," zone=",game.state.zone," player=",game.player.position," nearest=",game._nearest()," modal=",game.modal," buttons=",game.buttons.keys())
			return false
	return game.state.zone==zone
func main_menu():
	motion(Vector2.ZERO)
	await tap(KEY_ESCAPE)
	if game.modal and game.buttons.has("menu"): await choose("menu")
	if not game.in_menu and game.buttons.has("menu"): await choose("menu")
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
func maze_key_path(model, target: Vector2i):
	var previous_stage: int=model.stage
	var was_reflected: bool=model.reflected
	for attempt in range(64):
		if model.stage!=previous_stage or model.reflected!=was_reflected: return
		var path: Array=model.route(target)
		if path.is_empty(): return
		var start: Vector2i=model.tile
		var delta: Vector2i=path.front()-start
		var keycode=KEY_RIGHT if delta.x>0 else KEY_LEFT if delta.x<0 else KEY_DOWN if delta.y>0 else KEY_UP
		await tap(keycode)
		var elapsed:=0.0
		while model.tile==start and model.stage==previous_stage and model.reflected==was_reflected and elapsed<.44:
			await get_tree().physics_frame
			elapsed+=dt()

func play_reality(index: int,id: String) -> bool:
	var director=game.events_controller
	var model=director.activity.reality
	var panel=game.event_window.puzzle_panel
	var origin: Vector2=game.player.position
	if index==2 and tag=="together":
		await shot("maze-original")
		var wrong: Vector2i=model.PORTALS[0] if model.PORTALS[0]!=model.destination() else model.PORTALS[1]
		await maze_key_path(model,wrong)
		check(model.reflected and model.stage==0,"wrong door changes topology without losing progress")
		await shot("maze-reflected")
		await tap(KEY_ESCAPE)
		check(game.modal and game.event_window.pause_panel.visible,"maze pauses")
		await button(game.event_window.pause_panel.get_child(2))
		check(director.phase=="suspended" and game.player.position==origin,"maze suspended safely")
		await tap(KEY_ESCAPE);await choose("load")
		while game.transitions.busy: await get_tree().physics_frame
		check(director.phase=="suspended" and director.activity.reality.reflected,"reflected room restored")
		if director.phase!="suspended": return false
		if not await walk(director.npc.position+Vector2(0,30),12): return false
		await tap(KEY_E)
		if not game.event_window.active: return false
		model=director.activity.reality
		panel=game.event_window.puzzle_panel
		origin=game.player.position
	for passage in range(model.order.size()):
		if model.won(): break
		if tag=="home":
			var target: Vector2i=model.destination()
			var at: Vector2=panel.ORIGIN+(Vector2(target)+Vector2(.5,.5))*panel.CELL
			var previous: int=model.stage
			await mouse_at(panel.get_global_transform_with_canvas()*at)
			var elapsed=0.0
			while model.stage==previous and elapsed<8:
				await get_tree().physics_frame;elapsed+=dt()
		else:
			await maze_key_path(model,model.destination())
	check(model.won() and director.phase=="decision","maze exits via real input "+id)
	check(game.player.position==origin,"maze leaves world coordinates intact "+id)
	return model.won() and director.phase=="decision"

func play_event(index: int) -> bool:
	var director=game.events_controller
	var event=director.events[index]
	var place=game.journey.places[event.location]
	if not await travel(place.zone): check(false,"travel "+event.id);return false
	if not await walk(Vector2(place.point[0],place.point[1])+Vector2(0,60),24):
		check(false,"meeting approach "+event.id);return false
	var age=0.0
	while director.phase in ["travel","observe"] and age<180:
		await get_tree().physics_frame;age+=dt()
	check(director.phase=="ready","ready "+event.id)
	if director.phase!="ready": return false
	if not await walk(director.npc.position+Vector2(0,30),15): return false
	await tap(KEY_E)
	check(director.phase=="running" and not game.modal,"one interaction opens board "+event.id)
	check(game.state.flag("event_action_"+event.id),"board start persisted "+event.id)
	check(game.event_window.active,"viewport "+event.id)
	if not game.event_window.active: return false
	var activity=director.activity
	if activity.reality!=null:
		if not await play_reality(index,event.id): return false
		activity=director.activity
	if activity.trial!=null:
		var trial=activity.trial
		var panel=game.event_window.puzzle_panel
		if tag=="together":
			await shot("playing-"+event.id)
			await tap(KEY_ESCAPE)
			check(game.event_window.pause_panel.visible,"trial pauses "+event.id)
			await tap(KEY_ESCAPE)
			check(panel.is_ancestor_of(game.get_viewport().gui_get_focus_owner()),"trial focus restored "+event.id)
		for attempt in range(trial.MOVE_LIMIT):
			if director.phase!="running": break
			var action: int=trial.hint()
			if action<0: break
			if tag=="together": await mouse_click(panel.action_buttons[action])
			else: await button(panel.action_buttons[action])
		check(trial.won(),"unique trial solved by input "+event.id)
	if activity.puzzle!=null:
		var panel=game.event_window.puzzle_panel
		var at=game.player.position
		if tag=="together":
			await shot("playing-"+event.id)
			await tap(KEY_ESCAPE)
			check(game.event_window.pause_panel.visible,"puzzle pauses "+event.id)
			await tap(KEY_ESCAPE)
			check(panel.is_ancestor_of(game.get_viewport().gui_get_focus_owner()),"puzzle focus restored "+event.id)
		for attempt in range(80):
			if director.phase!="running": break
			var move: Array=activity.puzzle.hint()
			check(not move.is_empty(),"reachable puzzle move "+event.id)
			if move.is_empty(): break
			for tile in move:
				if tag=="together": await mouse_click(panel.tiles[tile])
				else: await button(panel.tiles[tile])
		check(game.player.position==at,"puzzle does not move player "+event.id)
		check(activity.puzzle.won(),"puzzle solved by input "+event.id)
	check(director.phase=="decision","victory "+event.id)
	if director.phase!="decision": return false
	await shot(event.id)
	for control in game.buttons.values():
		check(not control.text.begins_with("01") and not control.text.begins_with("02"),"choice without technical number")
	var option=event.choices[(1 if tag=="home" else 0) if index==11 else 0]
	await choose(option[0])
	if game.buttons.has("continue") and game.modal: await choose("continue")
	check(game.state.flag("event_done_"+event.id),"completed "+event.id)
	return true

func find_case(id: String) -> Dictionary:
	for spot in game.world.interactables:
		if spot.id=="case_"+id: return spot
	return {}

func play_case(entry: Dictionary, ending: String) -> bool:
	var director=game.investigations
	for attempt in range(12):
		if director.done(entry.id): return true
		var step: Dictionary=director.next_step(entry)
		if step.is_empty(): return false
		if not await travel(step.zone):
			check(false,"case travel "+step.id+" to "+step.zone)
			return false
		var clue=find_case(step.id)
		if clue.is_empty() or not await walk(clue.position,8):
			check(false,"case approach "+step.id+" in "+step.zone)
			return false
		await tap(KEY_E)
		match step.kind:
			"door":
				while game.transitions.busy: await get_tree().physics_frame
				check(game.state.zone==step.room,"case room reached "+step.room)
				if game.state.zone!=step.room: return false
				await shot(step.room)
			"question":
				if step.id=="arrival_report":
					await choose("answer_0")
					check(not director.seen(step.id),"wrong deduction leaves progress intact")
				await choose("answer_"+str(int(step.correct)))
			"survey":
				await choose("look_"+str((int(step.correct)+1)%4))
				check(not game.buttons.has("aligned"),"wrong viewpoint cannot record alignment")
				check(game.buttons["look_0"].get_parent() is HBoxContainer,"all viewpoints share a visible row")
				await choose("look_"+str(int(step.correct)))
				await get_tree().create_timer(.36).timeout
				await shot(step.id)
				await choose("aligned")
			"sequence":
				if step.id=="sluice_valves":
					for digit in [0,1,2]: await choose("order_"+str(digit))
					check(not director.seen(step.id),"wrong valve sequence can be retried")
				for digit in step.order: await choose("order_"+str(int(digit)))
			"device":
				var panel = game.column.get_child(2)
				await shot(step.id+"-before")
				await button(panel.buttons[3])
				check(not director.seen(step.id),"wrong mechanism setting can be retried")
				var moves = [0,1,2,3] if step.device=="winch" else [0,0,1,2,2,3]
				for action in moves:
					await button(panel.buttons[action])
				if not panel.finished and not director.seen(step.id):
					print("DEVICE BLOCK: ", step.id, " values=", panel.dials, " feedback=", panel.caption.text)
				for frame in range(180):
					if director.seen(step.id): break
					await get_tree().process_frame
				if step.device=="winch": await shot("landing-open")
			"witness":
				check(game.buttons.has("roll_rendezvous")==(ending=="together"),"joint archive account unlocks public testimony")
				check(game.buttons.has("roll_relay")==(ending=="together"),"receiver and pier choices unlock remote testimony")
				var option = "roll_rendezvous" if ending=="together" else "roll_private"
				await shot("roll-call-choices")
				await choose(option)
				check(director.decided(option),"roll-call decision retained")
			"trial":
				check(game.event_window.active and game.event_window.side_id==step.id,"optional board opens from its hotspot "+step.id)
				if not game.event_window.active: return false
				var board=game.event_window.displayed.trial
				for turn in range(board.MOVE_LIMIT):
					if board.won(): break
					var next: int=board.hint()
					if next<0: break
					await button(game.event_window.puzzle_panel.action_buttons[next])
				check(board.won(),"optional variant solved "+step.id)
			_:
				if step.kind=="listen": await choose("listen")
				await choose("remember")
		if not director.seen(step.id):
			check(false,"case checkpoint retains "+step.id)
			return false
		if not entry.branches.is_empty():
			var branch: Dictionary=entry.branches[0 if ending=="together" else 1]
			if game.buttons.has(branch.id) and game.modal:
				await choose(branch.id)
				check(director.decided(branch.id),"choice persists "+branch.id)
		if game.modal and game.buttons.has("close"): await choose("close")
	check(false,"case did not finish "+entry.id)
	return false

func campaign(ending: String):
	tag=ending
	var started=Time.get_ticks_msec()
	await choose("events_new")
	if game.buttons.has("restart"): await choose("restart")
	if game.departing_home: await get_tree().create_timer(1.3).timeout
	check(not game.in_menu and game.state.flag("event_campaign"),"clean new game")
	var ok=true
	for i in range(game.events_controller.events.size()):
		print("PLAYTHROUGH EVENT: ",tag," ",i+1)
		var investigation: Dictionary=game.investigations.active_chapter()
		while not investigation.is_empty():
			print("PLAYTHROUGH CASE: ",tag," ",investigation.id)
			if not await play_case(investigation,ending): ok=false;break
			investigation=game.investigations.active_chapter()
		if not ok or not await play_event(i): ok=false;break
	check(ok and game.state.flag("events_finished") and game.state.flag("events_final_"+ending) and game.modal,"final screen")
	results.append({"campaign":"events","ending":ending,"passed":ok and game.state.flag("events_finished"),"flags":game.state.flags.duplicate(),"history":game.state.history.size()})
	timing[ending]=float(Time.get_ticks_msec()-started)/1000.0
	await shot("ending")
	if ok and "--side-cases" in OS.get_cmdline_user_args() and game.buttons.has("walk"):
		var optional_started=Time.get_ticks_msec()
		await choose("walk")
		for definition in game.investigations.Catalog.data.sides:
			var side: Dictionary = game.investigations.entries[definition.id]
			if not game.investigations.available(side): continue
			print("PLAYTHROUGH SIDE CASE: ",side.id)
			if not await play_case(side,ending): return false
		optional_timing[ending]=float(Time.get_ticks_msec()-optional_started)/1000.0
		await main_menu()
	if game.modal and game.buttons.has("menu"): await choose("menu")
	return ok
func archive(ending: String) -> bool:
	tag="rift-"+ending
	await choose("settings");await choose("archive");await choose("rift")
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
	var args=OS.get_cmdline_user_args()
	if "--real-time" not in args:
		Engine.time_scale=8;Engine.physics_ticks_per_second=480;Engine.max_physics_steps_per_frame=64;Engine.max_fps=240
	if not OS.has_feature("editor"):
		output_dir=OS.get_executable_path().get_base_dir().path_join("qa-input")
		screenshot_dir=output_dir.path_join("screenshots")
	for arg in args:
		if arg.begins_with("--qa-output="):
			output_dir=arg.trim_prefix("--qa-output=")
			screenshot_dir=output_dir.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(screenshot_dir))
	get_tree().create_timer(3600).timeout.connect(func():check(false,"watchdog");finish())
	if not is_instance_valid(game):
		game=load("res://after_silence/scenes/main.tscn").instantiate();get_tree().root.add_child(game)
	await get_tree().process_frame
	game.expanded_new_game="--classic-story" not in args
	game.expedition_new_game="--expansion" in args
	var qa_prefix="user://qa_input_"+("source" if OS.has_feature("editor") else "export")+"_"+DisplayServer.get_name()+"_"+str(Time.get_ticks_usec())+"_"
	game.event_saves.path=qa_prefix+"events.json";game.rift_saves.path=qa_prefix+"rift.json";game.archive_saves.path=qa_prefix+"episode.json"
	if "--archive-only" not in args:
		for ending in (["together"] if "--one-ending" in args else ["together","home"]):
			if not await campaign(ending): finish();return
	if "--events-only" not in args:
		for ending in ["close","both","child","return"]:
			if not await archive(ending): finish();return
	finish()
func finish():
	motion(Vector2.ZERO)
	var report={"checks":checks,"failures":errors,"results":results,"screenshots":shots,"renderer":DisplayServer.get_name(),"time_scale":Engine.time_scale,"main_elapsed_seconds":timing,"optional_elapsed_seconds":optional_timing,"method":"input-driven automated playthrough; not a human playtest"}
	var out=output_dir.path_join("input-playthrough-report"+("-archive" if "--archive-only" in OS.get_cmdline_user_args() else "")+".json")
	var f=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("INPUT PLAYTHROUGH: ",checks," checks, ",errors.size()," failures; endings=",results.size())
	print("MAIN CAMPAIGN ELAPSED: ",timing," time_scale=",Engine.time_scale)
	print("OPTIONAL CHAPTERS ELAPSED: ",optional_timing)
	game.audio.shutdown();game.queue_free()
	await get_tree().process_frame;await get_tree().process_frame
	await get_tree().create_timer(.25,true,false,true).timeout
	get_tree().quit(0 if errors.is_empty() else 1)
