extends SceneTree
const Water=preload("res://after_silence/world/watercourse.gd")
var game
var checks=0
var failures=0
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize(): call_deferred("run")
func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	await create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/landscape120-"+name+".png")
func run():
	game=load("res://after_silence/scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.rift_saves.path="user://qa_landscape120.json"
	game._new_rift_game()
	game.rift.active=false;game.rift.hide();game.rift.phase="travel"
	game._close();game.set_physics_process(false);game.living.set_physics_process(false)
	game.state.set_flag("rift_finished");game.state.set_flag("returned")
	for zone in ["town","forest","orchard","harbor","shop"]:
		game._build_world(zone,Vector2(600,600) if zone!="shop" else Vector2(320,395))
		var trees=0
		for prop in game.world.sorter.get_children():
			if prop.get("kind")=="bridge": check(prop.z_index==-1,"bridge draws between water and actors")
			if prop.get("kind")=="tree":
				trees+=1
				check(Water.depth(zone,prop.position)<0,"trees stay on dry land")
			if prop.get("kind")=="flowers": check(Water.depth(zone,prop.position)<0,"no floating flowers")
		check(trees>12 if zone in ["town","forest","orchard","harbor"] else trees==0,"woodland density "+zone)
		for spot in game.world.interactables:
			var target=game.world.recover(spot.position+Vector2(0,24))
			check(not game.world.path_between(game.player.position,target).is_empty(),"reachable "+zone+"/"+spot.id)
		if zone=="town":
			game.toast.text=""
			for x in [600,1450]:
				var y=Water.river_y(x)
				check(game.world.walkable(Vector2(x,y)),"bridge walkable")
				check(not game.world.path_between(Vector2(x,y-80),Vector2(x,y+80)).is_empty(),"bridge connects banks")
			check(not game.world.walkable(Vector2(800,Water.river_y(800))),"river blocks walking")
			await shot("village")
			game.player.position=Vector2(620,1040);game.camera.reset_smoothing()
			await shot("river")
		if zone=="shop":
			game.shop.open();await shot("shop")
			game._close()
		if DisplayServer.get_name()!="headless":
			if is_instance_valid(game.living.camera_tween): game.living.camera_tween.kill()
			game.camera.zoom=Vector2.ONE*minf(640.0/game.world.dimensions.x,360.0/game.world.dimensions.y)*.92
			game.player.position=game.world.dimensions*.5;game.player.hide();game.camera.reset_smoothing()
			await shot("overview-"+zone)
			game.player.show();game.camera.zoom=Vector2.ONE
	game.state.tokens=3
	var before=game.state.item("bandage")
	check(game.shop.buy("bandage"),"purchase")
	check(game.state.tokens==1 and game.state.item("bandage")==before+1,"purchase debits tokens and grants item")
	check(not game.shop.buy("keepsake") and game.state.tokens==1,"insufficient funds atomic")
	check(not game.shop.buy("invalid"),"unknown goods rejected")
	var copy=game.State.new()
	check(copy.restore(game.state.to_data()) and copy.tokens==1,"shop balance saved")
	game._quest_help()
	check(game.buttons.has("map"),"quest help opens map action")
	game.audio.shutdown();game.queue_free()
	await process_frame;await create_timer(.3).timeout
	print("LANDSCAPE 0.12 QA: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
