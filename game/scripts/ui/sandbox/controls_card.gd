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
var _reveal: float = 1.0
var _open: bool = false
var _open_clock: float = 0.0
var _dim: ColorRect = null
var _overlay: Control = null
var _input_map: MenuInput = MenuInput.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	_layout = SandboxUiData.ui("controls_card", {})
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
	visible = false
	set_process(not manual_ticks)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not _open or not animations_enabled or _reveal >= 1.0:
		return
	_open_clock += delta
	var steps: int = int(_layout.get("open_steps", 4))
	var step_s: float = SandboxUiData.ui_float("step_s", 0.0833)
	_reveal = minf(1.0, 0.25 + 0.75 * float(int(_open_clock / step_s) + 1) / float(steps))
	_overlay.queue_redraw()


# ---- open and close ----

func open_card() -> void:
	if _open:
		return
	_open = true
	visible = true
	_open_clock = 0.0
	_reveal = 0.25 if animations_enabled else 1.0
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
			if allow_remap and _hint_rect().has_point(click.position):
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
	return Rect2(float(_layout["x"]), float(_layout["footer_y"]), float(_layout["w"]), float(_layout["footer_h"]))


# ---- drawing ----

func _draw_overlay() -> void:
	if not _open or _layout.is_empty():
		return
	var words: Dictionary = DataDB.get_value(SandboxUiData.TEXT_ID, "controls_card", {})
	var x: float = float(_layout["x"])
	var w: float = float(_layout["w"])
	var header: Rect2 = Rect2(x, float(_layout["header_y"]), w * _reveal, float(_layout["header_h"]))
	SandboxStyle.header_bar(_overlay, header)
	if _reveal < 1.0:
		return
	var head_base: float = header.position.y + 12.0
	SandboxStyle.text(_overlay, "body", Vector2(x + 8.0, head_base), str(words.get("title", "")), SandboxStyle.color("text_on_header"))
	if not camera_mode_text.is_empty():
		SandboxStyle.text_right(_overlay, "body", x + w - 8.0, head_base, camera_mode_text, SandboxStyle.color("text_on_header"), 150.0)
	var label_y: float = float(_layout["head_label_y"])
	SandboxStyle.label(_overlay, Vector2(float(_layout["key_x"]), label_y), str(words.get("keyboard", "")))
	SandboxStyle.label(_overlay, Vector2(float(_layout["pad_x"]), label_y), str(words.get("controller", "")))
	var rows: Array[Dictionary] = get_rows()
	for i: int in rows.size():
		var rect: Rect2 = Rect2(x, float(_layout["first_row_y"]) + float(i) * float(_layout["row_step"]), w, float(_layout["row_h"]))
		SandboxStyle.list_bar(_overlay, rect, false, i % 2 == 1)
		var base: float = rect.position.y + 11.0
		SandboxStyle.text(_overlay, "body", Vector2(float(_layout["label_x"]), base), str(rows[i]["label"]), SandboxStyle.color("text_selected"))
		SandboxStyle.text(_overlay, "body", Vector2(float(_layout["key_x"]), base), str(rows[i]["key"]), SandboxStyle.color("text"))
		SandboxStyle.text(_overlay, "body", Vector2(float(_layout["pad_x"]), base), str(rows[i]["pad"]), SandboxStyle.color("text"))
	var footer: Rect2 = _hint_rect()
	SandboxStyle.list_bar(_overlay, footer, allow_remap)
	var hint: String = str(words.get("change_hint" if allow_remap else "view_hint", ""))
	if allow_remap:
		SandboxStyle.cursor(_overlay, Vector2(footer.position.x + 4.0, footer.position.y + footer.size.y / 2.0))
	SandboxStyle.text(_overlay, "body", Vector2(footer.position.x + 16.0, footer.position.y + 11.0), hint, SandboxStyle.row_color(allow_remap))
	SandboxStyle.text(_overlay, "label", Vector2(x + 2.0, float(_layout["note_y"])), str(words.get("lock_note", "")).to_upper(), SandboxStyle.color("label_dim"))
