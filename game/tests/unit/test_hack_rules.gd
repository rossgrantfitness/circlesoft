extends TestCase
## HackRules (docs/slice/hacks_design.md): what each hack costs, and the first reason a cast is refused: the jam, the
## air, a cooldown, a hijack already running, no signal, a battery that is not full or not enough.

const ZAP: StringName = &"zap_drone"
const EMP: StringName = &"emp"
const OVERCLOCK: StringName = &"overclock"
const REBOOT: StringName = &"reboot"


func _rules() -> HackRules:
	return HackRules.from_data(CombatData.hacks())


## A context that allows everything: a full battery, nothing in the way, a target in reach.
func _ctx(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {"charge": 100.0, "capacity": 100.0, "now_ms": 10000.0, "locked": false, "airborne": false,
			"has_target": true, "hijack_active": false, "knobs": {}}
	base.merge(overrides, true)
	return base


func _why(id: StringName, overrides: Dictionary = {}, rules: HackRules = null) -> StringName:
	var use: HackRules = rules if rules != null else _rules()
	return StringName(str(use.check(id, _ctx(overrides))["reason"]))


# ---- the data ----

func test_the_four_hacks_come_in_the_designers_order() -> void:
	assert_eq(_rules().order(), [ZAP, EMP, OVERCLOCK, REBOOT] as Array[StringName])


func test_costs_are_the_designers_numbers() -> void:
	var rules: HackRules = _rules()
	assert_eq(rules.cost(ZAP, 80.0), 20.0)
	assert_eq(rules.cost(EMP, 80.0), 40.0)
	assert_eq(rules.cost(OVERCLOCK, 80.0), 50.0)
	assert_eq(rules.cost(REBOOT, 80.0), 80.0, "Reboot takes the whole battery")


func test_the_cost_knob_scales_everything_but_reboot() -> void:
	var rules: HackRules = _rules()
	var knobs: Dictionary = {"cost_scale": 0.5}
	assert_eq(rules.cost(ZAP, 100.0, knobs), 10.0)
	assert_eq(rules.cost(REBOOT, 100.0, knobs), 100.0)


func test_free_casting_costs_nothing() -> void:
	assert_eq(_rules().cost(OVERCLOCK, 100.0, {"free_cast": true}), 0.0)


func test_every_hack_names_a_cast_move_that_exists_in_moves_json() -> void:
	var moves: MoveSet = MoveSet.load_default()
	var rules: HackRules = _rules()
	for id: StringName in rules.order():
		assert_true(moves.has_move(&"red", rules.cast_move(id)), "%s -> %s" % [id, rules.cast_move(id)])
		assert_eq(str(moves.get_move(&"red", rules.cast_move(id)).get("kind", "")), "hack", "%s is a hack move" % id)


# ---- the verdict ----

func test_a_full_battery_and_a_clear_field_allows_every_hack() -> void:
	var rules: HackRules = _rules()
	for id: StringName in rules.order():
		assert_true(bool(rules.check(id, _ctx())["ok"]), String(id))


func test_the_verdict_carries_the_price() -> void:
	assert_eq(float(_rules().check(EMP, _ctx())["cost"]), 40.0)


func test_an_unknown_hack_is_refused() -> void:
	assert_eq(_why(&"nope"), HackRules.R_UNKNOWN)


func test_too_little_battery_is_refused_with_nothing_else_wrong() -> void:
	assert_eq(_why(ZAP, {"charge": 19.0}), HackRules.R_BATTERY)
	assert_eq(_why(ZAP, {"charge": 20.0}), HackRules.OK, "exactly the cost is enough")
	assert_eq(_why(EMP, {"charge": 39.0}), HackRules.R_BATTERY)
	assert_eq(_why(OVERCLOCK, {"charge": 49.0}), HackRules.R_BATTERY)


func test_reboot_needs_a_full_battery() -> void:
	assert_eq(_why(REBOOT, {"charge": 99.0}), HackRules.R_NOT_FULL)
	assert_eq(_why(REBOOT, {"charge": 100.0}), HackRules.OK)


func test_with_the_full_battery_knob_off_reboot_works_from_half_a_battery() -> void:
	var knobs: Dictionary = {"reboot_needs_full": false}
	assert_eq(_why(REBOOT, {"charge": 60.0, "knobs": knobs}), HackRules.OK)
	assert_eq(_why(REBOOT, {"charge": 50.0, "knobs": knobs}), HackRules.OK, "exactly half is enough")
	assert_eq(_why(REBOOT, {"charge": 40.0, "knobs": knobs}), HackRules.R_BATTERY)


func test_quiet_hours_jams_every_hack() -> void:
	var rules: HackRules = _rules()
	for id: StringName in rules.order():
		assert_eq(_why(id, {"locked": true}, rules), HackRules.R_LOCKED, String(id))


func test_the_jam_is_named_before_the_battery() -> void:
	assert_eq(_why(ZAP, {"locked": true, "charge": 0.0}), HackRules.R_LOCKED)


func test_zap_and_emp_can_be_cast_in_the_air_overclock_and_reboot_cannot() -> void:
	assert_eq(_why(ZAP, {"airborne": true}), HackRules.OK)
	assert_eq(_why(EMP, {"airborne": true}), HackRules.OK)
	assert_eq(_why(OVERCLOCK, {"airborne": true}), HackRules.R_AIR)
	assert_eq(_why(REBOOT, {"airborne": true}), HackRules.R_AIR)


func test_overclock_with_nothing_to_take_is_refused_before_it_costs_anything() -> void:
	assert_eq(_why(OVERCLOCK, {"has_target": false}), HackRules.R_NO_SIGNAL)


func test_zap_with_no_target_still_fires_straight() -> void:
	assert_eq(_why(ZAP, {"has_target": false}), HackRules.OK)


func test_a_second_overclock_is_refused_while_one_runs() -> void:
	assert_eq(_why(OVERCLOCK, {"hijack_active": true}), HackRules.R_OVERCLOCK)
	assert_eq(_why(ZAP, {"hijack_active": true}), HackRules.OK, "other hacks do not care")


# ---- cooldowns ----

func test_a_cast_starts_that_hacks_cooldown() -> void:
	var rules: HackRules = _rules()
	rules.start_cooldown(ZAP, 10000.0)
	assert_eq(_why(ZAP, {"now_ms": 10100.0}, rules), HackRules.R_COOLDOWN)
	assert_eq(rules.cooldown_left_ms(ZAP, 10100.0), 400.0, "500 ms from the data")
	assert_eq(_why(ZAP, {"now_ms": 10500.0}, rules), HackRules.OK)


func test_a_cast_also_starts_the_short_global_cooldown_for_the_others() -> void:
	var rules: HackRules = _rules()
	rules.start_cooldown(ZAP, 10000.0)
	assert_eq(_why(EMP, {"now_ms": 10100.0}, rules), HackRules.R_GLOBAL, "250 ms between any two hacks")
	assert_eq(_why(EMP, {"now_ms": 10250.0}, rules), HackRules.OK)


func test_the_cooldown_knob_scales_and_zero_turns_cooldowns_off() -> void:
	var rules: HackRules = _rules()
	rules.start_cooldown(OVERCLOCK, 0.0, {"cooldown_scale": 2.0})
	assert_eq(rules.cooldown_left_ms(OVERCLOCK, 0.0), 3000.0)
	var free: HackRules = _rules()
	free.start_cooldown(OVERCLOCK, 0.0, {"cooldown_scale": 0.0})
	assert_eq(free.cooldown_left_ms(OVERCLOCK, 0.0), 0.0)


func test_a_refunded_cast_leaves_no_cooldown() -> void:
	var rules: HackRules = _rules()
	rules.start_cooldown(OVERCLOCK, 10000.0)
	rules.clear_cooldown(OVERCLOCK)
	assert_eq(_why(OVERCLOCK, {"now_ms": 10001.0}, rules), HackRules.OK)


func test_the_cooldown_fraction_runs_from_one_to_zero() -> void:
	var rules: HackRules = _rules()
	rules.start_cooldown(EMP, 0.0)
	assert_almost_eq(rules.cooldown_fraction(EMP, 0.0), 1.0)
	assert_almost_eq(rules.cooldown_fraction(EMP, 600.0), 0.5)
	assert_almost_eq(rules.cooldown_fraction(EMP, 5000.0), 0.0)


# ---- affordable (for the automatic picker) ----

func test_affordable_looks_at_the_battery_only() -> void:
	var rules: HackRules = _rules()
	assert_true(rules.affordable(ZAP, 20.0, 100.0))
	assert_false(rules.affordable(ZAP, 19.0, 100.0))
	assert_false(rules.affordable(REBOOT, 99.0, 100.0))
	assert_true(rules.affordable(REBOOT, 100.0, 100.0))
	assert_true(rules.affordable(OVERCLOCK, 50.0, 100.0), "no target needed for this question")


# ---- what a hack does to tags ----

func test_zap_does_double_to_a_drone_and_triple_to_a_relay() -> void:
	var rules: HackRules = _rules()
	assert_eq(rules.tag_mult(ZAP, ["drone"]), 2.0)
	assert_eq(rules.tag_mult(ZAP, ["relay"]), 3.0)
	assert_eq(rules.tag_mult(ZAP, ["turret"]), 1.5)
	assert_eq(rules.tag_mult(ZAP, []), 1.0, "an untagged enemy takes plain damage")
	assert_eq(rules.tag_mult(ZAP, ["drone", "relay"]), 3.0, "the biggest tag wins")


func test_emp_stuns_drones_turrets_and_robots_for_different_times() -> void:
	var rules: HackRules = _rules()
	assert_eq(rules.stun_ms(EMP, ["drone"]), 3000.0)
	assert_eq(rules.stun_ms(EMP, ["turret"]), 4000.0)
	assert_eq(rules.stun_ms(EMP, ["robot"]), 2500.0)
	assert_eq(rules.stun_ms(EMP, []), 0.0, "an untagged enemy is only pushed")
	assert_eq(rules.stun_ms(EMP, ["drone"], 2.0), 6000.0, "the stun knob scales it")


func test_reboot_heals_half_of_her_health() -> void:
	var rules: HackRules = _rules()
	assert_eq(rules.heal_amount(REBOOT, 120, 1.0), 60)
	assert_eq(rules.heal_amount(REBOOT, 120, 1.0, {"reboot_heal_pct": 100.0}), 120, "the heal knob")


func test_a_part_battery_reboot_heals_in_proportion() -> void:
	var rules: HackRules = _rules()
	assert_eq(rules.heal_amount(REBOOT, 120, 0.6, {"reboot_needs_full": false}), 36, "half of 120, at 60 percent")
	assert_eq(rules.heal_amount(REBOOT, 120, 0.6, {"reboot_needs_full": true}), 60, "a full-battery Reboot is a full heal")


# ---- the knobs ----

func test_knobs_from_the_feel_panel_become_a_plain_dictionary() -> void:
	var feel: FeelKnobs = FeelKnobs.load_defaults()
	feel.set_value("hack_cost_scale", 0.5)
	feel.set_value("hack_pick_mode", "automatic")
	feel.set_value("hack_free_cast", true)
	var knobs: Dictionary = HackRules.knobs_from(feel)
	assert_eq(knobs["cost_scale"], 0.5)
	assert_eq(knobs["pick_mode"], "automatic")
	assert_eq(knobs["free_cast"], true)
	assert_eq(knobs["zap_pierce"], 3)
	assert_eq(knobs["overclock_s"], 10.0)
	assert_eq(knobs["reboot_needs_full"], true)


func test_knobs_from_nothing_are_the_neutral_defaults() -> void:
	var knobs: Dictionary = HackRules.knobs_from(null)
	assert_eq(knobs["cost_scale"], 1.0)
	assert_eq(knobs["pick_mode"], "pick_then_fire")
	assert_eq(knobs["free_cast"], false)
