extends TestCase
## DashCharges (pure) and its data: Ross's "dash on charges" (decisions 2026-10-09). Up to N charges, each dash spends one,
## spent charges come back one at a time on a single timer that dashing never restarts, and a short gap separates chained dashes.
## Every number is read from the feel knobs (data/combat/feel.json) or the scale profiles, never pinned here.

const STEP: float = 1.0 / 60.0

var _knobs: FeelKnobs = null


func before_each() -> void:
	_knobs = FeelKnobs.load_defaults()


func _max() -> int:
	return int(_knobs.get_f("dash_charges"))


func _recharge() -> float:
	return _knobs.get_f("dash_recharge_s")


func _run(charges: DashCharges, seconds: float) -> void:
	var frames: int = int(round(seconds / STEP))
	for i: int in frames:
		charges.tick(STEP, _recharge())


# ---- the knobs exist, with Ross's ranges ----

func test_the_three_knobs_exist_in_the_movement_group_with_ross_ranges() -> void:
	var list: Array = CombatData.feel().get("knobs", []) as Array
	var by_id: Dictionary = {}
	for entry: Variant in list:
		by_id[str((entry as Dictionary)["id"])] = entry
	for id: String in ["dash_charges", "dash_recharge_s", "dash_chain_gap_s"]:
		assert_true(by_id.has(id), id + " is an F12 knob")
		assert_eq(str((by_id[id] as Dictionary).get("group")), "movement", id + " sits with the other dash knobs")
	assert_eq(int((by_id["dash_charges"] as Dictionary)["min"]), 1)
	assert_eq(int((by_id["dash_charges"] as Dictionary)["max"]), 8)
	assert_almost_eq(float((by_id["dash_recharge_s"] as Dictionary)["min"]), 0.5)
	assert_almost_eq(float((by_id["dash_recharge_s"] as Dictionary)["max"]), 4.0)
	assert_almost_eq(float((by_id["dash_chain_gap_s"] as Dictionary)["min"]), 0.0)
	assert_almost_eq(float((by_id["dash_chain_gap_s"] as Dictionary)["max"]), 0.4)


func test_red_starts_with_the_knobs_full_count() -> void:
	var charges: DashCharges = DashCharges.create(_max())
	assert_eq(charges.count, _max())
	assert_true(charges.is_ready())


# ---- spending ----

func test_every_charge_can_be_spent_and_the_next_is_refused() -> void:
	var charges: DashCharges = DashCharges.create(_max())
	for i: int in _max():
		assert_true(charges.spend(), "dash %d of %d works" % [i + 1, _max()])
	assert_eq(charges.count, 0)
	assert_false(charges.has_charge())
	assert_false(charges.is_ready())
	assert_false(charges.spend(), "one more than she holds is refused")
	assert_eq(charges.count, 0, "and a refusal costs nothing")


# ---- refilling ----

func test_charges_refill_one_at_a_time() -> void:
	var charges: DashCharges = DashCharges.create(_max())
	for i: int in _max():
		charges.spend()
	_run(charges, _recharge() * 0.9)
	assert_eq(charges.count, 0, "nothing yet before the first recharge time")
	_run(charges, _recharge() * 0.2)
	assert_eq(charges.count, 1, "one charge after one recharge time, not all of them")
	_run(charges, _recharge())
	assert_eq(charges.count, 2, "the next one a recharge time later")
	_run(charges, _recharge() * float(_max()))
	assert_eq(charges.count, _max(), "and it stops at the max")
	assert_almost_eq(charges.refill_fraction(), 0.0, 0.0001, "a full set has no timer running")


func test_dashing_does_not_restart_the_refill_timer() -> void:
	var charges: DashCharges = DashCharges.create(_max())
	charges.spend()
	_run(charges, _recharge() * 0.75)
	charges.spend()                     # a second dash three quarters of the way through the first charge's refill
	assert_almost_eq(charges.refill_fraction(), 0.75, 0.03, "the timer carried on")
	_run(charges, _recharge() * 0.3)
	assert_eq(charges.count, _max() - 1, "the first spent charge arrived on its original schedule (one back, one still out)")
	_run(charges, _recharge())
	assert_eq(charges.count, _max(), "and the second a full recharge time after that")


func test_the_timer_runs_continuously_while_any_charge_is_missing() -> void:
	var charges: DashCharges = DashCharges.create(_max())
	charges.spend()
	charges.spend()
	var fractions: Array[float] = []
	for i: int in 30:
		charges.tick(STEP, _recharge())
		fractions.append(charges.refill_fraction())
	for i: int in range(1, fractions.size()):
		assert_gt(fractions[i], fractions[i - 1], "the pip keeps filling every frame")


func test_a_long_frame_loses_no_charge() -> void:
	var charges: DashCharges = DashCharges.create(_max())
	for i: int in _max():
		charges.spend()
	charges.tick(_recharge() * 2.5, _recharge())
	assert_eq(charges.count, 2, "two whole charges from two and a half recharge times, the rest carried")
	assert_almost_eq(charges.refill_fraction(), 0.5, 0.001)


# ---- the gap ----

func test_the_gap_blocks_a_new_dash_until_it_ends() -> void:
	var charges: DashCharges = DashCharges.create(_max())
	var gap: float = _knobs.get_f("dash_chain_gap_s")
	charges.start_gap(gap)
	assert_false(charges.is_ready(), "a charge is there but the gap is running")
	assert_true(charges.has_charge())
	charges.tick(gap * 0.5, _recharge())
	assert_false(charges.is_ready())
	charges.tick(gap * 0.6, _recharge())
	assert_true(charges.is_ready(), "ready as soon as the gap is over")


func test_a_zero_gap_never_blocks() -> void:
	var charges: DashCharges = DashCharges.create(_max())
	charges.start_gap(0.0)
	assert_true(charges.is_ready())


# ---- live knob changes ----

func test_raising_the_max_adds_full_charges_and_lowering_trims() -> void:
	var charges: DashCharges = DashCharges.create(3)
	charges.spend()
	charges.sync_max(5)
	assert_eq(charges.count, 4, "two new slots arrive full; the spent one stays spent")
	charges.sync_max(2)
	assert_eq(charges.count, 2)
	assert_eq(charges.max_count, 2)


func test_refill_all_resets_everything() -> void:
	var charges: DashCharges = DashCharges.create(_max())
	charges.spend()
	charges.spend()
	charges.start_gap(0.2)
	charges.refill_all()
	assert_eq(charges.count, _max())
	assert_true(charges.is_ready())


func test_the_snapshot_is_what_the_hud_reads() -> void:
	var charges: DashCharges = DashCharges.create(_max())
	charges.spend()
	_run(charges, _recharge() * 0.5)
	var shot: Dictionary = charges.snapshot()
	assert_eq(int(shot["count"]), _max() - 1)
	assert_eq(int(shot["max"]), _max())
	assert_almost_eq(float(shot["fraction"]), 0.5, 0.03)


# ---- scale profiles ----

func test_each_robot_profile_has_its_own_charge_numbers_in_data() -> void:
	for form_id: StringName in [ScaleProfile.FORM_SMALL, ScaleProfile.FORM_HUGE]:
		var profile: ScaleProfile = ScaleProfile.get_form(form_id)
		assert_not_null(profile)
		for id: String in ["dash_charges", "dash_recharge_s", "dash_chain_gap_s"]:
			assert_true(profile.has_knob(id), "%s sets %s" % [form_id, id])
		assert_ge(profile.knob("dash_charges", 0.0), 1.0)
		assert_ge(profile.knob("dash_recharge_s", 0.0), 0.5)


func test_red_has_no_override_so_the_f12_knobs_drive_her() -> void:
	var red: ScaleProfile = ScaleProfile.get_form(ScaleProfile.FORM_RED)
	assert_false(red.has_knob("dash_charges"))
	assert_false(red.has_knob("dash_recharge_s"))
	assert_false(red.has_knob("dash_chain_gap_s"))
