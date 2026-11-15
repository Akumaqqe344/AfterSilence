extends RefCounted
# Engine-independent deterministic rules. Scene movement is acknowledged by the
# encounter controller only after the existing Actor reaches its destination.
const CATALOG_PATH="res://after_silence/data/tactical_encounters.json"
const DIRECTIONS=[Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]
var cells: Dictionary={}
var edges: Dictionary={}
var units: Dictionary={}
var order: Array=[]
var turn=0
var round_number=1
var phase="setup"
var pending: Dictionary={}
var log: Array=[]
func key(p: Vector2i) -> String: return "%d:%d"%[p.x,p.y]
func point(value: Array) -> Vector2i: return Vector2i(int(value[0]),int(value[1]))
func location(id: String) -> Vector2i: return point(units[id].cell)
func active_id() -> String: return str(order[turn]) if not order.is_empty() and turn<order.size() else ""
func occupied(p: Vector2i,except_id: String="") -> bool:
	for id in units:
		if id!=except_id and location(id)==p: return true
	return false
func connected(a: Vector2i,b: Vector2i) -> bool:
	return cells.has(key(b)) and edges.get(key(a)+">"+key(b),false)
func configure(tiles: Array,links: Array,roster: Array) -> bool:
	cells.clear();edges.clear();units.clear();order.clear();pending={};log=[]
	var classes=JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH)).classes
	for p in tiles: cells[key(point(p))]=true
	for edge in links: edges[key(point(edge[0]))+">"+key(point(edge[1]))]=true
	for row in roster:
		if units.has(row.id) or not classes.has(row.role) or not cells.has(key(point(row.cell))) or occupied(point(row.cell)): return false
		var stats=classes[row.role]
		units[row.id]={"id":row.id,"side":row.side,"role":row.role,"cell":row.cell.duplicate(),"hp":int(stats.hp),"max_hp":int(stats.hp),"ap":int(stats.ap),"max_ap":int(stats.ap),"initiative":int(stats.initiative),"damage":int(stats.damage),"range":int(stats.range),"heal":int(stats.heal),"guard":0}
		order.append(row.id)
	order.sort_custom(func(a,b):return units[a].initiative>units[b].initiative if units[a].initiative!=units[b].initiative else str(a)<str(b))
	if not units.has("vera") or units.size()<3: return false
	turn=0;round_number=1;phase="active"
	return true
func route(id: String,target: Vector2i,limit: int=100) -> Array:
	if not units.has(id) or not cells.has(key(target)) or occupied(target,id): return []
	var start=location(id)
	var queue=[start]
	var previous={key(start):start}
	var distance={key(start):0}
	var found=false
	while not queue.is_empty():
		var p: Vector2i=queue.pop_front()
		if p==target: found=true;break
		if distance[key(p)]>=limit: continue
		for direction in DIRECTIONS:
			var next: Vector2i=p+direction
			if not connected(p,next) or previous.has(key(next)) or occupied(next,id): continue
			previous[key(next)]=p;distance[key(next)]=distance[key(p)]+1;queue.append(next)
	if not found: return []
	var result=[target]
	var cursor=target
	while cursor!=start:
		cursor=previous[key(cursor)];result.push_front(cursor)
	return result
func distance(a: Vector2i,b: Vector2i) -> int: return absi(a.x-b.x)+absi(a.y-b.y)
func sees(a: Vector2i,b: Vector2i) -> bool:
	var steps=maxi(1,maxi(absi(a.x-b.x),absi(a.y-b.y))*8)
	var previous=a
	for i in range(1,steps+1):
		var q=Vector2(a).lerp(Vector2(b),float(i)/steps)
		var current=Vector2i(roundi(q.x),roundi(q.y))
		if not cells.has(key(current)): return false
		if current!=previous:
			if current.x!=previous.x and current.y!=previous.y:
				var mid_x=Vector2i(current.x,previous.y)
				var mid_y=Vector2i(previous.x,current.y)
				if not (connected(previous,mid_x) and connected(mid_x,current) and connected(previous,mid_y) and connected(mid_y,current)): return false
			elif not connected(previous,current): return false
		previous=current
	return true
func can_target(id: String,target: String,kind: String) -> bool:
	if not units.has(id) or not units.has(target) or id==target: return false
	var a=units[id];var b=units[target]
	if kind=="attack":
		return a.ap>=2 and b.hp>0 and a.side!=b.side and distance(location(id),location(target))<=a.range and sees(location(id),location(target))
	return a.ap>=2 and a.heal>0 and a.side==b.side and b.hp<b.max_hp and distance(location(id),location(target))<=1 and sees(location(id),location(target))
func command(id: String,kind: String,target=null) -> Dictionary:
	if phase!="active" or id!=active_id() or not units.has(id) or units[id].hp<=0: return {"ok":false,"reason":"Сейчас ход другого участника."}
	var unit=units[id]
	match kind:
		"move":
			if not target is Vector2i: return {"ok":false,"reason":"Выбери клетку."}
			var path=route(id,target,unit.ap)
			if path.size()<2: return {"ok":false,"reason":"Клетка занята, закрыта или не хватает действий."}
			var cost=path.size()-1
			var points=[]
			for p in path: points.append([p.x,p.y])
			pending={"id":id,"from":unit.cell.duplicate(),"to":[target.x,target.y],"cost":cost,"path":points}
			unit.ap-=cost;unit.cell=[target.x,target.y];phase="moving"
		"attack","help":
			if not target is String or not can_target(id,target,kind): return {"ok":false,"reason":"Цель недоступна: проверь дальность, обзор и очки действий."}
			unit.ap-=2
			if kind=="attack":
				var other=units[target]
				var damage=maxi(0,unit.damage-other.guard)
				other.guard=0;other.hp=maxi(0,other.hp-damage)
				log.append({"actor":id,"action":kind,"target":target,"amount":damage,"round":round_number})
			else:
				var amount=mini(unit.heal,units[target].max_hp-units[target].hp)
				units[target].hp+=amount
				log.append({"actor":id,"action":kind,"target":target,"amount":amount,"round":round_number})
			outcome()
		"defend":
			if unit.ap<1: return {"ok":false,"reason":"Не хватает действий."}
			unit.ap-=1;unit.guard=1
			log.append({"actor":id,"action":kind,"round":round_number})
		"end":
			next_turn()
		"retreat":
			phase="retreated";log.append({"actor":id,"action":kind,"round":round_number})
		_: return {"ok":false,"reason":"Неизвестное действие."}
	return {"ok":true,"phase":phase}
func finish_move():
	if phase!="moving" or pending.is_empty(): return
	log.append({"actor":pending.id,"action":"move","from":pending.from,"to":pending.to,"round":round_number})
	pending={};phase="active";outcome()
func outcome():
	if units.vera.hp<=0: phase="defeat";return
	var enemies=0
	for unit in units.values():
		if unit.side=="enemy" and unit.hp>0: enemies+=1
	if enemies==0: phase="victory"
func next_turn():
	if phase!="active": return
	for attempt in range(order.size()):
		turn+=1
		if turn>=order.size(): turn=0;round_number+=1
		if units[active_id()].hp>0:
			units[active_id()].ap=units[active_id()].max_ap
			units[active_id()].guard=0
			break
	if round_number>80: phase="defeat"
func plan(id: String,kind: String) -> Dictionary:
	if phase!="active" or active_id()!=id: return {}
	if kind=="help":
		var wounded=[]
		for other in order:
			if can_target(id,other,"help"): wounded.append(other)
		wounded.sort_custom(func(a,b):return units[a].hp<units[b].hp if units[a].hp!=units[b].hp else str(a)<str(b))
		if not wounded.is_empty(): return {"kind":"help","target":wounded[0]}
	elif kind=="attack":
		var enemies=[]
		for other in order:
			if can_target(id,other,"attack"): enemies.append(other)
		enemies.sort_custom(func(a,b):return units[a].hp<units[b].hp if units[a].hp!=units[b].hp else str(a)<str(b))
		if not enemies.is_empty(): return {"kind":"attack","target":enemies[0]}
	elif kind=="move" and units[id].ap>0:
		var best=[]
		var target_id=""
		for other in order:
			if units[other].side==units[id].side or units[other].hp<=0: continue
			for direction in DIRECTIONS:
				var candidate=location(other)+direction
				var path=route(id,candidate)
				if path.size()>1 and (best.is_empty() or path.size()<best.size()):
					best=path;target_id=other
		if not best.is_empty():
			# Stay in range once a ranged class already has sight. Repositioning
			# is used only when there is no legal attack or enough AP to attack.
			if units[id].ap<2 and distance(location(id),location(target_id))<=units[id].range: return {}
			var steps=mini(units[id].ap,best.size()-1)
			var p: Vector2i=best[steps]
			return {"kind":"move","target":p}
	elif kind=="defend" and units[id].ap>0 and units[id].guard==0: return {"kind":"defend"}
	elif kind=="end": return {"kind":"end"}
	return {}
func capture() -> Dictionary:
	var tiles=[]
	for k in cells:
		var xy=k.split(":");tiles.append([int(xy[0]),int(xy[1])])
	var links=[]
	for k in edges:
		var pair=k.split(">");var a=pair[0].split(":");var b=pair[1].split(":")
		links.append([[int(a[0]),int(a[1])],[int(b[0]),int(b[1])]])
	return {"version":1,"tiles":tiles,"links":links,"units":units.duplicate(true),"order":order.duplicate(),"turn":turn,"round":round_number,"phase":phase,"pending":pending.duplicate(true),"log":log.slice(-200).duplicate(true)}
static func integer(value,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==int(value) and value>=low and value<=high
static func valid_pair(value) -> bool:
	return value is Array and value.size()==2 and integer(value[0],0,30) and integer(value[1],0,30)
static func valid(data: Dictionary) -> bool:
	if data.get("version")!=1 or data.get("phase") not in ["setup","active","moving","victory","defeat","retreated"]: return false
	if not integer(data.get("turn"),0,7) or not integer(data.get("round"),1,81): return false
	if not data.get("tiles") is Array or data.tiles.size()<3 or data.tiles.size()>300: return false
	var known={}
	for pair in data.tiles:
		if not valid_pair(pair) or known.has(str(pair)): return false
		known[str(pair)]=true
	if not data.get("links") is Array or data.links.size()>1200: return false
	for edge in data.links:
		if not edge is Array or edge.size()!=2 or not valid_pair(edge[0]) or not valid_pair(edge[1]): return false
		if not known.has(str(edge[0])) or not known.has(str(edge[1])) or absi(int(edge[0][0])-int(edge[1][0]))+absi(int(edge[0][1])-int(edge[1][1]))!=1: return false
	if not data.get("units") is Dictionary or data.units.size()<3 or data.units.size()>8 or not data.units.has("vera"): return false
	var classes=JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH)).classes
	var occupied_cells={}
	for id in data.units:
		var u=data.units[id]
		if id not in ["vera","nadia","lev","mara","pavel","sonya","child","alina","guest"] or not u is Dictionary or not classes.has(u.get("role","")) or u.get("id")!=id: return false
		if u.get("side") not in ["party","enemy"] or not valid_pair(u.get("cell")) or not known.has(str(u.cell)) or occupied_cells.has(str(u.cell)): return false
		occupied_cells[str(u.cell)]=true
		var stats=classes[u.role]
		for field in ["hp","max_hp","ap","max_ap","initiative","damage","range","heal","guard"]:
			if not integer(u.get(field),0,20): return false
		if u.max_hp!=stats.hp or u.max_ap!=stats.ap or u.hp>u.max_hp or u.ap>u.max_ap or u.guard>1: return false
		for field in ["initiative","damage","range","heal"]:
			if u[field]!=stats[field]: return false
	if not data.get("order") is Array or data.order.size()!=data.units.size() or data.turn>=data.order.size(): return false
	var seen={}
	for id in data.order:
		if not data.units.has(id) or seen.has(id): return false
		seen[id]=true
	if not data.get("pending") is Dictionary or not data.get("log") is Array or data.log.size()>200: return false
	for row in data.log:
		if not row is Dictionary or not data.units.has(row.get("actor","")) or row.get("action","") not in ["move","attack","help","defend","retreat"] or not integer(row.get("round"),1,81): return false
		if row.action in ["attack","help"]:
			if not data.units.has(row.get("target","")) or not integer(row.get("amount"),0,20): return false
		if row.action=="move" and (not valid_pair(row.get("from")) or not valid_pair(row.get("to"))): return false
	if data.units.vera.side!="party": return false
	var living_enemies=0
	for u in data.units.values():
		if u.side=="enemy" and u.hp>0: living_enemies+=1
	if data.phase=="victory" and (living_enemies>0 or data.units.vera.hp<=0): return false
	if data.phase=="defeat" and data.units.vera.hp>0 and data.round<=80: return false
	if data.phase=="moving":
		var p=data.pending
		if p.get("id")!=data.order[data.turn] or not valid_pair(p.get("from")) or not valid_pair(p.get("to")) or not integer(p.get("cost"),1,3): return false
		if not known.has(str(p.from)) or p.to!=data.units[p.id].cell: return false
		if not p.get("path") is Array or p.path.size()!=p.cost+1 or p.path[0]!=p.from or p.path.back()!=p.to: return false
		for i in range(p.path.size()):
			if not valid_pair(p.path[i]) or not known.has(str(p.path[i])): return false
			if i>0:
				var a=p.path[i-1];var b=p.path[i]
				if absi(int(a[0])-int(b[0]))+absi(int(a[1])-int(b[1]))!=1: return false
				if [a,b] not in data.links: return false
	elif not data.pending.is_empty(): return false
	return true
func restore(data: Dictionary) -> bool:
	if not valid(data): return false
	cells={};edges={}
	for p in data.tiles: cells[key(point(p))]=true
	for edge in data.links: edges[key(point(edge[0]))+">"+key(point(edge[1]))]=true
	units=data.units.duplicate(true);order=data.order.duplicate();turn=int(data.turn);round_number=int(data.round)
	phase=data.phase;pending=data.pending.duplicate(true);log=data.log.duplicate(true)
	for unit in units.values():
		unit.cell=[int(unit.cell[0]),int(unit.cell[1])]
		for field in ["hp","max_hp","ap","max_ap","initiative","damage","range","heal","guard"]: unit[field]=int(unit[field])
	if not pending.is_empty():
		pending.from=[int(pending.from[0]),int(pending.from[1])]
		pending.to=[int(pending.to[0]),int(pending.to[1])]
		pending.cost=int(pending.cost)
		for i in range(pending.path.size()): pending.path[i]=[int(pending.path[i][0]),int(pending.path[i][1])]
	for row in log:
		for field in ["round","amount"]:
			if row.has(field): row[field]=int(row[field])
		for field in ["from","to"]:
			if row.has(field): row[field]=[int(row[field][0]),int(row[field][1])]
	return true
