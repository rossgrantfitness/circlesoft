class_name RobotDisplay
extends Node3D
## A robot standing in the yard as part of the world (task CS-21): the loader parked with its back hatch, the colossus standing
## with its chest bay. While Red is inside one, the ActionPlayer wears the robot's model and the display is switched off; for the
## boarding and docking sequences the display is the actor (the hatch, the bay doors and the hop are bone poses on its skeleton, so
## no animation had to be baked, see docs/pivot/robot_scale_test.md section 2).
##
## The Technical Artist's extra bones are read by name: small: cockpit_hatch, cockpit_seat, boarding_point, dock_anchor; huge:
## dock_point, dock_door_l, dock_door_r, dock_approach. Everything is looked up by bone name, so a different robot file with the same
## names just works.

const KIND_SMALL: StringName = &"small"
const KIND_HUGE: StringName = &"huge"

var kind: StringName = KIND_SMALL
var model: Node3D = null
var model_path: String = ""
var hatch_open_deg: float = -100.0
var door_open_deg: float = 100.0

var _skeleton: Skeleton3D = null
var _anim: AnimationPlayer = null
var _body: StaticBody3D = null
var _bay_light: OmniLight3D = null
var _active: bool = true
var _hatch_amount: float = 0.0
var _doors_amount: float = 0.0


## Loads the robot's model and dresses it for the current look. False if the file is not there.
func setup(robot_kind: StringName, path: String) -> bool:
	kind = robot_kind
	model_path = path
	if not ResourceLoader.exists(path):
		return false
	var packed: PackedScene = load(path) as PackedScene
	model = packed.instantiate() as Node3D if packed != null else null
	if model == null:
		return false
	model.name = "Model"
	add_child(model)
	Ps2Look.upgrade_model(model, path, LookProfiles.active())
	LookProfiles.dress_model(model, path, "player")
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	_anim = players[0] as AnimationPlayer if not players.is_empty() else null
	_make_body()
	if kind == KIND_HUGE:
		_make_bay_light()
	play(&"idle")
	return true


func get_skeleton() -> Skeleton3D:
	return _skeleton


func get_animation_player() -> AnimationPlayer:
	return _anim


func is_active() -> bool:
	return _active


## On: seen, animating, solid. Off: hidden, still, walk-through (the player is wearing the robot).
func set_active(on: bool) -> void:
	_active = on
	visible = on
	if _anim != null:
		_anim.active = on
	if _body != null:
		_body.collision_layer = CombatLayers.bit(CombatLayers.ENEMY_BODY) if on else 0
	if not on and _bay_light != null:
		_bay_light.light_energy = 0.0


func play(clip: StringName, speed: float = 1.0) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _anim.current_animation != String(clip):
		_anim.play(clip, 0.08)
	_anim.speed_scale = speed


func current_clip() -> StringName:
	return StringName(_anim.current_animation) if _anim != null else &""


# ---- bones ----

func has_bone(bone: String) -> bool:
	return _skeleton != null and _skeleton.find_bone(bone) >= 0


## A bone's world transform (this node's own transform if there is no such bone).
func bone_transform(bone: String) -> Transform3D:
	if _skeleton == null:
		return global_transform
	var index: int = _skeleton.find_bone(bone)
	if index < 0:
		return global_transform
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(index)


func bone_position(bone: String) -> Vector3:
	return bone_transform(bone).origin


## Where Red steps up to the loader: on the floor 1.1 m behind it.
func boarding_point() -> Vector3:
	return bone_position("boarding_point")


## Where Red sits inside the loader.
func seat_point() -> Vector3:
	return bone_position("cockpit_seat")


## The floor point in front of the colossus where the loader stops to dock.
func approach_point() -> Vector3:
	return bone_position("dock_approach")


## The middle of the bay floor in the colossus's chest.
func dock_point() -> Vector3:
	return bone_position("dock_point")


## The loader's own floor point between its feet, which lines up with the colossus's dock_point.
func dock_anchor() -> Vector3:
	return bone_position("dock_anchor")


## The direction this robot faces (flat).
func facing() -> Vector3:
	var flat: Vector3 = global_basis.z
	flat.y = 0.0
	return flat.normalized() if flat.length() > 0.001 else Vector3.BACK


## Yaw (radians) that makes a robot face along `direction` (flat).
static func yaw_of(direction: Vector3) -> float:
	return atan2(direction.x, direction.z)


# ---- hatch, doors, lamps ----

## 0 closed, 1 fully open: the back hatch folds down into a ramp (about -100 degrees about X).
func set_hatch_open(amount: float) -> void:
	_hatch_amount = clampf(amount, 0.0, 1.0)
	_rotate_bone("cockpit_hatch", Vector3.RIGHT, deg_to_rad(hatch_open_deg) * clampf(amount, 0.0, 1.0))


## 0 closed, 1 open: the two chest doors swing out like a clamshell (about +/-100 degrees about Y).
func set_doors_open(amount: float) -> void:
	var k: float = clampf(amount, 0.0, 1.0)
	_doors_amount = k
	_rotate_bone("dock_door_l", Vector3.UP, deg_to_rad(door_open_deg) * k)
	_rotate_bone("dock_door_r", Vector3.UP, -deg_to_rad(door_open_deg) * k)
	if _bay_light != null:
		_bay_light.light_energy = 2.5 * k


func hatch_open_amount() -> float:
	return _hatch_amount


func doors_open_amount() -> float:
	return _doors_amount


func _rotate_bone(bone: String, axis: Vector3, angle: float) -> void:
	if _skeleton == null:
		return
	var index: int = _skeleton.find_bone(bone)
	if index < 0:
		return
	_skeleton.set_bone_pose_rotation(index, Quaternion(axis, angle))


# ---- body and bay light ----

## Something solid to walk into: a box for the loader, two leg columns for the colossus (on the enemy-body layer, which the
## colossus itself ignores).
func _make_body() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = CombatLayers.bit(CombatLayers.ENEMY_BODY)
	_body.collision_mask = 0
	add_child(_body)
	if kind == KIND_SMALL:
		_add_box_shape(Vector3(2.4, 3.2, 1.2), Vector3(0.0, 1.6, 0.1))
	else:
		for bone: String in ["foot_l", "foot_r"]:
			var at: Vector3 = Vector3.ZERO
			if _skeleton != null and _skeleton.find_bone(bone) >= 0:
				at = _skeleton.get_bone_global_rest(_skeleton.find_bone(bone)).origin
			var column: CollisionShape3D = CollisionShape3D.new()
			var shape: CylinderShape3D = CylinderShape3D.new()
			shape.radius = 5.5
			shape.height = 18.0
			column.shape = shape
			column.position = Vector3(at.x, 9.0, at.z)
			_body.add_child(column)


func _add_box_shape(size: Vector3, at: Vector3) -> void:
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = at
	_body.add_child(shape_node)


func _make_bay_light() -> void:
	if _skeleton == null or _skeleton.find_bone("dock_point") < 0:
		return
	var attach: BoneAttachment3D = BoneAttachment3D.new()
	attach.name = "DockPointAttach"
	attach.bone_name = "dock_point"
	_skeleton.add_child(attach)
	_bay_light = OmniLight3D.new()
	_bay_light.name = "BayLamp"
	_bay_light.position = Vector3(0.0, 2.5, 3.0)
	_bay_light.light_color = Color("#ffb347")
	_bay_light.light_energy = 0.0
	_bay_light.omni_range = 9.0
	attach.add_child(_bay_light)


func bay_light_energy() -> float:
	return _bay_light.light_energy if _bay_light != null else 0.0
