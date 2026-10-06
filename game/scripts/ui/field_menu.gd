class_name FieldMenu
extends Control
## The test field menu: Items, Status, Config, Save (a stub) and Close, in the shared window style.
## Opens with the `menu` action in the field and freezes Red; closes with `menu`, cancel or Close.
##
## Lives on the UiStage root (384x216 coordinates). Layout numbers come from data/ui/field_menu.json,
## strings from data/text/field_menu.json, colors and fonts from data/ui/ui_theme.json.
## Controller first (d-pad or stick, confirm, cancel), keyboard, and mouse (hover moves the cursor,
## click picks, right-click backs out). Cursor ticks go through UiAudio (AudioManager when present).
##
## Settings on the Config page are stored in the Config autoload (and written to disk when the page
## is left). The bag and party come from GameState. Using an item is a stub for now.
##
## Public API: open(), close(), is_open(), set `player` so Red freezes. Tests drive it with
## handle_command() / tick() and set `manual_ticks`; `animations_enabled = false` skips the
## window grow / slide steps.

signal opened
signal closed
signal page_changed(page_id: String)

enum State { CLOSED, OPENING, OPEN, CLOSING }

const THEME_ID: String = "ui/ui_theme"
const LAYOUT_ID: String = "ui/field_menu"
const TEXT_ID: String = "text/field_menu"
const UI_ID: String = "ui/dialogue_ui"
const SCENE_PATH: String = "res://scenes/ui/field_menu.tscn"
const PAGE_MAIN: String = "main"
const PAGE_ITEMS: String = "items"
const PAGE_STATUS: String = "status"
const PAGE_CONFIG: String = "config"
const PAGE_SAVE: String = "save"
const ACTION_OPEN: StringName = &"menu"
const RELEASE_FRAMES: int = 2
const DIM_STEP: int = 3
const PATH_GAME_STATE: NodePath = ^"/root/GameState"
const PATH_CONFIG: NodePath = ^"/root/Config"
const CONFIG_ROWS: PackedStringArray = ["text_speed", "voice_volume", "auto_timing"]

## Red, frozen while the menu is open (released two frames after it closes).
var player: PlayerController = null
## Off: the menu does not open (cutscenes, battles).
var enabled: bool = true
var manual_ticks: bool = false
var animations_enabled: bool = true
var audio: UiAudio = UiAudio.new()
## Injected for tests; null means the GameState / Config autoloads.
var game_state: Node = null
var config: Node = null

var _state: State = State.CLOSED
var _page: String = PAGE_MAIN
var _layout: Dictionary = {}
var _text: Dictionary = {}
var _c: Dictionary[String, Color] = {}
var _font_menu_size: int = 8
var _font_body_size: int = 12
var _step_s: float = 0.0833
var _step_clock: float = 0.0
var _open_amount: float = 0.0
var _slide_left: int = 0
var _input_map: MenuInput = MenuInput.new()
var _memory: Dictionary[String, int] = {}
var _release_left: int = -1
var _frozen_by_us: bool = false
var _was_frozen: bool = false
var _info_override: String = ""
var _preview: TypeWriter = TypeWriter.new()
var _preview_clock: float = 0.0
var _anim_clock: float = 0.0

var _dim: DitherFade = null
var _frame: Control = null
var _main_window: UiWindow = null
var _place_window: UiWindow = null
var _side_window: UiWindow = null
var _info_window: UiWindow = null
var _main_list: MenuList = null
var _page_root: Control = null
var _page_list: MenuList = null
var _info_label: Label = null
var _preview_label: Label = null
var _place_label: Label = null
var _side_draw: Control = null
var _command_ids: Array[String] = []


func _ready() -> void:
	var theme_data: Dictionary = DataDB.get_dict(THEME_ID)
	for key: String in theme_data["palette"]:
		_c[key] = Color.html(str(theme_data["palette"][key]))
	_step_s = float(theme_data["timing"]["ui_step_s"])
	_font_menu_size = UiFonts.get_size("menu")
	_font_body_size = UiFonts.get_size("dialogue")
	_layout = DataDB.get_dict(LAYOUT_ID)
	_text = DataDB.get_dict(TEXT_ID)
	for command: Dictionary in _layout["commands"]:
		_command_ids.append(str(command["id"]))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(UiStage.STAGE_SIZE)
	visible = false
	set_process(not manual_ticks)
	_build()


func _process(delta: float) -> void:
	tick(delta)


# ---- build ----

func _build() -> void:
	_dim = DitherFade.new()
	_dim.name = "Dim"
	_dim.size = size
	add_child(_dim)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.size = size
	add_child(_frame)
	_main_window = _make_window("MainWindow", _layout["main_window"])
	_place_window = _make_window("PlaceWindow", _layout["place_window"])
	_side_window = _make_window("SideWindow", _layout["side_window"])
	_info_window = _make_window("InfoWindow", _layout["info_window"])
	_main_list = _make_list(_main_window, _layout["main_window"])
	_main_list.activated.connect(_on_main_activated)
	_main_list.cursor_moved.connect(_on_main_moved)
	var commands: Dictionary = _text["commands"]
	var rows: Array[Dictionary] = []
	for id: String in _command_ids:
		rows.append({"id": id, "label": str(commands[id]["label"])})
	_main_list.set_items(rows)
	_place_label = _make_label(_place_window, "menu", "text_dim", Vector2(10, 1))
	_place_label.text = str(_text["place"]["title"])
	var place_name: Label = _make_label(_place_window, "menu", "text", Vector2(10, 13))
	place_name.text = str(_text["place"]["name"])
	_info_label = _make_label(_info_window, "body", "text", Vector2(10, 6))
	_info_label.size = Vector2(float(_layout["info_window"]["w"]) - 20.0, 24.0)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label = _make_label(_info_window, "body", "lamp_amber", Vector2(10, 26))
	_preview_label.size = Vector2(float(_layout["info_window"]["w"]) - 20.0, 16.0)
	_page_root = Control.new()
	_page_root.name = "PageRoot"
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side_window.add_child(_page_root)


func _make_window(node_name: String, rect: Dictionary) -> UiWindow:
	var window: UiWindow = UiWindow.new()
	window.name = node_name
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.position = Vector2(float(rect["x"]), float(rect["y"]))
	window.size = Vector2(float(rect["w"]), float(rect["h"]))
	_frame.add_child(window)
	return window


func _make_list(window: Control, rect: Dictionary) -> MenuList:
	var list: MenuList = MenuList.new()
	list.audio = audio
	list.row_height = int(_layout["list_step"])
	list.first_row_y = int(_layout["list_first_y"])
	list.text_x = int(_layout["list_text_x"])
	list.cursor_x = int(_layout["cursor_x"])
	list.size = Vector2(float(rect["w"]), float(rect["h"]))
	window.add_child(list)
	return list


func _make_label(parent: Control, font_key: String, color_key: String, at: Vector2) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiText.style_label(label, "menu" if font_key == "menu" else "dialogue", _c[color_key])
	label.position = at
	parent.add_child(label)
	return label


## Builds the menu on the UI stage (making the stage if needed) and returns it. `player` is frozen
## while the menu is open. Call once when a room loads; remove it with queue_free() when it unloads.
static func install(tree: SceneTree, player_to_freeze: PlayerController = null) -> FieldMenu:
	var stage: UiStage = UiStage.get_or_create(tree)
	var menu: FieldMenu = (load(SCENE_PATH) as PackedScene).instantiate() as FieldMenu
	menu.player = player_to_freeze
	stage.get_stage_root().add_child(menu)
	return menu


# ---- opening and closing ----

## Opens the menu on the main page. Returns false if it is disabled, already open, or another
## bubble / menu is up.
func open() -> bool:
	if _state != State.CLOSED or not enabled or _other_ui_busy():
		return false
	visible = true
	add_to_group(UiStage.MODAL_GROUP)
	_release_left = -1
	if player != null and not _frozen_by_us:
		_was_frozen = player.frozen
		player.frozen = true
		_frozen_by_us = true
	_page = PAGE_MAIN
	_memory.clear()
	_main_list.set_index(0, false)
	_main_list.active = true
	_dim.step_count = 8
	_dim.step = DIM_STEP
	audio.sfx("confirm")
	_set_open_amount(0.0 if animations_enabled else 1.0)
	_state = State.OPENING if animations_enabled else State.OPEN
	_show_page(PAGE_MAIN, false)
	if _state == State.OPEN:
		opened.emit()
	return true


## Closes the menu (the windows shrink back to a line) and saves the Config settings.
func close() -> void:
	if _state == State.CLOSED or _state == State.CLOSING:
		return
	_save_config()
	audio.sfx("back")
	if animations_enabled:
		_state = State.CLOSING
		_page_root.visible = false
		_main_list.visible = false
	else:
		_finish_close()


func _finish_close() -> void:
	_state = State.CLOSED
	visible = false
	_dim.step = 0
	_release_left = RELEASE_FRAMES
	closed.emit()


func is_open() -> bool:
	return _state == State.OPEN or _state == State.OPENING


func get_state() -> State:
	return _state


func _other_ui_busy() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	for node: Node in tree.get_nodes_in_group(UiStage.MODAL_GROUP):
		if node != self:
			return true
	return false


func _set_open_amount(amount: float) -> void:
	_open_amount = amount
	for window: UiWindow in [_main_window, _place_window, _side_window, _info_window]:
		window.open_amount = amount
	var full: bool = amount >= 1.0
	_main_list.visible = full
	_page_root.visible = full
	_info_label.visible = full
	_preview_label.visible = full
	_place_label.visible = full
	for child: Node in _place_window.get_children():
		if child is Label:
			(child as Label).visible = full


# ---- time ----

## Advances the open / close / slide animation and the config preview by `delta` seconds.
func tick(delta: float) -> void:
	_anim_clock += delta
	if _release_left >= 0:
		_release_left -= 1
		if _release_left <= 0:
			_release_left = -1
			_release()
	if _state == State.CLOSED:
		return
	_step_clock += delta
	while _step_clock >= _step_s:
		_step_clock -= _step_s
		_advance_step()
	_tick_preview(delta)


func _advance_step() -> void:
	var steps: int = int(_layout["open_steps"])
	var amount_step: float = 1.0 / float(steps)
	if _state == State.OPENING:
		_set_open_amount(minf(1.0, _open_amount + amount_step))
		if _open_amount >= 1.0:
			_state = State.OPEN
			opened.emit()
	elif _state == State.CLOSING:
		_set_open_amount(maxf(0.0, _open_amount - amount_step))
		if _open_amount <= 0.0:
			_finish_close()
	if _slide_left > 0:
		_slide_left -= 1
		_apply_slide()


func _release() -> void:
	if _state != State.CLOSED:
		return
	remove_from_group(UiStage.MODAL_GROUP)
	if _frozen_by_us and player != null and is_instance_valid(player):
		player.frozen = _was_frozen
	_frozen_by_us = false


func _apply_slide() -> void:
	var steps: int = int(_layout["page_slide_steps"])
	var offset: float = float(_layout["page_slide_px"]) * float(_slide_left) / float(steps)
	_page_root.position.x = offset


## Jumps every running animation to its end (tests).
func finish_animations() -> void:
	if _state == State.OPENING:
		_set_open_amount(1.0)
		_state = State.OPEN
		opened.emit()
	elif _state == State.CLOSING:
		_set_open_amount(0.0)
		_finish_close()
	_slide_left = 0
	_apply_slide()


# ---- input ----

func _input(event: InputEvent) -> void:
	if _state == State.CLOSED:
		if event.is_action_pressed(ACTION_OPEN) and not event.is_echo():
			if open():
				get_viewport().set_input_as_handled()
		return
	if _state != State.OPEN:
		return
	if event is InputEventMouse:
		if _handle_mouse(event):
			get_viewport().set_input_as_handled()
		return
	var command: MenuInput.Cmd = _input_map.classify(event)
	if command != MenuInput.Cmd.NONE:
		handle_command(command)
		get_viewport().set_input_as_handled()


## One menu command (what a button press means). Public so tests and cutscenes can drive it.
func handle_command(command: MenuInput.Cmd) -> void:
	if _state != State.OPEN:
		return
	if command == MenuInput.Cmd.MENU:
		close()
		return
	match _page:
		PAGE_MAIN:
			_command_main(command)
		PAGE_ITEMS:
			_command_items(command)
		PAGE_STATUS:
			_command_status(command)
		PAGE_CONFIG:
			_command_config(command)
		PAGE_SAVE:
			_command_save(command)


func _handle_mouse(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			handle_command(MenuInput.Cmd.CANCEL)
			return true
	var list: MenuList = _main_list if _page == PAGE_MAIN else _page_list
	if list != null and list.handle_mouse(event):
		return true
	return event is InputEventMouseButton


func _command_main(command: MenuInput.Cmd) -> void:
	match command:
		MenuInput.Cmd.CANCEL:
			close()
		_:
			_main_list.handle_command(command)


func _command_items(command: MenuInput.Cmd) -> void:
	match command:
		MenuInput.Cmd.CANCEL:
			_back_to_main()
		_:
			if _page_list != null:
				_page_list.handle_command(command)


func _command_status(command: MenuInput.Cmd) -> void:
	if command == MenuInput.Cmd.CANCEL or command == MenuInput.Cmd.CONFIRM:
		_back_to_main()


func _command_save(command: MenuInput.Cmd) -> void:
	if command == MenuInput.Cmd.CANCEL or command == MenuInput.Cmd.CONFIRM:
		_back_to_main()


func _command_config(command: MenuInput.Cmd) -> void:
	match command:
		MenuInput.Cmd.CANCEL:
			_save_config()
			_back_to_main()
		MenuInput.Cmd.LEFT:
			_change_config(-1)
		MenuInput.Cmd.RIGHT:
			_change_config(1)
		_:
			if _page_list != null:
				_page_list.handle_command(command)


# ---- pages ----

func _on_main_activated(index: int) -> void:
	var command: Dictionary = (_layout["commands"] as Array)[index]
	var page: String = str(command["page"])
	if page.is_empty():
		close()
		return
	_memory[PAGE_MAIN] = index
	_main_list.active = false
	_show_page(page, true)


func _on_main_moved(_index: int) -> void:
	_refresh_info()


func _back_to_main() -> void:
	audio.sfx("back")
	_main_list.active = true
	_show_page(PAGE_MAIN, true)


## Rebuilds the right-hand side for a page. Slides in by a few pixels when `slide` is true.
func _show_page(page: String, slide: bool) -> void:
	_page = page
	_info_override = ""
	_page_list = null
	_side_draw = null
	for child: Node in _page_root.get_children():
		_page_root.remove_child(child)
		child.queue_free()
	var side: Dictionary = _layout["save_window"] if page == PAGE_SAVE else _layout["side_window"]
	_side_window.position = Vector2(float(side["x"]), float(side["y"]))
	_side_window.size = Vector2(float(side["w"]), float(side["h"]))
	_preview_label.text = ""
	match page:
		PAGE_MAIN:
			_build_party_panel()
		PAGE_ITEMS:
			_build_items_page()
		PAGE_STATUS:
			_build_status_page()
		PAGE_CONFIG:
			_build_config_page()
		PAGE_SAVE:
			_build_save_page()
	if slide and animations_enabled:
		_slide_left = int(_layout["page_slide_steps"])
		_apply_slide()
	else:
		_slide_left = 0
		_page_root.position.x = 0.0
	_refresh_info()
	page_changed.emit(page)


func _new_drawing(callback: Callable) -> Control:
	var drawing: Control = Control.new()
	drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawing.size = _side_window.size
	drawing.draw.connect(callback.bind(drawing))
	_page_root.add_child(drawing)
	return drawing


func _new_page_list(rows: int, row_step: int, first_y: int) -> MenuList:
	var list: MenuList = _make_list(_page_root, {"w": _side_window.size.x, "h": _side_window.size.y})
	list.visible_rows = rows
	list.row_height = row_step
	list.first_row_y = first_y
	list.cursor_moved.connect(func(_i: int) -> void: _refresh_info())
	_page_list = list
	return list


func _state_node(path: NodePath, injected: Node) -> Node:
	return injected if injected != null else get_node_or_null(path)


func _get_state() -> Node:
	return _state_node(PATH_GAME_STATE, game_state)


func _get_config() -> Node:
	return _state_node(PATH_CONFIG, config)


# -- main page: the party panel --

func _build_party_panel() -> void:
	_side_draw = _new_drawing(_draw_party_panel)


func _party() -> Array[Dictionary]:
	var state: Node = _get_state()
	var party: Array[Dictionary] = []
	if state != null:
		party.assign(state.call("get_party"))
	return party


func _draw_party_panel(canvas: Control) -> void:
	var party: Array[Dictionary] = _party()
	var row_h: int = int(_layout["party_row_h"])
	for i: int in party.size():
		var top: int = int(_layout["party_top"]) + i * row_h
		_draw_member_row(canvas, party[i], top)


func _draw_member_row(canvas: Control, member: Dictionary, top: int) -> void:
	var inner_w: int = int(canvas.size.x)
	_draw_portrait(canvas, member, Vector2i(10, top + 4))
	UiText.draw(canvas, "menu", Vector2(46, top + 14), str(member["name"]), _c["text"])
	var level: String = str(_text["status"]["level"]).replace("{level}", str(int(member["level"])))
	UiText.draw(canvas, "menu", Vector2(0, top + 14), level, _c["text_dim"], HORIZONTAL_ALIGNMENT_RIGHT, inner_w - 12)
	_draw_stat_bar(canvas, Vector2i(46, top + 28), str(_text["status"]["hp"]), int(member["hp"]), int(member["hp_max"]),
			Color.html("#FF7A59"), int(_layout["hp_bar_h"]), inner_w - 12)
	_draw_stat_bar(canvas, Vector2i(46, top + 41), str(_text["status"]["juice"]), int(member["juice"]), int(member["juice_max"]),
			Color.html("#9BE35A"), int(_layout["juice_bar_h"]), inner_w - 12)


## A label, a bar and "now/max" with a number you can read without the color. `at.y` is the baseline.
func _draw_stat_bar(canvas: Control, at: Vector2i, label: String, value: int, maximum: int, color: Color, thickness: int, right_edge: int) -> void:
	var bar_x: int = at.x + int(_layout["bar_label_w"])
	var bar_w: int = int(_layout["bar_w"])
	var middle: int = at.y - 4
	UiText.draw(canvas, "menu", Vector2(at.x, at.y), label, _c["text_dim"])
	var y: int = middle - thickness / 2
	canvas.draw_rect(Rect2(bar_x - 1, y - 1, bar_w + 2, thickness + 2), _c["ink"])
	canvas.draw_rect(Rect2(bar_x, y, bar_w, thickness), _c["dusk"])
	var fill: int = int(round(float(bar_w) * float(value) / float(maxi(1, maximum))))
	canvas.draw_rect(Rect2(bar_x, y, fill, thickness), color)
	var numbers: String = "%d/%d" % [value, maximum]
	UiText.draw(canvas, "menu", Vector2(0, at.y), numbers, _c["text"], HORIZONTAL_ALIGNMENT_RIGHT, right_edge)


## Placeholder portrait: a colored tile with the character's initial (the real 96x96 portraits
## and 24x24 heads are in docs/art_requests.md).
func _draw_portrait(canvas: Control, member: Dictionary, at: Vector2i) -> void:
	var tile: int = int(_layout["portrait_size"])
	canvas.draw_rect(Rect2(at.x + 1, at.y + 1, tile, tile), _c["ink"])
	canvas.draw_rect(Rect2(at.x - 1, at.y - 1, tile + 2, tile + 2), _c["chalk"])
	canvas.draw_rect(Rect2(at.x, at.y, tile, tile), Color.html(str(member.get("accent", "#888888"))))
	var initial: String = str(member.get("initial", "?"))
	var big_size: int = int(_layout["portrait_initial_size"])
	var font: Font = UiFonts.get_font("title")
	canvas.draw_string(font, Vector2(at.x, at.y + (tile + big_size) / 2 - 3), initial, HORIZONTAL_ALIGNMENT_CENTER, tile, big_size, _c["ink"])


# -- items page --

func _build_items_page() -> void:
	var list: MenuList = _new_page_list(int(_layout["item_rows"]), int(_layout["list_step"]), int(_layout["list_first_y"]))
	list.activated.connect(_on_item_activated)
	list.set_items(_item_rows())
	list.set_index(_memory.get(PAGE_ITEMS, 0), false)
	if list.get_count() == 0:
		var empty: Label = _make_label(_page_root, "body", "text_dim", Vector2(20, 14))
		empty.text = str(_text["items"]["empty"])


func _item_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var state: Node = _get_state()
	if state == null:
		return rows
	for id: String in state.call("get_item_ids"):
		var info: Dictionary = state.call("get_item_info", id)
		rows.append({"id": id, "label": str(info["name"]), "value": "x%d" % int(state.call("item_count", id))})
	return rows


func _on_item_activated(index: int) -> void:
	_memory[PAGE_ITEMS] = index
	var id: String = _page_list.get_item_id(index)
	var state: Node = _get_state()
	if state == null or id.is_empty():
		return
	var info: Dictionary = state.call("get_item_info", id)
	_info_override = str(_text["items"]["use_stub"]).replace("{name}", str(info["name"]))
	_refresh_info()


# -- status page --

func _build_status_page() -> void:
	_side_draw = _new_drawing(_draw_status_cards)


func _draw_status_cards(canvas: Control) -> void:
	var party: Array[Dictionary] = _party()
	var card_w: int = int(_layout["status_card_w"])
	var gap: int = int(_layout["status_card_gap"])
	for i: int in party.size():
		var member: Dictionary = party[i]
		var x: int = 10 + i * (card_w + gap)
		var card: Rect2i = Rect2i(x, 10, card_w, int(canvas.size.y) - 20)
		PixelShape.fill_outlined(canvas, card, 4, 1, _c["dusk"], _c["night"])
		_draw_portrait(canvas, member, Vector2i(x + 8, 20))
		UiText.draw(canvas, "menu", Vector2(x + 42, 34), str(member["name"]), _c["text"])
		var level: String = str(_text["status"]["level"]).replace("{level}", str(int(member["level"])))
		UiText.draw(canvas, "menu", Vector2(x + 42, 48), level, _c["text_dim"])
		_draw_card_bar(canvas, Vector2i(x + 8, 68), str(_text["status"]["hp"]), int(member["hp"]), int(member["hp_max"]), Color.html("#FF7A59"), int(_layout["hp_bar_h"]), card_w - 16)
		_draw_card_bar(canvas, Vector2i(x + 8, 92), str(_text["status"]["juice"]), int(member["juice"]), int(member["juice_max"]), Color.html("#9BE35A"), int(_layout["juice_bar_h"]), card_w - 16)
		UiText.draw(canvas, "menu", Vector2(x + 8, 114), str(_text["status"]["weapon"]), _c["text_dim"])
		UiText.draw(canvas, "menu", Vector2(x + 8, 126), str(member.get("weapon", "")), _c["text"])


func _draw_card_bar(canvas: Control, at: Vector2i, label: String, value: int, maximum: int, color: Color, thickness: int, width: int) -> void:
	UiText.draw(canvas, "menu", Vector2(at.x, at.y), label, _c["text_dim"])
	UiText.draw(canvas, "menu", Vector2(at.x, at.y), "%d/%d" % [value, maximum], _c["text"], HORIZONTAL_ALIGNMENT_RIGHT, width)
	var y: int = at.y + 6
	canvas.draw_rect(Rect2(at.x - 1, y - 1, width + 2, thickness + 2), _c["ink"])
	canvas.draw_rect(Rect2(at.x, y, width, thickness), _c["dusk"])
	canvas.draw_rect(Rect2(at.x, y, int(round(float(width) * float(value) / float(maxi(1, maximum)))), thickness), color)


# -- config page --

func _build_config_page() -> void:
	var list: MenuList = _new_page_list(CONFIG_ROWS.size(), int(_layout["config_row_step"]), int(_layout["config_first_y"]))
	list.set_items(_config_rows())
	list.set_index(_memory.get(PAGE_CONFIG, 0), false)
	list.activated.connect(func(_i: int) -> void: _change_config(1, true))
	list.cursor_moved.connect(func(i: int) -> void: _memory[PAGE_CONFIG] = i)
	_restart_preview()


func _config_rows() -> Array[Dictionary]:
	var cfg: Node = _get_config()
	var strings: Dictionary = _text["config"]
	var rows: Array[Dictionary] = []
	if cfg == null:
		return rows
	var speed_names: Dictionary = strings["speed_names"]
	rows.append({"id": "text_speed", "label": str(strings["text_speed"]),
			"value": "< %s >" % str(speed_names.get(str(cfg.get("text_speed")), str(cfg.get("text_speed"))))})
	rows.append({"id": "voice_volume", "label": str(strings["voice_volume"]),
			"value": "< %d%% >" % int(round(float(cfg.get("voice_volume")) * 100.0))})
	rows.append({"id": "auto_timing", "label": str(strings["auto_timing"]),
			"value": "< %s >" % str(strings["on"] if bool(cfg.get("auto_timing")) else strings["off"])})
	return rows


## Changes the highlighted setting one step. `wrap` lets a confirm press cycle past the end.
func _change_config(direction: int, wrap: bool = false) -> void:
	var cfg: Node = _get_config()
	if cfg == null or _page_list == null:
		return
	var row: String = _page_list.get_item_id(_page_list.get_cursor_index())
	var changed: bool = false
	match row:
		"text_speed":
			var ids: Array[String] = []
			ids.assign(cfg.call("get_text_speed_ids"))
			var current: int = ids.find(str(cfg.get("text_speed")))
			var target: int = posmod(current + direction, ids.size()) if wrap else clampi(current + direction, 0, ids.size() - 1)
			if target != current:
				cfg.call("set_text_speed", ids[target])
				changed = true
		"voice_volume":
			var steps: int = int(_layout["volume_steps"])
			var current_step: int = int(round(float(cfg.get("voice_volume")) * float(steps)))
			var target_step: int = posmod(current_step + direction, steps + 1) if wrap else clampi(current_step + direction, 0, steps)
			if target_step != current_step:
				cfg.call("set_voice_volume", float(target_step) / float(steps))
				changed = true
				audio.voice(str(_text["config"]["preview_speaker"]), "a")
		"auto_timing":
			cfg.call("set_auto_timing", not bool(cfg.get("auto_timing")))
			changed = true
	if changed:
		audio.sfx("tick")
		_page_list.set_items(_config_rows(), true)
		_restart_preview()


func _restart_preview() -> void:
	if _page != PAGE_CONFIG:
		return
	var cfg: Node = _get_config()
	var cps: float = float(cfg.call("get_text_cps")) if cfg != null else 36.0
	_preview.start(str(_text["config"]["preview"]), cps, DataDB.get_value(UI_ID, "typing.pauses", {}))
	_preview_label.text = ""
	_preview_clock = 0.0


func _tick_preview(delta: float) -> void:
	if _page != PAGE_CONFIG:
		return
	if _preview.is_done():
		# Loop the line after a short rest so the speed can be judged again.
		_preview_clock += delta
		if _preview_clock > 1.5:
			_restart_preview()
		return
	var typed: String = _preview.advance(delta)
	if not typed.is_empty():
		_preview_label.text = _preview.get_visible_text()
		var speaker: String = str(_text["config"]["preview_speaker"])
		for character: String in typed:
			audio.voice(speaker, character)


func _save_config() -> void:
	var cfg: Node = _get_config()
	if cfg != null and cfg.has_method("save_file") and _page == PAGE_CONFIG:
		cfg.call("save_file")


# -- save page (a stub: save lamps only) --

func _build_save_page() -> void:
	var save: Dictionary = _text["save"]
	var line1: Label = _make_label(_page_root, "menu", "text", Vector2(14, 14))
	line1.text = str(save["line1"])
	var line2: Label = _make_label(_page_root, "body", "text_dim", Vector2(14, 28))
	line2.text = str(save["line2"])
	var list: MenuList = _new_page_list(1, 16, 46)
	list.set_items([{"id": "ok", "label": str(save["ok"])}] as Array[Dictionary])
	list.activated.connect(func(_i: int) -> void: _back_to_main())


# -- info window --

func _refresh_info() -> void:
	if _info_label == null:
		return
	var text: String = ""
	match _page:
		PAGE_MAIN:
			var id: String = _main_list.get_item_id(_main_list.get_cursor_index())
			text = str(_text["commands"].get(id, {}).get("hint", ""))
		PAGE_ITEMS:
			if not _info_override.is_empty():
				text = _info_override
			elif _page_list != null:
				var item_id: String = _page_list.get_item_id(_page_list.get_cursor_index())
				var state: Node = _get_state()
				if state != null and not item_id.is_empty():
					text = str(state.call("get_item_info", item_id)["desc"])
		PAGE_STATUS:
			text = str(_text["status"]["hint"])
		PAGE_CONFIG:
			if _page_list != null:
				var row: String = _page_list.get_item_id(_page_list.get_cursor_index())
				text = str(_text["config"]["hints"].get(row, ""))
		PAGE_SAVE:
			text = str(_text["commands"]["save"]["hint"])
	_info_label.text = text


# ---- queries (tests) ----

func get_page() -> String:
	return _page


func get_main_ids() -> Array[String]:
	return _command_ids.duplicate()


func get_main_index() -> int:
	return _main_list.get_cursor_index()


func get_main_list() -> MenuList:
	return _main_list


func get_page_list() -> MenuList:
	return _page_list


func get_info_text() -> String:
	return _info_label.text


func get_preview_text() -> String:
	return _preview_label.text


func get_dim_step() -> int:
	return _dim.step
