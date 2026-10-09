extends TestCase
## HackSelector: pick-then-fire (option A) cycles in order; automatic (option C) reads the situation. Every rule in
## hacks.json `auto.rules` has a test below, and the last test fails if a rule is added without one.

var _covered: Dictionary = {}


func _selector() -> HackSelector:
	return HackSelector.from_data(CombatData.hacks())


func _afford(all: bool = true) -> Dictionary:
	return {"zap_drone": all, "emp": all, "overclock": all, "reboot": all}


## A quiet situation: nobody near, nothing locked, nothing hijackable, every hack affordable, button tapped.
func _sit(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {"held_ms": 0.0, "enemy_dists": [], "lock": {"exists": false, "tags": [], "hijackable": false},
			"cone": [], "affordable": _afford()}
	base.merge(overrides, true)
	return base


func _expect(rule: String, hack: String, overrides: Dictionary, fizz: bool = false) -> void:
	var pick: Dictionary = _selector().pick_auto(_sit(overrides))
	assert_eq(pick["rule"], StringName(rule), "rule for %s" % overrides)
	assert_eq(pick["hack"], StringName(hack), "hack for rule %s" % rule)
	assert_eq(pick["fizz"], fizz, "fizz for rule %s" % rule)
	_covered[rule] = true


# ---- option A: pick, then fire ----

func test_it_starts_in_pick_mode_on_zap_drone() -> void:
	var selector: HackSelector = _selector()
	assert_eq(selector.mode, HackSelector.MODE_PICK)
	assert_eq(selector.selected(), &"zap_drone")
	assert_eq(selector.order(), [&"zap_drone", &"emp", &"overclock", &"reboot"] as Array[StringName])


func test_stepping_right_walks_the_order_and_wraps() -> void:
	var selector: HackSelector = _selector()
	var seen: Array[StringName] = []
	for i: int in range(5):
		seen.append(selector.step(1))
	assert_eq(seen, [&"emp", &"overclock", &"reboot", &"zap_drone", &"emp"] as Array[StringName])


func test_stepping_left_from_the_first_wraps_to_the_last() -> void:
	var selector: HackSelector = _selector()
	assert_eq(selector.step(-1), &"reboot")
	assert_eq(selector.step(-1), &"overclock")


func test_without_wrap_the_ends_stop() -> void:
	var selector: HackSelector = _selector()
	selector.wrap = false
	assert_eq(selector.step(-1), &"zap_drone")
	selector.select_index(3)
	assert_eq(selector.step(1), &"reboot")


func test_the_number_keys_choose_by_slot() -> void:
	var selector: HackSelector = _selector()
	assert_true(selector.select_index(2))
	assert_eq(selector.selected(), &"overclock")
	assert_false(selector.select_index(4), "there is no fifth hack")
	assert_false(selector.select_index(-1))
	assert_eq(selector.selected(), &"overclock", "a bad slot changes nothing")
	assert_true(selector.select_id(&"reboot"))
	assert_eq(selector.selected(), &"reboot")
	assert_false(selector.select_id(&"nope"))


func test_the_feel_knob_flips_the_mode_both_ways() -> void:
	var selector: HackSelector = _selector()
	selector.set_mode_from_knob("automatic")
	assert_eq(selector.mode, HackSelector.MODE_AUTO)
	selector.set_mode_from_knob("pick_then_fire")
	assert_eq(selector.mode, HackSelector.MODE_PICK)
	selector.set_mode_from_knob("garbage")
	assert_eq(selector.mode, HackSelector.MODE_PICK, "an unknown value changes nothing")


func test_the_hud_shows_the_selection_in_pick_and_the_last_used_in_auto() -> void:
	var selector: HackSelector = _selector()
	selector.select_index(1)
	assert_eq(selector.shown(), &"emp")
	selector.note_used(&"zap_drone")
	assert_eq(selector.shown(), &"emp", "pick mode shows the selection, not the last used")
	selector.set_mode_from_knob("automatic")
	assert_eq(selector.shown(), &"zap_drone", "automatic shows the last used, so the guess is never a surprise")


func test_automatic_with_nothing_used_yet_shows_the_selection() -> void:
	var selector: HackSelector = _selector()
	selector.set_mode_from_knob("automatic")
	assert_eq(selector.shown(), &"zap_drone")


# ---- option C: the rules, top to bottom ----

func test_reboot_hold_a_held_button_reboots() -> void:
	_expect("reboot_hold", "reboot", {"held_ms": 450.0})


func test_reboot_hold_a_tap_never_reboots() -> void:
	var pick: Dictionary = _selector().pick_auto(_sit({"held_ms": 449.0}))
	assert_ne(pick["rule"], &"reboot_hold")
	assert_eq(pick["hack"], &"zap_drone")


func test_reboot_hold_without_a_full_battery_fizzes_and_spends_nothing() -> void:
	var afford: Dictionary = _afford()
	afford["reboot"] = false
	_expect("reboot_hold", "reboot", {"held_ms": 600.0, "affordable": afford}, true)


func test_the_hold_time_knob_replaces_the_data_number() -> void:
	var selector: HackSelector = _selector()
	assert_eq(selector.pick_auto(_sit({"held_ms": 300.0}), {"auto_hold_ms": 250.0})["hack"], &"reboot")
	assert_eq(selector.pick_auto(_sit({"held_ms": 300.0}), {"auto_hold_ms": 600.0})["hack"], &"zap_drone")


func test_swarmed_four_close_enemies_get_an_emp() -> void:
	_expect("swarmed", "emp", {"enemy_dists": [1.0, 2.0, 3.0, 3.5]})


func test_swarmed_needs_all_four_inside_3_5_m() -> void:
	var pick: Dictionary = _selector().pick_auto(_sit({"enemy_dists": [1.0, 2.0, 3.0, 3.6]}))
	assert_ne(pick["rule"], &"swarmed")
	assert_eq(pick["rule"], &"crowd", "but three are inside 4.5 m")


func test_swarmed_beats_a_turret_in_front() -> void:
	var cone: Array = [{"dist": 6.0, "angle_deg": 5.0, "tags": ["turret"]}]
	_expect("swarmed", "emp", {"enemy_dists": [1.0, 1.5, 2.0, 2.5], "cone": cone})


func test_swarmed_that_cannot_be_afforded_tries_the_next_rule() -> void:
	var afford: Dictionary = _afford()
	afford["emp"] = false
	var pick: Dictionary = _selector().pick_auto(_sit({"enemy_dists": [1.0, 1.5, 2.0, 2.5], "affordable": afford}))
	assert_eq(pick["hack"], &"zap_drone", "no EMP money: it falls through to the default")
	assert_eq(pick["rule"], &"default")


func test_locked_machine_a_locked_turret_is_overclocked() -> void:
	_expect("locked_machine", "overclock", {"lock": {"exists": true, "tags": ["turret"], "hijackable": true}})


func test_locked_machine_counts_a_locked_drone() -> void:
	_expect("locked_machine", "overclock", {"lock": {"exists": true, "tags": ["drone"], "hijackable": true}})


func test_locked_machine_needs_something_she_can_hijack() -> void:
	var pick: Dictionary = _selector().pick_auto(_sit({"lock": {"exists": true, "tags": ["turret"], "hijackable": false}}))
	assert_eq(pick["hack"], &"zap_drone", "already hijacked, or not takeable: zap it instead")


func test_locked_machine_ignores_a_locked_plain_enemy() -> void:
	var pick: Dictionary = _selector().pick_auto(_sit({"lock": {"exists": true, "tags": [], "hijackable": true}}))
	assert_eq(pick["hack"], &"zap_drone")


func test_machine_ahead_a_turret_in_front_is_overclocked() -> void:
	_expect("machine_ahead", "overclock", {"cone": [{"dist": 8.0, "angle_deg": 20.0, "tags": ["turret"]}]})


func test_machine_ahead_takes_a_robot_too() -> void:
	_expect("machine_ahead", "overclock", {"cone": [{"dist": 10.0, "angle_deg": 60.0, "tags": ["robot"]}]})


func test_machine_ahead_leaves_loose_drones_to_be_zapped() -> void:
	var pick: Dictionary = _selector().pick_auto(_sit({"cone": [{"dist": 5.0, "angle_deg": 0.0, "tags": ["drone"]}]}))
	assert_eq(pick["hack"], &"zap_drone")


func test_machine_ahead_must_be_in_range_and_in_front() -> void:
	assert_eq(_selector().pick_auto(_sit({"cone": [{"dist": 10.1, "angle_deg": 0.0, "tags": ["turret"]}]}))["hack"], &"zap_drone", "too far")
	assert_eq(_selector().pick_auto(_sit({"cone": [{"dist": 5.0, "angle_deg": 61.0, "tags": ["turret"]}]}))["hack"], &"zap_drone", "behind her shoulder")


func test_machine_ahead_that_costs_too_much_falls_through() -> void:
	var afford: Dictionary = _afford()
	afford["overclock"] = false
	var pick: Dictionary = _selector().pick_auto(_sit({"cone": [{"dist": 5.0, "angle_deg": 0.0, "tags": ["turret"]}], "affordable": afford}))
	assert_eq(pick["hack"], &"zap_drone")


func test_crowd_three_enemies_inside_4_5_m_get_an_emp() -> void:
	_expect("crowd", "emp", {"enemy_dists": [2.0, 3.0, 4.5]})


func test_crowd_two_are_not_a_crowd() -> void:
	var pick: Dictionary = _selector().pick_auto(_sit({"enemy_dists": [2.0, 3.0]}))
	assert_eq(pick["rule"], &"default")


func test_the_crowd_knob_changes_how_many_make_a_crowd() -> void:
	var selector: HackSelector = _selector()
	assert_eq(selector.pick_auto(_sit({"enemy_dists": [2.0, 3.0]}), {"auto_crowd": 2})["hack"], &"emp")
	assert_eq(selector.pick_auto(_sit({"enemy_dists": [2.0, 3.0, 4.0]}), {"auto_crowd": 4})["hack"], &"zap_drone")


func test_default_is_a_zap_drone() -> void:
	_expect("default", "zap_drone", {})


func test_default_without_battery_fizzes() -> void:
	_expect("default", "zap_drone", {"affordable": _afford(false)}, true)


func test_the_rules_are_read_top_to_bottom() -> void:
	# A locked turret AND a crowd of three: the locked-machine rule comes first.
	var sit: Dictionary = _sit({"enemy_dists": [2.0, 3.0, 4.0], "lock": {"exists": true, "tags": ["turret"], "hijackable": true}})
	assert_eq(_selector().pick_auto(sit)["rule"], &"locked_machine")


func test_an_unknown_when_key_fails_its_rule() -> void:
	var doc: Dictionary = {"hacks": {"zap_drone": {}}, "auto": {"rules": [
			{"id": "typo", "hack": "emp", "when": {"enemies_closeby": 3}, "if_short": "next"},
			{"id": "default", "hack": "zap_drone", "when": {}, "if_short": "fizz"}]}}
	var selector: HackSelector = HackSelector.from_data(doc)
	assert_eq(selector.pick_auto(_sit())["rule"], &"default", "a typo never fires; it shows up in the tests")


func test_every_rule_in_the_data_has_a_test() -> void:
	# Runs after the others alphabetically only by accident; so it re-checks each rule id against the file itself.
	var tested: Array[String] = ["reboot_hold", "swarmed", "locked_machine", "machine_ahead", "crowd", "default"]
	for id: StringName in _selector().rule_ids():
		assert_has(tested, String(id), "rule %s has no test in this file" % id)
