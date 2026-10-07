extends TestCase
## The shop screen: the Buy / Sell / Leave flow, the quantity picker with the credit and 99-cap rules,
## half-price selling (key items stay home), the owned count, the up / down arrows per fighter for
## gear, and the counter that opens it.

const PLAYER_SCENE: String = "res://scenes/actors/player.tscn"
const ROOM_PATH: String = "res://scenes/debug/psx_test_room.tscn"

var _audio: FakeAudio = null
var _state: Node = null


func before_each() -> void:
	for node: Node in tree.get_nodes_in_group(UiStage.MODAL_GROUP):
		print("MODAL LEFTOVER: ", node.get_path(), " ", node.get_script().resource_path if node.get_script() != null else node.get_class())


func _make(credits: int = 500) -> ShopMenu:
	_audio = FakeAudio.new()
	_state = MenuKit.make_state(self)
	_state.call("add_credits", credits)
	var menu: ShopMenu = (load("res://scenes/ui/shop_menu.tscn") as PackedScene).instantiate() as ShopMenu
	menu.manual_ticks = true
	menu.animations_enabled = false
	menu.game_state = _state
	menu.audio.target = _audio
	add_to_root(menu)
	return menu


func _press(menu: ShopMenu, commands: Array) -> void:
	for command: MenuInput.Cmd in commands:
		menu.handle_command(command)


func _open(menu: ShopMenu, shop_id: String, row: int = -1) -> void:
	assert_true(menu.open_shop(shop_id))
	if row == 0:
		menu.handle_command(MenuInput.Cmd.CONFIRM)
	elif row == 1:
		_press(menu, [MenuInput.Cmd.DOWN, MenuInput.Cmd.CONFIRM])


func _go_to(menu: ShopMenu, item_id: String) -> void:
	var list: MenuList = menu.get_item_list()
	for i: int in list.get_count():
		if list.get_item_id(i) == item_id:
			list.set_index(i, false)
			return
	fail("no row for %s" % item_id)


func _row(menu: ShopMenu, item_id: String) -> Dictionary:
	for row: Dictionary in menu.get_item_list().get_items():
		if str(row["id"]) == item_id:
			return row
	return {}


# ---- opening ----

func test_it_opens_with_the_greeting_and_the_three_commands() -> void:
	var menu: ShopMenu = _make()
	_open(menu, "test_general")
	assert_true(menu.is_open())
	assert_eq(menu.get_state(), ShopMenu.State.COMMAND)
	assert_eq(menu.get_info_text(), ShopData.load_shop("test_general")["greeting"])
	var ids: Array[String] = []
	for row: Dictionary in menu.get_command_list().get_items():
		ids.append(str(row["id"]))
	assert_eq(ids, ["buy", "sell", "leave"])
	assert_eq(menu.get_credits_text(), "500")
	menu.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(menu.get_info_text(), "Sell things from your bag for half what they cost.", "moving the cursor shows each command's hint")


func test_an_unknown_shop_a_disabled_shop_or_a_busy_screen_does_not_open() -> void:
	var menu: ShopMenu = _make()
	assert_false(menu.open_shop("nowhere"))
	menu.enabled = false
	assert_false(menu.open_shop("test_general"))
	menu.enabled = true
	var busy: Node = Node.new()
	add_to_root(busy)
	busy.add_to_group(UiStage.MODAL_GROUP)
	assert_false(menu.open_shop("test_general"))
	busy.remove_from_group(UiStage.MODAL_GROUP)
	assert_true(menu.open_shop("test_general"))
	assert_false(menu.open_shop("test_gear"), "already open")


func test_leave_and_cancel_close_it() -> void:
	var menu: ShopMenu = _make()
	var events: Array[String] = []
	menu.closed.connect(func() -> void: events.append("closed"))
	_open(menu, "test_general")
	_press(menu, [MenuInput.Cmd.UP, MenuInput.Cmd.CONFIRM])
	assert_false(menu.is_open(), "Leave closes")
	_open(menu, "test_general")
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_false(menu.is_open(), "cancel on the commands closes")
	_open(menu, "test_general")
	menu.handle_command(MenuInput.Cmd.MENU)
	assert_false(menu.is_open())
	assert_eq(events.size(), 3)


func test_red_is_frozen_while_shopping_and_freed_two_frames_after() -> void:
	var player: PlayerController = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	add_to_root(player)
	var menu: ShopMenu = _make()
	menu.player = player
	_open(menu, "test_general")
	assert_true(player.frozen)
	assert_true(UiStage.is_busy(tree))
	menu.close()
	assert_true(player.frozen, "same frame: still frozen")
	for i: int in 3:
		menu.tick(0.016)
	assert_false(player.frozen)
	assert_false(UiStage.is_busy(tree))


func test_the_windows_grow_open_in_steps_when_animated() -> void:
	var menu: ShopMenu = _make()
	menu.animations_enabled = true
	_open(menu, "test_general")
	assert_eq(menu.get_state(), ShopMenu.State.OPENING)
	assert_false(menu.get_command_list().visible, "text waits for the window")
	for i: int in 4:
		menu.tick(0.09)
	assert_eq(menu.get_state(), ShopMenu.State.COMMAND)
	assert_true(menu.get_command_list().visible)
	menu.close()
	assert_eq(menu.get_state(), ShopMenu.State.CLOSING)
	menu.finish_animations()
	assert_eq(menu.get_state(), ShopMenu.State.CLOSED)


# ---- buying ----

func test_buy_lists_the_stock_with_prices() -> void:
	var menu: ShopMenu = _make()
	_open(menu, "test_general", 0)
	assert_eq(menu.get_state(), ShopMenu.State.LIST)
	var rows: Array[Dictionary] = menu.get_item_list().get_items()
	assert_eq(rows.size(), ShopData.load_shop("test_general")["stock"].size())
	assert_eq(rows[0]["label"], "Ration Bar")
	assert_eq(rows[0]["value"], "15")
	assert_eq(menu.get_info_text(), "Small heal. Tastes like the wrapper.")


func test_buying_with_the_quantity_picker_spends_credits_and_fills_the_bag() -> void:
	var menu: ShopMenu = _make(500)
	var log: Array[String] = []
	menu.bought.connect(func(id: String, qty: int) -> void: log.append("%s x%d" % [id, qty]))
	_open(menu, "test_general", 0)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_state(), ShopMenu.State.QUANTITY)
	assert_true(menu.is_quantity_shown())
	assert_eq(menu.get_quantity(), 1)
	_press(menu, [MenuInput.Cmd.UP, MenuInput.Cmd.UP])
	assert_eq(menu.get_quantity(), 3)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("get_credits"), 500 - 45)
	assert_eq(_state.call("item_count", "ration_bar"), 2 + 3, "the starting two plus three")
	assert_eq(menu.get_credits_text(), "455")
	assert_eq(menu.get_info_text(), "Bought 3 Ration Bar. Thank you!")
	assert_eq(menu.get_state(), ShopMenu.State.LIST, "back to the shelf")
	assert_false(menu.is_quantity_shown())
	assert_eq(log, ["ration_bar x3"])
	assert_eq(menu.owned_count("ration_bar"), 5)


func test_the_quantity_picker_is_capped_by_your_credits() -> void:
	var menu: ShopMenu = _make(50)
	_open(menu, "test_general", 0)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_quantity_max(), 3, "50 credits buys three 15-credit bars")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(menu.get_quantity(), 3, "left and right jump by ten but stop at the cap")
	menu.handle_command(MenuInput.Cmd.UP)
	assert_eq(menu.get_quantity(), 3)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("get_credits"), 5)


func test_the_quantity_picker_is_capped_by_the_99_limit() -> void:
	var menu: ShopMenu = _make(5000)
	_state.call("add_item", "ration_bar", 95)  # starting 2 + 95 = 97
	_open(menu, "test_general", 0)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_quantity_max(), 2)
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(menu.get_quantity(), 2)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("item_count", "ration_bar"), 99)
	var row: Dictionary = _row(menu, "ration_bar")
	assert_false(bool(row["enabled"]), "full stack: greyed")
	assert_eq(row["reason"], "You can't carry any more of those (99 max).")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_state(), ShopMenu.State.LIST, "a greyed row opens no picker")


func test_what_you_cannot_afford_is_greyed_with_a_reason() -> void:
	var menu: ShopMenu = _make(30)
	_open(menu, "test_general", 0)
	assert_true(bool(_row(menu, "ration_bar")["enabled"]))
	var chili: Dictionary = _row(menu, "can_of_chili")
	assert_false(bool(chili["enabled"]), "45 credits is more than 30")
	_go_to(menu, "can_of_chili")
	assert_eq(menu.get_info_text(), "Not enough credits.")
	_audio.sfx_ids.clear()
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_state(), ShopMenu.State.LIST)
	assert_has(_audio.sfx_ids, "menu_back")
	assert_eq(_state.call("get_credits"), 30)


func test_credits_never_go_below_zero() -> void:
	var menu: ShopMenu = _make(15)
	_open(menu, "test_general", 0)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_quantity_max(), 1)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("get_credits"), 0)
	assert_false(bool(_row(menu, "ration_bar")["enabled"]), "nothing left to spend")


func test_the_quantity_picker_keys_and_cancel() -> void:
	var menu: ShopMenu = _make(5000)
	_open(menu, "test_general", 0)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	menu.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(menu.get_quantity(), 1, "never below one")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(menu.get_quantity(), 11)
	menu.handle_command(MenuInput.Cmd.LEFT)
	assert_eq(menu.get_quantity(), 1)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(menu.get_state(), ShopMenu.State.LIST)
	assert_eq(_state.call("get_credits"), 5000, "cancel buys nothing")
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(menu.get_state(), ShopMenu.State.COMMAND)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_false(menu.is_open())


func test_the_owned_count_follows_the_highlighted_row() -> void:
	var menu: ShopMenu = _make()
	_open(menu, "test_general", 0)
	assert_eq(menu.owned_count("ration_bar"), 2)
	assert_eq(menu.owned_count("camp_stove"), 1)
	assert_eq(menu.owned_count("juice_box"), 0)


# ---- selling ----

func test_sell_lists_the_bag_at_half_price_and_leaves_key_items_out() -> void:
	var menu: ShopMenu = _make()
	_state.call("add_item", "delivery_crate", 1)
	_state.call("add_item", "rebar_blade", 1)
	_open(menu, "test_general", 1)
	assert_eq(menu.get_mode(), ShopMenu.Mode.SELL)
	assert_eq(menu.get_state(), ShopMenu.State.LIST)
	var ids: Array[String] = []
	for row: Dictionary in menu.get_item_list().get_items():
		ids.append(str(row["id"]))
	assert_has(ids, "ration_bar")
	assert_has(ids, "rebar_blade", "spare gear sells too")
	assert_does_not_have(ids, "delivery_crate", "key items can't be sold")
	assert_eq(_row(menu, "ration_bar")["value"], "7", "half of 15, rounded down")
	assert_eq(_row(menu, "rebar_blade")["value"], "190")
	assert_eq(_row(menu, "camp_stove")["value"], "60")


func test_selling_pays_half_and_empties_the_row() -> void:
	var menu: ShopMenu = _make(0)
	var log: Array[String] = []
	menu.sold.connect(func(id: String, qty: int) -> void: log.append("%s x%d" % [id, qty]))
	_open(menu, "test_general", 1)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_state(), ShopMenu.State.QUANTITY)
	assert_eq(menu.get_quantity_max(), 2, "you own two Ration Bars")
	menu.handle_command(MenuInput.Cmd.UP)
	menu.handle_command(MenuInput.Cmd.UP)
	assert_eq(menu.get_quantity(), 2, "capped at what you own")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("get_credits"), 14)
	assert_eq(_state.call("item_count", "ration_bar"), 0)
	assert_eq(menu.get_info_text(), "Sold 2 Ration Bar. Pleasure doing business.")
	assert_null(_row(menu, "ration_bar").get("id"), "the sold-out row is gone")
	assert_eq(log, ["ration_bar x2"])


func test_selling_one_of_several_keeps_the_rest() -> void:
	var menu: ShopMenu = _make(0)
	_open(menu, "test_general", 1)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("item_count", "ration_bar"), 1)
	assert_eq(_state.call("get_credits"), 7)
	assert_eq(menu.get_state(), ShopMenu.State.LIST)


func test_selling_the_last_thing_returns_to_the_commands() -> void:
	var menu: ShopMenu = _make(0)
	for id: String in _state.call("get_item_ids"):
		if id != "camp_stove":
			_state.call("remove_item", id, int(_state.call("item_count", id)))
	_open(menu, "test_general", 1)
	assert_eq(menu.get_item_list().get_count(), 1)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("get_credits"), 60)
	assert_eq(menu.get_state(), ShopMenu.State.COMMAND, "nothing left to sell")


func test_an_empty_bag_says_so_and_stays_on_the_commands() -> void:
	var menu: ShopMenu = _make(0)
	for id: String in _state.call("get_item_ids"):
		_state.call("remove_item", id, int(_state.call("item_count", id)))
	_open(menu, "test_general", 1)
	assert_eq(menu.get_state(), ShopMenu.State.COMMAND)
	assert_eq(menu.get_info_text(), "Nothing here to sell.")


func test_a_sale_and_a_purchase_round_trip_loses_half() -> void:
	var menu: ShopMenu = _make(100)
	_open(menu, "test_general", 0)
	_go_to(menu, "juice_box")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("get_credits"), 40)
	_press(menu, [MenuInput.Cmd.CANCEL, MenuInput.Cmd.DOWN, MenuInput.Cmd.CONFIRM])
	_go_to(menu, "juice_box")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("get_credits"), 70, "paid 60, got 30 back")


# ---- gear and the arrows ----

func test_the_gear_shop_lists_gear() -> void:
	var menu: ShopMenu = _make(2000)
	_open(menu, "test_gear", 0)
	var rows: Array[Dictionary] = menu.get_item_list().get_items()
	assert_eq(rows[0]["label"], "Rebar Blade")
	assert_eq(rows[0]["value"], "380")
	_go_to(menu, "rebar_blade")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_quantity_max(), 5, "2000 / 380")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("item_count", "rebar_blade"), 1, "bought gear goes in the bag, not on the fighter")
	assert_eq(Equipment.get_equipped("red", _state)["weapon"], "scrap_sword")
	assert_eq(menu.owned_count("rebar_blade"), 1)


func test_each_fighter_gets_an_up_or_down_arrow_for_armor() -> void:
	var menu: ShopMenu = _make()
	_open(menu, "test_gear", 0)
	var arrows: Array[Dictionary] = menu.get_fighter_arrows("padded_work_vest")
	assert_eq(arrows.size(), 3)
	var by_id: Dictionary = {}
	for entry: Dictionary in arrows:
		by_id[str(entry["id"])] = entry
	assert_eq(by_id["red"]["arrow"], 1, "better than Quilted Lining")
	assert_eq(by_id["mox"]["arrow"], 1, "better than the Too-Many-Pockets Vest")
	assert_eq(by_id["otis"]["arrow"], -1, "worse than Lucky Coveralls")
	for id: String in by_id:
		assert_true(bool(by_id[id]["can_wear"]), id)


func test_owner_locked_weapons_only_show_an_arrow_for_their_owner() -> void:
	var menu: ShopMenu = _make()
	_open(menu, "test_gear", 0)
	var arrows: Dictionary = {}
	for entry: Dictionary in menu.get_fighter_arrows("rebar_blade"):
		arrows[str(entry["id"])] = entry
	assert_true(bool(arrows["red"]["can_wear"]))
	assert_eq(arrows["red"]["arrow"], 1)
	assert_false(bool(arrows["otis"]["can_wear"]), "Red's sword is not for Otis")
	assert_false(bool(arrows["mox"]["can_wear"]))
	assert_eq(arrows["otis"]["arrow"], 0)
	var hammer: Dictionary = {}
	for entry: Dictionary in menu.get_fighter_arrows("rivet_hammer"):
		hammer[str(entry["id"])] = entry
	assert_true(bool(hammer["otis"]["can_wear"]))
	assert_false(bool(hammer["red"]["can_wear"]))


func test_a_piece_the_fighter_already_has_shows_no_change() -> void:
	var menu: ShopMenu = _make()
	_state.call("add_item", "rebar_blade", 1)
	Equipment.equip("red", "weapon", "rebar_blade", _state)
	_open(menu, "test_gear", 0)
	var arrows: Dictionary = {}
	for entry: Dictionary in menu.get_fighter_arrows("rebar_blade"):
		arrows[str(entry["id"])] = entry
	assert_eq(arrows["red"]["arrow"], 0, "wearing it already")
	assert_eq(menu.owned_count("rebar_blade"), 1, "worn gear counts as owned")


# ---- mouse ----

func _motion(position: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	return event


func _click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = true
	return event


func _row_point(list: MenuList, index: int) -> Vector2:
	var rect: Rect2 = list.get_row_rect(index)
	return list.get_global_transform() * (rect.position + rect.size / 2.0)


func test_mouse_picks_rows_and_the_wheel_changes_the_amount() -> void:
	var menu: ShopMenu = _make(5000)
	_open(menu, "test_general")
	menu._input(_click(_row_point(menu.get_command_list(), 0)))
	assert_eq(menu.get_state(), ShopMenu.State.LIST, "click on Buy")
	menu._input(_motion(_row_point(menu.get_item_list(), 2)))
	assert_eq(menu.get_item_list().get_cursor_index(), 2, "hover moves the cursor")
	menu._input(_click(_row_point(menu.get_item_list(), 2)))
	assert_eq(menu.get_state(), ShopMenu.State.QUANTITY)
	menu._input(_click(Vector2(5, 5), MOUSE_BUTTON_WHEEL_UP))
	assert_eq(menu.get_quantity(), 2)
	menu._input(_click(Vector2(5, 5), MOUSE_BUTTON_WHEEL_DOWN))
	assert_eq(menu.get_quantity(), 1)
	menu._input(_click(Vector2(5, 5), MOUSE_BUTTON_RIGHT))
	assert_eq(menu.get_state(), ShopMenu.State.LIST, "right-click backs out one step")


# ---- the counter ----

func test_a_counter_opens_its_shop_once_the_ui_is_free() -> void:
	var menu: ShopMenu = _make()
	var counter: ShopCounter = ShopCounter.new()
	counter.shop_id = "test_gear"
	counter.shop_menu = menu
	add_to_root(counter)
	assert_eq(counter.current_conversation(), "shop_counter", "the hook conversation the interactor starts")
	assert_eq(counter.get_child_count() > 0, true, "a placeholder counter is built")
	var busy: Node = Node.new()
	add_to_root(busy)
	busy.add_to_group(UiStage.MODAL_GROUP)
	counter.begin_use(Vector3.ZERO)
	assert_true(counter.is_opening())
	assert_false(counter.tick_open(), "waits while a bubble is up")
	assert_false(menu.is_open())
	busy.remove_from_group(UiStage.MODAL_GROUP)
	assert_true(counter.tick_open())
	assert_true(menu.is_open())
	assert_eq(menu.get_shop_id(), "test_gear")
	assert_false(counter.is_opening())


func test_the_test_room_has_a_general_store_and_a_gear_shop_counter() -> void:
	var room: Node3D = (load(ROOM_PATH) as PackedScene).instantiate() as Node3D
	add_to_root(room)
	var seen: Array[String] = []
	for node: Node in tree.get_nodes_in_group(ShopCounter.GROUP_COUNTER):
		if room.is_ancestor_of(node):
			seen.append((node as ShopCounter).shop_id)
			assert_true(ShopData.has_shop((node as ShopCounter).shop_id))
	seen.sort()
	assert_eq(seen, ["test_gear", "test_general"] as Array[String])


func test_pressing_interact_at_a_counter_in_the_test_room_opens_the_shop() -> void:
	var room: FieldRoom = (load(ROOM_PATH) as PackedScene).instantiate() as FieldRoom
	add_to_root(room)
	room.player.read_engine_input = false
	room.interactor.read_engine_input = false
	room.runner.manual_ticks = true
	var counter: ShopCounter = room.get_node("GeneralCounter") as ShopCounter
	var menu: ShopMenu = ShopMenu.install(tree, room.player)
	menu.manual_ticks = true
	menu.animations_enabled = false
	counter.shop_menu = menu
	room.player.global_position = counter.global_position + Vector3(0.0, 0.02, 1.0)
	room.player.rotation.y = PlayerMotion.yaw_for_direction(Vector3(0.0, 0.0, -1.0))
	for i: int in 4:
		await tree.physics_frame
	room.interactor.refresh()
	assert_eq(room.interactor.get_target(), counter, "Red is facing the counter")
	assert_true(room.interactor.try_interact())
	for i: int in 12:
		await tree.process_frame
		room.runner.tick(0.016)
		menu.tick(0.016)
	assert_true(menu.is_open(), "the shop opened")
	assert_true(room.player.frozen)
	menu.close()
	for i: int in 4:
		menu.tick(0.016)
	assert_false(room.player.frozen, "Red is free again when the shop closes")
