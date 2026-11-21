extends RefCounted

const Puzzle=preload("res://after_silence/core/quiet_puzzle.gd")
const Reality=preload("res://after_silence/core/reality_maze.gd")
const Trials=preload("res://after_silence/core/journey_trials.gd")
var mode: String
var puzzle
var reality
var trial
var variant: String=""

func _init(event: Dictionary):
	mode=event.mode
	variant=event.get("variant","")
	if mode=="reality": reality=Reality.new(event.id,variant)
	elif mode in Trials.ACTIONS: trial=Trials.new(mode,variant)
	else: puzzle=Puzzle.new(mode,variant)

func checkpoint() -> Dictionary:
	var data = {"mode":mode}
	if not variant.is_empty(): data.variant = variant
	if reality!=null: data.reality = reality.capture()
	elif trial!=null: data.moves = trial.capture()
	else: data.moves = puzzle.checkpoint()
	return data

func restore(data: Dictionary):
	if reality!=null: reality.restore(data.get("reality"))
	elif trial!=null: trial.restore(data.get("moves"))
	else: puzzle.restore(data.get("moves"))

func goal() -> int:
	if trial!=null: return trial.goal()
	return reality.order.size() if reality!=null else puzzle.goal()

func progress() -> int:
	if trial!=null: return trial.progress()
	return reality.stage if reality!=null else puzzle.progress()
