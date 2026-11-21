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
	if mode=="reality": reality=Reality.new(event.id)
	elif mode in Trials.ACTIONS: trial=Trials.new(mode,variant)
	else: puzzle=Puzzle.new(mode)

func checkpoint() -> Dictionary:
	if reality!=null: return {"mode":mode,"reality":reality.capture()}
	if trial!=null:
		var data={"mode":mode,"moves":trial.capture()}
		if not variant.is_empty(): data.variant=variant
		return data
	return {"mode":mode,"moves":puzzle.checkpoint()}

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
