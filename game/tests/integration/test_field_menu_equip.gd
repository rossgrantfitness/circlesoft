extends TestCase
## The Equip page: pick a fighter, a slot, then spare gear; stat arrows while comparing; the owner
## lock and heavy-armor rule with their reasons; taking a charm off; the bag swap.

var _audio: FakeAudio = null
var _state: Node = null


func _make() -> FieldMenu:
	_audio = FakeAudio.new()
	_state = MenuKit.make_state(self)
	return MenuKit.make_menu(self, _state, _audio)


func _equip(menu: FieldMenu) -> PageEquip:
	return menu.get_page_object() as PageEquip


## Opens Equip on a fighter's slot list (0 Red, 1 Otis, 2 Mox).
func _open_for(menu: FieldMenu, member_index: int) -> void:
	MenuKit.open_page(menu, 2)
	for i: int in member_index:
		menu.handle_command(MenuInput.Cmd.DOWN)
	menu.handle_command(MenuInput.Cmd.CONFIRM)


func _open_slot(menu: FieldMenu, member_index: int, slot_index: int) -> void:
	_open_for(menu, member_index)
	for i: int in slot_index:
		menu.handle_command(MenuInput.Cmd.DOWN)
	menu.handle_command(MenuInput.Cmd.CONFIRM)


func _row(menu: FieldMenu, item_id: String) -> Dictionary:
	for row: Dictionary in menu.get_page_list().get_items():
		if str(row["id"]) == item_id:
			return row
	return {}


func _go_to(menu: FieldMenu, item_id: String) -> void:
	var list: MenuList = menu.get_page_list()
	for i: int in list.get_count():
		if list.get_item_id(i) == item_id:
			list.set_index(i)
			return
	fail("no row for %s" % item_id)


func test_the_slot_list_shows_what_each_fighter_wears() -> void:
	var menu: FieldMenu = _make()
	_open_for(menu, 0)
	var page: PageEquip = _equip(menu)
	assert_eq(page.get_mode(), PageEquip.Mode.SLOT)
	assert_eq(page.get_member(), "red")
	var rows: Array[Dictionary] = menu.get_page_list().get_items()
	assert_eq(rows.size(), 3)
	assert_eq(rows[0]["label"], "Scrap Sword")
	assert_eq(rows[1]["label"], "Quilted Lining")
	assert_eq(rows[2]["label"], "- nothing -")
	menu.handle_command(MenuInput.Cmd.CANCEL)
	menu.handle_command(MenuInput.Cmd.DOWN)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(menu.get_page_list().get_items()[0]["label"], "Dock Mallet", "Otis")


func test_moving_over_fighters_shows_their_stats_before_picking() -> void:
	var menu: FieldMenu = _make()
	MenuKit.open_page(menu, 2)
	assert_eq(_equip(menu).get_member(), "red")
	menu.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(_equip(menu).get_member(), "otis")
	assert_eq(menu.get_page_list().get_items()[1]["label"], "Lucky Coveralls")


func test_the_owner_lock_greys_other_fighters_weapons_with_a_reason() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "rebar_blade")
	MenuKit.give(_state, "rivet_hammer")
	_open_slot(menu, 0, 0)
	assert_eq(_equip(menu).get_mode(), PageEquip.Mode.ITEM)
	assert_true(bool(_row(menu, "rebar_blade")["enabled"]))
	var hammer: Dictionary = _row(menu, "rivet_hammer")
	assert_false(bool(hammer["enabled"]), "Otis's hammer is not for Red")
	assert_eq(hammer["reason"], "Only Otis can use this.")
	_go_to(menu, "rivet_hammer")
	assert_eq(menu.get_info_text(), "Only Otis can use this.")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("item_count", "rivet_hammer"), 1, "still in the bag")
	assert_eq(Equipment.get_equipped("red", _state)["weapon"], "scrap_sword")


func test_heavy_armor_is_for_otis_only() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "lucky_coveralls")
	MenuKit.give(_state, "padded_work_vest")
	_open_slot(menu, 2, 1)
	assert_eq(_equip(menu).get_member(), "mox")
	assert_false(bool(_row(menu, "lucky_coveralls")["enabled"]))
	assert_eq(_row(menu, "lucky_coveralls")["reason"], "Heavy armor: Otis only.")
	assert_true(bool(_row(menu, "padded_work_vest")["enabled"]), "light armor fits anyone")
	menu.handle_command(MenuInput.Cmd.CANCEL)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	menu.handle_command(MenuInput.Cmd.UP)
	menu.handle_command(MenuInput.Cmd.CONFIRM)  # Otis; the slot list remembers the armor row
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_equip(menu).get_member(), "otis")
	assert_true(bool(_row(menu, "lucky_coveralls")["enabled"]), "Otis can wear heavy armor")


func test_comparing_gear_shows_each_changed_stat_with_an_arrow_direction() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "rebar_blade")
	_open_slot(menu, 0, 0)
	var page: PageEquip = _equip(menu)
	var now: Dictionary = StatCalc.stats("red", _state)
	var preview: Dictionary = page.get_preview()
	assert_eq(int(preview["attack"]), int(now["attack"]) + 4, "Rebar Blade +7 over Scrap Sword +3")
	assert_eq(MenuDraw.direction_of(int(preview["attack"]), int(now["attack"])), MenuDraw.ARROW_UP)
	assert_eq(int(preview["defense"]), int(now["defense"]), "untouched stats do not change")
	assert_eq(MenuDraw.direction_of(int(preview["defense"]), int(now["defense"])), MenuDraw.ARROW_SAME)


func test_a_worse_piece_shows_a_down_arrow() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "rebar_blade")
	_open_slot(menu, 0, 0)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(Equipment.get_equipped("red", _state)["weapon"], "rebar_blade")
	# The Scrap Sword went back to the bag; wearing it again is a step down.
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	var now: Dictionary = StatCalc.stats("red", _state)
	var preview: Dictionary = _equip(menu).get_preview()
	assert_eq(MenuDraw.direction_of(int(preview["attack"]), int(now["attack"])), MenuDraw.ARROW_DOWN)


func test_a_disabled_row_shows_no_preview() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "rivet_hammer")
	_open_slot(menu, 0, 0)
	assert_true(_equip(menu).get_preview().is_empty())


func test_equipping_swaps_with_the_bag_and_follows_the_stats() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "rebar_blade")
	var before: Dictionary = StatCalc.stats("red", _state)
	_open_slot(menu, 0, 0)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	var page: PageEquip = _equip(menu)
	assert_eq(page.get_mode(), PageEquip.Mode.SLOT, "back to the slot list")
	assert_eq(Equipment.get_equipped("red", _state)["weapon"], "rebar_blade")
	assert_eq(_state.call("item_count", "rebar_blade"), 0, "worn gear leaves the bag")
	assert_eq(_state.call("item_count", "scrap_sword"), 1, "the old one goes in")
	assert_eq(int(StatCalc.stats("red", _state)["attack"]), int(before["attack"]) + 4)
	assert_eq(menu.get_page_list().get_items()[0]["label"], "Rebar Blade")
	assert_eq(menu.get_info_text(), "Red is wearing Rebar Blade.")


func test_a_charm_can_be_put_on_and_taken_off() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "lucky_bolt")
	_open_slot(menu, 0, 2)
	assert_eq(menu.get_page_list().get_count(), 1, "no 'take it off' while the slot is empty")
	assert_eq(menu.get_page_list().get_items()[0]["id"], "lucky_bolt")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(Equipment.get_equipped("red", _state)["charm"], "lucky_bolt")
	menu.handle_command(MenuInput.Cmd.CONFIRM)  # the slot list remembers the charm row
	var rows: Array[Dictionary] = menu.get_page_list().get_items()
	assert_eq(rows[rows.size() - 1]["id"], PageEquip.REMOVE_ID, "a worn charm offers 'Take it off' at the end of the list")
	menu.get_page_list().set_index(rows.size() - 1)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(Equipment.get_equipped("red", _state)["charm"], "")
	assert_eq(_state.call("item_count", "lucky_bolt"), 1, "back in the bag")
	assert_eq(menu.get_info_text(), "Red took off the charm.")


func test_a_weapon_cannot_be_taken_off() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "rebar_blade")
	_open_slot(menu, 0, 0)
	for row: Dictionary in menu.get_page_list().get_items():
		assert_ne(row["id"], PageEquip.REMOVE_ID)


func test_a_slot_with_no_spares_says_so_and_stays_on_the_slot_list() -> void:
	var menu: FieldMenu = _make()
	_open_slot(menu, 0, 0)
	assert_eq(_equip(menu).get_mode(), PageEquip.Mode.SLOT)
	assert_eq(menu.get_info_text(), "No spare weapon in the bag.")


func test_cancel_steps_back_one_level_at_a_time() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "rebar_blade")
	_open_slot(menu, 0, 0)
	var page: PageEquip = _equip(menu)
	assert_eq(page.get_mode(), PageEquip.Mode.ITEM)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(page.get_mode(), PageEquip.Mode.SLOT)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(page.get_mode(), PageEquip.Mode.MEMBER)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(menu.get_page(), "main")


func test_equipping_armor_with_hp_raises_the_maximum() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "padded_work_vest")
	_open_slot(menu, 0, 1)
	var rows: Array[Dictionary] = menu.get_page_list().get_items()
	assert_eq(rows[0]["id"], "padded_work_vest")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(Equipment.get_equipped("red", _state)["armor"], "padded_work_vest")
	var stored: int = int(_state.call("get_member", "red")["hp_max"])
	assert_eq(stored, int(StatCalc.stats("red", _state)["hp"]), "the stored maximum follows the gear")
