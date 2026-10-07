class_name FieldMenu
extends Control
## The field menu: Items, Skills, Equip, Status, Party, Config and Save, with a side panel of the
## crew (portraits, HP, Juice), credits, play time and the place. Opens with the `menu` action in
## the field and freezes Red; closes with `menu`, cancel (on the main list) or by picking Save.
##
## Lives on the UiStage root (384x216 coordinates). Layout numbers come from data/ui/field_menu.json,
## strings from data/text/field_menu.json, colors and fonts from data/ui/ui_theme.json. Each page is
## its own class in scripts/ui/menu/ (a MenuPage); this class is the shell: the windows, the main
## list, the info window, input routing and the open / close animation.
## Controller first (d-pad or stick, confirm, cancel), keyboard, and mouse (hover moves the cursor,
## click picks, right-click backs out). Cursor ticks go through UiAudio (AudioManager when present).
##
## Save: greyed ("Find a save lamp") unless Red stands at a save spot (a node in group "save_lamp"
## or "save_spot" within reach). At a lamp it closes the menu and opens the lamp's save screen
## (SaveManager.open_lamp_menu). The Camp Stove uses the same check.
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
const SCENE_PATH: String = "res://scenes/ui/field_menu.tscn"
const PAGE_MAIN: String = "main"
const PAGE_ITEMS: String = "items"
const PAGE_SKILLS: String = "skills"
const PAGE_EQUIP: String = "equip"
const PAGE_STATUS: String = "status"
const PAGE_PARTY: String = "party"
const PAGE_CONFIG: String = "config"
const PAGE_SAVE: String = "save"
const ACTION_OPEN: StringName = &"menu"
const RELEASE_FRAMES: int = 2
const DIM_STEP: int = 3
const PATH_GAME_STATE: NodePath = ^"/root/GameState"
const PATH_CONFIG: NodePath = ^"/root/Config"
const PATH_SAVE_MANAGER: NodePath = ^"/root/SaveManager"
const GROUP_SAVE_LAMP: StringName = &"save_lamp"
const GROUP_SAVE_SPOT: StringName = &"save_spot"
const PAGE_AREA: Rect2 = Rect2(0, 0, 268, 162)

## Red, frozen while the menu is open (released two frames after it closes).
var player: PlayerController = null
## Off: the menu does not open (cutscenes, battles).
var enabled: bool = true
var manual_ticks: bool = false
var animations_enabled: bool = true
var audio: UiAudio = UiAudio.new()
## Injected for tests; null means the GameState / Config / SaveManager autoloads.
var game_state: Node = null
var config: Node = null
var save_manager: Node = null
## Tests (or a lamp that opens the menu itself) can force the save-spot answer: true / false. Null
## means "look for a save lamp near Red".
var save_spot_override: Variant = null
## Strings and layout, for the pages.
var layout: Dictionary = {}
var text: Dictionary = {}
## The menus' door to the bag, gear, skills and party. Rebuilt around the injected GameState.
var backend: GearBridge = null

var _state: State = State.CLOSED
var _page: String = PAGE_MAIN
var _page_obj: MenuPage = null
var _step_s: float = 0.0833
var _step_clock: float = 0.0
var _open_amount: float = 0.0
var _slide_left: int = 0
var _input_map: MenuInput = MenuInput.new()
var _release_left: int = -1
var _frozen_by_us: bool = false
var _was_frozen: bool = false
var _pending_save: bool = false
var _save_prompt: Node = null

var _dim: DitherFade = null
var _frame: Control = null
var _main_window: UiWindow = null
var _place_window: UiWindow = null
var _side_window: UiWindow = null
var _info_window: UiWindow = null
var _main_list: MenuList = null
var _page_root: Control = null
var _info_label: Label = null
var _place_label: Label = null
var _place_name: Label = null
var _command_ids: Array[String] = []


func _ready() -> void:
	var theme_data: Dictionary = DataDB.get_dict(THEME_ID)
	_step_s = float(theme_data["timing"]["ui_step_s"])
	layout = DataDB.get_dict(LAYOUT_ID)
	text = DataDB.get_dict(TEXT_ID)
	for command: Dictionary in layout["commands"]:
		_command_ids.append(str(command["id"]))
	backend = GearBridge.new(game_state)
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
	_main_window = _make_window("MainWindow", layout["main_window"])
	_place_window = _make_window("PlaceWindow", layout["place_window"])
	_side_window = _make_window("SideWindow", layout["side_window"])
	_info_window = _make_window("InfoWindow", layout["info_window"])
	_main_list = make_list(_main_window, {"x": 0, "y": 0, "w": float(layout["main_window"]["w"]), "h": float(layout["main_window"]["h"])})
	_main_list.visible_rows = _command_ids.size()
	_main_list.activated.connect(_on_main_activated)
	_main_list.cursor_moved.connect(_on_main_moved)
	_place_label = make_label(_place_window, "menu", "text_dim", Vector2(10, 1))
	_place_label.text = str(text["place"]["title"])
	_place_name = make_label(_place_window, "menu", "text", Vector2(10, 13))
	_info_label = make_label(_info_window, "body", "text", Vector2(10, 4))
	_info_label.size = Vector2(float(layout["info_window"]["w"]) - 20.0, 28.0)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_constant_override("line_spacing", -3)
	_page_root = Control.new()
	_page_root.name = "PageRoot"
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side_window.add_child(_page_root)
	_refresh_main_rows()


func _make_window(node_name: String, rect: Dictionary) -> UiWindow:
	var window: UiWindow = UiWindow.new()
	window.name = node_name
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.position = Vector2(float(rect["x"]), float(rect["y"]))
	window.size = Vector2(float(rect["w"]), float(rect["h"]))
	_frame.add_child(window)
	return window


# ---- widget helpers for the pages ----

## A MenuList inside `parent`. `rect` holds x, y, w, h and optionally first_y, step, text_x, rows.
func make_list(parent: Control, rect: Dictionary) -> MenuList:
	var list: MenuList = MenuList.new()
	list.audio = audio
	list.position = Vector2(float(rect.get("x", 0)), float(rect.get("y", 0)))
	list.size = Vector2(float(rect["w"]), float(rect["h"]))
	list.row_height = int(rect.get("step", layout["list_step"]))
	list.first_row_y = int(rect.get("first_y", layout["list_first_y"]))
	list.text_x = int(rect.get("text_x", layout["list_text_x"]))
	list.cursor_x = int(rect.get("cursor_x", layout["cursor_x"]))
	list.visible_rows = int(rect.get("rows", 8))
	parent.add_child(list)
	return list


func make_label(parent: Control, font_key: String, color_key: String, at: Vector2) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiText.style_label(label, "menu" if font_key == "menu" else "dialogue", MenuDraw.color(color_key))
	label.position = at
	parent.add_child(label)
	return label


## A transparent Control the page draws on. `callback(canvas)` runs on every redraw.
func make_drawing(parent: Control, at: Vector2, canvas_size: Vector2, callback: Callable) -> Control:
	var drawing: Control = Control.new()
	drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawing.position = at
	drawing.size = canvas_size
	drawing.draw.connect(callback.bind(drawing))
	parent.add_child(drawing)
	return drawing


## A MemberColumn of the party inside `parent` at `at`, sized for its style.
func make_member_column(parent: Control, style: MemberColumn.Style, at: Vector2) -> MemberColumn:
	var column: MemberColumn = MemberColumn.new()
	column.style = style
	column.audio = audio
	column.position = at
	var spec: Dictionary = layout["member_column"]
	var width: float = float(spec["width"]) if style != MemberColumn.Style.COMPACT else float(spec["compact_width"])
	if style == MemberColumn.Style.PANEL:
		width = float(layout["side_window"]["w"]) - at.x
	column.size = Vector2(width, PAGE_AREA.size.y - at.y)
	parent.add_child(column)
	column.set_members(backend.party())
	return column


func state_node() -> Node:
	return game_state if game_state != null else get_node_or_null(PATH_GAME_STATE)


func config_node() -> Node:
	return config if config != null else get_node_or_null(PATH_CONFIG)


func save_manager_node() -> Node:
	return save_manager if save_manager != null else get_node_or_null(PATH_SAVE_MANAGER)


## Builds the menu on the UI stage (making the stage if needed) and returns it. `player` is frozen
## while the menu is open. Call once when a room loads; remove it with queue_free() when it unloads.
static func install(tree: SceneTree, player_to_freeze: PlayerController = null) -> FieldMenu:
	var stage: UiStage = UiStage.get_or_create(tree)
	var menu: FieldMenu = (load(SCENE_PATH) as PackedScene).instantiate() as FieldMenu
	menu.player = player_to_freeze
	stage.get_stage_root().add_child(menu)
	return menu


# ---- the save spot ----

## True when Red is at a save spot: the Save row works and the Camp Stove can be used.
func at_save_spot() -> bool:
	if save_spot_override != null:
		return bool(save_spot_override)
	var tree: SceneTree = get_tree()
	if tree == null or player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	var radius: float = float(layout.get("save_spot_radius", 2.0))
	for group: StringName in [GROUP_SAVE_LAMP, GROUP_SAVE_SPOT]:
		for node: Node in tree.get_nodes_in_group(group):
			if node is Node3D and (node as Node3D).is_inside_tree():
				var offset: Vector3 = (node as Node3D).global_position - player.global_position
				if Vector2(offset.x, offset.z).length() <= radius and absf(offset.y) <= 1.5:
					return true
	return false


## "lamp" at a save spot, else "field": the Bag context for using items.
func item_context() -> String:
	return GearBridge.context_for(at_save_spot())


func _refresh_main_rows() -> void:
	var commands: Dictionary = text["commands"]
	var rows: Array[Dictionary] = []
	var can_save: bool = at_save_spot()
	for id: String in _command_ids:
		var row: Dictionary = {"id": id, "label": str(commands[id]["label"])}
		if id == PAGE_SAVE and not can_save:
			row["enabled"] = false
		rows.append(row)
	_main_list.set_items(rows, true)
	_place_name.text = _place_text()


## The place name for the Place window: the room the party is in, from data/text/save.json "places".
func _place_text() -> String:
	var where: Dictionary = backend.location() if backend != null else {}
	var room: String = str(where.get("room", ""))
	if room.is_empty():
		return str(text["place"]["name"])
	var named: String = str(DataDB.get_value("text/save", "places.%s" % room, ""))
	return named if not named.is_empty() else room.replace("_", " ").capitalize()


# ---- opening and closing ----

## Opens the menu on the main page. Returns false if it is disabled, already open, or another
## bubble / menu is up.
func open() -> bool:
	if _state != State.CLOSED or not enabled or _other_ui_busy():
		return false
	if backend == null or backend.state != game_state:
		backend = GearBridge.new(game_state)
	visible = true
	add_to_group(UiStage.MODAL_GROUP)
	_release_left = -1
	if player != null and not _frozen_by_us:
		_was_frozen = player.frozen
		player.frozen = true
		_frozen_by_us = true
	_page = PAGE_MAIN
	_pending_save = false
	_refresh_main_rows()
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
	if _page_obj != null:
		_page_obj.leave()
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
	_place_label.visible = full
	_place_name.visible = full


# ---- time ----

## Advances the open / close / slide animation and the page clocks by `delta` seconds.
func tick(delta: float) -> void:
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
	if _page_obj != null:
		_page_obj.tick(delta)


func _advance_step() -> void:
	var steps: int = int(layout["open_steps"])
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
	if _pending_save:
		_pending_save = false
		_open_save_prompt()


func _apply_slide() -> void:
	var steps: int = int(layout["page_slide_steps"])
	var offset: float = float(layout["page_slide_px"]) * float(_slide_left) / float(steps)
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
	if _page == PAGE_MAIN:
		_command_main(command)
	elif _page_obj != null:
		_page_obj.command(command)


func _handle_mouse(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			handle_command(MenuInput.Cmd.CANCEL)
			return true
	if _page == PAGE_MAIN:
		if _main_list.handle_mouse(event):
			return true
	elif _page_obj != null and _page_obj.mouse(event):
		return true
	return event is InputEventMouseButton


func _command_main(command: MenuInput.Cmd) -> void:
	match command:
		MenuInput.Cmd.CANCEL:
			close()
		_:
			_main_list.handle_command(command)


# ---- pages ----

func _on_main_activated(index: int) -> void:
	var command: Dictionary = (layout["commands"] as Array)[index]
	var page: String = str(command["page"])
	if page.is_empty():
		close()
		return
	if page == PAGE_SAVE:
		_begin_save()
		return
	_main_list.active = false
	_show_page(page, true)


func _on_main_moved(_index: int) -> void:
	refresh_info()


## Back to the main list (a page's cancel).
func back_to_main() -> void:
	audio.sfx("back")
	if _page_obj != null:
		_page_obj.leave()
	_main_list.active = true
	_show_page(PAGE_MAIN, true)


## Rebuilds the right-hand side for a page. Slides in by a few pixels when `slide` is true.
func _show_page(page: String, slide: bool) -> void:
	_page = page
	_page_obj = null
	for child: Node in _page_root.get_children():
		_page_root.remove_child(child)
		child.queue_free()
	_page_obj = _make_page(page)
	_page_obj.build()
	if slide and animations_enabled:
		_slide_left = int(layout["page_slide_steps"])
		_apply_slide()
	else:
		_slide_left = 0
		_page_root.position.x = 0.0
	refresh_info()
	page_changed.emit(page)


func _make_page(page: String) -> MenuPage:
	match page:
		PAGE_ITEMS:
			return PageItems.new(self, _page_root)
		PAGE_SKILLS:
			return PageSkills.new(self, _page_root)
		PAGE_EQUIP:
			return PageEquip.new(self, _page_root)
		PAGE_STATUS:
			return PageStatus.new(self, _page_root)
		PAGE_PARTY:
			return PageParty.new(self, _page_root)
		PAGE_CONFIG:
			return PageConfig.new(self, _page_root)
	return PageMain.new(self, _page_root)


## Tells the page to redraw from the current party (after something outside it changed it).
func refresh_pages() -> void:
	if _page_obj != null:
		_page_obj.refresh()
	_refresh_main_rows()


# ---- save ----

func _begin_save() -> void:
	if not at_save_spot():
		audio.sfx("back")
		return
	_pending_save = true
	close()


func _open_save_prompt() -> void:
	var manager: Node = save_manager_node()
	if manager == null or not manager.has_method("open_lamp_menu"):
		return
	_save_prompt = manager.call("open_lamp_menu", false, player) as Node


## The save screen opened by the Save row (null until then).
func get_save_prompt() -> Node:
	return _save_prompt


func is_save_pending() -> bool:
	return _pending_save


# ---- info window ----

func refresh_info() -> void:
	if _info_label == null:
		return
	var shown: Dictionary = {"text": "", "warn": false}
	if _page == PAGE_MAIN:
		var id: String = _main_list.get_item_id(_main_list.get_cursor_index())
		var hint: Dictionary = text["commands"].get(id, {})
		var line: String = str(hint.get("hint", ""))
		var warn: bool = false
		if id == PAGE_SAVE and not at_save_spot():
			line = str(hint.get("locked", line))
			warn = true
		shown = MenuPage.info_of(line, warn)
	elif _page_obj != null:
		shown = _page_obj.info()
	_info_label.text = str(shown["text"])
	_info_label.add_theme_color_override("font_color", MenuDraw.color("reason") if bool(shown["warn"]) else MenuDraw.color("text"))


# ---- queries (tests) ----

func get_page() -> String:
	return _page


func get_page_object() -> MenuPage:
	return _page_obj


func get_main_ids() -> Array[String]:
	return _command_ids.duplicate()


func get_main_index() -> int:
	return _main_list.get_cursor_index()


func get_main_list() -> MenuList:
	return _main_list


func get_page_list() -> MenuList:
	return _page_obj.primary_list() if _page_obj != null else null


func get_info_text() -> String:
	return _info_label.text


func get_place_text() -> String:
	return _place_name.text


func get_preview_text() -> String:
	if _page_obj is PageConfig:
		return (_page_obj as PageConfig).get_preview_text()
	return ""


func get_dim_step() -> int:
	return _dim.step
