extends Control

const Water=preload("res://after_silence/world/watercourse.gd")
const Landmarks=preload("res://after_silence/world/district_landmarks.gd")
const LAND=Color("c3c19d")
const PAPER_GRID=Color("7b867029")
const SITE_INK=Color("766046")
const ROAD=Color("e5d1a5")
const FOREST=Color("859674")
const BLUE=Color("557779")
const LOCATION=Color("263f37")
const TARGET=Color("a0563a")

var game
var bounds: Rect2
var scale_factor: float
var target: Dictionary

func _ready():
	name="DistrictMap"
	custom_minimum_size=Vector2(0,183)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	target=game.journey.guide_target() if game.state.flag("event_campaign") else {}
	if not game.state.flag("event_campaign"):
		for spot in game.world.interactables:
			if spot.id=="rift_next":
				target={"point":spot.position,"label":game.t("Огонёк","Light")}
				break
	if not game.comfort.reduce_motion:
		modulate.a=.25
		create_tween().tween_property(self,"modulate:a",1.0,.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func district_name() -> String:
	var zone: String=game.world.zone
	if zone in game.Homes.IDS:
		return game.journey.pair(game.Homes.NAMES[game.Homes.IDS.find(zone)])
	match zone:
		"town": return game.t("Город","Town")
		"forest": return game.t("Лес","Forest")
		"orchard": return game.t("Сад","Orchard")
		"harbor": return game.t("Пристань","Harbor")
		"library": return game.t("Библиотека","Library")
		"shop": return game.t("Лавка","Shop")
	return zone

func _draw():
	var world=game.world
	var available=Rect2(0,0,size.x*.63,size.y)
	draw_rect(available,Color("323d30"))
	scale_factor=minf((available.size.x-20)/world.dimensions.x,(available.size.y-16)/world.dimensions.y)
	bounds=Rect2(available.get_center()-world.dimensions*scale_factor*.5,world.dimensions*scale_factor)
	draw_rect(bounds,LAND)
	_draw_terrain(world)
	_draw_sites(world.zone)
	for prop in world.sorter.get_children():
		if not prop.has_meta("building"): continue
		var p=project_point(prop.position)
		draw_rect(Rect2(p-Vector2(4,4),Vector2(8,5)),Color("595747"))
		draw_colored_polygon(PackedVector2Array([p+Vector2(-5,-4),p+Vector2(0,-8),p+Vector2(5,-4)]),Color("885f4b"))
	draw_rect(bounds.grow(.5),Color("d7caab"),false,1)
	var font=get_theme_default_font()
	var north=Vector2(14,18)
	draw_string(font,north-Vector2(5,3),game.t("С","N"),HORIZONTAL_ALIGNMENT_CENTER,10,10,game.ComfortTheme.TEXT)
	draw_colored_polygon(PackedVector2Array([north,north+Vector2(-4,12),north+Vector2(0,9),north+Vector2(4,12)]),game.ComfortTheme.PEACH)
	if not target.is_empty():
		_goal_marker(project_point(target.point))
	_pin(project_point(game.player.position),LOCATION,4)
	var side=Vector2(available.end.x+16,23)
	_pin(side,LOCATION,4)
	draw_string(font,side+Vector2(13,4),game.t("Вера","Vera"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,game.ComfortTheme.TEXT)
	if not target.is_empty():
		side.y+=33
		_goal_marker(side)
		draw_string(font,side+Vector2(13,4),game.t("Текущая цель","Current goal"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,game.ComfortTheme.PEACH)
		draw_string(font,side+Vector2(13,21),target.label,HORIZONTAL_ALIGNMENT_LEFT,maxf(1,size.x-side.x-13),11,game.ComfortTheme.MUTED)
	side.y+=31 if target.is_empty() else 47
	for id in Landmarks.for_zone(world.zone):
		_site_pin(side,game.state.flag("landmark_"+id))
		var label=game.journey.pair(Landmarks.SITES[id].name)
		draw_string(font,side+Vector2(13,4),label,HORIZONTAL_ALIGNMENT_LEFT,maxf(1,size.x-side.x-13),11,game.ComfortTheme.TEXT)
		side.y+=23

func _draw_terrain(world):
	if world.paths.is_empty():
		for obstacle in world.obstacles:
			draw_rect(Rect2(project_point(obstacle.position),obstacle.size*scale_factor),Color("9a846b"))
		return
	for x in range(24,int(bounds.size.x),24):
		var edge=bounds.position+Vector2(x,0)
		draw_line(edge,edge+Vector2(0,bounds.size.y),PAPER_GRID,1)
	for y in range(24,int(bounds.size.y),24):
		var edge=bounds.position+Vector2(0,y)
		draw_line(edge,edge+Vector2(bounds.size.x,0),PAPER_GRID,1)
	for prop in world.sorter.get_children():
		if not prop.get("kind") in ["tree","flowers"]: continue
		var p=project_point(prop.position)
		if bounds.grow(-3).has_point(p):
			draw_circle(p,2 if prop.kind=="tree" else 1,FOREST)
	for path in world.paths:
		draw_line(project_point(path[0]),project_point(path[1]),ROAD,maxf(2,path[2]*scale_factor*2))
	for feature in Landmarks.FEATURES.get(world.zone,[]):
		var area: Rect2=feature[1]
		draw_rect(Rect2(project_point(area.position),area.size*scale_factor),Color("a89772"))
	if world.zone not in ["town","harbor"]: return
	var limit=Vector2i(world.dimensions)
	for y in range(0,limit.y,12):
		var start=-1
		for x in range(0,limit.x+12,12):
			var wet=x<limit.x and Water.depth(world.zone,Vector2(x+6,y+6))>0
			if wet and start<0: start=x
			elif not wet and start>=0:
				var area=Vector2(mini(x,limit.x)-start,mini(12,limit.y-y))
				draw_rect(Rect2(project_point(Vector2(start,y)),area*scale_factor),BLUE)
				start=-1
	if world.zone=="town":
		for x in [600,1450]:
			var p=Vector2(x,Water.river_y(x))
			draw_line(project_point(p-Vector2(0,37)),project_point(p+Vector2(0,37)),ROAD,3)
	if world.zone=="harbor":
		var dock=Rect2(project_point(Water.PIER.position),Water.PIER.size*scale_factor)
		draw_rect(dock,Color("a98058"))
		draw_rect(dock,Color("684d39"),false,1)

func _draw_sites(zone: String):
	for id in Landmarks.for_zone(zone):
		_site_pin(project_point(Landmarks.SITES[id].point),game.state.flag("landmark_"+id))

func _site_pin(at: Vector2,inspected: bool):
	var mark=Rect2(at.round()-Vector2(4,4),Vector2(8,8))
	draw_rect(mark,Color("ebd5a4"))
	draw_rect(mark.grow(-1),Color("7d8b59") if inspected else SITE_INK)
	draw_rect(Rect2(mark.position+Vector2(3,3),Vector2(2,2)),Color("f9dfad"))

func project_point(point: Vector2) -> Vector2:
	return bounds.position+point*scale_factor

func _goal_marker(point: Vector2):
	var diamond=PackedVector2Array([point-Vector2(0,7),point+Vector2(7,0),point+Vector2(0,7),point-Vector2(7,0)])
	draw_colored_polygon(diamond,TARGET)
	diamond.append(diamond[0])
	draw_polyline(diamond,Color("f4e6c6"),1,true)

func _pin(point: Vector2,color: Color,radius: float):
	draw_circle(point,radius+1,Color("f4e6c6"),true,-1,true)
	draw_circle(point,radius,color,true,-1,true)
