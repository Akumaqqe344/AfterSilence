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
	var origin=Maze.new("epochs")
	var wrong: Vector2i=Maze.PORTALS[0] if origin.destination()!=Maze.PORTALS[0] else Maze.PORTALS[1]
	assert_eq(enter(origin,wrong),"reflect")
	origin.move(origin.route(origin.destination())[0])
	var data=JSON.parse_string(JSON.stringify(origin.capture()))
	var other=Maze.new("epochs")
	assert_true(other.restore(data))
	assert_eq(other.capture(),origin.capture())
	assert_eq(other.move(Vector2i(0,0)),"")
	data.tile=[0,0]
	assert_false(other.restore(data))
	data.tile=[4,0]
	assert_false(other.restore(data))
	assert_eq(other.capture(),origin.capture())

func test_only_new_maze_stops_accept_maze_checkpoints():
	var checkpoint={"mode":"reality","reality":Maze.new("epochs").capture()}
	var save={"version":3,"index":0,"phase":"suspended","activity":checkpoint}
	assert_true(EventProgress.valid(save))
	save.index=3
	assert_false(EventProgress.valid(save))
	save.index=0
	checkpoint.mode="escort"
	checkpoint.erase("reality")
	assert_true(EventProgress.valid(save),"pre-0.20 saves remain readable")
	var migrated=EventProgress.upgrade(save,{"id":"letter","mode":"letter_press"})
	assert_eq(migrated.activity,{"mode":"letter_press","moves":[]})
	assert_eq(migrated.index,save.index)
	assert_eq(migrated.phase,"suspended")

func test_failed_legacy_scene_restarts_on_its_replacement():
	var save={"version":3,"index":1,"phase":"failure","activity":{"mode":"stealth","elapsed":16}}
	var migrated=EventProgress.upgrade(save,{"id":"guest","mode":"footprints"})
	assert_eq(migrated.phase,"suspended")
	assert_eq(migrated.activity.mode,"footprints")
	assert_true(EventProgress.valid(migrated))
	assert_eq(EventProgress.upgrade({"phase":"decision"},{"id":"guest","mode":"footprints"}),{"phase":"decision"})
