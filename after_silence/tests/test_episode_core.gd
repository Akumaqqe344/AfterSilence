extends GutTest
const State=preload("res://after_silence/core/world_state.gd")
const Saves=preload("res://after_silence/core/save_manager.gd")
const Evidence=preload("res://after_silence/core/evidence_manager.gd")
const Inventory=preload("res://after_silence/core/inventory_manager.gd")
const Quests=preload("res://after_silence/core/quest_manager.gd")
const NPCs=preload("res://after_silence/core/npc_state_controller.gd")
const Dialogue=preload("res://after_silence/core/dialogue_manager.gd")
var state
var saves
func before_each():
	state=State.new()
	saves=Saves.new()
	saves.path="user://gut_episode_"+str(Time.get_ticks_usec())+".json"
func after_each():
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(saves.path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.path+suffix))
func test_inventory_rejects_unknown_and_negative():
	assert_false(state.give("unknown"))
	assert_false(state.give("fuse",-1))
	assert_true(state.give("fuse"))
	assert_eq(state.item("fuse"),1)
func test_fuse_alternatives_preserve_progress():
	var inv=Inventory.new(state)
	state.give("fuse")
	assert_true(inv.install_fuse("library_light"))
	assert_false(inv.install_fuse("forest_power"))
	assert_true(inv.remove_library_fuse())
	assert_false(inv.remove_library_fuse())
	assert_true(inv.install_fuse("forest_power"))
	assert_eq(state.item("fuse"),0)
	assert_true(state.flag("forest_power"))
func test_fuse_wrong_socket_does_not_consume():
	state.give("fuse")
	assert_false(Inventory.new(state).install_fuse("anything"))
	assert_eq(state.item("fuse"),1)
func test_evidence_requires_collected_distinct_pair():
	var evidence=Evidence.new(state)
	assert_eq(evidence.connect_clues("poster","clock"),"")
	state.add_clue("poster")
	state.add_clue("clock")
	assert_eq(evidence.connect_clues("poster","poster"),"")
	assert_eq(evidence.connect_clues("clock","poster"),"date")
	assert_eq(evidence.connect_clues("poster","clock"),"date")
	assert_eq(state.links.size(),1)
func test_all_authored_inferences():
	var evidence=Evidence.new(state)
	for id in State.CLUES: state.add_clue(id)
	for id in Evidence.PAIRS:
		var pair=Evidence.PAIRS[id]
		assert_eq(evidence.connect_clues(pair[0],pair[1]),id)
	assert_eq(state.links.size(),4)
func test_state_round_trip():
	state.set_flag("promise")
	state.give("lens")
	state.add_clue("photo")
	state.echo=true
	state.zone="forest"
	state.position=Vector2(700,940)
	var copy=State.new()
	assert_true(copy.restore(state.to_data()))
	assert_eq(copy.to_data(),state.to_data())
func test_malformed_save_is_transactional():
	state.set_flag("promise")
	var before=state.to_data()
	for key in ["charges","pressure","clock","play_seconds","volume"]:
		var data=state.to_data()
		data[key]="invalid"
		assert_false(state.restore(data),key)
		assert_eq(state.to_data(),before)
	for key in ["inventory","relations"]:
		var data=state.to_data()
		data[key]={"fuse":[]}
		assert_false(state.restore(data),key)
		assert_eq(state.to_data(),before)
func test_bad_zone_position_and_containers():
	for pair in [["zone","missing"],["position",[INF,5]],["position",[1]],["evidence",{}],["flags",[]]]:
		var data=state.to_data()
		data[pair[0]]=pair[1]
		assert_false(state.restore(data),pair[0])
func test_unknown_values_filtered_and_numeric_values_clamped():
	var data=state.to_data()
	data.evidence=["photo","fake"]
	data.links=["date","fake"]
	data.inventory={"fuse":1e200,"fake":2}
	data.charges=1e200
	data.pressure=-12
	assert_true(state.restore(data))
	assert_eq(state.evidence,["photo"])
	assert_eq(state.links,["date"])
	assert_eq(state.item("fuse"),9)
	assert_eq(state.item("fake"),0)
	assert_eq(state.charges,3)
	assert_eq(state.pressure,0)
func test_checksummed_save_and_load():
	state.set_flag("promise")
	assert_true(saves.save(state))
	var copy=State.new()
	assert_true(saves.load_state(copy))
	assert_true(copy.flag("promise"))
func test_corrupt_main_recovers_previous_backup():
	state.set_flag("promise")
	assert_true(saves.save(state))
	state.set_flag("newer")
	assert_true(saves.save(state))
	var file=FileAccess.open(saves.path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var copy=State.new()
	assert_true(saves.load_state(copy))
	assert_true(copy.flag("promise"))
	assert_false(copy.flag("newer"))
func test_checksum_tamper_does_not_mutate_state():
	assert_true(saves.save(state))
	var envelope=JSON.parse_string(FileAccess.get_file_as_string(saves.path))
	envelope.payload=envelope.payload+" "
	var file=FileAccess.open(saves.path,FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	state.set_flag("safe")
	assert_false(saves.load_state(state))
	assert_true(state.flag("safe"))
func test_unknown_version_rejected():
	assert_true(saves.save(state))
	var envelope=JSON.parse_string(FileAccess.get_file_as_string(saves.path))
	envelope.version=999
	var file=FileAccess.open(saves.path,FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	assert_false(saves.load_state(state))
func test_relations_and_daily_schedule():
	var npcs=NPCs.new(state)
	npcs.change_relation("nadia",90)
	assert_eq(state.relations.nadia,5)
	npcs.change_relation("nadia",-90)
	assert_eq(state.relations.nadia,-5)
	assert_ne(npcs.destination("nadia",Vector2.ZERO,8),npcs.destination("nadia",Vector2.ZERO,18))
func test_dialogue_history_and_seen_bound():
	var dialogue=Dialogue.new(state)
	for i in range(120): dialogue.record("d"+str(i),"Speaker","Text")
	assert_eq(state.history.size(),100)
	assert_eq(state.seen.size(),100)
	assert_true(dialogue.was_seen("d119"))
	assert_false(dialogue.was_seen("d0"))
func test_quest_progression():
	var quests=Quests.new(state)
	assert_eq(quests.stage(),1)
	state.set_flag("nadia_met")
	assert_eq(quests.stage(),2)
	state.set_flag("catalog")
	state.set_flag("clock_solved")
	assert_eq(quests.stage(),3)
	state.set_flag("forest_power")
	assert_eq(quests.stage(),4)
	state.set_flag("sonya_met")
	assert_eq(quests.stage(),5)
	state.set_flag("returned")
	assert_eq(quests.stage(),6)
	state.set_flag("ending")
	assert_eq(quests.stage(),7)
func test_house_and_resident_save_round_trip():
	state.zone="home_lev"
	state.position=Vector2(320,350)
	NPCs.new(state).initialize()
	state.residents.nadia.zone="home_nadia"
	var copy=State.new()
	assert_true(copy.restore(state.to_data()))
	assert_eq(copy.zone,"home_lev")
	assert_eq(copy.residents,state.residents)
func test_invalid_resident_does_not_mutate_state():
	var before=state.to_data()
	for resident in [{"zone":"home_nadia"},{"zone":"town","x":[],"y":300},{"zone":"missing","x":200,"y":200}]:
		var data=state.to_data()
		data.residents={"nadia":resident}
		assert_false(state.restore(data))
		assert_eq(state.to_data(),before)
func test_old_saves_without_residents_are_accepted():
	var data=state.to_data()
	data.erase("residents")
	assert_true(state.restore(data))
	NPCs.new(state).initialize()
	assert_eq(state.residents.size(),5)
func test_achievements_survive_save_and_reject_unknown_ids():
	var achievements=load("res://after_silence/core/achievements.gd")
	state.add_clue("photo")
	assert_eq(achievements.evaluate(state),["first_clue"])
	assert_eq(achievements.evaluate(state).size(),0)
	var copy=State.new()
	assert_true(copy.restore(state.to_data()))
	assert_true("first_clue" in copy.achievements)
	var data=state.to_data()
	data.achievements.append("fake")
	assert_true(copy.restore(data))
	assert_false("fake" in copy.achievements)
func test_boss_telegraph_jump_and_three_counters():
	for action in ["as_left","as_right","as_up","as_down"]:
		if not InputMap.has_action(action): InputMap.add_action(action)

	var battle=load("res://after_silence/world/boss_battle.gd").new()
	add_child(battle)
	battle.start("relay",false)
	assert_false(battle.counter())
	battle.phase="attack"
	battle.target=battle.player_pos
	battle._physics_process(.016)
	assert_eq(battle.player_hp,2)
	battle.invulnerable=0
	battle.jump_age=0
	battle._hit()
	assert_eq(battle.player_hp,2)
	for i in range(3):
		battle.phase="exposed"
		battle.player_pos=Vector2(320,185)
		assert_true(battle.counter())
	assert_false(battle.active)
	battle.queue_free()
	await get_tree().process_frame

func test_ending_achievements_match_branch():
	var achievements=load("res://after_silence/core/achievements.gd")
	state.set_flag("ending_public",true)
	state.set_flag("ending")
	achievements.evaluate(state)
	assert_true("public_end" in state.achievements)
	assert_false("sealed_end" in state.achievements)
	var sealed=State.new()
	sealed.set_flag("ending_public",false)
	sealed.set_flag("ending")
	achievements.evaluate(sealed)
	assert_true("sealed_end" in sealed.achievements)
	assert_false("public_end" in sealed.achievements)
func test_quest_steps_follow_chapter_progress():
	var quests=Quests.new(state)
	assert_eq(quests.steps().size(),1)
	state.set_flag("nadia_met")
	assert_eq(quests.steps().size(),4)
	assert_false(quests.steps()[0][0])
	state.set_flag("mara_met")
	assert_true(quests.steps()[0][0])

func test_event_checkpoint_rejects_corruption_without_mutation():
	var activity={"mode":"epochs","elapsed":17.0,"progress":2.0,"hp":5,"step":2,"alert":0.0,"heat":0.0,"npc":[320,310],"epoch":1}
	state.event_state={"version":2,"index":2,"phase":"suspended","activity":activity}
	var data=state.to_data()
	var copy=State.new()
	assert_true(copy.restore(data))
	assert_eq(copy.event_state.activity.epoch,1)
	for value in ["2",3,{},false]:
		var corrupt=data.duplicate(true)
		corrupt.event_state.version=value
		assert_false(copy.restore(corrupt))
		assert_eq(copy.to_data(),data)
	for value in [-1,2,"past",[],{}]:
		var corrupt=data.duplicate(true)
		corrupt.event_state.activity.epoch=value
		var before=copy.to_data()
		assert_false(copy.restore(corrupt))
		assert_eq(copy.to_data(),before)
	var old=data.duplicate(true)
	old.event_state.erase("version");old.event_state.activity.erase("epoch")
	assert_true(copy.restore(old))
