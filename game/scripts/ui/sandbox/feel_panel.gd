class_name FeelPanel
extends Control
## The feel-knobs panel (CS-16, contract 4.9). Opens with F12 / pad Back, pauses the arena, frees
## the mouse, and lets Ross tune the game by hand. Every slider, toggle and drop-down is built from
## the knob list in data/combat/feel.json (no knob is named in this file), grouped into tabs, each
## with its unit, a "studio default" notch, and a one-line hint. Buttons: Save, Reset (to the studio
## numbers), Revert (to the last save) and Open folder.
##
## Controls (pad, keys and mouse all work): Up/Down picks a row (tabs above, buttons below), Left/Right
## changes the value (hold to go faster; on the tabs or buttons it moves between them), Confirm flips a
## toggle / picks the next option / presses a button, LB/RB or PageUp/PageDown switch tab, Cancel,
## Esc or the panel button closes. The mouse hovers, clicks, drags sliders and uses the wheel.
##
## Using it (lives on the UiStage, see SandboxHud which owns one):
##   panel.bind(knobs)        # knobs: the director's FeelKnobs (anything with get_f / get_b / get_s,
##                            # set_value and save_user works)
## Saving is the knobs object's job (save_user() writes user://feel/feel_current.json plus a dated
## copy and returns the full path); the panel shows that path and copies it to the clipboard.
## Layout: data/ui/sandbox_ui.json "feel_panel". Words: data/text/sandbox.json "feel".

signal opened
signal closed
## A knob was changed from the panel (the knobs object has already been told).
signal knob_changed(id: String, value: Variant)
## Save worked; `path` is the full path of feel_current.json.
signal saved(path: String)

enum Zone { TABS, ROWS, BUTTONS }

const BUTTON_IDS: Array[String] = ["save", "reset", "revert", "open_folder"]
const FEEL_DATA_ID: String = "combat/feel"
const FEEL_USER_DIR: String = "user://feel"
const MOUSE_DRAG_PAD: float = 4.0

## The knobs being edited (null until bind()).
var knobs: Object = null
var audio: UiAudio = UiAudio.new()
## Off: the panel does not run itself; tests call tick(delta).
var manual_ticks: bool = false
## On: read input in _input (the panel must live on the UiStage so mouse positions are stage pixels).
var listen_input: bool = true
## Off: opening does not pause the game (tests).
var pause_game: bool = true
var animations_enabled: bool = true
## Open-folder hook: Callable(path: String) -> int (an Error). Tests replace it.
var opener: Callable = Callable()
## Off: Save does not touch the clipboard (tests).
var clipboard_enabled: bool = true
## Tests set this to say a direction is still held ((command: MenuInput.Cmd) -> bool).
var hold_probe: Callable = Callable()

var _layout: Dictionary = {}
var _meta: Array[Dictionary] = []
var _groups: Array[String] = []
var _defaults: Dictionary = {}
var _snapshot: Dictionary = {}
var _open: bool = false
var _zone: Zone = Zone.ROWS
var _tab: int = 0
var _row: int = 0
var _top: int = 0
var _button: int = 0
var _dragging: bool = false
var _input_map: MenuInput = MenuInput.new()
var _hold_cmd: MenuInput.Cmd = MenuInput.Cmd.NONE
var _hold_clock: float = 0.0
var _hold_steps: int = 0
var _open_clock: float = 0.0
var _message: String = ""
var _message_good: bool = true
var _message_left: float = 0.0
var _last_path: String = ""
var _palette: Dictionary[String, Color] = {}

var _dim: ColorRect = null
var _window: UiWindow = null
var _overlay: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	_layout = SandboxUiData.ui("feel_panel", {})
	for key: String in DataDB.get_value(SandboxUiData.THEME_ID, "palette", {}):
		_palette[key] = SandboxUiData.palette(key)
	var window_rect: Rect2 = SandboxUiData.rect("feel_panel.window")
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = Color(_palette["ink"], float(_layout.get("dim_alpha", 0.5)))
	_dim.size = size
	add_child(_dim)
	_window = UiWindow.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.position = window_rect.position
	_window.size = window_rect.size
	add_child(_window)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.position = window_rect.position
	_overlay.size = window_rect.size
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	visible = false
	set_process(not manual_ticks)


func _exit_tree() -> void:
	if _open and pause_game:
		SandboxPauseGate.release(get_tree(), self)


# ---- binding ----

## Connects the panel to the knobs. `meta` is the knob list to show (default: knobs.knobs(), else the
## list in data/combat/feel.json); `defaults` maps knob id -> studio default (default: the values in
## data/combat/feel.json, else the values the knobs have right now).
func bind(knob_object: Object, meta: Array = [], defaults: Dictionary = {}) -> void:
	knobs = knob_object
	_meta.clear()
	var source: Array = meta
	if source.is_empty() and knobs != null and knobs.has_method("knobs"):
		source = knobs.call("knobs")
	if source.is_empty():
		source = DataDB.get_value(FEEL_DATA_ID, "knobs", [])
	for knob: Variant in source:
		if knob is Dictionary and not str((knob as Dictionary).get("id", "")).is_empty():
			_meta.append(knob as Dictionary)
	_groups = FeelFormat.groups_of(_meta)
	_defaults = defaults.duplicate() if not defaults.is_empty() else _studio_defaults()
	for knob: Dictionary in _meta:
		var id: String = str(knob["id"])
		if not _defaults.has(id):
			_defaults[id] = knob.get("default", _read(knob))
	_snapshot = _current_values()
	_tab = clampi(_tab, 0, maxi(0, _groups.size() - 1))
	_row = 0
	_top = 0
	_refresh()


## The studio defaults: the "value" of each knob in data/combat/feel.json (the file Ross's numbers will be copied into).
func _studio_defaults() -> Dictionary:
	var out: Dictionary = {}
	for knob: Variant in DataDB.get_value(FEEL_DATA_ID, "knobs", []):
		if knob is Dictionary and (knob as Dictionary).has("value"):
			out[str((knob as Dictionary).get("id", ""))] = (knob as Dictionary)["value"]
	return out


# ---- reading and writing the knobs ----

func _read(knob: Dictionary) -> Variant:
	var id: String = str(knob["id"])
	if knobs == null:
		return knob.get("value", 0.0)
	match FeelFormat.kind_of(knob):
		FeelFormat.KIND_BOOL:
			return bool(knobs.call("get_b", id))
		FeelFormat.KIND_CHOICE:
			return str(knobs.call("get_s", id))
		FeelFormat.KIND_INT:
			return roundi(float(knobs.call("get_f", id)))
		_:
			return float(knobs.call("get_f", id))


func _write(knob: Dictionary, value: Variant) -> void:
	if knobs == null:
		return
	var id: String = str(knob["id"])
	knobs.call("set_value", id, value)
	knob_changed.emit(id, value)


func _current_values() -> Dictionary:
	var out: Dictionary = {}
	for knob: Dictionary in _meta:
		out[str(knob["id"])] = _read(knob)
	return out


func get_knob_list() -> Array[Dictionary]:
	return _meta


func get_knob_groups() -> Array[String]:
	return _groups


## The studio default of a knob (what the notch shows).
func get_default(id: String) -> Variant:
	return _defaults.get(id)


func get_value(id: String) -> Variant:
	for knob: Dictionary in _meta:
		if str(knob["id"]) == id:
			return _read(knob)
	return null


## True when any knob differs from the last save (or from boot, before the first save).
func is_dirty() -> bool:
	for knob: Dictionary in _meta:
		var id: String = str(knob["id"])
		if not FeelFormat.same_value(knob, _read(knob), _snapshot.get(id)):
			return true
	return false


func _is_changed(knob: Dictionary) -> bool:
	return not FeelFormat.same_value(knob, _read(knob), _defaults.get(str(knob["id"])))


func _group_changed(group: String) -> bool:
	for knob: Dictionary in FeelFormat.knobs_in_group(_meta, group):
		if _is_changed(knob):
			return true
	return false


# ---- opening and closing ----

func open_panel() -> void:
	if _open:
		return
	_open = true
	visible = true
	_zone = Zone.ROWS
	_row = 0
	_top = 0
	_message = ""
	_message_left = 0.0
	_dragging = false
	_open_clock = 0.0
	_window.open_amount = 0.25 if animations_enabled else 1.0
	if pause_game:
		SandboxPauseGate.hold(get_tree(), self)
	audio.sfx("confirm")
	_refresh()
	opened.emit()


func close_panel() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_dragging = false
	_hold_cmd = MenuInput.Cmd.NONE
	if pause_game:
		SandboxPauseGate.release(get_tree(), self)
	audio.sfx("back")
	closed.emit()


func toggle_panel() -> void:
	if _open:
		close_panel()
	else:
		open_panel()


func is_open() -> bool:
	return _open


# ---- state the tests and the HUD can read ----

func get_zone() -> Zone:
	return _zone


func get_tab() -> int:
	return _tab


func get_row() -> int:
	return _row


func get_button() -> int:
	return _button


func get_message() -> String:
	return _message


func get_saved_path() -> String:
	return _last_path


## The knobs on the tab being shown.
func get_rows() -> Array[Dictionary]:
	if _groups.is_empty():
		return []
	return FeelFormat.knobs_in_group(_meta, _groups[_tab])


func get_cursor_knob() -> Dictionary:
	var rows: Array[Dictionary] = get_rows()
	if _row >= 0 and _row < rows.size():
		return rows[_row]
	return {}


## Moves focus straight to a knob (switches tab). Used by tests and by "show me this one".
func focus_knob(id: String) -> bool:
	for knob: Dictionary in _meta:
		if str(knob["id"]) != id:
			continue
		_tab = maxi(0, _groups.find(str(knob.get("group", ""))))
		_row = maxi(0, get_rows().find(knob))
		_zone = Zone.ROWS
		_scroll_to_row()
		_refresh()
		return true
	return false


# ---- time ----

func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not _open:
		return
	_open_clock += delta
	if animations_enabled and _window.open_amount < 1.0:
		var steps: int = int(_layout.get("open_steps", 4))
		var step_s: float = SandboxUiData.ui_float("step_s", 0.0833)
		_window.open_amount = minf(1.0, 0.25 + 0.75 * float(int(_open_clock / step_s) + 1) / float(steps))
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message = ""
			_overlay.queue_redraw()
	_tick_hold(delta)


func _tick_hold(delta: float) -> void:
	if _hold_cmd == MenuInput.Cmd.NONE:
		return
	if not _still_held(_hold_cmd):
		_hold_cmd = MenuInput.Cmd.NONE
		return
	_hold_clock += delta
	var every: float = float(_layout.get("repeat_every_s", 0.06))
	var due: float = float(_layout.get("repeat_delay_s", 0.35)) + every * float(_hold_steps)
	while _hold_clock >= due:
		var fast: bool = _hold_steps >= int(_layout.get("fast_after_steps", 10))
		_step_value(1 if _hold_cmd == MenuInput.Cmd.RIGHT else -1, int(_layout.get("fast_mult", 4)) if fast else 1)
		_hold_steps += 1
		due += every


func _still_held(command: MenuInput.Cmd) -> bool:
	if hold_probe.is_valid():
		return bool(hold_probe.call(command))
	return Input.is_action_pressed(&"move_right" if command == MenuInput.Cmd.RIGHT else &"move_left")


# ---- input ----

func _input(event: InputEvent) -> void:
	if not listen_input:
		return
	if SandboxPauseGate.is_feel_press(event):
		if _open or not SandboxPauseGate.is_held():
			toggle_panel()
			get_viewport().set_input_as_handled()
		return
	if _open and handle_event(event):
		get_viewport().set_input_as_handled()


## One input event while the panel is open. Mouse positions must be in stage pixels.
func handle_event(event: InputEvent) -> bool:
	if not _open:
		return false
	if event is InputEventMouse:
		return handle_mouse(event)
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_PAGEUP or key.keycode == KEY_PAGEDOWN):
			_shift_tab(1 if key.keycode == KEY_PAGEDOWN else -1)
			return true
	if event is InputEventJoypadButton:
		var pad: InputEventJoypadButton = event as InputEventJoypadButton
		if pad.pressed and (pad.button_index == JOY_BUTTON_LEFT_SHOULDER or pad.button_index == JOY_BUTTON_RIGHT_SHOULDER):
			_shift_tab(1 if pad.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1)
			return true
	if SandboxPauseGate.is_start_press(event):
		close_panel()
		return true
	var command: MenuInput.Cmd = _input_map.classify(event)
	if command == MenuInput.Cmd.NONE:
		return false
	var sideways: bool = command == MenuInput.Cmd.LEFT or command == MenuInput.Cmd.RIGHT
	if sideways and event is InputEventKey and (event as InputEventKey).echo:
		return true
	if sideways and _zone == Zone.ROWS:
		_hold_cmd = command
		_hold_clock = 0.0
		_hold_steps = 0
	return handle_command(command)


## A menu command. Returns true when the panel used it.
func handle_command(command: MenuInput.Cmd) -> bool:
	if not _open:
		return false
	match command:
		MenuInput.Cmd.UP:
			_move_focus(-1)
		MenuInput.Cmd.DOWN:
			_move_focus(1)
		MenuInput.Cmd.LEFT:
			_sideways(-1)
		MenuInput.Cmd.RIGHT:
			_sideways(1)
		MenuInput.Cmd.CONFIRM:
			_confirm()
		MenuInput.Cmd.CANCEL:
			close_panel()
		_:
			return false
	return true


func _move_focus(direction: int) -> void:
	var rows: int = get_rows().size()
	match _zone:
		Zone.TABS:
			if direction > 0:
				_set_zone(Zone.ROWS if rows > 0 else Zone.BUTTONS)
				_row = 0
			else:
				_set_zone(Zone.BUTTONS)
		Zone.ROWS:
			var target: int = _row + direction
			if target < 0:
				_set_zone(Zone.TABS)
			elif target >= rows:
				_set_zone(Zone.BUTTONS)
			else:
				_row = target
		Zone.BUTTONS:
			if direction < 0 and rows > 0:
				_set_zone(Zone.ROWS)
				_row = rows - 1
			else:
				_set_zone(Zone.TABS)
	_scroll_to_row()
	audio.sfx("tick")
	_refresh()


func _set_zone(zone: Zone) -> void:
	_zone = zone


func _sideways(direction: int) -> void:
	match _zone:
		Zone.TABS:
			_shift_tab(direction)
		Zone.ROWS:
			_step_value(direction, 1)
		Zone.BUTTONS:
			_button = posmod(_button + direction, BUTTON_IDS.size())
			audio.sfx("tick")
			_refresh()


func _shift_tab(direction: int) -> void:
	if _groups.size() < 2:
		return
	_tab = posmod(_tab + direction, _groups.size())
	_row = clampi(_row, 0, maxi(0, get_rows().size() - 1))
	_top = 0
	_scroll_to_row()
	audio.sfx("tick")
	_refresh()


func _confirm() -> void:
	match _zone:
		Zone.TABS:
			_move_focus(1)
		Zone.ROWS:
			var knob: Dictionary = get_cursor_knob()
			if knob.is_empty():
				return
			match FeelFormat.kind_of(knob):
				FeelFormat.KIND_BOOL:
					_set_knob(knob, not bool(_read(knob)))
				FeelFormat.KIND_CHOICE:
					_set_knob(knob, FeelFormat.cycle_choice(knob, str(_read(knob)), 1))
				_:
					audio.sfx("tick")
		Zone.BUTTONS:
			press_button(BUTTON_IDS[_button])


## Changes the value under the cursor by `steps` steps of its size (toggles and choices flip or cycle).
func _step_value(direction: int, steps: int) -> void:
	var knob: Dictionary = get_cursor_knob()
	if knob.is_empty():
		return
	match FeelFormat.kind_of(knob):
		FeelFormat.KIND_BOOL:
			_set_knob(knob, direction > 0)
		FeelFormat.KIND_CHOICE:
			_set_knob(knob, FeelFormat.cycle_choice(knob, str(_read(knob)), direction))
		_:
			var now: float = float(_read(knob))
			_set_knob(knob, FeelFormat.step_number(knob, now, direction * steps))


## Sets a knob (clamped and snapped for sliders) and plays the tick when it actually changed.
func _set_knob(knob: Dictionary, value: Variant) -> void:
	var before: Variant = _read(knob)
	var target: Variant = value
	if FeelFormat.is_slider(knob):
		target = FeelFormat.snap(knob, float(value))
		if FeelFormat.kind_of(knob) == FeelFormat.KIND_INT:
			target = roundi(float(target))
	if FeelFormat.same_value(knob, before, target):
		return
	_write(knob, target)
	audio.sfx("tick")
	_refresh()


## Sets a knob by id from outside (the buttons, tests). Returns false for an unknown id.
func set_knob_value(id: String, value: Variant) -> bool:
	for knob: Dictionary in _meta:
		if str(knob["id"]) == id:
			_set_knob(knob, value)
			return true
	return false


# ---- the buttons ----

func press_button(button_id: String) -> void:
	match button_id:
		"save":
			save_now()
		"reset":
			reset_to_defaults()
		"revert":
			revert_to_save()
		"open_folder":
			open_folder()


## Writes the file through the knobs object and remembers this state as "the last save".
func save_now() -> void:
	var path: String = ""
	if knobs != null and knobs.has_method("save_user"):
		path = str(knobs.call("save_user"))
	if path.is_empty():
		_say(SandboxUiData.text("feel.messages.save_failed"), false)
		audio.sfx("back")
		return
	_last_path = path
	_snapshot = _current_values()
	var key: String = "saved"
	if clipboard_enabled and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(path)
		key = "saved_copied"
	_say(SandboxUiData.fmt(SandboxUiData.text("feel.messages.%s" % key), {"path": FeelFormat.shorten_path(path, int(_layout.get("path_chars", 50)))}), true)
	audio.sfx("confirm")
	saved.emit(path)
	_refresh()


## Every knob back to the studio's number (not saved until Save).
func reset_to_defaults() -> void:
	for knob: Dictionary in _meta:
		var id: String = str(knob["id"])
		if _defaults.has(id) and not FeelFormat.same_value(knob, _read(knob), _defaults[id]):
			_write(knob, _defaults[id])
	_say(SandboxUiData.text("feel.messages.reset_done"), true)
	audio.sfx("confirm")
	_refresh()


## Every knob back to the last save (or to how it was when the sandbox started, before the first save).
func revert_to_save() -> void:
	var changed: bool = false
	for knob: Dictionary in _meta:
		var id: String = str(knob["id"])
		if _snapshot.has(id) and not FeelFormat.same_value(knob, _read(knob), _snapshot[id]):
			_write(knob, _snapshot[id])
			changed = true
	_say(SandboxUiData.text("feel.messages.revert_done" if changed else "feel.messages.revert_nothing"), true)
	audio.sfx("confirm" if changed else "back")
	_refresh()


## The folder where the saved files live (where the last save went, else user://feel).
func get_folder() -> String:
	if not _last_path.is_empty():
		return _last_path.get_base_dir()
	return ProjectSettings.globalize_path(FEEL_USER_DIR)


func open_folder() -> void:
	var folder: String = get_folder()
	DirAccess.make_dir_recursive_absolute(folder)
	var result: int = OK
	if opener.is_valid():
		result = int(opener.call(folder))
	else:
		result = OS.shell_open(folder)
	if result == OK:
		_say(SandboxUiData.fmt(SandboxUiData.text("feel.messages.folder_opened"), {"path": FeelFormat.shorten_path(folder, int(_layout.get("path_chars", 50)))}), true)
	else:
		_say(SandboxUiData.fmt(SandboxUiData.text("feel.messages.folder_failed"), {"path": FeelFormat.shorten_path(folder, int(_layout.get("path_chars", 50)))}), false)
	audio.sfx("confirm")


func _say(text: String, good: bool) -> void:
	_message = text
	_message_good = good
	_message_left = float(_layout.get("message_s", 12.0))


# ---- mouse ----

func _local(stage_point: Vector2) -> Vector2:
	return _overlay.get_global_transform().affine_inverse() * stage_point


## Hover, click, drag and wheel. `event.position` must be in stage pixels. Returns true when used.
func handle_mouse(event: InputEvent) -> bool:
	if not _open:
		return false
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var at: Vector2 = _local(motion.position)
		if _dragging:
			_drag_to(at.x)
			return true
		var row: int = _row_at(at)
		if row >= 0:
			_row = row
			_zone = Zone.ROWS
			_refresh()
			return true
		var button: int = _button_at(at)
		if button >= 0:
			_button = button
			_zone = Zone.BUTTONS
			_refresh()
			return true
		return _window.get_rect().has_point(motion.position)
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		var at: Vector2 = _local(click.position)
		if not click.pressed:
			if click.button_index == MOUSE_BUTTON_LEFT:
				_dragging = false
			return false
		match click.button_index:
			MOUSE_BUTTON_LEFT:
				return _click(at)
			MOUSE_BUTTON_RIGHT:
				close_panel()
				return true
			MOUSE_BUTTON_WHEEL_UP:
				_wheel(1)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				_wheel(-1)
				return true
	return false


func _click(at: Vector2) -> bool:
	var tab: int = _tab_at(at)
	if tab >= 0:
		if tab != _tab:
			_tab = tab
			_row = 0
			_top = 0
			audio.sfx("tick")
		_zone = Zone.TABS
		_refresh()
		return true
	var button: int = _button_at(at)
	if button >= 0:
		_button = button
		_zone = Zone.BUTTONS
		press_button(BUTTON_IDS[button])
		_refresh()
		return true
	var row: int = _row_at(at)
	if row >= 0:
		_row = row
		_zone = Zone.ROWS
		var knob: Dictionary = get_cursor_knob()
		match FeelFormat.kind_of(knob):
			FeelFormat.KIND_BOOL:
				_set_knob(knob, not bool(_read(knob)))
			FeelFormat.KIND_CHOICE:
				_set_knob(knob, FeelFormat.cycle_choice(knob, str(_read(knob)), 1))
			_:
				var track: Rect2 = _slider_rect(row - _top).grow_individual(MOUSE_DRAG_PAD, 0, MOUSE_DRAG_PAD, 0)
				if track.has_point(at):
					_dragging = true
					_drag_to(at.x)
		_refresh()
		return true
	return _window.get_rect().has_point(at + _overlay.position)


func _drag_to(local_x: float) -> void:
	var knob: Dictionary = get_cursor_knob()
	if knob.is_empty() or not FeelFormat.is_slider(knob):
		return
	var slider_x: float = float(_layout["slider_x"])
	var along: float = (local_x - slider_x) / float(_layout["slider_w"])
	_set_knob(knob, FeelFormat.value_at(knob, along))


func _wheel(direction: int) -> void:
	if _zone == Zone.ROWS and not get_cursor_knob().is_empty():
		_step_value(direction, 1)


# ---- layout helpers (local to the window) ----

func _rows_visible() -> int:
	return int(_layout.get("rows_visible", 7))


func _scroll_to_row() -> void:
	if _row < _top:
		_top = _row
	elif _row >= _top + _rows_visible():
		_top = _row - _rows_visible() + 1
	_top = clampi(_top, 0, maxi(0, get_rows().size() - _rows_visible()))


func _row_rect(visible_index: int) -> Rect2:
	var y: float = float(_layout["row_y"]) + float(visible_index) * float(_layout["row_h"])
	return Rect2(6.0, y, _overlay.size.x - 12.0, float(_layout["row_h"]))


func _slider_rect(visible_index: int) -> Rect2:
	var row: Rect2 = _row_rect(visible_index)
	var h: float = float(_layout["slider_h"])
	return Rect2(float(_layout["slider_x"]), row.position.y + (row.size.y - h) / 2.0, float(_layout["slider_w"]), h)


func _row_at(at: Vector2) -> int:
	var rows: Array[Dictionary] = get_rows()
	for i: int in _rows_visible():
		if _top + i >= rows.size():
			break
		if _row_rect(i).has_point(at):
			return _top + i
	return -1


func _tab_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var x: float = 10.0
	var pad: float = float(_layout.get("tab_pad_x", 5))
	for group: String in _groups:
		var w: float = float(UiFonts.text_width("tag", FeelFormat.group_title(group))) + pad * 2.0
		out.append(Rect2(x, float(_layout["tab_y"]), w, float(_layout["tab_h"])))
		x += w + 2.0
	return out


func _tab_at(at: Vector2) -> int:
	var rects: Array[Rect2] = _tab_rects()
	for i: int in rects.size():
		if rects[i].has_point(at):
			return i
	return -1


func _button_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var x: float = float(_layout["label_x"])
	var pad: float = float(_layout.get("button_pad_x", 7))
	for id: String in BUTTON_IDS:
		var w: float = float(UiFonts.text_width("menu", SandboxUiData.text("feel.buttons.%s" % id))) + pad * 2.0
		out.append(Rect2(x, float(_layout["button_y"]), w, float(_layout["button_h"])))
		x += w + float(_layout.get("button_gap", 6))
	return out


func _button_at(at: Vector2) -> int:
	var rects: Array[Rect2] = _button_rects()
	for i: int in rects.size():
		if rects[i].has_point(at):
			return i
	return -1


func _refresh() -> void:
	if _overlay != null:
		_overlay.queue_redraw()


# ---- drawing ----

func _draw_overlay() -> void:
	if not _open or _layout.is_empty():
		return
	var width: float = _overlay.size.x
	UiText.draw(_overlay, "menu", Vector2(16, float(_layout["title_y"])), SandboxUiData.text("feel.title"), _palette["lamp_amber"])
	var status: String = SandboxUiData.text("feel.unsaved") if is_dirty() else SandboxUiData.text("feel.saved")
	var status_color: Color = _palette["lamp_glow"] if is_dirty() else _palette["text_dim"]
	UiText.draw(_overlay, "tag", Vector2(width - 14, float(_layout["title_y"])), status, status_color, HORIZONTAL_ALIGNMENT_RIGHT, 150.0)
	UiText.draw(_overlay, "tag", Vector2(width - 14 - 150, float(_layout["title_y"])), SandboxUiData.text("feel.paused"), _palette["slate_light"], HORIZONTAL_ALIGNMENT_RIGHT, 140.0)
	_draw_tabs()
	_draw_rows()
	_draw_info()
	_draw_buttons()


func _draw_tabs() -> void:
	var rects: Array[Rect2] = _tab_rects()
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		var active: bool = i == _tab
		var focused: bool = active and _zone == Zone.TABS
		if active:
			_overlay.draw_rect(rect, Color(_palette["dusk"], 0.9))
			_overlay.draw_rect(Rect2(rect.position.x, rect.end.y - 2.0, rect.size.x, 2.0), _palette["lamp_amber"] if focused else _palette["brass"])
		var color: Color = _palette["lamp_amber"] if focused else (_palette["text"] if active else _palette["slate_light"])
		UiText.draw(_overlay, "tag", Vector2(rect.position.x + float(_layout.get("tab_pad_x", 5)), rect.position.y + 10.0), FeelFormat.group_title(_groups[i]), color)
		if _group_changed(_groups[i]):
			_overlay.draw_rect(Rect2(rect.end.x - 4.0, rect.position.y + 1.0, 2.0, 2.0), _palette["lamp_glow"])


func _draw_rows() -> void:
	var rows: Array[Dictionary] = get_rows()
	for i: int in _rows_visible():
		var index: int = _top + i
		if index >= rows.size():
			break
		var knob: Dictionary = rows[index]
		var rect: Rect2 = _row_rect(i)
		var focused: bool = index == _row and _zone == Zone.ROWS
		var baseline: float = rect.position.y + 11.0
		if focused:
			_overlay.draw_rect(rect, Color(_palette["dusk"], 0.8))
			_draw_cursor_arrow(Vector2(float(_layout.get("cursor_x", 3)), rect.position.y + rect.size.y / 2.0))
		var changed: bool = _is_changed(knob)
		if changed:
			_overlay.draw_rect(Rect2(float(_layout.get("pip_x", 14)), rect.position.y + rect.size.y / 2.0 - 1.0, 3.0, 3.0), _palette["lamp_glow"])
		var color: Color = _palette["lamp_amber"] if focused else _palette["text"]
		UiText.draw(_overlay, "menu", Vector2(float(_layout["label_x"]), baseline), FeelFormat.label_of(knob), color)
		var value: Variant = _read(knob)
		var value_color: Color = _palette["lamp_glow"] if changed else _palette["text"]
		var value_right: float = float(_layout["value_right"])
		if FeelFormat.is_slider(knob):
			_draw_slider(knob, i, float(value), focused)
			UiText.draw(_overlay, "menu", Vector2(value_right - 80.0, baseline), FeelFormat.value_text(knob, value), value_color, HORIZONTAL_ALIGNMENT_RIGHT, 80.0)
		else:
			var text: String = FeelFormat.value_text(knob, value)
			if FeelFormat.kind_of(knob) == FeelFormat.KIND_BOOL:
				value_color = SandboxUiData.color("good") if bool(value) else _palette["text_dim"]
			UiText.draw(_overlay, "menu", Vector2(value_right - 150.0, baseline), text, value_color, HORIZONTAL_ALIGNMENT_RIGHT, 150.0)
			if focused:
				var text_w: float = float(UiFonts.text_width("menu", text))
				var mid: float = rect.position.y + rect.size.y / 2.0
				_draw_arrow(Vector2(value_right - text_w - 8.0, mid), -1, _palette["lamp_amber"])
				_draw_arrow(Vector2(value_right + 3.0, mid), 1, _palette["lamp_amber"])
	_draw_scroll_arrows(rows.size())


func _draw_cursor_arrow(center: Vector2) -> void:
	for i: int in 4:
		_overlay.draw_rect(Rect2(center.x + float(i), center.y - float(3 - i), 1.0, float((3 - i) * 2 + 1)), _palette["lamp_amber"])


func _draw_arrow(center: Vector2, direction: int, color: Color) -> void:
	for i: int in 3:
		var x: float = center.x + float(i * direction)
		_overlay.draw_rect(Rect2(x, center.y - float(2 - i), 1.0, float((2 - i) * 2 + 1)), color)


func _draw_slider(knob: Dictionary, visible_index: int, value: float, focused: bool) -> void:
	var track: Rect2 = _slider_rect(visible_index)
	_overlay.draw_rect(track.grow(1.0), _palette["ink"])
	_overlay.draw_rect(track, _palette["night"])
	var along: float = FeelFormat.fraction(knob, value)
	var fill_w: float = roundf(track.size.x * along)
	if fill_w > 0.0:
		_overlay.draw_rect(Rect2(track.position, Vector2(fill_w, track.size.y)), _palette["lamp_amber"] if focused else _palette["brass"])
		_overlay.draw_rect(Rect2(track.position, Vector2(fill_w, 1.0)), Color(_palette["lamp_glow"], 0.8))
	var default_value: Variant = _defaults.get(str(knob["id"]))
	if default_value != null:
		var notch_x: float = track.position.x + roundf(track.size.x * FeelFormat.fraction(knob, float(default_value)))
		_overlay.draw_rect(Rect2(notch_x - 1.0, track.position.y - 3.0, 2.0, track.size.y + 6.0), _palette["chalk"])
		_overlay.draw_rect(Rect2(notch_x - 1.0, track.position.y - 3.0, 2.0, 1.0), _palette["ink"])
	var handle_x: float = track.position.x + fill_w
	_overlay.draw_rect(Rect2(handle_x - 1.0, track.position.y - 2.0, 3.0, track.size.y + 4.0), _palette["ink"])
	_overlay.draw_rect(Rect2(handle_x, track.position.y - 1.0, 1.0, track.size.y + 2.0), _palette["lamp_glow"] if focused else _palette["chalk"])


func _draw_scroll_arrows(count: int) -> void:
	var x: float = _overlay.size.x - 14.0
	if _top > 0:
		_overlay.draw_rect(Rect2(x + 2.0, float(_layout["row_y"]) - 3.0, 1.0, 1.0), _palette["lamp_amber"])
		_overlay.draw_rect(Rect2(x + 1.0, float(_layout["row_y"]) - 2.0, 3.0, 1.0), _palette["lamp_amber"])
	if _top + _rows_visible() < count:
		var y: float = float(_layout["row_y"]) + float(_rows_visible()) * float(_layout["row_h"]) + 1.0
		_overlay.draw_rect(Rect2(x + 1.0, y, 3.0, 1.0), _palette["lamp_amber"])
		_overlay.draw_rect(Rect2(x + 2.0, y + 1.0, 1.0, 1.0), _palette["lamp_amber"])


## The three lines of the info area (hint, default and range, message).
func get_info_lines() -> Array[String]:
	var lines: Array[String] = ["", "", ""]
	if _zone == Zone.BUTTONS:
		lines[0] = SandboxUiData.text("feel.button_hints.%s" % BUTTON_IDS[_button])
	elif _zone == Zone.TABS:
		lines[0] = SandboxUiData.text("feel.move_hint")
	else:
		var knob: Dictionary = get_cursor_knob()
		if not knob.is_empty():
			lines[0] = FeelFormat.hint_of(knob)
			var default_value: Variant = _defaults.get(str(knob["id"]))
			var default_text: String = FeelFormat.value_text(knob, default_value) if default_value != null else ""
			var line: String = SandboxUiData.fmt(SandboxUiData.text("feel.default_line"), {"value": default_text})
			if FeelFormat.is_slider(knob):
				line += "    " + SandboxUiData.fmt(SandboxUiData.text("feel.range_line"), {
					"min": FeelFormat.number_text(knob, FeelFormat.min_of(knob)),
					"max": FeelFormat.value_text(knob, FeelFormat.max_of(knob)),
				})
			elif FeelFormat.kind_of(knob) == FeelFormat.KIND_CHOICE:
				var meaning: String = FeelFormat.choice_hint_of(knob, str(_read(knob)))
				if not meaning.is_empty():
					line = meaning + "    " + line
			lines[1] = line
	lines[2] = _message
	return lines


func _draw_info() -> void:
	var top: float = float(_layout["info_y"])
	var lines: Array[String] = get_info_lines()
	_overlay.draw_rect(Rect2(8.0, top - 2.0, _overlay.size.x - 16.0, 1.0), Color(_palette["slate"], 0.6))
	UiText.draw(_overlay, "tag", Vector2(14, top + 9.0), lines[0], _palette["text"])
	UiText.draw(_overlay, "tag", Vector2(14, top + 20.0), lines[1], _palette["slate_light"])
	var message_color: Color = SandboxUiData.color("good") if _message_good else SandboxUiData.color("warn")
	if not _message.is_empty():
		UiText.draw(_overlay, "tag", Vector2(14, top + 31.0), lines[2], message_color)
	else:
		UiText.draw(_overlay, "tag", Vector2(14, top + 31.0), SandboxUiData.text("feel.move_hint"), _palette["text_dim"])


func _draw_buttons() -> void:
	var rects: Array[Rect2] = _button_rects()
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		var focused: bool = i == _button and _zone == Zone.BUTTONS
		_overlay.draw_rect(rect.grow(1.0), _palette["ink"])
		_overlay.draw_rect(rect, _palette["dusk"] if focused else _palette["night"])
		if focused:
			_overlay.draw_rect(Rect2(rect.position.x, rect.end.y - 2.0, rect.size.x, 2.0), _palette["lamp_amber"])
		var label: String = SandboxUiData.text("feel.buttons.%s" % BUTTON_IDS[i])
		var color: Color = _palette["lamp_amber"] if focused else _palette["text"]
		UiText.draw(_overlay, "menu", Vector2(rect.position.x + float(_layout.get("button_pad_x", 7)), rect.position.y + 11.0), label, color)
