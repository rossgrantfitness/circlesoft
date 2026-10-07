extends TestCase
## Milestone 1 integration: main.tscn shows the title first, loads the test room when the title
## emits start_demo_requested (New Game: Red's home in Harrow), and goes back to the title on Esc / Start.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const TITLE_STUB: String = "res://tests/fixtures/ui/title_stub.tscn"
const MISSING_TITLE: String = "res://scenes/ui/no_such_title.tscn"
## New Game from the title now starts in Red's home in Harrow Landing (rooms.json "start_room").
const ROOM_NAME: String = "HarrowHome"
## start_demo() (no title, or the title turned off) still loads the scene Main was given: the test room.
const DEMO_ROOM_NAME: String = "PsxTestRoom"


func after_each() -> void:
	Input.action_release(&"start")


func _make_main(title_path: String, show_title: bool = true) -> Main:
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate() as Main
	main.title_scene_path = title_path
	main.show_title = show_title
	add_to_root(main)
	return main


func _room(main: Main, room_name: String = ROOM_NAME) -> Node:
	return main.screen.get_world_root().get_node_or_null(room_name)


func test_shows_the_title_first_when_it_exists() -> void:
	var main: Main = _make_main(TITLE_STUB)
	assert_eq(main.get_state(), Main.State.TITLE)
	assert_not_null(main.get_title())
	assert_eq(main.get_title().get_parent(), main.screen.get_ui_layer(), "title is on the sharp UI layer")
	assert_null(_room(main), "no room yet")


func test_start_signal_loads_the_room_and_removes_the_title() -> void:
	var main: Main = _make_main(TITLE_STUB)
	var title: Node = main.get_title()
	title.emit_signal("start_demo_requested")
	assert_eq(main.get_state(), Main.State.ROOM)
	assert_not_null(_room(main), "test room loaded into the PSX world")
	assert_null(main.get_title())
	assert_null(title.get_parent(), "title left the tree")


func test_back_to_title_clears_the_room_and_shows_the_title_again() -> void:
	var main: Main = _make_main(TITLE_STUB)
	main.get_title().emit_signal("start_demo_requested")
	main.go_to_title()
	assert_eq(main.get_state(), Main.State.TITLE)
	assert_null(_room(main))
	assert_not_null(main.get_title())
	main.get_title().emit_signal("start_demo_requested")
	assert_not_null(_room(main), "can start again")


func test_goes_straight_to_the_room_when_there_is_no_title_scene() -> void:
	var main: Main = _make_main(MISSING_TITLE)
	assert_eq(main.get_state(), Main.State.ROOM)
	assert_not_null(_room(main, DEMO_ROOM_NAME))


func test_goes_straight_to_the_room_when_title_is_off() -> void:
	var main: Main = _make_main(TITLE_STUB, false)
	assert_eq(main.get_state(), Main.State.ROOM)
	assert_not_null(_room(main, DEMO_ROOM_NAME))


func test_start_button_in_the_room_returns_to_the_title() -> void:
	var main: Main = _make_main(TITLE_STUB)
	main.get_title().emit_signal("start_demo_requested")
	# The opening scene of Harrow holds Esc / Start while it talks: mark it seen.
	tree.root.get_node("GameState").call("set_flag", "intro_seen", true)
	await tree.process_frame
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.ROOM, "stays in the room with no input")
	Input.action_press(&"start")
	await tree.process_frame
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.TITLE, "Esc / Start goes back to the title")
	assert_null(_room(main))


func test_the_press_that_started_the_demo_does_not_bounce_back() -> void:
	var main: Main = _make_main(TITLE_STUB)
	Input.action_press(&"start")
	main.get_title().emit_signal("start_demo_requested")
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.ROOM, "same-frame press ignored")


func test_debug_overlay_is_on_the_ui_layer() -> void:
	var main: Main = _make_main(TITLE_STUB)
	assert_not_null(main.overlay)
	assert_eq(main.overlay.get_parent(), main.screen.get_ui_layer())


func test_real_title_screen_hooks_up_when_it_exists() -> void:
	if not ResourceLoader.exists(Main.TITLE_SCENE_PATH):
		assert_true(true, "title screen not built yet; the hookup is covered by the stand-in tests")
		return
	var main: Main = _make_main(Main.TITLE_SCENE_PATH)
	assert_eq(main.get_state(), Main.State.TITLE)
	assert_true(main.get_title().has_signal(Main.START_SIGNAL))
	main.get_title().emit_signal(Main.START_SIGNAL)
	assert_eq(main.get_state(), Main.State.ROOM)
	assert_not_null(_room(main))
