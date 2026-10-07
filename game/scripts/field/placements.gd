class_name Placements
extends RefCounted
## Reads data/world/placements.json (what stands in each room: pickups, crates, doors, map
## enemies) and data/text/exploration.json (the short messages). Nodes in a room scene carry a
## `placement_id`; everything else about them comes from here.

const DATA_ID: String = "world/placements"
const TEXT_ID: String = "text/exploration"
const SECTION_PICKUPS: String = "pickups"
const SECTION_CRATES: String = "crates"
const SECTION_DOORS: String = "doors"
const SECTION_ENEMIES: String = "enemies"
const SECTION_NPCS: String = "npcs"
const SECTION_SPOTS: String = "spots"
const SECTIONS: Array[String] = [SECTION_PICKUPS, SECTION_CRATES, SECTION_DOORS, SECTION_ENEMIES, SECTION_NPCS, SECTION_SPOTS]
const SCENES_ID: String = "world/story_scenes"
const JOBS_ID: String = "world/jobs"


static func data() -> Dictionary:
	return DataDB.get_dict(DATA_ID)


static func section(section_name: String) -> Dictionary:
	return data().get(section_name, {})


static func entry(section_name: String, placement_id: String) -> Dictionary:
	return section(section_name).get(placement_id, {})


static func pickup(placement_id: String) -> Dictionary:
	return entry(SECTION_PICKUPS, placement_id)


static func crate(placement_id: String) -> Dictionary:
	return entry(SECTION_CRATES, placement_id)


static func door(placement_id: String) -> Dictionary:
	return entry(SECTION_DOORS, placement_id)


static func enemy(placement_id: String) -> Dictionary:
	return entry(SECTION_ENEMIES, placement_id)


static func npc(placement_id: String) -> Dictionary:
	return entry(SECTION_NPCS, placement_id)


static func spot(placement_id: String) -> Dictionary:
	return entry(SECTION_SPOTS, placement_id)


## A story scene from data/world/story_scenes.json.
static func scene(scene_id: String) -> Dictionary:
	return DataDB.get_dict(SCENES_ID).get("scenes", {}).get(scene_id, {})


static func scene_ids() -> Array[String]:
	var found: Array[String] = []
	found.assign((DataDB.get_dict(SCENES_ID).get("scenes", {}) as Dictionary).keys())
	return found


## A job from data/world/jobs.json.
static func job(job_id: String) -> Dictionary:
	return DataDB.get_dict(JOBS_ID).get("jobs", {}).get(job_id, {})


static func ids(section_name: String) -> Array[String]:
	var found: Array[String] = []
	found.assign(section(section_name).keys())
	return found


## Placement ids of one section that belong to a room.
static func ids_in_room(section_name: String, room_id: String) -> Array[String]:
	var found: Array[String] = []
	var block: Dictionary = section(section_name)
	for placement_id: String in block:
		if str((block[placement_id] as Dictionary).get("room", "")) == room_id:
			found.append(placement_id)
	return found


## A message from data/text/exploration.json with {tokens} filled in.
static func text(key: String, tokens: Dictionary = {}) -> String:
	var line: String = str(DataDB.get_dict(TEXT_ID).get(key, key))
	for token: String in tokens:
		line = line.replace("{%s}" % token, str(tokens[token]))
	return line
