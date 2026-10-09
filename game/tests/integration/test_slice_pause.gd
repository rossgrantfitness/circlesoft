extends TestCase
## The slice pause menu (VS-11): Resume, Menu (when the town systems listen), Controls, Tuning and Quit to title, in the
## sandbox pause menu's look. It says what was picked and the HUD acts.

const HUD_SCENE: String = "res://scenes/ui/slice/action_hud.tscn"

var _host: FakeSliceHost = null
var _hud: ActionHud = null
var _pause: SlicePause = null
var _menu_calls: int = 0
var _quits: int = 0


func _setup(listen_for_menu: bool = true) -> void:
	_menu_calls = 0
	_quits = 0
	_host = FakeSliceHost.new()
	_hud = (load(HUD_SCENE) as PackedScene).instantiate() as ActionHud
	_hud.manual_ticks = true
	_hud.animations_enabled = false
	_hud.listen_input = false
	_hud.relocate_to_window = false
	_hud.auto_router = false
	_hud.audio.target = FakeAudio.new()
	add_to_root(_hud)
	_pause = _hud.get_slice_pause()
	_pause.pause_game = false
	_hud.get_feel_panel().pause_game = false
	_hud.get_continue_screen().pause_game = false
	_hud.bind(_host)
	if listen_for_menu:
		_hud.field_menu_requested.connect(func() -> void: _menu_calls += 1)
	_hud.quit_requested.connect(func() -> void: _quits += 1)


func after_each() -> void:
	SandboxPauseGate.clear(tree)
	if _host != null:
		if is_instance_valid(_hud) and _hud.is_inside_tree():
			_hud.unbind()
		_host.free_nodes()


func _rows() -> Array[String]:
	return _pause.item_ids()


func test_the_slice_uses_its_own_pause_menu() -> void:
	_setup()
	assert_true(_hud.get_pause_menu() is SlicePause)
	_hud.open_pause()
	assert_true(_pause.is_open())
	assert_true(_hud.is_menu_open())
	assert_eq(_rows(), ["resume", "menu", "controls", "feel", "quit"] as Array[String])
	assert_false(_rows().has("reset"), "a slice room has no arena reset")


func test_the_menu_row_only_shows_when_something_listens() -> void:
	_setup(false)
	_hud.open_pause()
	assert_false(_rows().has("menu"))
	assert_eq(_rows(), ["resume", "controls", "feel", "quit"] as Array[String])


func test_resume_closes_it() -> void:
	_setup()
	_hud.open_pause()
	_pause.activate()
	assert_false(_pause.is_open())


func test_menu_closes_the_pause_and_asks_for_the_field_menu() -> void:
	_setup()
	_hud.open_pause()
	_pause.move(1)
	assert_eq(_pause.get_item_id(_pause.get_cursor_index()), "menu")
	_pause.activate()
	assert_false(_pause.is_open())
	assert_eq(_menu_calls, 1)


func test_tuning_opens_the_feel_panel() -> void:
	_setup()
	_hud.open_pause()
	for i: int in 3:
		_pause.move(1)
	assert_eq(_pause.get_item_id(_pause.get_cursor_index()), "feel")
	_pause.activate()
	assert_false(_pause.is_open())
	assert_true(_hud.get_feel_panel().is_open())
	_hud.get_feel_panel().close_panel()


func test_controls_opens_the_card() -> void:
	_setup()
	_hud.open_pause()
	_pause.move(2)
	_pause.activate()
	assert_true(_pause.get_card().is_open())
	assert_true(_pause.is_sub_page_open())


func test_quit_says_so_without_quitting_the_game() -> void:
	_setup()
	_hud.open_pause()
	_pause.move(-1)
	assert_eq(_pause.get_item_id(_pause.get_cursor_index()), "quit")
	_pause.activate()
	assert_eq(_quits, 1, "Main takes it to the title; the HUD never quits the process in the slice")


func test_cancel_and_the_cursor_wrap() -> void:
	_setup()
	_hud.open_pause()
	_pause.handle_command(MenuInput.Cmd.UP)
	assert_eq(_pause.get_cursor_index(), _rows().size() - 1)
	_pause.handle_command(MenuInput.Cmd.CANCEL)
	assert_false(_pause.is_open())


func test_the_words_are_the_slices_own() -> void:
	_setup()
	for id: String in ["resume", "menu", "controls", "feel", "quit"]:
		assert_ne(SliceUiData.text("pause.%s" % id), "", "pause.%s has text" % id)
		assert_ne(SliceUiData.text("pause.hints.%s" % id), "", "pause.hints.%s has text" % id)


func test_the_rows_fit_above_the_information_bar() -> void:
	_setup()
	var layout: Dictionary = SliceUiData.ui("pause", {})
	var last_bottom: float = float(layout["row_y"]) + float(_rows().size() - 1) * float(layout["row_step"]) + float(layout["row_h"])
	assert_lt(last_bottom, float(layout["info_y"]) - 4.0)
	_hud.open_pause()
	_pause._overlay.queue_redraw()
	await tree.process_frame
	assert_true(_pause.is_open())


func test_the_sandbox_pause_menu_is_unchanged() -> void:
	var sandbox_pause: SandboxPause = (load("res://scenes/ui/sandbox/sandbox_pause.tscn") as PackedScene).instantiate() as SandboxPause
	add_to_root(sandbox_pause)
	sandbox_pause.pause_game = false
	assert_eq(sandbox_pause.item_ids(), ["resume", "reset", "controls", "quit"] as Array[String])
