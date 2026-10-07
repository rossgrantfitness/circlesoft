class_name FlagPose
extends Node3D
## Turns its node to a pose while a Conditions dictionary holds, swinging there smoothly when the
## flag changes and snapping there when the room loads (the checkpoint's boom barrier: down, then
## raised once the road is open). `when` is JSON text like {"flag": "checkpoint_open"}; `pose_degrees`
## is the rotation (x, y, z) it takes.

@export var when: String = ""
@export var pose_degrees: Vector3 = Vector3(0.0, 0.0, 80.0)
@export var degrees_per_second: float = 90.0

var _condition: Dictionary = {}
var _rest: Vector3 = Vector3.ZERO


func _ready() -> void:
	_condition = FlagVisible._parse(when)
	_rest = rotation_degrees
	rotation_degrees = _target()
	var state: Node = WorldProgress.game_state()
	if state != null and state.has_signal("flag_changed"):
		state.connect("flag_changed", func(_f: String, _v: bool) -> void: set_process(true))
	set_process(false)


func _process(delta: float) -> void:
	var goal: Vector3 = _target()
	rotation_degrees = rotation_degrees.move_toward(goal, degrees_per_second * delta)
	if rotation_degrees.is_equal_approx(goal):
		set_process(false)


func _target() -> Vector3:
	return _rest + pose_degrees if Conditions.met(_condition) else _rest
