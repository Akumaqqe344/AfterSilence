extends Node2D
var zone="town"
var echo=false
var anchor: Node2D
var age=0.0
var game
var motes=[]
const Water=preload("res://after_silence/world/watercourse.gd")
func _ready():
	z_index=20
func _process(dt):
	if game==null or game.comfort.reduce_motion or game.modal or game.in_menu or game.event_window.active:
		if not motes.is_empty(): motes.clear()
		queue_redraw()
		return
	age+=dt
	if is_instance_valid(anchor): position=anchor.position
	for mote in motes: mote.age+=dt
	while not motes.is_empty() and motes[0].age>.35: motes.pop_front()
	queue_redraw()

func footstep(running: bool):
	if game==null or game.comfort.reduce_motion or not is_instance_valid(anchor) or anchor.elevation>2: return
	if zone not in ["town","forest","orchard","harbor"]: return
	for i in range(4 if running else 2):
		var offset=Vector2(-7+i*4,2+i%2*2)
		motes.append({"start":anchor.position+offset,"velocity":Vector2(-16+i*9,-12-i%2*9),"age":0.0})
	while motes.size()>28: motes.pop_front()

func _draw():
	if game==null or game.comfort.reduce_motion or game.modal or game.in_menu or game.event_window.active: return
	var count=34 if zone=="forest" else 16
	for i in range(count):
		var speed=110.0 if zone=="forest" else 7.0
		var p=Vector2(fposmod(i*97.0-age*speed*.2,720)-360,fposmod(i*71.0+age*speed,440)-220)
		if zone=="forest": draw_line(p,p+Vector2(-2,7),Color(.62,.76,.8,.13 if not echo else .22))
		else: draw_rect(Rect2(p.round(),Vector2(1,1)),Color("dfceb64e"))
	if zone in ["town","harbor","orchard"]:
		for i in range(22):
			var cell=(position/32).floor()*32
			var anchor_at=cell+Vector2(posmod(i*67,580)-290,posmod(i*41,300)-150)
			var world=anchor_at+Vector2(roundf(sin(i+age*.72)*7),0)
			if Water.depth(zone,world)<8: continue
			var glint=(world-position).round()
			draw_rect(Rect2(glint,Vector2(5+i%8,1)),Color("a9e1d964"))
			if i%4==0: draw_rect(Rect2(glint+Vector2(2,3),Vector2(4,1)),Color("b3e3e23a"))
	for mote in motes:
		var at=(mote.start-position+mote.velocity*mote.age).round()
		draw_rect(Rect2(at,Vector2(3,2)),Color(.72,.61,.48,(1.0-mote.age/.35)*.7))
	if echo:
		for i in range(4): draw_rect(Rect2(-360,-180+i*100+sin(age*.15+i)*25,720,12),Color(.4,.5,.65,.025))
