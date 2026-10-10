class_name InputRemap
extends RefCounted
## Button remapping for the Config screen. A "group" is one row of the Controls page (Confirm,
## Cancel, Jump...). Each group has one keyboard key and one controller button that can be changed;
## the other keys on the same action (for example Enter as a second Confirm) stay as they are.
##
## The pure part works on plain dictionaries so it can be tested without touching the real input
## map and saved straight into user://config.json:
##   overrides   {group: {"key": physical_keycode, "pad": button_index}}   (only what differs from the defaults)
##   effective   the same shape, but with every group filled in
## apply() writes an overrides dictionary into Godot's InputMap, always starting from the original
## project bindings (captured the first time anything here runs), so applying twice or applying an
## empty dictionary is safe. The groups come from data/ui/config_screen.json ("controls.rows").
##
## Movement keys, Esc and F1 to F12 can't be bound (they are used by the menus and the debug keys),
## and neither can the d-pad or the Start button.

const DATA_ID: String = "ui/config_screen"
const KIND_KEY: String = "key"
const KIND_PAD: String = "pad"
const NO_CODE: int = -1
const MOVE_ACTIONS: PackedStringArray = ["move_up", "move_down", "move_left", "move_right"]
const START_ACTION: String = "start"

static var _original: Dictionary[String, Array] = {}


# ---- groups ----

static func group_ids() -> Array[String]:
	var ids: Array[String] = []
	for row: Variant in DataDB.get_value(DATA_ID, "controls.rows", []):
		ids.append(str((row as Dictionary)["id"]))
	return ids


static func group_actions(group: String) -> Array[String]:
	var actions: Array[String] = []
	for row: Variant in DataDB.get_value(DATA_ID, "controls.rows", []):
		if str((row as Dictionary)["id"]) == group:
			for action: Variant in (row as Dictionary)["actions"]:
				actions.append(str(action))
	return actions


# ---- the pure part ----

## The project's own bindings as {group: {"key": int, "pad": int}} (NO_CODE where there is none).
static func defaults() -> Dictionary:
	snapshot()
	var out: Dictionary = {}
	for group: String in group_ids():
		var actions: Array[String] = group_actions(group)
		var events: Array = _original.get(actions[0], []) if not actions.is_empty() else []
		out[group] = {KIND_KEY: _first_code(events, KIND_KEY), KIND_PAD: _first_code(events, KIND_PAD)}
	return out


## Every group's current binding: the defaults with `overrides` laid over them.
static func effective(overrides: Dictionary) -> Dictionary:
	var out: Dictionary = defaults()
	for group: String in out:
		if not overrides.has(group):
			continue
		for kind: String in [KIND_KEY, KIND_PAD]:
			if (overrides[group] as Dictionary).has(kind):
				out[group][kind] = int((overrides[group] as Dictionary)[kind])
	return out


## Only the entries of `effective_map` that differ from the defaults.
static func overrides_from(effective_map: Dictionary) -> Dictionary:
	var base: Dictionary = defaults()
	var out: Dictionary = {}
	for group: String in effective_map:
		if not base.has(group):
			continue
		for kind: String in [KIND_KEY, KIND_PAD]:
			var code: int = int((effective_map[group] as Dictionary).get(kind, base[group][kind]))
			if code != int(base[group][kind]):
				if not out.has(group):
					out[group] = {}
				out[group][kind] = code
	return out


## `current` (an effective map) with `group`'s key or pad set to `code`. If a group that must
## differ from this one (see swap_sets) already uses that code, the two swap, so neither is left
## doing nothing or sharing a button it shouldn't. Groups outside the swap sets (the Clutch press
## shares buttons with Confirm and Jump on purpose) are left alone.
static func rebind(current: Dictionary, group: String, kind: String, code: int) -> Dictionary:
	var out: Dictionary = current.duplicate(true)
	if not out.has(group):
		return out
	var old_code: int = int(out[group][kind])
	var other: String = holder_of(out, kind, code, group)
	if not other.is_empty():
		out[other][kind] = old_code
	out[group][kind] = code
	return out


## The group, among those that must stay different from `group`, that currently holds `code`
## ("" if none). The screen uses it to say "swapped with ...".
static func holder_of(current: Dictionary, kind: String, code: int, group: String) -> String:
	for other: String in swap_partners(group):
		if current.has(other) and int(current[other][kind]) == code:
			return other
	return ""


## Every group that shares a swap set with `group`.
static func swap_partners(group: String) -> Array[String]:
	var partners: Array[String] = []
	for set_: Variant in DataDB.get_value(DATA_ID, "controls.swap_sets", []):
		if (set_ as Array).has(group):
			for other: Variant in set_:
				if str(other) != group and not partners.has(str(other)):
					partners.append(str(other))
	return partners


## True for keys and buttons that can't be bound.
static func is_reserved(kind: String, code: int) -> bool:
	snapshot()
	if kind == KIND_KEY:
		if code == KEY_ESCAPE or (code >= KEY_F1 and code <= KEY_F12):
			return true
		for action: String in MOVE_ACTIONS:
			if _first_code_all(_original.get(action, []), KIND_KEY).has(code):
				return true
		return false
	for action: String in MOVE_ACTIONS:
		if _first_code_all(_original.get(action, []), KIND_PAD).has(code):
			return true
	return _first_code_all(_original.get(START_ACTION, []), KIND_PAD).has(code)


# ---- names for the screen ----

static func key_name(code: int) -> String:
	if code == NO_CODE or code == 0:
		return "-"
	var label: int = DisplayServer.keyboard_get_keycode_from_physical(code as Key)
	var named: String = OS.get_keycode_string((label if label != 0 else code) as Key)
	return named if not named.is_empty() else "Key %d" % code


static func pad_name(code: int) -> String:
	if code == NO_CODE:
		return "-"
	var names: Array = DataDB.get_value("text/config", "controls.pad_buttons", [])
	if code >= 0 and code < names.size():
		return str(names[code])
	return "Btn %d" % code


static func code_name(kind: String, code: int) -> String:
	return key_name(code) if kind == KIND_KEY else pad_name(code)


# ---- the real input map ----

## Remembers the project's original bindings for every action in a group (once).
static func snapshot() -> void:
	if not _original.is_empty():
		return
	var wanted: Array[String] = []
	for group: String in group_ids():
		wanted.append_array(group_actions(group))
	wanted.append_array(MOVE_ACTIONS)
	wanted.append(START_ACTION)
	for action: String in wanted:
		if InputMap.has_action(action) and not _original.has(action):
			var copies: Array = []
			for event: InputEvent in InputMap.action_get_events(action):
				copies.append(event.duplicate())
			_original[action] = copies


## Puts the original bindings back.
static func reset() -> void:
	apply({})


## Writes `overrides` into the InputMap (from the original bindings, every time).
static func apply(overrides: Dictionary) -> void:
	snapshot()
	var now: Dictionary = effective(overrides)
	var assigned_keys: Dictionary[int, String] = {}
	var assigned_pads: Dictionary[int, String] = {}
	for group: String in overrides:
		if not now.has(group):
			continue
		if (overrides[group] as Dictionary).has(KIND_KEY):
			assigned_keys[int(now[group][KIND_KEY])] = group
		if (overrides[group] as Dictionary).has(KIND_PAD):
			assigned_pads[int(now[group][KIND_PAD])] = group
	for group: String in group_ids():
		for action: String in group_actions(group):
			if not InputMap.has_action(action) or not _original.has(action):
				continue
			var events: Array = []
			for event: Variant in _original[action]:
				events.append((event as InputEvent).duplicate())
			_replace_primary(events, KIND_KEY, int(now[group][KIND_KEY]))
			_replace_primary(events, KIND_PAD, int(now[group][KIND_PAD]))
			events = _without_stolen(events, group, assigned_keys, assigned_pads)
			InputMap.action_erase_events(action)
			for event: Variant in events:
				InputMap.action_add_event(action, event as InputEvent)


# ---- helpers ----

static func _code_of(event: InputEvent, kind: String) -> int:
	if kind == KIND_KEY and event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if kind == KIND_PAD and event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index
	return NO_CODE


static func _first_code(events: Array, kind: String) -> int:
	var all: Array = _first_code_all(events, kind)
	return int(all[0]) if not all.is_empty() else NO_CODE


static func _first_code_all(events: Array, kind: String) -> Array:
	var codes: Array = []
	for event: Variant in events:
		var code: int = _code_of(event as InputEvent, kind)
		if code != NO_CODE:
			codes.append(code)
	return codes


## Sets the first key (or pad button) event to `code`, adding one when the action has none.
static func _replace_primary(events: Array, kind: String, code: int) -> void:
	if code == NO_CODE:
		return
	for event: Variant in events:
		if _code_of(event as InputEvent, kind) == NO_CODE:
			continue
		if kind == KIND_KEY:
			(event as InputEventKey).physical_keycode = code as Key
			(event as InputEventKey).keycode = KEY_NONE
		else:
			(event as InputEventJoypadButton).button_index = code as JoyButton
		return
	if kind == KIND_KEY:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = code as Key
		events.append(key)
	else:
		var pad: InputEventJoypadButton = InputEventJoypadButton.new()
		pad.button_index = code as JoyButton
		events.append(pad)


## Drops the second-choice keys and buttons of an action that another group has just been given,
## so a key never does two jobs after a remap.
static func _without_stolen(events: Array, group: String, assigned_keys: Dictionary, assigned_pads: Dictionary) -> Array:
	var kept: Array = []
	var seen_key: bool = false
	var seen_pad: bool = false
	for event: Variant in events:
		var key_code: int = _code_of(event as InputEvent, KIND_KEY)
		var pad_code: int = _code_of(event as InputEvent, KIND_PAD)
		var is_primary: bool = false
		if key_code != NO_CODE:
			is_primary = not seen_key
			seen_key = true
			if not is_primary and assigned_keys.has(key_code) and str(assigned_keys[key_code]) != group:
				continue
		elif pad_code != NO_CODE:
			is_primary = not seen_pad
			seen_pad = true
			if not is_primary and assigned_pads.has(pad_code) and str(assigned_pads[pad_code]) != group:
				continue
		kept.append(event)
	return kept
