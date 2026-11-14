extends Control
signal won(id: String, flawless: bool)
signal struck
signal hurt
const PORTRAIT=preload("res://after_silence/assets/pechatai/player/idle.png")
const ARENA=Rect2(52,106,536,214)
var boss_id="relay"
var english=false
var active=false
var boss_hp=3
var player_hp=3
var flawless=true
var player_pos=Vector2(320,272)
var phase="windup"
var phase_age=0.0
var wave=0
var target=Vector2(320,240)
var jump_age=1.0
var invulnerable=0.0
var bullets: Array=[]
var flash=0.0
var note=""
func start(id: String, en: bool) -> void:
	boss_id=id
	english=en
	active=true
	visible=true
	boss_hp=3
	player_hp=3
	flawless=true
	player_pos=Vector2(320,273)
	target=player_pos
	phase="windup"
	phase_age=0.0
	wave=0
	bullets.clear()
	jump_age=1.0
	invulnerable=0.0
	flash=0.0
	note="УКЛОНЯЙСЯ · ПРОБЕЛ — ПРЫЖОК · E — КОНТРАТАКА" if not en else "DODGE · SPACE TO JUMP · E TO COUNTER"
	queue_redraw()
func jump() -> bool:
	if not active or jump_age<.44: return false
	jump_age=0.0
	return true
func pattern() -> int:
	return (wave+1)%3 if boss_id=="watcher" else wave%3
func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode==KEY_SPACE:
		jump()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode==KEY_E:
		counter()
		get_viewport().set_input_as_handled()
func counter() -> bool:
	if not active or phase!="exposed" or player_pos.distance_to(Vector2(320,148))>92: return false
	boss_hp-=1
	struck.emit()
	flash=.25
	if boss_hp<=0:
		active=false
		visible=false
		won.emit(boss_id,flawless)
	else:
		wave=0
		phase="windup"
		phase_age=0.0
		player_pos=Vector2(320,273)
		note="КОНТУР ПОВРЕЖДЁН · ЕЩЁ %d"%boss_hp if not english else "CIRCUIT DAMAGED · %d LEFT"%boss_hp
	queue_redraw()
	return true
func _physics_process(dt: float) -> void:
	if not active: return
	dt=minf(dt,.05)
	phase_age+=dt
	jump_age=minf(1.0,jump_age+dt)
	invulnerable=maxf(0,invulnerable-dt)
	flash=maxf(0,flash-dt)
	var motion=Input.get_vector("as_left","as_right","as_up","as_down")
	player_pos+=motion*192.0*dt
	player_pos=player_pos.clamp(ARENA.position+Vector2(12,14),ARENA.end-Vector2(12,14))
	if phase=="windup":
		if phase_age<.1: target=player_pos
		if phase_age>=(.7 if boss_id=="watcher" else .85):
			phase="attack"
			phase_age=0.0
			if pattern()==1:
				for i in range(-4 if boss_id=="watcher" else -3,5 if boss_id=="watcher" else 4):
					bullets.append({"pos":Vector2(320,138),"velocity":Vector2.from_angle(PI/2+i*.21)*(215.0 if boss_id=="watcher" else 175.0)})
	elif phase=="attack":
		if pattern()==0 and absf(player_pos.x-target.x)<23 and phase_age<.7: _hit()
		if pattern()==2 and absf(player_pos.y-target.y)<21 and phase_age<.7: _hit()
		for bullet in bullets:
			bullet.pos+=bullet.velocity*dt
			if bullet.pos.distance_to(player_pos)<13: _hit()
		bullets=bullets.filter(func(b): return ARENA.grow(24).has_point(b.pos))
		if phase_age>=(1.0 if boss_id=="watcher" else 1.15):
			bullets.clear()
			wave+=1
			phase="exposed" if wave%3==0 else "windup"
			phase_age=0.0
			if phase=="exposed": note="СИГНАЛ ОТКРЫТ · ПОДОЙДИ И НАЖМИ E" if not english else "SIGNAL OPEN · GET CLOSE AND PRESS E"
	elif phase=="exposed" and phase_age>=(3.0 if boss_id=="watcher" else 3.5):
		phase="windup"
		phase_age=0.0
		note="СЛЕДИ ЗА РАЗМЕТКОЙ" if not english else "WATCH THE TELEGRAPH"
	queue_redraw()
func _hit() -> void:
	if invulnerable>0 or jump_age<.44: return
	player_hp-=1
	hurt.emit()
	flawless=false
	invulnerable=1.2
	flash=.35
	if player_hp<=0:
		player_hp=3
		boss_hp=3
		wave=0
		phase="windup"
		phase_age=0.0
		player_pos=Vector2(320,273)
		bullets.clear()
		note="ПОПРОБУЙ СНОВА · СМОТРИ НА ПРЕДУПРЕЖДЕНИЯ" if not english else "TRY AGAIN · WATCH THE WARNINGS"
func _draw() -> void:
	if not active: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("050b10ef"))
	draw_rect(ARENA,Color("0d2028"))
	draw_rect(ARENA,Color("478d8b"),false,2)
	for x in range(60,580,32): draw_line(Vector2(x,ARENA.position.y),Vector2(x,ARENA.end.y),Color("203c43"),1)
	for y in range(116,320,32): draw_line(Vector2(ARENA.position.x,y),Vector2(ARENA.end.x,y),Color("203c43"),1)
	var accent=Color("e283a0") if boss_id=="watcher" else Color("8ce0ce")
	if phase=="windup":
		var warning=accent * Color(1,1,1,.2+.3*phase_age/.85)
		if pattern()==0: draw_rect(Rect2(target.x-23,ARENA.position.y,46,ARENA.size.y),warning)
		elif pattern()==2: draw_rect(Rect2(ARENA.position.x,target.y-21,ARENA.size.x,42),warning)
		else:
			for i in range(-3,4): draw_line(Vector2(320,138),Vector2(320,138)+Vector2.from_angle(PI/2+i*.21)*210,warning,4)
	if phase=="attack":
		if pattern()==0 and phase_age<.7: draw_rect(Rect2(target.x-23,ARENA.position.y,46,ARENA.size.y),accent)
		if pattern()==2 and phase_age<.7: draw_rect(Rect2(ARENA.position.x,target.y-21,ARENA.size.x,42),accent)
	for bullet in bullets: draw_circle(bullet.pos,7,accent)
	var boss=Vector2(320,148)
	var pulse=sin(Time.get_ticks_msec()*.006)*4.0
	for i in range(8):
		var direction=Vector2.from_angle(i*TAU/8+phase_age*.3)
		draw_line(boss+direction*35,boss+direction*(53+pulse),accent,3)
	draw_arc(boss,48+pulse,0,TAU,48,accent.darkened(.45),2)
	draw_circle(boss,37,accent if phase=="exposed" else Color("314d53"))
	draw_circle(boss,26,Color("101a22"))
	draw_circle(boss+Vector2(-9,-3),4,accent)
	draw_circle(boss+Vector2(9,-3),4,accent)
	var bob=4*jump_age*(.44-jump_age)/(.44*.44)*20 if jump_age<.44 else 0.0
	draw_texture_rect_region(PORTRAIT,Rect2(player_pos+Vector2(-24,-45-bob),Vector2(48,52)),Rect2(4,2,56,61),Color.WHITE if invulnerable<=0 or int(invulnerable*10)%2==0 else Color("a4c7c2"))
	draw_rect(Rect2(52,59,160,8),Color("294148"))
	draw_rect(Rect2(52,59,160*boss_hp/3.0,8),accent)
	draw_rect(Rect2(428,59,160,8),Color("294148"))
	draw_rect(Rect2(428,59,160*player_hp/3.0,8),Color("9ecbb1"))
	var font=get_theme_default_font()
	draw_string(font,Vector2(52,45),"НАБЛЮДАТЕЛЬ" if boss_id=="watcher" and not english else "WATCHER" if boss_id=="watcher" else "СТОРОЖ РЕЛЕ" if not english else "RELAY GUARDIAN",HORIZONTAL_ALIGNMENT_LEFT,-1,10,accent)
	draw_string(font,Vector2(52,342),note,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("d2e7dc"))
	if flash>0: draw_rect(Rect2(Vector2.ZERO,size),Color(1,1,1,flash*.25))
