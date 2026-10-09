extends TestCase
## CommandDeckModel: the deck's focus, the hack list opening and the stub rows' notes. Pure.


func test_it_starts_on_the_hack_row() -> void:
	var model: CommandDeckModel = CommandDeckModel.new()
	assert_eq(model.row_id(), "hack")
	assert_false(model.submenu_open)
	assert_eq(CommandDeckModel.ROWS, ["attack", "hack", "item"] as Array[String])


func test_scrolling_wraps_and_closes_the_list() -> void:
	var model: CommandDeckModel = CommandDeckModel.new()
	model.choose()
	assert_true(model.submenu_open)
	model.scroll(1)
	assert_eq(model.row_id(), "item")
	assert_false(model.submenu_open)
	model.scroll(1)
	assert_eq(model.row_id(), "attack")
	model.scroll(-1)
	assert_eq(model.row_id(), "item")


func test_choosing_hack_opens_then_closes_the_list() -> void:
	var model: CommandDeckModel = CommandDeckModel.new()
	assert_eq(model.choose(), "opened")
	assert_true(model.submenu_open)
	assert_eq(model.choose(), "closed")
	assert_false(model.submenu_open)
	model.choose()
	assert_true(model.close_submenu())
	assert_false(model.close_submenu())


func test_automatic_mode_has_no_list_to_open() -> void:
	var model: CommandDeckModel = CommandDeckModel.new()
	assert_eq(model.choose(true), "note")
	assert_false(model.submenu_open)
	assert_eq(model.note(), SliceUiData.text("deck.auto_note"))


func test_the_item_row_says_coming_later_and_the_note_fades() -> void:
	var model: CommandDeckModel = CommandDeckModel.new()
	model.focus("item")
	assert_eq(model.choose(), "note")
	assert_eq(model.note(), "Items: coming later")
	model.tick(5.0)
	assert_eq(model.note(), "")


func test_focusing_another_row_closes_the_list() -> void:
	var model: CommandDeckModel = CommandDeckModel.new()
	model.choose()
	model.focus("attack")
	assert_false(model.submenu_open)
	model.focus("nonsense")
	assert_eq(model.row_id(), "attack")
