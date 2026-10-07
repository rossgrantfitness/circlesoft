class_name ConfigScreen
extends Control
## The Config screen, shared by the title screen and the field menu's Config page.
##
## Rows (data/ui/config_screen.json): Auto-Timing, Wide Windows, Timing Offset, Tap-Along Test,
## Text Speed, Auto-Advance, Skip Seen Cutscenes, Master / Music / SFX / Voice volume, Controls
## (button remap, keyboard and controller) and Vibration. Everything is stored in the Config
## autoload and saved to user://config.json on every change. Strings are in data/text/config.json.
##
## Using it:
##   var screen: ConfigScreen = ConfigScreen.new()
##   screen.size = Vector2(352, 200)        # any size from about 268x144 up; it lays itself out
##   parent.add_child(screen)               # a node on the 384x216 UI stage
##   screen.closed.connect(on_config_closed)
##   screen.open()
## Input: set `listen_input = true` to let it read input itself (it must live on the UiStage, whose
## mouse positions are already in stage pixels), or forward events yourself with handle_event()
## (mouse positions in stage pixels, like MenuList). `closed` fires when the player backs out of the
## top level. `is_busy()` is true while a sub-page (Controls, a button capture, the tap-along test)
## is up, so the owner knows Cancel will not close the screen. Set `show_frame = false` when the
## owner already draws a window, and `show_title = false` when it draws its own title.
##
## The tap-along test flashes and dings on a steady beat while the player taps; TapAlong turns the
## taps into a suggested Timing Offset, and the player can accept it with one press.

signal opened
## The player backed out of the top level. The owner should hide or free the screen.
signal closed
## A setting changed (the Config key, for example "text_speed").
signal setting_changed(key: String)
## The tap-along test finished with this result dictionary (see TapAlong.suggest).
signal tap_test_finished(result: Dictionary)

enum State { CLOSED, OPENING, LIST, CONTROLS, CAPTURE, TAP_INTRO, TAP_RUN, TAP_RESULT }

const UI_ID: String = "ui/config_screen"
const TEXT_ID: String = "text/config"
const THEME_ID: String = "ui/ui_theme"
const DIALOGUE_ID: String = "ui/dialogue_ui"
const CONFIG_PATH: NodePath = ^"/root/Config"
const KEY_NONE_CODE: int = 0

## Where the settings live. Null means the Config autoload (tests pass their own copy).
var config: Node = null
var audio: UiAudio = UiAudio.new():
	set(value):
		audio = value
		for list: MenuList in [_list, _controls_list, _result_list]:
			if list != null:
				list.audio = value
## Off: the screen does not run itself; the owner (or a test) calls tick(delta).
var manual_ticks: bool = false
## On: read input in _input (see the class comment).
var listen_input: bool = false
var show_frame: bool = true
var show_title: bool = true
## Off: ignores input (the owner has another widget in front).
var active: bool = true
## Milliseconds clock for the tap-along test. Tests replace it; the default is the system clock.
var clock_ms: Callable = Callable()

var _ui: Dictionary = {}
var _text: Dictionary = {}
var _palette: Dictionary[String, Color] = {}
var _rows: Array[Dictionary] = []
var _state: State = State.CLOSED
var _input_map: MenuInput = MenuInput.new()
var _step_s: float = 0.0833
var _open_clock: float = 0.0
var _anim_clock: float = 0.0

var _window: UiWindow = null
var _list: MenuList = null
var _controls_list: MenuList = null
var _result_list: MenuList = null
var _overlay: Control = null

var _preview: TypeWriter = TypeWriter.new()
var _preview_wait: float = 0.0
var _preview_row: String = ""

var _control_ids: Array[String] = []
var _control_col: int = 0
var _capture_group: String = ""
var _capture_kind: String = ""
var _capture_left: float = 0.0
var _message: String = ""
var _message_left: float = 0.0

var _tap_start_ms: float = 0.0
var _tap_beats: Array[float] = []
var _tap_taps: Array[float] = []
var _tap_next_beat: int = 0
var _tap_flash_left: float = 0.0
var _tap_last_delta: float = NAN
var _tap_done_at_ms: float = 0.0
var _tap_result: Dictionary = {}
var _tap_result_message: String = ""


func _ready() -> void:
	_ui = DataDB.get_dict(UI_ID)
	_text = DataDB.get_dict(TEXT_ID)
	var theme_data: Dictionary = DataDB.get_dict(THEME_ID)
	for key: String in theme_data["palette"]:
		_palette[key] = Color.html(str(theme_data["palette"][key]))
	_step_s = float(theme_data["timing"]["ui_step_s"])
	for row: Variant in _ui["rows"]:
		_rows.append(row as Dictionary)
	for row: Variant in _ui["controls"]["rows"]:
		_control_ids.append(str((row as Dictionary)["id"]))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window = UiWindow.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window)
	_list = _make_list("List")
	_list.activated.connect(_on_row_activated)
	_list.cursor_moved.connect(_on_row_moved)
	_controls_list = _make_list("ControlsList")
	_controls_list.activated.connect(_on_control_activated)
	_controls_list.cursor_moved.connect(func(_i: int) -> void: _overlay.queue_redraw())
	_result_list = _make_list("ResultList")
	_result_list.activated.connect(_on_result_activated)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	resized.connect(_layout)
	_layout()
	visible = false
	set_process(not manual_ticks)


func _make_list(list_name: String) -> MenuList:
	var list: MenuList = MenuList.new()
	list.name = list_name
	list.audio = audio
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.visible = false
	add_child(list)
	return list


# ---- layout ----

func _layout() -> void:
	if _window == null:
		return
	_window.size = size
	_window.visible = show_frame
	_overlay.size = size
	var pad: int = int(_ui["list_pad"])
	var title_h: int = int(_ui["title_height"]) if show_title else pad
	var row_h: int = int(_ui["row_height"])
	var rows: int = maxi(2, (int(size.y) - title_h - int(_ui["info_height"]) - pad) / row_h)
	for list: MenuList in [_list, _controls_list]:
		list.position = Vector2(pad, title_h)
		list.size = Vector2(size.x - pad * 2, rows * row_h + pad * 2)
		list.visible_rows = rows
		list.row_height = row_h
		list.first_row_y = pad
		list.text_x = int(_ui["text_x"])
		list.cursor_x = int(_ui["cursor_x"])
		list.value_pad = int(_ui["value_pad"])
	_result_list.row_height = row_h
	_result_list.first_row_y = 2
	_result_list.text_x = int(_ui["text_x"])
	_result_list.cursor_x = int(_ui["cursor_x"])
	_result_list.visible_rows = 3
	_result_list.size = Vector2(size.x - pad * 2, 3 * row_h + 4)
	_result_list.position = Vector2(pad, title_h + 38)
	_overlay.queue_redraw()


func _info_top() -> int:
	return int(size.y) - int(_ui["info_height"])


# ---- opening and closing ----

## Shows the screen at the top level. `instant` skips the window-opening animation.
func open(instant: bool = false) -> void:
	if _state != State.CLOSED:
		return
	visible = true
	_state = State.OPENING
	_open_clock = 0.0
	_window.open_amount = 1.0 if instant else 0.0
	_refresh_rows(false)
	_preview_row = ""
	_apply_state_visibility()
	if instant:
		_finish_opening()
	_overlay.queue_redraw()


func _finish_opening() -> void:
	_window.open_amount = 1.0
	_state = State.LIST
	_apply_state_visibility()
	_restart_preview()
	opened.emit()
	_overlay.queue_redraw()


## Leaves the screen (saves first) and emits `closed`.
func close() -> void:
	if _state == State.CLOSED:
		return
	_save()
	_state = State.CLOSED
	visible = false
	_apply_state_visibility()
	closed.emit()


func is_open() -> bool:
	return _state != State.CLOSED


## True while a sub-page is up (Cancel goes back one level instead of closing).
func is_busy() -> bool:
	return _state != State.CLOSED and _state != State.LIST and _state != State.OPENING


func get_state() -> State:
	return _state


func _apply_state_visibility() -> void:
	var ready_to_show: bool = _state != State.CLOSED and _state != State.OPENING
	_list.visible = ready_to_show and _state == State.LIST
	_list.active = _state == State.LIST
	_controls_list.visible = ready_to_show and (_state == State.CONTROLS or _state == State.CAPTURE)
	_controls_list.active = _state == State.CONTROLS
	_result_list.visible = ready_to_show and _state == State.TAP_RESULT
	_result_list.active = _state == State.TAP_RESULT


func _set_state(new_state: State) -> void:
	_state = new_state
	_apply_state_visibility()
	_overlay.queue_redraw()


# ---- the config node ----

func _cfg() -> Node:
	if config != null and is_instance_valid(config):
		return config
	return get_node_or_null(CONFIG_PATH)


func _save() -> void:
	var cfg: Node = _cfg()
	if cfg != null and cfg.has_method("save_file"):
		cfg.call("save_file")


func _now_ms() -> float:
	if clock_ms.is_valid():
		return float(clock_ms.call())
	return float(Time.get_ticks_usec()) / 1000.0


# ---- the rows ----

func get_row_ids() -> Array[String]:
	var ids: Array[String] = []
	for row: Dictionary in _rows:
		ids.append(str(row["id"]))
	return ids


## The list rows as shown: [{id, label, value, enabled}].
func get_row_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for row: Dictionary in _rows:
		var id: String = str(row["id"])
		items.append({"id": id, "label": str(_text["rows"][id]["label"]), "value": _row_value(row), "enabled": true})
	return items


func get_row_value(row_id: String) -> String:
	for row: Dictionary in _rows:
		if str(row["id"]) == row_id:
			return _row_value(row)
	return ""


func get_cursor_row_id() -> String:
	return _list.get_item_id(_list.get_cursor_index()) if _list != null else ""


func get_list() -> MenuList:
	return _list


func get_controls_list() -> MenuList:
	return _controls_list


func get_result_list() -> MenuList:
	return _result_list


func _row_value(row: Dictionary) -> String:
	var cfg: Node = _cfg()
	var id: String = str(row["id"])
	if cfg == null:
		return ""
	match str(row["type"]):
		"toggle":
			return str(_text["on"] if _get_bool(id) else _text["off"])
		"offset":
			return _signed_ms(int(cfg.get("timing_offset_ms")))
		"choice":
			return str(_text["speed_names"].get(str(cfg.get("text_speed")), str(cfg.get("text_speed"))))
		"volume":
			return str(_text["percent_format"]).replace("{n}", str(roundi(float(cfg.call("get_volume", str(row["volume"]))) * 100.0)))
		"action":
			return str(_text["rows"][id].get("value", ""))
	return ""


func _signed_ms(ms: int) -> String:
	var number: String = ("+%d" % ms) if ms > 0 else str(ms)
	return str(_text["ms_format"]).replace("{ms}", number)


func _get_bool(id: String) -> bool:
	var cfg: Node = _cfg()
	match id:
		"auto_timing":
			return bool(cfg.get("auto_timing"))
		"wide_windows":
			return bool(cfg.get("wide_windows"))
		"auto_advance":
			return bool(cfg.get("auto_advance"))
		"skip_seen":
			return bool(cfg.get("skip_seen_cutscenes"))
		"vibration":
			return bool(cfg.get("vibration"))
	return false


func _set_bool(id: String, value: bool) -> String:
	var cfg: Node = _cfg()
	match id:
		"auto_timing":
			cfg.call("set_auto_timing", value)
			return "auto_timing"
		"wide_windows":
			cfg.call("set_wide_windows", value)
			return "wide_windows"
		"auto_advance":
			cfg.call("set_auto_advance", value)
			return "auto_advance"
		"skip_seen":
			cfg.call("set_skip_seen_cutscenes", value)
			return "skip_seen_cutscenes"
		"vibration":
			cfg.call("set_vibration", value)
			return "vibration"
	return ""


func _refresh_rows(keep_index: bool = true) -> void:
	if _list == null:
		return
	_list.set_items(get_row_items(), keep_index)
	_overlay.queue_redraw()


## Changes row `index` one step. Arrows (`wrap` false) stop at the ends and set toggles On / Off;
## Confirm (`wrap` true) flips toggles and wraps sliders and speeds round to the start.
## Returns true when a setting changed.
func change_row(index: int, direction: int, wrap: bool) -> bool:
	var cfg: Node = _cfg()
	if cfg == null or index < 0 or index >= _rows.size():
		return false
	var row: Dictionary = _rows[index]
	var id: String = str(row["id"])
	var changed_key: String = ""
	match str(row["type"]):
		"toggle":
			var target: bool = (not _get_bool(id)) if wrap else direction > 0
			if target != _get_bool(id):
				changed_key = _set_bool(id, target)
		"offset":
			var before: int = int(cfg.get("timing_offset_ms"))
			if not cfg.call("step_timing_offset", direction) and wrap:
				cfg.call("set_timing_offset_ms", int(cfg.call("get_timing_offset_min_ms")) if direction > 0 else int(cfg.call("get_timing_offset_max_ms")))
			if int(cfg.get("timing_offset_ms")) != before:
				changed_key = "timing_offset_ms"
		"choice":
			var before_speed: String = str(cfg.get("text_speed"))
			if not cfg.call("step_text_speed", direction) and wrap:
				var ids: Array = cfg.call("get_text_speed_ids")
				cfg.call("set_text_speed", str(ids[0]) if direction > 0 else str(ids[ids.size() - 1]))
			if str(cfg.get("text_speed")) != before_speed:
				changed_key = "text_speed"
		"volume":
			var steps: int = int(_ui["volume_steps"])
			var level: int = roundi(float(cfg.call("get_volume", str(row["volume"]))) * steps)
			var target_level: int = level + direction
			if wrap and (target_level > steps or target_level < 0):
				target_level = 0 if direction > 0 else steps
			target_level = clampi(target_level, 0, steps)
			if target_level != level:
				cfg.call("set_volume", str(row["volume"]), float(target_level) / float(steps))
				changed_key = "%s_volume" % str(row["volume"])
	if changed_key.is_empty():
		return false
	_after_change(id, changed_key)
	return true


func _after_change(row_id: String, key: String) -> void:
	_save()
	_refresh_rows(true)
	audio.sfx("tick")
	if row_id == "text_speed":
		_restart_preview()
	elif row_id == "voice_volume":
		audio.voice(str(_text["preview"]["speaker"]), "a")
	elif row_id == "vibration" and _get_bool("vibration"):
		_buzz()
	setting_changed.emit(key)


func _buzz() -> void:
	var pads: Array[int] = Input.get_connected_joypads()
	if pads.is_empty():
		return
	var test: Dictionary = _ui["vibration_test"]
	Input.start_joy_vibration(pads[0], float(test["weak"]), float(test["strong"]), float(test["duration_s"]))


func _on_row_activated(index: int) -> void:
	var id: String = str(_rows[index]["id"])
	if id == "tap_along":
		start_tap_along()
	elif id == "controls":
		open_controls()
	else:
		change_row(index, 1, true)


func _on_row_moved(_index: int) -> void:
	_restart_preview()
	_overlay.queue_redraw()


# ---- text speed preview ----

func _restart_preview() -> void:
	var cfg: Node = _cfg()
	if cfg == null or _list == null:
		return
	_preview_row = get_cursor_row_id()
	if _preview_row != "text_speed":
		return
	_preview.start(str(_text["preview"]["text"]), float(cfg.call("get_text_cps")), DataDB.get_value(DIALOGUE_ID, "typing.pauses", {}))
	_preview_wait = 0.0


## The preview line as typed so far (only while the cursor is on Text Speed).
func get_preview_text() -> String:
	return _preview.get_visible_text() if _preview_row == "text_speed" else ""


# ---- time ----

func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if _state == State.CLOSED:
		return
	_anim_clock += delta
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message = ""
			_overlay.queue_redraw()
	match _state:
		State.OPENING:
			_open_clock += delta
			var steps: int = int(_ui["open_steps"])
			var reached: float = minf(1.0, floorf(_open_clock / _step_s) / float(steps))
			_window.open_amount = reached
			if reached >= 1.0:
				_finish_opening()
		State.LIST:
			_tick_preview(delta)
		State.CAPTURE:
			_capture_left -= delta
			if _capture_left <= 0.0:
				_cancel_capture()
		State.TAP_RUN:
			_tick_tap_run(delta)
	_overlay.queue_redraw()


func _tick_preview(delta: float) -> void:
	if _preview_row != "text_speed":
		if get_cursor_row_id() == "text_speed":
			_restart_preview()
		return
	if _preview.is_done():
		_preview_wait += delta
		if _preview_wait > 1.4:
			_restart_preview()
	else:
		_preview.advance(delta)


# ---- input ----

func _input(event: InputEvent) -> void:
	if listen_input and active and handle_event(event):
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


## Gives the screen one input event. Returns true when it used it. Mouse positions must be in
## stage pixels.
func handle_event(event: InputEvent) -> bool:
	if _state == State.CLOSED or _state == State.OPENING or not active:
		return false
	if _state == State.CAPTURE:
		return _event_capture(event)
	if _state == State.TAP_RUN:
		return _event_tap_run(event)
	if event is InputEventMouse:
		return _event_mouse(event)
	var command: MenuInput.Cmd = _input_map.classify(event)
	if command == MenuInput.Cmd.NONE:
		return false
	return handle_command(command)


## A menu command (up / down / left / right / confirm / cancel) for whichever page is up.
func handle_command(command: MenuInput.Cmd) -> bool:
	if _state == State.CLOSED or _state == State.OPENING or not active:
		return false
	match _state:
		State.LIST:
			return _command_list(command)
		State.CONTROLS:
			return _command_controls(command)
		State.TAP_INTRO:
			if command == MenuInput.Cmd.CONFIRM:
				_begin_tap_run()
				return true
			if command == MenuInput.Cmd.CANCEL:
				_back_to_list()
				return true
		State.TAP_RESULT:
			if command == MenuInput.Cmd.CANCEL:
				_back_to_list()
				return true
			return _result_list.handle_command(command)
	return false


func _command_list(command: MenuInput.Cmd) -> bool:
	match command:
		MenuInput.Cmd.LEFT:
			change_row(_list.get_cursor_index(), -1, false)
			return true
		MenuInput.Cmd.RIGHT:
			change_row(_list.get_cursor_index(), 1, false)
			return true
		MenuInput.Cmd.CANCEL:
			audio.sfx("back")
			close()
			return true
	return _list.handle_command(command)


func _command_controls(command: MenuInput.Cmd) -> bool:
	match command:
		MenuInput.Cmd.LEFT:
			_set_control_col(0)
			return true
		MenuInput.Cmd.RIGHT:
			_set_control_col(1)
			return true
		MenuInput.Cmd.CANCEL:
			audio.sfx("back")
			_back_to_list()
			return true
	return _controls_list.handle_command(command)


func _event_mouse(event: InputEvent) -> bool:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		return handle_command(MenuInput.Cmd.CANCEL)
	match _state:
		State.LIST:
			return _list.handle_mouse(event)
		State.CONTROLS:
			if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				_set_control_col(1 if _local_x(button.position) >= _pad_col_x() - 4.0 else 0)
			return _controls_list.handle_mouse(event)
		State.TAP_INTRO:
			if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				_begin_tap_run()
				return true
		State.TAP_RESULT:
			return _result_list.handle_mouse(event)
	return false


func _local_x(stage_point: Vector2) -> float:
	return (get_global_transform().affine_inverse() * stage_point).x


func _back_to_list() -> void:
	_set_state(State.LIST)
	_message = ""
	_restart_preview()


# ---- controls (remap) ----

func open_controls() -> void:
	if _state != State.LIST:
		return
	_control_col = 0
	_message = ""
	_refresh_control_items()
	_controls_list.set_index(0, false)
	_set_state(State.CONTROLS)


func get_control_ids() -> Array[String]:
	return _control_ids


## The column being edited on the Controls page: 0 keyboard, 1 controller.
func get_control_column() -> int:
	return _control_col


func _refresh_control_items() -> void:
	var items: Array[Dictionary] = []
	for id: String in _control_ids:
		items.append({"id": id, "label": str(_text["controls"]["rows"][id]["label"]), "enabled": true})
	items.append({"id": "reset", "label": str(_text["controls"]["reset"]), "enabled": true})
	_controls_list.set_items(items, true)
	_overlay.queue_redraw()


func _set_control_col(col: int) -> void:
	if _controls_list.get_item_id(_controls_list.get_cursor_index()) == "reset":
		return
	if col != _control_col:
		_control_col = col
		audio.sfx("tick")
		_overlay.queue_redraw()


func _on_control_activated(index: int) -> void:
	var id: String = _controls_list.get_item_id(index)
	if id == "reset":
		var cfg: Node = _cfg()
		if cfg != null:
			cfg.call("clear_bindings")
		_save()
		_show_message(str(_text["controls"]["reset_done"]))
		setting_changed.emit("bindings")
		_overlay.queue_redraw()
		return
	begin_capture(id, "pad" if _control_col == 1 else "key")


## Starts waiting for a new key ("key") or controller button ("pad") for a control group.
func begin_capture(group: String, kind: String) -> void:
	_capture_group = group
	_capture_kind = kind
	_capture_left = float(_ui["controls"]["capture_timeout_s"])
	_message = ""
	_set_state(State.CAPTURE)


func get_capture_group() -> String:
	return _capture_group


func get_capture_kind() -> String:
	return _capture_kind


func _cancel_capture() -> void:
	if _state == State.CAPTURE:
		audio.sfx("back")
		_set_state(State.CONTROLS)


func _event_capture(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_capture()
			return true
		return click.pressed
	if event is InputEventMouse:
		return false
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.pressed or key.echo:
			return true
		var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code == KEY_ESCAPE:
			_cancel_capture()
		elif _capture_kind == "key":
			commit_binding(code)
		return true
	if event is InputEventJoypadButton:
		var pad: InputEventJoypadButton = event as InputEventJoypadButton
		if pad.pressed and _capture_kind == "pad":
			commit_binding(pad.button_index)
		return true
	return false


## Binds the code being captured (what pressing the new key or button does). Reserved codes are
## refused with a message and the capture stays open.
func commit_binding(code: int) -> void:
	if _state != State.CAPTURE:
		return
	var cfg: Node = _cfg()
	if cfg == null:
		return
	if InputRemap.is_reserved(_capture_kind, code):
		audio.sfx("back")
		_show_message(str(_text["controls"]["reserved"]))
		return
	var swapped_with: String = str(cfg.call("set_binding", _capture_group, _capture_kind, code))
	audio.sfx("confirm")
	if swapped_with.is_empty():
		_show_message(str(_text["controls"]["bound"]))
	else:
		_show_message(str(_text["controls"]["swapped"]).replace("{label}", str(_text["controls"]["rows"][swapped_with]["label"])))
	_save()
	setting_changed.emit("bindings")
	_set_state(State.CONTROLS)


func get_message() -> String:
	return _message


func _show_message(message: String) -> void:
	_message = message
	_message_left = 3.0
	_overlay.queue_redraw()


func _pad_col_x() -> float:
	return size.x - float(_ui["value_pad"]) - float(_ui["controls"]["pad_col_w"])


func _key_col_x() -> float:
	return _pad_col_x() - float(_ui["controls"]["key_col_w"])


# ---- tap-along test ----

func start_tap_along() -> void:
	if _state != State.LIST:
		return
	_tap_result = {}
	_set_state(State.TAP_INTRO)


func get_tap_result() -> Dictionary:
	return _tap_result


## The beats that have flashed so far, as clock milliseconds.
func get_tap_beats() -> Array[float]:
	return _tap_beats


func get_tap_taps() -> Array[float]:
	return _tap_taps


func _tap_params() -> Dictionary:
	return _ui["tap_along"]


func _begin_tap_run() -> void:
	_tap_beats.clear()
	_tap_taps.clear()
	_tap_next_beat = 0
	_tap_flash_left = 0.0
	_tap_last_delta = NAN
	_tap_start_ms = _now_ms()
	_tap_done_at_ms = 0.0
	audio.sfx("confirm")
	_set_state(State.TAP_RUN)


func _beat_time_ms(index: int) -> float:
	var params: Dictionary = _tap_params()
	return _tap_start_ms + (float(params["lead_in_s"]) + float(index) * float(params["interval_s"])) * 1000.0


func _tick_tap_run(delta: float) -> void:
	var params: Dictionary = _tap_params()
	var now: float = _now_ms()
	_tap_flash_left = maxf(0.0, _tap_flash_left - delta)
	var total: int = int(params["beats"])
	while _tap_next_beat < total and now >= _beat_time_ms(_tap_next_beat):
		# The flash and the ding go out on the same frame; that moment is the beat's time.
		_tap_beats.append(now)
		_tap_next_beat += 1
		_tap_flash_left = float(params["flash_s"])
		audio.sfx_id(str(params["sfx"]))
	if _tap_next_beat >= total and now >= _tap_beats[total - 1] + float(params["interval_s"]) * 1000.0 * 0.75:
		_finish_tap_run()


func _event_tap_run(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if not click.pressed:
			return false
		if click.button_index == MOUSE_BUTTON_RIGHT:
			_back_to_list()
		elif click.button_index == MOUSE_BUTTON_LEFT:
			register_tap()
		return true
	if event is InputEventMouse:
		return false
	if _input_map.classify(event) == MenuInput.Cmd.CANCEL and event.is_action_pressed(&"cancel"):
		_back_to_list()
		return true
	for action: Variant in _tap_params()["tap_actions"]:
		if InputMap.has_action(str(action)) and event.is_action_pressed(str(action)):
			register_tap()
			return true
	return event is InputEventKey or event is InputEventJoypadButton


## Records a tap right now. (What a press on the flash does.)
func register_tap() -> void:
	if _state != State.TAP_RUN:
		return
	var now: float = _now_ms()
	_tap_taps.append(now)
	if not _tap_beats.is_empty():
		var nearest: float = INF
		var last_delta: float = NAN
		for beat: float in _tap_beats:
			if absf(now - beat) < absf(nearest):
				nearest = now - beat
				last_delta = nearest
		if absf(last_delta) <= float(_tap_params()["max_match_ms"]):
			_tap_last_delta = last_delta
	_overlay.queue_redraw()


func _finish_tap_run() -> void:
	set_tap_result_from_taps()
	_set_state(State.TAP_RESULT)


## Works out the suggestion from the beats and taps recorded so far and builds the result list.
func set_tap_result_from_taps() -> void:
	var params: Dictionary = _tap_params()
	var cfg: Node = _cfg()
	var step: int = int(cfg.call("get_timing_offset_step_ms")) if cfg != null else 10
	var min_ms: int = int(cfg.call("get_timing_offset_min_ms")) if cfg != null else -200
	var max_ms: int = int(cfg.call("get_timing_offset_max_ms")) if cfg != null else 200
	var deltas: Array[float] = TapAlong.match_taps(_tap_beats, _tap_taps, float(params["max_match_ms"]))
	_tap_result = TapAlong.suggest(deltas, params, step, min_ms, max_ms)
	var words: Dictionary = _text["tap_along"]
	var items: Array[Dictionary] = []
	if bool(_tap_result["ok"]):
		var ms: int = int(_tap_result["offset_ms"])
		items.append({"id": "use", "label": str(words["use"]).replace("{ms}", _signed_number(ms)), "enabled": true})
	items.append({"id": "retry", "label": str(words["retry"]), "enabled": true})
	items.append({"id": "back", "label": str(words["back"]), "enabled": true})
	_result_list.visible_rows = items.size()
	_result_list.size.y = items.size() * _result_list.row_height + 4
	_result_list.set_items(items, false)
	tap_test_finished.emit(_tap_result)


func _signed_number(ms: int) -> String:
	return ("+%d" % ms) if ms > 0 else str(ms)


func _on_result_activated(index: int) -> void:
	var id: String = _result_list.get_item_id(index)
	match id:
		"use":
			var cfg: Node = _cfg()
			if cfg != null:
				cfg.call("set_timing_offset_ms", int(_tap_result["offset_ms"]))
			_save()
			_refresh_rows(true)
			_show_message(str(_text["tap_along"]["applied"]).replace("{ms}", _signed_number(int(_tap_result["offset_ms"]))))
			setting_changed.emit("timing_offset_ms")
			_back_to_list()
		"retry":
			_set_state(State.TAP_INTRO)
		_:
			_back_to_list()


# ---- drawing ----

func _draw_overlay() -> void:
	if _state == State.CLOSED or _state == State.OPENING or _ui.is_empty():
		return
	match _state:
		State.LIST:
			_draw_title(str(_text["title"]))
			_draw_volume_bars()
			_draw_list_info()
		State.CONTROLS, State.CAPTURE:
			_draw_title(str(_text["controls"]["title"]))
			_draw_control_cells()
			_draw_controls_info()
		State.TAP_INTRO:
			_draw_title(str(_text["tap_along"]["title"]))
			_draw_tap_intro()
		State.TAP_RUN:
			_draw_title(str(_text["tap_along"]["title"]))
			_draw_tap_run()
		State.TAP_RESULT:
			_draw_title(str(_text["tap_along"]["title"]))
			_draw_tap_result()
	if _message_left > 0.0 and _state != State.CONTROLS and _state != State.CAPTURE:
		_draw_line_center(_info_top() + 24, _message, _palette["lamp_glow"])


func _draw_title(title: String) -> void:
	if not show_title:
		return
	UiText.draw(_overlay, "menu", Vector2(14, 17), title, _palette["text_highlight"])


func _draw_line_center(baseline: int, text: String, color: Color, font_key: String = "body") -> void:
	UiText.draw(_overlay, font_key, Vector2(0, baseline), text, color, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _info_lines(text: String) -> PackedStringArray:
	var font: Font = UiFonts.get_font("body")
	return TextWrap.wrap(font, UiFonts.get_size("body"), text, int(size.x) - 28)


func _draw_info(lines: Array, color: Color = Color.TRANSPARENT) -> void:
	var top: int = _info_top()
	_overlay.draw_rect(Rect2(10, top - 2, size.x - 20, 1), _palette["dusk"])
	var row: int = 0
	for line: Variant in lines:
		var text_color: Color = color if color.a > 0.0 else _palette["text"]
		UiText.draw(_overlay, "body", Vector2(14, top + 12 + row * 14), str(line), text_color)
		row += 1


func _draw_list_info() -> void:
	var row_id: String = get_cursor_row_id()
	if row_id.is_empty():
		return
	var hint: String = str(_text["rows"][row_id]["hint"])
	if row_id == "vibration" and Input.get_connected_joypads().is_empty():
		hint = str(_text["rows"][row_id]["hint_no_pad"])
	if row_id == "text_speed":
		# The first line types out at the chosen speed so the player can see it.
		_draw_info(["", hint])
		UiText.draw(_overlay, "body", Vector2(14, _info_top() + 12), get_preview_text(), _palette["lamp_glow"])
		return
	var lines: Array = []
	for line: String in _info_lines(hint):
		lines.append(line)
	_draw_info(lines.slice(0, 2))


func _draw_volume_bars() -> void:
	var bar: Dictionary = _ui["volume_bar"]
	var cfg: Node = _cfg()
	if cfg == null:
		return
	var segments: int = int(bar["segments"])
	var seg_w: int = int(bar["segment_w"])
	var gap: int = int(bar["gap"])
	var total_w: int = segments * seg_w + (segments - 1) * gap
	var value_font: Font = UiFonts.get_font("menu")
	var value_size: int = UiFonts.get_size("menu")
	var percent_w: int = int(ceil(value_font.get_string_size("100%", HORIZONTAL_ALIGNMENT_LEFT, -1, value_size).x))
	for i: int in _list.get_count():
		var row: Dictionary = _rows[i]
		if str(row["type"]) != "volume":
			continue
		var rect: Rect2 = _list.get_row_rect(i)
		if rect.size == Vector2.ZERO:
			continue
		var level: float = float(cfg.call("get_volume", str(row["volume"])))
		var filled: int = roundi(level * float(segments))
		var right: float = _list.position.x + _list.size.x - float(_ui["value_pad"]) - float(percent_w) - float(bar["text_gap"])
		var x: float = right - float(total_w)
		var y: float = _list.position.y + rect.position.y + (rect.size.y - float(bar["height"])) / 2.0
		var selected: bool = i == _list.get_cursor_index()
		for s: int in segments:
			var color: Color = _palette["dusk"]
			if s < filled:
				color = _palette["lamp_amber"] if selected else _palette["text"]
			_overlay.draw_rect(Rect2(x + s * (seg_w + gap), y, seg_w, float(bar["height"])), color)


func _control_codes(group: String) -> Dictionary:
	var cfg: Node = _cfg()
	var effective: Dictionary = cfg.call("get_effective_bindings") if cfg != null else InputRemap.defaults()
	return effective.get(group, {"key": -1, "pad": -1})


func _draw_control_cells() -> void:
	var title_y: int = 17
	if show_title:
		UiText.draw(_overlay, "body", Vector2(_key_col_x(), title_y), str(_text["controls"]["keyboard"]), _palette["slate_light"])
		UiText.draw(_overlay, "body", Vector2(_pad_col_x(), title_y), str(_text["controls"]["controller"]), _palette["slate_light"])
	var blink_on: bool = int(_anim_clock / 0.35) % 2 == 0
	for i: int in _controls_list.get_count():
		var id: String = _controls_list.get_item_id(i)
		if id == "reset":
			continue
		var rect: Rect2 = _controls_list.get_row_rect(i)
		if rect.size == Vector2.ZERO:
			continue
		var baseline: float = _controls_list.position.y + float(_controls_list.first_row_y + (i - _controls_list.get_top()) * _controls_list.row_height + UiFonts.get_size("menu"))
		var codes: Dictionary = _control_codes(id)
		var selected: bool = i == _controls_list.get_cursor_index()
		for col: int in 2:
			var kind: String = "pad" if col == 1 else "key"
			var x: float = _pad_col_x() if col == 1 else _key_col_x()
			var label: String = InputRemap.code_name(kind, int(codes[kind]))
			var color: Color = _palette["text"]
			if selected and col == _control_col:
				color = _palette["text_highlight"]
				var width: float = float(UiFonts.text_width("menu", label))
				_overlay.draw_rect(Rect2(x, baseline + 3, maxf(width, 20.0), 1), _palette["lamp_amber"])
			elif selected:
				color = _palette["slate_light"]
			if _state == State.CAPTURE and selected and col == _control_col:
				label = "..." if blink_on else ""
				color = _palette["lamp_glow"]
			UiText.draw(_overlay, "menu", Vector2(x, baseline), label, color)


func _draw_controls_info() -> void:
	var words: Dictionary = _text["controls"]
	var id: String = _controls_list.get_item_id(_controls_list.get_cursor_index())
	if _state == State.CAPTURE:
		var prompt: String = str(words["capture_hint_key"] if _capture_kind == "key" else words["capture_hint_pad"])
		_draw_info([prompt, str(words["fixed_note"])], _palette["lamp_glow"])
		return
	var first: String = _message
	if first.is_empty():
		first = str(words["reset_hint"]) if id == "reset" else (str(words["rows"][id]["hint"]) if not id.is_empty() else "")
	var second: String = str(words["fixed_note"]) if id == "reset" else str(words["hint"])
	_draw_info([first, second])


func _draw_tap_intro() -> void:
	var words: Dictionary = _text["tap_along"]
	var codes: Dictionary = _control_codes("clutch")
	var button: String = "%s / %s" % [InputRemap.key_name(int(codes["key"])), InputRemap.pad_name(int(codes["pad"]))]
	var mid: int = int(_list.position.y) + 40
	_draw_line_center(mid, str(words["intro_1"]), _palette["text"], "menu")
	_draw_line_center(mid + 18, str(words["intro_2"]).replace("{button}", "%s (%s)" % [str(words["button_name"]), button]), _palette["text"], "menu")
	_draw_line_center(mid + 46, str(words["intro_go"]), _palette["lamp_amber"], "menu")


func _draw_tap_run() -> void:
	var words: Dictionary = _text["tap_along"]
	var params: Dictionary = _tap_params()
	var total: int = int(params["beats"])
	var area_top: int = int(_list.position.y)
	var area_bottom: int = _info_top()
	var center: Vector2 = Vector2(size.x / 2.0, float(area_top + area_bottom) / 2.0 - 6.0)
	var half: int = 20
	var flashing: bool = _tap_flash_left > 0.0
	var ring_rect: Rect2i = Rect2i(int(center.x) - half - 3, int(center.y) - half - 3, half * 2 + 6, half * 2 + 6)
	PixelShape.fill(_overlay, ring_rect, 16, _palette["ink"])
	PixelShape.fill(_overlay, Rect2i(int(center.x) - half, int(center.y) - half, half * 2, half * 2), 14, _palette["lamp_glow"] if flashing else _palette["dusk"])
	# One dot per beat: lit once it has flashed.
	var dots_y: float = center.y + half + 12.0
	var dot_step: float = 12.0
	var dots_x: float = center.x - float(total - 1) * dot_step / 2.0
	for i: int in total:
		var lit: bool = i < _tap_beats.size()
		_overlay.draw_rect(Rect2(dots_x + i * dot_step - 2.0, dots_y - 2.0, 5, 5), _palette["lamp_amber"] if lit else _palette["dusk"])
	if not is_nan(_tap_last_delta):
		_draw_line_center(int(center.y) + 4, _signed_number(roundi(_tap_last_delta)), _palette["ink"] if flashing else _palette["text"], "menu")
	var line: String = str(words["get_ready"]) if _tap_beats.is_empty() else str(words["tap_now"]).replace("{n}", str(_tap_beats.size())).replace("{total}", str(total))
	_draw_info([line], _palette["lamp_glow"])


func _draw_tap_result() -> void:
	var words: Dictionary = _text["tap_along"]
	var lines: Array = []
	if bool(_tap_result.get("ok", false)):
		var ms: int = int(_tap_result["offset_ms"])
		var mean: int = roundi(float(_tap_result["mean_ms"]))
		var big: String = str(_text["ms_format"]).replace("{ms}", _signed_number(ms))
		UiText.draw(_overlay, "title", Vector2(0, float(_list.position.y) + 34.0), big, _palette["lamp_glow"], HORIZONTAL_ALIGNMENT_CENTER, size.x)
		if absi(mean) < 5:
			lines.append(str(words["on_time"]))
		elif mean > 0:
			lines.append(str(words["late"]).replace("{ms}", str(mean)))
		else:
			lines.append(str(words["early"]).replace("{ms}", str(-mean)))
		lines.append(str(words["suggest"]).replace("{ms}", _signed_number(ms)) if bool(_tap_result["steady"]) else str(words["unsteady"]))
	else:
		lines.append(str(words["messy"] if str(_tap_result.get("reason", "")) == TapAlong.REASON_UNSTEADY else words["too_few"]))
	_draw_info(lines)


# ---- queries ----

func get_tap_state_text() -> String:
	return str(_tap_result.get("reason", ""))
