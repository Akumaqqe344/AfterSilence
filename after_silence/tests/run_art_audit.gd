extends SceneTree
var game
var checks=0
var failures=0
var contact: Image
var shot_index=0
const ART=preload("res://after_silence/core/art_catalog.gd")
const PROP=preload("res://after_silence/world/prop.gd")
func check(value: bool,label: String):
	checks+=1
	if not value: failures+=1;push_error(label)
func _initialize(): call_deferred("run")
func standing_point(target: Vector2) -> Vector2:
	for radius in [24,40,48]:
		for i in range(16):
			var candidate=target+Vector2.from_angle(i*TAU/16)*radius
			if game.world.walkable(candidate): return candidate
	return Vector2(-1,-1)
func shot(label: String):
	if DisplayServer.get_name()=="headless": return
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	image.save_png("res://work/art100-"+label+".png")
	image.resize(480,270,Image.INTERPOLATE_NEAREST)
	contact.blit_rect(image,Rect2i(0,0,480,270),Vector2i(shot_index%3*480,shot_index/3*270))
	shot_index+=1
func run():
	game=load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.rift_saves.path="user://qa_art100.json"
	game._new_rift_game()
	game.rift.active=false;game.rift.hide();game.rift.phase="travel";game.rift.index=12
	game.state.set_flag("rift_finished");game.state.set_flag("returned")
	game.state.set_flag("bridge_repaired");game.state.set_flag("town_power");game.state.set_flag("clinic_ready")
	game._close();game.set_physics_process(false);game.living.set_physics_process(false)
	game.living.visible=false;game.adventure.visible=false;game.adventure.set_process(false)
	game.toast.text="";game.objective.text="";game.hint.text="";game.status.text=""
	game.state.clock=12;game.state.echo=false
	contact=Image.create(1440,1080,false,Image.FORMAT_RGBA8)
	contact.fill(Color("142628"))
	check(ART.data.props.size()==40,"forty coherent static sprites")
	for id in ART.data.props:
		var texture=load(ART.BASE+ART.data.props[id].file)
		check(texture!=null,"load asset "+id)
		var size=ART.data.props[id].size
		check(int(size[0])%2==0 and int(size[1])%2==0,"integer 2x display scale "+id)
		var image=texture.get_image()
		var alpha_ok=true
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var alpha=image.get_pixel(x,y).a
				if alpha!=0.0 and alpha!=1.0: alpha_ok=false
		check(alpha_ok,"binary alpha square pixels "+id)
	var scenes=[["town",Vector2(680,520)],["town",Vector2(600,1020)],["library",Vector2(480,430)],["forest",Vector2(700,540)],["orchard",Vector2(600,510)],["harbor",Vector2(800,610)],["home_nadia",Vector2(330,300)],["home_lev",Vector2(330,300)],["home_pavel",Vector2(330,300)],["home_sonya",Vector2(330,300)]]
	for i in range(scenes.size()):
		var zone=scenes[i][0]
		game._build_world(zone,scenes[i][1])
		game.world.modulate=Color("b5c6b6")
		game.camera.reset_smoothing()
		var ids={}
		for spot in game.world.interactables:
			check(not ids.has(spot.id),zone+" unique hotspot "+spot.id)
			ids[spot.id]=true
			if not game.can_interact(spot.id): continue
			check(Rect2(Vector2.ZERO,game.world.dimensions).has_point(spot.position),zone+" hotspot inside map "+spot.id)
			var stand=standing_point(spot.position)
			check(stand.x>=0,zone+" reachable nearby standing point "+spot.id)
			if stand.x>=0: check(not game.world.path_between(game.player.position,stand).is_empty(),zone+" connected navigation "+spot.id)
		var bridges=0
		var rugs=0
		var lamp_count=0
		for prop in game.world.sorter.get_children():
			if not prop is PROP: continue
			check(prop.tex!=null,zone+" no placeholder "+prop.kind)
			check(prop.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,zone+" nearest "+prop.kind)
			if prop.kind=="rug": rugs+=1
			if prop.kind=="bridge": bridges+=1
			if prop.kind=="lamp": lamp_count+=1
			if prop.kind.begins_with("personal_"): check(prop.z_index==1,"personal objects stay above furniture")
		check(rugs==0 if zone not in game.Homes.IDS else rugs==1,zone+" rugs only inside homes")
		check(bridges==2 if zone=="town" else bridges==0,zone+" actual river crossings")
		if zone in game.Homes.IDS: check(lamp_count==1,zone+" no duplicate lamp")
		await shot("%02d-%s"%[i,zone])
		if i!=1 and DisplayServer.get_name()!="headless":
			if is_instance_valid(game.living.camera_tween): game.living.camera_tween.kill()
			game.camera.zoom=Vector2.ONE*minf(640.0/game.world.dimensions.x,360.0/game.world.dimensions.y)*.9
			game.player.position=game.world.dimensions*.5
			game.player.hide()
			game.camera.reset_smoothing()
			await create_timer(.15).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/overview100-"+zone+".png")
			game.camera.zoom=Vector2.ONE
			game.player.show()
		if zone=="home_lev" and "--floor-only" in OS.get_cmdline_user_args():
			game.world.sorter.hide()
			await create_timer(.15).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/floor-only100.png")
			game.world.sorter.show()
	for i in range(2):
		game.state.echo=i==0
		game._build_world("forest" if i==0 else "town",Vector2(700,540) if i==0 else Vector2(680,520))
		game.world.modulate=Color("7b93b3") if i==0 else Color("7b889f")
		await shot("10-forest-echo" if i==0 else "11-town-night")
	if DisplayServer.get_name()!="headless": contact.save_png("res://work/art100-contact.png")
	if DisplayServer.get_name()!="headless":
		contact.fill(Color("142628"));shot_index=0
		for index in [0,1,2,3,4,5,7]:
			game.rift.index=index;game.rift.active=true;game.rift.show()
			game.rift.show_intro();game.rift.start_play();game.rift.set_physics_process(false)
			check(game.rift.phase=="play","minigame renderer "+game.rift.play_mode())
			await shot("mini-"+game.rift.play_mode())
		contact.save_png("res://work/art100-minigames.png")
	game.audio.shutdown();game.queue_free()
	await process_frame;await process_frame
	await create_timer(.3).timeout
	print("ART AUDIT QA: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
