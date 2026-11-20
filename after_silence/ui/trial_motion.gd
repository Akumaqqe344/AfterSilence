extends Control

var game
var particles=[]
var transfers=[]
var turns=[]
const DURATION=.36

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=2
	set_process(false)

func burst(at: Vector2,tint: Color,amount: int=8):
	if game.comfort.reduce_motion: return
	for i in range(amount):
		var ray=Vector2.from_angle(i*TAU/amount)
		particles.append({"point":at,"speed":ray*(20+i%3*10),"age":0.0,"color":tint})
	while particles.size()>112: particles.pop_front()
	set_process(true)

func transfer(from: Vector2,to: Vector2,tint: Color):
	if game.comfort.reduce_motion: return
	transfers.append({"from":from,"to":to,"age":0.0,"color":tint})
	while transfers.size()>8: transfers.pop_front()
	set_process(true)

func turn(at: Vector2,texture: Texture2D):
	if game.comfort.reduce_motion: return
	turns.append({"point":at,"texture":texture,"age":0.0})
	while turns.size()>4: turns.pop_front()
	set_process(true)

func _process(dt):
	if game.modal: return
	for set_of_items in [particles,transfers,turns]:
		for item in set_of_items: item.age+=dt
		while not set_of_items.is_empty() and set_of_items[0].age>=DURATION: set_of_items.pop_front()
	queue_redraw()
	if particles.is_empty() and transfers.is_empty() and turns.is_empty(): set_process(false)

func _draw():
	for turn_effect in turns:
		var t=turn_effect.age/DURATION
		draw_set_transform(turn_effect.point,-PI*.5*(1-t))
		draw_texture_rect(turn_effect.texture,Rect2(-25,-25,50,50),false,Color(1,1,1,1.0-t))
	draw_set_transform(Vector2.ZERO)
	for item in particles:
		var t=item.age/DURATION
		var at=(item.point+item.speed*item.age+Vector2(0,-13*sin(t*PI))).round()
		var tint: Color=item.color
		tint.a=(1.0-t)*.88
		draw_rect(Rect2(at,Vector2.ONE*(3 if t<.32 else 2)),tint)
		if t<.42 and item.speed.length_squared()>1200:
			draw_rect(Rect2(at+Vector2(-2,1),Vector2(7,1)),tint)
			draw_rect(Rect2(at+Vector2(1,-2),Vector2(1,7)),tint)
	for item in transfers:
		for i in range(4):
			var t=maxf(0,item.age/DURATION-i*.08)
			var at=(item.from.lerp(item.to,t)+Vector2(0,-18*sin(t*PI))).round()
			var tint: Color=item.color
			tint.a=(1-t*.6)*(1-i*.2)
			draw_rect(Rect2(at-Vector2(2,2),Vector2(5,5)),tint)
