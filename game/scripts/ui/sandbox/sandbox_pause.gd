class_name SandboxPause
extends Control
## The sandbox pause menu: Resume, Reset arena, Controls, Quit. Opens with Esc / pad Start (the HUD
## asks), pauses the arena through SandboxPauseGate, and frees the mouse. "Controls" opens the
## ControlsCard; Confirm on the card opens the existing Config screen on its Controls page, where the
## buttons can be changed (overrides save to user://config.json as always).
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
		if _list != null:
			_list.audio = value
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
var _palette: Dictionary[String, Color] = {}
var _open: bool = false
var _open_clock: float = 0.0
var _input_map: MenuInput = MenuInput.new()
var _dim: ColorRect = null
var _window: UiWindow = null
var _list: MenuList = null
var _overlay: Control = null
var _card: ControlsCard = null
var _config: ConfigScreen = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	_layout = SandboxUiData.ui("pause", {})
	for key: String in DataDB.get_value(SandboxUiData.THEME_ID, "palette", {}):
		_palette[key] = SandboxUiData.palette(key)
	var rect: Rect2 = SandboxUiData.rect("pause.window")
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
	_list = MenuList.new()
	_list.name = "List"
	_list.audio = audio
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.position = rect.position
	_list.size = rect.size
	_list.visible_rows = ITEM_IDS.size()
	_list.row_height = int(_layout.get("row_h", 16))
	_list.first_row_y = int(_layout.get("first_row_y", 30))
	_list.text_x = int(_layout.get("text_x", 28))
	_list.cursor_x = int(_layout.get("cursor_x", 10))
	_list.activated.connect(_on_activated)
	_list.cursor_moved.connect(func(_i: int) -> void: _overlay.queue_redraw())
	add_child(_list)
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
	_list.set_items(_items(), false)
	visible = false
	set_process(not manual_ticks)


func _exit_tree() -> void:
	if _open and pause_game:
		SandboxPauseGate.release(get_tree(), self)


func _items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for id: String in ITEM_IDS:
		items.append({"id": id, "label": SandboxUiData.text("pause.%s" % id), "enabled": true})
	return items


# ---- open and close ----

func open_menu() -> void:
	if _open:
		return
	_open = true
	visible = true
	_open_clock = 0.0
	_window.open_amount = 0.25 if animations_enabled else 1.0
	_list.set_index(0, false)
	_list.active = true
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


func get_list() -> MenuList:
	return _list


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
	if not _open or not animations_enabled or _window.open_amount >= 1.0:
		return
	_open_clock += delta
	var steps: int = int(_layout.get("open_steps", 4))
	var step_s: float = SandboxUiData.ui_float("step_s", 0.0833)
	_window.open_amount = minf(1.0, 0.25 + 0.75 * float(int(_open_clock / step_s) + 1) / float(steps))
	_overlay.queue_redraw()


# ---- choices ----

func _on_activated(index: int) -> void:
	match _list.get_item_id(index):
		"resume":
			resume()
		"reset":
			resume()
			reset_requested.emit()
		"controls":
			_card.open_card()
			_list.active = false
		"quit":
			quit_requested.emit()


func _on_card_closed() -> void:
	_list.active = true
	_overlay.queue_redraw()


func _open_remap() -> void:
	if _config == null:
		_config = ConfigScreen.new()
		_config.name = "ConfigScreen"
		_config.config = config
		_config.position = SandboxUiData.rect("controls_card.window").position
		_config.size = SandboxUiData.rect("controls_card.window").size
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
	if event is InputEventMouse:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			resume()
			return true
		return _list.handle_mouse(event)
	if SandboxPauseGate.is_start_press(event):
		resume()
		return true
	return handle_command(_input_map.classify(event))


func handle_command(command: MenuInput.Cmd) -> bool:
	if not _open or is_sub_page_open():
		return false
	if command == MenuInput.Cmd.CANCEL:
		resume()
		return true
	return _list.handle_command(command)


# ---- drawing ----

func _draw_overlay() -> void:
	if not _open or _layout.is_empty():
		return
	var rect: Rect2 = SandboxUiData.rect("pause.window")
	UiText.draw(_overlay, "menu", Vector2(rect.position.x + 14.0, rect.position.y + float(_layout["title_y"])), SandboxUiData.text("pause.title"), _palette["lamp_amber"])
	var id: String = _list.get_item_id(_list.get_cursor_index())
	var hint: String = SandboxUiData.text("pause.hints.%s" % id)
	var center_x: float = rect.position.x + rect.size.x / 2.0
	if _list.active:
		UiText.draw(_overlay, "tag", Vector2(center_x - 150.0, rect.end.y + 14.0), hint, _palette["slate_light"], HORIZONTAL_ALIGNMENT_CENTER, 300.0)
