extends RefCounted
signal quest_started(id: String)
signal objective_updated(id: String, completed: int, total: int)
signal quest_completed(id: String)
var state
var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/objectives.json"))
var progress={}
func _init(s): state=s
func meets(rule: Dictionary) -> bool:
	for id in rule.get("flags",[]):
		if not state.flag(id): return false
	for id in rule.get("relation",{}):
		if state.relations.get(id,0)<rule.relation[id]: return false
	for id in rule.get("items",{}):
		if state.item(id)<rule.items[id]: return false
	if rule.has("district") and not state.flag("district_"+rule.district): return false
	if rule.has("hours"):
		var a=float(rule.hours[0]);var b=float(rule.hours[1])
		if not (state.clock>=a and state.clock<b if a<b else state.clock>=a or state.clock<b): return false
	return true
func done(goal: Dictionary) -> bool:
	match goal.kind:
		"find":
			for i in range(int(goal.count)):
				if not state.flag(goal.prefix+str(i)): return false
			return true
		"visit": return state.flag("explored_"+goal.zone)
		"talk","choose","minigame": return state.flag(goal.flag)
	return false
func refresh():
	if not state.flag("rift_mode"): return
	for quest in data.quests:
		if not meets(quest.requires) or state.flag("objective_"+quest.id): continue
		if not state.flag("objective_started_"+quest.id):
			state.set_flag("objective_started_"+quest.id)
			quest_started.emit(quest.id)
		var count=0
		for goal in quest.goals:
			if done(goal): count+=1
		if progress.get(quest.id,-1)!=count:
			progress[quest.id]=count
			objective_updated.emit(quest.id,count,quest.goals.size())
		if count!=quest.goals.size(): continue
		state.set_flag("objective_"+quest.id)
		for flag in quest.effects.get("flags",[]): state.set_flag(flag)
		for id in quest.effects.get("items",{}): state.give(id,int(quest.effects.items[id]))
		quest_completed.emit(quest.id)
func journal(language: String) -> String:
	var lines=[]
	for quest in data.quests:
		if not meets(quest.requires): continue
		lines.append(("◆ " if state.flag("objective_"+quest.id) else "◇ ")+quest.title[1 if language=="en" else 0])
	return "\n".join(lines)
