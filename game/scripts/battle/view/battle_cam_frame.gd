class_name BattleCamFrame
extends RefCounted
## The formation as the camera director sees it, so shots are written once and fit any party / enemy layout.
##
## Axes: `axis` runs from the enemies' centre toward the party's centre (on the floor), `side` points toward the
## default camera side (the cross of axis and up, turned to face +Z), up is +Y. A shot position or target is an
## anchor (mid, party, enemy, hero0..2, foe0..3, boss, actor, target, pair_mid) plus an offset [along axis, up,
## along side], and the offset is scaled by `scale` (the formation's half-span over a reference span), so a wider
## formation pulls every shot back with it. "frame": "pair" swaps the axes for the ones through the acting pair
## (from the target toward the actor).

const DEFAULT_HEIGHT: float = 1.1
const SIDE_PARTY: String = "party"
const SIDE_ENEMY: String = "enemy"

var entries: Dictionary[String, Dictionary] = {}
var axis: Vector3 = Vector3.RIGHT
var side_axis: Vector3 = Vector3.BACK
var scale: float = 1.0
var party_centre: Vector3 = Vector3.ZERO
var enemy_centre: Vector3 = Vector3.ZERO
var mid: Vector3 = Vector3.ZERO


## list: [{id, side, slot, pos: Vector3, height: float, is_boss: bool}]
func build(list: Array, ref_half_span: float, scale_min: float, scale_max: float) -> void:
	entries.clear()
	var party: Array[Vector3] = []
	var enemies: Array[Vector3] = []
	for item: Variant in list:
		var entry: Dictionary = item
		entries[str(entry["id"])] = entry
		if str(entry["side"]) == SIDE_PARTY:
			party.append(entry["pos"])
		else:
			enemies.append(entry["pos"])
	party_centre = _centre(party)
	enemy_centre = _centre(enemies)
	if party.is_empty():
		party_centre = enemy_centre + Vector3.RIGHT * ref_half_span * 2.0
	if enemies.is_empty():
		enemy_centre = party_centre - Vector3.RIGHT * ref_half_span * 2.0
	mid = (party_centre + enemy_centre) * 0.5
	var flat: Vector3 = party_centre - enemy_centre
	flat.y = 0.0
	axis = flat.normalized() if flat.length() > 0.01 else Vector3.RIGHT
	side_axis = side_of(axis)
	var half_span: float = flat.length() * 0.5
	scale = clampf(half_span / maxf(ref_half_span, 0.01), scale_min, scale_max)


## The side direction for a horizontal axis: perpendicular to it, on the +Z (default camera) side.
static func side_of(horizontal: Vector3) -> Vector3:
	var side: Vector3 = horizontal.cross(Vector3.UP)
	if side.dot(Vector3.BACK) < 0.0:
		side = -side
	return side.normalized()


func has_entry(id: String) -> bool:
	return entries.has(id)


func position_of(id: String) -> Vector3:
	if entries.has(id):
		return entries[id]["pos"]
	return mid


func height_of(id: String) -> float:
	if entries.has(id):
		return float(entries[id].get("height", DEFAULT_HEIGHT))
	return DEFAULT_HEIGHT


func ids_on(side: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in entries:
		if str(entries[id]["side"]) == side:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return int(entries[a]["slot"]) < int(entries[b]["slot"]))
	return out


func boss_id() -> String:
	for id: String in ids_on(SIDE_ENEMY):
		if bool(entries[id].get("is_boss", false)):
			return id
	return ""


func anchor(name: String, ctx: Dictionary = {}) -> Vector3:
	match name:
		"mid":
			return mid
		"party":
			return party_centre
		"enemy":
			return enemy_centre
		"boss":
			var boss: String = boss_id()
			return position_of(boss) if not boss.is_empty() else enemy_centre
		"actor":
			return position_of(str(ctx.get("actor", "")))
		"target":
			return _centre_of(ctx.get("targets", []))
		"pair_mid":
			return (position_of(str(ctx.get("actor", ""))) + _centre_of(ctx.get("targets", []))) * 0.5
	if name.begins_with("hero") or name.begins_with("foe"):
		var ids: Array[String] = ids_on(SIDE_PARTY if name.begins_with("hero") else SIDE_ENEMY)
		if ids.is_empty():
			return party_centre if name.begins_with("hero") else enemy_centre
		var index: int = clampi(int(name.substr(4)), 0, ids.size() - 1)
		return position_of(ids[index])
	return mid


## spec: {"at": anchor, "off": [x, y, z], "frame": "pair" | "formation"} -> world point.
func resolve(spec: Dictionary, ctx: Dictionary = {}) -> Vector3:
	var base: Vector3 = anchor(str(spec.get("at", "mid")), ctx)
	var off_list: Array = spec.get("off", [0, 0, 0])
	var off: Vector3 = Vector3(float(off_list[0]), float(off_list[1]), float(off_list[2]))
	var along: Vector3 = axis
	var across: Vector3 = side_axis
	var k: float = scale
	if str(spec.get("frame", "formation")) == "pair" and ctx.has("pair_axis"):
		along = ctx["pair_axis"]
		across = side_of(along)
		k = float(ctx.get("pair_scale", 1.0))
	return base + (along * off.x + Vector3.UP * off.y + across * off.z) * k


## Context for an action between `actor` and `targets`: the pair axis (target -> actor) and its scale.
func pair_context(actor: String, targets: Array, ref_separation: float, scale_min: float, scale_max: float) -> Dictionary:
	var a: Vector3 = position_of(actor)
	var t: Vector3 = _centre_of(targets)
	var flat: Vector3 = a - t
	flat.y = 0.0
	var along: Vector3 = flat.normalized() if flat.length() > 0.5 else axis
	return {"actor": actor, "targets": targets, "pair_axis": along,
			"pair_scale": clampf(flat.length() / maxf(ref_separation, 0.01), scale_min, scale_max)}


func _centre_of(ids: Array) -> Vector3:
	var points: Array[Vector3] = []
	for id: Variant in ids:
		points.append(position_of(str(id)))
	return _centre(points) if not points.is_empty() else mid


static func _centre(points: Array[Vector3]) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var total: Vector3 = Vector3.ZERO
	for p: Vector3 in points:
		total += p
	return total / float(points.size())
