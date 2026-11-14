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
