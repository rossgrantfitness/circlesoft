class_name GearVisuals
extends Node
## Visible gear on a character model: right now, the sword in Red's hand (docs/pivot/combat_api.md 4.7).
##
## Finds the model's Skeleton3D, hangs one BoneAttachment3D on `weapon_socket` (else `hand_r`, else the model
## root at a fixed offset, with a warning) and puts the chosen sword under it. Every sword file has its origin at
## the middle of the grip and its blade along +Y, so the socket needs no per-sword fiddling; `offset`, `rot_deg`
## and `scale` in data/combat/swords.json are there for the day a sword needs a nudge.
##
## Swords change the look only; the moves are the same for all of them.

signal sword_changed(sword_id: StringName)

const DATA_ID: String = "combat/swords"
const SOCKET_BONE: StringName = &"weapon_socket"
const HAND_BONE: StringName = &"hand_r"
const ATTACH_NAME: String = "WeaponAttachment"
const SWORD_NAME: String = "Sword"
## Where a sword sits when the model has neither socket nor hand bone (metres, in the model's space).
const FALLBACK_OFFSET: Vector3 = Vector3(-0.3, 0.4, 0.0)

@export var model_root: NodePath = NodePath()

var _current: StringName = &""
var _sword: Node3D = null
var _attachment: Node3D = null
var _warned: bool = false
## Test hook: replaces data/combat/swords.json.
var data_override: Dictionary = {}


## Equips a sword by id. False (and nothing changes) if the id is unknown or its file will not load.
func equip_sword(sword_id: StringName) -> bool:
	var entry: Dictionary = sword_entry(sword_id)
	if entry.is_empty():
		push_warning("GearVisuals: no sword called '%s' in %s" % [sword_id, DATA_ID])
		return false
	var packed: PackedScene = load(str(entry.get("model", ""))) as PackedScene
	if packed == null:
		push_warning("GearVisuals: sword model '%s' will not load" % str(entry.get("model", "")))
		return false
	var parent: Node3D = _attachment_node()
	if parent == null:
		return false
	if _sword != null:
		parent.remove_child(_sword)
		_sword.queue_free()
		_sword = null
	var instance: Node3D = packed.instantiate() as Node3D
	if instance == null:
		return false
	instance.name = SWORD_NAME
	var offset: Array = entry.get("offset", [0, 0, 0])
	var turn: Array = entry.get("rot_deg", [0, 0, 0])
	instance.position = Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
	instance.rotation_degrees = Vector3(float(turn[0]), float(turn[1]), float(turn[2]))
	instance.scale = Vector3.ONE * float(entry.get("scale", 1.0))
	parent.add_child(instance)
	_sword = instance
	_current = sword_id
	sword_changed.emit(sword_id)
	return true


func current_sword() -> StringName:
	return _current


func get_sword() -> Node3D:
	return _sword


## The two ends of the blade as Node3Ds riding the sword (for the trail): `base` near the guard, `tip` at the point.
## Empty when no sword is equipped.
func blade_points() -> Dictionary:
	if _sword == null:
		return {}
	var trail: Dictionary = sword_entry(_current).get("trail", {})
	var points: Dictionary = {}
	for key: String in ["base", "tip"]:
		var marker: Node3D = _sword.get_node_or_null("Blade" + key.capitalize()) as Node3D
		if marker == null:
			marker = Node3D.new()
			marker.name = "Blade" + key.capitalize()
			_sword.add_child(marker)
		marker.position = Vector3(0.0, float(trail.get(key + "_m", 0.1 if key == "base" else 0.6)), 0.0)
		points[key] = marker
	return points


## The sword ids in rack order.
func rack_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: Variant in _data().get("rack", []):
		ids.append(StringName(str(id)))
	return ids


func default_sword() -> StringName:
	return StringName(str(_data().get("default", "")))


func sword_entry(sword_id: StringName) -> Dictionary:
	var swords: Variant = _data().get("swords", {})
	if swords is Dictionary and (swords as Dictionary).has(String(sword_id)):
		return (swords as Dictionary)[String(sword_id)]
	return {}


## The trail colour for a sword (white if it has none).
func trail_color(sword_id: StringName) -> Color:
	var trail: Dictionary = sword_entry(sword_id).get("trail", {})
	return Color.html(str(trail.get("color", "#ffffff")))


func _data() -> Dictionary:
	if not data_override.is_empty():
		return data_override
	var db: Node = get_node_or_null("/root/DataDB")
	return db.call("get_dict", DATA_ID) if db != null else {}


# ---- where the sword hangs ----

func _model() -> Node3D:
	if not model_root.is_empty():
		return get_node_or_null(model_root) as Node3D
	return get_parent() as Node3D


func _attachment_node() -> Node3D:
	if _attachment != null and is_instance_valid(_attachment):
		return _attachment
	var model: Node3D = _model()
	if model == null:
		push_warning("GearVisuals: no model to put the sword on (set model_root)")
		return null
	var skeleton: Skeleton3D = null
	for found: Node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = found as Skeleton3D
		break
	if skeleton != null:
		for bone: StringName in [SOCKET_BONE, HAND_BONE]:
			if skeleton.find_bone(bone) < 0:
				continue
			if bone != SOCKET_BONE:
				_warn_once("GearVisuals: no weapon_socket bone on '%s'; using hand_r" % model.name)
			var attach: BoneAttachment3D = BoneAttachment3D.new()
			attach.name = ATTACH_NAME
			attach.bone_name = String(bone)
			skeleton.add_child(attach)
			_attachment = attach
			return attach
	_warn_once("GearVisuals: no weapon_socket or hand_r bone on '%s'; the sword floats at a fixed offset" % model.name)
	var holder: Node3D = Node3D.new()
	holder.name = ATTACH_NAME
	holder.position = FALLBACK_OFFSET
	model.add_child(holder)
	_attachment = holder
	return holder


func _warn_once(text: String) -> void:
	if not _warned:
		_warned = true
		push_warning(text)
