extends RefCounted

const Puzzle=preload("res://after_silence/core/quiet_puzzle.gd")
const Reality=preload("res://after_silence/core/reality_maze.gd")
const Trials=preload("res://after_silence/core/journey_trials.gd")
const MODES=["tubes","pairs","seeds","lights","shelves","reality","letter_press","footprints","balance","signal_grid","railway","echo_tuning"]
const PUZZLE_STOPS={3:"tubes",5:"pairs",6:"seeds",9:"lights",11:"shelves"}
# Recognize obsolete save markers so a valid story slot can be migrated.
const RETIRED=["escort","rhythm","stealth","switches","epochs","route","defense","evacuation","dodge","repair","tactics"]

static func valid(data: Dictionary) -> bool:
	if data.is_empty(): return true
	var version=data.get("version",1)
	if not (version is int or version is float) or version not in [1,2,3,1.0,2.0,3.0]: return false
	if data.get("phase","") not in ["travel","observe","ready","action","running","suspended","decision","failure","finished"]: return false
	var index=data.get("index",-1)
	if not (index is int or index is float) or not is_finite(float(index)) or index<0 or index>(12 if version>=2 else 9) or index!=int(index): return false
	var activity=data.get("activity",{})
	if not activity is Dictionary: return false
	if activity.is_empty(): return true
	var mode=activity.get("mode","")
	var variant: Variant = activity.get("variant", "")
	if not variant is String or variant not in ["", "quiet_plaza", Trials.FIELD_VARIANT]: return false
	if variant == "quiet_plaza" and mode != "signal_grid": return false
	if mode in RETIRED: return true
	if mode=="reality":
		if Trials.STOPS.has(int(index)): return activity.get("reality") is Dictionary
		var id: String=Reality.STOPS.get(int(index),"")
		return id!="" and Reality.new(id,variant).restore(activity.get("reality"))
	if mode in Trials.ACTIONS:
		return Trials.STOPS.get(int(index))==mode and Trials.new(mode,variant).restore(activity.get("moves"))
	return mode in Puzzle.SIZES and PUZZLE_STOPS.get(int(index))==mode and Puzzle.new(mode,variant).restore(activity.get("moves"))

static func upgrade(data: Dictionary, event: Dictionary) -> Dictionary:
	var saved=data.duplicate(true)
	var stage=saved.get("phase","")
	if stage=="failure": saved.phase="suspended"
	if stage in ["observe","action"]: saved.phase="travel"
	if stage in ["failure","running","suspended"] and saved.get("activity",{}).get("mode","")!=event.mode:
		if event.mode=="reality":
			saved.activity={"mode":"reality","reality":Reality.new(event.id).capture()}
		else:
			saved.activity={"mode":event.mode,"moves":[]}
	return saved
