extends TestCase
## The Harrow Landing data hangs together (docs/maps/harrow_landing.md): the nine rooms and their
## doors, every townsperson and spot matches a node in its room, every line and scene they name exists,
## and the story scenes only use actors, encounters and flags that are real.

const ROOMS: Array[String] = ["harrow_home", "harrow_square", "harrow_courier", "harrow_store", "harrow_gear", "harrow_docks",
		"harrow_dock_office", "harrow_bar", "harrow_checkpoint"]
## The doors the map draws, "room:spawn" targets from the "Graybox build notes".
const MAP_DOORS: Dictionary = {
	"sq_to_courier": "harrow_courier:from_square", "sq_to_store": "harrow_store:from_square", "sq_to_gear": "harrow_gear:from_square",
	"sq_to_checkpoint": "harrow_checkpoint:from_square", "sq_to_home": "harrow_home:from_square", "sq_to_docks": "harrow_docks:from_square",
	"dk_to_square": "harrow_square:from_docks", "dk_to_office": "harrow_dock_office:from_docks", "dk_to_bar": "harrow_bar:from_docks",
	"cp_to_square": "harrow_square:from_checkpoint", "cp_to_road": "road_mast_road:from_harrow",
	"hm_to_square": "harrow_square:from_home", "cr_to_square": "harrow_square:from_courier", "st_to_square": "harrow_square:from_store",
	"gr_to_square": "harrow_square:from_gear", "do_to_docks": "harrow_docks:from_dock_office", "br_to_docks": "harrow_docks:from_bar",
}

var _runner: DialogueRunner = null


func _conversations() -> DialogueRunner:
	if _runner == null:
		_runner = own(DialogueRunner.new()) as DialogueRunner
		_runner.index_from_data()
	return _runner


func _scene_root(room_id: String) -> Node:
	var path: String = str(DataDB.get_dict("world/rooms")["rooms"][room_id]["scene"])
	return own((load(path) as PackedScene).instantiate())


func test_the_nine_rooms_are_in_rooms_json_and_new_game_starts_on_the_train() -> void:
	var rooms: Dictionary = DataDB.get_dict("world/rooms")["rooms"]
	for room_id: String in ROOMS:
		assert_has(rooms, room_id)
		assert_true(ResourceLoader.exists(str(rooms[room_id]["scene"])), room_id)
	assert_eq(DataDB.get_value("world/rooms", "start_room"), "train_flatcar")
	assert_eq(DataDB.get_value("world/rooms", "rooms.train_flatcar.default_spawn"), "start")
	assert_eq(DataDB.get_value("world/save", "new_game.story_beat"), "b0_train")


func test_the_doors_go_where_the_map_says() -> void:
	for door_id: String in MAP_DOORS:
		var door: Dictionary = Placements.door(door_id)
		assert_false(door.is_empty(), door_id)
		assert_eq("%s:%s" % [door["to_room"], door["to_spawn"]], str(MAP_DOORS[door_id]), door_id)
	assert_eq(Placements.door("sq_to_docks")["requires"], {"flag": "job_main_taken"}, "the dock stairs need the slip")
	assert_eq(Placements.door("cp_to_road")["requires"], {"flag": "checkpoint_open"}, "the boom barrier opens in B2")


func test_every_door_in_a_room_scene_has_a_return_door_to_a_real_spawn() -> void:
	var rooms: Dictionary = DataDB.get_dict("world/rooms")["rooms"]
	for room_id: String in ROOMS:
		var root: Node = _scene_root(room_id)
		var doors: int = 0
		for node: Node in root.find_children("*", "Node3D", true, false):
			if node is Door:
				doors += 1
				var door: Dictionary = Placements.door((node as Door).placement_id)
				assert_has(rooms[str(door["to_room"])]["spawns"], str(door["to_spawn"]))
		assert_gt(doors, 0, room_id + " has a door")


func test_every_npc_and_spot_has_a_node_in_its_room_and_the_other_way_round() -> void:
	var kinds: Dictionary = {Placements.SECTION_NPCS: "PlacedNpc", Placements.SECTION_SPOTS: "SceneSpot"}
	for section: String in kinds:
		var seen: Array[String] = []
		# Every room in rooms.json, not just Harrow's nine: the Spillway and the works have people and signs too.
		for room_id: String in DataDB.get_dict("world/rooms")["rooms"]:
			var root: Node = _scene_root(room_id)
			for node: Node in root.find_children("*", "Node3D", true, false):
				var script: Script = node.get_script() as Script
				if script != null and script.get_global_name() == kinds[section]:
					var placement_id: String = str(node.get("placement_id"))
					assert_has(Placements.section(section), placement_id, "%s in %s" % [placement_id, room_id])
					if Placements.section(section).has(placement_id):
						assert_eq(str(Placements.entry(section, placement_id)["room"]), room_id, placement_id)
					seen.append(placement_id)
		for placement_id: String in Placements.ids(section):
			if placement_id == "cr_board":
				continue  # the job board node is a JobBoard, listed under spots only for its id
			assert_has(seen, placement_id, "%s/%s has a node" % [section, placement_id])


func test_every_line_an_npc_or_spot_can_say_exists() -> void:
	var runner: DialogueRunner = _conversations()
	for section: String in [Placements.SECTION_NPCS, Placements.SECTION_SPOTS]:
		for placement_id: String in Placements.ids(section):
			var data: Dictionary = Placements.entry(section, placement_id)
			if section == Placements.SECTION_NPCS:
				assert_false((data["variants"] as Array).is_empty(), placement_id + " says something")
			for variant: Dictionary in data["variants"]:
				if variant.has("conversation"):
					assert_true(runner.has_conversation(str(variant["conversation"])), "%s: %s" % [placement_id, variant["conversation"]])
				if variant.has("scene"):
					assert_false(Placements.scene(str(variant["scene"])).is_empty(), "%s: scene %s" % [placement_id, variant["scene"]])


func test_story_scenes_only_use_real_lines_actors_encounters_and_flags() -> void:
	var runner: DialogueRunner = _conversations()
	var encounters: Array[String] = []
	for entry: Dictionary in DataDB.get_dict("battle/encounters")["encounters"]:
		encounters.append(str(entry["id"]))
	var item_ids: Array[String] = []
	for entry: Dictionary in DataDB.get_dict("items/items")["items"]:
		item_ids.append(str(entry["id"]))
	for scene_id: String in Placements.scene_ids():
		var scene: Dictionary = Placements.scene(scene_id)
		assert_has(DataDB.get_dict("world/rooms")["rooms"], str(scene["room"]), scene_id)
		if scene.has("trigger"):
			assert_false(str(scene.get("once", "")).is_empty(), scene_id + ": a scene that starts by itself must set a once flag")
		var root: Node = _scene_root(str(scene["room"]))
		var names: Array[String] = ["red"]
		for node: Node in root.find_children("*", "Node3D", true, false):
			names.append(str(node.name))
			if node.get("placement_id") != null:
				names.append(str(node.get("placement_id")))
		for step: Dictionary in scene["steps"]:
			var what: String = str(step["do"])
			if what == "say":
				assert_true(runner.has_conversation(str(step["conversation"])), "%s: %s" % [scene_id, step["conversation"]])
			if what == "battle":
				assert_has(encounters, str(step["encounter"]), scene_id)
				assert_has(["normal", "party", "enemies"], str(step["first_turn"]))
			if step.has("actor") and not str(step["actor"]).begins_with("follower:"):
				assert_has(names, str(step["actor"]), "%s: actor %s is in %s" % [scene_id, step["actor"], scene["room"]])
			if what == "give_item" or what == "take_item":
				assert_has(item_ids, str(step["item"]), scene_id)
			if what == "beat":
				assert_has(["b1_night", "b2_otis_joined", "b3_home_again", "b2_road", "b3_tower"], str(step["beat"]))


func test_jobs_use_real_items_and_the_flags_the_story_uses() -> void:
	var item_ids: Array[String] = []
	for entry: Dictionary in DataDB.get_dict("items/items")["items"]:
		item_ids.append(str(entry["id"]))
	var jobs: Dictionary = DataDB.get_dict("world/jobs")["jobs"]
	assert_eq(jobs.keys(), ["main", "dark_window", "appeal"], "the main job and the two side deliveries")
	for job_id: String in jobs:
		var job: Dictionary = jobs[job_id]
		for entry: Dictionary in job["take"]["give_items"]:
			assert_has(item_ids, str(entry["item"]), job_id)
		for key: String in ["taken_flag", "done_flag"]:
			assert_false(str(job[key]).is_empty())
		assert_has(job["take"]["set_flags"], job["taken_flag"], job_id + " sets its own taken flag")
	assert_eq(jobs["main"]["taken_flag"], "job_main_taken")
	assert_eq(jobs["dark_window"]["done_flag"], "job_dark_window_done")
	assert_eq(jobs["appeal"]["done_flag"], "job_appeal_done")


func test_the_five_hidden_items_and_the_shops_are_in_data() -> void:
	var hidden: Array[String] = ["sq_alley_stash", "dk_chili", "dk_pier_coffee", "cp_bin", "br_jukebox"]
	for placement_id: String in hidden:
		var found: bool = Placements.pickup(placement_id).size() > 0 or Placements.crate(placement_id).size() > 0
		assert_true(found, placement_id)
	assert_eq(Placements.crate("sq_alley_stash")["style"], "chalk", "the alley stash carries the Coldrunner chalk mark")
	assert_eq(Placements.crate("sq_alley_stash")["credits"], 60)
	for shop_id: String in ["harrow_general", "harrow_gear"]:
		assert_true(ShopData.has_shop(shop_id))
		assert_eq(ShopData.validate(ShopData.load_shop(shop_id)), [] as Array[String])


func test_the_conversations_are_clean() -> void:
	var doc: Dictionary = DataDB.get_dict("dialogue/harrow_town")
	assert_eq(DialogueRunner.validate(doc["conversations"]), [] as Array[String])
