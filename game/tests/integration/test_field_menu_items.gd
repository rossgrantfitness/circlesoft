extends TestCase
## The Items page: tabs for items, spare gear and key items; greyed rows with a reason; using an
## item and picking who gets it; the Camp Stove only at a save lamp; revive, boosters and the 99 cap
## through the real Bag rules.

var _audio: FakeAudio = null
var _state: Node = null


func _make(at_lamp: bool = false) -> FieldMenu:
	_audio = FakeAudio.new()
	_state = MenuKit.make_state(self)
	var menu: FieldMenu = MenuKit.make_menu(self, _state, _audio)
	menu.save_spot_override = at_lamp
	return menu


func _items(menu: FieldMenu) -> PageItems:
	return menu.get_page_object() as PageItems


func _row(menu: FieldMenu, item_id: String) -> Dictionary:
	for row: Dictionary in menu.get_page_list().get_items():
		if str(row["id"]) == item_id:
			return row
	return {}


func _go_to(menu: FieldMenu, item_id: String) -> void:
	var list: MenuList = menu.get_page_list()
	for i: int in list.get_count():
		if list.get_item_id(i) == item_id:
			list.set_index(i, false)
			return
	fail("no row for %s" % item_id)


func test_three_tabs_hold_items_gear_and_key_items() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "rebar_blade")
	MenuKit.give(_state, "delivery_crate")
	MenuKit.open_page(menu, 0)
	var page: PageItems = _items(menu)
	assert_eq(page.get_tab(), "items")
	assert_eq(menu.get_page_list().get_items()[0]["label"], "Ration Bar")
	assert_null(_row(menu, "rebar_blade").get("id"), "gear is not on the Items tab")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(page.get_tab(), "gear")
	assert_eq(_row(menu, "rebar_blade")["label"], "Rebar Blade")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(page.get_tab(), "key")
	assert_eq(_row(menu, "delivery_crate")["label"], "Delivery Crate")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(page.get_tab(), "items", "the tabs wrap")
	menu.handle_command(MenuInput.Cmd.LEFT)
	assert_eq(page.get_tab(), "key")


func test_key_items_and_spare_gear_cannot_be_used() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "delivery_crate")
	MenuKit.give(_state, "rebar_blade")
	MenuKit.open_page(menu, 0)
	var page: PageItems = _items(menu)
	menu.handle_command(MenuInput.Cmd.RIGHT)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_false(page.is_picking_target())
	assert_eq(menu.get_info_text(), "Spare gear. Wear it from the Equip page.")
	menu.handle_command(MenuInput.Cmd.RIGHT)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_false(page.is_picking_target())
	assert_eq(menu.get_info_text(), "Key items can't be used here.")


func test_the_camp_stove_is_greyed_with_a_reason_away_from_a_lamp() -> void:
	var menu: FieldMenu = _make(false)
	MenuKit.open_page(menu, 0)
	var stove: Dictionary = _row(menu, "camp_stove")
	assert_false(bool(stove["enabled"]))
	assert_eq(stove["reason"], "Use it at a save lamp.")
	_go_to(menu, "camp_stove")
	menu.get_page_list().set_index(menu.get_page_list().get_cursor_index())
	assert_eq(menu.get_info_text(), "Use it at a save lamp.", "the info window says why")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_false(_items(menu).is_picking_target(), "a greyed row does nothing")
	assert_eq(_state.call("item_count", "camp_stove"), 1)


func test_the_camp_stove_rests_the_whole_crew_at_a_lamp() -> void:
	var menu: FieldMenu = _make(true)
	MenuKit.open_page(menu, 0)
	assert_true(bool(_row(menu, "camp_stove")["enabled"]))
	_go_to(menu, "camp_stove")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	var page: PageItems = _items(menu)
	assert_true(page.is_picking_target(), "asks for a confirm for the whole crew")
	assert_eq(menu.get_info_text(), "Use it on the whole crew? Press confirm.")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_false(page.is_picking_target())
	for member: Dictionary in _state.call("get_party"):
		assert_eq(member["hp"], member["hp_max"], str(member["id"]))
		assert_eq(member["juice"], member["juice_max"], str(member["id"]))
	assert_eq(_state.call("item_count", "camp_stove"), 0, "the stove is used up")
	assert_eq(menu.get_info_text(), "Everyone is rested up. Full HP and Juice.")


func test_the_camp_stove_is_greyed_when_everyone_is_already_rested() -> void:
	var menu: FieldMenu = _make(true)
	_state.call("rest_party")
	MenuKit.open_page(menu, 0)
	var stove: Dictionary = _row(menu, "camp_stove")
	assert_false(bool(stove["enabled"]))
	assert_eq(stove["reason"], "Everyone is already rested up.")


func test_battle_only_items_are_greyed() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "burn_gel")
	MenuKit.give(_state, "smoke_bomb")
	MenuKit.open_page(menu, 0)
	for id: String in ["burn_gel", "smoke_bomb"]:
		assert_false(bool(_row(menu, id)["enabled"]), id)
		assert_eq(_row(menu, id)["reason"], "Battle only.", id)


func test_using_an_item_picks_who_and_only_lists_fighters_it_helps() -> void:
	var menu: FieldMenu = _make()
	MenuKit.open_page(menu, 0)
	assert_eq(menu.get_info_text(), "Small heal. Tastes like the wrapper.")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	var page: PageItems = _items(menu)
	assert_true(page.is_picking_target())
	assert_eq(page.get_column().selected_id(), "otis", "the cursor starts on the first fighter who needs it")
	assert_true(page.get_column().dimmed.has("red"), "Red is at full HP: greyed")
	assert_false(page.get_column().dimmed.has("otis"))
	assert_false(page.get_column().dimmed.has("mox"))
	assert_eq(menu.get_info_text(), "Use it on whom?")


func test_the_heal_is_capped_at_max_hp_and_the_count_goes_down() -> void:
	var menu: FieldMenu = _make()
	_state.call("update_member", "otis", {"hp": 61, "hp_max": 66})
	MenuKit.open_page(menu, 0)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("item_count", "ration_bar"), 2)
	menu.handle_command(MenuInput.Cmd.CONFIRM)  # Otis
	assert_eq(_state.call("get_member", "otis")["hp"], 66, "capped at the maximum")
	assert_eq(_state.call("item_count", "ration_bar"), 1)
	assert_eq(menu.get_info_text(), "Otis recovered 5 HP.")


func test_it_stays_on_who_while_someone_still_needs_it_then_returns() -> void:
	var menu: FieldMenu = _make()
	_state.call("update_member", "otis", {"hp": 40, "hp_max": 66})
	_state.call("update_member", "mox", {"hp": 10, "hp_max": 34})
	MenuKit.open_page(menu, 0)
	var page: PageItems = _items(menu)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	menu.handle_command(MenuInput.Cmd.CONFIRM)  # first Ration Bar on Otis
	assert_eq(_state.call("get_member", "otis")["hp"], 66, "40 + 30 is more than 66, so it is capped")
	assert_true(page.is_picking_target(), "Mox still needs one")
	assert_true(page.get_column().dimmed.has("otis"), "Otis is full now")
	assert_eq(page.get_column().selected_id(), "mox")
	menu.handle_command(MenuInput.Cmd.CONFIRM)  # second one on Mox
	assert_eq(_state.call("get_member", "mox")["hp"], 34)
	assert_eq(_state.call("item_count", "ration_bar"), 0)
	assert_false(page.is_picking_target(), "nothing left to use")
	assert_eq(menu.get_page_list().get_count(), 2, "the used-up row is gone")


func test_cancel_from_who_changes_nothing() -> void:
	var menu: FieldMenu = _make()
	MenuKit.open_page(menu, 0)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_true(_items(menu).is_picking_target())
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_false(_items(menu).is_picking_target())
	assert_eq(menu.get_page(), "items", "cancel only stepped back")
	assert_eq(_state.call("item_count", "ration_bar"), 2)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(menu.get_page(), "main")


func test_a_greyed_target_buzzes_and_uses_nothing() -> void:
	var menu: FieldMenu = _make()
	MenuKit.open_page(menu, 0)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	var page: PageItems = _items(menu)
	page.get_column().select("red")
	assert_eq(menu.get_info_text(), "Red is already fine.")
	_audio.sfx_ids.clear()
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_state.call("item_count", "ration_bar"), 2)
	assert_has(_audio.sfx_ids, "menu_back")


func test_smelling_salts_wait_for_someone_to_be_down() -> void:
	var menu: FieldMenu = _make()
	MenuKit.open_page(menu, 0)
	var salts: Dictionary = _row(menu, "smelling_salts")
	assert_false(bool(salts["enabled"]))
	assert_eq(salts["reason"], "Nobody is Down.")
	menu.handle_command(MenuInput.Cmd.CANCEL)
	_state.call("update_member", "mox", {"hp": 0})
	MenuKit.open_page(menu, 0)
	assert_true(bool(_row(menu, "smelling_salts")["enabled"]))
	_go_to(menu, "smelling_salts")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_items(menu).get_column().selected_id(), "mox")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	var mox: Dictionary = _state.call("get_member", "mox")
	assert_eq(mox["hp"], 9, "25 percent of 34, rounded")
	assert_eq(_state.call("item_count", "smelling_salts"), 0)


func test_a_booster_raises_a_stat_for_good() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "protein_shake")
	var before: int = int(StatCalc.stats("red", _state)["attack"])
	MenuKit.open_page(menu, 0)
	assert_true(bool(_row(menu, "protein_shake")["enabled"]), "boosters work from the field menu")
	_go_to(menu, "protein_shake")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	menu.get_page_object().get_column().select("red")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(int(StatCalc.stats("red", _state)["attack"]), before + 2)
	assert_eq(menu.get_info_text(), "Red feels stronger. Attack +2.")


func test_the_count_shows_beside_each_item() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "ration_bar", 7)
	MenuKit.open_page(menu, 0)
	assert_eq(_row(menu, "ration_bar")["value"], "x9")
	MenuKit.give(_state, "ration_bar", 99)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	MenuKit.open_page(menu, 0)
	assert_eq(_row(menu, "ration_bar")["value"], "x99", "the 99 cap holds")


func test_the_page_remembers_the_tab_and_row() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "rebar_blade")
	MenuKit.give(_state, "scrap_sword")
	MenuKit.open_page(menu, 0)
	menu.handle_command(MenuInput.Cmd.RIGHT)
	menu.handle_command(MenuInput.Cmd.DOWN)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_items(menu).get_tab(), "gear")
	assert_eq(menu.get_page_list().get_cursor_index(), 1)


func test_an_empty_tab_says_so() -> void:
	var menu: FieldMenu = _make()
	MenuKit.open_page(menu, 0)
	menu.handle_command(MenuInput.Cmd.RIGHT)
	assert_eq(menu.get_page_list().get_count(), 0)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	menu.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(menu.get_page(), "items")
