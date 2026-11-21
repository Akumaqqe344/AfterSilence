extends Node

var game
var checks=0
var failures=0
var output="res://work/wayfinding0220"

func _ready():
	call_deferred("run")

func check(ok: bool, message: String):
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"screenshot "+name)

func test_route(index: int, zone: String, start: Vector2, expected: String, phase: String="travel"):
	var director=game.events_controller
	director.index=index
	for i in range(index): game.state.set_flag("event_done_"+director.events[i].id)
	var event=director.events[index]
	var place=game.journey.places[event.location]
	director.center=Vector2(place.point[0],place.point[1])
	game._build_world(zone,start)
	director.phase=phase
	director.npc=game.actors[event.npc]
	if phase=="ready":
		game.state.residents[event.npc].zone=zone
		director.npc.position=game.world.recover(director.center)
		game.npcs.attach(game,event.npc)
	game.route_guide.refresh()
	var guide=game.route_guide
	check(guide.target.get("id","")==expected,"next target "+expected+" from "+zone)
	check(not guide.route.is_empty(),"walkable route "+expected+" from "+zone)
	if guide.route.is_empty(): return
	check(guide.route[-1].distance_to(guide.target.point)<=guide.target.range,"route reaches interaction range "+expected)
	var geometry=game.npcs.nav(zone)
	for i in range(1,guide.route.size()):
		check(game.npcs.navigation.clear_segment(geometry,guide.route[i-1],guide.route[i]),"no wall crossing "+expected+" segment "+str(i))

func tap_g():
	for pressed in [true,false]:
		var event=InputEventKey.new()
		event.physical_keycode=KEY_G;event.keycode=KEY_G;event.pressed=pressed
		get_viewport().push_input(event,true)
		await get_tree().process_frame

func begin_board(index: int):
	var director=game.events_controller
	if game.event_window.active: game.event_window.leave()
	var event=director.events[index]
	var place=game.journey.places[event.location]
	var site=Vector2(place.point[0],place.point[1])
	test_route(index,place.zone,site+Vector2(0,70),event.npc,"ready")
	director.talk(event.npc)
	check(game.event_window.active,"visual board opens "+event.id)
	return game.event_window.puzzle_panel

func click(button: Button):
	var point=button.get_global_transform_with_canvas()*(button.size*.5)
	var move=InputEventMouseMotion.new();move.position=point;move.global_position=point
	get_viewport().push_input(move,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		get_viewport().push_input(event,true)

func test_board_motion():
	var panel=begin_board(0)
	await get_tree().process_frame
	var hint: Button=panel.get_node("Hint")
	check(not hint.get_rect().intersects(panel.undo_button.get_rect()) and not panel.undo_button.get_rect().intersects(panel.reset_button.get_rect()),"trial tools keep separate hit areas")
	check(is_instance_valid(game.event_window.entrance),"board enters with animation")
	await get_tree().create_timer(.10).timeout
	check(game.event_window.decoration.time>.04,"board decorative motion advances")
	game.event_window.toggle_pause()
	check(is_instance_valid(game.event_window.pause_motion),"pause panel enters with animation")
	game.event_window.resume()
	click(panel.action_buttons[panel.model.hint()])
	check(not panel.effects.turns.is_empty() and not panel.effects.particles.is_empty(),"letter rotates its artwork")
	check(is_instance_valid(game.event_window.bar_motion),"accepted move animates the progress bar")
	await shot("05-letter-motion")
	panel=begin_board(8)
	for attempt in range(4):
		var move=panel.model.hint()
		click(panel.action_buttons[move])
		if move==3: break
	check(panel.dispatch_to>=0 and panel.model.round_index==1,"correct track animates carriage")
	await get_tree().create_timer(.14).timeout
	check(panel.rail_u>0,"carriage advances on track")
	await shot("06-rail-motion")
	panel=begin_board(2)
	click(panel.get_node("Hint"))
	check(not panel.guide_path.is_empty() and panel.guide_path[-1]==panel.model.destination(),"maze hint shows a walkable arrow path")
	await shot("07-maze-arrows")
	game.comfort.reduce_motion=true
	panel=begin_board(0)
	check(not is_instance_valid(game.event_window.entrance) and not game.event_window.decoration.is_processing(),"reduced motion removes entry and decorative effects")
	click(panel.action_buttons[panel.model.hint()])
	check(panel.effects.turns.is_empty() and panel.effects.particles.is_empty(),"reduced motion suppresses puzzle effects")
	game.event_window.leave()

func run():
	get_tree().create_timer(90).timeout.connect(func():push_error("Wayfinding QA timed out");get_tree().quit(2))
	if not OS.has_feature("editor"): output=OS.get_executable_path().get_base_dir().path_join("qa-wayfinding")
	DirAccess.make_dir_recursive_absolute(output)
	var suffix=DisplayServer.get_name()+"_"+str(Time.get_ticks_usec())
	game.event_saves.path="user://qa_wayfinding_"+suffix+".json"
	game.comfort.path="user://qa_wayfinding_"+suffix+".cfg"
	game.comfort.reduce_motion=false;game.comfort.route_guide=true
	game._main_menu()
	var time=game.modal_backdrop.sky_time
	await get_tree().create_timer(.32).timeout
	check(game.modal_backdrop.sky_time>time+.15,"actual animated menu")
	check(game.modal_backdrop.departure_elapsed<0.0,"Vera stays inside until the player starts a new journey")
	await shot("01-dusk")
	game.comfort.reduce_motion=true
	game._main_menu()
	check(not game.modal_backdrop.is_processing(),"reduced motion stops menu animation")
	check(game.modal_backdrop.sky_time==0.0,"reduced motion holds the cottage lighting still")
	game.comfort.reduce_motion=false
	game._new_event_game();game._close()
	game.set_physics_process(false);game.events_controller.set_physics_process(false)
	test_route(0,"town",Vector2(690,647),"lev","ready")
	game.story_hud.announce(game.t("Площадь","Square"))
	check(game.story_hud.arrival_age>0,"zone arrival ribbon appears")
	await shot("02-npc")
	check(game.world.interactables.all(func(spot):return spot.id!="event_preparation"),"no detached quest trigger")
	test_route(9,"town",Vector2(609,640),"to_library")
	test_route(3,"town",Vector2(607,773),"home_lev")
	test_route(6,"town",Vector2(1264,700),"visit_orchard")
	test_route(8,"town",Vector2(607,1010),"visit_harbor")
	await shot("04-crossing")
	test_route(10,"town",Vector2(700,555),"to_forest")
	test_route(0,"home_nadia",Vector2(320,300),"leave_home")
	test_route(0,"orchard",Vector2(600,520),"district_return")
	test_route(0,"library",Vector2(480,470),"to_town")
	await tap_g()
	check(not game.comfort.route_guide and game.route_guide.route.is_empty(),"G hides navigation")
	await tap_g()
	check(game.comfort.route_guide,"G restores navigation")
	await test_board_motion()
	game.audio.shutdown();game.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(.3).timeout
	print("WAYFINDING QA: %d checks, %d failures"%[checks,failures])
	get_tree().quit(1 if failures else 0)
