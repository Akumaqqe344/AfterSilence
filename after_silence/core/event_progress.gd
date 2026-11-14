extends RefCounted
const MODES=["escort","rhythm","stealth","switches","route","defense","evacuation","dodge","repair"]
static func valid(data: Dictionary) -> bool:
	if data.is_empty(): return true
	if data.get("phase","") not in ["observe","ready","running","decision","failure","finished"]: return false
	var index=data.get("index",-1)
	if not (index is int or index is float) or not is_finite(float(index)) or index!=int(index) or index<0 or index>9: return false
	var activity=data.get("activity",{})
	if not activity is Dictionary: return false
	if not activity.is_empty():
		if activity.get("mode","") not in MODES: return false
		for key in ["elapsed","progress","hp","step","alert","heat"]:
			var n=activity.get(key)
			if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>10000: return false
		if activity.hp>5 or activity.elapsed>110: return false
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
