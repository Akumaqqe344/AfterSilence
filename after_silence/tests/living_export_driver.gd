extends Node
var game
var checks=0
var failures=0
func check(value: bool,label: String):
	checks+=1
	if not value: failures+=1;push_error(label)
func _ready(): call_deferred("run")
func run():
	game.rift_saves.path="user://qa_living_export.json"
	game._new_rift_game()
	game.rift.active=false;game.rift.hide();game.rift.phase="travel"
	game._close()
	game.set_physics_process(false);game.living.set_physics_process(false)
	check(game.living.data.version==1,"packed JSON loaded")
	game.living.remember("lev","help")
	check(game.living.talk("lev"),"packed dialogue usable")
	check(game.body.text.contains("помню"),"memory changes dialogue")
	game._close()
	game.living.handle("cache_supplies")
	check(game.state.item("bandage")==1,"packed stash award")
	game.state.charges=0;game._item("bandage");game._close()
	check(game.state.charges==3,"packed inventory action")
	game.state.set_flag("district_orchard");game.living.tick(91)
	check(game.state.flag("delivery_arrived"),"packed offscreen event")
	game.state.set_flag("rift_q08_done");game.living.tick(0)
	check(game.state.flag("clinic_ready"),"packed quest consequence")
	game._build_world("home_sonya",Vector2(320,395))
	check(game.world.interactables.any(func(spot):return spot.id=="personal_letter"),"packed personal hotspot")
	game.state.play_seconds=181;game.living.tick(0)
	check(game.state.flag("weather_rain"),"packed weather")
	var state=load("res://after_silence/core/world_state.gd").new()
	check(state.restore(game.state.to_data()) and state.last_memories.lev=="stash","packed save compatibility")
	var art=load("res://after_silence/core/art_catalog.gd")
	check(art.data.props.size()==40,"packed art catalog")
	for id in art.data.props:
		check(load(art.BASE+art.data.props[id].file)!=null,"packed texture "+id)
	game.state.set_flag("bridge_repaired")
	game._build_world("town",Vector2(600,1020))
	check(game.world.sorter.get_children().filter(func(prop):return prop.get("kind")=="bridge").size()==2,"two packed river crossings")
	check(not game.world.sorter.get_children().any(func(prop):return prop.get("kind")=="rug"),"no packed outdoor rugs")
	game.audio.shutdown()
	check(load("res://after_silence/assets/art120/shop_front.png")!=null,"packed shop sprite")
	check(load("res://after_silence/assets/art120/well.png")!=null,"packed well sprite")
	game.state.tokens=3
	check(game.shop.buy("bandage") and game.state.tokens==1,"packed shop purchase")
	check(not game.shop.buy("keepsake") and game.state.tokens==1,"packed shop insufficient funds")
	game._build_world("shop",Vector2(320,395))
	check(game.world.interactables.any(func(s):return s.id=="shop_counter"),"packed shop interior")
	check(game.npcs.routine.current("nadia",0)[5]=="sleep","packed midnight schedule")
	check(game.inventory.catalog.size()==6,"packed item catalog")
	game.state.give("bandage")
	check(game.inventory.craft_badge(),"packed crafting")
	check(game.inventory.transfer("keepsake",true),"packed storage")
	check(game.battle.ai.get_child_count()==3,"packed Beehave")
	game.talkkit_pilot.play()
	await get_tree().process_frame
	check(game.talkkit_pilot.talk.state!=NPCTalkKit.State.IDLE,"packed TalkKit")
	game.talkkit_pilot.talk.stop()
	game._close()
	print("LIVING EXPORT QA: %d checks, %d failures"%[checks,failures])
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(.3).timeout
	get_tree().quit(0 if failures==0 else 1)
