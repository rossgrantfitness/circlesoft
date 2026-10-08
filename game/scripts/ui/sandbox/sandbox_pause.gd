class_name SandboxPause
extends Control
## The sandbox pause menu: Resume, Reset arena, Controls, Quit, as a header bar over a stack of
## slightly offset bars (SandboxStyle). Opens with Esc / pad Start (the HUD asks), pauses the arena
## through SandboxPauseGate, and frees the mouse. "Controls" opens the ControlsCard; Confirm on the
## card opens the existing Config screen on its Controls page, where buttons can be changed
## (overrides save to user://config.json as always).
##
## It does not reset or quit anything itself: it says so (`reset_requested`, `quit_requested`) and the
## HUD, which knows the sandbox, does it. Words: data/text/sandbox.json "pause". Layout: sandbox_ui.json "pause".

signal opened
## The menu closed and the game is running again (Resume, Cancel or Start).
signal resumed
signal reset_requested
signal quit_requested

const ITEM_IDS: Array[String] = ["resume", "reset", "controls", "quit"]

var audio: UiAudio = UiAudio.new():
	set(value):
		audio = value
		if _card != null:
			_card.audio = value
## Off: the menu does not run itself; tests call tick(delta).
var manual_ticks: bool = false
var listen_input: bool = true
## Off: opening does not pause the game (tests).
var pause_game: bool = true
var animations_enabled: bool = true
## The Config node for the remap page (null: the Config autoload).
var config: Node = null

var _layout: Dictionary = {}
var _open: bool = false
var _open_clock: float = 0.0
var _reveal: float = 1.0
var _index: int = 0
var _input_map: MenuInput = MenuInput.new()
var _dim: ColorRect = null
var _overlay: Control = null
var _card: ControlsCard = null
var _config: ConfigScreen = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	_layout = SandboxUiData.ui("pause", {})
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
	_card = (load("res://scenes/ui/sandbox/controls_card.tscn") as PackedScene).instantiate() as ControlsCard
	_card.name = "ControlsCard"
	_card.audio = audio
	_card.manual_ticks = manual_ticks
	_card.listen_input = listen_input
	_card.animations_enabled = animations_enabled
	_card.closed.connect(_on_card_closed)
	_card.remap_requested.connect(_open_remap)
	add_child(_card)
	visible = false
	set_process(not manual_ticks)


func _exit_tree() -> void:
	if _open and pause_game:
		SandboxPauseGate.release(get_tree(), self)


# ---- open and close ----

func open_menu() -> void:
	if _open:
		return
	_open = true
	visible = true
	_open_clock = 0.0
	_reveal = 0.25 if animations_enabled else 1.0
	_index = 0
	if pause_game:
		SandboxPauseGate.hold(get_tree(), self)
	audio.sfx("confirm")
	_overlay.queue_redraw()
	opened.emit()


## Closes the menu and gives the game back.
func resume() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if _card.is_open():
		_card.close_card()
	if _config != null and _config.is_open():
		_config.close()
	if pause_game:
		SandboxPauseGate.release(get_tree(), self)
	audio.sfx("back")
	resumed.emit()


func is_open() -> bool:
	return _open


func get_cursor_index() -> int:
	return _index


func get_item_id(index: int) -> String:
	return ITEM_IDS[index] if index >= 0 and index < ITEM_IDS.size() else ""


func get_card() -> ControlsCard:
	return _card


func get_config_screen() -> ConfigScreen:
	return _config


## True while the card or the Config screen is on top of the menu.
func is_sub_page_open() -> bool:
	return _card.is_open() or (_config != null and _config.is_open())


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


# ---- choices ----

## Moves the cursor (wraps).
func move(direction: int) -> void:
	_index = posmod(_index + direction, ITEM_IDS.size())
	audio.sfx("tick")
	_overlay.queue_redraw()


## Picks the row under the cursor.
func activate() -> void:
	audio.sfx("confirm")
	match ITEM_IDS[_index]:
		"resume":
			resume()
		"reset":
			resume()
			reset_requested.emit()
		"controls":
			_card.open_card()
		"quit":
			quit_requested.emit()
	_overlay.queue_redraw()


func _on_card_closed() -> void:
	_overlay.queue_redraw()


func _open_remap() -> void:
	if _config == null:
		_config = ConfigScreen.new()
		_config.name = "ConfigScreen"
		_config.config = config
		_config.position = Vector2(16, 8)
		_config.size = Vector2(352, 200)
		_config.listen_input = listen_input
		_config.manual_ticks = manual_ticks
		_config.closed.connect(_on_config_closed)
		add_child(_config)
	_config.audio = audio
	_config.open(true)
	_config.open_controls()
	_card.visible = false


func _on_config_closed() -> void:
	if _card.is_open():
		_card.visible = true
		_card.refresh()


# ---- input ----

func _input(event: InputEvent) -> void:
	if listen_input and _open and handle_event(event):
		get_viewport().set_input_as_handled()


## One input event while the menu is open. Mouse positions must be in stage pixels.
func handle_event(event: InputEvent) -> bool:
	if not _open or is_sub_page_open():
		return false
	if event is InputEventMouseMotion:
		var hover: int = _row_at((event as InputEventMouseMotion).position)
		if hover >= 0 and hover != _index:
			_index = hover
			audio.sfx("tick")
			_overlay.queue_redraw()
		return hover >= 0
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_RIGHT:
			resume()
			return true
		if click.button_index == MOUSE_BUTTON_LEFT:
			var hit: int = _row_at(click.position)
			if hit >= 0:
				_index = hit
				activate()
				return true
		if click.button_index == MOUSE_BUTTON_WHEEL_UP:
			move(-1)
			return true
		if click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move(1)
			return true
		return false
	if event is InputEventMouse:
		return false
	if SandboxPauseGate.is_start_press(event):
		resume()
		return true
	return handle_command(_input_map.classify(event))


func handle_command(command: MenuInput.Cmd) -> bool:
	if not _open or is_sub_page_open():
		return false
	match command:
		MenuInput.Cmd.UP:
			move(-1)
		MenuInput.Cmd.DOWN:
			move(1)
		MenuInput.Cmd.CONFIRM:
			activate()
		MenuInput.Cmd.CANCEL:
			resume()
		_:
			return false
	return true


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
	SandboxStyle.text(_overlay, "body", Vector2(header.position.x + 8.0, header.position.y + 12.0), SandboxUiData.text("pause.title"), SandboxStyle.color("text_on_header"))
	var browsing: bool = not is_sub_page_open()
	for i: int in ITEM_IDS.size():
		var rect: Rect2 = _row_rect(i)
		var selected: bool = i == _index and browsing
		SandboxStyle.list_bar(_overlay, rect, selected)
		if selected:
			SandboxStyle.cursor(_overlay, Vector2(rect.position.x + 3.0, rect.position.y + rect.size.y / 2.0))
		SandboxStyle.text(_overlay, "body", Vector2(float(_layout["x"]) + float(_layout.get("text_x", 22)), rect.position.y + 11.0), SandboxUiData.text("pause.%s" % ITEM_IDS[i]), SandboxStyle.row_color(selected))
	if browsing:
		var info_y: float = float(_layout["info_y"])
		var info_x: float = float(_layout.get("info_x", 16))
		SandboxStyle.label(_overlay, Vector2(info_x + 2.0, info_y - 3.0), SandboxUiData.text("pause.info_label"))
		SandboxStyle.list_bar(_overlay, Rect2(info_x, info_y, float(_layout.get("info_w", 352)), float(_layout["info_h"])))
		SandboxStyle.text(_overlay, "label", Vector2(info_x + 6.0, info_y + 10.0), SandboxUiData.text("pause.hints.%s" % ITEM_IDS[_index]).to_upper(), SandboxStyle.color("text"))
