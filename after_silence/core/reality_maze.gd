extends RefCounted
## A portal changes the room's topology and remaps its doors. Movement is grid based.
const STOPS={2:"epochs"}
const SIGILS=["◆","●","+"]
const ORDERS={
	"epochs":[0,2,1],
}
const ENTRY=Vector2i(4,5)
const PORTALS=[Vector2i(1,0),Vector2i(4,0),Vector2i(7,0)]
const FLOOR=[
	["#.##.##.#","#.......#","#.##.##.#","#..#.#..#","##.....##","#.......#","#########"],
	["#.##.##.#","#.......#","#.#...#.#","#.##.##.#","#.......#","##.....##","#########"],
	["#.##.##.#","#.......#","###...###","#.......#","#.#.#.#.#","#.......#","#########"],
	["#.##.##.#","#.......#","#..###..#","#.......#","###...###","#.......#","#########"],
	["#.##.##.#","#.......#","#.##.#..#","#..#.#..#","##...#.##","#.......#","#########"],
]

var scene_id: String
var stage=0
var reflected=false
var tile=ENTRY
var order: Array
var scene_number: int
var variant: String
const FIELD_VARIANT = "field_notes"

func _init(id: String, configuration: String = ""):
	scene_id=id
	variant=configuration
	order=[1, 0, 2, 1] if variant == FIELD_VARIANT else ORDERS[id]
	scene_number=1 if variant == FIELD_VARIANT else 2

func walkable(point: Vector2i) -> bool:
	if not Rect2i(0,0,9,7).has_point(point): return false
	var x=8-point.x if reflected else point.x
	return FLOOR[(scene_number+stage+int(reflected))%FLOOR.size()][point.y][x]=="."

func sigil(door: int) -> int:
	var slot=2-door if reflected else door
	return posmod(slot+scene_number+stage,3)

func destination() -> Vector2i:
	for i in range(PORTALS.size()):
		if not won() and sigil(i)==order[stage]: return PORTALS[i]
	return ENTRY

func won() -> bool:
	return stage==order.size()

func move(next: Vector2i) -> String:
	if won() or (next-tile).abs().x+(next-tile).abs().y!=1 or not walkable(next): return ""
	tile=next
	var door=PORTALS.find(next)
	if door<0: return "walk"
	tile=ENTRY
	if sigil(door)==order[stage]:
		stage+=1
		reflected=false
		return "advance"
	reflected=not reflected
	return "reflect"

func route(end: Vector2i) -> Array[Vector2i]:
	if not walkable(end): return []
	var previous={tile:tile}
	var frontier: Array[Vector2i]=[tile]
	var cursor=0
	while cursor<frontier.size() and not previous.has(end):
		var point=frontier[cursor]
		cursor+=1
		for direction in [Vector2i.UP,Vector2i.LEFT,Vector2i.DOWN,Vector2i.RIGHT]:
			var next=point+direction
			if previous.has(next) or not walkable(next): continue
			if next in PORTALS and next!=end: continue
			previous[next]=point
			frontier.append(next)
	if not previous.has(end): return []
	var result: Array[Vector2i]=[]
	while end!=tile:
		result.push_front(end)
		end=previous[end]
	return result

func reset():
	stage=0;reflected=false;tile=ENTRY

func capture() -> Dictionary:
	return {"stage":stage,"reflected":reflected,"tile":[tile.x,tile.y]}

func restore(data: Variant) -> bool:
	if not data is Dictionary or not data.get("reflected") is bool: return false
	var saved_stage=data.get("stage")
	var cell=data.get("tile")
	if not _whole(saved_stage,order.size()) or not cell is Array or cell.size()!=2: return false
	if not _whole(cell[0],9) or not _whole(cell[1],7): return false
	var candidate=get_script().new(scene_id,variant)
	candidate.stage=int(saved_stage);candidate.reflected=data.reflected
	var point=Vector2i(cell[0],cell[1])
	if not candidate.walkable(point) or point in PORTALS or (point!=ENTRY and candidate.route(point).is_empty()): return false
	stage=candidate.stage;reflected=candidate.reflected;tile=point
	return true

static func _whole(number: Variant, limit: int) -> bool:
	return (number is int or number is float) and is_finite(float(number)) and number>=0 and number<limit and number==int(number)
