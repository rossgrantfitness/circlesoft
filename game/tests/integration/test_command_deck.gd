extends TestCase
## The command deck in the action HUD (Ross's pick for Decision 1): Attack / Hack / Item rows, the hack list with battery
## costs, the pick following the host's selection, the deck's own buttons, the Item stub, and the slow-time switch.

const HUD_SCENE: String = "res://scenes/ui/slice/action_hud.tscn"

var _host: FakeSliceHost = null
var _hud: ActionHud = null


func _setup() -> void:
	Features.clear_overrides()
	_host = FakeSliceHost.new()
	_hud = (load(HUD_SCENE) as PackedScene).instantiate() as ActionHud
	_hud.manual_ticks = true
	_hud.animations_enabled = false
	_hud.listen_input = false
	_hud.relocate_to_window = false
	_hud.auto_router = false
	_hud.audio.target = FakeAudio.new()
	add_to_root(_hud)
	_hud.get_slice_pause().pause_game = false
	_hud.get_continue_screen().pause_game = false
	_hud.bind(_host)


func after_each() -> void:
	Engine.time_scale = 1.0
	SandboxPauseGate.clear(tree)
	Features.clear_overrides()
	if _host != null:
		if is_instance_valid(_hud) and _hud.is_inside_tree():
			_hud.unbind()
		_host.free_nodes()


func _key(action: StringName) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_the_deck_has_three_rows_and_starts_on_hack() -> void:
	_setup()
	var deck: CommandDeck = _hud.get_deck()
	assert_eq(deck.row_rects().size(), 3)
	assert_eq(deck.model.row_id(), "hack")
	assert_false(deck.model.submenu_open)
	assert_eq(deck.submenu_rects().size(), 0, "no list until it is chosen")


func test_choosing_hack_opens_a_list_of_the_four_with_costs() -> void:
	_setup()
	assert_eq(_hud.deck_choose(), "opened")
	var deck: CommandDeck = _hud.get_deck()
	assert_eq(deck.submenu_rects().size(), 4)
	var model: HackPanelModel = _hud.get_hack_panel().model
	assert_eq(model.cost_of("zap_drone"), int(CombatData.hacks()["hacks"]["zap_drone"]["cost"]))
	assert_eq(_hud.deck_choose(), "closed")


func test_moving_the_pick_changes_the_current_hack_shown_on_the_deck() -> void:
	_setup()
	_hud.deck_choose()
	_host.director.hack_selected.emit(&"overclock")
	var model: HackPanelModel = _hud.get_hack_panel().model
	assert_eq(model.highlight_id(), "overclock")
	assert_eq(_hud.get_deck().hacks.highlight_id(), "overclock", "the deck reads the same model")


func test_the_list_closes_when_a_hack_is_cast() -> void:
	_setup()
	_hud.deck_choose()
	_host.director.hack_cast.emit({"hack": "emp"})
	assert_false(_hud.get_deck().model.submenu_open)


func test_the_deck_buttons_work_through_input_events() -> void:
	_setup()
	assert_true(InputMap.has_action(ActionHud.ACTION_DECK_OPEN))
	assert_true(_hud.handle_deck_event(_key(ActionHud.ACTION_DECK_OPEN)))
	assert_true(_hud.get_deck().model.submenu_open)
	assert_true(_hud.handle_deck_event(_key(ActionHud.ACTION_DECK_SCROLL)))
	assert_eq(_hud.get_deck().model.row_id(), "item")
	assert_false(_hud.get_deck().model.submenu_open)
	_hud.handle_deck_event(_key(ActionHud.ACTION_DECK_OPEN))
	assert_eq(_hud.get_deck().model.note(), "Items: coming later")


func test_the_deck_ignores_its_buttons_while_a_menu_is_open() -> void:
	_setup()
	_hud.open_pause()
	assert_false(_hud.handle_deck_event(_key(ActionHud.ACTION_DECK_OPEN)))


func test_automatic_mode_shows_auto_and_has_no_list() -> void:
	_setup()
	_host.director.feel.set_value("hack_pick_mode", "automatic")
	assert_true(_hud.get_hack_panel().model.is_auto())
	assert_eq(_hud.deck_choose(), "note")
	assert_eq(_hud.get_deck().submenu_rects().size(), 0)


func test_the_game_keeps_running_while_the_list_is_open_by_default() -> void:
	_setup()
	_hud.deck_choose()
	_hud.tick(0.1)
	assert_false(_hud.is_slowmo_active())
	assert_eq(Engine.time_scale, 1.0)
	assert_false(_host.director.feel.get_b("deck_slowmo"), "off by default")


func test_the_slow_time_switch_slows_the_game_only_while_the_list_is_open() -> void:
	_setup()
	_host.director.feel.set_value("deck_slowmo", true)
	_host.director.feel.set_value("deck_slowmo_scale", 0.4)
	_hud.tick(0.1)
	assert_eq(Engine.time_scale, 1.0, "closed list: normal speed")
	_hud.deck_choose()
	_hud.tick(0.1)
	assert_true(_hud.is_slowmo_active())
	assert_almost_eq(Engine.time_scale, 0.4, 0.001)
	_hud.deck_choose()
	_hud.tick(0.1)
	assert_eq(Engine.time_scale, 1.0)
	_hud.deck_choose()
	_hud.tick(0.1)
	_hud.unbind()
	assert_eq(Engine.time_scale, 1.0, "unbinding never leaves the game slowed")


func test_opening_the_pause_menu_gives_the_speed_back() -> void:
	_setup()
	_host.director.feel.set_value("deck_slowmo", true)
	_hud.deck_choose()
	_hud.tick(0.1)
	assert_true(_hud.is_slowmo_active())
	_hud.open_pause()
	_hud.tick(0.1)
	assert_eq(Engine.time_scale, 1.0)


func test_the_deck_draws_every_state_without_errors() -> void:
	_setup()
	var deck: CommandDeck = _hud.get_deck()
	deck.size = Vector2(640, 360)
	_hud.deck_choose()
	_host.director.hack_locked.emit(true, 3000.0)
	_host.director.hack_cast.emit({"hack": "zap_drone"})
	_hud.deck_choose()
	_hud.tick(0.1)
	_hud.deck_scroll(1)
	_hud.deck_choose()
	_hud.tick(0.1)
	_host.director.feel.set_value("hack_pick_mode", "automatic")
	_hud.tick(0.1)
	await tree.process_frame
	assert_true(deck.is_inside_tree())


func test_a_click_pick_goes_to_the_players_caster_when_it_can_take_it() -> void:
	_setup()
	_hud.pick_hack("emp")
	assert_eq(_hud.get_hack_panel().model.selected, "emp")
