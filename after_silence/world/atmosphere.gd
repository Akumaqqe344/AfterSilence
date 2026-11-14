extends Node2D
var zone="town"
var echo=false
var anchor: Node2D
var age=0.0
func _ready():
	z_index=20
func _process(dt):
	age+=dt
	if is_instance_valid(anchor): position=anchor.position
	queue_redraw()
func _draw():
	var count=40 if zone=="forest" else 20
	for i in range(count):
		var speed=110.0 if zone=="forest" else 7.0
		var p=Vector2(fposmod(i*97.0-age*speed*.2,720)-360,fposmod(i*71.0+age*speed,440)-220)
		if zone=="forest": draw_line(p,p+Vector2(-2,7),Color(.62,.76,.8,.13 if not echo else .22))
		else: draw_rect(Rect2(p,Vector2(1,1)),Color(.88,.81,.59,.25+.15*sin(age+i)))
	if echo:
		for i in range(4): draw_rect(Rect2(-360,-180+i*100+sin(age*.15+i)*25,720,12),Color(.4,.5,.65,.025))
