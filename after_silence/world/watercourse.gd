extends RefCounted
# Shared world-space water geometry for visuals, props and collision.
const PIER=Rect2(980,724,156,56)
static func river_y(x: float) -> float:
	return 1028.0+sin((x-600.0)*.0055)*30.0+sin((x-600.0)*.014)*9.0
static func bridge_at(p: Vector2) -> bool:
	return (absf(p.x-600)<27 or absf(p.x-1450)<27) and absf(p.y-river_y(p.x))<54
static func depth(zone: String,p: Vector2) -> float:
	if zone=="town":
		var river=28.0-absf(p.y-river_y(p.x))
		var d=(p-Vector2(1080,150))/Vector2(100,64)
		var pond=(1.0-d.length())*60.0+sin(p.x*.05)*2.5+sin(p.y*.07)*2.0
		return maxf(river,pond)
	if zone=="harbor":
		# A rounded cove continues beyond the eastern and southern map edges.
		return (1.0-((p-Vector2(1280,1000))/Vector2(330,430)).length())*260.0+sin(p.y*.025)*4.0
	return -10000.0
static func blocked(zone: String,p: Vector2) -> bool:
	return depth(zone,p)>0 and not crossing_at(zone,p)

static func crossing_at(zone: String,p: Vector2) -> bool:
	return (zone=="town" and bridge_at(p)) or (zone=="harbor" and PIER.has_point(p))
