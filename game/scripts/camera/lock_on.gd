class_name LockOn
extends Node
## Hard lock-on and soft targeting for Red (docs/pivot/combat_api.md 4.8).
##
## toggle(): lock to the best target, or let go if already locked. With nobody in range it asks the
## camera to recenter (the `recenter_requested` signal). switch(flick): step to the next target left
## or right. soft_target() / magnet_target(): who an attack should snap to without a hard lock.
##
## Candidates are the live enemies. They come from `candidate_provider` (a Callable returning an
## Array of Node3D; tests set it) or, by default, from the CombatDirector in group "combat_director"
## (`actors(&"enemy")`). An enemy is a candidate while it is alive (`hp` > 0 when it has one), in range
## and visible from Red (a ray against the world layer). A locked target that dies, goes out of
## `break_range_m`, or stays hidden past `los_grace_s` is dropped on its own.
## All numbers are in data/combat/camera.json "lock" and "magnet".

signal target_changed(target: Node3D)
signal recenter_requested

const DATA_ID: String = "combat/camera"
const GROUP_DIRECTOR: StringName = &"combat_director"
const ACTION_LOCK_ON: StringName = &"lock_on"
const TEAM_ENEMY: StringName = &"enemy"

## Poll the lock_on action in tick() (the game). Tests turn it off and call toggle() themselves.
@export var read_engine_input: bool = true
## Returns Array[Node3D] of possible targets. Empty callable = ask the CombatDirector.
var candidate_provider: Callable = Callable()
## Red (where the search measures from).
var origin_node: Node3D = null
## The camera, for "which way is forward" and "which side is right". Null = the viewport camera.
var camera_node: Node3D = null

## Reach multiplier for every range below (CS-21: a 50 m robot sees a lot further than Red). 1.0 = camera.json as written.
var range_scale: float = 1.0

var _target: Node3D = null
var _params: Dictionary = {}
var _magnet: Dictionary = {}
var _hidden_for_s: float = 0.0


func _ready() -> void:
	reload_data()


func reload_data() -> void:
	var db: Node = _db()
	_params = (db.call("get_value", DATA_ID, "lock", {}) as Dictionary) if db != null else {}
	_magnet = (db.call("get_value", DATA_ID, "magnet", {}) as Dictionary) if db != null else {}


func _physics_process(delta: float) -> void:
	tick(delta)


## One step: reads the lock_on button (when asked to) and drops a target that is gone.
func tick(delta: float) -> void:
	if read_engine_input and Input.is_action_just_pressed(ACTION_LOCK_ON):
		toggle()
	if _target == null:
		return
	if not is_instance_valid(_target) or not _target.is_inside_tree() or not _is_alive(_target):
		release()
		return
	var origin: Vector3 = _origin()
	var distance: float = LockOnMath.flat_offset(origin, _target.global_position).length()
	if distance > _f(_params, "break_range_m", 21.0) * range_scale:
		release()
		return
	if _can_see(_target):
		_hidden_for_s = 0.0
	else:
		_hidden_for_s += delta
		if _hidden_for_s > _f(_params, "los_grace_s", 0.6):
			release()


func get_target() -> Node3D:
	return _target if is_instance_valid(_target) else null


func has_target() -> bool:
	return get_target() != null


## Lock to the best target, or let go. Returns the target afterwards (null when released or nobody).
func toggle() -> Node3D:
	if has_target():
		release()
		return null
	var pick: Node3D = best_target()
	if pick == null:
		recenter_requested.emit()
		return null
	set_target(pick)
	return pick


func set_target(target: Node3D) -> void:
	if target == _target:
		return
	_target = target
	_hidden_for_s = 0.0
	target_changed.emit(_target)


func release() -> void:
	if _target == null:
		return
	_target = null
	_hidden_for_s = 0.0
	target_changed.emit(null)


## The best eligible target for a fresh lock (null if none).
func best_target() -> Node3D:
	var list: Array[Node3D] = _eligible(_f(_params, "max_range_m", 16.0) * range_scale, true)
	if list.is_empty():
		return null
	var entries: Array[Dictionary] = _entries(list)
	var params: Dictionary = _params.duplicate()
	params["max_range_m"] = _f(_params, "max_range_m", 16.0) * range_scale
	var index: int = LockOnMath.best(entries, _cam_forward(), _origin(), params)
	return list[index] if index >= 0 else null


## Flick left or right (screen-style vector, x right, y down) to move the lock to its neighbour.
## Returns the new target. Does nothing without a lock.
func switch(flick: Vector2) -> Node3D:
	if not has_target():
		return null
	var list: Array[Node3D] = _eligible(_f(_params, "break_range_m", 21.0) * range_scale, true)
	if not list.has(_target):
		list.append(_target)
	var entries: Array[Dictionary] = _entries(list)
	var index: int = LockOnMath.switch_index(entries, list.find(_target), flick, _cam_right(), _origin())
	if index >= 0 and list[index] != _target:
		set_target(list[index])
	return _target


## Who an attack should snap to when there is no hard lock: the nearest-to-`stick_dir` enemy in the
## magnet cone. `stick_dir` (flat, world space) is where she is pushing; zero means her facing, which
## the caller passes in `facing`. Range and cone default to camera.json "magnet".
func soft_target(stick_dir: Vector3, facing: Vector3 = Vector3.ZERO, range_m: float = -1.0, cone_deg: float = -1.0) -> Node3D:
	var reach: float = range_m if range_m > 0.0 else _f(_magnet, "default_range_m", 3.5)
	var cone: float = cone_deg if cone_deg > 0.0 else _f(_magnet, "default_cone_deg", 70.0)
	var dir: Vector3 = stick_dir if stick_dir.length() > 0.001 else facing
	if dir.length() < 0.001:
		dir = _cam_forward()
	var list: Array[Node3D] = _eligible(reach, false)
	var index: int = LockOnMath.magnet_pick(_entries(list), _origin(), dir, reach, cone)
	return list[index] if index >= 0 else null


## The target a move that starts now should turn toward: the hard lock wins when there is one (and it
## is within camera.json magnet.locked_target_max_range_m), else the soft target.
func magnet_target(stick_dir: Vector3, facing: Vector3, range_m: float, cone_deg: float) -> Node3D:
	var locked: Node3D = get_target()
	if locked != null:
		var distance: float = LockOnMath.flat_offset(_origin(), locked.global_position).length()
		if distance <= _f(_magnet, "locked_target_max_range_m", 9.0) * range_scale:
			return locked
	return soft_target(stick_dir, facing, range_m, cone_deg)


# ---- helpers ----

func _candidates() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var raw: Variant = null
	if candidate_provider.is_valid():
		raw = candidate_provider.call()
	elif is_inside_tree():
		var director: Node = get_tree().get_first_node_in_group(GROUP_DIRECTOR)
		if director != null and director.has_method("actors"):
			raw = director.call("actors", TEAM_ENEMY)
	if raw is Array:
		for item: Variant in raw as Array:
			var node: Node3D = item as Node3D
			if node != null and is_instance_valid(node) and node.is_inside_tree() and _is_alive(node):
				out.append(node)
	return out


func _eligible(reach: float, need_sight: bool) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var origin: Vector3 = _origin()
	for node: Node3D in _candidates():
		if LockOnMath.flat_offset(origin, node.global_position).length() > reach:
			continue
		if need_sight and not _can_see(node):
			continue
		out.append(node)
	return out


func _entries(list: Array[Node3D]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for node: Node3D in list:
		out.append({"pos": node.global_position, "node": node})
	return out


func _is_alive(node: Node3D) -> bool:
	if "hp" in node:
		return int(node.get("hp")) > 0
	return true


func _origin() -> Vector3:
	if origin_node != null and is_instance_valid(origin_node):
		return origin_node.global_position
	return Vector3.ZERO


func _cam_basis() -> Basis:
	if camera_node != null and is_instance_valid(camera_node):
		return camera_node.global_basis
	if is_inside_tree():
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null:
			return cam.global_basis
	return Basis.IDENTITY


func _cam_forward() -> Vector3:
	return PlayerMotion.flat_forward(_cam_basis())


func _cam_right() -> Vector3:
	return PlayerMotion.flat_right(_cam_basis())


## True when nothing in the world layer sits between Red's chest and the target's chest.
func _can_see(node: Node3D) -> bool:
	if not is_inside_tree():
		return true
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null:
		return true
	var height: Vector3 = Vector3.UP * _f(_params, "los_height_m", 0.9)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			_origin() + height, node.global_position + height, int(_params.get("los_mask", 1)))
	query.collide_with_areas = false
	return space.intersect_ray(query).is_empty()


func _space() -> PhysicsDirectSpaceState3D:
	var world: World3D = get_viewport().world_3d if is_inside_tree() else null
	return world.direct_space_state if world != null else null


static func _f(source: Dictionary, key: String, fallback: float) -> float:
	return float(source.get(key, fallback))


func _db() -> Node:
	return get_node_or_null("/root/DataDB") if is_inside_tree() else null
