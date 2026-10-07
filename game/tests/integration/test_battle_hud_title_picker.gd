extends TestCase
## The title screen's "Battle Test" entry: the menu items come from data, Battle Test opens the
## encounter picker, the picker lists every encounter (name, enemies, tier tag), cancel goes back to
## the menu, and picking one fades out and emits battle_test_requested(encounter_id).

const SCENE_PATH: String = "res://scenes/ui/title_screen.tscn"
const MENU_OPEN_WAIT_S: float = 0.7
const FADE_WAIT_LIMIT_S: float = 3.0


func _make_title() -> TitleScreen:
	var title: TitleScreen = (load(SCENE_PATH) as PackedScene).instantiate() as TitleScreen
	title.save_manager = own(FakeTitleSaves.new()) as Node  # no saves, whatever is on this machine
	add_to_root(title)
	return title


func _action(name: StringName, pressed: bool = true) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = name
	event.pressed = pressed
	return event


func _press(name: StringName) -> void:
	tree.root.push_input(_action(name))
	tree.root.push_input(_action(name, false))


func _wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout


func _open_picker(title: TitleScreen) -> void:
	await tree.process_frame
	_press(&"confirm")
	await _wait(MENU_OPEN_WAIT_S)
	for i: int in title.get_item_ids().find("battle_test"):
		_press(&"move_down")
	_press(&"confirm")


func _encounters() -> Array:
	return DataDB.get_value("battle/encounters", "encounters", [])


func test_menu_items_come_from_data_and_include_battle_test() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	var wanted: Array[String] = []
	var labels: Array[String] = []
	for entry: Dictionary in DataDB.get_dict("text/title")["menu"]:
		wanted.append(str(entry["id"]))
		labels.append(str(entry["label"]))
	assert_eq(wanted, ["new_game", "continue", "config", "battle_test", "quit"])
	assert_eq(title.get_item_ids(), wanted)
	assert_eq(labels, ["New Game", "Continue", "Config", "Battle Test", "Quit"])
	assert_eq(title.get_item_label_texts(), labels)


func test_version_tag_is_0_3_0_from_data() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	assert_eq(str(DataDB.get_dict("text/title")["version"]), "v0.3.0")
	assert_eq(title.get_version_text(), "v0.3.0")


func test_the_menu_rows_fit_inside_the_menu_window() -> void:
	var layout: Dictionary = DataDB.get_dict("ui/ui_theme")["title_screen"]
	var window: Dictionary = layout["menu_window"]
	var rows: int = (DataDB.get_dict("text/title")["menu"] as Array).size()
	var last_bottom: float = float(layout["menu_item_first_y"]) + float(rows) * float(layout["menu_item_step"])
	assert_le(last_bottom, float(window["h"]))
	assert_le(float(window["y"]) + float(window["h"]), 197.0, "stays above the version and credit line")


func test_battle_test_opens_the_picker_and_hides_the_menu_rows() -> void:
	var title: TitleScreen = _make_title()
	await _open_picker(title)
	assert_eq(title.get_state(), TitleScreen.State.PICKER)
	assert_true(title.get_picker().is_open())
	await _wait(0.5)
	assert_false(title.is_menu_visible(), "the menu window closes behind the picker")


func test_the_picker_stays_shut_until_battle_test_is_chosen() -> void:
	var title: TitleScreen = _make_title()
	await tree.process_frame
	assert_false(title.get_picker().is_open())
	_press(&"confirm")
	await _wait(MENU_OPEN_WAIT_S)
	assert_false(title.get_picker().is_open())


func test_the_picker_lists_every_encounter_with_name_enemies_and_tier() -> void:
	var title: TitleScreen = _make_title()
	await _open_picker(title)
	var picker: BattleTestPicker = title.get_picker()
	var encounters: Array = _encounters()
	assert_gt(encounters.size(), 0)
	var ids: Array[String] = []
	for entry: Dictionary in encounters:
		ids.append(str(entry["id"]))
	assert_eq(picker.get_encounter_ids(), ids, "every encounter in encounters.json, in file order")
	assert_eq(picker.get_list().get_count(), ids.size())
	var rows: Array[Dictionary] = picker.get_rows()
	for i: int in rows.size():
		var entry: Dictionary = encounters[i]
		assert_eq(rows[i]["name"], str(entry["name"]), "friendly name")
		assert_eq(rows[i]["tier"], str(entry["tier"]))
		assert_gt(str(rows[i]["enemies"]).length(), 0)
		assert_eq(picker.get_list().get_items()[i]["label"], str(entry["name"]))
	assert_eq(picker.tier_text("tutorial"), "Tutorial")
	assert_eq(picker.tier_text("tough"), "Tough")


func test_enemy_summary_names_each_enemy_and_counts_repeats() -> void:
	var title: TitleScreen = _make_title()
	await _open_picker(title)
	var by_id: Dictionary = {}
	for row: Dictionary in title.get_picker().get_rows():
		by_id[row["id"]] = row
	assert_eq(by_id["grunt_solo"]["enemies"], "Signals Grunt")
	assert_eq(by_id["grunt_pair"]["enemies"], "Signals Grunt x2")
	assert_true(str(by_id["squad_four"]["enemies"]).contains("Signals Grunt x2"))
	assert_true(str(by_id["squad_four"]["enemies"]).contains("Buzzkill"))


func test_every_row_fits_inside_the_picker_window() -> void:
	var title: TitleScreen = _make_title()
	await _open_picker(title)
	var width: float = BattleUiData.ui_rect("layout.encounter_picker").size.x
	for row: Dictionary in title.get_picker().get_rows():
		var enemies: float = float(UiFonts.text_width("tag", str(row["enemies"])))
		var tag: float = float(UiFonts.text_width("tag", title.get_picker().tier_text(str(row["tier"])))) + 8.0
		assert_lt(20.0 + enemies, width - 14.0 - tag, "%s: enemies line clears the tier tag" % row["id"])
		assert_lt(float(UiFonts.text_width("menu", str(row["name"]))) + 20.0, width - 14.0 - tag, str(row["id"]))


func test_picker_fits_the_stage_and_every_encounter_is_visible_or_scrollable() -> void:
	var rect: Rect2 = BattleUiData.ui_rect("layout.encounter_picker")
	assert_true(Rect2(0, 0, 384, 216).encloses(rect))
	var rows: int = BattleUiData.ui_int("layout.encounter_picker.rows")
	var row_h: int = BattleUiData.ui_int("layout.encounter_picker.row_h")
	assert_le(float(BattleUiData.ui_int("layout.encounter_picker.first_y") + rows * row_h), rect.size.y)


func test_cursor_keys_move_through_the_picker_and_cancel_returns_to_the_menu() -> void:
	var title: TitleScreen = _make_title()
	await _open_picker(title)
	var list: MenuList = title.get_picker().get_list()
	assert_eq(list.get_cursor_index(), 0)
	_press(&"move_down")
	assert_eq(list.get_cursor_index(), 1)
	_press(&"cancel")
	assert_eq(title.get_state(), TitleScreen.State.MENU)
	assert_false(title.get_picker().is_open())
	await _wait(0.5)
	assert_true(title.is_menu_ready(), "the menu window is back")
	assert_eq(title.get_cursor_index(), title.get_item_ids().find("battle_test"), "the title cursor is still on Battle Test")


func test_picking_emits_the_signal_with_the_right_id_after_the_fade() -> void:
	var title: TitleScreen = _make_title()
	await _open_picker(title)
	var picked: Array[String] = []
	var demos: Array[int] = [0]
	title.battle_test_requested.connect(func(id: String) -> void: picked.append(id))
	title.start_demo_requested.connect(func() -> void: demos[0] += 1)
	_press(&"move_down")
	_press(&"move_down")  # the third encounter
	_press(&"confirm")
	var wanted: String = str((_encounters()[2] as Dictionary)["id"])
	assert_eq(title.get_state(), TitleScreen.State.LEAVING)
	var waited: float = 0.0
	while picked.is_empty() and waited < FADE_WAIT_LIMIT_S:
		await _wait(0.1)
		waited += 0.1
	assert_eq(picked, [wanted])
	assert_eq(demos[0], 0, "Battle Test does not start the demo")


func test_the_first_encounter_is_picked_with_one_confirm() -> void:
	var title: TitleScreen = _make_title()
	await _open_picker(title)
	var picked: Array[String] = []
	title.battle_test_requested.connect(func(id: String) -> void: picked.append(id))
	_press(&"confirm")
	var waited: float = 0.0
	while picked.is_empty() and waited < FADE_WAIT_LIMIT_S:
		await _wait(0.1)
		waited += 0.1
	assert_eq(picked, [str((_encounters()[0] as Dictionary)["id"])])


func test_input_is_ignored_while_leaving_after_a_pick() -> void:
	var title: TitleScreen = _make_title()
	await _open_picker(title)
	_press(&"confirm")
	_press(&"cancel")
	assert_eq(title.get_state(), TitleScreen.State.LEAVING)


func test_picker_works_with_the_mouse_right_click_cancels() -> void:
	var title: TitleScreen = _make_title()
	await _open_picker(title)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	assert_true(title.get_picker().handle_mouse(click))
	assert_eq(title.get_state(), TitleScreen.State.MENU)


func test_picker_mouse_click_on_a_row_picks_it() -> void:
	var title: TitleScreen = _make_title()
	await _open_picker(title)
	var picker: BattleTestPicker = title.get_picker()
	var picked: Array[String] = []
	picker.picked.connect(func(id: String) -> void: picked.append(id))
	var list: MenuList = picker.get_list()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = list.get_global_transform() * list.get_row_rect(3).get_center()
	assert_true(picker.handle_mouse(click))
	assert_eq(picked, [str((_encounters()[3] as Dictionary)["id"])])


func test_every_encounter_has_a_friendly_name_and_a_known_tier() -> void:
	for entry: Dictionary in _encounters():
		assert_true(entry.has("name") and str(entry["name"]).length() > 0, str(entry["id"]))
		assert_has(["tutorial", "regular", "tough"], str(entry.get("tier", "")), str(entry["id"]))
		assert_true(BattleUiData.ui("tiers", {}).has(str(entry["tier"])), "a tag color for %s" % entry["tier"])
