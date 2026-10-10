extends TestCase
## The Continue screen (VS-11): it opens when the room says Red was knocked out, waits a beat before it takes a press,
## offers Continue and Quit to title, says where Continue goes, and tells the room to restart. Through the real HUD.

const HUD_SCENE: String = "res://scenes/ui/slice/action_hud.tscn"

var _host: FakeSliceHost = null
var _hud: ActionHud = null
var _screen: ContinueScreen = null
var _quits: int = 0
var _continues: int = 0


func _setup() -> void:
	_quits = 0
	_continues = 0
	_host = FakeSliceHost.new()
	_hud = (load(HUD_SCENE) as PackedScene).instantiate() as ActionHud
	_hud.manual_ticks = true
	_hud.animations_enabled = false
	_hud.listen_input = false
	_hud.relocate_to_window = false
	_hud.auto_router = false
	_hud.audio.target = FakeAudio.new()
	add_to_root(_hud)
	_hud.get_continue_screen().pause_game = false
	_hud.get_slice_pause().pause_game = false
	_hud.bind(_host)
	_hud.quit_requested.connect(func() -> void: _quits += 1)
	_hud.continue_requested.connect(func() -> void: _continues += 1)
	_screen = _hud.get_continue_screen()


func after_each() -> void:
	SandboxPauseGate.clear(tree)
	if _host != null:
		if is_instance_valid(_hud) and _hud.is_inside_tree():
			_hud.unbind()
		_host.free_nodes()


func test_a_knock_out_opens_the_screen() -> void:
	_setup()
	assert_false(_screen.is_open())
	_host.knocked_out_rule.emit("room_entrance")
	assert_true(_screen.is_open())
	assert_true(_hud.is_menu_open())
	assert_eq(_screen.get_item_id(0), "continue")
	assert_eq(_screen.get_item_id(1), "quit")


func test_the_sandbox_rule_none_shows_no_screen() -> void:
	_setup()
	_host.knocked_out_rule.emit("none")
	assert_false(_screen.is_open(), "she just gets up")


func test_a_mashed_button_does_nothing_in_the_first_beat() -> void:
	_setup()
	_host.knocked_out_rule.emit("room_entrance")
	assert_false(_screen.accepts_input())
	_screen.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_host.continue_calls, 0)
	_screen.tick(1.0)
	assert_true(_screen.accepts_input())


func test_continue_asks_the_room_to_restart_and_closes() -> void:
	_setup()
	_host.knocked_out_rule.emit("room_entrance")
	_screen.tick(1.0)
	_screen.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_host.continue_calls, 1)
	assert_eq(_continues, 1)
	assert_false(_screen.is_open())


func test_quit_says_so_and_does_not_restart() -> void:
	_setup()
	_host.knocked_out_rule.emit("room_entrance")
	_screen.tick(1.0)
	_screen.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(_screen.get_cursor_index(), 1)
	_screen.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_quits, 1)
	assert_eq(_host.continue_calls, 0)
	assert_false(_screen.is_open())


func test_the_cursor_wraps_and_cancel_goes_back_to_continue() -> void:
	_setup()
	_host.knocked_out_rule.emit("room_entrance")
	_screen.handle_command(MenuInput.Cmd.UP)
	assert_eq(_screen.get_cursor_index(), 1)
	_screen.handle_command(MenuInput.Cmd.CANCEL)
	assert_eq(_screen.get_cursor_index(), 0)
	assert_true(_screen.is_open(), "there is no backing out of a knock-out")


func test_the_info_bar_says_where_continue_goes() -> void:
	_setup()
	_host.knocked_out_rule.emit("room_entrance")
	assert_eq(_screen.info_text(), SliceUiData.text("continue.hint_room"))
	_screen.close_screen()
	_host.knocked_out_rule.emit("last_save")
	assert_eq(_screen.info_text(), SliceUiData.text("continue.hint_save"))
	_screen.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(_screen.info_text(), SliceUiData.text("continue.hint_quit"))


func test_a_fight_in_progress_says_it_restarts_the_fight() -> void:
	_setup()
	_hud.show_boss_bar({"name": "Kasp", "hp": 10, "hp_max": 10, "phases": []})
	_hud.tick(1.0)
	_host.knocked_out_rule.emit("room_entrance")
	assert_eq(_screen.info_text(), SliceUiData.text("continue.hint_boss"))


func test_the_room_restarting_closes_the_screen() -> void:
	_setup()
	_host.knocked_out_rule.emit("room_entrance")
	_host.continue_started.emit("market_hideout", "from_market")
	assert_false(_screen.is_open())


func test_the_mouse_can_pick_a_row() -> void:
	_setup()
	_host.knocked_out_rule.emit("room_entrance")
	_screen.tick(1.0)
	var rect: Rect2 = _screen._row_rect(1)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = _screen._overlay.get_global_transform_with_canvas() * rect.get_center()
	_screen.handle_event(motion)
	assert_eq(_screen.get_cursor_index(), 1)


func test_rebinding_closes_a_stale_screen() -> void:
	_setup()
	_host.knocked_out_rule.emit("room_entrance")
	var other: FakeSliceHost = FakeSliceHost.new()
	_hud.bind(other)
	assert_false(_screen.is_open())
	_hud.unbind()
	other.free_nodes()


func test_the_screen_draws_without_errors() -> void:
	_setup()
	_host.knocked_out_rule.emit("room_entrance")
	_screen.tick(1.0)
	_screen._overlay.queue_redraw()
	await tree.process_frame
	assert_true(_screen.visible)
