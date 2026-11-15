extends Node
var game
var checks=0
var failures=0
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures+=1;push_error(label)
func _ready(): call_deferred("run")
func run():
	game.event_saves.path="user://qa_events_export140.json"
	game._new_event_game();game.set_physics_process(false)
	var director=game.events_controller
	director.set_physics_process(false)
	game._close()
	for frame in range(1200):
		game.npcs.update(game,.05,true)
		director._physics_process(0)
		if director.phase!="travel": break
	game._close()
	check(director.events.size()==12,"packed twelve NPC events")
	for event in director.events:
		check(event.choices.size()>=2,"packed alternatives "+event.id)
		check(event.mode in preload("res://after_silence/core/event_progress.gd").MODES,"packed activity "+event.mode)
	check(game.world.interactables.all(func(s):return s.id not in ["rift_next","hotspot_lamp"] and not str(s.id).begins_with("collect_")),"packed world has no quest lamps or collections")
	game.player.position=director.npc.position+Vector2(0,60)
	director._physics_process(3.2)
	check(director.phase=="ready","packed observation")
	director.talk("lev");check(game.buttons.has("help"),"packed NPC dialogue")
	director.begin_preparation();game.player.position=director.preparation_point()
	check(director.complete_preparation(),"packed required world action")
	director.activity.set_physics_process(false)
	director.activity.elapsed=15;director.activity.progress=2
	game._save(false)
	await game._load_game()
	check(director.phase=="running" and director.activity.elapsed==15 and director.activity.progress==2,"packed save resume")
	director.activity.set_physics_process(false)
	director.activity.hp=0;director.activity.tick(.01)
	check(director.phase=="failure","packed defeat")
	game.body.visible_characters=-1
	game.buttons.retry.pressed.emit()
	check(director.activity.hp==5,"packed retry")
	director.activity.active=false
	game.event_window.close()
	game.audio.shutdown();game.queue_free()
	await get_tree().process_frame;await get_tree().create_timer(.3).timeout
	print("NPC EVENTS EXPORT QA: %d checks, %d failures"%[checks,failures])
	get_tree().quit(1 if failures else 0)
