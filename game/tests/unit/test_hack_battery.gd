extends TestCase
## HackBattery (slice tech plan 4.2): what a sword hit is worth, the per-second cap, hack hits never refilling it,
## spending and refunds, Kasp's lock, and the data it reads (hacks.json: capacity 100, start 50, hit 7, blocked 3,
## armored 4, guard_broken 10, finisher +6, air +2, cap 30 a second).


func _battery() -> HackBattery:
	return HackBattery.from_data(CombatData.hacks())


func test_it_starts_at_the_new_game_charge_and_reports_fill() -> void:
	var battery: HackBattery = _battery()
	assert_eq(battery.capacity(), 100.0)
	assert_eq(battery.charge(), 50.0)
	assert_almost_eq(battery.fill(), 0.5)
	assert_false(battery.is_full())


func test_it_reads_the_battery_block_alone_too() -> void:
	var block: Dictionary = CombatData.hacks()["battery"]
	var battery: HackBattery = HackBattery.from_data(block)
	assert_eq(battery.capacity(), 100.0)
	assert_eq(battery.charge(), 50.0)


func test_each_outcome_is_worth_its_number_from_the_data() -> void:
	var battery: HackBattery = _battery()
	assert_eq(battery.gain_for(&"hit"), 7.0)
	assert_eq(battery.gain_for(&"stagger"), 7.0, "a hit that broke poise is a clean hit")
	assert_eq(battery.gain_for(&"blocked"), 3.0)
	assert_eq(battery.gain_for(&"armored"), 4.0)
	assert_eq(battery.gain_for(&"guard_broken"), 10.0)


func test_a_finisher_and_an_air_hit_add_their_bonus() -> void:
	var battery: HackBattery = _battery()
	assert_eq(battery.gain_for(&"hit", false, true), 13.0)
	assert_eq(battery.gain_for(&"hit", true, false), 9.0)
	assert_eq(battery.gain_for(&"hit", true, true), 15.0)


func test_misses_and_parries_are_worth_nothing() -> void:
	var battery: HackBattery = _battery()
	for outcome: StringName in [&"evaded", &"parried", &"perfect_parry", &"guarded", &"ignored"]:
		assert_eq(battery.gain_for(outcome, true, true), 0.0, String(outcome))


func test_a_sword_hit_fills_it() -> void:
	var battery: HackBattery = _battery()
	var added: float = battery.add_from_hit(&"hit", &"light_1", false, false, 0.0)
	assert_eq(added, 7.0)
	assert_eq(battery.charge(), 57.0)


func test_a_light_string_of_three_ending_in_a_finisher_is_27() -> void:
	# hacks_design.md: "one Light string of three plus its finisher is about 27" (7 + 7 + 7 + 6).
	var battery: HackBattery = _battery()
	battery.set_charge(0.0)
	var total: float = 0.0
	total += battery.add_from_hit(&"hit", &"light_1", false, false, 0.0)
	total += battery.add_from_hit(&"hit", &"light_2", false, false, 250.0)
	total += battery.add_from_hit(&"hit", &"launcher", false, true, 500.0)
	assert_eq(total, 27.0)


func test_the_per_second_cap_stops_a_multi_hit_filling_it_in_a_frame() -> void:
	var battery: HackBattery = _battery()
	battery.set_charge(0.0)
	var gained: float = 0.0
	for i: int in range(6):
		gained += battery.add_from_hit(&"hit", &"air_3", false, true, 100.0)       # 13 each, the same moment
	assert_eq(gained, 30.0, "the cap is 30 a second")
	assert_eq(battery.charge(), 30.0)


func test_the_cap_window_slides_so_it_fills_again_a_second_later() -> void:
	var battery: HackBattery = _battery()
	battery.set_charge(0.0)
	for i: int in range(5):
		battery.add_from_hit(&"hit", &"x", false, true, 0.0)
	assert_eq(battery.charge(), 30.0)
	assert_eq(battery.add_from_hit(&"hit", &"x", false, false, 999.0), 0.0, "still the same second")
	assert_eq(battery.add_from_hit(&"hit", &"x", false, false, 1000.0), 7.0, "a second on, the window is clear")


func test_it_never_goes_past_capacity() -> void:
	var battery: HackBattery = _battery()
	battery.set_charge(97.0)
	assert_eq(battery.add_from_hit(&"hit", &"x", false, false, 0.0), 3.0, "only 3 fit")
	assert_true(battery.is_full())
	assert_eq(battery.add_from_hit(&"hit", &"x", false, false, 2000.0), 0.0, "and nothing more")


func test_a_hack_hit_never_refills_the_battery() -> void:
	var battery: HackBattery = _battery()
	assert_eq(battery.add_from_hit(&"hit", &"hack_zap", false, false, 0.0, 1.0, &"hack"), 0.0)
	assert_eq(battery.add_from_hit(&"hit", &"x", false, false, 0.0, 1.0, &"hijacked"), 0.0)
	assert_eq(battery.charge(), 50.0)


func test_the_gain_scale_knob_multiplies_what_a_hit_gives() -> void:
	var battery: HackBattery = _battery()
	assert_eq(battery.add_from_hit(&"hit", &"x", false, false, 0.0, 2.0), 14.0)
	assert_eq(battery.add_from_hit(&"hit", &"x", false, false, 5000.0, 0.0), 0.0, "scale 0 gives nothing")


func test_spend_takes_the_cost_or_nothing() -> void:
	var battery: HackBattery = _battery()
	assert_true(battery.can_spend(50.0))
	assert_false(battery.can_spend(50.5))
	assert_false(battery.spend(60.0))
	assert_eq(battery.charge(), 50.0, "a refused spend takes nothing")
	assert_true(battery.spend(20.0))
	assert_eq(battery.charge(), 30.0)


func test_spend_all_empties_it_and_says_how_much_it_took() -> void:
	var battery: HackBattery = _battery()
	battery.reset_full()
	assert_eq(battery.spend_all(), 100.0)
	assert_eq(battery.charge(), 0.0)


func test_a_refund_puts_it_back_up_to_capacity() -> void:
	var battery: HackBattery = _battery()
	battery.spend(20.0)
	battery.refund(20.0)
	assert_eq(battery.charge(), 50.0)
	battery.refund(500.0)
	assert_eq(battery.charge(), 100.0)


func test_quiet_hours_locks_it_for_a_while_and_keeps_the_charge() -> void:
	var battery: HackBattery = _battery()
	assert_false(battery.is_locked(0.0))
	battery.lock(5000.0, 1000.0)
	assert_true(battery.is_locked(1000.0))
	assert_true(battery.is_locked(5999.0))
	assert_false(battery.is_locked(6000.0))
	assert_eq(battery.lock_left_ms(2000.0), 4000.0)
	assert_eq(battery.lock_left_ms(7000.0), 0.0)
	assert_eq(battery.charge(), 50.0, "the charge is kept")


func test_a_shorter_lock_does_not_cut_a_longer_one() -> void:
	var battery: HackBattery = _battery()
	battery.lock(5000.0, 0.0)
	battery.lock(1000.0, 0.0)
	assert_eq(battery.lock_left_ms(0.0), 5000.0)


func test_unlock_ends_the_lock_at_once() -> void:
	var battery: HackBattery = _battery()
	battery.lock(5000.0, 0.0)
	battery.unlock()
	assert_false(battery.is_locked(1.0))


func test_reset_full_and_reset_start() -> void:
	var battery: HackBattery = _battery()
	battery.reset_full()
	assert_eq(battery.charge(), 100.0)
	battery.lock(1000.0, 0.0)
	battery.reset_start()
	assert_eq(battery.charge(), 50.0)
	assert_false(battery.is_locked(1.0), "a reset clears the jam too")


func test_set_charge_is_clamped() -> void:
	var battery: HackBattery = _battery()
	battery.set_charge(-5.0)
	assert_eq(battery.charge(), 0.0)
	battery.set_charge(250.0)
	assert_eq(battery.charge(), 100.0)
