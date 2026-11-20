extends RefCounted

const Puzzle=preload("res://after_silence/core/quiet_puzzle.gd")
const Reality=preload("res://after_silence/core/reality_maze.gd")
var mode: String
var puzzle
var reality

func _init(event: Dictionary):
	mode=event.mode
	if mode=="reality": reality=Reality.new(event.id)
	else: puzzle=Puzzle.new(mode)

func checkpoint() -> Dictionary:
	if reality!=null: return {"mode":mode,"reality":reality.capture()}
	return {"mode":mode,"moves":puzzle.checkpoint()}

func restore(data: Dictionary):
	if reality!=null: reality.restore(data.get("reality"))
	else: puzzle.restore(data.get("moves"))

func goal() -> int:
	return reality.order.size() if reality!=null else puzzle.goal()

func progress() -> int:
	return reality.stage if reality!=null else puzzle.progress()
