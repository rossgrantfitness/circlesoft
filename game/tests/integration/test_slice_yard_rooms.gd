extends TestCase
## VS-20, the junkyard on foot (docs/maps/junkyard.md, scripts/tools/make_junkyard_rooms.py): J1 to J4 load, their spawns, doors, hack
## targets, pickups, encounter markers and save terminal are where the data says and can be reached by the walk check (steps up of 1.0 m
## or less, hops of 1.6 m), the fight spaces are open, doors connect to the market and to each other both ways, and a real slice Main
## boots each room as an ActionRoom with the orbit camera and combat on. The data checks run on the scenes without a tree.

const WalkGrid = preload("res://tests/integration/walk_grid_kit.gd")
const ROOMS_ID: String = "slice/rooms"
const PLACEMENTS_ID: String = "slice/placements"
const ENCOUNTERS_ID: String = "slice/encounters"
const YARD: Array[String] = ["junk_j1", "junk_j2", "junk_j3", "junk_j4"]
const SECTIONS: Array[String] = ["doors", "pickups", "crates", "npcs", "spots"]
const REACH_M: float = 1.8
## Where each room's main fight happens (centre) and how wide the open disc must be (radius).
const FIGHT_SPACE: Dictionary = {"junk_j1": Vector2(36.0, 22.0), "junk_j2": Vector2(66.0, 22.0), "junk_j3": Vector2(22.0, 40.0), "junk_j4": Vector2(40.0, 30.0)}
const FIGHT_RADIUS_M: float = 12.0
## Nodes whose own spot is not walkable (turret mounts on ledges and pedestals): the fixtures.
const SIZES: Dictionary = {"junk_j1": Vector2(64, 44), "junk_j2": Vector2(150, 40), "junk_j3": Vector2(100, 80), "junk_j4": Vector2(90, 60)}

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


# ---- helpers ----

func _rooms() -> Dictionary:
	return DataDB.get_dict(ROOMS_ID).get("rooms", {}) as Dictionary


func _section(name: String) -> Dictionary:
	return DataDB.get_dict(PLACEMENTS_ID).get(name, {}) as Dictionary


func _encounters() -> Dictionary:
	return DataDB.get_dict(ENCOUNTERS_ID).get("encounters", {}) as Dictionary


func _scene_of(room_id: String) -> Node3D:
	var packed: PackedScene = load(str(_rooms()[room_id]["scene"])) as PackedScene
	assert_not_null(packed, "%s scene loads" % room_id)
	var node: Node3D = packed.instantiate() as Node3D
	own(node)
	return node


func _markers(level: Node, holder: String) -> Dictionary:
	var out: Dictionary = {}
	var node: Node = level.get_node_or_null(holder)
	if node != null:
		for child: Node in node.get_children():
			out[str(child.name)] = child
	return out


## Every node of a level with a placement id: {node, id}.
func _placed(level: Node) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for node: Node in level.find_children("*", "Node3D", true, false):
		if "placement_id" in node and not str(node.get("placement_id")).is_empty():
			found.append({"node": node, "id": str(node.get("placement_id"))})
	return found


func _targets(level: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node: Node in level.find_children("*", "Node3D", true, false):
		if "target_id" in node and not str(node.get("target_id")).is_empty():
			found.append(node as Node3D)
	return found


func _world(node: Node3D, level: Node3D) -> Vector3:
	var result: Vector3 = node.position
	var at: Node = node.get_parent()
	while at != null and at != level:
		if at is Node3D:
			result = (at as Node3D).transform * result
		at = at.get_parent()
	return result


## The crane's bridge exists only at run time: the girder at the end of its first job (placements hack_targets crane_j3).
func _extra_for(room_id: String) -> Array:
	if room_id != "junk_j3":
		return []
	var job: Dictionary = ((_section("hack_targets")["crane_j3"] as Dictionary)["jobs"] as Array)[0]
	var path: Array = job["path"]
	var end: Array = path[path.size() - 1]
	var size: Array = (job["cargo"] as Dictionary)["size"]
	return [{"pos": Vector3(float(end[0]), float(end[1]), float(end[2])), "size": Vector3(float(size[0]), float(size[1]), float(size[2]))}]


func _grid(room_id: String, level: Node3D, with_extra: bool = true) -> Object:
	var size: Vector2 = SIZES[room_id]
	return WalkGrid.new(level, size.x + 12.0, size.y + 12.0, -12.0, -12.0, _extra_for(room_id) if with_extra else [])


# ---- the rooms file and the scenes ----

func test_the_four_yard_rooms_are_dungeon_rooms_with_scenes_and_spawns() -> void:
	for id: String in YARD:
		assert_true(_rooms().has(id), "%s is in slice/rooms.json" % id)
		var entry: Dictionary = _rooms()[id]
		assert_eq(entry.get("kind"), "dungeon")
		assert_eq(entry.get("camera"), "orbit", "%s uses the free orbit camera" % id)
		assert_true(bool(entry.get("combat", false)), "%s is a fighting room" % id)
		assert_true(bool(entry.get("checkpoint", false)), "%s is a checkpoint (a death restarts at its entrance)" % id)
		assert_eq(entry.get("form"), "red")
		assert_true(ResourceLoader.exists(str(entry["scene"])), "%s scene exists" % id)
		assert_has(entry["spawns"], entry["default_spawn"])
	assert_eq(_rooms()["junk_j4"].get("robots"), "junk_j4", "J4 builds its loader from the robot data")
	assert_true(bool(_rooms()["junk_j1"].get("autosave", false)), "J1 auto-saves on entry")


func test_each_scene_is_a_plain_level_with_matching_spawns() -> void:
	for id: String in YARD:
		var level: Node3D = _scene_of(id)
		assert_false(level is FieldRoom, "%s is a plain level (Main wraps it in an ActionRoom)" % id)
		assert_null(level.get_node_or_null("CameraRig"), "%s has no diorama rig (orbit camera)" % id)
		assert_not_null(level.get_node_or_null("WorldEnvironment"))
		assert_not_null(level.get_node_or_null("Collision"))
		var markers: Dictionary = _markers(level, "Spawns")
		var listed: Array = _rooms()[id]["spawns"]
		for spawn: String in listed:
			assert_true(markers.has(spawn), "%s has spawn %s" % [id, spawn])
		for spawn: String in markers:
			assert_has(listed, spawn, "%s marker %s is listed" % [id, spawn])


func test_every_placement_and_hack_target_has_a_node_and_the_reverse() -> void:
	var targets: Dictionary = _section("hack_targets")
	var seen_ids: Dictionary = {}
	var seen_targets: Dictionary = {}
	for id: String in YARD:
		var level: Node3D = _scene_of(id)
		for item: Dictionary in _placed(level):
			var pid: String = item["id"]
			var found: bool = false
			for name: String in SECTIONS:
				if _section(name).has(pid):
					found = true
					assert_eq((_section(name)[pid] as Dictionary).get("room"), id, "%s belongs to %s" % [pid, id])
			assert_true(found, "%s: node %s has a placements entry" % [id, pid])
			seen_ids[pid] = id
		for target: Node3D in _targets(level):
			var tid: String = str(target.get("target_id"))
			assert_true(targets.has(tid), "%s: hack target %s has a hack_targets entry" % [id, tid])
			if targets.has(tid):
				assert_eq((targets[tid] as Dictionary).get("room"), id, "%s lives in %s" % [tid, id])
			seen_targets[tid] = id
	for name: String in SECTIONS:
		for pid: String in _section(name):
			var room: String = str((_section(name)[pid] as Dictionary).get("room", ""))
			if YARD.has(room):
				assert_eq(seen_ids.get(pid, ""), room, "%s %s has a node in %s" % [name, pid, room])
	for tid: String in targets:
		if tid.begins_with("_"):
			continue
		var room: String = str((targets[tid] as Dictionary).get("room", ""))
		if YARD.has(room):
			assert_eq(seen_targets.get(tid, ""), room, "hack target %s has a node in %s" % [tid, room])


func test_the_hack_targets_are_of_the_right_kind() -> void:
	var kinds: Dictionary = {"hack_j1_door": "HackDoor", "term_j2_gate": "HackTerminal", "crane_j3": "HackCrane", "dline_j3": "DroneLine", "hack_j3_vault": "HackDoor", "loader_j4": "HackLoader"}
	for id: String in YARD:
		for target: Node3D in _targets(_scene_of(id)):
			var tid: String = str(target.get("target_id"))
			assert_true(kinds.has(tid), "%s is a known hack target" % tid)
			assert_eq(str(target.get_script().get_global_name()), kinds[tid], "%s uses the %s script" % [tid, kinds[tid]])


func test_the_fuse_doors_carry_their_slabs_and_the_gates_ask_for_their_flags() -> void:
	var targets: Dictionary = _section("hack_targets")
	for tid: String in ["hack_j1_door", "hack_j3_vault"]:
		assert_true((targets[tid] as Dictionary).has("slab"), "%s slides a slab" % tid)
	var doors: Dictionary = _section("doors")
	assert_eq(((doors["jk_j1_to_j2"] as Dictionary)["requires"] as Dictionary)["flag"], (targets["hack_j1_door"] as Dictionary)["flag"], "the J1 gate opens by the fuse box's flag")
	assert_eq(((doors["jk_j2_to_j3"] as Dictionary)["requires"] as Dictionary)["flag"], (targets["term_j2_gate"] as Dictionary)["flag"], "the J2 gate opens by the terminal's flag")
	var bridge: Dictionary = ((targets["crane_j3"] as Dictionary)["jobs"] as Array)[0]
	assert_eq(bridge["flag"], "hack_j3_bridge_placed")
	var end: Array = (bridge["path"] as Array)[(bridge["path"] as Array).size() - 1]
	var size: Array = (bridge["cargo"] as Dictionary)["size"]
	assert_lt(float(end[0]) - float(size[0]) * 0.5, 46.0, "the girder's west end rests on the west rim (pit x 46 to 55)")
	assert_gt(float(end[0]) + float(size[0]) * 0.5, 55.0, "and its east end on the east rim")


# ---- encounters ----

func test_every_encounter_has_its_markers_where_encounters_json_says() -> void:
	var checked: int = 0
	for id: String in YARD:
		var level: Node3D = _scene_of(id)
		var enc_nodes: Dictionary = _markers(level, "Encounters")
		var fixtures: Dictionary = _markers(level, "Fixtures")
		for eid: String in _encounters():
			var enc: Dictionary = _encounters()[eid]
			if enc.get("room") != id:
				continue
			checked += 1
			assert_true(enc_nodes.has(eid), "%s: Encounters/%s exists" % [id, eid])
			if not enc_nodes.has(eid):
				continue
			var node: Node3D = enc_nodes[eid]
			var count: int = 0
			for wave: Dictionary in enc.get("waves", []):
				for spawn: Dictionary in wave["spawn"]:
					count += 1
					var at: Array = spawn["at"]
					var marker: Node3D = null
					for child: Node in node.get_children():
						if child.name.begins_with("%s_%s_" % [wave["id"], spawn["enemy"]]) and str(child.get_meta("wave", "")) == wave["id"]:
							var w: Vector3 = _world(child as Node3D, level)
							if absf(w.x - float(at[0])) < 0.01 and absf(w.z - float(at[1])) < 0.01:
								marker = child as Node3D
					assert_not_null(marker, "%s: %s has a marker for %s at %s" % [id, eid, spawn["enemy"], str(at)])
			assert_eq(node.get_child_count(), count, "%s: %s has one marker per spawn entry" % [eid, eid])
			for fx: Dictionary in enc.get("fixtures", []):
				assert_true(fixtures.has(fx["id"]), "%s: fixture %s exists" % [id, fx["id"]])
				if fixtures.has(fx["id"]):
					var f: Node3D = fixtures[fx["id"]]
					assert_almost_eq(f.position.x, float((fx["at"] as Array)[0]), 0.01)
					assert_almost_eq(f.position.z, float((fx["at"] as Array)[1]), 0.01)
					assert_almost_eq(f.position.y, float(fx.get("up_m", 0.0)), 0.01, "%s sits %s m up" % [fx["id"], fx.get("up_m", 0.0)])
	assert_ge(float(checked), 5.0, "the five foot encounters (J1 pair, J2 chute and pit stop, J3 yard, J4 stand) are all checked")


func test_the_fight_spaces_are_open_floor() -> void:
	for id: String in YARD:
		var level: Node3D = _scene_of(id)
		var grid: Object = _grid(id, level)
		var centre: Vector2 = FIGHT_SPACE[id]
		var total: int = 0
		var free: int = 0
		var dz: float = -FIGHT_RADIUS_M
		while dz <= FIGHT_RADIUS_M:
			var dx: float = -FIGHT_RADIUS_M
			while dx <= FIGHT_RADIUS_M:
				if dx * dx + dz * dz <= FIGHT_RADIUS_M * FIGHT_RADIUS_M:
					total += 1
					var y: float = grid.height_at(centre.x + dx, centre.y + dz)
					if y > -50.0 and absf(y) < 0.1:
						free += 1
				dx += 0.5
			dz += 0.5
		assert_ge(float(free) / float(total), 0.85, "%s: the fight space (a 24 m circle at %s) is at least 85 percent open floor" % [id, str(centre)])


# ---- doors ----

func test_doors_lead_somewhere_and_come_back() -> void:
	var edges: Array[Dictionary] = []
	for id: String in YARD:
		for item: Dictionary in _placed(_scene_of(id)):
			if not item["node"] is Door:
				continue
			var door: Dictionary = _section("doors")[item["id"]]
			var to_room: String = str(door["to_room"])
			assert_true(_rooms().has(to_room), "%s leads to a room that exists (%s)" % [item["id"], to_room])
			if _rooms().has(to_room):
				assert_has(_rooms()[to_room]["spawns"], door["to_spawn"], "%s lands on a spawn that exists" % item["id"])
			edges.append({"id": item["id"], "from": id, "to": to_room})
	assert_eq(edges.size(), 7, "seven doors in J1 to J4")
	var gate_back: Dictionary = _section("doors")["mk_gt_to_junk"]
	assert_eq(gate_back["to_room"], "junk_j1", "Gate 4's barrier leads into J1 (and J1 is built now)")
	for edge: Dictionary in edges:
		var back: bool = false
		for other: Dictionary in edges:
			if other["from"] == edge["to"] and other["to"] == edge["from"]:
				back = true
		if edge["to"] == "market_gate":
			back = true          # the market's barrier door (mk_gt_to_junk) is the other half, checked above
		assert_true(back, "%s has a door back from %s" % [edge["id"], edge["to"]])


# ---- the walk check ----

func test_every_spawn_door_prop_and_target_is_reachable_on_foot() -> void:
	for id: String in YARD:
		var level: Node3D = _scene_of(id)
		var grid: Object = _grid(id, level)
		var markers: Dictionary = _markers(level, "Spawns")
		var start_name: String = str(_rooms()[id]["default_spawn"])
		var start: Marker3D = markers[start_name]
		var start_cell: Vector2i = grid.cell_of(start.position.x, start.position.z)
		assert_true(grid.standable(start_cell.x, start_cell.y), "%s: spawn %s is on solid ground" % [id, start_name])
		assert_le(absf(grid.h(start_cell.x, start_cell.y) - start.position.y), 0.6, "%s: spawn %s stands on the ground under it" % [id, start_name])
		var reached: Dictionary = grid.reach_from(start.position.x, start.position.z)
		for spawn_name: String in markers:
			var m: Marker3D = markers[spawn_name]
			assert_true(reached.has(grid.cell_of(m.position.x, m.position.z)), "%s: spawn %s is reachable from %s" % [id, spawn_name, start_name])
		for item: Dictionary in _placed(level):
			var node: Node3D = item["node"]
			var w: Vector3 = _world(node, level)
			assert_true(grid.reaches(reached, w.x, w.z, w.y, REACH_M), "%s: %s can be reached on foot" % [id, item["id"]])
			if not node is Door and not node is JobBoard:
				var cell: Vector2i = grid.cell_of(w.x, w.z)
				assert_le(grid.h(cell.x, cell.y), w.y + 0.6, "%s: %s is not buried in a wall or prop" % [id, item["id"]])
		for target: Node3D in _targets(level):
			var w: Vector3 = _world(target, level)
			var tid: String = str(target.get("target_id"))
			var radius: float = 12.0 if tid in ["dline_j3", "hack_j1_door"] else 4.0        # lock-on and zap reach: the hacks aim from a distance
			var stand_y: float = 0.0 if tid == "hack_j1_door" else w.y                        # the fuse box is 5 m up a pylon: Red zaps it from the floor
			assert_true(grid.reaches(reached, w.x, w.z, stand_y, radius), "%s: %s can be used from where Red stands" % [id, tid])
		var barks: Dictionary = _markers(level, "Barks")
		for bark: String in barks:
			var b: Node3D = barks[bark]
			assert_true(grid.reaches(reached, b.position.x, b.position.z, grid.height_at(b.position.x, b.position.z), float(b.get_meta("radius_m", 5.0))), "%s: Red can walk into the radius of %s" % [id, bark])
		var encs: Dictionary = _markers(level, "Encounters")
		for eid: String in encs:
			for child: Node in (encs[eid] as Node).get_children():
				var w: Vector3 = _world(child as Node3D, level)
				assert_true(grid.reaches(reached, w.x, w.z, 0.0, 1.5), "%s: the %s spawn %s stands on open ground" % [id, eid, child.name])


func test_the_crane_bridge_is_what_joins_the_two_halves_of_j3() -> void:
	var level: Node3D = _scene_of("junk_j3")
	var west: Marker3D = level.get_node("Spawns/from_j2")
	var east: Marker3D = level.get_node("Spawns/from_j4")
	var bare: Object = _grid("junk_j3", level, false)
	var reached: Dictionary = bare.reach_from(west.position.x, west.position.z)
	assert_false(reached.has(bare.cell_of(east.position.x, east.position.z)), "without the bridge the east half is out of reach (the pit is 9 m wide)")
	var bridged: Object = _grid("junk_j3", level, true)
	var with_bridge: Dictionary = bridged.reach_from(west.position.x, west.position.z)
	assert_true(with_bridge.has(bridged.cell_of(east.position.x, east.position.z)), "with the girder placed Red walks across")
	var terminal: Node3D = level.get_node("term_save_j3")
	assert_true(bridged.reaches(with_bridge, terminal.position.x, terminal.position.z, 0.0, REACH_M), "the save terminal is on the far side of the bridge")
	assert_false(bare.reaches(reached, terminal.position.x, terminal.position.z, 0.0, REACH_M), "and not reachable without it (the last save is earned)")


func test_the_turret_ledges_and_the_pit_stop_ramp() -> void:
	var level: Node3D = _scene_of("junk_j2")
	var grid: Object = _grid("junk_j2", level)
	var reached: Dictionary = grid.reach_from(2.0, 17.0)
	var t2: Node3D = level.get_node("Fixtures/turret_j2_b")
	assert_true(grid.reaches(reached, t2.position.x, t2.position.z, 4.0, 1.5), "Red can climb the scrap ramp to turret T2's ledge (4 m up)")
	var t1: Node3D = level.get_node("Fixtures/turret_j2_a")
	assert_false(grid.reaches(reached, t1.position.x, t1.position.z, 4.0, 1.5), "turret T1's ledge is out of reach (it is a gun to deal with, not a perch)")
	var gate: Node3D = level.get_node("term_j2_gate")
	assert_true(grid.reaches(reached, gate.position.x, gate.position.z, 4.0, 2.0), "the gate terminal on bay 3's high ground is reachable up the ramp")


func test_the_stand_shutters_are_open_and_the_loader_lane_reaches_the_wall() -> void:
	var level: Node3D = _scene_of("junk_j4")
	assert_not_null(level.get_node_or_null("Shutters/shutter_w"))
	assert_not_null(level.get_node_or_null("Shutters/shutter_e"))
	assert_gt(level.get_node("Shutters/shutter_w").position.y, 3.0, "the shutters start raised (open)")
	var grid: Object = _grid("junk_j4", level)
	var reached: Dictionary = grid.reach_from(2.0, 30.0)
	var wall: Node3D = level.get_node("Breakables/SmashWall")
	assert_true(grid.reaches(reached, wall.position.x - 3.0, wall.position.z, 0.0, 1.0), "Red can walk the whole way to the smash wall (86 m)")
	var loader: Node3D = level.get_node("loader_j4")
	assert_true(grid.reaches(reached, loader.position.x, loader.position.z, 0.0, 3.0), "and to the loader's cradle")
	var robots: Dictionary = DataDB.get_dict("slice/robot_rooms/junk_j4")
	var pos: Array = (robots["small_robot"] as Dictionary)["pos"]
	assert_true(grid.reaches(reached, float(pos[0]), float(pos[2]), 0.0, 6.0), "the loader in the robot data stands on the cradle platform")


func test_rooms_match_the_map_sizes() -> void:
	for id: String in YARD:
		var size: Vector2 = SIZES[id]
		var level: Node3D = _scene_of(id)
		var grid: Object = _grid(id, level)
		var reached: Dictionary = grid.reach_from((level.get_node("Spawns/%s" % str(_rooms()[id]["default_spawn"])) as Marker3D).position.x,
				(level.get_node("Spawns/%s" % str(_rooms()[id]["default_spawn"])) as Marker3D).position.z)
		var max_x: float = -1000.0
		for cell: Vector2i in reached:
			max_x = maxf(max_x, grid.cell_center(cell.x, cell.y).x)
		assert_ge(max_x, size.x - 6.0, "%s runs the map's length (%s m wide)" % [id, size.x])


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
	await _until_room("market_hideout")


func _until_room(room_id: String, limit: int = 240) -> void:
	for i: int in limit:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return
	fail("never reached %s" % room_id)


func test_every_yard_room_boots_as_an_action_room_with_the_orbit_camera() -> void:
	await _start()
	for id: String in YARD:
		_router.call("go_to", id, str(_rooms()[id]["default_spawn"]))
		await _until_room(id)
		var room: ActionRoom = _main.get_room() as ActionRoom
		assert_true(room is ActionRoom, "%s is an ActionRoom" % id)
		assert_true(room.is_combat(), "%s is a fighting room" % id)
		assert_not_null(room.get_lock_on(), "%s has lock-on" % id)
		assert_not_null(room.get_camera(), "%s has the orbit camera" % id)
		assert_null(room.camera_rig, "%s has no diorama rig" % id)
		var marker: Marker3D = room.find_spawn(str(_rooms()[id]["default_spawn"]))
		assert_lt(room.hero.global_position.distance_to(marker.global_position), 1.0, "%s: Red is on her spawn" % id)
		assert_false(room.hero.town_mode, "%s: attacks and hacks are on" % id)


func test_the_gate_barrier_leads_into_the_yard_and_back() -> void:
	await _start()
	_router.call("go_to", "market_gate", "from_square")
	await _until_room("market_gate")
	_state.call("set_flag", "job_main_taken", true)
	var barrier: Door = null
	for node: Node in (_main.get_room() as ActionRoom).find_children("*", "Node3D", true, false):
		if node is Door and (node as Door).placement_id == "mk_gt_to_junk":
			barrier = node as Door
	assert_not_null(barrier)
	assert_true(barrier.is_unlocked())
	WorldProgress.mark_opened(barrier.unlock_id())          # the first-time "stamp, stamp" message is a bubble the test does not click through
	barrier.use((_main.get_room() as ActionRoom).hero, (_main.get_room() as ActionRoom).interactor)
	await _until_room("junk_j1")
	var j1: ActionRoom = _main.get_room() as ActionRoom
	assert_lt(j1.hero.global_position.distance_to(j1.find_spawn("from_market").global_position), 1.0, "she arrives at J1's west end")
	var back: Door = null
	for node: Node in j1.find_children("*", "Node3D", true, false):
		if node is Door and (node as Door).placement_id == "jk_j1_to_market":
			back = node as Door
	assert_not_null(back)
	back.use(j1.hero, j1.interactor)
	await _until_room("market_gate")
	_state.call("set_flag", "job_main_taken", false)


func test_the_fuse_box_gate_is_shut_until_the_flag_is_set() -> void:
	await _start()
	_router.call("go_to", "junk_j1", "from_market")
	await _until_room("junk_j1")
	var room: ActionRoom = _main.get_room() as ActionRoom
	var gate: Door = null
	for node: Node in room.find_children("*", "Node3D", true, false):
		if node is Door and (node as Door).placement_id == "jk_j1_to_j2":
			gate = node as Door
	assert_not_null(gate)
	assert_false(gate.is_unlocked(), "the J1 gate is shut")
	_state.call("set_flag", "hack_j1_door_open", true)
	assert_true(gate.is_unlocked(), "and opens by the fuse box's flag")
	_state.call("set_flag", "hack_j1_door_open", false)
