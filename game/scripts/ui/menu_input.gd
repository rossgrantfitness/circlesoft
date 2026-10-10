class_name MenuInput
extends RefCounted
## Turns raw input events into menu commands, so every menu and bubble reads input the same way.
## Keyboard and d-pad come through the input actions; the analog stick is handled here with a
## press / release threshold so a held stick moves the cursor once, not on every motion event.
## Mouse is not handled here (callers get stage-space positions themselves).

enum Cmd { NONE, UP, DOWN, LEFT, RIGHT, CONFIRM, CANCEL, MENU }

const ACTION_UP: StringName = &"move_up"
const ACTION_DOWN: StringName = &"move_down"
const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_CONFIRM: StringName = &"confirm"
const ACTION_CANCEL: StringName = &"cancel"
const ACTION_MENU: StringName = &"menu"
const STICK_PRESS: float = 0.6
const STICK_RELEASE: float = 0.3

var _stick_dir: Dictionary[int, int] = {}


## The command for an event, or Cmd.NONE. Key repeat counts for the four directions only.
func classify(event: InputEvent) -> Cmd:
	if event is InputEventJoypadMotion:
		return _stick(event as InputEventJoypadMotion)
	if event is InputEventMouse:
		return Cmd.NONE
	if event.is_action_pressed(ACTION_UP, true):
		return Cmd.UP
	if event.is_action_pressed(ACTION_DOWN, true):
		return Cmd.DOWN
	if event.is_action_pressed(ACTION_LEFT, true):
		return Cmd.LEFT
	if event.is_action_pressed(ACTION_RIGHT, true):
		return Cmd.RIGHT
	if event.is_action_pressed(ACTION_CONFIRM):
		return Cmd.CONFIRM
	if event.is_action_pressed(ACTION_CANCEL):
		return Cmd.CANCEL
	if event.is_action_pressed(ACTION_MENU):
		return Cmd.MENU
	return Cmd.NONE


func _stick(event: InputEventJoypadMotion) -> Cmd:
	var axis: int = event.axis
	if axis != JOY_AXIS_LEFT_X and axis != JOY_AXIS_LEFT_Y:
		return Cmd.NONE
	var value: float = event.axis_value
	if absf(value) < STICK_RELEASE:
		_stick_dir[axis] = 0
		return Cmd.NONE
	var direction: int = int(signf(value)) if absf(value) >= STICK_PRESS else 0
	if direction == 0 or direction == _stick_dir.get(axis, 0):
		return Cmd.NONE
	_stick_dir[axis] = direction
	if axis == JOY_AXIS_LEFT_Y:
		return Cmd.DOWN if direction > 0 else Cmd.UP
	return Cmd.RIGHT if direction > 0 else Cmd.LEFT
