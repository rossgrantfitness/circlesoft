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


## Extra placement files laid over world/placements (DataDB ids). Main adds "slice/placements" in slice mode, so the
## slice's doors, pickups and spots sit beside the old game's without touching them. A later file wins on a clash.
static var extra_ids: Array[String] = []
## The same for story scenes (world/story_scenes) and jobs (world/jobs): "slice/story_scenes" and "slice/jobs" in slice mode.
static var extra_scene_ids: Array[String] = []
static var extra_job_ids: Array[String] = []


static func data() -> Dictionary:
	return DataDB.get_dict(DATA_ID)


## Every section name in the placements files (pickups, doors, ... and any the slice adds, like hack targets).
static func section_names() -> Array[String]:
	var names: Array[String] = []
	var docs: Array[Dictionary] = [data()]
	for extra_id: String in extra_ids:
		docs.append(DataDB.get_dict(extra_id))
	for doc: Dictionary in docs:
		for key: Variant in doc.keys():
			if doc[key] is Dictionary and not str(key).begins_with("_") and not names.has(str(key)):
				names.append(str(key))
	return names


static func section(section_name: String) -> Dictionary:
	var base: Dictionary = data().get(section_name, {})
	if extra_ids.is_empty():
		return base
	var merged: Dictionary = base.duplicate()
	for extra_id: String in extra_ids:
		var more: Dictionary = DataDB.get_dict(extra_id).get(section_name, {})
		for placement_id: String in more:
			merged[placement_id] = more[placement_id]
	return merged


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
	return scenes_doc().get(scene_id, {})


static func scene_ids() -> Array[String]:
	var found: Array[String] = []
	found.assign(scenes_doc().keys())
	return found


## Every story scene: world/story_scenes plus the extra files (a later file wins on a clash).
static func scenes_doc() -> Dictionary:
	var merged: Dictionary = (DataDB.get_dict(SCENES_ID).get("scenes", {}) as Dictionary).duplicate()
	for extra_id: String in extra_scene_ids:
		merged.merge(DataDB.get_dict(extra_id).get("scenes", {}) as Dictionary, true)
	return merged


## A job from data/world/jobs.json (or an extra jobs file).
static func job(job_id: String) -> Dictionary:
	return jobs_doc().get(job_id, {})


## Every job: world/jobs plus the extra files.
static func jobs_doc() -> Dictionary:
	var merged: Dictionary = (DataDB.get_dict(JOBS_ID).get("jobs", {}) as Dictionary).duplicate()
	for extra_id: String in extra_job_ids:
		merged.merge(DataDB.get_dict(extra_id).get("jobs", {}) as Dictionary, true)
	return merged


## The job board's words: world/jobs "text", with the extra files' keys laid over it.
static func jobs_text() -> Dictionary:
	var merged: Dictionary = (DataDB.get_dict(JOBS_ID).get("text", {}) as Dictionary).duplicate()
	for extra_id: String in extra_job_ids:
		merged.merge(DataDB.get_dict(extra_id).get("text", {}) as Dictionary, true)
	return merged


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
