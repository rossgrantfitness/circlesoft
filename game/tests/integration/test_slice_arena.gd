extends TestCase
## VS-29, Kasp's arena graybox (docs/maps/kasp_arena.md, scripts/tools/make_kasp_arena.py): one scene at two scales. Every named node the boss
## code looks for exists at the map's coordinates; the spawns are on the floor and reach the ramp, the plateau and each turret pylon on foot;
## the plateau is clear; the turrets see the centre; the dormant colossus stands in its cradle and the loader is parked at the gate (robot data);
## the clutter stays off the plateau, the gates, the heaps and the cradle; and a real slice Main boots it as an ActionRoom with the orbit camera,
## the robot stage and a retry spawn on each phase.

const WalkGrid = preload("res://tests/integration/walk_grid_kit.gd")
const ROOM: String = "kasp_arena"
const PLATEAU_TOP: float = 3.0
## name -> [x, y, z] from the map (the named-node table in kasp_arena.md); y is the marker's height.
const MARKERS: Dictionary = {
	"hushmaster_start": [0.0, 3.0, 0.0], "turret_k_nw": [-13.0, 5.5, -14.0], "turret_k_ne": [13.0, 5.5, -14.0], "turret_k_e": [18.0, 5.5, 8.0],
	"drone_hatch_a": [-10.0, 3.0, -6.0], "drone_hatch_b": [10.0, 3.0, -6.0], "drone_hatch_c": [0.0, 3.0, 11.0],
	"kasp_escape_target": [0.0, 3.0, -19.0], "mech_start": [0.0, 0.0, -110.0], "loader_parked": [8.0, 0.0, 56.0],
	"colossus_cradle": [105.0, 0.0, 0.0], "colossus_dock_pos": [84.0, 0.0, 0.0], "dock_approach": [68.2, 0.0, 0.0], "stockade_e_gate": [62.0, 0.0, 0.0],
}
const SPAWNS: Dictionary = {"from_j5": [0.0, 58.0], "retry_phase1": [0.0, 54.0], "retry_phase2": [84.0, 0.0]}
const SHOTS: Array[String] = ["shot_wide", "shot_ramp", "shot_reveal", "shot_title", "shot_jack_in", "shot_core_reveal"]
const CRANES: Array[String] = ["crane_a", "crane_b", "crane_c"]

var _main: Main = null
var _router: Node = null
var _state: Node = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_router = tree.root.get_node("SceneRouter")


func after_each() -> void:
	if _main != null and is_instance_valid(_main):
		_main.apply_mode(GameMode.Mode.CLASSIC)
	_router.set("main", null)
	_router.set("instant", false)
	_router.set("current_room_id", "")
	_router.set("pending_room_id", "")
	_router.set("rooms_id", "world/rooms")
	_state.set("rooms_data_id", "world/rooms")
	_state.call("reset")
	Placements.extra_ids = []
	Placements.extra_scene_ids = []
	Placements.extra_job_ids = []
	InputSorting.revert()
	for node: Node in tree.get_nodes_in_group(ActionRoom.GROUP_HUD):
		node.queue_free()
	for action: StringName in [&"light", &"interact", &"jump"]:
		Input.action_release(action)


func _entry() -> Dictionary:
	return (DataDB.get_dict("slice/rooms").get("rooms", {}) as Dictionary).get(ROOM, {})


func _level() -> Node3D:
	var packed: PackedScene = load(str(_entry()["scene"])) as PackedScene
	assert_not_null(packed, "the arena scene loads")
	var node: Node3D = packed.instantiate() as Node3D
	own(node)
	return node


func _grid(level: Node3D) -> Object:
	return WalkGrid.new(level, 32.0, 78.0, -32.0, -32.0)


func test_the_rooms_row_is_the_arena_row_of_the_map() -> void:
	var entry: Dictionary = _entry()
	assert_false(entry.is_empty(), "kasp_arena is in slice/rooms.json")
	assert_eq(entry.get("kind"), "arena")
	assert_eq(entry.get("camera"), "orbit")
	assert_true(bool(entry.get("combat", false)))
	assert_eq(entry.get("robots"), "kasp_arena", "the robot stage builds the loader and the colossus")
	assert_true(bool(entry.get("checkpoint", false)), "a retry point")
	assert_true(bool(entry.get("autosave", false)), "the arena gate auto-saves")
	assert_eq(entry.get("spawns"), ["from_j5", "retry_phase1", "retry_phase2"])
	assert_eq(entry.get("default_spawn"), "from_j5")
	assert_true(ResourceLoader.exists(str(entry["scene"])))


func test_every_named_node_the_boss_code_looks_for_is_there_at_the_maps_coordinates() -> void:
	var level: Node3D = _level()
	assert_false(level is FieldRoom, "a plain level, Main wraps it in an ActionRoom")
	for marker_name: String in MARKERS:
		var node: Node3D = level.get_node_or_null("Markers/" + marker_name) as Node3D
		assert_not_null(node, "Markers/%s exists" % marker_name)
		if node != null:
			var want: Array = MARKERS[marker_name]
			assert_almost_eq(node.position.x, float(want[0]), 0.05, "%s x" % marker_name)
			assert_almost_eq(node.position.y, float(want[1]), 0.05, "%s y" % marker_name)
			assert_almost_eq(node.position.z, float(want[2]), 0.05, "%s z" % marker_name)
	for spawn_name: String in SPAWNS:
		var spawn: Marker3D = level.get_node_or_null("Spawns/" + spawn_name) as Marker3D
		assert_not_null(spawn, "Spawns/%s exists" % spawn_name)
		if spawn != null:
			assert_almost_eq(spawn.position.x, float((SPAWNS[spawn_name] as Array)[0]), 0.05)
			assert_almost_eq(spawn.position.z, float((SPAWNS[spawn_name] as Array)[1]), 0.05)
	for shot: String in SHOTS:
		assert_not_null(level.get_node_or_null("Shots/" + shot), "camera shot %s exists" % shot)
	for crane: String in CRANES:
		assert_not_null(level.get_node_or_null(crane), "%s exists" % crane)
		assert_not_null(level.get_node_or_null("%s/magnet" % crane), "%s has its magnet marker" % crane)
	assert_not_null(level.get_node_or_null("term_save_arena"), "the save terminal (outside the south gate)")
	assert_not_null(level.get_node_or_null("stockade_e_barricade"), "the east gate's barricade (crane B lifts it in the transition)")
	assert_eq(level.get_node("term_save_arena").get("room_id"), ROOM)


func test_the_names_match_what_the_boss_data_asks_for() -> void:
	var hush: Dictionary = DataDB.get_dict("combat/bosses/hushmaster")
	var arena: Dictionary = {}
	for phase: Variant in hush.get("phases", []) as Array:
		if (phase as Dictionary).has("arena"):
			arena = (phase as Dictionary)["arena"]
	if arena.is_empty():
		return          # the Combat Designer's file may be reshaped; the named-node table above is the contract
	var level: Node3D = _level()
	for key: String in ["hushmaster_start", "retry_node"]:
		var wanted: String = str(arena.get(key, ""))
		if wanted.is_empty():
			continue
		var found: bool = level.get_node_or_null("Markers/" + wanted) != null or level.get_node_or_null("Spawns/" + wanted) != null
		assert_true(found, "boss data names %s and the arena has it" % wanted)
	for list_key: String in ["drone_hatches", "turret_nodes"]:
		for wanted: Variant in arena.get(list_key, []) as Array:
			assert_not_null(level.get_node_or_null("Markers/" + str(wanted)), "boss data names %s and the arena has it" % str(wanted))


func test_spawns_are_on_the_floor_and_reach_the_ramp_the_plateau_and_every_pylon() -> void:
	var level: Node3D = _level()
	var grid: Object = _grid(level)
	var start: Marker3D = level.get_node("Spawns/from_j5")
	var cell: Vector2i = grid.cell_of(start.position.x, start.position.z)
	assert_almost_eq(grid.h(cell.x, cell.y), 0.0, 0.05, "from_j5 stands on the bowl floor")
	var reached: Dictionary = grid.reach_from(start.position.x, start.position.z)
	for spawn_name: String in ["retry_phase1"]:
		var m: Marker3D = level.get_node("Spawns/" + spawn_name)
		assert_true(reached.has(grid.cell_of(m.position.x, m.position.z)), "%s is reachable from the gate" % spawn_name)
		assert_almost_eq(grid.height_at(m.position.x, m.position.z), 0.0, 0.05, "%s is on the floor" % spawn_name)
	assert_true(reached.has(grid.cell_of(0.0, 0.0)), "Red can walk up the ramp onto the plateau and to its centre")
	assert_almost_eq(grid.height_at(0.0, 0.0), PLATEAU_TOP, 0.05, "the plateau top is 3 m up")
	for tid: String in ["turret_k_nw", "turret_k_ne", "turret_k_e"]:
		var t: Node3D = level.get_node("Markers/" + tid)
		assert_true(grid.reaches(reached, t.position.x, t.position.z, PLATEAU_TOP, 3.0), "%s's pylon is within reach on the plateau" % tid)
	for hid: String in ["drone_hatch_a", "drone_hatch_b", "drone_hatch_c"]:
		var m: Node3D = level.get_node("Markers/" + hid)
		assert_true(reached.has(grid.cell_of(m.position.x, m.position.z)), "%s is on the walkable plateau" % hid)
	var terminal: Node3D = level.get_node("term_save_arena")
	assert_true(grid.reaches(reached, terminal.position.x, terminal.position.z, 0.0, 1.8), "the save terminal is reachable by the gate")
	var loader: Node3D = level.get_node("Markers/loader_parked")
	assert_true(grid.reaches(reached, loader.position.x, loader.position.z, 0.0, 3.0), "the parked loader's pad is reachable (she boards it from the plateau side)")


func test_the_ramp_climbs_three_metres_over_sixteen_and_the_plateau_is_clear() -> void:
	var level: Node3D = _level()
	var grid: Object = _grid(level)
	assert_almost_eq(grid.height_at(0.0, 36.5), 0.0, 0.2, "the ramp starts at the floor (z 36)")
	assert_almost_eq(grid.height_at(0.0, 20.5), PLATEAU_TOP, 0.25, "and meets the plateau at z 20")
	var previous: float = 0.0
	var z: float = 36.0
	while z >= 20.5:
		var y: float = grid.height_at(0.0, z)
		assert_le(y - previous, 0.2, "no step on the ramp at z %s" % z)
		previous = y
		z -= 0.5
	# no props inside the fight space: flat at plateau height out to the pylons and the rail (r 17.5)
	var bad: int = 0
	var dz: float = -17.5
	while dz <= 17.5:
		var dx: float = -17.5
		while dx <= 17.5:
			if dx * dx + dz * dz <= 17.5 * 17.5 and absf(grid.height_at(dx, dz) - PLATEAU_TOP) > 0.05:
				bad += 1
			dx += 0.5
		dz += 0.5
	assert_eq(bad, 0, "nothing stands on the plateau inside radius 17.5 m (the rings and the hatches are flat)")
	# the rail has the ramp's mouth open and is closed elsewhere
	assert_gt(grid.height_at(0.0, -19.7), PLATEAU_TOP + 0.5, "the rail stands at the north edge")
	assert_almost_eq(grid.height_at(0.0, 19.7), PLATEAU_TOP, 0.3, "and is open where the ramp comes up")


func test_every_turret_sees_the_plateau_centre() -> void:
	var level: Node3D = _level()
	var grid: Object = _grid(level)
	for tid: String in ["turret_k_nw", "turret_k_ne", "turret_k_e"]:
		var t: Node3D = level.get_node("Markers/" + tid)
		var dir: Vector2 = Vector2(-t.position.x, -t.position.z)
		var length: float = dir.length()
		assert_ge(length, 18.0, "%s is on the plateau's edge" % tid)
		assert_le(length, 22.0)
		dir = dir.normalized()
		var step: float = 2.5
		while step < length - 1.0:
			var h: float = grid.height_at(t.position.x + dir.x * step, t.position.z + dir.y * step)
			assert_le(h, PLATEAU_TOP + 0.05, "%s has a clear line to the centre (%s m out)" % [tid, step])
			step += 0.5


func test_the_stockade_has_two_gates_and_the_bowl_is_walled_in() -> void:
	var level: Node3D = _level()
	var big: Object = WalkGrid.new(level, 75.0, 75.0, -75.0, -75.0)
	# the south gate is open, the east gate is shut by the barricade, the rest of the ring is solid wall
	assert_gt(big.height_at(0.0, 62.0), -50.0, "floor in the south gate")
	assert_almost_eq(big.height_at(0.0, 62.0), 0.0, 0.05, "the south gate is open floor")
	assert_gt(big.height_at(62.0, 0.0), 2.0, "the east gate is shut by its barricade until the transition")
	var wall_cells: int = 0
	for deg: int in range(0, 360, 5):
		var a: float = deg_to_rad(float(deg))
		if absf(sin(a)) < 0.2 and cos(a) > 0.0:
			continue          # east gate
		if absf(cos(a)) < 0.2 and sin(a) > 0.0:
			continue          # south gate
		if big.height_at(62.0 * cos(a), 62.0 * sin(a)) > 4.0:
			wall_cells += 1
	assert_ge(wall_cells, 60, "the rest of the 62 m ring is an 8 m wall (%d of the sampled 5 degree steps)" % wall_cells)
	var rim: Object = WalkGrid.new(level, 175.0, 175.0, -175.0, -175.0)
	assert_gt(rim.height_at(161.0, 0.0), 10.0, "an invisible wall at r 161 keeps both robots in the bowl")
	assert_gt(rim.height_at(0.0, -161.0), 10.0)
	var heaps: Array[String] = ["Props/Heap_a", "Props/Heap_b", "Props/Heap_c"]
	for heap: String in heaps:
		assert_not_null(level.get_node_or_null(heap), "%s stands" % heap)
	assert_almost_eq((level.get_node("Props/Heap_b") as Node3D).position.z, -110.0, 0.1, "the junk mech's heap is at (0, -110)")
	assert_eq(level.get_node("Rim").get_child_count(), 36, "the rim cliffs ring the bowl")


# ---- the robot data ----

func test_the_colossus_stands_in_its_cradle_and_the_loader_is_parked() -> void:
	var data: Dictionary = DataDB.get_dict("slice/robot_rooms/kasp_arena")
	assert_false(data.is_empty(), "robot_rooms/kasp_arena.json exists")
	assert_eq(data.get("ground"), false, "the level supplies the floor")
	var loader: Array = (data["small_robot"] as Dictionary)["pos"]
	var colossus: Array = (data["huge_robot"] as Dictionary)["pos"]
	assert_almost_eq(float(loader[0]), 8.0, 0.01, "the loader is parked at (8, 56)")
	assert_almost_eq(float(loader[2]), 56.0, 0.01)
	assert_almost_eq(float(colossus[0]), 105.0, 0.01, "the colossus stands in its cradle at (105, 0), visible from the first frame (Ross 2026-10-09, A)")
	assert_almost_eq(float(colossus[2]), 0.0, 0.01)
	assert_almost_eq(float((data["huge_robot"] as Dictionary)["yaw_deg"]), -90.0, 0.01, "facing west, toward the plateau")
	var market: Dictionary = DataDB.get_dict("slice/market").get("switches", {}) as Dictionary
	assert_eq((market["colossus_in_phase_1"] as Dictionary)["value"], "visible")


func test_the_smashable_clutter_keeps_off_the_plateau_the_gates_the_heaps_and_the_cradle() -> void:
	var data: Dictionary = DataDB.get_dict("slice/robot_rooms/kasp_arena")
	var props: Array = data["props"] as Array
	assert_ge(float(props.size()), 30.0, "eight clusters of smashable containers, cars and crates")
	var kinds: Dictionary = DataDB.get_dict("combat/robot_yard").get("kinds", {}) as Dictionary
	for entry: Variant in props:
		var p: Dictionary = entry
		var pos: Array = p["pos"]
		var x: float = float(pos[0])
		var z: float = float(pos[2])
		assert_true(kinds.has(str(p["kind"])), "kind %s is a real robot-yard prop" % p["kind"])
		assert_gt(Vector2(x, z).length(), 80.0, "clutter stays outside the stockade (%s, %s)" % [x, z])
		assert_lt(Vector2(x, z).length(), 155.0, "and inside the bowl wall")
		assert_false(x > 70.0 and absf(z) < 50.0, "and off the cradle (%s, %s)" % [x, z])
		for heap: Array in [[-64.0, -95.0], [0.0, -110.0], [64.0, -95.0]]:
			assert_gt(Vector2(x - float(heap[0]), z - float(heap[1])).length(), 30.0, "and off the heaps (%s, %s)" % [x, z])


# ---- a real boot ----

func _start() -> void:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate() as Main
	_main.show_title = false
	_main.debug_overlay_enabled = false
	_main.sandbox_boot_enabled = false
	add_to_root(_main)
	_main.apply_mode(GameMode.Mode.SLICE)
	_router.set("main", _main)
	_router.set("instant", true)
	_main.start_new_game()
	for i: int in 240:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == "market_hideout" and room.hero != null and not bool(_router.call("is_busy")):
			return
	fail("never reached the hideout")


func _until_room(room_id: String, limit: int = 300) -> void:
	for i: int in limit:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return
	fail("never reached %s" % room_id)


func test_the_arena_boots_as_an_action_room_with_the_robot_stage_and_both_retry_spawns() -> void:
	await _start()
	_router.call("go_to", ROOM, "from_j5")
	await _until_room(ROOM)
	var room: ActionRoom = _main.get_room() as ActionRoom
	assert_true(room.is_combat())
	assert_not_null(room.get_lock_on(), "lock-on")
	assert_not_null(room.get_camera(), "the orbit camera")
	assert_not_null(room.get_robot_stage(), "the robot stage is built from kasp_arena.json")
	assert_lt(room.hero.global_position.distance_to(room.find_spawn("from_j5").global_position), 1.0, "Red arrives at the south gate")
	assert_not_null(room.find_spawn("retry_phase1"))
	assert_not_null(room.find_spawn("retry_phase2"))
	var yard: Object = room.get_robot_stage().get("yard")
	assert_not_null(yard, "the yard (loader, colossus, clutter) is built")
	var colossus: Variant = yard.get("huge")
	if colossus != null and colossus is Node3D:
		assert_almost_eq((colossus as Node3D).global_position.x, 105.0, 0.5, "the colossus stands in its cradle")
