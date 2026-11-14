extends SceneTree
var game
var checks=0
var failures=0
func check(value: bool,label: String):
	checks+=1
	if not value: failures+=1;push_error(label)
func _initialize(): call_deferred("run")
func run():
	game=load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.rift_saves.path="user://qa_living090.json"
	game._new_rift_game()
	game.rift.active=false;game.rift.hide();game.rift.phase="travel"
	game._close()
	var living=game.living
	living.set_physics_process(false)
	game.set_physics_process(false)
	check(living.data.version==1,"versioned content")
	game.state.echo=true
	check(game.npcs.behavior("nadia")=="fear","civilian fears echo")
	check(game.npcs.behavior("pavel")=="alarm","guard responds to alarm")
	game.state.set_flag("calm_nadia")
	check(game.npcs.behavior("nadia")=="routine","reassurance calms resident")
	game.state.echo=false
	game.state.charges=1
	check(game.npcs.behavior("nadia")=="help","healer detects low energy")
	game.state.charges=3
	game.state.clock=22
	check(game.npcs.behavior("lev")=="home","night return")
	game.state.clock=11
	game.state.play_seconds=181
	living.tick(0)
	check(game.state.flag("weather_rain"),"weather cycle rain")
	check(game.npcs.task("lev")[2]=="library","rain reroutes workers to shelter")
	game.state.play_seconds=0;living.tick(0)
	check(game.npcs.task("lev")[2]=="town","dry weather restores work")
	living.remember("lev","help")
	check(living.talk("lev"),"short contextual dialogue")
	check(game.state.flag("rumor_lev"),"conversation reveals map rumor")
	check(game.body.text.contains("помню"),"dialogue reflects memory")
	game._close()
	game._build_world("home_lev",Vector2(320,395))
	var personal=game.world.interactables.filter(func(spot):return str(spot.id).begins_with("personal_"))
	check(personal.size()==2,"two owner-specific home hotspots")
	check(living.handle("personal_plan"),"inspect personal object")
	check(game.state.last_memories.lev=="plan","personal inspection remembered")
	game._close()
	game._build_world("town",Vector2(800,580))
	living.handle("cache_supplies")
	check(game.state.item("keepsake")==1 and game.state.item("bandage")==1,"stash awards usable items")
	living.handle("cache_supplies")
	check(game.state.item("keepsake")==1,"stash cannot be farmed")
	game.state.charges=0
	game._item("bandage")
	check(game.state.charges==3 and game.state.item("bandage")==0,"dressing consumed to heal")
	game._close()
	var rule=living.data.requests[0].requires
	check(not living.meets(rule),"patrol quest locked by conditions")
	game.state.clock=22;game.state.relations.pavel=1;game.state.set_flag("rumor_pavel")
	check(living.meets(rule),"overnight hours relation knowledge and item accepted")
	game.state.clock=12
	check(not living.meets(rule),"quest closed in daytime")
	game.state.clock=22
	living.talk("pavel")
	for button in game.buttons.values():
		if button.text.contains("дозору"): button.pressed.emit();break
	check(game.state.flag("safe_patrol") and game.state.item("keepsake")==0,"night quest consumes token and enables patrol")
	check(game.npcs.behavior("pavel")=="search","guard patrol behavior")
	game._close()
	game.state.set_flag("district_orchard")
	game.state.set_flag("district_harbor")
	living.tick(89)
	check(not game.state.flag("delivery_arrived"),"offscreen event waits")
	game._build_world("orchard",Vector2(600,700));living.tick(1)
	check(game.state.away_times.orchard_delivery==0,"return resets absence")
	game._build_world("town",Vector2(600,600));living.tick(91)
	check(game.state.flag("delivery_arrived"),"offscreen delivery happens without player")
	living.tick(121)
	check(game.state.flag("harbor_lit"),"offscreen harbor event")
	game.state.set_flag("rift_q04_done");game.state.set_flag("rift_q05_done");game.state.set_flag("rift_q08_done")
	living.tick(0)
	check(game.state.flag("town_power") and game.state.flag("bridge_repaired") and game.state.flag("clinic_ready"),"minigames change world")
	check(game.world.interactables.any(func(spot):return spot.id=="clinic_rest"),"clinic interaction actually spawned")
	var restored=load("res://after_silence/core/world_state.gd").new()
	check(restored.restore(game.state.to_data()),"new state roundtrip")
	check(restored.last_memories.lev=="power" and restored.flag("safe_patrol"),"memories and consequences persist")
	check(restored.away_times==game.state.away_times,"absence clocks persist")
	var bad=game.state.to_data();bad.last_memories={"lev":42}
	check(not restored.restore(bad),"reject invalid memory data")
	bad=game.state.to_data();bad.away_times={"orchard_delivery":"oops"}
	check(not restored.restore(bad),"reject invalid event clock")
	living.focus("memory")
	await create_timer(.55).timeout
	check(game.camera.zoom.x>1.1,"scene camera eases in")
	living.restore_camera()
	await create_timer(.55).timeout
	check(is_equal_approx(game.camera.zoom.x,1.0),"camera restores player zoom")
	game.battle.start("relay",false);game.battle.set_physics_process(false)
	game.battle.boss_hp=3;game.battle.wave=0
	var first=game.battle.pattern()
	game.battle.boss_hp=2
	check(game.battle.combat_stage()==1 and game.battle.pattern()!=first,"second boss phase changes pattern")
	game.battle.boss_hp=1;game.battle.wave=1;game.battle.phase="windup";game.battle.phase_age=1
	game.battle._physics_process(.01)
	check(game.battle.combat_stage()==2 and game.battle.bullets.size()>0,"final boss phase combines attacks")
	game.battle.active=false;game.battle.hide()
	if "--qa-visual" in OS.get_cmdline_user_args():
		game.state.clock=22;game.state.play_seconds=181;living.tick(0)
		game._build_world("harbor",Vector2(600,600))
		game.adventure.expanded=true
		living.visible=true
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://work/living090.png")
	game.audio.shutdown();game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.3).timeout
	print("LIVING WORLD QA: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
