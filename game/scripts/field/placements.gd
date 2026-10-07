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
const SECTIONS: Array[String] = [SECTION_PICKUPS, SECTION_CRATES, SECTION_DOORS, SECTION_ENEMIES]


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
