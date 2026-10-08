class_name ControlsCard
extends Control
## The controls card: every button of the sandbox, keyboard and mouse on the left, controller on the
## right, from the contract's input table (data/text/sandbox.json "controls_card"). Where the project's
## InputMap already has the action, the card shows the buttons that are really bound (so a remap
## shows up here); the words in the data are the defaults and the fallback.
##
## Opened by the pause menu's Controls row. Confirm asks the owner to open the Config screen's
## Controls page (`remap_requested`); Cancel or a right click closes it (`closed`).

signal closed
signal remap_requested

const MAX_KEY_NAMES: int = 3

var audio: UiAudio = UiAudio.new()
var manual_ticks: bool = false
var listen_input: bool = true
var animations_enabled: bool = true
## Off: Confirm does nothing (the viewing-only card).
var allow_remap: bool = true
## The camera style shown in the header ("" hides it).
var camera_mode_text: String = ""

var _layout: Dictionary = {}
var _palette: Dictionary[String, Color] = {}
var _open: bool = false
var _open_clock: float = 0.0
var _dim: ColorRect = null
var _window: UiWindow = null
var _overlay: Control = null
var _input_map: MenuInput = MenuInput.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	_layout = SandboxUiData.ui("controls_card", {})
	for key: String in DataDB.get_value(SandboxUiData.THEME_ID, "palette", {}):
		_palette[key] = SandboxUiData.palette(key)
	var rect: Rect2 = SandboxUiData.rect("controls_card.window")
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = Color(_palette["ink"], float(_layout.get("dim_alpha", 0.5)))
	_dim.size = size
	add_child(_dim)
	_window = UiWindow.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.position = rect.position
	_window.size = rect.size
	add_child(_window)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.position = rect.position
	_overlay.size = rect.size
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	visible = false
	set_process(not manual_ticks)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not _open or not animations_enabled or _window.open_amount >= 1.0:
		return
	_open_clock += delta
	var steps: int = int(_layout.get("open_steps", 4))
	var step_s: float = SandboxUiData.ui_float("step_s", 0.0833)
	_window.open_amount = minf(1.0, 0.25 + 0.75 * float(int(_open_clock / step_s) + 1) / float(steps))


# ---- open and close ----

func open_card() -> void:
	if _open:
		return
	_open = true
	visible = true
	_open_clock = 0.0
	_window.open_amount = 0.25 if animations_enabled else 1.0
	audio.sfx("confirm")
	_overlay.queue_redraw()


func close_card() -> void:
	if not _open:
		return
	_open = false
	visible = false
	audio.sfx("back")
	closed.emit()


func is_open() -> bool:
	return _open


## Redraws (the camera style or a binding changed).
func refresh() -> void:
	if _overlay != null:
		_overlay.queue_redraw()


# ---- the rows ----

## The card's rows as shown: [{action, label, key, pad}] with live bindings filled in.
func get_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Variant in DataDB.get_value(SandboxUiData.TEXT_ID, "controls_card.rows", []):
		var entry: Dictionary = row as Dictionary
		var shown: Dictionary = binding_text(entry)
		out.append({"action": str(entry.get("action", "")), "label": str(entry.get("label", "")), "key": shown["key"], "pad": shown["pad"]})
	return out


## The keyboard / mouse and controller words for one data row. Rows marked "fixed", or whose
## action is not in the InputMap, use the words written in the data.
static func binding_text(row: Dictionary) -> Dictionary:
	var key_text: String = str(row.get("key", ""))
	var pad_text: String = str(row.get("pad", ""))
	var action: StringName = StringName(str(row.get("action", "")))
	if bool(row.get("fixed", false)) or not InputMap.has_action(action):
		return {"key": key_text, "pad": pad_text}
	var keys: Array[String] = []
	var pads: Array[String] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: InputEventKey = event as InputEventKey
			var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			var named: String = InputRemap.key_name(code)
			if named != "-" and not keys.has(named):
				keys.append(named)
		elif event is InputEventMouseButton:
			var mouse_name: String = str(DataDB.get_value(SandboxUiData.TEXT_ID, "controls_card.mouse_names.%d" % (event as InputEventMouseButton).button_index, ""))
			if not mouse_name.is_empty() and not keys.has(mouse_name):
				keys.append(mouse_name)
		elif event is InputEventJoypadButton:
			var index: int = (event as InputEventJoypadButton).button_index
			var names: Array = DataDB.get_value(SandboxUiData.TEXT_ID, "controls_card.pad_names", [])
			var pad_name: String = str(names[index]) if index >= 0 and index < names.size() else InputRemap.pad_name(index)
			if not pads.has(pad_name):
				pads.append(pad_name)
	if not keys.is_empty():
		key_text = " / ".join(keys.slice(0, MAX_KEY_NAMES))
	if not pads.is_empty():
		pad_text = pads[0]
	return {"key": key_text, "pad": pad_text}


# ---- input ----

func _input(event: InputEvent) -> void:
	if listen_input and _open and handle_event(event):
		get_viewport().set_input_as_handled()


func handle_event(event: InputEvent) -> bool:
	if not _open:
		return false
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
			close_card()
			return true
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			var at: Vector2 = _overlay.get_global_transform().affine_inverse() * click.position
			if allow_remap and _hint_rect().has_point(at):
				remap_requested.emit()
			return true
		return false
	if event is InputEventMouse:
		return false
	if SandboxPauseGate.is_start_press(event):
		close_card()
		return true
	var command: MenuInput.Cmd = _input_map.classify(event)
	return handle_command(command)


func handle_command(command: MenuInput.Cmd) -> bool:
	if not _open:
		return false
	match command:
		MenuInput.Cmd.CANCEL:
			close_card()
			return true
		MenuInput.Cmd.CONFIRM:
			if allow_remap:
				remap_requested.emit()
			return true
		MenuInput.Cmd.NONE:
			return false
	return true


func _hint_rect() -> Rect2:
	return Rect2(8.0, float(_layout.get("hint_y", 192)) - 10.0, _overlay.size.x - 16.0, 14.0)


# ---- drawing ----

func _draw_overlay() -> void:
	if not _open or _layout.is_empty():
		return
	var words: Dictionary = DataDB.get_value(SandboxUiData.TEXT_ID, "controls_card", {})
	UiText.draw(_overlay, "menu", Vector2(16, float(_layout["title_y"])), str(words.get("title", "")), _palette["lamp_amber"])
	if not camera_mode_text.is_empty():
		UiText.draw(_overlay, "tag", Vector2(_overlay.size.x - 14.0, float(_layout["title_y"])), camera_mode_text, _palette["slate_light"], HORIZONTAL_ALIGNMENT_RIGHT, 150.0)
	var head_y: float = float(_layout["head_y"])
	UiText.draw(_overlay, "tag", Vector2(float(_layout["key_x"]), head_y), str(words.get("keyboard", "")), _palette["lamp_glow"])
	UiText.draw(_overlay, "tag", Vector2(float(_layout["pad_x"]), head_y), str(words.get("controller", "")), _palette["lamp_glow"])
	_overlay.draw_rect(Rect2(10.0, head_y + 3.0, _overlay.size.x - 20.0, 1.0), Color(_palette["slate"], 0.7))
	var rows: Array[Dictionary] = get_rows()
	for i: int in rows.size():
		var y: float = float(_layout["first_row_y"]) + float(i) * float(_layout["row_h"]) + 8.0
		if i % 2 == 1:
			_overlay.draw_rect(Rect2(10.0, y - 8.0, _overlay.size.x - 20.0, float(_layout["row_h"])), Color(_palette["dusk"], 0.25))
		UiText.draw(_overlay, "tag", Vector2(float(_layout["label_x"]), y), str(rows[i]["label"]), _palette["text"])
		UiText.draw(_overlay, "tag", Vector2(float(_layout["key_x"]), y), str(rows[i]["key"]), _palette["chalk"])
		UiText.draw(_overlay, "tag", Vector2(float(_layout["pad_x"]), y), str(rows[i]["pad"]), _palette["chalk"])
	UiText.draw(_overlay, "tag", Vector2(16.0, float(_layout["note_y"])), str(words.get("lock_note", "")), _palette["slate_light"])
	var hint: String = str(words.get("change_hint" if allow_remap else "view_hint", ""))
	UiText.draw(_overlay, "tag", Vector2(16.0, float(_layout.get("hint_y", 192))), hint, _palette["lamp_amber"] if allow_remap else _palette["text_dim"])
