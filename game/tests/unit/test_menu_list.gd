extends TestCase
## MenuList: wrap-around, scrolling a long list, cursor memory, disabled rows, mouse.

var _audio: FakeAudio = null


func _make(count: int, rows: int = 3) -> MenuList:
	_audio = FakeAudio.new()
	var list: MenuList = MenuList.new()
	list.audio.target = _audio
	list.visible_rows = rows
	list.size = Vector2(200, 100)
	add_to_root(list)
	var items: Array[Dictionary] = []
	for i: int in count:
		items.append({"id": "row%d" % i, "label": "Row %d" % i, "value": "x%d" % i})
	list.set_items(items)
	return list


func test_move_wraps_and_ticks() -> void:
	var list: MenuList = _make(4)
	assert_true(list.move(1))
	assert_eq(list.get_cursor_index(), 1)
	list.set_index(0, false)
	assert_true(list.move(-1))
	assert_eq(list.get_cursor_index(), 3, "wraps to the bottom")
	assert_true(list.move(1))
	assert_eq(list.get_cursor_index(), 0, "wraps to the top")
	assert_eq(_audio.sfx_ids.count("menu_tick"), 3)


func test_no_wrap_mode_stops_at_the_ends() -> void:
	var list: MenuList = _make(3)
	list.wrap_around = false
	assert_false(list.move(-1))
	list.set_index(2, false)
	assert_false(list.move(1))


func test_a_long_list_scrolls_to_keep_the_cursor_visible() -> void:
	var list: MenuList = _make(10, 3)
	assert_eq(list.get_top(), 0)
	list.set_index(2, false)
	assert_eq(list.get_top(), 0)
	list.move(1)
	assert_eq(list.get_top(), 1)
	list.set_index(9, false)
	assert_eq(list.get_top(), 7)
	list.move(1)  # wraps to the top
	assert_eq(list.get_top(), 0)


func test_confirm_activates_and_reports_the_index() -> void:
	var list: MenuList = _make(3)
	var picked: Array[int] = []
	list.activated.connect(func(index: int) -> void: picked.append(index))
	list.move(1)
	assert_true(list.handle_command(MenuInput.Cmd.CONFIRM))
	assert_eq(picked, [1])
	assert_has(_audio.sfx_ids, "menu_confirm")


func test_a_disabled_row_does_not_activate() -> void:
	var list: MenuList = _make(2)
	var items: Array[Dictionary] = [{"id": "a", "label": "A", "enabled": false}, {"id": "b", "label": "B"}]
	list.set_items(items)
	var picked: Array[int] = []
	list.activated.connect(func(index: int) -> void: picked.append(index))
	list.activate()
	assert_eq(picked, [])
	assert_has(_audio.sfx_ids, "menu_back")


func test_an_inactive_list_ignores_input() -> void:
	var list: MenuList = _make(3)
	list.active = false
	assert_false(list.handle_command(MenuInput.Cmd.DOWN))
	assert_eq(list.get_cursor_index(), 0)


func test_set_items_keeps_the_cursor_when_asked() -> void:
	var list: MenuList = _make(5)
	list.set_index(3, false)
	var shorter: Array[Dictionary] = [{"label": "A"}, {"label": "B"}]
	list.set_items(shorter, true)
	assert_eq(list.get_cursor_index(), 1, "kept but clamped to the new length")
	list.set_items(shorter)
	assert_eq(list.get_cursor_index(), 0)


func test_mouse_hover_wheel_and_click() -> void:
	var list: MenuList = _make(5, 4)
	var rect: Rect2 = list.get_row_rect(2)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = list.get_global_transform() * (rect.position + rect.size / 2.0)
	assert_true(list.handle_mouse(motion))
	assert_eq(list.get_cursor_index(), 2)
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	list.handle_mouse(wheel)
	assert_eq(list.get_cursor_index(), 3)
	var picked: Array[int] = []
	list.activated.connect(func(index: int) -> void: picked.append(index))
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var row0: Rect2 = list.get_row_rect(0)
	click.position = list.get_global_transform() * (row0.position + row0.size / 2.0)
	assert_true(list.handle_mouse(click))
	assert_eq(picked, [0])


func test_empty_list_is_safe() -> void:
	var list: MenuList = _make(0)
	assert_false(list.move(1))
	list.activate()
	assert_false(list.handle_mouse(InputEventMouseMotion.new()))
	assert_eq(list.get_item_id(0), "")
