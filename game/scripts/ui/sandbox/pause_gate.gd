class_name SandboxPauseGate
extends RefCounted
## One place that pauses the arena for the sandbox's pause menu and feel panel, and reads the two
## buttons that open them. Several holders can ask for a pause at once (the pause menu opens the
## controls card, say); the game un-pauses and gives the mouse back only when the last one lets go.
##
## While held: the scene tree is paused, the mouse is freed (the camera captures it during play,
## so the old mouse mode is remembered and restored), and the UiStage keeps running so menus still
## get their keyboard and mouse events. Nobody touches Engine.time_scale.

const ACTION_START: StringName = &"start"
const ACTION_CONFIRM: StringName = &"confirm"
const ACTION_FEEL: StringName = &"feel_panel"

static var _holders: Array[int] = []
static var _saved_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
static var _was_paused: bool = false
static var _active: bool = false
static var _stage: Node = null
static var _stage_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT


## Ask for the pause. Safe to call twice from the same holder.
static func hold(tree: SceneTree, holder: Object) -> void:
	if tree == null or holder == null:
		return
	_prune()
	var id: int = holder.get_instance_id()
	if _holders.has(id):
		return
	if _holders.is_empty():
		_saved_mouse = Input.mouse_mode
		_was_paused = tree.paused
		_active = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		tree.paused = true
		_stage = tree.get_first_node_in_group(UiStage.GROUP)
		if _stage != null:
			_stage_mode = _stage.process_mode
			_stage.process_mode = Node.PROCESS_MODE_ALWAYS
	_holders.append(id)


## Let go of the pause. The last holder to let go restores everything.
static func release(tree: SceneTree, holder: Object) -> void:
	if holder == null:
		return
	_holders.erase(holder.get_instance_id())
	_prune()
	if not _holders.is_empty():
		return
	_restore(tree)


static func is_held() -> bool:
	_prune()
	return not _holders.is_empty()


static func is_holder(holder: Object) -> bool:
	return holder != null and _holders.has(holder.get_instance_id())


## Drops every hold and restores the game (tests, scene changes).
static func clear(tree: SceneTree) -> void:
	_holders.clear()
	_restore(tree)


static func _restore(tree: SceneTree) -> void:
	if _stage != null and is_instance_valid(_stage):
		_stage.process_mode = _stage_mode
	_stage = null
	if not _active:
		return
	_active = false
	if tree != null and not _was_paused:
		tree.paused = false
	Input.mouse_mode = _saved_mouse
	_was_paused = false


static func _prune() -> void:
	var alive: Array[int] = []
	for id: int in _holders:
		if is_instance_valid(instance_from_id(id)):
			alive.append(id)
	_holders = alive


# ---- the two buttons ----

## True for the pause button (Esc, pad Start). Enter is also bound to `start` in the project, but
## it is Confirm first, so menus that are already open never read it as "close".
static func is_start_press(event: InputEvent) -> bool:
	if not InputMap.has_action(ACTION_START):
		return false
	if not event.is_action_pressed(ACTION_START, false):
		return false
	return not (InputMap.has_action(ACTION_CONFIRM) and event.is_action_pressed(ACTION_CONFIRM, false))


## True for the feel-panel button (F12, pad Back). Falls back to the raw buttons when the input
## action has not been added to the project yet.
static func is_feel_press(event: InputEvent) -> bool:
	if InputMap.has_action(ACTION_FEEL):
		return event.is_action_pressed(ACTION_FEEL, false)
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return key.pressed and not key.echo and (key.keycode == KEY_F12 or key.physical_keycode == KEY_F12)
	if event is InputEventJoypadButton:
		var pad: InputEventJoypadButton = event as InputEventJoypadButton
		return pad.pressed and pad.button_index == JOY_BUTTON_BACK
	return false
