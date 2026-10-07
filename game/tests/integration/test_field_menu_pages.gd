extends TestCase
## The Skills, Status and Party pages and the main page's side panel.

const SCRATCH: String = "user://test_menu_pages_scratch.json"

var _audio: FakeAudio = null
var _state: Node = null


func _make(plain_state: bool = false) -> FieldMenu:
	_audio = FakeAudio.new()
	_state = MenuKit.make_state(self, plain_state)
	return MenuKit.make_menu(self, _state, _audio)


# ---- the side panel ----

func test_the_side_panel_shows_the_crew_credits_time_and_place() -> void:
	var menu: FieldMenu = _make()
	_state.call("add_credits", 1240)
	_state.call("tick_play_time", 3725.0)
	_state.call("set_location", "harrow_landing", "")
	_state.call("update_member", "otis", {"hp": 40})
	menu.open()
	var page: PageMain = menu.get_page_object() as PageMain
	assert_eq(page.footer_text(), {"credits": "1,240", "time": "1:02:05"})
	assert_eq(menu.get_place_text(), "Harrow Landing")
	var members: Array[Dictionary] = page.get_column().members
	assert_eq(members.size(), 3)
	assert_eq(members[0]["name"], "Red")
	assert_eq(members[1]["hp"], 40, "HP comes straight from the party state")
	assert_eq(members[2]["juice_max"], 16)
	assert_eq(page.get_column().members[1]["initial"], "O", "placeholder initial heads")


func test_the_side_panel_refreshes_when_the_menu_opens_again() -> void:
	var menu: FieldMenu = _make()
	menu.open()
	assert_eq((menu.get_page_object() as PageMain).footer_text()["credits"], "0")
	menu.close()
	_state.call("add_credits", 5)
	menu.open()
	assert_eq((menu.get_page_object() as PageMain).footer_text()["credits"], "5")


func test_an_unknown_room_gets_a_tidied_name() -> void:
	var menu: FieldMenu = _make()
	_state.call("set_location", "some_new_room", "")
	menu.open()
	assert_eq(menu.get_place_text(), "Some New Room")


# ---- skills ----

func test_skills_lists_what_each_fighter_knows_with_costs() -> void:
	var menu: FieldMenu = _make()
	MenuKit.open_page(menu, 1)
	var page: PageSkills = menu.get_page_object() as PageSkills
	assert_eq(page.get_mode(), PageSkills.Mode.MEMBER)
	var rows: Array[Dictionary] = menu.get_page_list().get_items()
	assert_eq(rows.size(), 2, "Red knows two skills at level 3")
	assert_eq(rows[0]["label"], "Porch Light")
	assert_eq(rows[0]["value"], "8")
	menu.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(menu.get_page_list().get_items()[0]["label"], "Heave-Ho", "moving over Otis shows his skills")


func test_attack_skills_are_greyed_as_battle_only() -> void:
	var menu: FieldMenu = _make()
	MenuKit.open_page(menu, 1)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	var page: PageSkills = menu.get_page_object() as PageSkills
	assert_eq(page.get_mode(), PageSkills.Mode.LIST)
	var row: Dictionary = menu.get_page_list().get_items()[0]
	assert_false(bool(row["enabled"]))
	assert_eq(menu.get_info_text(), "Battle only.")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(page.get_mode(), PageSkills.Mode.LIST, "a greyed skill does nothing")


func _skills_for_otis_at_level_4(menu: FieldMenu) -> void:
	_state.call("update_member", "otis", {"level": 4})
	MenuKit.open_page(menu, 1)
	menu.handle_command(MenuInput.Cmd.DOWN)
	menu.handle_command(MenuInput.Cmd.CONFIRM)


func test_a_field_heal_skill_heals_a_friend_and_pays_the_juice() -> void:
	var menu: FieldMenu = _make()
	_skills_for_otis_at_level_4(menu)
	var page: PageSkills = menu.get_page_object() as PageSkills
	var drop_row: Dictionary = menu.get_page_list().get_items()[2]
	assert_eq(drop_row["label"], "Cough Drop")
	assert_true(bool(drop_row["enabled"]), "a heal works in the field")
	menu.get_page_list().set_index(2)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(page.get_mode(), PageSkills.Mode.TARGET)
	assert_true(page.get_column().dimmed.has("red"), "Red is not hurt")
	page.get_column().select("mox")
	var juice_before: int = int(_state.call("get_member", "otis")["juice"])
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(int(_state.call("get_member", "mox")["hp"]), 34, "healed up to the maximum")
	assert_eq(int(_state.call("get_member", "otis")["juice"]), juice_before - 4, "Cough Drop costs 4 Juice")
	assert_eq(page.get_mode(), PageSkills.Mode.LIST)
	assert_true(menu.get_info_text().begins_with("Mox feels better"))


func test_not_enough_juice_greys_the_skill_with_a_reason() -> void:
	var menu: FieldMenu = _make()
	_state.call("update_member", "otis", {"juice": 2})
	_skills_for_otis_at_level_4(menu)
	var row: Dictionary = menu.get_page_list().get_items()[2]
	assert_false(bool(row["enabled"]))
	assert_eq(row["reason"], "Not enough Juice.")


func test_a_heal_skill_with_nobody_hurt_is_greyed() -> void:
	var menu: FieldMenu = _make()
	_state.call("rest_party")
	_skills_for_otis_at_level_4(menu)
	var row: Dictionary = menu.get_page_list().get_items()[2]
	assert_false(bool(row["enabled"]))
	assert_eq(row["reason"], "Nobody needs that right now.")


func test_skills_cancel_steps_back() -> void:
	var menu: FieldMenu = _make()
	_skills_for_otis_at_level_4(menu)
	var page: PageSkills = menu.get_page_object() as PageSkills
	menu.get_page_list().set_index(2)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(page.get_mode(), PageSkills.Mode.TARGET)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(page.get_mode(), PageSkills.Mode.LIST)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(page.get_mode(), PageSkills.Mode.MEMBER)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(menu.get_page(), "main")


# ---- status ----

func test_status_uses_stat_calc_for_the_numbers() -> void:
	var menu: FieldMenu = _make()
	MenuKit.give(_state, "rebar_blade")
	Equipment.equip("red", "weapon", "rebar_blade", _state)
	MenuKit.open_page(menu, 3)
	var page: PageStatus = menu.get_page_object() as PageStatus
	assert_eq(page.get_member(), "red")
	var shown: Dictionary = page.describe("red")
	assert_eq(shown["stats"], StatCalc.stats("red", _state))
	assert_eq(shown["name"], "Red")
	assert_eq(shown["level"], 3)
	assert_eq(shown["gear"]["weapon"], "Rebar Blade")
	assert_eq(shown["gear"]["charm"], "- nothing -")
	assert_eq(shown["skills"], ["Porch Light", "Double Swing"])
	assert_eq(shown["condition"], "Fine")


func test_status_shows_xp_to_the_next_level_and_down_for_the_count() -> void:
	var menu: FieldMenu = _make()
	_state.call("update_member", "mox", {"hp": 0, "xp": 10})
	MenuKit.open_page(menu, 3)
	var page: PageStatus = menu.get_page_object() as PageStatus
	var to_next: int = Progression.new().xp_to_next(3, 10)
	assert_gt(to_next, 0)
	assert_eq(page.describe("mox")["xp_line"], "%d XP to next level" % to_next)
	assert_eq(page.describe("mox")["condition"], "Down for the Count")


func test_status_switches_fighters_with_up_and_down() -> void:
	var menu: FieldMenu = _make()
	MenuKit.open_page(menu, 3)
	var page: PageStatus = menu.get_page_object() as PageStatus
	menu.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(page.get_member(), "otis")
	menu.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(page.get_member(), "mox")
	menu.handle_command(MenuInput.Cmd.CANCEL)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq((menu.get_page_object() as PageStatus).get_member(), "mox", "remembers who you were looking at")


# ---- party ----

func test_party_swaps_two_fighters_and_red_stays_the_leader() -> void:
	var menu: FieldMenu = _make()
	MenuKit.open_page(menu, 4)
	var page: PageParty = menu.get_page_object() as PageParty
	assert_eq(page.get_mode(), PageParty.Mode.PICK)
	assert_true(page.get_column().dimmed.has("red"), "the leader is locked")
	assert_eq(page.get_column().selected_id(), "otis")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(page.get_mode(), PageParty.Mode.SWAP)
	assert_eq(page.get_column().selected_id(), "mox", "the cursor jumps to the other fighter")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(page.get_mode(), PageParty.Mode.PICK)
	assert_eq(_state.call("get_party_ids"), ["red", "mox", "otis"])
	assert_eq(menu.get_info_text(), "Order set: Red, Mox, Otis.")


func test_party_cancel_in_the_swap_goes_back_without_changes() -> void:
	var menu: FieldMenu = _make()
	MenuKit.open_page(menu, 4)
	var page: PageParty = menu.get_page_object() as PageParty
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(page.get_mode(), PageParty.Mode.PICK)
	assert_eq(_state.call("get_party_ids"), ["red", "otis", "mox"])
	menu.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(menu.get_page(), "main")


func test_party_order_is_locked_when_game_state_cannot_reorder() -> void:
	var menu: FieldMenu = _make(true)
	if _state.has_method("set_party_order"):
		return  # the real GameState can reorder now; the locked case no longer exists
	MenuKit.open_page(menu, 4)
	var page: PageParty = menu.get_page_object() as PageParty
	assert_eq(page.get_column().dimmed.size(), 3, "everyone is locked")
	assert_eq(menu.get_info_text(), "The order can't be changed right now.")
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(page.get_mode(), PageParty.Mode.PICK)
