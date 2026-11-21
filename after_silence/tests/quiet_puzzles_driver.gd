extends Node

const Puzzle=preload("res://after_silence/core/quiet_puzzle.gd")
var game
var root: Window
var checks=0
var failures=0

func _ready(): call_deferred("run")

func check(condition: bool,label: String):
	checks+=1
	if not condition:
		failures+=1
		push_error(label)

func click(button: Button):
	await get_tree().process_frame
	var p=button.get_global_transform_with_canvas()*(button.size*.5)
	var motion=InputEventMouseMotion.new()
	motion.position=p;motion.global_position=p
	game.get_viewport().push_input(motion,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=p;event.global_position=p
		game.get_viewport().push_input(event,true)
		await get_tree().process_frame

func escape():
	for pressed in [true,false]:
		var event=InputEventKey.new()
		event.physical_keycode=KEY_ESCAPE;event.keycode=KEY_ESCAPE;event.pressed=pressed
		game.get_viewport().push_input(event,true)
		await get_tree().process_frame

func fixture(index: int):
	game._new_event_game()
	game._close()
	var director=game.events_controller
	director.index=index
	for i in range(index): game.state.set_flag("event_done_"+director.events[i].id)
	var event=director.events[index]
	var place=game.journey.places[event.location]
	director.center=Vector2(place.point[0],place.point[1])
	game._build_world(place.zone,director.center+Vector2(0,60))
	director.npc=game.actors[event.npc]
	game.state.residents[event.npc].zone=place.zone
	game.npcs.attach(game,event.npc)
	director.npc.position=director.center
	game.npcs.capture(game)
	director.phase="ready"
	check(director.talk(event.npc) and game.event_window.active,"NPC opens "+event.id)

func run():
	root=get_tree().root
	get_tree().create_timer(120).timeout.connect(func():push_error("Quiet puzzle QA timeout");get_tree().quit(2))
	if not is_instance_valid(game):
		game=load("res://after_silence/scenes/main.tscn").instantiate()
		root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var source=OS.has_feature("editor")
	game.event_saves.path="user://qa_0190_puzzles_"+("source_" if source else "export_")+DisplayServer.get_name()+".json"
	var out="res://work/puzzles0190" if source else OS.get_executable_path().get_base_dir().path_join("qa-puzzles")
	DirAccess.make_dir_recursive_absolute(out)
	var director=game.events_controller
	for index in [3,5,6,9,11]:
		fixture(index)
		var event=director.events[index]
		var activity=director.activity
		var panel=game.event_window.puzzle_panel
		var resident:int=director.npc.get_instance_id()
		var location:Vector2=game.player.position
		check(activity.mode==Puzzle.EVENTS[event.id],"correct game "+event.id)
		check(game.actors.size()==8,"persistent population "+event.id)
		await click(panel.hint_button)
		var move: Array=panel.marked.duplicate()
		check(not move.is_empty(),"hint marks a move "+event.id)
		if move.is_empty(): break
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join(event.id+".png"))
		for tile in move: await click(panel.tiles[tile])
		check(activity.puzzle.history.size()==1,"mouse action "+event.id)
		await click(panel.undo_button)
		check(activity.puzzle.history.is_empty(),"undo "+event.id)
		for tile in move: await click(panel.tiles[tile])
		await escape()
		check(game.modal and game.event_window.pause_panel.visible,"Esc pause "+event.id)
		await escape()
		check(panel.is_ancestor_of(root.gui_get_focus_owner()),"focus restore "+event.id)
		check(game.player.position==location and director.npc.get_instance_id()==resident,"world participants kept "+event.id)
		await escape()
		await click(game.event_window.pause_panel.get_child(2))
		check(director.phase=="suspended" and not game.event_window.active,"save and leave "+event.id)
		await game._load_game()
		check(director.phase=="suspended" and director.activity.puzzle.history==[move],"reload "+event.id)
		game._close()
		director.resume_activity()
		panel=game.event_window.puzzle_panel
		await click(panel.reset_button)
		check(director.activity.puzzle.history.is_empty(),"restart board "+event.id)
		for attempt in range(Puzzle.MOVE_LIMIT):
			var model=director.activity.puzzle
			if director.phase!="running": break
			var next: Array=model.hint()
			if next.is_empty(): break
			for tile in next: await click(panel.tiles[tile])
		check(director.phase=="decision" and not game.event_window.active,"complete and exit "+event.id)
		director.choose(event.choices[0])
		check(game.state.flag("event_done_"+event.id),"story consequence "+event.id)
		check(game.world.sorter.has_node("Memento_"+event.id),"world consequence "+event.id)
		game._close()
	game.audio.shutdown()
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(.3,true,false,true).timeout
	print("QUIET PUZZLES QA: %d checks, %d failures"%[checks,failures])
	get_tree().quit(1 if failures else 0)
