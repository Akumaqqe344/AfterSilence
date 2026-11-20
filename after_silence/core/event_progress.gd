extends RefCounted
const Puzzle=preload("res://after_silence/core/quiet_puzzle.gd")
const Reality=preload("res://after_silence/core/reality_maze.gd")
const MODES=["escort","rhythm","stealth","switches","epochs","route","defense","evacuation","dodge","repair","tactics","tubes","pairs","seeds","lights","shelves","reality"]
const PUZZLE_STOPS={3:"tubes",5:"pairs",6:"seeds",9:"lights",11:"shelves"}
static func valid(data: Dictionary) -> bool:
	if data.is_empty(): return true
	var version=data.get("version",1)
	if not (version is int or version is float) or version not in [1,2,3,1.0,2.0,3.0]: return false
	if data.get("phase","") not in ["travel","observe","ready","action","running","suspended","decision","failure","finished"]: return false
	var index=data.get("index",-1)
	if not (index is int or index is float) or not is_finite(float(index)) or index!=int(index) or index<0 or index>(12 if data.get("version",1)>=2 else 9): return false
	var activity=data.get("activity",{})
	if not activity is Dictionary: return false
	if not activity.is_empty():
		if activity.get("mode","") not in MODES: return false
		if activity.mode=="reality":
			var id: String=Reality.STOPS.get(int(index),"")
			if id=="" or not Reality.new(id).restore(activity.get("reality")): return false
		if Puzzle.SIZES.has(activity.mode):
			if PUZZLE_STOPS.get(int(index))!=activity.mode or not activity.has("moves"): return false
			if not Puzzle.new(activity.mode).restore(activity.moves): return false
		if activity.mode=="tactics":
			if not activity.get("tactics") is Dictionary or not preload("res://after_silence/world/tactical_encounter.gd").valid(activity.tactics): return false
			if int(index) not in [4,7] or activity.tactics.encounter!=("bridge" if int(index)==4 else "crowd"): return false
		for key in ["elapsed","progress","hp","step","alert","heat"]:
			var n=activity.get(key)
			if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>10000: return false
		if activity.hp>5 or activity.elapsed>(3600 if activity.mode=="epochs" else 110): return false
		if activity.has("maze"):
			if activity.mode!="epochs" or not activity.maze is Dictionary or not preload("res://after_silence/core/sonya_maze_layout.gd").valid(activity.maze): return false
		if activity.get("epoch",0) not in [0,1,0.0,1.0]: return false
		var p=activity.get("npc")
		if not p is Array or p.size()!=2: return false
		for n in p:
			if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>2000: return false
		var recruited=activity.get("recruited",[])
		if not recruited is Array or recruited.size()>3: return false
		for n in recruited:
			if n not in [0,1,2,0.0,1.0,2.0]: return false
		var people=activity.get("followers",[])
		if not people is Array or people.size()>3: return false
		for person in people:
			if not person is Dictionary or not person.get("rescued") is bool: return false
			var pos=person.get("position")
			if not pos is Array or pos.size()!=2: return false
			for n in pos:
				if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>2000: return false
	return true
