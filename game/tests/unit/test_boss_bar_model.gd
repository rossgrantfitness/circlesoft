extends TestCase
## BossBarModel: the boss bar's numbers, phases and slide. Pure.

const INFO: Dictionary = {"name": "The Hushmaster", "hp": 300, "hp_max": 300, "phases": [{"id": "rig", "name": "The rig"}, {"id": "mech", "name": "The junk mech"}], "phase": 0}


func _model() -> BossBarModel:
	var model: BossBarModel = BossBarModel.new()
	model.show_bar(INFO)
	return model


func test_showing_the_bar_slides_it_in() -> void:
	var model: BossBarModel = _model()
	assert_true(model.shown)
	assert_false(model.is_visible(), "nothing is on screen until it has begun to slide in")
	model.tick(0.1)
	assert_true(model.is_visible())
	model.tick(1.0)
	assert_almost_eq(model.presence, 1.0, 0.0001)
	assert_eq(model.boss_name, "The Hushmaster")
	assert_eq(model.phase_count(), 2)


func test_health_eases_down_and_a_chip_trails_it() -> void:
	var model: BossBarModel = _model()
	model.tick(1.0)
	model.set_hp(150.0)
	assert_almost_eq(model.fill(), 0.5, 0.0001)
	assert_almost_eq(model.chip, 1.0, 0.0001, "the chip waits where the health was")
	model.tick(0.1)
	assert_lt(model.fill_shown, 1.0)
	assert_gt(model.fill_shown, 0.5, "the bar eases, it doesn't jump")
	for i: int in 60:
		model.tick(0.1)
	assert_almost_eq(model.fill_shown, 0.5, 0.001)
	assert_almost_eq(model.chip, 0.5, 0.001)


func test_healing_does_not_leave_a_chip() -> void:
	var model: BossBarModel = _model()
	model.set_hp(100.0)
	model.tick(0.1)
	var chip_before: float = model.chip
	model.set_hp(200.0)
	assert_eq(model.chip, chip_before)


func test_a_phase_change_flashes_and_names_the_new_phase() -> void:
	var model: BossBarModel = _model()
	model.tick(1.0)
	assert_eq(model.phase_name(), "The rig")
	assert_almost_eq(model.flash(), 0.0, 0.0001)
	model.set_phase(1)
	assert_eq(model.phase_index, 1)
	assert_eq(model.phase_name(), "The junk mech")
	assert_gt(model.flash(), 0.9)
	model.tick(1.0)
	assert_almost_eq(model.flash(), 0.0, 0.0001)
	model.set_phase(1)
	assert_almost_eq(model.flash(), 0.0, 0.0001, "the same phase again doesn't flash")
	model.set_phase(9)
	assert_eq(model.phase_index, 1, "an out-of-range phase is clamped")


func test_hiding_fades_the_bar_away_and_it_can_come_back() -> void:
	var model: BossBarModel = _model()
	model.tick(1.0)
	model.hide_bar()
	model.tick(0.2)
	assert_true(model.is_visible())
	model.tick(1.0)
	assert_false(model.shown)
	model.show_bar(INFO)
	assert_almost_eq(model.fill_shown, 1.0, 0.0001, "a new fight starts full")


func test_part_pips_count_what_still_stands_and_clamp() -> void:
	var model: BossBarModel = BossBarModel.new()
	model.set_pips(3, 4)
	assert_eq(model.pips_standing, 3)
	assert_eq(model.pips_total, 4)
	model.set_pips(9, 4)
	assert_eq(model.pips_standing, 4, "never more than the total")
	model.set_pips(-2, 4)
	assert_eq(model.pips_standing, 0)
	model.show_bar({"name": "x", "hp": 1.0, "hp_max": 1.0})
	assert_eq(model.pips_total, 0, "showing a new bar clears them")
