extends Control

const DARK=Color("202e25eb")
const TRACE=Color("ead196")
const GHOST=Color("34303e")
const INTERVAL=.20
const SPACING=43.0
var game
var target: Dictionary={}
var route=PackedVector2Array()
var sample_age=0.0
var travel_age=0.0
var last_zone=""
var remaining=0.0
var sampled_start=Vector2.INF
var sampled_target=Vector2.INF
var sampled_revision=-1
var sampled_id=""
var toggle: Button
var tile_skin: StyleBox

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	toggle=Button.new()
	toggle.position=Vector2(10,326);toggle.size=Vector2(37,22)
	toggle.add_theme_font_size_override("font_size",11)
	toggle.focus_mode=Control.FOCUS_NONE
	toggle.pressed.connect(game._toggle_route_guide)
	add_child(toggle)
	tile_skin=game.PixelArt.panel("hud",5)
	game.ComfortMotion.wire_button(toggle,game.comfort)

func _process(dt):
	var available=game.state.flag("event_campaign") and not game.in_menu and not game.modal and not game.event_window.active and not game.transitions.busy and not game.cutscenes.running and not game.adventure.expanded and is_instance_valid(game.player)
	visible=available and game.events_controller.index<game.events_controller.events.size()
	if not visible:
		sample_age=0
		return
	toggle.tooltip_text=game.t("Скрыть маршрут · G","Hide route · G") if game.comfort.route_guide else game.t("Показать маршрут · G","Show route · G")
	toggle.text="→ G" if game.comfort.route_guide else "G"
	if not game.comfort.route_guide:
		route.clear();target.clear();sample_age=0;sampled_revision=-1;queue_redraw();return
	sample_age-=dt
	if game.state.zone!=last_zone or sample_age<=0:
		last_zone=game.state.zone
		sample_age=INTERVAL
		refresh(false)
	if not game.comfort.reduce_motion: travel_age=fmod(travel_age+dt,3.0)
	queue_redraw()

func refresh(force: bool=true):
	target=game.journey.guide_target()
	if target.is_empty():
		route.clear();remaining=0;sampled_revision=-1
		return
	var start: Vector2=game.player.position
	var end: Vector2=target.point
	var revision: int=game.world.geometry_revision
	if not force and sampled_revision==revision and sampled_id==target.id and sampled_start.distance_squared_to(start)<144.0 and sampled_target.distance_squared_to(end)<64.0:
		return
	sampled_revision=revision
	sampled_id=target.id
	sampled_start=start
	sampled_target=end
	route.clear();remaining=0
	var navigation=game.npcs.navigation
	var geometry=game.npcs.nav(game.state.zone)
	var best=PackedVector2Array()
	var best_length=INF
	# Test near the real hotspot, so the final marker stays inside its use range.
	var candidates=[end]
	for radius in [12.0,23.0]:
		for i in range(8): candidates.append(end+Vector2.from_angle(i*TAU/8)*radius)
	for point in candidates:
		if not navigation.clear_segment(geometry,point,point): continue
		var path: PackedVector2Array=navigation.path(geometry,start,point)
		if path.is_empty(): continue
		var length=_length(path)+point.distance_to(end)*.65
		if length<best_length: best=path;best_length=length
		# A directly reachable hotspot is preferable to a nearby detour.
		if point==end: break
	if not best.is_empty():
		route=_smooth(best,geometry)
		remaining=_length(route)

func _length(points: PackedVector2Array) -> float:
	var length=0.0
	for i in range(1,points.size()): length+=points[i-1].distance_to(points[i])
	return length

func _smooth(points: PackedVector2Array, geometry: Dictionary) -> PackedVector2Array:
	var result=PackedVector2Array([points[0]])
	var i=0
	while i<points.size()-1:
		var next=i+1
		for option in range(i+2,mini(points.size(),i+13)):
			if not game.npcs.navigation.clear_segment(geometry,points[i],points[option]): break
			next=option
		result.append(points[next]);i=next
	return result

func _draw():
	if target.is_empty() or not game.comfort.route_guide or not is_instance_valid(game.world): return
	var transform=game.world.get_global_transform_with_canvas()
	var dst: Vector2=transform*target.point
	if not dst.is_finite(): return
	var viewport_bounds=Rect2(Vector2(19,57),size-Vector2(38,115))
	var close: bool=game.player.position.distance_to(target.point)<=target.range
	var caption: String=target.label
	var detail=game.t("Ищи проход рядом","Look for a nearby passage") if route.is_empty() else game.t("До цели · %d шаг.","To goal · %d steps")%ceili(remaining/16)
	if close:
		detail=game.t("E · взаимодействовать","E · interact") if target.action else game.t("Ты на месте","You're here")
	draw_style_box(tile_skin,Rect2(51,321,159,27))
	draw_string(get_theme_default_font(),Vector2(57,332),caption,HORIZONTAL_ALIGNMENT_LEFT,149,11,TRACE)
	draw_string(get_theme_default_font(),Vector2(57,343),detail,HORIZONTAL_ALIGNMENT_LEFT,149,9,game.ComfortTheme.TEXT)
	if not route.is_empty() and not close:
		var points=_markers(route,SPACING+(0 if game.comfort.reduce_motion else 14*travel_age/3))
		for sample in points:
			var at: Vector2=transform*sample.point
			if viewport_bounds.has_point(at): _arrow(at,sample.direction,4,Color("eaca93"))
		var guide_point: Vector2=transform*route[mini(1,route.size()-1)]
		if guide_point.is_finite() and not viewport_bounds.has_point(guide_point):
			var mid=size*.5
			var ray=guide_point-mid
			var scale_factor=minf((viewport_bounds.size.x*.5)/maxf(absf(ray.x),1),(viewport_bounds.size.y*.5)/maxf(absf(ray.y),1))
			var pin=(viewport_bounds.get_center()+ray*scale_factor*.93).round()
			draw_circle(pin,12,DARK)
			_arrow(pin,ray.normalized(),7,TRACE)
	if viewport_bounds.has_point(dst):
		var shift=0 if game.comfort.reduce_motion else roundf(sin(travel_age*TAU/3)*2)
		var marker=dst+Vector2(0,-15+shift)
		draw_circle(marker,9,DARK)
		var rim=Color(.94,.80,.55,.42) if close else Color(.94,.80,.55,.30)
		draw_arc(marker,11,0,TAU,20,rim,1)
		_arrow(marker,Vector2.DOWN,5,TRACE)
		if close and target.action:
			draw_rect(Rect2(marker+Vector2(10,-7),Vector2(17,14)),DARK)
			draw_string(get_theme_default_font(),marker+Vector2(15,4),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,10,TRACE)

func _markers(points: PackedVector2Array, offset: float) -> Array:
	var choices=[]
	var walked=0.0
	for i in range(1,points.size()):
		var delta=points[i]-points[i-1]
		var span=delta.length()
		if not is_finite(span) or span<.5: continue
		while offset<=walked+span:
			choices.append({"point":points[i-1]+delta*((offset-walked)/span),"direction":delta/span})
			if choices.size()>=10: return choices
			offset+=SPACING
		walked+=span
	return choices

func _arrow(at: Vector2, direction: Vector2, scale_px: float, tint: Color):
	if not at.is_finite() or not direction.is_finite() or direction.length_squared() < .01: return
	var normal=direction.orthogonal()
	var points=PackedVector2Array([(at+direction*scale_px).round(),(at-direction*scale_px+normal*scale_px*.8).round(),(at-direction*scale_px*.45).round(),(at-direction*scale_px-normal*scale_px*.8).round()])
	draw_colored_polygon(points,tint)
	points.append(points[0])
	draw_polyline(points,GHOST,1)
