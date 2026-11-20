extends GutTest

const Trials=preload("res://after_silence/core/journey_trials.gd")
const Progress=preload("res://after_silence/core/event_progress.gd")

func test_all_twelve_story_stops_have_different_modes():
	var events=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/npc_events.json")).events
	var modes={}
	assert_eq(events.size(),12)
	for i in range(events.size()):
		assert_false(modes.has(events[i].mode),events[i].id)
		modes[events[i].mode]=true
		if Trials.STOPS.has(i): assert_eq(events[i].mode,Trials.STOPS[i])

func test_each_trial_can_be_solved_and_saved_part_way():
	for kind in Trials.ACTIONS:
		var trial=Trials.new(kind)
		assert_true(trial.perform(trial.hint()),kind)
		var checkpoint=JSON.parse_string(JSON.stringify(trial.capture()))
		var copy=Trials.new(kind)
		assert_true(copy.restore(checkpoint),kind)
		assert_eq(copy.state,trial.state,kind)
		assert_eq(copy.round_index,trial.round_index,kind)
		assert_false(copy.restore([999]),kind)
		assert_eq(copy.capture(),trial.capture(),kind)
		copy.undo()
		assert_eq(copy.state,Trials.new(kind).state,kind)
		for attempt in range(Trials.MOVE_LIMIT):
			if trial.won(): break
			assert_true(trial.perform(trial.hint()),kind)
		assert_true(trial.won(),kind)
		assert_eq(trial.progress(),trial.goal(),kind)

func test_wrong_route_and_wrong_wave_do_not_advance():
	var train=Trials.new("railway")
	var echo=Trials.new("echo_tuning")
	assert_false(train.perform(3))
	assert_false(echo.perform(4))
	assert_eq(train.progress(),0)
	assert_eq(echo.progress(),0)
	assert_eq(train.capture(),[])
	assert_eq(echo.capture(),[])

func test_resume_uses_story_stop_and_discards_replaced_layout():
	var old={"version":3,"index":4,"phase":"suspended","activity":{"mode":"reality","reality":{"stage":1,"tile":[4,5],"reflected":true}}}
	assert_true(Progress.valid(old))
	var replaced=Progress.upgrade(old,{"id":"bridge","mode":"balance"})
	assert_eq(replaced.activity,{"mode":"balance","moves":[]})
	assert_eq(replaced.phase,"suspended")
	assert_true(Progress.valid(replaced))
	replaced.index=1
	assert_false(Progress.valid(replaced))
