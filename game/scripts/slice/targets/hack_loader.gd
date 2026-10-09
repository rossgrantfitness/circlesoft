class_name HackLoader
extends HackTarget
## The loader robot's wake-up button at the end of J4 (docs/slice/slice_tech_plan.md 5.2 and 5.3; the Level Designer's call was a
## button press, not Overclock). Using it wakes the loader and starts the scripted boarding: RobotStage.wake_and_board().
## Data (hack_targets entry, kind "loader"): flag (loader_awake: the same flag the robot room's `wake_flag` names, so the
## stage and this button agree), robot ("small_robot"), reach_m.
## Once awake it is spent; from then on Red boards by walking into the glowing ring, as in the robot test.

signal woke(target_id: StringName)

## Set by tests; otherwise found in group `robot_stage`.
var stage: RobotStage = null


func _init() -> void:
	accepts = PackedStringArray(["interact"])
	lockable = false


func _ready_for(hack_id: StringName) -> bool:
	if hack_id != ACCEPT_INTERACT:
		return true
	return _stage() != null


func _apply(_hack_id: StringName, _info: Dictionary) -> bool:
	var found: RobotStage = _stage()
	if found == null:
		return false
	if not found.wake_and_board():
		return false
	woke.emit(target_id)
	return true


func _stage() -> RobotStage:
	if stage != null and is_instance_valid(stage):
		return stage
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(RobotStage.GROUP) as RobotStage
