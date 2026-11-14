extends RefCounted
const BASE="res://after_silence/assets/art100/"
static var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"catalog.json"))
static var cache: Dictionary={}
const ALIASES={"library":"house-1","stone":"rock","catalog":"book","schematic":"plan","note":"letter","signpost":"poster","personal_album":"photo","personal_drawing":"plan","personal_letter":"letter","personal_log":"book","personal_medal":"medal","personal_tools":"tools","personal_plan":"plan","personal_medicine":"medicine"}
static func key(kind: String, variant: int) -> String:
	if kind=="house": return "house-"+str(posmod(variant,4))
	if kind=="tree": return "tree-"+str(posmod(variant,3))
	return ALIASES.get(kind,kind)
static func apply(node, kind: String, variant: int) -> bool:
	if kind in ["shop_front","well","gazebo","village_board"]:
		node.tex=load("res://after_silence/assets/art120/"+kind+".png")
		node.size=node.tex.get_size()*2
		return true
	var id=key(kind,variant)
	if not data.props.has(id): return false
	var entry=data.props[id]
	if not cache.has(id): cache[id]=load(BASE+entry.file)
	node.tex=cache[id]
	node.size=Vector2(entry.size[0],entry.size[1])
	if kind=="flowers": node.size=Vector2(28,20)
	return true
