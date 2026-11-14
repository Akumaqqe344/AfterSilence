extends SceneTree
var game
var checks=0
var failures=0
func check(value: bool,label: String):
	checks+=1
	if not value: failures+=1;push_error(label)
func _initialize(): call_deferred("run")
func snap(name: String):
	if DisplayServer.get_name()=="headless": return
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/"+name+".png")
func run():
	game=load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.rift_saves.path="user://qa_visual091.json"
	game._new_rift_game()
	game.rift.active=false;game.rift.hide();game.rift.phase="travel"
	game._close();game.set_physics_process(false);game.living.set_physics_process(false)
	game.state.set_flag("rift_finished")
	game.rift.index=12
	game._build_world("town",Vector2(670,525))
	game.hint.text="";game.objective.text="";game.status.text=""
	check(not game.world.interactables.any(func(s):return s.id=="rift_next"),"no stale quest marker after ending")
	game._nearest()
	for id in ["poster","photo","relay","home_memory"]:
		game.toast.text="";game.interact(id)
		check(game.toast.text=="","completed object stays silent: "+id)
	check(not game.can_interact("poster"),"inactive archive item has no action hint")
	game.state.set_flag("rift_mode",false)
	check(game.can_interact("poster"),"archive interaction preserved")
	game.state.set_flag("rift_mode")
	var lamp
	for prop in game.world.sorter.get_children():
		if prop.get_meta("hotspot_id","")=="hotspot_lamp": lamp=prop
	check(is_instance_valid(lamp) and lamp.kind=="street_lamp","outdoor lamp is outdoor sprite")
	check(lamp.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"nearest pixel filtering")
	check(lamp.size.y<=72 and lamp.size.x<=30,"lamp has controlled scale")
	check(not game.world.walkable(lamp.position),"lamp base registered in navigation")
	for i in range(20):
		game.adventure.handle("hotspot_lamp")
	check(not game.world.has_node("InteractiveLamp"),"rapid even toggles leave no light")
	game.adventure.handle("hotspot_lamp")
	var light=game.world.get_node("InteractiveLamp")
	check(light.position.distance_to(lamp.position+lamp.light_anchor())<1,"light follows glass rather than foot")
	game._build_world("town",Vector2(670,525))
	check(game.world.has_node("InteractiveLamp"),"lamp state restores after rebuild")
	check(game.world.path_between(Vector2(600,550),Vector2(800,500)).size()>0,"road remains navigable")
	game.toast.text="";game.living.handle("cache_supplies");game.toast.text="";game.living.handle("cache_supplies")
	check(game.toast.text=="","used stash does not repeat notification")
	game.living.visible=false;game.adventure.expanded=false
	await snap("visual091-town")
	for kind in game.world.PROP_ART:
		var art=load("res://after_silence/assets/props091/"+game.world.PROP_ART[kind]+".png")
		check(art!=null and art.get_width()<=42 and art.get_height()<=72,"native pixel sprite: "+kind)
	game._build_world("library",Vector2(225,500))
	var relay
	for prop in game.world.sorter.get_children():
		if prop.get("kind")=="relay": relay=prop
	check(is_instance_valid(relay) and relay.tex!=null,"relay uses detailed sprite")
	await snap("visual091-relay")
	game._build_world("home_lev",Vector2(350,330))
	check(not game.world.sorter.get_children().any(func(prop):return prop.get_meta("hotspot_id","")=="leave_home"),"indoor exit has no outdoor lantern")
	await snap("visual091-home")
	game.audio.shutdown();game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.3).timeout
	print("VISUAL FIX QA: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
