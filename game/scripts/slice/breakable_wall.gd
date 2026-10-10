class_name BreakableWall
extends StaticBody3D
## A scrap wall that can be smashed (the junkyard's `Breakables/*`). Two kinds, told apart by group:
##   `crane_breakable`  the crane's swinging load smashes it: HackCrane calls smash() (or stomp()) on arrival.
##   `loader_smash`     only the loader can break it: it falls when Red, in a robot form (small or huge), walks into it. On foot
##                      it is just a wall.
## smash() makes it sink into the floor in a puff of dust, switches its collision off and sets the sticky flag
## `smashed_<room>_<name>` (a retry that rewinds the room's flags stands it up again; a reload after a save does not matter,
## since the flag is part of the save). ActionRoom gives this script to every such wall in a room at start-up (setup()).

signal smashed(wall: BreakableWall)

const GROUP_CRANE: StringName = &"crane_breakable"
const GROUP_LOADER: StringName = &"loader_smash"
const GROUP_ROOM: StringName = &"action_room"
const SINK_S: float = 0.8
const REACH_M: float = 0.9

var _done: bool = false
var _sink_t: float = -1.0
var _start_y: float = 0.0
var _depth_m: float = 4.0
var _room: Node = null


## Called by ActionRoom after it attaches the script. `for_room` is the room that owns the wall.
func setup(for_room: Node = null) -> void:
	_room = for_room
	_start_y = position.y
	_depth_m = _guess_height() + 0.3
	set_physics_process(is_loader_only())       # the crane's walls wait for smash(); the loader's watch for the loader
	if _flag_set():
		_finish()


func is_loader_only() -> bool:
	return is_in_group(GROUP_LOADER)


func is_smashed() -> bool:
	return _done


## The crane's load or the loader hit it: down it goes.
func smash() -> void:
	if _done or _sink_t >= 0.0:
		return
	_sink_t = 0.0
	set_physics_process(true)
	_set_collision(false)
	_set_flag()
	_dust()
	smashed.emit(self)


## A robot's foot: the same as smash().
func stomp() -> void:
	smash()


func _physics_process(delta: float) -> void:
	if _sink_t >= 0.0 and not _done:
		_sink_t = minf(_sink_t + delta / SINK_S, 1.0)
		position.y = _start_y - _depth_m * _sink_t * _sink_t
		if _sink_t >= 1.0:
			_finish()
		return
	if is_loader_only() and _loader_is_touching():
		smash()


func _finish() -> void:
	_done = true
	_sink_t = 1.0
	visible = false
	_set_collision(false)
	set_physics_process(false)


func _set_collision(on: bool) -> void:
	for child: Node in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).set_deferred("disabled", not on)


## True when Red is in a robot form and her body is against one of this wall's boxes.
func _loader_is_touching() -> bool:
	var room: Node = _owner_room()
	if room == null:
		return false
	var hero: Node3D = room.get("hero") as Node3D
	if hero == null or not is_instance_valid(hero) or StringName(room.call("get_form")) == &"red":
		return false
	var reach: float = REACH_M + float(hero.get("radius_m") if "radius_m" in hero else 0.5)
	for child: Node in find_children("*", "CollisionShape3D", true, false):
		var shape_node: CollisionShape3D = child as CollisionShape3D
		var box: BoxShape3D = shape_node.shape as BoxShape3D
		if box == null:
			continue
		var local: Vector3 = shape_node.global_transform.affine_inverse() * hero.global_position
		var outside: Vector3 = (local.abs() - box.size * 0.5).max(Vector3.ZERO)
		outside.y = 0.0          # her height does not matter; the floor under her does
		if outside.length() <= reach:
			return true
	return false


func _owner_room() -> Node:
	if _room != null and is_instance_valid(_room):
		return _room
	_room = get_tree().get_first_node_in_group(GROUP_ROOM)
	return _room


func _guess_height() -> float:
	var top: float = 3.0
	for child: Node in find_children("*", "CollisionShape3D", true, false):
		var box: BoxShape3D = (child as CollisionShape3D).shape as BoxShape3D
		if box != null:
			top = maxf(top, (child as Node3D).position.y + box.size.y * 0.5)
	return top


func flag_id() -> String:
	var room: Node = _owner_room()
	var room_id: String = str(room.get("room_id")) if room != null else ""
	return "smashed_%s_%s" % [room_id, str(name)]


func _flag_set() -> bool:
	var state: Node = get_node_or_null("/root/GameState")
	return state != null and bool(state.call("get_flag", flag_id()))


func _set_flag() -> void:
	var state: Node = get_node_or_null("/root/GameState")
	if state != null:
		state.call("set_flag", flag_id(), true)


func _dust() -> void:
	if is_inside_tree() and get_parent() != null:
		ScaleDust.spawn(get_parent(), global_position + Vector3.UP * 0.2, &"step_small")
