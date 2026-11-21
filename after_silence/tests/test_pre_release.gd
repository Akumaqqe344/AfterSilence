extends GutTest

const Trial = preload("res://after_silence/core/archive_trials.gd")
const Save = preload("res://after_silence/core/save_manager.gd")
const State = preload("res://after_silence/core/world_state.gd")
const Comfort = preload("res://after_silence/ui/comfort_preferences.gd")

func test_relay_requires_both_pump_branches_and_an_isolated_bell():
	var solutions = []
	for upper in 4:
		for distributor in 4:
			for lower in 4:
				if Trial.solved("relay",[upper,distributor,lower]): solutions.append([upper,distributor,lower])
	assert_eq(solutions,[[1,2,2]])
	assert_true(Trial.circuits([1,1,2]).alarm)
	assert_false(Trial.solved("relay",[1,1,2]))

func test_archive_state_restores_only_valid_checkpoints():
	var source = State.new()
	source.archive_boards = {"catalog":[0,-1,-1],"clock":[0,17],"relay":[1,2,1],"unknown":[7]}
	source.case_orders = {"audio_order":[1,2],"copies_proof":[0,0]}
	var restored = State.new()
	assert_true(restored.restore(JSON.parse_string(JSON.stringify(source.to_data()))))
	assert_eq(restored.archive_boards,{"catalog":[0,-1,-1],"clock":[0,17],"relay":[1,2,1]})
	assert_eq(restored.case_orders,{"audio_order":[1,2]})
	assert_eq(Trial.checkpoint("clock",[24,60]),[0,0])

func test_0330_schema_preserves_progress_without_new_fields():
	var source = State.new()
	source.zone = "tide_station"
	source.case_trials = {"tide_winch":[1,1,0]}
	source.set_flag("case_choice_archive_joint")
	var old = source.to_data()
	old.erase("archive_boards")
	old.erase("case_orders")
	var restored = State.new()
	assert_true(restored.restore(old))
	assert_eq(restored.zone,"tide_station")
	assert_true(restored.flag("case_choice_archive_joint"))
	assert_eq(restored.case_trials["tide_winch"],[1,1,0])
	assert_eq(restored.archive_boards,{})

func test_corrupt_primary_cannot_replace_the_healthy_backup():
	var store = Save.new()
	store.path = "user://qa_recovery_090_%s.json" % Time.get_ticks_usec()
	var state = State.new()
	assert_true(store.save(state),store.last_error)
	state.set_flag("case_choice_archive_joint")
	assert_true(store.save(state),store.last_error)
	var backup = FileAccess.get_file_as_string(store.path+".bak")
	var damaged = FileAccess.open(store.path,FileAccess.WRITE)
	damaged.store_string("damaged primary")
	damaged.close()
	var recovered = State.new()
	assert_true(store.load_state(recovered))
	assert_eq(store.recovered_from,".bak")
	assert_false(recovered.flag("case_choice_archive_joint"))
	assert_true(store.save(recovered),store.last_error)
	assert_eq(FileAccess.get_file_as_string(store.path+".bak"),backup)
	var preserved = false
	for file in DirAccess.get_files_at("user://"):
		if file.begins_with(store.path.get_file()+".unreadable-"):
			preserved = FileAccess.get_file_as_string("user://"+file)=="damaged primary"
	assert_true(preserved)

func test_audio_levels_persist_independently():
	var prefs = Comfort.new()
	prefs.path = "user://qa_mix_090_%s.cfg" % Time.get_ticks_usec()
	prefs.volume = .65
	prefs.music_volume = 0
	prefs.effects_volume = .8
	assert_eq(prefs.save_preferences(),OK)
	var loaded = Comfort.new()
	loaded.path = prefs.path
	loaded.load_preferences()
	assert_eq(loaded.volume,.65)
	assert_eq(loaded.music_volume,0.0)
	assert_eq(loaded.effects_volume,.8)
