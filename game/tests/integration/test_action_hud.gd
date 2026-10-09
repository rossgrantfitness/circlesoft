extends TestCase
## The action HUD (VS-11): it binds to a combat host (here a stand-in for an ActionRoom with the real CombatDirector) and
## reacts to the hack signals (battery, lock, pick, cast, refusal, hijack), runs the boss bar, the radio box and the location
## card, follows the feature switches, and keeps everything it inherits from the sandbox HUD.

const HUD_SCENE: String = "res://scenes/ui/slice/action_hud.tscn"

var _audio: FakeAudio = null
var _host: FakeSliceHost = null
var _hud: ActionHud = null


func _setup(listen_menu: bool = false) -> void:
	Features.clear_overrides()
	_audio = FakeAudio.new()
	_host = FakeSliceHost.new()
	_host.add_enemy(&"grunt_1", Vector2(320, 180))
	_hud = (load(HUD_SCENE) as PackedScene).instantiate() as ActionHud
	_hud.manual_ticks = true
	_hud.animations_enabled = false
	_hud.listen_input = false
	_hud.relocate_to_window = false
	_hud.auto_router = false
	_hud.audio.target = _audio
	add_to_root(_hud)
	_hud.get_slice_pause().pause_game = false
	_hud.get_continue_screen().pause_game = false
	_hud.get_feel_panel().pause_game = false
	_hud.bind(_host)
	if listen_menu:
		_hud.field_menu_requested.connect(func() -> void: pass)


func after_each() -> void:
	SandboxPauseGate.clear(tree)
	Features.clear_overrides()
	if _host != null:
		if is_instance_valid(_hud) and _hud.is_inside_tree():
			_hud.unbind()
		_host.free_nodes()


func _model() -> HackPanelModel:
	return _hud.get_hack_panel().model


# ---- it is still the sandbox HUD underneath ----

func test_it_keeps_the_sandbox_hud_parts() -> void:
	_setup()
	assert_eq(_hud.get_hp(), 120)
	_host.director.hp_changed.emit(&"red", 80, 120)
	assert_eq(_hud.get_hp(), 80)
	_host.director.hit_landed.emit({"attacker": &"red", "target": &"grunt_1", "outcome": "hit", "damage": 9})
	assert_eq(_hud.get_floaters().size(), 1, "damage numbers still float")


func test_the_old_coming_later_call_out_stays_quiet_in_the_slice() -> void:
	_setup()
	_host.player.hack_pressed.emit({"text": "Hack: coming later"})
	assert_eq(_hud.get_callouts().size(), 0)


func test_it_can_bind_to_another_host_and_back() -> void:
	_setup()
	var other: FakeSliceHost = FakeSliceHost.new()
	_hud.bind(other)
	other.director.battery_changed.emit(40.0, 100.0)
	assert_eq(_model().charge, 40.0)
	_host.director.battery_changed.emit(90.0, 100.0)
	assert_eq(_model().charge, 40.0, "the old host no longer feeds it")
	_hud.unbind()
	other.free_nodes()


# ---- the hack panel ----

func test_the_battery_follows_the_directors_signal() -> void:
	_setup()
	_host.director.battery_changed.emit(63.0, 100.0)
	assert_eq(_model().charge, 63.0)
	assert_almost_eq(_model().fill(), 0.63, 0.0001)
	_host.director.battery_changed.emit(10.0, 120.0)
	assert_eq(_model().capacity, 120.0)


func test_the_battery_starts_from_the_directors_own() -> void:
	_setup()
	_host.director.battery.reset_full()
	_hud.bind(_host)
	assert_eq(_model().charge, _host.director.battery.charge())


func test_quiet_hours_jams_the_panel_and_frees_it() -> void:
	_setup()
	_host.director.hack_locked.emit(true, 5000.0)
	assert_true(_model().is_locked())
	_hud.tick(1.0)
	assert_almost_eq(_model().lock_left_s(), 4.0, 0.01)
	_host.director.hack_locked.emit(false, 0.0)
	assert_false(_model().is_locked())


func test_picking_a_hack_moves_the_highlight_and_ticks() -> void:
	_setup()
	_host.director.hack_selected.emit(&"overclock")
	assert_eq(_model().selected, "overclock")


func test_in_automatic_mode_the_panel_shows_the_last_hack_used() -> void:
	_setup()
	_host.director.feel.set_value("hack_pick_mode", "automatic")
	assert_true(_model().is_auto(), "the feel knob flips the panel live")
	_host.director.hack_selected.emit(&"emp")
	assert_eq(_model().highlight_id(), "emp")
	_host.director.feel.set_value("hack_pick_mode", "pick_then_fire")
	assert_false(_model().is_auto())


func test_a_cast_starts_the_cooldown_sweep() -> void:
	_setup()
	_host.director.battery_changed.emit(100.0, 100.0)
	_host.director.hack_cast.emit({"hack": "zap_drone", "name": "Zap Drone", "cost": 25})
	assert_gt(_model().cooldown_frac("zap_drone"), 0.9)
	assert_false(_model().is_ready("zap_drone"))
	_hud.tick(1.0)
	assert_true(_model().is_ready("zap_drone"))


func test_a_refused_cast_shakes_the_bar_and_some_say_why() -> void:
	_setup()
	_host.director.hack_refused.emit({"hack": "emp", "reason": "battery"})
	assert_eq(_model().denied_id(), "emp")
	assert_eq(_hud.get_callouts().size(), 0, "a plain 'not enough battery' needs no words")
	_host.director.hack_refused.emit({"hack": "overclock", "reason": "no_signal"})
	assert_eq(_hud.get_callouts(), ["No signal"] as Array[String])
	_host.director.hack_refused.emit({"hack": "reboot", "reason": "not_full"})
	assert_has(_hud.get_callouts(), "Needs a full battery")


func test_a_hijack_shows_its_timer_and_clears() -> void:
	_setup()
	_host.director.hijack_changed.emit({"target": &"grunt_1", "active": true, "duration_s": 10.0})
	assert_eq(_model().longest_hijack(), "grunt_1")
	_hud.tick(2.5)
	assert_almost_eq(_model().hijack_left_s("grunt_1"), 7.5, 0.01)
	_host.director.hijack_changed.emit({"target": &"grunt_1", "active": false, "duration_s": 10.0})
	assert_eq(_model().longest_hijack(), "")


func test_the_hack_knobs_reach_the_panel() -> void:
	_setup()
	var base: int = _model().cost_of("emp")
	_host.director.feel.set_value("hack_cost_scale", 0.5)
	assert_lt(float(_model().cost_of("emp")), float(base))
	_host.director.feel.set_value("hack_free_cast", true)
	assert_eq(_model().cost_of("emp"), 0)
	_host.director.feel.set_value("hack_cooldown_scale", 0.0)
	assert_eq(_model().cooldown_ms_of("emp"), 0.0)


func test_the_panel_draws_every_state_without_errors() -> void:
	_setup()
	_hud.size = Vector2(SandboxStyle.REFERENCE_SIZE)
	var panel: HackPanel = _hud.get_hack_panel()
	panel.size = _hud.size
	_hud.tick(0.1)
	_host.director.hack_locked.emit(true, 3000.0)
	_hud.tick(0.1)
	_host.director.hack_locked.emit(false, 0.0)
	_host.director.hack_refused.emit({"hack": "emp", "reason": "battery"})
	_host.director.hijack_changed.emit({"target": &"grunt_1", "active": true, "duration_s": 6.0})
	_host.director.feel.set_value("hack_pick_mode", "automatic")
	_hud.tick(0.1)
	panel.queue_redraw()
	await tree.process_frame
	assert_true(panel.is_inside_tree())
	assert_eq(panel.row_rects().size(), 4)


func test_the_panel_hides_while_a_menu_is_open() -> void:
	_setup()
	_hud.tick(0.1)
	assert_true(_hud.get_hack_panel().visible)
	_hud.open_pause()
	_hud.tick(0.1)
	assert_false(_hud.get_hack_panel().visible)


func test_the_stack_stays_inside_the_ui() -> void:
	_setup()
	var rects: Dictionary = _hud.get_hack_panel().row_rects()
	for id: String in rects:
		var rect: Rect2 = rects[id]
		assert_ge(rect.position.x, 0.0)
		assert_le(rect.end.x + 8.0, float(SandboxStyle.REFERENCE_SIZE.x) / 2.0, "the list stays in its corner")
		assert_le(rect.end.y, float(SandboxStyle.REFERENCE_SIZE.y) * 0.6)


# ---- the boss bar ----

func test_the_host_can_run_the_boss_bar() -> void:
	_setup()
	var info: Dictionary = {"name": "The Hushmaster", "hp": 300, "hp_max": 300, "phases": [{"id": "rig", "name": "The rig"}, {"id": "mech", "name": "The junk mech"}]}
	_host.boss.boss_bar_shown.emit(info)
	_hud.tick(1.0)
	var model: BossBarModel = _hud.get_boss_bar().model
	assert_true(model.is_visible())
	assert_eq(model.boss_name, "The Hushmaster")
	_host.boss.boss_hp_changed.emit(120.0, 300.0)
	assert_almost_eq(model.fill(), 0.4, 0.0001)
	_host.boss.boss_phase_changed.emit(1, "The junk mech")
	assert_eq(model.phase_index, 1)
	_host.boss.boss_bar_hidden.emit()
	_hud.tick(2.0)
	assert_false(model.is_visible())


func test_the_boss_bar_api_works_without_signals() -> void:
	_setup()
	_hud.show_boss_bar({"name": "Kasp", "hp": 10, "hp_max": 10, "phases": []})
	_hud.tick(1.0)
	assert_true(_hud.get_boss_bar().model.is_visible())
	assert_eq(_hud.get_boss_bar().model.phase_count(), 0)
	_hud.hide_boss_bar()


func test_the_boss_bar_draws_inside_the_ui_at_any_window_size() -> void:
	_setup()
	for ui_size: Vector2 in [Vector2(384, 216), Vector2(480, 270), Vector2(640, 270)]:
		var rect: Rect2 = _hud.get_boss_bar().bar_rect(ui_size)
		assert_ge(rect.position.x, 0.0)
		assert_le(rect.end.x, ui_size.x)
		assert_le(rect.end.y, ui_size.y)
		assert_almost_eq(rect.get_center().x, ui_size.x / 2.0, 1.0, "centered")
		assert_ge(rect.position.x, 124.0, "clear of Red's health")
		assert_le(rect.end.x, ui_size.x - 124.0, "clear of the Noise meter")


# ---- the radio ----

func test_a_bark_shows_in_the_radio_box() -> void:
	_setup()
	assert_true(_hud.radio_say("vela", "Turret on the left, Red."))
	var radio: RadioBark = _hud.get_radio()
	_hud.tick(2.0)
	var line: Dictionary = radio.current_line()
	assert_eq(line["name"], "Vela")
	assert_eq(line["shown"], "Turret on the left, Red.")


func test_the_box_stays_in_the_bottom_left_whatever_the_window() -> void:
	_setup()
	for ui_size: Vector2 in [Vector2(384, 216), Vector2(640, 360)]:
		var rect: Rect2 = _hud.get_radio().box_rect(ui_size)
		assert_ge(rect.position.x, 0.0)
		assert_le(rect.end.y, ui_size.y)
		assert_lt(rect.end.x, ui_size.x / 2.0 + 120.0)


# ---- the location card ----

func test_entering_an_area_shows_its_card_once() -> void:
	_setup()
	var card: LocationCard = _hud.get_location_card()
	assert_true(_hud.show_location({"name": "Scrap Canyon", "kind": "dungeon"}))
	assert_eq(card.get_title(), "Scrap Canyon")
	assert_eq(card.get_subtitle(), "Dungeon")
	assert_false(_hud.show_location({"name": "Scrap Canyon", "kind": "dungeon"}), "same area: no second card")
	assert_true(_hud.show_location({"name": "Gate Road", "area": "Scrap Canyon", "kind": "dungeon"}) == false, "a room of the same area stays quiet")
	assert_true(_hud.show_location({"name": "The Market", "kind": "town"}))
	assert_eq(card.get_subtitle(), "Town")


func test_a_room_can_opt_out_of_the_card() -> void:
	_setup()
	assert_false(_hud.show_location({"name": "Closet", "card": false}))
	assert_false(_hud.show_location({}))
	assert_false(_hud.get_location_card().is_showing())


func test_the_card_slides_holds_and_goes() -> void:
	_setup()
	var card: LocationCard = _hud.get_location_card()
	card.show_card("Junkyard", "Dungeon")
	assert_true(card.is_showing())
	_hud.tick(1.0)
	assert_true(card.is_showing())
	_hud.tick(5.0)
	assert_false(card.is_showing())


func test_the_router_drives_the_card() -> void:
	_setup()
	var router: FakeRouter = FakeRouter.new()
	_hud.attach_router(router)
	router.room_entered.emit("market_a")
	assert_eq(_hud.get_location_card().get_title(), "Night Market")
	_hud.attach_router(null)
	router.free()


class FakeRouter extends Node:
	signal room_entered(room_id: String)

	func get_room_entry(room_id: String) -> Dictionary:
		return {"name": "Night Market", "kind": "town"} if room_id == "market_a" else {}


# ---- the Lights On element follows its switch ----

func test_the_lights_on_bulb_and_noise_meter_follow_the_switches() -> void:
	_setup()
	assert_true(_hud.is_lights_on_shown())
	assert_true(_hud.is_noise_shown())
	_host.director.lights_on_changed.emit(true, 8.0)
	assert_true(_hud.is_lights_on())
	Features.set_on(Features.LIGHTS_ON, false)
	_hud.tick(0.01)
	assert_false(_hud.is_lights_on_shown(), "the bulb is hidden")
	assert_false(_hud.is_lights_on(), "and what was running is dropped")
	assert_true(_hud.is_noise_shown())
	Features.set_on(Features.NOISE_METER, false)
	_hud.tick(0.01)
	assert_false(_hud.is_noise_shown())
	Features.set_on(Features.LIGHTS_ON, true)
	Features.set_on(Features.NOISE_METER, true)
	_hud.tick(0.01)
	assert_true(_hud.is_lights_on_shown() and _hud.is_noise_shown(), "flip them back and they return")


func test_the_directors_feature_signal_rebuilds_the_feel_panel_list() -> void:
	_setup()
	var panel: FeelPanel = _hud.get_feel_panel()
	var with_knob: int = panel.get_knob_list().size()
	Features.set_on(Features.LIGHTS_ON, false)
	_host.director.feature_changed.emit(Features.LIGHTS_ON, false)
	assert_lt(float(panel.get_knob_list().size()), float(with_knob), "the Lights On knob leaves the list")
	Features.set_on(Features.LIGHTS_ON, true)
	_host.director.feature_changed.emit(Features.LIGHTS_ON, true)
	assert_eq(panel.get_knob_list().size(), with_knob)


func test_the_hud_draws_with_every_feature_off() -> void:
	_setup()
	for id: StringName in Features.IDS:
		Features.set_on(id, false)
	_hud.tick(0.1)
	await tree.process_frame
	assert_false(_hud.is_lights_on_shown() or _hud.is_noise_shown())
