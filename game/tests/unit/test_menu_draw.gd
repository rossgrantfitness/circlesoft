extends TestCase
## The small helpers the field menu and the shop share: number and time formatting, stat-change
## directions, colors, and the member column's pick list.


func test_play_time_shows_hours_minutes_and_seconds() -> void:
	assert_eq(MenuDraw.format_time(0), "0:00:00")
	assert_eq(MenuDraw.format_time(65), "0:01:05")
	assert_eq(MenuDraw.format_time(3725), "1:02:05")
	assert_eq(MenuDraw.format_time(36000), "10:00:00")
	assert_eq(MenuDraw.format_time(-5), "0:00:00", "never negative")


func test_credits_get_thousands_separators() -> void:
	assert_eq(MenuDraw.format_number(0), "0")
	assert_eq(MenuDraw.format_number(999), "999")
	assert_eq(MenuDraw.format_number(1000), "1,000")
	assert_eq(MenuDraw.format_number(1500), "1,500")
	assert_eq(MenuDraw.format_number(1234567), "1,234,567")


func test_stat_change_direction() -> void:
	assert_eq(MenuDraw.direction_of(5, 3), MenuDraw.ARROW_UP)
	assert_eq(MenuDraw.direction_of(3, 5), MenuDraw.ARROW_DOWN)
	assert_eq(MenuDraw.direction_of(4, 4), MenuDraw.ARROW_SAME)


func test_colors_come_from_the_palette_and_the_menu_colors() -> void:
	assert_eq(MenuDraw.color("lamp_amber"), Color.html("#FFB347"))
	assert_eq(MenuDraw.color("hp"), Color.html("#FF7A59"))
	assert_eq(MenuDraw.color("juice"), Color.html("#9BE35A"))
	assert_ne(MenuDraw.color("up"), MenuDraw.color("down"), "up and down arrows differ")


func test_the_member_column_picks_dims_and_remembers() -> void:
	var state: Node = MenuKit.make_state(self)
	var column: MemberColumn = MemberColumn.new()
	column.size = Vector2(128, 162)
	add_to_root(column)
	column.set_members(Array(state.call("get_party"), TYPE_DICTIONARY, "", null))
	assert_eq(column.selected_id(), "red")
	column.list.move(1)
	assert_eq(column.selected_id(), "otis")
	column.set_dimmed(["mox"] as Array[String])
	assert_true(column.dimmed.has("mox"))
	assert_false(bool(column.list.get_items()[2]["enabled"]), "a dimmed fighter can't be picked")
	var picked: Array[String] = []
	column.picked.connect(func(id: String) -> void: picked.append(id))
	column.list.activate()
	assert_eq(picked, ["otis"])
	column.select("mox")
	assert_eq(column.selected_id(), "mox")
	column.list.activate()
	assert_eq(picked, ["otis"], "picking a dimmed fighter does nothing")
