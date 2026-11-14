extends RefCounted
var running=false
func play(game, id: String, steps: Array):
	if id in game.state.seen: return
	running=true
	for step in steps:
		match step.kind:
			"move":
				var actor=game.player if step.actor=="vera" else game.actors.get(step.actor)
				if not is_instance_valid(actor): continue
				actor.target=step.target
				actor.scripted=true
				var elapsed=0.0
				while actor.position.distance_to(actor.target)>3 and elapsed<3:
					await game.get_tree().physics_frame
					elapsed+=1.0/Engine.physics_ticks_per_second
				actor.scripted=false
			"camera":
				var tween=game.create_tween()
				tween.tween_property(game.camera,"offset",step.offset,step.duration)
				await tween.finished
			"sound": game.audio.ping(game.state.volume)
			"wait": await game.get_tree().create_timer(step.duration).timeout
	game.state.seen.append(id)
	running=false
