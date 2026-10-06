class_name BattleRoster
extends RefCounted
## The HUD's own copy of who is in the fight: names, sides, slots, HP / Juice, statuses and
## down / fled flags. Built from the `battle_started` snapshot and kept current by the signals
## (stats_changed, status_changed, combatant_down / revived / fled). Pure data, no nodes.

const SIDE_PARTY: String = "party"
const SIDE_ENEMY: String = "enemy"

var _members: Dictionary[String, Dictionary] = {}
var _ids: Array[String] = []


## Replaces everything from a `snapshot()` dictionary ({"combatants": [ {id, side, slot, name, ...} ]}).
func load_snapshot(snap: Dictionary) -> void:
	_members.clear()
	_ids.clear()
	var list: Array = snap.get("combatants", [])
	for entry: Variant in list:
		var member: Dictionary = (entry as Dictionary).duplicate(true)
		var id: String = str(member.get("id", ""))
		if id.is_empty():
			continue
		member["fled"] = false
		var statuses: Array[String] = []
		for status: Variant in member.get("statuses", []):
			statuses.append(str(status))
		member["statuses"] = statuses
		member["down"] = bool(member.get("down", false)) or int(member.get("hp", 1)) <= 0
		_members[id] = member
		_ids.append(id)


func is_empty() -> bool:
	return _members.is_empty()


func has(id: String) -> bool:
	return _members.has(id)


func get_member(id: String) -> Dictionary:
	return _members.get(id, {})


func name_of(id: String) -> String:
	return str(get_member(id).get("name", id))


func side_of(id: String) -> String:
	return str(get_member(id).get("side", ""))


func slot_of(id: String) -> int:
	return int(get_member(id).get("slot", 0))


func kind_of(id: String) -> String:
	return str(get_member(id).get("kind", id))


func is_down(id: String) -> bool:
	return bool(get_member(id).get("down", false))


func is_fled(id: String) -> bool:
	return bool(get_member(id).get("fled", false))


## Down or fled: not part of the fight any more.
func is_out(id: String) -> bool:
	return is_down(id) or is_fled(id)


## Ids of a side ("party" / "enemy"; "" = everyone) ordered by slot, then by arrival.
func ids(side: String = "") -> Array[String]:
	var out: Array[String] = []
	for id: String in _ids:
		if side.is_empty() or side_of(id) == side:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return slot_of(a) < slot_of(b))
	return out


## Still standing on that side.
func live_ids(side: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ids(side):
		if not is_out(id):
			out.append(id)
	return out


## Down (not fled) on that side: who a revive can target.
func down_ids(side: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ids(side):
		if is_down(id) and not is_fled(id):
			out.append(id)
	return out


func all_out(side: String) -> bool:
	return live_ids(side).is_empty() and not ids(side).is_empty()


func has_status(id: String, status_id: String) -> bool:
	return (get_member(id).get("statuses", []) as Array).has(status_id)


func statuses_of(id: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(get_member(id).get("statuses", []))
	return out


# ---- updates ----

func set_stats(id: String, hp: int, hp_max: int, juice: int, juice_max: int) -> void:
	if not _members.has(id):
		return
	var member: Dictionary = _members[id]
	member["hp"] = hp
	member["hp_max"] = hp_max
	member["juice"] = juice
	member["juice_max"] = juice_max


func set_status(id: String, status_id: String, added: bool) -> void:
	if not _members.has(id):
		return
	var statuses: Array = _members[id]["statuses"]
	if added and not statuses.has(status_id):
		statuses.append(status_id)
	elif not added:
		statuses.erase(status_id)


func set_down(id: String, down: bool) -> void:
	if _members.has(id):
		_members[id]["down"] = down


func set_fled(id: String) -> void:
	if _members.has(id):
		_members[id]["fled"] = true
