extends GutTest

const Puzzle=preload("res://after_silence/core/quiet_puzzle.gd")
const Checkpoint=preload("res://after_silence/core/event_progress.gd")

func test_all_boards_complete_with_accessible_hints():
	for mode in Puzzle.SIZES:
		var puzzle=Puzzle.new(mode)
		for attempt in range(Puzzle.MOVE_LIMIT):
			if puzzle.won(): break
			var move=puzzle.hint()
			assert_false(move.is_empty(),mode)
			if move.is_empty(): break
			assert_true(puzzle.submit(move),mode)
		assert_true(puzzle.won(),mode)
		assert_eq(puzzle.progress(),puzzle.goal(),mode)

func test_save_round_trip_and_undo_are_transactional():
	for mode in Puzzle.SIZES:
		var original=Puzzle.new(mode)
		var moves=original.hint()
		assert_true(original.submit(moves),mode)
		var saved=JSON.parse_string(JSON.stringify(original.checkpoint()))
		var copy=Puzzle.new(mode)
		assert_true(copy.restore(saved),mode)
		assert_eq(copy.board,original.board,mode)
		assert_false(copy.restore([[0,9999]]),mode)
		assert_eq(copy.board,original.board,mode)
		copy.undo()
		assert_eq(copy.board,Puzzle.new(mode).board,mode)
		assert_eq(copy.round_index,0,mode)

func test_bad_moves_leave_boards_and_progress_untouched():
	for mode in Puzzle.SIZES:
		var puzzle=Puzzle.new(mode)
		var before=puzzle.board.duplicate(true)
		assert_false(puzzle.submit([0,0]),mode)
		assert_eq(puzzle.board,before,mode)
		assert_true(puzzle.checkpoint().is_empty(),mode)

func test_only_the_matching_event_accepts_a_puzzle_save():
	var activity={"mode":"tubes","moves":[],"npc":[250,300],"hp":5,"elapsed":0,"progress":0,"step":0,"alert":0,"heat":0}
	var event={"version":3,"index":3,"phase":"suspended","activity":activity}
	assert_true(Checkpoint.valid(event))
	event.index=5
	assert_false(Checkpoint.valid(event))
	event.index=3
	activity.mode="repair"
	activity.erase("moves")
	assert_true(Checkpoint.valid(event))
