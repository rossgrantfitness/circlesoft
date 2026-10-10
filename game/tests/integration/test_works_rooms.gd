extends TestCase
## The Spillway and the jammer works (M4-1): every room loads, every door and spawn resolves, the
## placements match the nodes, the text exists, the breather floor has no enemies, the lamps are where
## the map says, and the grim dressing is written for each room.

var _state: Node = null


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")


func after_each() -> void:
	_state.call("reset")


func _rooms_json() -> Dictionary:
	return DataDB.get_dict("world/rooms")["rooms"]


func test_every_works_room_is_in_rooms_json_with_its_scene_and_spawns() -> void:
	for room_id: String in WorksKit.ROOMS:
		assert_has(_rooms_json(), room_id)
		var entry: Dictionary = _rooms_json()[room_id]
		assert_true(ResourceLoader.exists(str(entry["scene"])), room_id + " scene exists")
		var room: FieldRoom = WorksKit.load_room(self, room_id)
		assert_eq(room.room_id, room_id)
		for spawn_id: String in entry["spawns"]:
			var marker: Marker3D = room.find_spawn(spawn_id)
			assert_not_null(marker, "%s has %s" % [room_id, spawn_id])
			if marker != null:
				assert_eq(str(marker.name), spawn_id, "a real marker, not a fallback")
		assert_has(entry["spawns"], entry["default_spawn"])
		room.free()


func test_the_room_names_are_the_new_display_names() -> void:
	var expected: Dictionary = {"road_mast_road": "The Spillway", "road_mast_foot": "The Works Gate", "tower_sump": "The Sump",
			"tower_cable_hall": "Cable Mill", "tower_bell_gallery": "Bell Gallery", "tower_generator": "Power Room",
			"tower_jammer_deck": "Drone Line", "tower_landing": "Last Landing", "tower_roof": "The Roof"}
	for room_id: String in expected:
		assert_eq(_rooms_json()[room_id]["name"], expected[room_id], room_id)


func test_every_door_in_the_works_leads_to_a_real_room_and_spawn() -> void:
	var seen: int = 0
	for room_id: String in WorksKit.ROOMS:
		var room: FieldRoom = WorksKit.load_room(self, room_id)
		for door: Door in WorksKit.doors(room):
			seen += 1
			assert_has(_rooms_json(), door.get_target_room(), door.placement_id)
			assert_has(_rooms_json()[door.get_target_room()]["spawns"], door.get_target_spawn(), door.placement_id + " target spawn")
			assert_eq(str(Placements.door(door.placement_id)["room"]), room_id, door.placement_id + " belongs here")
		room.free()
	assert_ge(seen, 15, "all the works doors were checked")


func test_every_door_has_a_way_back() -> void:
	# Each works door's target room has some door that leads back to this room (the lift aside).
	for room_id: String in WorksKit.ROOMS:
		var room: FieldRoom = WorksKit.load_room(self, room_id)
		for door: Door in WorksKit.doors(room):
			var target: String = door.get_target_room()
			if not WorksKit.ROOMS.has(target):
				continue
			var back: bool = false
			var there: FieldRoom = WorksKit.load_room(self, target)
			for other: Door in WorksKit.doors(there):
				back = back or other.get_target_room() == room_id
			there.free()
			assert_true(back, "%s -> %s has a way back" % [room_id, target])
		room.free()


func test_placements_in_the_works_have_nodes_and_the_nodes_have_placements() -> void:
	var by_section: Dictionary = {"crates": "res://scripts/field/crate.gd", "doors": "res://scripts/field/door.gd",
			"enemies": "res://scripts/encounter/map_enemy.gd", "npcs": "res://scripts/field/placed_npc.gd", "spots": "res://scripts/field/scene_spot.gd"}
	for room_id: String in WorksKit.ROOMS:
		var room: FieldRoom = WorksKit.load_room(self, room_id)
		for section: String in by_section:
			var in_scene: Array[String] = []
			for node: Node in room.find_children("*", "", true, false):
				var script: Script = node.get_script() as Script
				if script != null and script.resource_path == str(by_section[section]):
					in_scene.append(str(node.get("placement_id")))
			var in_data: Array[String] = Placements.ids_in_room(section, room_id)
			in_scene.sort()
			in_data.sort()
			assert_eq(in_scene, in_data, "%s: %s match the data" % [room_id, section])
		room.free()


func test_every_conversation_the_works_names_exists_and_speakers_are_known() -> void:
	var runner: DialogueRunner = own(DialogueRunner.new()) as DialogueRunner
	runner.index_from_data()
	var speakers: Dictionary = DataDB.get_value("ui/dialogue_ui", "speakers", {})
	var wanted: Array[String] = []
	for section: String in ["npcs", "spots"]:
		for id: String in Placements.ids(section):
			var entry: Dictionary = Placements.entry(section, id)
			if not WorksKit.ROOMS.has(str(entry["room"])):
				continue
			for variant: Dictionary in entry.get("variants", []):
				if variant.has("conversation"):
					wanted.append(str(variant["conversation"]))
				if variant.has("scene"):
					assert_false(Placements.scene(str(variant["scene"])).is_empty(), "%s: scene %s" % [id, variant["scene"]])
	for scene_id: String in Placements.scene_ids():
		var scene: Dictionary = Placements.scene(scene_id)
		if WorksKit.ROOMS.has(str(scene.get("room", ""))):
			for step: Dictionary in scene["steps"]:
				if str(step.get("do", "")) == "say":
					wanted.append(str(step["conversation"]))
	assert_gt(wanted.size(), 25)
	for conversation_id: String in wanted:
		assert_true(runner.has_conversation(conversation_id), conversation_id)
	var doc: Dictionary = DataDB.get_dict("dialogue/works")["conversations"]
	assert_eq(DialogueRunner.validate(doc), [] as Array[String])
	for conversation_id: String in doc:
		for line: Dictionary in doc[conversation_id]:
			var speaker: String = str(line["speaker"])
			assert_true(speakers.has(speaker) or speaker.begins_with("crowd_"), "%s: %s is a known speaker" % [conversation_id, speaker])


func test_every_placement_in_the_works_names_things_that_exist() -> void:
	var items: Array[String] = []
	for entry: Dictionary in DataDB.get_dict("items/items")["items"]:
		items.append(str(entry["id"]))
	for entry: Dictionary in DataDB.get_dict("items/equipment")["gear"]:
		items.append(str(entry["id"]))
	for id: String in Placements.ids("crates"):
		var crate: Dictionary = Placements.crate(id)
		if WorksKit.ROOMS.has(str(crate["room"])):
			for entry: Dictionary in crate["items"]:
				assert_has(items, str(entry["item"]), id)
	for id: String in Placements.ids("enemies"):
		var foe: Dictionary = Placements.enemy(id)
		if WorksKit.ROOMS.has(str(foe["room"])):
			assert_not_null(MapEnemy.enemy_definition(str(foe["enemy"])).get("id"), id + " enemy")
			var found: bool = false
			for encounter: Dictionary in DataDB.get_dict("battle/encounters")["encounters"]:
				found = found or str(encounter["id"]) == str(foe["encounter"])
			assert_true(found, id + " encounter " + str(foe["encounter"]))
			for entry: Dictionary in foe.get("win_reward", {}).get("items", []):
				assert_has(items, str(entry["item"]), id + " reward")


func test_the_breather_floor_has_no_enemies() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_generator")
	assert_eq(room.encounters.enemies().size(), 0, "the Power Room is a beat to breathe")
	assert_true(Placements.ids_in_room("enemies", "tower_generator").is_empty())


func test_the_fights_are_where_the_map_says() -> void:
	var expected: Dictionary = {"road_mast_road": ["rd_patrol"], "tower_sump": ["ts_card_1"], "tower_cable_hall": ["tc_drones"],
			"tower_bell_gallery": ["tb_card_pair"], "tower_jammer_deck": ["td_squad", "td_quota_a", "td_quota_b", "td_quota_c"]}
	for room_id: String in expected:
		var found: Array[String] = Placements.ids_in_room("enemies", room_id)
		found.sort()
		var want: Array[String] = []
		want.assign(expected[room_id])
		want.sort()
		assert_eq(found, want, room_id)
	for id: String in ["ts_card_1", "tb_card_pair", "td_squad"]:
		var foe: Dictionary = Placements.enemy(id)
		assert_eq(foe["kind"], "story", id + " is a must-win that stays beaten")
		assert_true(bool(foe.get("badge", false)), id + " carries the lanyard marker")
		var reward: Array = foe["win_reward"]["items"]
		assert_eq(reward.size(), 1, id + " drops one thing")
		assert_eq(str(reward[0]["item"]), WorksKit.CARD)
		assert_eq(int(reward[0]["count"]), 1, id + " drops one card")
	assert_eq(Placements.enemy("rd_patrol")["kind"], "regular", "the Spillway patrol comes back")


func test_the_save_lamps_and_the_thermos_are_where_the_map_says() -> void:
	var sump: FieldRoom = WorksKit.load_room(self, "tower_sump")
	var lamp: SaveLamp = sump.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is SaveLamp)[0] as SaveLamp
	assert_false(lamp.rest, "a dungeon lamp saves, it does not heal")
	assert_eq(lamp.room_id, "tower_sump")
	assert_not_null(sump.find_spawn(lamp.spawn_id), "its spawn marker exists")
	assert_gt(lamp.global_position.distance_to(sump.find_spawn("from_tunnel").global_position), 3.0)
	assert_lt(lamp.global_position.x, 1.0, "in the west wall, beside the grate")
	var landing: FieldRoom = WorksKit.load_room(self, "tower_landing")
	var lamp2: SaveLamp = landing.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is SaveLamp)[0] as SaveLamp
	assert_eq(lamp2.room_id, "tower_landing")
	assert_not_null(landing.find_spawn(lamp2.spawn_id))
	assert_true(Placements.npc("tl_old_zero")["variants"][0].has("scene"), "the old Zero's thermos is a scene")


func test_every_works_room_has_grim_dressing_and_the_look_keeps_it() -> void:
	var rooms: Dictionary = DataDB.get_dict("world/look_dressing")["rooms"]
	for room_id: String in WorksKit.ROOMS:
		assert_has(rooms, room_id)
		assert_gt((rooms[room_id]["items"] as Array).size(), 8, room_id + " has a kit")
		var room: FieldRoom = WorksKit.load_room(self, room_id)
		var dressing: GrimDressing = room.get_node_or_null("GrimDressing") as GrimDressing
		assert_not_null(dressing, room_id + " has its GrimDressing node")
		if dressing != null:
			assert_eq(dressing.dressing_id, room_id)
		room.free()


func test_the_rooms_are_the_size_the_map_says() -> void:
	var sizes: Dictionary = {"road_mast_road": Vector2(34, 8), "road_mast_foot": Vector2(18, 12), "tower_sump": Vector2(16, 10),
			"tower_jammer_deck": Vector2(18, 12), "tower_landing": Vector2(8, 6), "tower_roof": Vector2(20, 14)}
	for room_id: String in sizes:
		var room: FieldRoom = WorksKit.load_room(self, room_id)
		var floor_node: MeshInstance3D = room.get_node("Floor") as MeshInstance3D
		var plane: PlaneMesh = floor_node.mesh as PlaneMesh
		assert_eq(plane.size, sizes[room_id], room_id)
		room.free()


func test_the_warp_cheat_walks_the_rooms_in_order() -> void:
	var room: FieldRoom = WorksKit.load_room(self, "tower_sump")
	var warp: WorksWarp = room.get_node("WorksWarp") as WorksWarp
	assert_eq(warp.target_for(1), "tower_cable_hall")
	assert_eq(warp.target_for(-1), "road_mast_foot")
	var stub: ExplorationKit.RouterStub = own(ExplorationKit.RouterStub.new()) as ExplorationKit.RouterStub
	warp.router = stub
	assert_true(warp.warp_by(1))
	assert_eq(stub.calls, [["tower_cable_hall", ""]])
	var last: FieldRoom = WorksKit.load_room(self, "tower_roof")
	assert_eq((last.get_node("WorksWarp") as WorksWarp).target_for(1), "road_mast_road", "it wraps")
