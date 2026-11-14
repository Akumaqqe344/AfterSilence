extends RefCounted
const NUMBERS={"index":[0,11],"elapsed":[0,100000],"remaining":[0,60],"health":[1,3],"rescued":[0,20],"switch_round":[0,20],"beat":[0,8],"beat_age":[0,10],"mask":[0,15],"wave":[0,10000],"lane":[0,2],"guard_age":[0,2],"reveal_time":[0,10]}
static func valid(data: Dictionary) -> bool:
	if data.is_empty(): return true
	if not data.get("phase","") in ["play","decision","intro"]: return false
	for key in NUMBERS:
		var value=data.get(key)
		if not (value is float or value is int) or not is_finite(float(value)): return false
		if value<NUMBERS[key][0] or value>NUMBERS[key][1]: return false
	for key in ["player_pos","escort_pos"]:
		var v=data.get(key)
		if not v is Array or v.size()!=2: return false
		for n in v:
			if not (n is float or n is int) or not is_finite(float(n)) or n<0 or n>640: return false
	for key in ["board","picked","matched"]:
		var list=data.get(key)
		if not list is Array or list.size()>8: return false
		for n in list:
			if not (n is float or n is int) or n!=int(n) or n<0 or n>7: return false
	if data.phase!="intro":
		var mode=preload("res://after_silence/core/quest_catalog.gd").data.quests[int(data.index)].mode
		var expected=8 if mode=="memory" else 4 if mode=="circuit" else 6
		if data.board.size()!=expected: return false
		if mode=="memory":
			for n in data.board:
				if n<1 or n>4: return false
		if mode=="circuit" and data.board.any(func(n):return n>3): return false
		for key in ["picked","matched"]:
			for n in data[key]:
				if n>=expected: return false
	return true

static func capture(rift) -> Dictionary:
	var data={"phase":rift.before_pause if rift.phase=="pause" else rift.phase}
	for key in NUMBERS: data[key]=rift.get(key)
	for key in ["board","picked","matched"]: data[key]=rift.get(key).duplicate()
	for key in ["player_pos","escort_pos"]:
		var p=rift.get(key)
		data[key]=[p.x,p.y]
	return data if valid(data) else {}

static func apply(rift, data: Dictionary) -> bool:
	if data.is_empty() or not valid(data) or int(data.index)!=rift.index: return false
	for key in NUMBERS: rift.set(key,data[key])
	for key in ["board","picked","matched"]: rift.set(key,data[key].map(func(n):return int(n)))
	for key in ["player_pos","escort_pos"]: rift.set(key,Vector2(data[key][0],data[key][1]))
	# JSON numbers have no integer type guarantee; bitmasks and indices require ints.
	for key in ["index","health","rescued","switch_round","beat","mask","wave","lane"]: rift.set(key,int(data[key]))
	rift.phase=data.phase
	rift.show_phase()
	return true
