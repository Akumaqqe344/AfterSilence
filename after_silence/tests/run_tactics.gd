extends SceneTree
var game
var checks=0
var failures=0
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures+=1;print("TACTICAL QA ERROR: ",label)
func _initialize(): call_deferred("run")
func run():
	Engine.time_scale=8;Engine.physics_ticks_per_second=480;Engine.max_physics_steps_per_frame=64;Engine.max_fps=240
	create_timer(900).timeout.connect(func():print("TACTICAL QA ERROR: watchdog");quit(2))
	game=load("res://after_silence/scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.event_saves.path="user://qa_tactics_fixture.json"
	for index in [4,7]:
		game._new_event_game();game._close()
		var d=game.events_controller
		for i in range(index): game.state.set_flag("event_done_"+d.events[i].id)
		d.index=index
		d.events[index].mode="tactics"
		var place=game.journey.places[d.events[index].location]
		game._build_world(place.zone,Vector2(place.point[0],place.point[1])+Vector2(0,60))
		d.prepare(false)
		var identities={}
		for id in game.actors: identities[id]=game.actors[id].get_instance_id()
		var age=0.0
		while d.phase in ["travel","observe"] and age<60:
			if game.modal: game._close()
			await physics_frame;age+=1.0/60
		check(d.phase=="ready","meeting ready "+str(index))
		d.begin_preparation()
		check(not game.state.flag("event_action_"+d.events[index].id),"world action required")
		d.start_activity()
		check(not game.event_window.active,"cannot bypass world action")
		game.player.position=d.preparation_point()
		if index==7:
			game.player.position+=Vector2(5,15)
			for pair in [["mara",Vector2(600,600)],["lev",Vector2(601.4145,601.4145)]]:
				game.state.residents[pair[0]].zone="town";game.actors[pair[0]].position=pair[1];game.npcs.attach(game,pair[0])
		check(d.complete_preparation(),"world action completed")
		var tactics=d.activity.tactics
		check(tactics.board.units.size()==4,"one ally and two enemies")
		var origins={}
		for id in tactics.ids(): origins[id]=game.state.residents[id].combat_origin.duplicate(true)
		if index==7: origins.mara={"zone":"town","point":[600,600]}
		tactics.controls.retreat.pressed.emit()
		check(d.phase=="failure" and not game.event_window.active,"retreat returns through failure UI")
		check(not game.state.flag("combat_won_"+d.events[index].id),"retreat cannot grant victory")
		game.body.visible_characters=-1
		game.buttons.retry.pressed.emit()
		tactics=d.activity.tactics
		check(game.event_window.active and tactics.board.units.vera.hp==5,"retry builds a clean tactical attempt")
		for id in game.actors: check(game.actors[id].get_instance_id()==identities[id],"persistent Actor through retreat/retry "+id)
		var saved=false
		var sampled=false
		var yielded=false
		age=0
		while d.phase=="running" and age<600:
			if game.state.residents.mara.get("control","")=="yielding": yielded=true
			if not sampled and tactics.stage=="battle" and DisplayServer.get_name()!="headless":
				sampled=true
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://work/tactics-"+d.events[index].id+"-active.png")
			if tactics.stage=="battle" and tactics.board.phase=="active" and tactics.board.active_id()=="vera":
				var command={}
				for kind in ["help","attack","move","defend","end"]:
					command=tactics.board.plan("vera",kind)
					if not command.is_empty(): break
				tactics.perform(command.kind,command.get("target"))
			if tactics.stage=="battle" and tactics.board.phase=="moving" and not saved:
				saved=true
				var before=tactics.board.capture()
				game.event_window.leave()
				var people=game.state.residents.duplicate(true)
				await game._load_game()
				check(d.phase=="suspended","combat load suspended")
				tactics=d.activity.tactics
				var after=tactics.board.capture()
				for field in before:
					if before[field]!=after[field]: print("TACTICAL CHECKPOINT DIFFERENCE ",field,": ",str(before[field]).left(140)," => ",str(after[field]).left(140))
				check(tactics.board.capture()==before,"AP, initiative and pending command survive load")
				for id in tactics.ids():
					check(game.state.residents[id].zone==people[id].zone,"combat room preserved "+id)
					check(game.actors[id].position.distance_to(Vector2(people[id].x,people[id].y))<.1,"combat position preserved "+id)
				d.resume_activity()
			await physics_frame;age+=1.0/60
		check(d.phase=="decision","combat victory "+str(index)+" phase="+d.phase+" stage="+tactics.stage+" board="+tactics.board.phase+" round="+str(tactics.board.round_number)+" note="+tactics.note)
		check(game.state.flag("combat_won_"+d.events[index].id),"combat consequence")
		if index==7: check(yielded,"noncombat resident physically yields instead of blocking formation")
		if not saved:
			for id in game.actors: check(game.actors[id].get_instance_id()==identities[id],"same actor "+id)
		if d.phase=="decision": await d.choose(d.events[index].choices[0])
		game._close()
		var returned={}
		for frame in range(3600):
			for id in origins:
				var r=game.state.residents[id]
				var destination=origins[id]
				if r.zone==destination.zone and game.actors[id].position.distance_to(Vector2(destination.point[0],destination.point[1]))<50 and r.get("control","")=="routine": returned[id]=true
			if returned.size()==origins.size(): break
			await physics_frame
		for id in origins: check(returned.has(id),"real return to safe origin "+id)
	# A suspended 0.15 defense encounter must keep its original mechanic and HP.
	game._new_event_game();game._close()
	var d=game.events_controller
	for i in range(4): game.state.set_flag("event_done_"+d.events[i].id)
	game.state.residents.pavel.zone="town";game.state.residents.pavel.x=600.0;game.state.residents.pavel.y=930.0
	game.state.zone="town";game.state.position=Vector2(600,995)
	game.state.event_state={"version":2,"index":4,"phase":"suspended","activity":{"mode":"defense","elapsed":15.0,"progress":2.0,"hp":4,"step":0,"alert":0.0,"heat":0.0,"npc":[600,930]}}
	check(game.saves.save(game.state),"legacy encounter save accepted")
	await game._load_game()
	check(d.phase=="suspended" and d.activity.mode=="defense","legacy defense does not silently change into tactics")
	check(d.activity.elapsed==15 and d.activity.progress==2 and d.activity.hp==4,"legacy defense progress and health restored")
	check(game.state.flag("event_action_bridge"),"active legacy event migrated past the new preparation gate")
	game.audio.shutdown();game.queue_free();await process_frame;await create_timer(1.5,true,false,true).timeout
	print("TACTICAL QA: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
