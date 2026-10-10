class_name ShopMenu
extends Control
## A shop: Buy, Sell and Leave. Buying lists the shop's stock (data/shops/*.json) with prices and
## greys what you can't afford (or can't carry) with a reason; selling lists the bag (key items
## stay home) at half price. Picking a row opens the quantity picker (up and down change it by one,
## left and right by ten, capped by your credits and the 99 limit) with the total and the owned
## count; the left side always shows credits and how many you own. In a gear shop each fighter
## gets an up or down arrow for the highlighted piece (or "can't wear").
##
## The money and bag rules are ShopLogic's (through GearBridge); this class only asks and shows.
## Lives on the UiStage root (384x216). Layout: data/ui/shop_ui.json, strings: data/text/shop.json,
## colors and fonts: data/ui/ui_theme.json. Controller first, then keyboard and mouse (hover moves,
## click picks, wheel changes the amount, right-click backs out).
##
## Public API: ShopMenu.install(tree, player), open_shop(shop_id), close(), is_open(), handle_command().
## Tests drive it with handle_command() / tick(), `manual_ticks` and `animations_enabled = false`.

signal opened
signal closed
signal bought(item_id: String, qty: int)
signal sold(item_id: String, qty: int)

enum State { CLOSED, OPENING, COMMAND, LIST, QUANTITY, CLOSING }
enum Mode { BUY, SELL }

const THEME_ID: String = "ui/ui_theme"
const LAYOUT_ID: String = "ui/shop_ui"
const TEXT_ID: String = "text/shop"
const SCENE_PATH: String = "res://scenes/ui/shop_menu.tscn"
const PATH_GAME_STATE: NodePath = ^"/root/GameState"
const ROW_BUY: String = "buy"
const ROW_SELL: String = "sell"
const ROW_LEAVE: String = "leave"
const RELEASE_FRAMES: int = 2
const DIM_STEP: int = 3
const NO_ARROW_TEXT: String = "-"

## Red, frozen while the shop is open (released two frames after it closes).
var player: CharacterBody3D = null
## Off: the shop does not open.
var enabled: bool = true
var manual_ticks: bool = false
var animations_enabled: bool = true
var audio: UiAudio = UiAudio.new()
## Injected for tests; null means the GameState autoload.
var game_state: Node = null
var layout: Dictionary = {}
var text: Dictionary = {}
var backend: GearBridge = null

var _state: State = State.CLOSED
var _mode: Mode = Mode.BUY
var _shop: Dictionary = {}
var _step_s: float = 0.0833
var _step_clock: float = 0.0
var _open_amount: float = 0.0
var _input_map: MenuInput = MenuInput.new()
var _release_left: int = -1
var _frozen_by_us: bool = false
var _was_frozen: bool = false
var _message: String = ""
var _message_warn: bool = false
var _quantity: int = 1
var _quantity_max: int = 1
var _memory: Dictionary = {}

var _dim: DitherFade = null
var _frame: Control = null
var _command_window: UiWindow = null
var _credits_window: UiWindow = null
var _owned_window: UiWindow = null
var _list_window: UiWindow = null
var _info_window: UiWindow = null
var _quantity_window: UiWindow = null
var _command_list: MenuList = null
var _item_list: MenuList = null
var _credits_draw: Control = null
var _owned_draw: Control = null
var _list_draw: Control = null
var _quantity_draw: Control = null
var _info_label: Label = null


func _ready() -> void:
	var theme_data: Dictionary = DataDB.get_dict(THEME_ID)
	_step_s = float(theme_data["timing"]["ui_step_s"])
	layout = DataDB.get_dict(LAYOUT_ID)
	text = DataDB.get_dict(TEXT_ID)
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
	_command_window = _make_window("CommandWindow", layout["command_window"])
	_credits_window = _make_window("CreditsWindow", layout["credits_window"])
	_owned_window = _make_window("OwnedWindow", layout["owned_window"])
	_list_window = _make_window("ListWindow", layout["list_window"])
	_info_window = _make_window("InfoWindow", layout["info_window"])
	_quantity_window = _make_window("QuantityWindow", layout["quantity_window"])
	_quantity_window.visible = false

	_command_list = _make_list(_command_window, layout["command_window"], int(layout["command_first_y"]), int(layout["command_step"]), int(layout["command_text_x"]), 3)
	_command_list.activated.connect(_on_command_activated)
	_command_list.cursor_moved.connect(func(_i: int) -> void:
		_message = ""
		_refresh_info())
	var commands: Dictionary = text["commands"]
	_command_list.set_items([
		{"id": ROW_BUY, "label": str(commands["buy"])},
		{"id": ROW_SELL, "label": str(commands["sell"])},
		{"id": ROW_LEAVE, "label": str(commands["leave"])},
	] as Array[Dictionary])

	_item_list = _make_list(_list_window, layout["list_window"], int(layout["list_first_y"]), int(layout["list_step"]), int(layout["list_text_x"]), int(layout["list_rows"]))
	_item_list.active = false
	_item_list.activated.connect(_on_item_activated)
	_item_list.cursor_moved.connect(_on_item_moved)
	_list_draw = _make_drawing(_list_window, layout["list_window"], _draw_list_title)

	_credits_draw = _make_drawing(_credits_window, layout["credits_window"], _draw_credits)
	_owned_draw = _make_drawing(_owned_window, layout["owned_window"], _draw_owned)
	_quantity_draw = _make_drawing(_quantity_window, layout["quantity_window"], _draw_quantity)

	_info_label = Label.new()
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiText.style_label(_info_label, "dialogue", MenuDraw.color("text"))
	_info_label.position = Vector2(10, 4)
	_info_label.size = Vector2(float(layout["info_window"]["w"]) - 20.0, 30.0)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_constant_override("line_spacing", -3)
	_info_window.add_child(_info_label)


func _make_window(node_name: String, rect: Dictionary) -> UiWindow:
	var window: UiWindow = UiWindow.new()
	window.name = node_name
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.position = Vector2(float(rect["x"]), float(rect["y"]))
	window.size = Vector2(float(rect["w"]), float(rect["h"]))
	_frame.add_child(window)
	return window


func _make_list(window: Control, rect: Dictionary, first_y: int, step: int, text_x: int, rows: int) -> MenuList:
	var list: MenuList = MenuList.new()
	list.audio = audio
	list.size = Vector2(float(rect["w"]), float(rect["h"]))
	list.row_height = step
	list.first_row_y = first_y
	list.text_x = text_x
	list.cursor_x = int(layout["cursor_x"])
	list.visible_rows = rows
	window.add_child(list)
	return list


func _make_drawing(window: Control, rect: Dictionary, callback: Callable) -> Control:
	var drawing: Control = Control.new()
	drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawing.size = Vector2(float(rect["w"]), float(rect["h"]))
	drawing.draw.connect(callback.bind(drawing))
	window.add_child(drawing)
	return drawing


func state_node() -> Node:
	return game_state if game_state != null else get_node_or_null(PATH_GAME_STATE)


## Builds a shop screen on the UI stage (making the stage if needed) and returns it.
static func install(tree: SceneTree, player_to_freeze: CharacterBody3D = null) -> ShopMenu:
	var stage: UiStage = UiStage.get_or_create(tree)
	var menu: ShopMenu = (load(SCENE_PATH) as PackedScene).instantiate() as ShopMenu
	menu.player = player_to_freeze
	stage.get_stage_root().add_child(menu)
	return menu


# ---- opening and closing ----

## Opens a shop by id (a file in data/shops/). False when the shop is unknown, this one is already
## open or disabled, or a bubble / menu is up.
func open_shop(shop_id: String) -> bool:
	if _state != State.CLOSED or not enabled or _other_ui_busy():
		return false
	var shop: Dictionary = ShopData.load_shop(shop_id)
	if shop.is_empty():
		push_warning("ShopMenu: no shop '%s'" % shop_id)
		return false
	_shop = shop
	if backend == null or backend.state != game_state:
		backend = GearBridge.new(game_state)
	visible = true
	add_to_group(UiStage.MODAL_GROUP)
	_release_left = -1
	if player != null and not _frozen_by_us:
		_was_frozen = HeroLink.is_frozen(player)
		HeroLink.set_frozen(player, true)
		_frozen_by_us = true
	_memory.clear()
	_mode = Mode.BUY
	_message = str(shop["greeting"])
	_message_warn = false
	_command_list.set_index(0, false)
	_command_list.active = true
	_item_list.active = false
	_quantity_window.visible = false
	_dim.step_count = 8
	_dim.step = DIM_STEP
	audio.sfx("confirm")
	_set_open_amount(0.0 if animations_enabled else 1.0)
	_state = State.OPENING if animations_enabled else State.COMMAND
	_load_rows()
	_redraw_all()
	_refresh_info()
	if _state == State.COMMAND:
		opened.emit()
	return true


## Leaves the shop (the windows shrink back to a line).
func close() -> void:
	if _state == State.CLOSED or _state == State.CLOSING:
		return
	audio.sfx("back")
	_quantity_window.visible = false
	if animations_enabled:
		_state = State.CLOSING
		_set_content_visible(false)
	else:
		_finish_close()


func _finish_close() -> void:
	_state = State.CLOSED
	visible = false
	_dim.step = 0
	_release_left = RELEASE_FRAMES
	closed.emit()


func is_open() -> bool:
	return _state != State.CLOSED and _state != State.CLOSING


func get_state() -> State:
	return _state


func get_mode() -> Mode:
	return _mode


func get_shop_id() -> String:
	return str(_shop.get("id", ""))


func _other_ui_busy() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	for node: Node in tree.get_nodes_in_group(UiStage.MODAL_GROUP):
		if node != self:
			return true
	return false


func _windows() -> Array[UiWindow]:
	return [_command_window, _credits_window, _owned_window, _list_window, _info_window]


func _set_open_amount(amount: float) -> void:
	_open_amount = amount
	for window: UiWindow in _windows():
		window.open_amount = amount
	_set_content_visible(amount >= 1.0)


func _set_content_visible(full: bool) -> void:
	_command_list.visible = full
	_item_list.visible = full
	_credits_draw.visible = full
	_owned_draw.visible = full
	_list_draw.visible = full
	_info_label.visible = full


# ---- time ----

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


func _advance_step() -> void:
	var amount_step: float = 1.0 / float(int(layout["open_steps"]))
	if _state == State.OPENING:
		_set_open_amount(minf(1.0, _open_amount + amount_step))
		if _open_amount >= 1.0:
			_state = State.COMMAND
			opened.emit()
	elif _state == State.CLOSING:
		_set_open_amount(maxf(0.0, _open_amount - amount_step))
		if _open_amount <= 0.0:
			_finish_close()


func _release() -> void:
	if _state != State.CLOSED:
		return
	remove_from_group(UiStage.MODAL_GROUP)
	if _frozen_by_us and player != null and is_instance_valid(player):
		HeroLink.set_frozen(player, _was_frozen)
	_frozen_by_us = false


## Jumps every running animation to its end (tests).
func finish_animations() -> void:
	if _state == State.OPENING:
		_set_open_amount(1.0)
		_state = State.COMMAND
		opened.emit()
	elif _state == State.CLOSING:
		_set_open_amount(0.0)
		_finish_close()


# ---- input ----

func _input(event: InputEvent) -> void:
	if _state == State.CLOSED or _state == State.OPENING or _state == State.CLOSING:
		return
	if event is InputEventMouse:
		if _handle_mouse(event):
			get_viewport().set_input_as_handled()
		return
	var command: MenuInput.Cmd = _input_map.classify(event)
	if command != MenuInput.Cmd.NONE:
		handle_command(command)
		get_viewport().set_input_as_handled()


## One menu command. Public so tests and cutscenes can drive it.
func handle_command(command: MenuInput.Cmd) -> void:
	if _state == State.CLOSED or _state == State.OPENING or _state == State.CLOSING:
		return
	if command == MenuInput.Cmd.MENU:
		close()
		return
	match _state:
		State.COMMAND:
			if command == MenuInput.Cmd.CANCEL:
				close()
			else:
				_command_list.handle_command(command)
		State.LIST:
			if command == MenuInput.Cmd.CANCEL:
				_back_to_commands()
			else:
				_item_list.handle_command(command)
		State.QUANTITY:
			_command_quantity(command)


func _handle_mouse(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			handle_command(MenuInput.Cmd.CANCEL)
			return true
		if _state == State.QUANTITY and button.pressed:
			match button.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_change_quantity(1)
					return true
				MOUSE_BUTTON_WHEEL_DOWN:
					_change_quantity(-1)
					return true
				MOUSE_BUTTON_LEFT:
					handle_command(MenuInput.Cmd.CONFIRM)
					return true
	match _state:
		State.COMMAND:
			if _command_list.handle_mouse(event):
				return true
		State.LIST:
			if _item_list.handle_mouse(event):
				return true
	return event is InputEventMouseButton


# ---- the command list and the item rows ----

func _on_command_activated(index: int) -> void:
	match _command_list.get_item_id(index):
		ROW_BUY:
			_enter_list(Mode.BUY)
		ROW_SELL:
			_enter_list(Mode.SELL)
		ROW_LEAVE:
			close()


func _enter_list(mode: Mode) -> void:
	_mode = mode
	_message = ""
	_load_rows()
	_item_list.set_index(int(_memory.get(int(mode), 0)), false)
	if _item_list.get_count() == 0:
		_message = str(text["empty_sell"]) if mode == Mode.SELL else ""
		_message_warn = false
		audio.sfx("back")
		_refresh_info()
		return
	_state = State.LIST
	_command_list.active = false
	_item_list.active = true
	_redraw_all()
	_refresh_info()


func _back_to_commands() -> void:
	audio.sfx("back")
	_state = State.COMMAND
	_item_list.active = false
	_command_list.active = true
	_message = ""
	_redraw_all()
	_refresh_info()


## Rebuilds the rows for the current mode from the stock or the bag.
func _load_rows() -> void:
	var rows: Array[Dictionary] = []
	var ids: Array[String] = []
	if _mode == Mode.BUY:
		ids = _stock_ids()
	else:
		ids.append_array(backend.tab_ids(GearBridge.TAB_ITEMS))
		ids.append_array(backend.tab_ids(GearBridge.TAB_GEAR))
	for id: String in ids:
		var row: Dictionary = {"id": id, "label": backend.item_name(id)}
		if _mode == Mode.BUY:
			row["value"] = str(backend.buy_price(id))
			var why: String = backend.buy_reason(id, 1)
			row["enabled"] = why.is_empty()
			row["reason"] = why
		else:
			row["value"] = str(backend.sell_price(id))
			var why_sell: String = backend.sell_reason(id, 1)
			row["enabled"] = why_sell.is_empty()
			row["reason"] = why_sell
		rows.append(row)
	_item_list.set_items(rows, true)


func _stock_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_shop.get("stock", []))
	return out


func _on_item_moved(index: int) -> void:
	_memory[int(_mode)] = index
	_message = ""
	_owned_draw.queue_redraw()
	_refresh_info()


func _on_item_activated(index: int) -> void:
	var id: String = _item_list.get_item_id(index)
	if id.is_empty():
		return
	_memory[int(_mode)] = index
	_quantity = 1
	_quantity_max = backend.max_buyable(id) if _mode == Mode.BUY else backend.max_sellable(id)
	if _quantity_max < 1:
		audio.sfx("back")
		return
	_state = State.QUANTITY
	_item_list.active = false
	_quantity_window.visible = true
	_message = ""
	_quantity_draw.queue_redraw()
	_refresh_info()


# ---- the quantity picker ----

func _command_quantity(command: MenuInput.Cmd) -> void:
	match command:
		MenuInput.Cmd.UP:
			_change_quantity(1)
		MenuInput.Cmd.DOWN:
			_change_quantity(-1)
		MenuInput.Cmd.RIGHT:
			_change_quantity(int(layout["quantity_step_big"]))
		MenuInput.Cmd.LEFT:
			_change_quantity(-int(layout["quantity_step_big"]))
		MenuInput.Cmd.CONFIRM:
			_commit()
		MenuInput.Cmd.CANCEL:
			audio.sfx("back")
			_leave_quantity()


func _change_quantity(delta: int) -> void:
	var target: int = clampi(_quantity + delta, 1, maxi(_quantity_max, 1))
	if target == _quantity:
		return
	_quantity = target
	audio.sfx("tick")
	_quantity_draw.queue_redraw()
	_refresh_info()


func _leave_quantity() -> void:
	_state = State.LIST
	_quantity_window.visible = false
	_item_list.active = true
	_refresh_info()


func _commit() -> void:
	var id: String = _item_list.get_item_id(_item_list.get_cursor_index())
	var qty: int = _quantity
	var ok: bool = backend.buy(id, qty) if _mode == Mode.BUY else backend.sell(id, qty)
	if not ok:
		_message = backend.buy_reason(id, qty) if _mode == Mode.BUY else backend.sell_reason(id, qty)
		_message_warn = true
		audio.sfx("back")
		_leave_quantity()
		_load_rows()
		return
	var template: String = str(text["bought"]) if _mode == Mode.BUY else str(text["sold"])
	_message = template.replace("{n}", str(qty)).replace("{item}", backend.item_name(id))
	_message_warn = false
	if _mode == Mode.BUY:
		bought.emit(id, qty)
	else:
		sold.emit(id, qty)
	_state = State.LIST
	_quantity_window.visible = false
	_item_list.active = true
	_load_rows()
	if _item_list.get_count() == 0:
		_back_to_commands_after_sale()
	_redraw_all()
	_refresh_info()


func _back_to_commands_after_sale() -> void:
	var keep: String = _message
	_state = State.COMMAND
	_item_list.active = false
	_command_list.active = true
	_message = keep


# ---- drawing ----

func _redraw_all() -> void:
	_credits_draw.queue_redraw()
	_owned_draw.queue_redraw()
	_list_draw.queue_redraw()
	_quantity_draw.queue_redraw()


func _draw_credits(canvas: Control) -> void:
	UiText.draw(canvas, "menu", Vector2(12, 19), str(text["credits"]), MenuDraw.color("text_dim"))
	UiText.draw(canvas, "menu", Vector2(0, 19), MenuDraw.format_number(backend.credits()), MenuDraw.color("lamp_glow"),
			HORIZONTAL_ALIGNMENT_RIGHT, canvas.size.x - 12.0)


func _draw_list_title(canvas: Control) -> void:
	var y: int = int(layout["list_title_y"])
	UiText.draw(canvas, "menu", Vector2(14, y), str(_shop.get("name", "")), MenuDraw.color("text_highlight"))
	var key: String = "buy" if _mode == Mode.BUY else "sell"
	UiText.draw(canvas, "menu", Vector2(0, y), str(text["list_title"][key]), MenuDraw.color("text_dim"), HORIZONTAL_ALIGNMENT_RIGHT, canvas.size.x - 14.0)
	canvas.draw_rect(Rect2(10, y + 4, canvas.size.x - 20.0, 1), MenuDraw.color("dusk"))


func _highlighted_id() -> String:
	if _state != State.LIST and _state != State.QUANTITY:
		return ""
	return _item_list.get_item_id(_item_list.get_cursor_index())


func _draw_owned(canvas: Control) -> void:
	var id: String = _highlighted_id()
	UiText.draw(canvas, "menu", Vector2(12, 18), str(text["owned"]), MenuDraw.color("text_dim"))
	if id.is_empty():
		return
	UiText.draw(canvas, "menu", Vector2(0, 18), str(owned_count(id)), MenuDraw.color("text"), HORIZONTAL_ALIGNMENT_RIGHT, canvas.size.x - 12.0)
	if _mode != Mode.BUY or not backend.is_gear(id):
		return
	var first_y: int = int(layout["fighter_row_y"])
	var step: int = int(layout["fighter_row_step"])
	var tile: int = int(layout["fighter_tile"])
	var row: int = 0
	for entry: Dictionary in get_fighter_arrows(id):
		var y: int = first_y + row * step
		var member: Dictionary = backend.member(str(entry["id"]))
		var can_wear: bool = bool(entry["can_wear"])
		MenuDraw.portrait(canvas, member, Vector2i(12, y - 9), tile, 9, not can_wear)
		UiText.draw(canvas, "menu", Vector2(28, y + 1), str(entry["name"]), MenuDraw.color("text") if can_wear else MenuDraw.color("text_dim"))
		if can_wear:
			MenuDraw.arrow(canvas, Vector2i(canvas.size.x - 20, y - 8), int(entry["arrow"]))
			if int(entry["arrow"]) == MenuDraw.ARROW_SAME:
				UiText.draw(canvas, "menu", Vector2(0, y + 1), "=", MenuDraw.color("text_dim"), HORIZONTAL_ALIGNMENT_RIGHT, canvas.size.x - 14.0)
		else:
			UiText.draw(canvas, "menu", Vector2(0, y + 1), NO_ARROW_TEXT, MenuDraw.color("text_dim"), HORIZONTAL_ALIGNMENT_RIGHT, canvas.size.x - 14.0)
		row += 1


func _draw_quantity(canvas: Control) -> void:
	var id: String = _highlighted_id()
	if id.is_empty() or _state != State.QUANTITY:
		return
	var strings: Dictionary = text["quantity"]
	var unit: int = backend.buy_price(id) if _mode == Mode.BUY else backend.sell_price(id)
	UiText.draw(canvas, "menu", Vector2(14, 18), backend.item_name(id), MenuDraw.color("text_highlight"))
	UiText.draw(canvas, "menu", Vector2(0, 18), "%s %d" % [str(strings["owned"]), owned_count(id)], MenuDraw.color("text_dim"),
			HORIZONTAL_ALIGNMENT_RIGHT, canvas.size.x - 14.0)
	var how_many: String = str(strings["how_many_buy"] if _mode == Mode.BUY else strings["how_many_sell"])
	UiText.draw(canvas, "menu", Vector2(14, 38), how_many, MenuDraw.color("text_dim"))
	var picker: String = "<  %d  >" % _quantity
	UiText.draw(canvas, "menu", Vector2(0, 38), picker, MenuDraw.color("text_highlight"), HORIZONTAL_ALIGNMENT_RIGHT, canvas.size.x - 14.0)
	UiText.draw(canvas, "menu", Vector2(14, 58), str(strings["total"]), MenuDraw.color("text_dim"))
	UiText.draw(canvas, "menu", Vector2(0, 58), MenuDraw.format_number(unit * _quantity), MenuDraw.color("lamp_glow"),
			HORIZONTAL_ALIGNMENT_RIGHT, canvas.size.x - 14.0)


# ---- info window ----

func _refresh_info() -> void:
	if _info_label == null:
		return
	var line: String = ""
	var warn: bool = false
	if not _message.is_empty():
		line = _message
		warn = _message_warn
	else:
		match _state:
			State.LIST:
				var row_id: String = _item_list.get_item_id(_item_list.get_cursor_index())
				if not row_id.is_empty():
					var row: Dictionary = _item_list.get_items()[_item_list.get_cursor_index()]
					if not bool(row.get("enabled", true)):
						line = str(row.get("reason", ""))
						warn = true
					else:
						line = backend.item_desc(row_id)
			State.QUANTITY:
				line = backend.item_desc(_item_list.get_item_id(_item_list.get_cursor_index()))
			_:
				var id: String = _command_list.get_item_id(_command_list.get_cursor_index())
				line = str(text["hints"].get(id, ""))
	MenuDraw.set_info_text(_info_label, line, int(layout["info_window"]["h"]))
	_info_label.add_theme_color_override("font_color", MenuDraw.color("reason") if warn else MenuDraw.color("text"))
	_owned_draw.queue_redraw()


# ---- queries (tests and the list) ----

## How many of an item you have: the bag plus, for gear, what the fighters are wearing.
func owned_count(item_id: String) -> int:
	var total: int = backend.owned(item_id)
	if backend.is_gear(item_id):
		for member_id: String in backend.party_ids():
			for slot: String in GearBridge.SLOTS:
				if str(backend.equipped(member_id)[slot]) == item_id:
					total += 1
	return total


## Per fighter for a piece of gear: [{id, name, can_wear, arrow}], arrow being 1 (better than what
## they wear in that slot), -1 (worse) or 0 (same). The arrows in the Owned window come from here.
func get_fighter_arrows(item_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for member_id: String in backend.party_ids():
		var comparison: Dictionary = backend.compare(member_id, item_id)
		out.append({"id": member_id, "name": backend.member_name(member_id), "can_wear": bool(comparison["can_wear"]),
				"arrow": int(comparison["arrow"])})
	return out


func get_command_list() -> MenuList:
	return _command_list


func get_item_list() -> MenuList:
	return _item_list


func get_quantity() -> int:
	return _quantity


func get_quantity_max() -> int:
	return _quantity_max


func get_info_text() -> String:
	return _info_label.text


func get_credits_text() -> String:
	return MenuDraw.format_number(backend.credits())


func is_quantity_shown() -> bool:
	return _quantity_window.visible


func get_dim_step() -> int:
	return _dim.step
