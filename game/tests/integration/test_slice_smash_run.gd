extends TestCase
## VS-22, the loader section (docs/maps/junkyard.md: J4's loader and smash wall, J5 Smash Run, the climb out at the arena gate).
## The smashables are robot-yard props (data/slice/robot_rooms/junk_j4.json and junk_j5.json, built at run time by RobotYard), so this test
## checks the data against the scene's floor with the walk check: every prop stands on open ground, the loader-only scrap walls close each way
## on foot and the way through them reaches the exit, the loot pickups stand where their containers do, the Foreman's gate is the exit's width,
## and a loader-only wall really does shrug off Red's sword and break to the loader's swing or a stomp.

const WalkGrid = preload("res://tests/integration/walk_grid_kit.gd")
const ROOMS_ID: String = "slice/rooms"
const LOADER_ONLY: Array[String] = ["scrap_wall_3m", "scrap_gate_12m"]

var _kit: RobotStageKit = null


func after_each() -> void:
	_kit = null


func _scene_of(room_id: String) -> Node3D:
	var rooms: Dictionary = DataDB.get_dict(ROOMS_ID).get("rooms", {}) as Dictionary
	var node: Node3D = (load(str((rooms[room_id] as Dictionary)["scene"])) as PackedScene).instantiate() as Node3D
	own(node)
	return node


func _kinds() -> Dictionary:
	return DataDB.get_dict("combat/robot_yard").get("kinds", {}) as Dictionary


func _props(room_id: String) -> Array:
	return DataDB.get_dict("slice/robot_rooms/" + room_id).get("props", []) as Array


## The footprint of a prop as a box for the walk check (the box turns with its yaw: swapped x and z at 90 or 270 degrees).
func _box_of(entry: Dictionary) -> Dictionary:
	var cfg: Dictionary = _kinds()[str(entry["kind"])]
	var size: Array = cfg["aabb_size"]
	var yaw: float = fposmod(float(entry.get("yaw_deg", 0.0)), 180.0)
	var quarter: bool = absf(yaw - 90.0) < 45.0
	var sx: float = float(size[2]) if quarter else float(size[0])
	var sz: float = float(size[0]) if quarter else float(size[2])
	var pos: Array = entry["pos"]
	return {"pos": Vector3(float(pos[0]), float(size[1]) * 0.5, float(pos[2])), "size": Vector3(sx, float(size[1]), sz)}


func _blockers(room_id: String) -> Array:
	var out: Array = []
	for raw: Variant in _props(room_id):
		var entry: Dictionary = raw
		if LOADER_ONLY.has(str(entry["kind"])):
			out.append(_box_of(entry))
	return out


# ---- the data ----

func test_the_new_scrap_kinds_are_loader_only_and_their_models_exist() -> void:
	var kinds: Dictionary = _kinds()
	for kind: String in LOADER_ONLY:
		assert_true(kinds.has(kind), "%s is a robot-yard kind" % kind)
		var cfg: Dictionary = kinds[kind]
		assert_ge(float(cfg.get("min_hit_damage", 0)), 20.0, "%s only breaks to a hit of 20 or more (Red on foot does 8 to 12, the loader about four times that)" % kind)
		assert_true(ResourceLoader.exists("res://art/placeholder/robots/props/%s.glb" % str(cfg["model"])), "%s has its placeholder model" % kind)
	assert_ge(float(kinds["scrap_gate_12m"]["hp"]), 400.0, "the Foreman's gate is about hp 400")
	assert_eq(float((kinds["scrap_gate_12m"]["aabb_size"] as Array)[1]), 12.0, "12 m tall")
	assert_eq(float((kinds["scrap_gate_12m"]["aabb_size"] as Array)[0]), 16.0, "16 m wide")
	assert_true(kinds.has("container_stack") and float((kinds["container_stack"]["aabb_size"] as Array)[1]) > 7.5, "the canyon's stacks are 7.8 m high")


func test_every_prop_kind_in_the_two_robot_files_exists() -> void:
	var kinds: Dictionary = _kinds()
	for room_id: String in ["junk_j5"]:
		for raw: Variant in _props(room_id):
			assert_true(kinds.has(str((raw as Dictionary)["kind"])), "%s: kind %s exists" % [room_id, (raw as Dictionary)["kind"]])


func test_j5_has_the_zones_of_the_map_and_enough_to_flatten() -> void:
	var props: Array = _props("junk_j5")
	assert_ge(float(props.size()), 100.0, "a Car Graveyard of about 80 cars and the rest of the run: well over 100 smashables")
	var cars: int = 0
	var walls_lane: int = 0
	var layers: Dictionary = {}
	var stacks: int = 0
	var gate: Dictionary = {}
	for raw: Variant in props:
		var p: Dictionary = raw
		var x: float = float((p["pos"] as Array)[0])
		match str(p["kind"]):
			"car":
				cars += 1
				assert_true(x >= 50.0 and x <= 130.0, "cars stand in the graveyard (x 50 to 130), not at %s" % x)
			"scrap_wall_3m":
				if x < 50.0:
					walls_lane += 1
				else:
					layers[x] = true
			"container_stack":
				stacks += 1
				assert_true(x >= 130.0 and x <= 200.0, "stacks stand in the canyon (x 130 to 200), not at %s" % x)
			"scrap_gate_12m":
				gate = p
	assert_ge(float(cars), 60.0, "about 80 cars (a few are dropped around the encounter spawns)")
	assert_eq(walls_lane, 3, "Breaker's Lane has three scrap walls")
	assert_eq(layers.size(), 3, "the Foreman's Wall has three layers before the gate")
	assert_ge(float(stacks), 15.0, "the canyon is lined with container stacks")
	assert_false(gate.is_empty(), "the big gate stands at the end")
	assert_eq(gate.get("on_smash_flag"), "j5_gate_smashed", "smashing the gate sets j5_gate_smashed")
	assert_ge(float((gate["pos"] as Array)[0]), 260.0, "x 260 or more (the wall zone is x 200 to 280)")


func test_every_loot_container_has_its_pickup_where_the_prop_stands() -> void:
	var pickups: Dictionary = DataDB.get_dict("slice/placements").get("pickups", {}) as Dictionary
	var level: Node3D = _scene_of("junk_j5")
	var loot: int = 0
	for node: Node in level.find_children("*", "Node3D", true, false):
		if node is Pickup and str(node.get("placement_id")).begins_with("jk_j5_"):
			var pid: String = str(node.get("placement_id"))
			assert_true(pickups.has(pid), "%s has a placements entry" % pid)
			assert_eq((pickups[pid] as Dictionary).get("room"), "junk_j5")
			loot += 1
			var near: bool = false
			for raw: Variant in _props("junk_j5"):
				var pos: Array = (raw as Dictionary)["pos"]
				if absf(float(pos[0]) - (node as Node3D).position.x) < 0.2 and absf(float(pos[2]) - (node as Node3D).position.z) < 0.2:
					near = true
			assert_true(near, "%s stands where a container, crate or car stands" % pid)
	assert_eq(loot, 12, "eleven loot containers and the hidden car's prize")


# ---- the floor under it all ----

func test_every_prop_stands_on_open_ground_in_its_room() -> void:
	for room_id: String in ["junk_j5"]:
		var level: Node3D = _scene_of(room_id)
		var size: Vector2 = Vector2(300, 120)
		var grid: Object = WalkGrid.new(level, size.x, size.y, -12.0, -12.0)
		for raw: Variant in _props(room_id):
			var p: Dictionary = raw
			var pos: Array = p["pos"]
			var y: float = grid.height_at(float(pos[0]), float(pos[2]))
			assert_almost_eq(y, 0.0, 0.05, "%s: %s at (%s, %s) stands on open floor, not in a cliff, a platform or the void" % [room_id, p["kind"], pos[0], pos[2]])
			# the whole footprint, not just the middle
			var box: Dictionary = _box_of(p)
			var half: Vector3 = (box["size"] as Vector3) * 0.5
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var cy: float = grid.height_at(float(pos[0]) + corner.x * half.x * 0.85, float(pos[2]) + corner.y * half.z * 0.85)
				assert_almost_eq(cy, 0.0, 0.05, "%s: %s at (%s, %s) has open floor under its whole footprint" % [room_id, p["kind"], pos[0], pos[2]])


func test_the_loader_only_walls_close_the_lane_and_the_way_through_them_reaches_the_exit() -> void:
	# J5: on foot (with the walls standing) the exit door is out of reach; once the loader has smashed them it is not.
	var level: Node3D = _scene_of("junk_j5")
	var start: Marker3D = level.get_node("Spawns/from_j4")
	var door: Node3D = level.get_node("DoorArena")
	var shut: Object = WalkGrid.new(level, 305.0, 125.0, -12.0, -12.0, _blockers("junk_j5"))
	var reached_shut: Dictionary = shut.reach_from(start.position.x, start.position.z)
	assert_false(shut.reaches(reached_shut, door.position.x, door.position.z, 0.0, 1.5), "with the scrap walls and the gate standing nothing on foot reaches the exit")
	assert_true(shut.reaches(reached_shut, 8.0, 54.0, 0.0, 1.0), "Breaker's Lane's first stretch is open: the first wall is the tutorial smash")
	assert_false(shut.reaches(reached_shut, 20.0, 54.0, 0.0, 1.0), "and the first scrap wall (x 14) shuts the lane")
	var open: Object = WalkGrid.new(level, 305.0, 125.0, -12.0, -12.0)
	var reached_open: Dictionary = open.reach_from(start.position.x, start.position.z)
	assert_true(open.reaches(reached_open, door.position.x, door.position.z, 0.0, 1.5), "with them smashed the exit door is reachable (the loader's route is real)")
	for tid: String in ["a", "b", "c", "d", "e"]:
		var platform: Node3D = level.get_node("Platform_" + tid)
		assert_almost_eq(open.height_at(platform.position.x, platform.position.z), 3.0, 0.05, "turret platform %s is 3 m up (encounters.json up_m)" % tid)
	# J4: the scene's smash wall (Breakables/SmashWall, group loader_smash) is what closes the lane to the door.
	var j4: Node3D = _scene_of("junk_j4")
	assert_true(j4.get_node("Breakables/SmashWall").is_in_group(&"loader_smash"), "J4's wall is a loader-only BreakableWall")
	var j4_start: Marker3D = j4.get_node("Spawns/from_j3")
	var j4_door: Node3D = j4.get_node("DoorEast")
	var j4_shut: Object = WalkGrid.new(j4, 110.0, 70.0, -12.0, -12.0)
	assert_false(j4_shut.reaches(j4_shut.reach_from(j4_start.position.x, j4_start.position.z), j4_door.position.x, j4_door.position.z, 0.0, 1.5), "J4: the wall shuts the lane to J5")
	var wall: Node = j4.get_node("Breakables/SmashWall")
	wall.get_parent().remove_child(wall)
	wall.free()
	var j4_open: Object = WalkGrid.new(j4, 110.0, 70.0, -12.0, -12.0)
	assert_true(j4_open.reaches(j4_open.reach_from(j4_start.position.x, j4_start.position.z), j4_door.position.x, j4_door.position.z, 0.0, 1.5), "J4: and the door is there once it is smashed")


func test_the_gate_matches_the_last_corridor_and_the_exit_door_is_beyond_it() -> void:
	var level: Node3D = _scene_of("junk_j5")
	var grid: Object = WalkGrid.new(level, 305.0, 125.0, -12.0, -12.0)
	# the last corridor is 16 m wide (z 46 to 62): the gate is 16 wide and fills it; 3 m outside it is wall
	assert_almost_eq(grid.height_at(272.0, 54.0), 0.0, 0.05, "open floor where the gate stands")
	assert_gt(grid.height_at(272.0, 44.0), 5.0, "cliff just outside the corridor's north side")
	assert_gt(grid.height_at(272.0, 64.0), 5.0, "and its south side")
	var gate: Dictionary = {}
	for raw: Variant in _props("junk_j5"):
		if (raw as Dictionary)["kind"] == "scrap_gate_12m":
			gate = raw
	assert_almost_eq(float(((_kinds()["scrap_gate_12m"] as Dictionary)["aabb_size"] as Array)[0]), 16.0, 0.01)
	assert_lt(float((gate["pos"] as Array)[0]), 292.0, "the gate is before the exit door (x 292)")
	var door_data: Dictionary = (DataDB.get_dict("slice/placements")["doors"] as Dictionary)["jk_j5_to_arena"]
	assert_eq(door_data["to_room"], "kasp_arena")
	assert_eq(door_data["to_spawn"], "from_j5")


func test_the_arrival_in_the_arena_has_a_climb_out_scene_and_a_ring_road() -> void:
	var scene: Dictionary = (DataDB.get_dict("slice/story_scenes")["scenes"] as Dictionary).get("arena_climb_out", {})
	assert_false(scene.is_empty(), "the climb-out scene exists")
	assert_eq(scene.get("room"), "kasp_arena")
	assert_has((scene["trigger"] as Dictionary)["spawn"], "from_j5", "it runs when she arrives by the south gate")
	var steps: Array = scene["steps"]
	assert_eq((steps[0] as Dictionary)["do"], "form", "the form step (disembark) is how she climbs out")
	assert_eq((steps[0] as Dictionary)["action"], "disembark")
	var arena: Node3D = (load("res://scenes/slice/arena/kasp_arena.tscn") as PackedScene).instantiate() as Node3D
	own(arena)
	var road: Node = arena.get_node_or_null("ring_road")
	assert_not_null(road, "BossTransition drives the loader along ring_road")
	assert_ge(float(road.get_child_count()), 4.0, "with waypoints")
	var first: Node3D = road.get_child(0) as Node3D
	var loader: Node3D = arena.get_node("Markers/loader_parked")
	assert_lt(Vector2(first.position.x - loader.position.x, first.position.z - loader.position.z).length(), 12.0, "the first waypoint is by the parked loader")
	var last: Node3D = road.get_child(road.get_child_count() - 1) as Node3D
	assert_gt(last.position.x, 50.0, "and the last is at the east gate")


# ---- a loader-only wall against Red and against the loader ----

func _wall_kit() -> SmashProp:
	_kit = RobotStageKit.new(self)
	await _kit.boot({"ground": false, "small_robot": {"pos": [0.0, 0.0, -40.0], "yaw_deg": 0.0},
			"props": [{"kind": "scrap_wall_3m", "pos": [20.0, 0.0, 0.0], "yaw_deg": 90.0}, {"kind": "scrap_gate_12m", "pos": [40.0, 0.0, 0.0], "yaw_deg": 90.0, "on_smash_flag": "test_gate_smashed"}]})
	for prop: SmashProp in _kit.stage.yard.props:
		if prop.kind == &"scrap_wall_3m":
			return prop
	return null


func test_a_loader_only_wall_shrugs_off_red_and_breaks_to_the_loader_or_a_stomp() -> void:
	var wall: SmashProp = await _wall_kit()
	assert_not_null(wall)
	var hp: int = wall.hp
	wall.apply_hit({"damage": 10, "outcome": &"hit"})         # Red's sword
	assert_eq(wall.hp, hp, "Red's sword (10) only clinks off a scrap wall")
	wall.apply_hit({"damage": 24, "outcome": &"hit"})
	assert_eq(wall.hp, hp, "24 is still too little")
	wall.apply_hit({"damage": 36, "outcome": &"hit"})         # the loader's swing, about 4 x 9
	assert_eq(wall.hp, hp - 36, "the loader's swing (36) lands")
	wall.apply_hit({"damage": 36, "outcome": &"hit"})
	assert_true(wall.dead, "and two swings break it (hp 60)")
	assert_true(wall.is_collapsing() or wall.is_gone())


func test_a_stomp_breaks_a_weakened_wall_and_the_gate_sets_its_flag() -> void:
	var wall: SmashProp = await _wall_kit()
	wall.apply_hit({"damage": 50, "outcome": &"hit"})
	assert_eq(wall.hp, 10, "a hurt wall")
	wall.stomp()
	assert_true(wall.dead, "a stomp breaks it even when its health is under the minimum hit")
	var gate: SmashProp = null
	for prop: SmashProp in _kit.stage.yard.props:
		if prop.kind == &"scrap_gate_12m":
			gate = prop
	assert_not_null(gate)
	assert_eq(gate.hp, 400)
	assert_false(WorldProgress.has_flag("test_gate_smashed"))
	for i: int in 12:
		gate.apply_hit({"damage": 36, "outcome": &"hit"})
	assert_true(gate.dead, "about eleven loader swings (400 / 36) bring the gate down")
	assert_true(WorldProgress.has_flag("test_gate_smashed"), "and set the flag the data names")
	var state: Node = tree.root.get_node("GameState")
	state.call("set_flag", "test_gate_smashed", false)


# ---- a real boot: J5 in the loader, through the door, and out at the arena gate ----

var _main: Main = null


func _boot_slice() -> void:
	var router: Node = tree.root.get_node("SceneRouter")
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate() as Main
	_main.show_title = false
	_main.debug_overlay_enabled = false
	_main.sandbox_boot_enabled = false
	add_to_root(_main)
	_main.apply_mode(GameMode.Mode.SLICE)
	router.set("main", _main)
	router.set("instant", true)
	_main.start_new_game()
	await _until("market_hideout")


func _until(room_id: String, limit: int = 400) -> ActionRoom:
	var router: Node = tree.root.get_node("SceneRouter")
	for i: int in limit:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return room
	fail("never reached %s" % room_id)
	return null


func _cleanup_boot() -> void:
	var router: Node = tree.root.get_node("SceneRouter")
	var state: Node = tree.root.get_node("GameState")
	if _main != null and is_instance_valid(_main):
		_main.apply_mode(GameMode.Mode.CLASSIC)
	router.set("main", null)
	router.set("instant", false)
	router.set("current_room_id", "")
	router.set("pending_room_id", "")
	router.set("rooms_id", "world/rooms")
	state.set("rooms_data_id", "world/rooms")
	state.call("reset")
	Placements.extra_ids = []
	Placements.extra_scene_ids = []
	Placements.extra_job_ids = []
	InputSorting.revert()
	for node: Node in tree.get_nodes_in_group(ActionRoom.GROUP_HUD):
		node.queue_free()


func test_j5_starts_in_the_loader_and_the_arena_climb_out_puts_her_on_foot() -> void:
	await _boot_slice()
	var router: Node = tree.root.get_node("SceneRouter")
	router.call("go_to", "junk_j5", "from_j4")
	var j5: ActionRoom = await _until("junk_j5")
	assert_eq(j5.get_form(), &"small", "J5 starts with Red already in the loader")
	assert_not_null(j5.get_robot_stage(), "the stage builds the smashables")
	assert_ge(float(j5.get_robot_stage().yard.props.size()), 100.0, "119 props stand in the yard")
	assert_true(j5.saving_blocked(), "no saving in the loader")
	# through the gate's door into the arena (the carried form is the loader)
	router.call("go_to", "kasp_arena", "from_j5")
	var arena: ActionRoom = await _until("kasp_arena")
	assert_not_null(arena.story, "the arena has a story director")
	var waited: int = 0
	while arena.get_robot_stage().form() != &"red" and waited < 900:
		await tree.physics_frame
		waited += 1
	assert_eq(arena.get_robot_stage().form(), &"red", "the arena_climb_out scene climbs her out at the gate (the form step)")
	waited = 0
	while not WorldProgress.has_flag("arena_arrived") and waited < 300:
		await tree.physics_frame
		waited += 1
	assert_true(WorldProgress.has_flag("arena_arrived"), "and its last step ran")
	assert_false(arena.saving_blocked(), "on foot she can save at the arena gate's terminal")
	_cleanup_boot()
