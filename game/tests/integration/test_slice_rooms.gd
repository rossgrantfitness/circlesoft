extends TestCase
## VS-14, the night market graybox (docs/maps/night_market.md, scripts/tools/make_market_rooms.py). Every market room
## loads, its spawns are reachable from the New Game start by a walk check (steps of 1.0 m or less, hops within Red's
## 1.6 m jump), its doors connect both ways (or lead to a room still listed under pending_rooms), every placement id has a
## node and every node has a placement, and a real slice Main boots each room as an ActionRoom in town mode (diorama camera,
## no fighting, Red on the spawn). The data checks run on the scenes without a tree; the boot checks use Main like
## test_action_room.gd.

const ROOMS_ID: String = "slice/rooms"
const PLACEMENTS_ID: String = "slice/placements"
const MARKET_PREFIX: String = "market_"
const START_ROOM: String = "market_hideout"
const START_SPAWN: String = "start"
const GRID: float = 0.25
const STEP_UP_M: float = 1.0           # Red steps up this much with no jump
const JUMP_M: float = 1.6              # and jumps this high
const JUMP_REACH_M: float = 1.0        # across a gap this wide
const DROP_M: float = 2.0
const BLOCKED_M: float = 2.0           # a cell taller than this is a wall
const REACH_M: float = 1.8             # how close a reachable cell must be to a prop to use it
const NODE_SECTIONS: Array[String] = ["doors", "pickups", "crates", "npcs", "spots"]

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


# ---- helpers: the data ----

func _rooms_doc() -> Dictionary:
	return DataDB.get_dict(ROOMS_ID)


func _rooms() -> Dictionary:
	return _rooms_doc().get("rooms", {}) as Dictionary


func _market_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _rooms():
		if id.begins_with(MARKET_PREFIX):
			ids.append(id)
	ids.sort()
	return ids


func _placements() -> Dictionary:
	return DataDB.get_dict(PLACEMENTS_ID)


func _section(name: String) -> Dictionary:
	return _placements().get(name, {}) as Dictionary


func _pending() -> Dictionary:
	return _rooms_doc().get("pending_rooms", {}) as Dictionary


func _scene_of(room_id: String) -> Node3D:
	var packed: PackedScene = load(str(_rooms()[room_id]["scene"])) as PackedScene
	assert_not_null(packed, "%s scene loads" % room_id)
	var node: Node3D = packed.instantiate() as Node3D
	own(node)
	return node


## Every node of a level scene that carries a placement id: {node, id}.
func _placed(level: Node) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for node: Node in level.find_children("*", "Node3D", true, false):
		if "placement_id" in node and not str(node.get("placement_id")).is_empty():
			found.append({"node": node, "id": str(node.get("placement_id"))})
	return found


func _spawn_markers(level: Node) -> Dictionary:
	var out: Dictionary = {}
	var holder: Node = level.get_node_or_null("Spawns")
	if holder != null:
		for child: Node in holder.get_children():
			if child is Marker3D:
				out[str(child.name)] = child
	return out


func _section_of(node: Node, id: String) -> String:
	if node is Door:
		return "doors"
	if node is Pickup:
		return "pickups"
	if node is Crate:
		return "crates"
	if node is PlacedNpc:
		return "npcs"
	if node is JobBoard or node is SceneSpot:
		return "spots"
	for name: String in NODE_SECTIONS:
		if _section(name).has(id):
			return name
	return ""


# ---- the rooms file ----

func test_the_market_has_nine_town_rooms_with_scenes_and_spawns() -> void:
	var ids: Array[String] = _market_ids()
	assert_eq(ids.size(), 9, "nine market rooms (docs/maps/night_market.md)")
	for expected: String in ["market_square", "market_wharf", "market_gate", "market_hideout", "market_dispatch", "market_corner", "market_forge", "market_repair", "market_arcade"]:
		assert_has(ids, expected)
	for id: String in ids:
		var entry: Dictionary = _rooms()[id]
		assert_eq(entry.get("kind"), "town", "%s is a town room" % id)
		assert_eq(entry.get("camera"), "diorama", "%s uses the diorama camera" % id)
		assert_false(bool(entry.get("combat", true)), "%s has no fighting" % id)
		assert_eq(entry.get("form"), "red", "%s: Red walks in as Red" % id)
		assert_false(str(entry.get("look_profile", "")).is_empty(), "%s names a look profile" % id)
		assert_true(ResourceLoader.exists(str(entry["scene"])), "%s scene exists" % id)
		assert_has(entry["spawns"], entry["default_spawn"], "%s default spawn is listed" % id)


func test_new_game_starts_in_the_hideout_and_it_autosaves() -> void:
	assert_eq(_rooms_doc().get("start_room"), START_ROOM)
	assert_has(_rooms()[START_ROOM]["spawns"], START_SPAWN)
	assert_eq(_rooms()[START_ROOM]["default_spawn"], START_SPAWN)
	assert_true(bool(_rooms()[START_ROOM].get("autosave", false)), "the hideout auto-saves on entry")


# ---- every scene ----

func test_each_scene_loads_and_its_spawns_match_the_rooms_file() -> void:
	for id: String in _market_ids():
		var level: Node3D = _scene_of(id)
		assert_not_null(level, id)
		assert_false(level is FieldRoom, "%s is a plain level (Main wraps it in an ActionRoom)" % id)
		assert_not_null(level.get_node_or_null("CameraRig"), "%s has the diorama camera rig" % id)
		assert_not_null(level.get_node_or_null("CameraBounds"), "%s has camera bounds" % id)
		assert_not_null(level.get_node_or_null("WorldEnvironment"), "%s has an environment" % id)
		assert_not_null(level.get_node_or_null("Collision"), "%s has collision" % id)
		var markers: Dictionary = _spawn_markers(level)
		var listed: Array = _rooms()[id]["spawns"]
		for spawn: String in listed:
			assert_true(markers.has(spawn), "%s has spawn marker %s" % [id, spawn])
		for spawn: String in markers:
			assert_has(listed, spawn, "%s marker %s is listed in rooms.json" % [id, spawn])


func test_every_placement_id_matches_a_node_and_the_reverse() -> void:
	var seen: Dictionary = {}
	for id: String in _market_ids():
		var level: Node3D = _scene_of(id)
		for item: Dictionary in _placed(level):
			var pid: String = item["id"]
			var section: String = _section_of(item["node"], pid)
			assert_ne(section, "", "%s: node %s has a known kind" % [id, pid])
			var entry: Dictionary = _section(section).get(pid, {}) as Dictionary
			if not entry.is_empty():
				assert_eq(entry.get("room"), id, "%s: placement %s belongs to this room" % [id, pid])
			else:
				fail("%s: node %s has no entry in slice/placements.json %s" % [id, pid, section])
			assert_false(seen.has(pid), "placement id %s used once" % pid)
			seen[pid] = id
	for name: String in NODE_SECTIONS:
		for pid: String in _section(name):
			var room: String = str((_section(name)[pid] as Dictionary).get("room", ""))
			if room.begins_with(MARKET_PREFIX):
				assert_eq(seen.get(pid, ""), room, "%s %s has a node in %s" % [name, pid, room])


func test_placements_point_at_words_scenes_items_and_shops_that_exist() -> void:
	var runner: DialogueRunner = DialogueRunner.new()
	runner.index_from_data()
	var scenes: Dictionary = DataDB.get_dict("slice/story_scenes").get("scenes", {}) as Dictionary
	var items: Array[String] = []
	for row: Variant in DataDB.get_value("items/items", "items", []) as Array:
		items.append(str((row as Dictionary).get("id", "")))
	for row: Variant in DataDB.get_value("items/equipment", "equipment", []) as Array:
		items.append(str((row as Dictionary).get("id", "")))
	for section_name: String in ["npcs", "spots"]:
		for pid: String in _section(section_name):
			var entry: Dictionary = _section(section_name)[pid]
			for variant: Variant in entry.get("variants", []) as Array:
				var v: Dictionary = variant
				if v.has("conversation"):
					assert_true(runner.has_conversation(str(v["conversation"])), "%s: conversation %s exists" % [pid, v["conversation"]])
				if v.has("scene"):
					assert_true(scenes.has(str(v["scene"])), "%s: story scene %s exists in slice/story_scenes.json" % [pid, v["scene"]])
	for scene_id: String in scenes:
		for step: Variant in (scenes[scene_id] as Dictionary).get("steps", []) as Array:
			var s: Dictionary = step
			if s.get("do") == "say":
				assert_true(runner.has_conversation(str(s["conversation"])), "scene %s says %s" % [scene_id, s["conversation"]])
	for section_name: String in ["pickups", "crates"]:
		for pid: String in _section(section_name):
			var entry: Dictionary = _section(section_name)[pid]
			var wanted: Array = [entry.get("item", "")] if entry.has("item") else []
			for row: Variant in entry.get("items", []) as Array:
				wanted.append((row as Dictionary).get("item", ""))
			for item_id: Variant in wanted:
				assert_has(items, str(item_id), "%s gives a real item (%s)" % [pid, item_id])
	for level_id: String in ["market_corner", "market_forge"]:
		var counter: Node = _scene_of(level_id).get_node_or_null("ShopCounter")
		assert_not_null(counter, "%s has its shop counter" % level_id)
		var shop_id: String = str(counter.get("shop_id"))
		var stock: Array = DataDB.get_value("shops/" + shop_id, "stock", []) as Array
		assert_false(stock.is_empty(), "%s: shop %s has stock" % [level_id, shop_id])
		for item_id: Variant in stock:
			assert_has(items, str(item_id), "%s sells a real item" % shop_id)
	var jobs: Dictionary = DataDB.get_dict("slice/jobs").get("jobs", {}) as Dictionary
	assert_false(jobs.is_empty(), "the job board has jobs")
	var board_ids: Array[String] = []
	for item: Dictionary in _placed(_scene_of("market_dispatch")):
		if item["node"] is JobBoard:
			board_ids.append(item["id"])
	assert_eq(board_ids.size(), 1, "one job board, in the Dispatch Counter")
	for job_id: String in jobs:
		assert_eq((jobs[job_id] as Dictionary).get("board"), board_ids[0], "%s is on the board" % job_id)


# ---- doors connect ----

func test_every_door_leads_somewhere_and_comes_back() -> void:
	var door_count: int = 0
	var edges: Array[Dictionary] = []
	for id: String in _market_ids():
		for item: Dictionary in _placed(_scene_of(id)):
			if not item["node"] is Door:
				continue
			door_count += 1
			var door: Dictionary = _section("doors").get(item["id"], {})
			var to_room: String = str(door.get("to_room", ""))
			var to_spawn: String = str(door.get("to_spawn", ""))
			assert_eq(door.get("room"), id, "%s belongs to %s" % [item["id"], id])
			if _rooms().has(to_room):
				assert_has(_rooms()[to_room]["spawns"], to_spawn, "%s lands on a spawn that exists" % item["id"])
			else:
				assert_true(_pending().has(to_room), "%s leads to %s, which exists or is listed in pending_rooms" % [item["id"], to_room])
				assert_has(_pending().get(to_room, []), to_spawn, "%s: pending room %s lists spawn %s" % [item["id"], to_room, to_spawn])
			edges.append({"id": item["id"], "from": id, "to": to_room, "spawn": to_spawn})
	assert_eq(door_count, 19, "19 doors in nine rooms")
	for edge: Dictionary in edges:
		if not _rooms().has(edge["to"]):
			continue
		var back: bool = false
		for other: Dictionary in edges:
			if other["from"] == edge["to"] and other["to"] == edge["from"]:
				back = true
		assert_true(back, "%s: %s has a door back to %s" % [edge["id"], edge["to"], edge["from"]])


func test_the_hatch_connects_the_hideout_and_the_repair_shop_both_ways() -> void:
	var down: Dictionary = _section("doors")["mk_hd_hatch"]
	var up: Dictionary = _section("doors")["mk_rp_hatch"]
	assert_eq(down["to_room"], "market_repair")
	assert_eq(down["to_spawn"], "from_hideout", "the hatch down lands at market_repair:from_hideout")
	assert_eq(up["to_room"], "market_hideout")
	assert_eq(up["to_spawn"], "from_repair", "the ladder up lands at market_hideout:from_repair")
	assert_has(_rooms()["market_repair"]["spawns"], "from_hideout")
	assert_has(_rooms()["market_hideout"]["spawns"], "from_repair")


func test_the_boom_barrier_is_locked_until_the_main_job_is_taken() -> void:
	var door_data: Dictionary = _section("doors")["mk_gt_to_junk"]
	assert_eq(door_data["to_room"], "junk_j1")
	assert_eq((door_data["requires"] as Dictionary).get("flag"), "job_main_taken")
	assert_false(str(door_data.get("locked_message", "")).is_empty(), "the lock says why")
	assert_eq(door_data.get("room"), "market_gate")
	for pid: String in _section("doors"):
		if pid != "mk_gt_to_junk":
			assert_false((_section("doors")[pid] as Dictionary).has("requires"), "%s is open from the start" % pid)
	var jobs: Dictionary = DataDB.get_dict("slice/jobs").get("jobs", {}) as Dictionary
	var main_job: Dictionary = {}
	for job_id: String in jobs:
		if (jobs[job_id] as Dictionary).get("taken_flag") == "job_main_taken":
			main_job = jobs[job_id]
	assert_false(main_job.is_empty(), "a job sets job_main_taken")
	assert_has((main_job["take"] as Dictionary)["set_flags"], "job_main_taken")
	assert_eq(((main_job["take"] as Dictionary)["give_items"] as Array)[0]["item"], "courier_pass")


# ---- the walk check ----

## One level scene as a height grid: every box in the Collision body, rasterised; then breadth-first from a spawn with
## steps up of 1.0 m or less, drops of 2.0 m or less, and jumps of 1.6 m across gaps of up to 1.0 m.
class WalkGrid extends RefCounted:
	var x0: float = -1.0
	var z0: float = -1.0
	var nx: int = 0
	var nz: int = 0
	var height: PackedFloat32Array = PackedFloat32Array()    # -99 = void

	func _init(level: Node3D, max_x: float, max_z: float) -> void:
		nx = int(ceil((max_x - x0) / GRID))
		nz = int(ceil((max_z - z0) / GRID))
		height.resize(nx * nz)
		height.fill(-99.0)
		var body: Node = level.get_node("Collision")
		for child: Node in body.get_children():
			var shape_node: CollisionShape3D = child as CollisionShape3D
			if shape_node == null or not shape_node.shape is BoxShape3D:
				continue
			var size: Vector3 = (shape_node.shape as BoxShape3D).size
			var box: AABB = shape_node.transform * AABB(-size * 0.5, size)
			var top: float = box.position.y + box.size.y
			for iz: int in nz:
				for ix: int in nx:
					var c: Vector2 = cell_center(ix, iz)
					if c.x >= box.position.x and c.x <= box.position.x + box.size.x and c.y >= box.position.z and c.y <= box.position.z + box.size.z:
						height[iz * nx + ix] = maxf(height[iz * nx + ix], top)

	func cell_center(ix: int, iz: int) -> Vector2:
		return Vector2(x0 + (ix + 0.5) * GRID, z0 + (iz + 0.5) * GRID)

	func cell_of(x: float, z: float) -> Vector2i:
		return Vector2i(clampi(int(floor((x - x0) / GRID)), 0, nx - 1), clampi(int(floor((z - z0) / GRID)), 0, nz - 1))

	func h(ix: int, iz: int) -> float:
		if ix < 0 or iz < 0 or ix >= nx or iz >= nz:
			return -99.0
		return height[iz * nx + ix]

	func standable(ix: int, iz: int) -> bool:
		var v: float = h(ix, iz)
		return v > -50.0 and v <= BLOCKED_M

	## All cells Red can reach from (x, z): Vector2i -> true.
	func reach_from(x: float, z: float) -> Dictionary:
		var start: Vector2i = cell_of(x, z)
		var seen: Dictionary = {start: true}
		var queue: Array[Vector2i] = [start]
		var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		var jump_dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
		var jump_cells: int = int(JUMP_REACH_M / GRID)
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			var here: float = h(at.x, at.y)
			for d: Vector2i in dirs:
				var next: Vector2i = at + d
				if seen.has(next) or not standable(next.x, next.y):
					continue
				var rise: float = h(next.x, next.y) - here
				if rise <= STEP_UP_M and rise >= -DROP_M:
					seen[next] = true
					queue.append(next)
			for d: Vector2i in jump_dirs:
				for k: int in range(2, jump_cells + 1):
					var next: Vector2i = at + d * k
					if seen.has(next) or not standable(next.x, next.y):
						continue
					var rise: float = h(next.x, next.y) - here
					if rise > JUMP_M or rise < -DROP_M:
						continue
					var clear: bool = true
					for j: int in range(1, k):
						var mid: Vector2i = at + d * j
						if h(mid.x, mid.y) > maxf(here, h(next.x, next.y)) + 0.4:
							clear = false
					if clear:
						seen[next] = true
						queue.append(next)
		return seen

	## True when a reached cell is within `radius` of (x, z) and about as high as `y`.
	func reaches(reached: Dictionary, x: float, z: float, y: float, radius: float) -> bool:
		var span: int = int(ceil(radius / GRID))
		var centre: Vector2i = cell_of(x, z)
		for dz: int in range(-span, span + 1):
			for dx: int in range(-span, span + 1):
				var cell: Vector2i = centre + Vector2i(dx, dz)
				if not reached.has(cell):
					continue
				var c: Vector2 = cell_center(cell.x, cell.y)
				if c.distance_to(Vector2(x, z)) <= radius and absf(h(cell.x, cell.y) - y) <= STEP_UP_M + 0.2:
					return true
		return false


func test_every_spawn_is_on_the_floor_and_every_door_and_prop_is_reachable_from_it() -> void:
	for id: String in _market_ids():
		var level: Node3D = _scene_of(id)
		var grid: WalkGrid = WalkGrid.new(level, 30.0, 18.0)
		var markers: Dictionary = _spawn_markers(level)
		var start_name: String = START_SPAWN if id == START_ROOM else str(_rooms()[id]["default_spawn"])
		var start: Marker3D = markers[start_name]
		var start_cell: Vector2i = grid.cell_of(start.position.x, start.position.z)
		assert_true(grid.standable(start_cell.x, start_cell.y), "%s: spawn %s is on solid floor" % [id, start_name])
		assert_almost_eq(grid.h(start_cell.x, start_cell.y), 0.0, 0.05, "%s: spawn %s is on the floor, not on a prop" % [id, start_name])
		var reached: Dictionary = grid.reach_from(start.position.x, start.position.z)
		for spawn_name: String in markers:
			var m: Marker3D = markers[spawn_name]
			var cell: Vector2i = grid.cell_of(m.position.x, m.position.z)
			assert_almost_eq(grid.h(cell.x, cell.y), 0.0, 0.05, "%s: spawn %s stands on the floor" % [id, spawn_name])
			assert_true(reached.has(cell), "%s: spawn %s is reachable from %s" % [id, spawn_name, start_name])
		for item: Dictionary in _placed(level):
			var node: Node3D = item["node"]
			var y: float = node.position.y
			var mounted: bool = node is PlacedNpc and y > 1.5      # Ume leans out of her window
			assert_true(grid.reaches(reached, node.position.x, node.position.z, minf(y, 1.8) if mounted else y, REACH_M + (1.3 if mounted else 0.0)),
					"%s: %s (%s) can be reached from the %s spawn" % [id, item["id"], node.name, start_name])
			if y < 1.5 and not node is Door and not node is JobBoard:
				var cell: Vector2i = grid.cell_of(node.position.x, node.position.z)
				assert_le(grid.h(cell.x, cell.y), y + 0.55, "%s: %s is not buried in a wall or prop" % [id, item["id"]])


func test_the_crate_hops_reach_the_ledge_and_the_stack() -> void:
	# Tarp Square: the window ledge (1.8 m) needs the step crate (0.9 m); without it the ledge is out of reach.
	var level: Node3D = _scene_of("market_square")
	var grid: WalkGrid = WalkGrid.new(level, 30.0, 18.0)
	var reached: Dictionary = grid.reach_from(1.2, 4.0)
	var ledge: Node3D = level.get_node("WindowLedge")
	assert_true(grid.reaches(reached, ledge.position.x, ledge.position.z, ledge.position.y, 0.4), "the ledge is reachable (crate step, then the ledge)")
	var without: Node3D = _scene_of("market_square")
	var crate: Node = without.get_node("Collision/CrateStepShape")
	without.get_node("Collision").remove_child(crate)
	crate.free()
	var blocked: WalkGrid = WalkGrid.new(without, 30.0, 18.0)
	var reached_no_crate: Dictionary = blocked.reach_from(1.2, 4.0)
	assert_false(blocked.reaches(reached_no_crate, ledge.position.x, ledge.position.z, ledge.position.y, 0.4), "without the step crate the 1.8 m ledge is out of reach")
	# The Wharf's stack: a crate (0.9 m) then a second on it (top 1.8 m), and the pier.
	var wharf: Node3D = _scene_of("market_wharf")
	var wharf_grid: WalkGrid = WalkGrid.new(wharf, 30.0, 18.0)
	var wharf_reach: Dictionary = wharf_grid.reach_from(12.0, 1.5)
	var top: Node3D = wharf.get_node("CratePickup")
	assert_true(wharf_grid.reaches(wharf_reach, top.position.x, top.position.z, top.position.y, 0.4), "the crate-stack pickup (1.8 m) is reachable by hopping crate A then B")
	var pier: Node3D = wharf.get_node("PierPickup")
	assert_true(wharf_grid.reaches(wharf_reach, pier.position.x, pier.position.z, pier.position.y, 0.4), "the pier-end pickup is reachable along the pier")


func test_rooms_keep_their_harrow_sizes_and_doors() -> void:
	# The map says every wall, door and floor size is the approved Harrow layout (docs/maps/night_market.md).
	var sizes: Dictionary = {"market_square": Vector2(22, 12), "market_wharf": Vector2(24, 9), "market_gate": Vector2(14, 9), "market_hideout": Vector2(7, 5),
			"market_dispatch": Vector2(8, 6), "market_corner": Vector2(7, 5), "market_forge": Vector2(7, 5), "market_repair": Vector2(7, 5), "market_arcade": Vector2(9, 6)}
	for id: String in sizes:
		var level: Node3D = _scene_of(id)
		var size: Vector2 = sizes[id]
		var floor_shape: CollisionShape3D = level.get_node("Collision/FloorShape") as CollisionShape3D
		assert_almost_eq((floor_shape.shape as BoxShape3D).size.x, size.x + 2.0, 0.01, "%s floor width" % id)
		assert_almost_eq((floor_shape.shape as BoxShape3D).size.z, size.y + 2.0, 0.01, "%s floor depth" % id)
	var square: Node3D = _scene_of("market_square")
	var door_x: Dictionary = {"DoorDispatch": 4.0, "DoorCorner": 8.5, "DoorForge": 16.0, "DoorGate": 20.0}
	for name: String in door_x:
		assert_almost_eq((square.get_node(name) as Node3D).position.x, door_x[name], 0.01, "%s stays where Harrow had it" % name)


func test_the_market_switches_are_recorded_with_rosses_answers() -> void:
	var switches: Dictionary = DataDB.get_dict("slice/market").get("switches", {}) as Dictionary
	assert_eq((switches["market_tone"] as Dictionary)["value"], "loud", "Ross 2026-10-09: loud and cheerful from the start")
	assert_eq((switches["repair_shop"] as Dictionary)["value"], "dock_office")
	assert_eq((switches["one_way_after_loader"] as Dictionary)["value"], true)
	assert_eq((switches["colossus_in_phase_1"] as Dictionary)["value"], "visible")


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
	await _until_room(START_ROOM)


func _until_room(room_id: String, limit: int = 180) -> void:
	for i: int in limit:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return
	fail("never reached %s" % room_id)


func _room() -> ActionRoom:
	return _main.get_room() as ActionRoom


func _door(room: ActionRoom, placement: String) -> Door:
	for node: Node in room.find_children("*", "Node3D", true, false):
		if node is Door and (node as Door).placement_id == placement:
			return node as Door
	return null


func test_new_game_boots_the_hideout_as_an_action_room_on_the_start_spawn() -> void:
	await _start()
	var room: ActionRoom = _room()
	assert_not_null(room, "Main wrapped the plain level in an ActionRoom")
	assert_eq(room.room_id, START_ROOM)
	assert_eq(room.entry_spawn, START_SPAWN)
	assert_false(room.is_combat())
	assert_true(room.hero.town_mode, "attacks and hacks are off in town")
	assert_not_null(room.camera_rig, "the diorama camera")
	assert_null(room.get_lock_on())
	assert_eq(_state.call("get_location")["room"], START_ROOM)
	var start_marker: Marker3D = room.find_spawn(START_SPAWN)
	assert_not_null(start_marker)
	assert_lt(room.hero.global_position.distance_to(start_marker.global_position), 0.6, "Red wakes on the start spawn")
	assert_not_null(room.find_child("SaveDeck", true, false), "the hacker deck (save terminal) is in the hideout")


func test_every_room_boots_in_town_mode_with_red_on_its_spawn() -> void:
	await _start()
	for id: String in _market_ids():
		if id != START_ROOM:
			_router.call("go_to", id, str(_rooms()[id]["default_spawn"]))
			await _until_room(id)
		var room: ActionRoom = _room()
		assert_true(room is ActionRoom, "%s is an ActionRoom" % id)
		assert_eq(room.room_id, id)
		assert_false(room.is_combat(), "%s has no fighting" % id)
		assert_not_null(room.get_director(), "%s has a director (the HUD binds everywhere)" % id)
		assert_not_null(room.get_camera_3d(), "%s has a camera" % id)
		assert_not_null(room.camera_rig, "%s uses the level's diorama camera" % id)
		var marker: Marker3D = room.find_spawn(str(_rooms()[id]["default_spawn"]))
		assert_lt(room.hero.global_position.distance_to(marker.global_position), 0.6, "%s: Red is on her spawn" % id)


func test_the_hatch_door_takes_red_down_to_the_repair_shop_and_back_up() -> void:
	await _start()
	var down: Door = _door(_room(), "mk_hd_hatch")
	assert_not_null(down)
	assert_true(down.is_unlocked())
	down.use(_room().hero, _room().interactor)
	await _until_room("market_repair")
	var shop: ActionRoom = _room()
	assert_lt(shop.hero.global_position.distance_to(shop.find_spawn("from_hideout").global_position), 0.6, "Red comes out at the ladder")
	var up: Door = _door(shop, "mk_rp_hatch")
	assert_not_null(up)
	up.use(shop.hero, shop.interactor)
	await _until_room("market_hideout")
	assert_lt(_room().hero.global_position.distance_to(_room().find_spawn("from_repair").global_position), 0.6, "and up the hatch into the hideout")


func test_the_gate_barrier_door_opens_only_with_the_flag() -> void:
	await _start()
	_router.call("go_to", "market_gate", "from_square")
	await _until_room("market_gate")
	var barrier: Door = _door(_room(), "mk_gt_to_junk")
	assert_not_null(barrier)
	_state.call("set_flag", "job_main_taken", false)
	assert_false(barrier.is_unlocked(), "locked before the main job is taken")
	_state.call("set_flag", "job_main_taken", true)
	assert_true(barrier.is_unlocked(), "open once job_main_taken is set")
	_state.call("set_flag", "job_main_taken", false)
