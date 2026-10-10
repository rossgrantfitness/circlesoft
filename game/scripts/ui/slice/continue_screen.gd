class_name ContinueScreen
extends Control
## The Continue screen (VS-11, plan 2.4): Red was knocked out. The picture dims, a header bar says "Knocked out"
## and two stacked bars offer Continue and Quit to title, with an information bar that says where Continue
## goes (the room's entrance, the last save, or the start of the boss fight) and what it costs. It says what
## was chosen (`continue_chosen`, `quit_chosen`) and the HUD acts on the room. Input comes after a short beat so a
## mashed button from the fight can't pick Continue by accident. Words: data/text/slice_ui.json "continue";
## layout: data/ui/slice_ui.json "continue". Same look as the pause menu (SandboxStyle).

signal opened
signal continue_chosen
signal quit_chosen

const ITEM_IDS: Array[String] = ["continue", "quit"]

var audio: UiAudio = UiAudio.new()
var manual_ticks: bool = false
var listen_input: bool = true
## On: opening pauses the game. Off by default: Red is already down, the room's own auto-continue timer (slice.json
## retry.auto_continue_s, used by bots) must keep running, and nothing hits a knocked-out hero.
var pause_game: bool = false
var animations_enabled: bool = true

var _layout: Dictionary = {}
var _open: bool = false
var _index: int = 0
var _age: float = 0.0
var _reveal: float = 1.0
var _hint_key: String = "hint_room"
var _cost: int = 0
var _input_map: MenuInput = MenuInput.new()
var _dim: ColorRect = null
var _overlay: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layout = SliceUiData.ui("continue", {})
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = Color(SandboxStyle.color("dim"), float(_layout.get("dim_alpha", 0.7)))
	add_child(_dim)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = Vector2(SandboxStyle.REFERENCE_SIZE)
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


## Opens for a knock-out. `rule` is the retry rule ("room_entrance", "last_save"); `boss` says the fight restarts
## from the arena gate or the phase start; `credit_cost` is shown when above 0.
func open_screen(rule: String = "room_entrance", boss: bool = false, credit_cost: int = 0) -> void:
	if _open:
		return
	_open = true
	visible = true
	_index = 0
	_age = 0.0
	_reveal = 0.25 if animations_enabled else 1.0
	_cost = credit_cost
	_hint_key = "hint_boss" if boss else ("hint_save" if rule == "last_save" else "hint_room")
	if pause_game:
		SandboxPauseGate.hold(get_tree(), self)
	_overlay.queue_redraw()
	opened.emit()


func close_screen() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if pause_game:
		SandboxPauseGate.release(get_tree(), self)


func is_open() -> bool:
	return _open


func get_cursor_index() -> int:
	return _index


func get_item_id(index: int) -> String:
	return ITEM_IDS[index] if index >= 0 and index < ITEM_IDS.size() else ""


## True once the opening beat has passed and a button can pick.
func accepts_input() -> bool:
	return _open and _age >= float(_layout.get("input_delay_s", 0.5))


## The information line for the cursor's row.
func info_text() -> String:
	if ITEM_IDS[_index] == "quit":
		return SliceUiData.text("continue.hint_quit")
	var line: String = SliceUiData.text("continue.%s" % _hint_key)
	if _cost > 0:
		line += " " + SliceUiData.fmt("continue.cost", {"credits": _cost})
	return line


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not _open:
		return
	_age += delta
	if animations_enabled and _reveal < 1.0:
		var steps: int = int(_layout.get("open_steps", 4))
		_reveal = minf(1.0, 0.25 + 0.75 * float(int(_age / SandboxUiData.ui_float("step_s", 0.0833)) + 1) / float(steps))
	_overlay.queue_redraw()


# ---- choices ----

func move(direction: int) -> void:
	_index = posmod(_index + direction, ITEM_IDS.size())
	audio.sfx("tick")
	_overlay.queue_redraw()


func activate() -> void:
	if not accepts_input():
		return
	audio.sfx("confirm")
	match ITEM_IDS[_index]:
		"continue":
			continue_chosen.emit()
		"quit":
			quit_chosen.emit()
	_overlay.queue_redraw()


# ---- input ----

func _input(event: InputEvent) -> void:
	if listen_input and _open and handle_event(event):
		get_viewport().set_input_as_handled()


func handle_event(event: InputEvent) -> bool:
	if not _open:
		return false
	if event is InputEventMouseMotion:
		var hover: int = _row_at(_to_local((event as InputEventMouseMotion).position))
		if hover >= 0 and hover != _index:
			_index = hover
			audio.sfx("tick")
			_overlay.queue_redraw()
		return hover >= 0
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			var hit: int = _row_at(_to_local(click.position))
			if hit >= 0:
				_index = hit
				activate()
				return true
		return false
	if event is InputEventMouse:
		return false
	return handle_command(_input_map.classify(event))


func handle_command(command: MenuInput.Cmd) -> bool:
	if not _open:
		return false
	match command:
		MenuInput.Cmd.UP:
			move(-1)
		MenuInput.Cmd.DOWN:
			move(1)
		MenuInput.Cmd.CONFIRM:
			activate()
		MenuInput.Cmd.CANCEL:
			if _index != 0:
				_index = 0
				audio.sfx("tick")
				_overlay.queue_redraw()
		_:
			return false
	return true


func _fit() -> void:
	size = SandboxStyle.ui_size(self)
	if _dim != null:
		_dim.size = size
	if _overlay != null:
		_overlay.size = Vector2(SandboxStyle.REFERENCE_SIZE)
		_overlay.position = SandboxStyle.center_offset(self)


func _to_local(point: Vector2) -> Vector2:
	return _overlay.get_global_transform_with_canvas().affine_inverse() * point


func _row_rect(index: int) -> Rect2:
	var offset: float = float(_layout.get("stack_offset", 3)) * float(index)
	return Rect2(float(_layout["x"]) + offset, float(_layout["row_y"]) + float(index) * float(_layout["row_step"]), float(_layout["w"]) - offset, float(_layout["row_h"]))


func _row_at(at: Vector2) -> int:
	for i: int in ITEM_IDS.size():
		if _row_rect(i).has_point(at):
			return i
	return -1


# ---- drawing ----

func _draw_overlay() -> void:
	if not _open or _layout.is_empty():
		return
	var header: Rect2 = Rect2(float(_layout["x"]), float(_layout["row_y"]) - float(_layout["header_h"]) - 5.0, float(_layout["w"]) * _reveal, float(_layout["header_h"]))
	SandboxStyle.header_bar(_overlay, header)
	if _reveal < 1.0:
		return
	SandboxStyle.text(_overlay, "body", Vector2(header.position.x + 8.0, header.position.y + 12.0), SliceUiData.text("continue.title"), SandboxStyle.color("text_on_header"))
	var ready: bool = accepts_input()
	for i: int in ITEM_IDS.size():
		var rect: Rect2 = _row_rect(i)
		var selected: bool = i == _index and ready
		SandboxStyle.list_bar(_overlay, rect, selected, not ready)
		if selected:
			SandboxStyle.cursor(_overlay, Vector2(rect.position.x + 3.0, rect.position.y + rect.size.y / 2.0))
		SandboxStyle.text(_overlay, "body", Vector2(float(_layout["x"]) + float(_layout.get("text_x", 22)), rect.position.y + 11.0), SliceUiData.text("continue.%s" % ITEM_IDS[i]), SandboxStyle.row_color(selected, ready))
	var info_y: float = float(_layout["info_y"])
	var info_x: float = float(_layout.get("info_x", 16))
	SandboxStyle.label(_overlay, Vector2(info_x + 2.0, info_y - 3.0), SliceUiData.text("continue.info_label"))
	SandboxStyle.list_bar(_overlay, Rect2(info_x, info_y, float(_layout.get("info_w", 352)), float(_layout["info_h"])))
	SandboxStyle.text(_overlay, "label", Vector2(info_x + 6.0, info_y + 10.0), info_text().to_upper(), SandboxStyle.color("text"))
