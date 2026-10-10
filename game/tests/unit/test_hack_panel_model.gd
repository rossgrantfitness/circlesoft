extends TestCase
## HackPanelModel: what the hack panel shows, from data/combat/hacks.json and the director's signals. Pure.


func _model() -> HackPanelModel:
	return HackPanelModel.load_default()


func test_the_list_follows_the_data_order_and_names() -> void:
	var model: HackPanelModel = _model()
	assert_eq(model.order, ["zap_drone", "emp", "overclock", "reboot"] as Array[String])
	assert_eq(model.display_name("emp"), "EMP")
	assert_eq(model.selected, "zap_drone")
	assert_false(model.is_auto())
	for id: String in model.order:
		assert_true(HackIcons.has_icon(model.icon_of(id)), "%s has an icon (placeholder or final)" % id)


func test_a_hack_is_greyed_until_the_battery_can_pay() -> void:
	var model: HackPanelModel = _model()
	var zap_cost: int = model.cost_of("zap_drone")
	model.set_battery(float(zap_cost) - 1.0, 100.0)
	assert_false(model.can_afford("zap_drone"))
	model.set_battery(float(zap_cost), 100.0)
	assert_true(model.can_afford("zap_drone"))
	assert_true(model.is_ready("zap_drone"))


func test_reboot_takes_the_whole_bar_and_wants_it_full() -> void:
	var model: HackPanelModel = _model()
	assert_true(model.takes_all("reboot"))
	assert_eq(model.cost_of("reboot"), 100)
	model.set_battery(99.0, 100.0)
	assert_false(model.can_afford("reboot"))
	model.set_battery(100.0, 100.0)
	assert_true(model.can_afford("reboot"))


func test_cost_scale_and_free_casting_change_what_the_panel_shows() -> void:
	var model: HackPanelModel = _model()
	var base: int = model.cost_of("emp")
	model.cost_scale = 0.5
	assert_eq(model.cost_of("emp"), roundi(float(base) * 0.5))
	assert_eq(model.cost_of("reboot"), 100, "Reboot always takes the whole bar")
	model.free_cast = true
	model.set_battery(0.0, 100.0)
	assert_eq(model.cost_of("emp"), 0)
	assert_true(model.can_afford("emp"))


func test_the_bar_has_a_tick_at_each_cost_but_the_all_in_one() -> void:
	var model: HackPanelModel = _model()
	var ticks: Array[Dictionary] = model.cost_ticks()
	assert_eq(ticks.size(), 4)
	var fixed: int = 0
	for entry: Dictionary in ticks:
		if not bool(entry["all"]):
			fixed += 1
			assert_almost_eq(float(entry["frac"]), float(model.cost_of(str(entry["id"]))) / model.capacity, 0.0001)
	assert_eq(fixed, 3)


func test_picking_wraps_both_ways() -> void:
	var model: HackPanelModel = _model()
	model.step(-1)
	assert_eq(model.selected, "reboot")
	model.step(1)
	assert_eq(model.selected, "zap_drone")
	model.select("overclock")
	assert_eq(model.highlight_id(), "overclock")
	model.select("nope")
	assert_eq(model.selected, "overclock", "an unknown id changes nothing")


func test_automatic_mode_lights_the_last_hack_used() -> void:
	var model: HackPanelModel = _model()
	model.set_mode_from_data("automatic")
	assert_true(model.is_auto())
	model.note_cast("emp", 1000.0)
	assert_eq(model.highlight_id(), "emp")
	model.set_mode_from_data("pick_then_fire")
	assert_eq(model.highlight_id(), model.selected)


func test_a_cooldown_sweeps_down_to_ready() -> void:
	var model: HackPanelModel = _model()
	model.set_battery(100.0, 100.0)
	model.note_cast("zap_drone", 600.0)
	assert_false(model.is_ready("zap_drone"))
	assert_almost_eq(model.cooldown_frac("zap_drone"), 1.0, 0.0001)
	model.tick(0.3)
	assert_almost_eq(model.cooldown_frac("zap_drone"), 0.5, 0.01)
	model.tick(0.4)
	assert_true(model.is_ready("zap_drone"))
	assert_eq(model.cooldown_ms_of("zap_drone"), float(CombatData.hacks()["hacks"]["zap_drone"]["cooldown_ms"]), "the cooldown comes from hacks.json")
	model.cooldown_scale = 0.0
	assert_eq(model.cooldown_ms_of("zap_drone"), 0.0, "the knob can turn cooldowns off")


func test_quiet_hours_blocks_every_hack_and_counts_down() -> void:
	var model: HackPanelModel = _model()
	model.set_battery(100.0, 100.0)
	model.set_lock(true, 5000.0)
	assert_true(model.is_locked())
	assert_false(model.is_ready("emp"))
	assert_true(model.can_afford("emp"), "the charge is kept; only the jam stops the cast")
	assert_almost_eq(model.lock_left_s(), 5.0, 0.001)
	model.tick(2.0)
	assert_almost_eq(model.lock_left_s(), 3.0, 0.001)
	model.set_lock(false, 0.0)
	assert_false(model.is_locked())
	model.set_lock(true, 100.0)
	model.tick(1.0)
	assert_false(model.is_locked(), "it frees itself when the time runs out")


func test_a_refused_cast_shakes_for_a_moment() -> void:
	var model: HackPanelModel = _model()
	assert_eq(model.denied_id(), "")
	model.note_denied("emp")
	assert_eq(model.denied_id(), "emp")
	model.tick(1.0)
	assert_eq(model.denied_id(), "")


func test_hijack_timers_drain_and_the_longest_one_is_shown() -> void:
	var model: HackPanelModel = _model()
	model.set_hijack("turret_1", 10.0, 10.0)
	model.set_hijack("drone_2", 4.0, 10.0)
	assert_eq(model.longest_hijack(), "turret_1")
	model.tick(5.0)
	assert_eq(model.hijack_ids().size(), 1, "the 4 s link ran out")
	assert_almost_eq(model.hijack_frac("turret_1"), 0.5, 0.001)
	model.clear_hijack("turret_1")
	assert_eq(model.longest_hijack(), "")


func test_the_battery_clamps() -> void:
	var model: HackPanelModel = _model()
	model.set_battery(250.0, 100.0)
	assert_eq(model.charge, 100.0)
	model.set_battery(-3.0, 100.0)
	assert_eq(model.charge, 0.0)
	assert_almost_eq(model.fill(), 0.0, 0.0001)
