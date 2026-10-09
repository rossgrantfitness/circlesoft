class_name InputSorting
extends RefCounted
## Input sorting for the slice (docs/slice/slice_tech_plan.md 3, Decision 3; data/slice/input_sorting.json).
##
## The shelved game and the sandbox share one InputMap (project.godot), where pad B is both `dash` and `interact`/`cancel`.
## The slice does not rewrite that map. Instead:
##   * data says which actions are live together in each kind of room (town, dungeon, menu);
##   * conflicts() lists live pairs that share a button, other than the pairs data says are on purpose;
##   * apply() makes the small slice-boot changes (Decision 3: pad B stops being `interact`; option B puts the talk
##     button on the right trigger) and install() re-applies them after the Config screen remaps buttons.
## tests/unit/test_input_sorting.gd proves that after apply() no room kind has an accidental shared button.

const DATA_ID: String = "slice/input_sorting"
const CONFIG_SIGNAL: StringName = &"setting_changed"

static var _installed_on: Object = null
static var _mode: StringName = InteractRules.MODE_ATTACK_BUTTON
## The events an action had before apply() first touched it, so revert() can put the old game's buttons back.
static var _before: Dictionary[String, Array] = {}


# ---- data ----

static func context_names() -> Array[String]:
	var out: Array[String] = []
	out.assign((DataDB.get_value(DATA_ID, "contexts", {}) as Dictionary).keys())
	return out


## The actions that are live together in a context ("town", "dungeon", "menu").
static func live_actions(context: String) -> Array[String]:
	var out: Array[String] = []
	for action: Variant in (DataDB.get_value(DATA_ID, "contexts.%s" % context, []) as Array):
		out.append(str(action))
	return out


## The context a rooms.json `kind` uses (town, dungeon and arena; unknown kinds count as a dungeon).
static func context_for_kind(kind: String) -> String:
	return str(DataDB.get_value(DATA_ID, "room_kinds.%s" % kind, "dungeon"))


## Pairs that share a button on purpose: [["confirm", "start"], ...].
static func allowed_overlaps() -> Array:
	var out: Array = []
	for entry: Variant in (DataDB.get_value(DATA_ID, "allowed_overlaps", []) as Array):
		out.append((entry as Dictionary).get("actions", []))
	return out


# ---- reading the map ----

## A text id for each input event on an action: "key:69", "pad:1", "mouse:1", "axis:5:1".
static func signatures(action: String) -> Array[String]:
	var out: Array[String] = []
	if not InputMap.has_action(action):
		return out
	for event: InputEvent in InputMap.action_get_events(action):
		var sig: String = signature_of(event)
		if not sig.is_empty():
			out.append(sig)
	return out


static func signature_of(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		return "key:%d" % code
	if event is InputEventJoypadButton:
		return "pad:%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		return "axis:%d:%d" % [motion.axis, signi(int(motion.axis_value))]
	return ""


## Live pairs in a context that share a button and are not on the allowed list:
## [{"a": action, "b": action, "button": signature}].
static func conflicts(context: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var live: Array[String] = live_actions(context)
	var allowed: Array = allowed_overlaps()
	for i: int in live.size():
		var sigs_a: Array[String] = signatures(live[i])
		for j: int in range(i + 1, live.size()):
			if _is_allowed(allowed, live[i], live[j]):
				continue
			for sig: String in signatures(live[j]):
				if sigs_a.has(sig):
					out.append({"a": live[i], "b": live[j], "button": sig})
	return out


static func _is_allowed(allowed: Array, a: String, b: String) -> bool:
	for pair: Variant in allowed:
		var names: Array = pair as Array
		if names.has(a) and names.has(b):
			return true
	return false


# ---- applying ----

## Applies Decision 3's changes for `interact_mode` (InteractRules.MODE_*) to the InputMap. Safe to repeat.
static func apply(interact_mode: StringName) -> void:
	_mode = interact_mode
	InputRemap.snapshot()            # remember the project's own bindings before touching any, so a remap starts from them
	ensure_slice_actions()
	var changes: Array = (DataDB.get_value(DATA_ID, "always_changes", []) as Array).duplicate()
	changes.append_array(DataDB.get_value(DATA_ID, "interact_changes.%s" % String(interact_mode), []) as Array)
	for entry: Variant in changes:
		var change: Dictionary = entry as Dictionary
		var action: String = str(change.get("action", ""))
		if not InputMap.has_action(action):
			continue
		if not _before.has(action):
			_before[action] = InputMap.action_get_events(action).duplicate()
		for button: Variant in (change.get("remove_pad_buttons", []) as Array):
			_remove_pad_button(action, int(button))
		for axis_entry: Variant in (change.get("add_pad_axes", []) as Array):
			var info: Dictionary = axis_entry as Dictionary
			_add_pad_axis(action, int(info.get("axis", 0)), float(info.get("value", 1.0)))


## The slice's own buttons that the project file does not have: the hack picker's wheel, d-pad left / right and keys 1 to 4
## (HackCaster), and the command deck's open and scroll (ActionHud). Both add them only when missing, so this is safe to repeat.
static func ensure_slice_actions() -> void:
	HackCaster.ensure_actions()
	ActionHud.ensure_deck_actions()


## Puts every action apply() touched back as it was (the old game's buttons).
static func revert() -> void:
	for action: String in _before:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event: Variant in _before[action]:
			InputMap.action_add_event(action, event as InputEvent)
	_before.clear()


## apply() for the mode in data/slice/slice.json, and again whenever the Config autoload remaps a button (a remap
## rebuilds the actions from the project's bindings, which would put pad B back on `interact`).
static func install(config: Object = null) -> void:
	var rules: InteractRules = InteractRules.load_default()
	apply(rules.mode)
	if config != null and config != _installed_on and config.has_signal(CONFIG_SIGNAL):
		config.connect(CONFIG_SIGNAL, _on_setting_changed)
		_installed_on = config


static func _on_setting_changed(_key: String) -> void:
	apply(_mode)


static func _remove_pad_button(action: String, button: int) -> void:
	var keep: Array[InputEvent] = []
	var removed: bool = false
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			removed = true
		else:
			keep.append(event)
	if not removed:
		return
	InputMap.action_erase_events(action)
	for event: InputEvent in keep:
		InputMap.action_add_event(action, event)


static func _add_pad_axis(action: String, axis: int, value: float) -> void:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == axis:
			return
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = axis as JoyAxis
	motion.axis_value = value
	InputMap.action_add_event(action, motion)
