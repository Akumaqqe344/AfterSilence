extends RefCounted
## Deterministic boards. Checkpoints store accepted moves and rebuild the board.
const EVENTS={"machine":"tubes","memory":"pairs","garden":"seeds","collision":"lights","shore":"shelves"}
const LEGACY={"machine":"repair","memory":"rhythm","garden":"escort","collision":"route","shore":"evacuation"}
const SIZES={"tubes":5,"pairs":12,"seeds":9,"lights":12,"shelves":12}
const CAPACITY=3
const MOVE_LIMIT=80
const PAIRS=[0,1,2,3,4,5,3,0,5,2,1,4]
const SHELVES=[0,1,2,3,2,0,3,1,3,2,1,0]
const SEEDS=[0,1,2,1,0,2]
const LIGHTS=[
	[0,1,0,2,2,0,1,2,1,2,1,0],
	[0,2,0,2,2,1,2,0,1,2,1,0],
	[0,2,1,2,2,1,0,1,2,1,2,0],
]
const TUBES=[[0,1,2],[1,2,0],[2,0,1],[],[]]

var mode: String
var board: Array
var history: Array=[]
var round_index=0

func _init(kind: String) -> void:
	mode=kind
	reset()

func reset() -> void:
	history.clear()
	round_index=0
	match mode:
		"tubes": board=TUBES.duplicate(true)
		"pairs": board=PAIRS.duplicate()
		"shelves": board=SHELVES.duplicate()
		"seeds": board=[0,1,2,-1,-1,-1,-1,-1,-1]
		"lights": board=LIGHTS[0].duplicate()

func color_at(i: int) -> int:
	if mode=="tubes": return -1 if board[i].is_empty() else board[i].back()
	return board[i]%3 if mode=="seeds" and i>=3 and board[i]>=0 else board[i]

func can_start(i: int) -> bool:
	return mode=="seeds" or color_at(i)>=0

func steps(selection: Array) -> int:
	if mode=="seeds": return 1 if selection.is_empty() else 2
	return 3 if mode=="shelves" else 2

func submit(move: Array) -> bool:
	if history.size()>=MOVE_LIMIT or won() or not _apply(move): return false
	history.append(move.duplicate())
	return true

func _apply(move: Array) -> bool:
	match mode:
		"tubes":
			if move.size()!=2 or not _can_pour(board,move[0],move[1]): return false
			board[move[1]].append(board[move[0]].pop_back())
		"pairs","shelves":
			if move.size()!=steps([]) or color_at(move[0])<0: return false
			for i in move:
				if move.count(i)!=1 or color_at(i)!=color_at(move[0]): return false
			for i in move: board[i]=-1
		"seeds":
			var plot: int=move.back()
			if plot<3: return false
			if move.size()==1 and board[plot] in [0,1,2]: board[plot]+=3
			elif move.size()==2 and board[plot]==-1 and move[0]==SEEDS[plot-3]: board[plot]=move[0]
			else: return false
		"lights":
			if move.size()!=2 or not _lights_match(move[0],move[1]): return false
			round_index+=1
			if round_index<LIGHTS.size(): board=LIGHTS[round_index].duplicate()
		_: return false
	return true

func _lights_match(a: int,b: int) -> bool:
	if absi(a%4-b%4)+absi(int(a/4)-int(b/4))!=1 or board[a]==board[b]: return false
	var swapped=board.duplicate()
	swapped[a]=board[b]
	swapped[b]=board[a]
	for i in [a,b]:
		var start=int(i/4)*4
		for x in [start,start+1]:
			if i in [x,x+1,x+2] and swapped[x]==swapped[x+1] and swapped[x]==swapped[x+2]: return true
		var col=i%4
		if swapped[col]==swapped[col+4] and swapped[col]==swapped[col+8]: return true
	return false

func goal() -> int:
	return {"tubes":3,"pairs":6,"seeds":12,"lights":3,"shelves":4}[mode]

func progress() -> int:
	match mode:
		"tubes": return _sorted_tubes(board)
		"lights": return round_index
		_: return history.size()

func won() -> bool:
	return progress()==goal()

func undo() -> void:
	if history.is_empty(): return
	var moves=history.slice(0,history.size()-1)
	reset()
	for move in moves: submit(move)

func checkpoint() -> Array:
	return history.duplicate(true)

func restore(raw: Variant) -> bool:
	if not raw is Array or raw.size()>MOVE_LIMIT: return false
	var candidate=get_script().new(mode)
	for move in raw:
		if not move is Array or move.is_empty() or move.size()>3: return false
		var indices: Array=[]
		for n in move:
			if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>=SIZES[mode] or n!=int(n): return false
			indices.append(int(n))
		if not candidate.submit(indices): return false
	if candidate.won(): return false
	board=candidate.board
	history=candidate.history
	round_index=candidate.round_index
	return true

func hint() -> Array:
	if won() or history.size()>=MOVE_LIMIT: return []
	match mode:
		"tubes": return _tube_hint()
		"seeds":
			for i in range(3,board.size()):
				if board[i]==-1: return [SEEDS[i-3],i]
				if board[i]<3: return [i]
		"lights":
			for a in range(board.size()):
				for b in range(a+1,board.size()):
					if _lights_match(a,b): return [a,b]
		"pairs","shelves":
			for a in range(board.size()):
				if board[a]<0: continue
				var group=[a]
				for b in range(a+1,board.size()):
					if board[b]==board[a]: group.append(b)
				if group.size()==steps([]): return group
	return []

static func _can_pour(stacks: Array,a: int,b: int) -> bool:
	if a==b or stacks[a].is_empty() or stacks[b].size()==CAPACITY: return false
	return stacks[b].is_empty() or stacks[a].back()==stacks[b].back()

static func _sorted_tubes(stacks: Array) -> int:
	var count=0
	for stack in stacks:
		if stack.size()==CAPACITY and stack[0]==stack[1] and stack[1]==stack[2]: count+=1
	return count

func _tube_hint() -> Array:
	var states=[board]
	var first_moves=[[]]
	var seen={str(board):true}
	var cursor=0
	while cursor<states.size() and cursor<6000:
		var stacks=states[cursor]
		var first=first_moves[cursor]
		cursor+=1
		for a in range(stacks.size()):
			for b in range(stacks.size()):
				if not _can_pour(stacks,a,b): continue
				var next=stacks.duplicate(true)
				next[b].append(next[a].pop_back())
				var key=str(next)
				if seen.has(key): continue
				seen[key]=true
				var initial=first if not first.is_empty() else [a,b]
				if _sorted_tubes(next)==3: return initial
				states.append(next)
				first_moves.append(initial)
	return []
