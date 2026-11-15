extends GutTest
const Battle=preload("res://after_silence/core/tactical_battle.gd")
func sample() -> RefCounted:
	var tiles=[];var links=[]
	for y in range(5):
		for x in range(5): tiles.append([x,y])
	for p in tiles:
		for d in Battle.DIRECTIONS:
			var next=Vector2i(p[0],p[1])+d
			if next.x>=0 and next.x<5 and next.y>=0 and next.y<5: links.append([p,[next.x,next.y]])
	var model=Battle.new()
	assert_true(model.configure(tiles,links,[{"id":"vera","side":"party","role":"wanderer","cell":[1,1]},{"id":"pavel","side":"party","role":"warden","cell":[1,2]},{"id":"guest","side":"enemy","role":"ranger","cell":[3,1]},{"id":"mara","side":"enemy","role":"mediator","cell":[3,3]}]))
	return model
func test_turn_order_and_movement_charge():
	var b=sample()
	assert_eq(b.order,["vera","pavel","guest","mara"])
	assert_true(b.command("vera","move",Vector2i(2,1)).ok)
	assert_eq(b.units.vera.ap,2)
	assert_eq(b.phase,"moving")
	assert_false(b.command("vera","attack","guest").ok)
	b.finish_move()
	assert_true(b.command("vera","attack","guest").ok)
	assert_eq(b.units.guest.hp,1)
	assert_eq(b.units.vera.ap,0)
	assert_false(b.command("vera","defend").ok)
func test_invalid_commands_do_not_change_state():
	var b=sample()
	var before=b.capture()
	for command in [["pavel","end",null],["vera","move",Vector2i(1,2)],["vera","move",Vector2i(4,4)],["vera","attack","pavel"],["vera","attack","guest"],["vera","help","guest"]]:
		assert_false(b.command(command[0],command[1],command[2]).ok)
		assert_eq(b.capture(),before)
func test_guard_and_help_use_actions():
	var b=sample()
	b.units.vera.hp=1
	assert_true(b.command("vera","defend").ok)
	assert_eq(b.units.vera.guard,1)
	b.command("vera","end")
	assert_true(b.command("pavel","help","vera").ok)
	assert_eq(b.units.vera.hp,2)
	assert_eq(b.units.pavel.ap,1)
	assert_false(b.command("pavel","help","vera").ok)
func test_blocked_cells_and_edges_occlude_and_disconnect():
	var b=sample()
	b.cells.erase("2:1")
	assert_false(b.sees(Vector2i(1,1),Vector2i(3,1)))
	var path=b.route("vera",Vector2i(2,2),10)
	assert_gt(path.size(),0)
	for p in path: assert_ne(p,Vector2i(2,1))
	b.edges.erase("1:1>1:0");b.edges.erase("1:1>0:1")
	b.edges.erase("1:1>1:2");b.edges.erase("1:1>2:1")
	assert_eq(b.route("vera",Vector2i(2,2)),[])
func test_save_restores_pending_movement_without_recharging():
	var b=sample();b.command("vera","move",Vector2i(2,1))
	var saved=JSON.parse_string(JSON.stringify(b.capture()))
	var copy=Battle.new()
	assert_true(copy.restore(saved))
	assert_eq(copy.phase,"moving")
	assert_eq(copy.units.vera.ap,2.0)
	copy.finish_move()
	assert_eq(copy.location("vera"),Vector2i(2,1))
	assert_eq(copy.units.vera.ap,2.0)
	var before=copy.capture()
	for field in ["hp","ap","damage","range"]:
		var bad=saved.duplicate(true);bad.units.vera[field]=999
		assert_false(copy.restore(bad))
		assert_eq(copy.capture(),before)
func test_class_aware_ai_and_determinism():
	var a=sample();var b=sample()
	for i in range(600):
		if a.phase in ["victory","defeat"]: break
		var id=a.active_id()
		var choice={}
		for kind in ["help","attack","move","defend","end"]:
			choice=a.plan(id,kind)
			if not choice.is_empty(): break
		assert_false(choice.is_empty())
		assert_true(a.command(id,choice.kind,choice.get("target")).ok)
		assert_true(b.command(id,choice.kind,choice.get("target")).ok)
		if a.phase=="moving": a.finish_move();b.finish_move()
		assert_eq(a.capture(),b.capture())
	assert_true(a.phase in ["victory","defeat"])
func test_retreat_is_terminal_and_save_validation_is_atomic():
	var b=sample()
	assert_true(b.command("vera","retreat").ok)
	var before=b.capture()
	assert_false(b.command("vera","attack","guest").ok)
	assert_eq(b.capture(),before)
	var bad=before.duplicate(true);bad.order[1]="vera"
	assert_false(b.restore(bad));assert_eq(b.capture(),before)
func test_enemy_attacks_cause_defeat_and_guard_consumes_the_hit():
	var b=sample()
	b.command("vera","defend");b.command("vera","end");b.command("pavel","end")
	assert_true(b.command("guest","attack","vera").ok)
	assert_eq(b.units.vera.hp,5)
	assert_eq(b.units.vera.guard,0)
	b.command("guest","end");b.command("mara","end")
	for hit in range(5):
		b.command("vera","end");b.command("pavel","end")
		assert_true(b.command("guest","attack","vera").ok)
		if b.phase=="defeat": break
		b.command("guest","end");b.command("mara","end")
	assert_eq(b.units.vera.hp,0)
	assert_eq(b.phase,"defeat")
	assert_true(Battle.valid(b.capture()))
