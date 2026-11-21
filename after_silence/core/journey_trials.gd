extends RefCounted

const STOPS={0:"letter_press",1:"footprints",4:"balance",7:"signal_grid",8:"railway",10:"echo_tuning"}
const GUEST_TRACES=[
	[[0,0],[1,1],[2,0],[0,1],[1,0],[2,1]],
	[[2,1],[0,0],[1,0],[2,0],[0,1],[1,1]],
	[[1,0],[2,1],[0,1],[0,0],[1,1],[2,0]],
]
const GUEST_CLUES=[[1,0],[2,1],[0,1]]
const LOADS=[1,2,3,4,6]
const BALANCED=[1,2,1,1,2]
const SIGNAL=[4,14,31,14,4]
const STATIONS=[2,0,3]
const ECHOES=[[1,3],[4,1],[2,0]]
const ACTIONS={"letter_press":4,"footprints":6,"balance":5,"signal_grid":25,"railway":4,"echo_tuning":5}
const MOVE_LIMIT=200
const FIELD_VARIANT = "field_notes"
const FIELD_TRACES = [[1,0],[2,1],[0,1],[2,0]]

var kind: String
var variant: String
var loads: Array=LOADS
var balance_plan: Array=BALANCED
var signal_rows: Array=SIGNAL
var stations: Array = STATIONS
var echoes: Array = ECHOES
var trace_clues: Array = GUEST_CLUES
var trace_rows: Array = GUEST_TRACES
var history: Array[int]=[]
var state: Array
var round_index=0

func _init(mode: String, configuration: String=""):
	kind=mode
	variant=configuration
	if kind=="balance" and variant=="weights":
		loads=[2,3,4,7,8]
		balance_plan=[2,2,1,2,1]
	if kind=="signal_grid" and variant=="lamps":
		signal_rows=[17,10,4,10,17]
	if kind=="signal_grid" and variant=="quiet_plaza":
		signal_rows=[14,17,17,17,14]
	if variant == FIELD_VARIANT:
		loads = [4, 3, 5, 7, 9]
		balance_plan = [1, 1, 2, 1, 2]
		signal_rows = [31, 17, 21, 10, 4]
		stations = [1, 3, 0, 2]
		echoes = [[3, 0], [1, 3], [4, 2], [2, 4]]
		trace_clues = FIELD_TRACES
		trace_rows = GUEST_TRACES + [GUEST_TRACES[0].duplicate()]
	reset()

func reset():
	history.clear()
	round_index=0
	match kind:
		"letter_press": state=[3,2,1,2] if variant==FIELD_VARIANT else [1,3,2,1]
		"footprints": state=[]
		"balance","signal_grid": state=[0,0,0,0,0]
		"railway": state=[0,0,0]
		"echo_tuning": state=[2,2]

func perform(action: int) -> bool:
	if action<0 or action>=ACTIONS[kind] or won() or history.size()>=MOVE_LIMIT: return false
	match kind:
		"letter_press": state[action]=(state[action]+1)%4
		"footprints":
			if trace_rows[round_index][action]!=trace_clues[round_index]: return false
			round_index+=1
		"balance": state[action]=(state[action]+1)%3
		"signal_grid":
			var row=floori(action/5.0)
			state[row]^=1<<(action%5)
		"railway":
			if action==3:
				if station()!=stations[round_index]: return false
				round_index+=1
			else: state[action]=1-state[action]
		"echo_tuning":
			if action==4:
				if state!=echoes[round_index]: return false
				round_index+=1
			else:
				var axis=floori(action/2.0)
				var next=state[axis]+(1 if action%2 else -1)
				if next<0 or next>4: return false
				state[axis]=next
	history.append(action)
	return true

func station() -> int:
	return state[0]*2+state[state[0]+1]

func weight(side: int) -> int:
	var total=0
	for i in range(loads.size()):
		if state[i]==side: total+=loads[i]
	return total

static func runs(bits: int) -> Array[int]:
	var result: Array[int]=[]
	var length=0
	for i in range(6):
		if bits&(1<<i): length+=1
		elif length>0: result.append(length);length=0
	return result

static func column(rows: Array, x: int) -> int:
	var result=0
	for y in range(5):
		if rows[y]&(1<<x): result|=1<<y
	return result

func goal() -> int:
	return {"letter_press":4,"footprints":trace_clues.size(),"balance":6,"signal_grid":10,"railway":stations.size(),"echo_tuning":echoes.size()}[kind]

func progress() -> int:
	match kind:
		"letter_press": return state.count(0)
		"balance":
			var loaded=5-state.count(0)
			return 6 if loaded==5 and weight(1)==weight(2) else loaded
		"signal_grid":
			var correct=0
			for i in range(5):
				if runs(state[i])==runs(signal_rows[i]): correct+=1
				if runs(column(state,i))==runs(column(signal_rows,i)): correct+=1
			return correct
		_: return round_index

func won() -> bool:
	return progress()==goal()

func hint() -> int:
	if won() or history.size()>=MOVE_LIMIT: return -1
	match kind:
		"letter_press":
			for i in range(state.size()):
				if state[i]!=0: return i
		"footprints": return trace_rows[round_index].find(trace_clues[round_index])
		"balance":
			for i in range(state.size()):
				if state[i]!=balance_plan[i]: return i
		"signal_grid":
			for y in range(5):
				for x in range(5):
					if (state[y]^signal_rows[y])&(1<<x): return y*5+x
		"railway":
			var target: int=stations[round_index]
			var lane=floori(target/2.0)
			if state[0]!=lane: return 0
			if state[lane+1]!=target%2: return lane+1
			return 3
		"echo_tuning":
			var pattern: Array=echoes[round_index]
			for i in range(2):
				if state[i]!=pattern[i]: return i*2+int(state[i]<pattern[i])
			return 4
	return -1

func capture() -> Array:
	return history.duplicate()

func restore(raw: Variant) -> bool:
	if not raw is Array or raw.size()>MOVE_LIMIT: return false
	var trial=get_script().new(kind,variant)
	for action in raw:
		if not (action is int or action is float) or not is_finite(float(action)) or action<0 or action>=ACTIONS[kind] or int(action)!=action: return false
		if not trial.perform(int(action)): return false
	if trial.won(): return false
	history=trial.history;state=trial.state;round_index=trial.round_index
	return true

func undo():
	if history.is_empty(): return
	var kept=history.slice(0,-1)
	reset()
	for action in kept: perform(action)
