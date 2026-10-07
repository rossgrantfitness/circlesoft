extends TestCase
## The exploration data hangs together: every room in rooms.json has its scene and spawn markers, every
## door leads somewhere real, every pickup / crate / enemy placement matches a node in its room, and
## every item, enemy and encounter they name exists. Also the enemies' `field` blocks.

const ROOMS_ID: String = "world/rooms"


func _items() -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in DataDB.get_dict("items/items")["items"]:
		ids.append(str(entry["id"]))
	return ids


func _enemy_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in DataDB.get_dict("battle/enemies")["enemies"]:
		ids.append(str(entry["id"]))
	return ids


func _encounter_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in DataDB.get_dict("battle/encounters")["encounters"]:
		ids.append(str(entry["id"]))
	return ids


func _room_scene(room_id: String) -> Node:
	var path: String = str(DataDB.get_dict(ROOMS_ID)["rooms"][room_id]["scene"])
	return own((load(path) as PackedScene).instantiate())


func _placement_nodes(root: Node, script_path: String) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in root.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path == script_path:
			found.append(node)
	return found


func test_every_room_has_a_scene_and_its_spawn_markers() -> void:
	var rooms: Dictionary = DataDB.get_dict(ROOMS_ID)["rooms"]
	assert_false(rooms.is_empty())
	for room_id: String in rooms:
		var entry: Dictionary = rooms[room_id]
		assert_true(ResourceLoader.exists(str(entry["scene"])), room_id + " scene exists")
		var root: Node = _room_scene(room_id)
		assert_true(root is FieldRoom, room_id + " is a FieldRoom")
		var room: FieldRoom = root as FieldRoom
		assert_eq(room.room_id, room_id, "the scene knows its own id")
		var spawns: Array = entry["spawns"]
		assert_false(spawns.is_empty(), room_id + " lists spawns")
		assert_has(spawns, str(entry["default_spawn"]), room_id + " default spawn is one of them")
		for spawn_id: String in spawns:
			assert_not_null(room.find_spawn(spawn_id), "%s has the marker %s" % [room_id, spawn_id])
			assert_has(room.spawn_names(), spawn_id, "%s: %s is a real marker, not a fallback" % [room_id, spawn_id])


func test_start_room_and_new_game_room_exist() -> void:
	var data: Dictionary = DataDB.get_dict(ROOMS_ID)
	assert_has(data["rooms"], str(data["start_room"]))
	var new_game: Dictionary = DataDB.get_dict("world/save").get("new_game", {})
	if not new_game.is_empty():
		assert_has(data["rooms"], str(new_game["room"]), "the save system's new-game room")
		assert_has(data["rooms"][str(new_game["room"])]["spawns"], str(new_game["spawn"]), "and its spawn")


func test_every_door_leads_to_a_real_room_and_spawn() -> void:
	var doors: Dictionary = Placements.section(Placements.SECTION_DOORS)
	assert_false(doors.is_empty())
	var rooms: Dictionary = DataDB.get_dict(ROOMS_ID)["rooms"]
	var items: Array[String] = _items()
	for door_id: String in doors:
		var door: Dictionary = doors[door_id]
		assert_has(rooms, str(door["room"]), door_id + ": its own room")
		assert_has(rooms, str(door["to_room"]), door_id + ": target room")
		if rooms.has(str(door["to_room"])):
			assert_has(rooms[str(door["to_room"])]["spawns"], str(door["to_spawn"]), door_id + ": target spawn")
		var needs: Dictionary = door.get("requires", {})
		if not needs.is_empty():
			assert_false(str(door.get("locked_message", "")).is_empty(), door_id + ": a locked door says what it needs")
			if needs.has("item"):
				assert_has(items, str(needs["item"]), door_id + ": the key item exists")


func test_placements_match_the_nodes_in_their_rooms() -> void:
	var rooms: Dictionary = DataDB.get_dict(ROOMS_ID)["rooms"]
	var kinds: Dictionary = {
		Placements.SECTION_PICKUPS: "res://scripts/field/pickup.gd", Placements.SECTION_CRATES: "res://scripts/field/crate.gd",
		Placements.SECTION_DOORS: "res://scripts/field/door.gd", Placements.SECTION_ENEMIES: "res://scripts/encounter/map_enemy.gd",
	}
	for section: String in kinds:
		var seen: Array[String] = []
		for room_id: String in rooms:
			var root: Node = _room_scene(room_id)
			for node: Node in _placement_nodes(root, str(kinds[section])):
				var placement_id: String = str(node.get("placement_id"))
				assert_has(Placements.section(section), placement_id, "%s/%s is in placements.json" % [room_id, placement_id])
				if Placements.section(section).has(placement_id):
					assert_eq(str(Placements.entry(section, placement_id)["room"]), room_id, placement_id + " belongs to this room")
				seen.append(placement_id)
		for placement_id: String in Placements.ids(section):
			assert_has(seen, placement_id, "%s/%s has a node in a room scene" % [section, placement_id])


func test_pickups_crates_and_enemies_name_things_that_exist() -> void:
	var items: Array[String] = _items()
	for pickup_id: String in Placements.ids(Placements.SECTION_PICKUPS):
		var pickup: Dictionary = Placements.pickup(pickup_id)
		assert_true(pickup.has("item") or int(pickup.get("credits", 0)) > 0, pickup_id + " gives something")
		if pickup.has("item"):
			assert_has(items, str(pickup["item"]), pickup_id)
	for crate_id: String in Placements.ids(Placements.SECTION_CRATES):
		for entry: Dictionary in Placements.crate(crate_id).get("items", []):
			assert_has(items, str(entry["item"]), crate_id)
	var enemies: Array[String] = _enemy_ids()
	var encounters: Array[String] = _encounter_ids()
	for enemy_id: String in Placements.ids(Placements.SECTION_ENEMIES):
		var enemy: Dictionary = Placements.enemy(enemy_id)
		assert_has(enemies, str(enemy["enemy"]), enemy_id)
		assert_has(encounters, str(enemy["encounter"]), enemy_id)
		assert_has(["regular", "story", "boss"], str(enemy["kind"]), enemy_id)
		if str(enemy["kind"]) != "regular":
			assert_false(str(enemy.get("defeat_flag", "")).is_empty(), enemy_id + ": story fights and bosses stay beaten through a flag")
		for point: Variant in enemy["patrol"]:
			assert_eq((point as Array).size(), 3, enemy_id + ": patrol points are [x, y, z]")


func test_every_enemy_has_a_field_block_with_speeds() -> void:
	for entry: Dictionary in DataDB.get_dict("battle/enemies")["enemies"]:
		var field: Dictionary = entry.get("field", {})
		assert_false(field.is_empty(), "%s has a field block" % entry["id"])
		for key: String in ["walk_speed", "chase_speed", "sight_m", "give_up_s"]:
			assert_gt(float(field.get(key, 0.0)), 0.0, "%s field.%s" % [entry["id"], key])
		assert_gt(float(field.get("chase_speed", 0.0)), float(field.get("walk_speed", 0.0)), "%s chases faster than it walks" % entry["id"])
		var run_speed: float = float(DataDB.get_value("world/field_tuning", "run_speed"))
		assert_lt(float(field.get("chase_speed", 0.0)), run_speed, "%s: Red can outrun it" % entry["id"])


func test_the_exploration_numbers_load() -> void:
	var tuning: ExplorationTuning = ExplorationTuning.from_db()
	assert_gt(tuning.door_trigger_depth, 0.0)
	assert_gt(tuning.climb_s, 0.0)
	assert_gt(tuning.hop_height, 0.0)
	assert_gt(tuning.follow_teleport_distance, 0.0)
	var field: FieldTuning = FieldTuning.from_db(DataDB)
	assert_gt(field.blink_time_s, 0.0)
	assert_gt(field.follow_spacing, 0.0)
	assert_gt(field.follow_breadcrumb_step, 0.0)
	assert_gt(field.follow_catch_up_speed_mult, 1.0)


func test_the_messages_are_all_there() -> void:
	for key: String in ["got_item", "got_items", "got_credits", "crate_open", "crate_empty", "bag_full", "locked_default"]:
		assert_true(DataDB.get_dict("text/exploration").has(key), key)
	assert_eq(Placements.text("got_item", {"item": "Ration Bar"}), "Got Ration Bar!")
	assert_eq(Placements.text("got_items", {"item": "Coffee", "count": 2}), "Got Coffee x2!")
