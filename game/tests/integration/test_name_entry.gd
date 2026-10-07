extends TestCase
## NameEntry: the "Name the Hero" window: it starts on "Red", takes up to 8 letters from the grid or
## the keyboard, deletes, falls back to the default when empty, and reports submit / cancel.


func _make() -> NameEntry:
	var entry: NameEntry = NameEntry.new()
	entry.audio.target = FakeAudio.new()
	add_to_root(entry)
	entry.open()
	return entry


func _action(name: StringName) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _key(code: Key, unicode: int = 0) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = true
	return event


func test_it_starts_on_the_default_name_from_data() -> void:
	var entry: NameEntry = _make()
	assert_eq(entry.get_name_text(), "Red")
	assert_eq(entry.get_default_name(), "Red")
	assert_eq(entry.get_max_length(), 8, "the style guide's 8 letters")
	assert_eq(entry.get_title_text(), str(DataDB.get_dict("text/title")["name_entry"]["title"]))


func test_picking_letters_from_the_grid_adds_them() -> void:
	var entry: NameEntry = _make()
	entry.set_name_text("")
	entry.set_cursor(0, 0)
	assert_eq(entry.get_cursor_cell(), "A")
	entry.handle_command(MenuInput.Cmd.CONFIRM)
	entry.handle_command(MenuInput.Cmd.RIGHT)
	entry.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(entry.get_name_text(), "AB")


func test_the_cursor_wraps_and_moves_between_rows() -> void:
	var entry: NameEntry = _make()
	entry.handle_command(MenuInput.Cmd.LEFT)
	assert_eq(entry.get_cursor(), Vector2i(12, 0), "wraps to the end of the row")
	entry.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(entry.get_cursor_cell(), "Z")
	entry.handle_command(MenuInput.Cmd.UP)
	entry.handle_command(MenuInput.Cmd.UP)
	assert_eq(entry.get_cursor().y, entry.get_grid_rows().size(), "up from the top goes to the action row")
	assert_has(entry.get_action_ids(), entry.get_cursor_cell())


func test_the_name_stops_at_eight_letters() -> void:
	var entry: NameEntry = _make()
	entry.set_name_text("")
	for i: int in 12:
		entry.type_char("x")
	assert_eq(entry.get_name_text(), "xxxxxxxx")
	assert_false(entry.type_char("y"))


func test_letters_not_in_the_allowed_set_are_refused() -> void:
	var entry: NameEntry = _make()
	entry.set_name_text("")
	assert_false(entry.type_char("@"))
	assert_false(entry.type_char("é"))
	assert_false(entry.type_char("ab"), "one character at a time")
	assert_true(entry.type_char("a"))
	assert_true(entry.type_char(" "))
	assert_eq(entry.get_name_text(), "a ")


func test_a_name_cannot_start_with_a_space() -> void:
	var entry: NameEntry = _make()
	entry.set_name_text("")
	assert_false(entry.type_char(" "))


func test_cancel_deletes_a_letter_then_backs_out_when_empty() -> void:
	var entry: NameEntry = _make()
	var backed: Array[bool] = []
	entry.cancelled.connect(func() -> void: backed.append(true))
	entry.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(entry.get_name_text(), "Re")
	entry.handle_command(MenuInput.Cmd.CANCEL)
	entry.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(entry.get_name_text(), "")
	assert_eq(backed.size(), 0, "deleting is not backing out")
	entry.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(backed.size(), 1)


func test_the_action_cells_work() -> void:
	var entry: NameEntry = _make()
	entry.set_name_text("Abc")
	var row: int = entry.get_grid_rows().size()
	var ids: Array[String] = entry.get_action_ids()
	entry.set_cursor(ids.find("space"), row)
	entry.pick()
	assert_eq(entry.get_name_text(), "Abc ")
	entry.set_cursor(ids.find("delete"), row)
	entry.pick()
	assert_eq(entry.get_name_text(), "Abc")
	entry.set_cursor(ids.find("default"), row)
	entry.pick()
	assert_eq(entry.get_name_text(), "Red")


func test_ok_submits_the_name_and_an_empty_name_becomes_the_default() -> void:
	var entry: NameEntry = _make()
	var heard: Array[String] = []
	entry.submitted.connect(func(hero_name: String) -> void: heard.append(hero_name))
	entry.set_name_text("Ruby")
	entry.set_cursor(entry.get_action_ids().find("ok"), entry.get_grid_rows().size())
	entry.pick()
	entry.set_name_text("")
	entry.submit()
	entry.set_name_text("  ")
	entry.submit()
	assert_eq(heard, ["Ruby", "Red", "Red"])


func test_a_keyboard_types_letters_deletes_and_submits() -> void:
	var entry: NameEntry = _make()
	var heard: Array[String] = []
	entry.submitted.connect(func(hero_name: String) -> void: heard.append(hero_name))
	entry.set_name_text("")
	assert_true(entry.handle_event(_key(KEY_Z, 90)), "Z types a Z (it is not Confirm here)")
	assert_true(entry.handle_event(_key(KEY_E, 101)))
	assert_true(entry.handle_event(_key(KEY_D, 100)))
	assert_eq(entry.get_name_text(), "Zed")
	entry.handle_event(_key(KEY_BACKSPACE))
	assert_eq(entry.get_name_text(), "Ze")
	entry.handle_event(_key(KEY_ENTER))
	assert_eq(heard, ["Ze"])


func test_escape_cancels_from_the_keyboard() -> void:
	var entry: NameEntry = _make()
	var backed: Array[bool] = []
	entry.cancelled.connect(func() -> void: backed.append(true))
	entry.handle_event(_key(KEY_ESCAPE))
	assert_eq(backed.size(), 1)


func test_arrow_keys_and_the_pad_move_the_cursor_through_actions() -> void:
	var entry: NameEntry = _make()
	assert_true(entry.handle_event(_action(&"move_right")))
	assert_eq(entry.get_cursor(), Vector2i(1, 0))
	assert_true(entry.handle_event(_action(&"move_down")))
	assert_eq(entry.get_cursor(), Vector2i(1, 1))
	assert_true(entry.handle_event(_action(&"confirm")))
	assert_eq(entry.get_name_text(), "RedO")


func test_the_mouse_hovers_clicks_and_right_click_deletes() -> void:
	var entry: NameEntry = _make()
	entry.set_name_text("")
	var rect: Rect2 = entry.get_cell_rect(2, 0)
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = entry.get_global_transform() * rect.get_center()
	assert_true(entry.handle_event(move))
	assert_eq(entry.get_cursor(), Vector2i(2, 0))
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = move.position
	assert_true(entry.handle_event(click))
	assert_eq(entry.get_name_text(), "C")
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	assert_true(entry.handle_event(right))
	assert_eq(entry.get_name_text(), "")


func test_a_closed_window_ignores_input() -> void:
	var entry: NameEntry = _make()
	entry.close()
	assert_false(entry.handle_event(_action(&"confirm")))
	assert_false(entry.visible)


func test_reopening_starts_fresh() -> void:
	var entry: NameEntry = _make()
	entry.set_name_text("Zzz")
	entry.close()
	entry.open()
	assert_eq(entry.get_name_text(), "Red")
	assert_eq(entry.get_cursor(), Vector2i(0, 0))


func test_every_cell_fits_inside_the_window() -> void:
	var entry: NameEntry = _make()
	var bounds: Rect2 = Rect2(Vector2.ZERO, entry.size)
	for row: int in entry.get_grid_rows().size() + 1:
		var cols: int = entry.get_grid_rows()[row].length() if row < entry.get_grid_rows().size() else entry.get_action_ids().size()
		for col: int in cols:
			assert_true(bounds.encloses(entry.get_cell_rect(col, row)), "cell %d,%d" % [col, row])
	assert_true(Rect2(0, 0, 384, 216).encloses(Rect2(entry.position, entry.size)), "the window fits the stage")


func test_every_grid_letter_is_allowed() -> void:
	var data: Dictionary = DataDB.get_dict("text/title")["name_entry"]
	var allowed: String = str(data["allowed"])
	for row: String in data["rows"]:
		for i: int in row.length():
			assert_true(allowed.contains(row[i]), "'%s' is on the grid but not allowed" % row[i])
