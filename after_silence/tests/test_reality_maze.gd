extends GutTest

const Maze=preload("res://after_silence/core/reality_maze.gd")
const EventProgress=preload("res://after_silence/core/event_progress.gd")

func enter(maze,door: Vector2i) -> String:
	var outcome=""
	for tile in maze.route(door): outcome=maze.move(tile)
	return outcome

func test_every_portal_is_reachable_in_every_room_and_reflection():
	for id in Maze.ORDERS:
		var maze=Maze.new(id)
		while not maze.won():
			var stage: int=maze.stage
			for door in Maze.PORTALS: assert_false(maze.route(door).is_empty(),id)
			var wrong: Vector2i=Maze.PORTALS[0] if maze.destination()!=Maze.PORTALS[0] else Maze.PORTALS[1]
			assert_eq(enter(maze,wrong),"reflect",id)
			assert_eq(maze.stage,stage,id)
			assert_true(maze.reflected,id)
			for door in Maze.PORTALS: assert_false(maze.route(door).is_empty(),id)
			assert_eq(enter(maze,maze.destination()),"advance",id)
			if maze.stage==stage: break
		assert_true(maze.won(),id)

func test_checkpoint_restores_reflection_and_rejects_wall_and_portal():
	var origin=Maze.new("guest")
	var wrong: Vector2i=Maze.PORTALS[0] if origin.destination()!=Maze.PORTALS[0] else Maze.PORTALS[1]
	assert_eq(enter(origin,wrong),"reflect")
	origin.move(origin.route(origin.destination())[0])
	var data=JSON.parse_string(JSON.stringify(origin.capture()))
	var other=Maze.new("guest")
	assert_true(other.restore(data))
	assert_eq(other.capture(),origin.capture())
	assert_eq(other.move(Vector2i(0,0)),"")
	data.tile=[0,0]
	assert_false(other.restore(data))
	data.tile=[4,0]
	assert_false(other.restore(data))
	assert_eq(other.capture(),origin.capture())

func test_only_new_maze_stops_accept_maze_checkpoints():
	var checkpoint={"mode":"reality","reality":Maze.new("letter").capture(),"npc":[600,600],"elapsed":0,"progress":0,"hp":5,"step":0,"alert":0,"heat":0}
	var save={"version":3,"index":0,"phase":"suspended","activity":checkpoint}
	assert_true(EventProgress.valid(save))
	save.index=3
	assert_false(EventProgress.valid(save))
	save.index=0
	checkpoint.mode="escort"
	checkpoint.erase("reality")
	assert_true(EventProgress.valid(save),"pre-0.20 saves remain readable")
