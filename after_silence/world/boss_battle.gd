extends Control
signal won(id: String, flawless: bool)
signal struck
signal hurt
signal left
const Art=preload("res://after_silence/core/ppae_art.gd")
const Impact=preload("res://after_silence/scenes/ppae_impact.tscn")
const Stage=preload("res://after_silence/ui/trial_stage_art.gd")
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
var art_motion=Vector2.ZERO
var art_age=0.0
var frozen=false
var defeated=false
var jump_buffer=0.0
var end_panel: Panel
var end_title: Label
var continue_button: Button
var leave_button: Button
var ai: SelectorComposite
var blackboard: Blackboard
func _ready():
	ai=SelectorComposite.new()
	ai.name="BossPhaseSelector"
	blackboard=Blackboard.new()
	add_child(blackboard)
	for mode in ["windup","attack","exposed"]:
		var leaf=preload("res://after_silence/core/boss_phase_leaf.gd").new()
		leaf.phase_name=mode
		leaf.name=mode
		ai.add_child(leaf)
	add_child(ai)
	end_panel=Panel.new()
	end_panel.position=Vector2(174,117)
	end_panel.size=Vector2(292,126)
	end_panel.add_theme_stylebox_override("panel",Stage.plate("panel"))
	add_child(end_panel)
	end_title=Label.new();end_title.position=Vector2(15,10);end_panel.add_child(end_title)
	continue_button=Button.new();continue_button.position=Vector2(14,43);continue_button.size=Vector2(264,29)
	end_panel.add_child(continue_button);Stage.button(continue_button)
	continue_button.pressed.connect(func():
		if defeated: start(boss_id,english)
		else: _resume_battle())
	leave_button=Button.new();leave_button.position=Vector2(14,81);leave_button.size=Vector2(264,29)
	end_panel.add_child(leave_button);Stage.button(leave_button)
	leave_button.pressed.connect(_leave_battle)
	end_panel.hide()
var reduced_motion=false

func start(id: String, en: bool) -> void:
	boss_id=id
	english=en
	active=true
	frozen=false
	defeated=false
	jump_buffer=0
	end_panel.hide()
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
	art_age=0.0
	art_motion=Vector2.ZERO
	note="УКЛОНЯЙСЯ · ПРОБЕЛ — ПРЫЖОК · E — КОНТРАТАКА" if not en else "DODGE · SPACE TO JUMP · E TO COUNTER"
	queue_redraw()
func jump() -> bool:
	if not active or frozen or jump_age<.44: return false
	jump_age=0.0
	return true
func pattern() -> int:
	return (wave+1+combat_stage())%3 if boss_id=="watcher" else (wave+combat_stage())%3
func combat_stage() -> int:
	return clampi(3-boss_hp,0,2)
func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode==KEY_ESCAPE:
		if not frozen: _show_battle_result(false)
		elif not defeated: _resume_battle()
		get_viewport().set_input_as_handled()
		return
	if frozen: return
	if event.physical_keycode==KEY_SPACE:
		if not jump() and jump_age>=.30: jump_buffer=.14
		get_viewport().set_input_as_handled()
	elif event.physical_keycode==KEY_E:
		counter()
		get_viewport().set_input_as_handled()
func counter() -> bool:
	if not active or frozen or phase!="exposed" or player_pos.distance_to(Vector2(320,148))>92: return false
	boss_hp-=1
	_impact(Vector2(320,148))
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
	if not active or frozen: return
	dt=minf(dt,.05)
	phase_age+=dt
	jump_age=minf(1.0,jump_age+dt)
	if jump_buffer>0:
		jump_buffer=maxf(0,jump_buffer-dt)
		if jump_age>=.44 and jump_buffer>0: jump();jump_buffer=0
	invulnerable=maxf(0,invulnerable-dt)
	flash=maxf(0,flash-dt)
	var motion=Input.get_vector("as_left","as_right","as_up","as_down")
	art_motion=motion
	art_age=fposmod(art_age+dt,60.0)
	player_pos+=motion*192.0*dt
	player_pos=player_pos.clamp(ARENA.position+Vector2(12,14),ARENA.end-Vector2(12,14))
	blackboard.set_value("dt",dt)
	ai.tick(self,blackboard)
	ai.after_run(self,blackboard)
	queue_redraw()
func tick_phase(dt: float) -> void:
	if phase=="windup":
		if phase_age<.1: target=player_pos
		if phase_age>=(.7 if boss_id=="watcher" else .85):
			phase="attack"
			phase_age=0.0
			if pattern()==1 or combat_stage()==2:
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
	_impact(player_pos)
	hurt.emit()
	flawless=false
	invulnerable=1.2
	flash=.35
	if player_hp<=0:
		player_hp=0
		bullets.clear()
		_show_battle_result(true)

func _show_battle_result(lost: bool) -> void:
	frozen=true
	defeated=lost
	jump_buffer=0.0
	end_title.text=("The signal faded" if english else "Сигнал погас") if lost else ("Paused" if english else "Пауза")
	continue_button.text=("Retry" if english else "Повторить") if lost else ("Resume" if english else "Продолжить")
	leave_button.text="Return to the area" if english else "Вернуться в локацию"
	end_panel.show()
	continue_button.grab_focus()
	queue_redraw()

func _resume_battle() -> void:
	frozen=false
	end_panel.hide()
	continue_button.release_focus()

func _leave_battle() -> void:
	_resume_battle()
	active=false
	hide()
	left.emit()
func _impact(at: Vector2) -> void:
	if reduced_motion: return
	var burst=Impact.instantiate()
	burst.position=at
	add_child(burst)
	var playback: AnimationPlayer=burst.get_node("AnimationPlayer")
	playback.animation_finished.connect(func(_name): burst.queue_free())
	playback.play("impact")

func _draw() -> void:
	if not active: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("151f1af6"))
	draw_rect(ARENA.grow(6),Color("33453b"))
	Stage.surface(self,"signal_grid" if boss_id=="relay" else "reality",ARENA)
	draw_rect(ARENA,Color("96b3a4"),false,2)
	for x in range(60,580,32): draw_line(Vector2(x,ARENA.position.y),Vector2(x,ARENA.end.y),Color("2a3d35"),1)
	for y in range(116,320,32): draw_line(Vector2(ARENA.position.x,y),Vector2(ARENA.end.x,y),Color("2a3d35"),1)
	var accent=Color("e283a0") if boss_id=="watcher" else Color("8ce0ce")
	if phase=="windup":
		var warning=accent * Color(1,1,1,.2+.3*phase_age/.85)
		if pattern()==0: draw_rect(Rect2(target.x-23,ARENA.position.y,46,ARENA.size.y),warning)
		elif pattern()==2: draw_rect(Rect2(ARENA.position.x,target.y-21,ARENA.size.x,42),warning)
		else:
			for i in range(-3,4): draw_line(Vector2(320,138),Vector2(320,138)+Vector2.from_angle(PI/2+i*.21)*210,warning,4)
		if combat_stage()==2 and pattern()!=1:
			for i in range(-3,4): draw_line(Vector2(320,138),Vector2(320,138)+Vector2.from_angle(PI/2+i*.21)*210,warning,2)
	if phase=="attack":
		if pattern()==0 and phase_age<.7: draw_rect(Rect2(target.x-23,ARENA.position.y,46,ARENA.size.y),accent)
		if pattern()==2 and phase_age<.7: draw_rect(Rect2(ARENA.position.x,target.y-21,ARENA.size.x,42),accent)
	for bullet in bullets: Stage.stamp(self,9,bullet.pos,Vector2(18,18),accent.lerp(Color.WHITE,.38))
	var boss=Vector2(320,148)
	var pulse=0.0 if reduced_motion else sin(Time.get_ticks_msec()*.003)*3.0
	var boss_pose: String="attack_S" if phase=="attack" else "hurt_S" if phase=="exposed" else "idle_S"
	Art.paint_actor(self,"watcher" if boss_id=="watcher" else "guardian",boss_pose,0 if reduced_motion else int(phase_age*8),boss+Vector2(0,28+round(pulse)),1.58,Color("dbc5af") if phase=="exposed" else Color.WHITE)
	var bob=4*jump_age*(.44-jump_age)/(.44*.44)*20 if jump_age<.44 else 0.0
	var facing: String="E" if art_motion.x>.2 else "W" if art_motion.x<-.2 else "S" if art_motion.y>.2 else "N"
	var action: String="hurt" if invulnerable>1.0 else "dodge" if bob>0.0 else "idle" if art_motion.is_zero_approx() else "walk"
	Art.paint_actor(self,"vera",action+"_"+facing,0 if reduced_motion else int(art_age*9),player_pos-Vector2(0,bob),.95)
	draw_rect(Rect2(52,59,160,8),Color("2e4037"))
	draw_rect(Rect2(52,59,160*boss_hp/3.0,8),accent)
	draw_rect(Rect2(428,59,160,8),Color("2e4037"))
	draw_rect(Rect2(428,59,160*player_hp/3.0,8),Color("9ecbb1"))
	var font=get_theme_default_font()
	draw_string(font,Vector2(260,78),("ФАЗА " if not english else "PHASE ")+str(combat_stage()+1),HORIZONTAL_ALIGNMENT_LEFT,-1,9,accent)
	draw_string(font,Vector2(52,45),"НАБЛЮДАТЕЛЬ" if boss_id=="watcher" and not english else "WATCHER" if boss_id=="watcher" else "СТОРОЖ РЕЛЕ" if not english else "RELAY GUARDIAN",HORIZONTAL_ALIGNMENT_LEFT,-1,10,accent)
	draw_string(font,Vector2(52,342),note,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("d2e7dc"))
	if frozen: draw_rect(Rect2(Vector2.ZERO,size),Color("14101aaa"))
