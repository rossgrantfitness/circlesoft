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
## Where Save writes (passed to the knobs' save_user). Empty: the knobs' own folder, user://feel. Tests set it.
var save_dir: String = ""
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
var _tab_first: int = 0   ## first tab shown when the strip has to scroll
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
var _reveal: float = 1.0

var _dim: ColorRect = null
var _overlay: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layout = SandboxUiData.ui("feel_panel", {})
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = Color(SandboxStyle.color("dim"), float(_layout.get("dim_alpha", 0.5)))
	_dim.size = size
	add_child(_dim)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = size
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_fit()
	if get_parent() is Control:
		(get_parent() as Control).resized.connect(_fit)
	visible = false
	set_process(not manual_ticks)


func _exit_tree() -> void:
	if _open and pause_game:
		SandboxPauseGate.release(get_tree(), self)


## Sizes itself to the UI space it lives in and centers its reference-sized layout there.
func _fit() -> void:
	size = SandboxStyle.ui_size(self)
	if _dim != null:
		_dim.size = size
	if _overlay != null:
		_overlay.size = Vector2(SandboxStyle.REFERENCE_SIZE)
		_overlay.position = SandboxStyle.center_offset(self)


# ---- binding ----

## Connects the panel to the knobs. `meta` is the knob list to show (default: knobs.knobs(), else the
## list in data/combat/feel.json); `defaults` maps knob id -> studio default (default: the knob's own
## "default", else its value in data/combat/feel.json, else the value the knobs have right now).
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
	_defaults = defaults.duplicate()
	var studio: Dictionary = _studio_defaults()
	for knob: Dictionary in _meta:
		var id: String = str(knob["id"])
		if not _defaults.has(id):
			_defaults[id] = knob.get("default", studio.get(id, _read(knob)))
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
	_reveal = 0.25 if animations_enabled else 1.0
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
	if animations_enabled and _reveal < 1.0:
		var steps: int = int(_layout.get("open_steps", 4))
		var step_s: float = SandboxUiData.ui_float("step_s", 0.0833)
		_reveal = minf(1.0, 0.25 + 0.75 * float(int(_open_clock / step_s) + 1) / float(steps))
		_overlay.queue_redraw()
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
		path = str(knobs.call("save_user", save_dir)) if not save_dir.is_empty() else str(knobs.call("save_user"))
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
	return _overlay.get_global_transform_with_canvas().affine_inverse() * stage_point


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
		return _panel_rect().has_point(at)
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
	return _panel_rect().has_point(at)


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


# ---- layout helpers (stage pixels) ----

func _left() -> float:
	return float(_layout["x"])


func _width() -> float:
	return float(_layout["w"])


func _panel_rect() -> Rect2:
	var top: float = float(_layout["header_y"])
	return Rect2(_left(), top, _width(), float(_layout["button_y"]) + float(_layout["button_h"]) - top)


func _rows_visible() -> int:
	return int(_layout.get("rows_visible", 7))


func _scroll_to_row() -> void:
	if _row < _top:
		_top = _row
	elif _row >= _top + _rows_visible():
		_top = _row - _rows_visible() + 1
	_top = clampi(_top, 0, maxi(0, get_rows().size() - _rows_visible()))


func _row_rect(visible_index: int) -> Rect2:
	var y: float = float(_layout["row_y"]) + float(visible_index) * float(_layout["row_step"])
	return Rect2(_left(), y, _width(), float(_layout["row_h"]))


func _slider_rect(visible_index: int) -> Rect2:
	var row: Rect2 = _row_rect(visible_index)
	var h: float = float(_layout["slider_h"])
	return Rect2(float(_layout["slider_x"]), row.position.y + roundf((row.size.y - h) / 2.0), float(_layout["slider_w"]), h)


func _row_at(at: Vector2) -> int:
	var rows: Array[Dictionary] = get_rows()
	for i: int in _rows_visible():
		if _top + i >= rows.size():
			break
		if _row_rect(i).has_point(at):
			return _top + i
	return -1


## One rect per group. When every tab fits it is the old even row; with more groups than fit
## (the "Hacks" and "Boss" groups made that happen) the strip scrolls: the tabs outside the window
## get an empty rect on the edge they scrolled off, and the active tab is always inside the window.
func _tab_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var gap: float = float(_layout.get("tab_gap", 2))
	var widths: Array[float] = []
	var text_total: float = 0.0
	for group: String in _groups:
		var text_w: float = SandboxStyle.text_width("label", FeelFormat.group_title(group).to_upper())
		widths.append(text_w)
		text_total += text_w
	var count: int = _groups.size()
	var room: float = _width() - gap * float(maxi(0, count - 1))
	var max_pad: float = float(_layout.get("tab_pad_x", 6))
	var min_pad: float = float(_layout.get("tab_min_pad_x", 3))
	var y: float = float(_layout["tab_y"])
	var h: float = float(_layout["tab_h"])
	var pad: float = clampf((room - text_total) / maxf(1.0, float(count) * 2.0), min_pad, max_pad)
	var needed: float = text_total + pad * 2.0 * float(count)
	if needed <= room + 0.01:
		_tab_first = 0
		var x: float = _left()
		for i: int in count:
			var w: float = widths[i] + pad * 2.0
			out.append(Rect2(x, y, w, h))
			x += w + gap
		return out
	# Scrolling strip at the minimum padding.
	var span: Array[float] = []
	for i: int in count:
		span.append(widths[i] + pad * 2.0)
	_tab_first = clampi(_tab_first, 0, maxi(0, count - 1))
	var last: int = _tab_last_for(_tab_first, span, gap)
	if _tab < _tab_first:
		_tab_first = _tab
		last = _tab_last_for(_tab_first, span, gap)
	while _tab > last and _tab_first < count - 1:
		_tab_first += 1
		last = _tab_last_for(_tab_first, span, gap)
	# Pull the window back when there is empty room on the right.
	while _tab_first > 0 and _tab_strip_w(_tab_first - 1, last, span, gap) <= _width() + 0.01:
		_tab_first -= 1
	var x2: float = _left()
	for i: int in count:
		if i < _tab_first:
			out.append(Rect2(_left(), y, 0.0, h))
		elif i > last:
			out.append(Rect2(_left() + _width(), y, 0.0, h))
		else:
			out.append(Rect2(x2, y, span[i], h))
			x2 += span[i] + gap
	return out


## The last tab index that fits in the strip when it starts at `first`.
func _tab_last_for(first: int, span: Array[float], gap: float) -> int:
	var used: float = 0.0
	var last: int = first
	for i: int in range(first, span.size()):
		var next: float = used + span[i] + (gap if i > first else 0.0)
		if next > _width() + 0.01 and i > first:
			break
		used = next
		last = i
	return last


func _tab_strip_w(first: int, last: int, span: Array[float], gap: float) -> float:
	var total: float = 0.0
	for i: int in range(first, last + 1):
		total += span[i] + (gap if i > first else 0.0)
	return total


func _tab_at(at: Vector2) -> int:
	var rects: Array[Rect2] = _tab_rects()
	for i: int in rects.size():
		if rects[i].size.x > 0.0 and rects[i].has_point(at):
			return i
	return -1


func _button_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var x: float = _left()
	var pad: float = float(_layout.get("button_pad_x", 8))
	for id: String in BUTTON_IDS:
		var w: float = SandboxStyle.text_width("body", SandboxUiData.text("feel.buttons.%s" % id)) + pad * 2.0
		out.append(Rect2(x, float(_layout["button_y"]), w, float(_layout["button_h"])))
		x += w + float(_layout.get("button_gap", 4))
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


# ---- drawing (the look is SandboxStyle's) ----

func _draw_overlay() -> void:
	if not _open or _layout.is_empty():
		return
	var header: Rect2 = Rect2(_left(), float(_layout["header_y"]), _width() * _reveal, float(_layout["header_h"]))
	SandboxStyle.header_bar(_overlay, header)
	if _reveal < 1.0:
		return
	var head_base: float = header.position.y + 12.0
	SandboxStyle.text(_overlay, "body", Vector2(_left() + 8.0, head_base), SandboxUiData.text("feel.title"), SandboxStyle.color("text_on_header"))
	var count: int = get_rows().size()
	if count > 0 and _zone == Zone.ROWS:
		OffsetStat.draw(_overlay, Vector2(_left() + _width() - 8.0, head_base), SandboxUiData.text("feel.knob_count"), str(_row + 1), str(count), SandboxStyle.color("text_on_header"), true)
	else:
		SandboxStyle.text_right(_overlay, "body", _left() + _width() - 8.0, head_base, SandboxUiData.text("feel.paused"), SandboxStyle.color("text_on_header"), 120.0)
	_draw_tabs()
	_draw_rows()
	_draw_info()
	_draw_buttons()


func _draw_tabs() -> void:
	var rects: Array[Rect2] = _tab_rects()
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		if rect.size.x <= 0.0:
			continue
		var active: bool = i == _tab
		SandboxStyle.list_bar(_overlay, rect, active, not active)
		var pad: float = (rect.size.x - SandboxStyle.text_width("label", FeelFormat.group_title(_groups[i]).to_upper())) / 2.0
		SandboxStyle.text(_overlay, "label", Vector2(rect.position.x + pad, rect.position.y + 9.0), FeelFormat.group_title(_groups[i]).to_upper(), SandboxStyle.row_color(active))
		if active and _zone == Zone.TABS:
			SandboxStyle.cursor(_overlay, Vector2(rect.position.x - 1.0, rect.position.y + rect.size.y / 2.0))
		if _group_changed(_groups[i]):
			_overlay.draw_rect(Rect2(rect.end.x - 4.0, rect.position.y + 2.0, 2.0, 2.0), SandboxStyle.color("pip"))
	var mid: float = float(_layout["tab_y"]) + float(_layout["tab_h"]) / 2.0
	var more_left: bool = not rects.is_empty() and rects[0].size.x <= 0.0
	var more_right: bool = not rects.is_empty() and rects.back().size.x <= 0.0
	SandboxStyle.arrow(_overlay, Vector2(_left() - 7.0, mid), Vector2i.LEFT, SandboxStyle.color("pip") if more_left else Color(0, 0, 0, 0))
	SandboxStyle.arrow(_overlay, Vector2(_left() + _width() + 7.0, mid), Vector2i.RIGHT, SandboxStyle.color("pip") if more_right else Color(0, 0, 0, 0))


func _draw_rows() -> void:
	var rows: Array[Dictionary] = get_rows()
	for i: int in _rows_visible():
		var index: int = _top + i
		if index >= rows.size():
			break
		var knob: Dictionary = rows[index]
		var rect: Rect2 = _row_rect(i)
		var focused: bool = index == _row and _zone == Zone.ROWS
		SandboxStyle.list_bar(_overlay, rect, focused)
		var mid: float = rect.position.y + rect.size.y / 2.0
		if focused:
			SandboxStyle.cursor(_overlay, Vector2(float(_layout.get("cursor_x", 5)), mid))
		var changed: bool = _is_changed(knob)
		if changed:
			_overlay.draw_rect(Rect2(float(_layout.get("pip_x", 14)), mid - 1.0, 3.0, 3.0), SandboxStyle.color("pip"))
		var baseline: float = rect.position.y + 11.0
		SandboxStyle.text(_overlay, "body", Vector2(float(_layout["label_x"]), baseline), FeelFormat.label_of(knob), SandboxStyle.row_color(focused))
		var value: Variant = _read(knob)
		var value_color: Color = SandboxStyle.color("pip") if changed else SandboxStyle.color("text")
		var value_right: float = float(_layout["value_right"])
		if FeelFormat.is_slider(knob):
			_draw_slider(knob, i, float(value), focused)
			SandboxStyle.text_right(_overlay, "digits", value_right, baseline, FeelFormat.value_text(knob, value), value_color, 84.0)
		else:
			var text: String = FeelFormat.value_text(knob, value)
			if FeelFormat.kind_of(knob) == FeelFormat.KIND_BOOL:
				value_color = SandboxStyle.color("good") if bool(value) else SandboxStyle.color("text_dim")
			SandboxStyle.text_right(_overlay, "body", value_right, baseline, text, value_color, 150.0)
			if focused:
				var text_w: float = SandboxStyle.text_width("body", text)
				SandboxStyle.arrow(_overlay, Vector2(value_right - text_w - 7.0, mid), Vector2i.LEFT)
				SandboxStyle.arrow(_overlay, Vector2(value_right + 7.0, mid), Vector2i.RIGHT)
	var arrow_x: float = _left() + _width() + 7.0
	var first_y: float = float(_layout["row_y"])
	if _top > 0:
		SandboxStyle.arrow(_overlay, Vector2(arrow_x, first_y + 5.0), Vector2i.UP)
	if _top + _rows_visible() < rows.size():
		SandboxStyle.arrow(_overlay, Vector2(arrow_x, first_y + float(_rows_visible()) * float(_layout["row_step"]) - 6.0), Vector2i.DOWN)


func _draw_slider(knob: Dictionary, visible_index: int, value: float, focused: bool) -> void:
	var track: Rect2 = _slider_rect(visible_index)
	var top: Color = SandboxStyle.color("slider_focus_top" if focused else "slider_top")
	var bottom: Color = SandboxStyle.color("slider_focus_bottom" if focused else "slider_bottom")
	var along: float = FeelFormat.fraction(knob, value)
	SandboxStyle.thin_bar(_overlay, track, along, top, bottom)
	var default_value: Variant = _defaults.get(str(knob["id"]))
	if default_value != null:
		var notch_x: float = track.position.x + roundf(track.size.x * FeelFormat.fraction(knob, float(default_value)))
		_overlay.draw_rect(Rect2(notch_x, track.position.y - 3.0, 1.0, track.size.y + 6.0), SandboxStyle.color("notch"))
	var handle_x: float = track.position.x + floorf(track.size.x * along)
	_overlay.draw_rect(Rect2(handle_x - 1.0, track.position.y - 2.0, 3.0, track.size.y + 4.0), SandboxStyle.color("track_edge"))
	_overlay.draw_rect(Rect2(handle_x, track.position.y - 1.0, 1.0, track.size.y + 2.0), SandboxStyle.color("text_light") if focused else SandboxStyle.color("text"))


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
	var lines: Array[String] = get_info_lines()
	var top: float = float(_layout["info_y"])
	SandboxStyle.label(_overlay, Vector2(_left() + 2.0, float(_layout["info_label_y"])), SandboxUiData.text("feel.info_label"))
	SandboxStyle.list_bar(_overlay, Rect2(_left(), top, _width(), float(_layout["info_h"])))
	SandboxStyle.text(_overlay, "body", Vector2(_left() + 8.0, top + 12.0), lines[0], SandboxStyle.color("text"))
	if not _message.is_empty():
		var tint: Color = SandboxStyle.color("good") if _message_good else SandboxStyle.color("warn")
		SandboxStyle.text(_overlay, "label", Vector2(_left() + 8.0, top + 24.0), lines[2], tint)
	else:
		SandboxStyle.text(_overlay, "label", Vector2(_left() + 8.0, top + 24.0), lines[1].to_upper(), SandboxStyle.color("label_dim"))


func _draw_buttons() -> void:
	var rects: Array[Rect2] = _button_rects()
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		var focused: bool = i == _button and _zone == Zone.BUTTONS
		SandboxStyle.list_bar(_overlay, rect, focused)
		var pad: float = float(_layout.get("button_pad_x", 8))
		SandboxStyle.text(_overlay, "body", Vector2(rect.position.x + pad, rect.position.y + 11.0), SandboxUiData.text("feel.buttons.%s" % BUTTON_IDS[i]), SandboxStyle.row_color(focused))
		if focused:
			SandboxStyle.cursor(_overlay, Vector2(rect.position.x + 1.0, rect.position.y + rect.size.y / 2.0))
	var dirty: bool = is_dirty()
	var status: String = SandboxUiData.text("feel.unsaved" if dirty else "feel.saved")
	SandboxStyle.label(_overlay, Vector2(_left() + _width() - SandboxStyle.text_width("label", status.to_upper()) - 2.0, float(_layout["info_label_y"])), status, SandboxStyle.color("pip") if dirty else SandboxStyle.color("label_dim"))
