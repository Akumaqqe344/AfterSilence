extends RefCounted
static var data: Dictionary=read_catalog()
static func read_catalog() -> Dictionary:
	var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://after_silence/data/campaign.json"))
	assert(parsed is Dictionary and parsed.get("version")==1,"Invalid campaign version")
	assert(parsed.quests is Array and parsed.quests.size()==12,"Campaign requires twelve events")
	var ids=[]
	for quest in parsed.quests:
		assert(quest.id not in ids and quest.title.size()==2 and quest.stop.size()==2,"Invalid quest")
		assert(quest.requires=="" or quest.requires in ids,"Invalid quest dependency")
		assert(quest.mode in ["route","switch","rhythm","defense","circuit","memory","herbs"],"Unknown mechanic")
		ids.append(quest.id)
	return parsed
static func points() -> Array:
	return data.quests.map(func(q): return Vector2(q.stop[0],q.stop[1]))
static func summaries() -> Array:
	return data.quests.map(func(q): return q.short)
