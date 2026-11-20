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
	var modes={}
	for event in director.events:
		check(event.choices.size()>=2,"packed alternatives "+event.id)
		check(event.mode in preload("res://after_silence/core/event_progress.gd").MODES,"packed activity "+event.mode)
		check(not modes.has(event.mode),"unique mechanic "+event.mode)
		modes[event.mode]=true
	check(game.world.interactables.all(func(s):return s.id not in ["rift_next","hotspot_lamp"] and not str(s.id).begins_with("collect_")),"packed world has no quest lamps or collections")
	game.player.position=director.npc.position+Vector2(0,60)
	director._physics_process(3.2)
	check(director.phase=="ready","packed observation")
	director.talk("lev");check(game.buttons.has("help"),"packed NPC dialogue")
	director.begin_preparation();game.player.position=director.preparation_point()
	check(director.complete_preparation(),"packed required world action")
	game.event_window.leave()
	var position=game.state.position
	game.state.event_state={"version":3,"index":0,"phase":"running","activity":{"mode":"escort","elapsed":15,"progress":2,"hp":3}}
	check(game.saves.save(game.state),"write old checkpoint to isolated QA slot")
	await game._load_game()
	check(director.phase=="running" and director.activity.mode=="letter_press","old escort opens letter restoration")
	check(director.activity.trial.history.is_empty() and game.state.position==position,"migration starts new board at same world position")
	check(game.state.flag("event_action_letter"),"completed world preparation retained")
	game.event_window.toggle_pause()
	game.event_window.retry()
	check(game.event_window.active and director.activity.mode=="letter_press","retry opens only the replacement")
	game.event_window.leave()
	var guest=director.events[1]
	var place=game.journey.places[guest.location]
	var site=Vector2(place.point[0],place.point[1])
	game.state.set_flag("event_done_letter")
	game._build_world(place.zone,site+Vector2(0,45))
	game.state.position=game.player.position
	var resident=game.state.residents[guest.npc]
	resident.zone=place.zone;resident.x=site.x;resident.y=site.y
	game.state.event_state={"version":3,"index":1,"phase":"suspended","activity":{"mode":"reality","reality":{"stage":1,"reflected":true,"tile":[4,5]}}}
	check(game.saves.save(game.state),"write the old repeated maze checkpoint")
	await game._load_game()
	check(director.index==1 and director.phase=="suspended" and director.activity.mode=="footprints","repeated maze resumes as a clue trial")
	check(game.state.flag("event_done_letter") and game.state.flag("event_action_guest"),"previous event and preparation retained")
	director.resume_activity()
	check(game.event_window.active and director.activity.trial.round_index==0,"resume cannot reopen the repeated maze")
	game.event_window.leave()
	game.audio.shutdown();game.queue_free()
	await get_tree().process_frame;await get_tree().create_timer(.3).timeout
	print("NPC EVENTS EXPORT QA: %d checks, %d failures"%[checks,failures])
	get_tree().quit(1 if failures else 0)
