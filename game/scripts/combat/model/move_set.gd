class_name MoveSet
extends RefCounted
## All the move sets in data/combat/moves.json (Red, grunt, brute), with the gaps filled in so nothing
## else has to check for missing fields. Pure data: no clock, no nodes.
##
## A normalised move keeps every field of the file and adds: id, total_ms, impact_ms, telegraph_ms
## (-1 = none), parryable, dodge_flare, rehit_ms, chain_from_ms / chain_to_ms (-1 = no chain window).

const STATE_GROUND: StringName = &"ground"
const STATE_AIR: StringName = &"air"
const NONE: float = -1.0

var _sets: Dictionary = {}    # set id (String) -> {"entries": Dictionary, "moves": Dictionary of id -> move}


static func load_default() -> MoveSet:
	return from_data(CombatData.moves())


static func from_data(doc: Dictionary) -> MoveSet:
	var move_set: MoveSet = MoveSet.new()
	var sets: Dictionary = doc.get("sets", {})
	for set_id: Variant in sets.keys():
		var raw: Dictionary = sets[set_id]
		var moves: Dictionary = {}
		var raw_moves: Dictionary = raw.get("moves", {})
		for move_id: Variant in raw_moves.keys():
			moves[str(move_id)] = _normalise(str(move_id), raw_moves[move_id])
		move_set._sets[str(set_id)] = {"entries": (raw.get("entries", {}) as Dictionary).duplicate(true), "moves": moves}
	return move_set


func set_ids() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in _sets.keys():
		out.append(str(id))
	return out


func has_set(owner_set: StringName) -> bool:
	return _sets.has(String(owner_set))


func has_move(owner_set: StringName, move_id: StringName) -> bool:
	if not _sets.has(String(owner_set)):
		return false
	return ((_sets[String(owner_set)] as Dictionary)["moves"] as Dictionary).has(String(move_id))


## The normalised move (a copy-safe shared dictionary: do not change it). Empty if unknown.
func get_move(owner_set: StringName, move_id: StringName) -> Dictionary:
	if not has_move(owner_set, move_id):
		return {}
	return ((_sets[String(owner_set)] as Dictionary)["moves"] as Dictionary)[String(move_id)]


func move_ids(owner_set: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if _sets.has(String(owner_set)):
		for id: Variant in ((_sets[String(owner_set)] as Dictionary)["moves"] as Dictionary).keys():
			out.append(StringName(str(id)))
	return out


## The move a fresh input token starts from a state ("ground" / "air"). &"" if there is none.
func entry(owner_set: StringName, state: StringName, token: StringName) -> StringName:
	if not _sets.has(String(owner_set)):
		return &""
	var entries: Dictionary = (_sets[String(owner_set)] as Dictionary)["entries"]
	var for_state: Dictionary = entries.get(String(state), {})
	return StringName(str(for_state.get(String(token), "")))


## The move that follows `move_id` for an input token. &"" if none.
func link(owner_set: StringName, move_id: StringName, token: StringName) -> StringName:
	var move: Dictionary = get_move(owner_set, move_id)
	var links: Dictionary = move.get("links", {})
	return StringName(str(links.get(String(token), "")))


func entries(owner_set: StringName) -> Dictionary:
	if not _sets.has(String(owner_set)):
		return {}
	return (_sets[String(owner_set)] as Dictionary)["entries"]


static func total_ms(move: Dictionary) -> float:
	return float(move.get("startup_ms", 0.0)) + float(move.get("active_ms", 0.0)) + float(move.get("recovery_ms", 0.0))


static func _normalise(move_id: String, raw: Dictionary) -> Dictionary:
	var move: Dictionary = raw.duplicate(true)
	move["id"] = move_id
	for key: String in ["startup_ms", "active_ms", "recovery_ms"]:
		move[key] = float(move.get(key, 0.0))
	move["state"] = str(move.get("state", "ground"))
	move["total_ms"] = total_ms(move)
	if not move.has("cancels"):
		move["cancels"] = {}
	if not move.has("links"):
		move["links"] = {}
	if not move.has("hitboxes"):
		move["hitboxes"] = []
	if not move.has("hit"):
		move["hit"] = {}
	move["launcher"] = bool(move.get("launcher", false))
	move["parryable"] = bool(move.get("parryable", true))
	move["dodge_flare"] = bool(move.get("dodge_flare", true))
	move["rehit_ms"] = float(move.get("rehit_ms", 0.0))
	move["telegraph_ms"] = float(move["telegraph_ms"]) if move.has("telegraph_ms") else NONE
	var boxes: Array = move["hitboxes"]
	if move.has("impact_ms"):
		move["impact_ms"] = float(move["impact_ms"])
	elif not boxes.is_empty():
		move["impact_ms"] = float((boxes[0] as Dictionary).get("from_ms", move["startup_ms"]))
	else:
		move["impact_ms"] = float(move["startup_ms"])
	var chain: Array = (move["cancels"] as Dictionary).get("chain", [])
	if chain.size() >= 2:
		move["chain_from_ms"] = float(chain[0])
		move["chain_to_ms"] = float(chain[1])
	else:
		move["chain_from_ms"] = NONE
		move["chain_to_ms"] = NONE
	return move
