extends TestCase
## EnemyBrain's new behaviours (enemy_ai_design): the defence roll, dodge and block, the guard hold, low health
## (flee, flank, enrage), repositioning, telegraph timing, retaliation and noticing. Everything is seeded, and the
## numbers are the real enemies.json. Where a chance is checked it is checked over many seeds with a tolerance.

const STEP: float = 16.0
const GRUNT: String = "grunt"
const BRUTE: String = "brute"


## A brain plus the clock and view that drive it.
class Driver extends RefCounted:
	var brain: EnemyBrain
	var now: float = 0.0
	var view: Dictionary = {}
	var last: Dictionary = {}
	var swing_id: int = 0

	func step(ms: float = 16.0) -> Dictionary:
		now += ms
		last = brain.step(now, view)
		return last

	func run(ms: float) -> Dictionary:
		var end: float = now + ms
		while now < end:
			step()
		return last

	func until_state(wanted: StringName, max_ms: float) -> bool:
		var end: float = now + max_ms
		while now < end:
			step()
			if brain.state() == wanted:
				return true
		return false

	## Red starts a swing; the brain gets up to `max_wait` ms to answer. Returns {defend, after_ms} or {}.
	func swing(move_class: StringName, threat: bool = true, max_wait: float = 400.0) -> Dictionary:
		swing_id += 1
		view["player_swing_id"] = swing_id
		view["player_move_class"] = move_class
		view["player_swing_threat"] = threat
		view["player_swing_active"] = true
		var started: float = now
		while now - started <= max_wait:
			var intent: Dictionary = step()
			if not (intent["defend"] as Dictionary).is_empty():
				return {"defend": intent["defend"], "after_ms": now - started}
		return {}


func _make(enemy: String, rng_seed: int = 1, defend_patch: Dictionary = {}, reactions_patch: Dictionary = {}) -> EnemyBrain:
	var all: Dictionary = CombatData.enemies()
	var data: Dictionary = ((all["enemies"] as Dictionary)[enemy] as Dictionary).duplicate(true)
	data["gaits"] = {"strafe": 1.5, "retreat": 3.4, "flee": 4.6}
	data["telegraph_rules"] = all["telegraph_rules"]
	if not defend_patch.is_empty():
		(data["behaviour"]["defend"] as Dictionary).merge(defend_patch, true)
	if not reactions_patch.is_empty():
		(data["behaviour"]["reactions"] as Dictionary).merge(reactions_patch, true)
	return EnemyBrain.create(data, rng_seed)


func _view(extra: Dictionary = {}) -> Dictionary:
	var view: Dictionary = {"dist_to_player": 4.0, "player_airborne": false, "player_attacking": false, "has_token": false,
		"state": &"free", "poise_frac": 1.0, "attacks_enabled": false, "hp_frac": 1.0, "my_angle_deg": 20.0, "in_rear_arc": false,
		"crowd_count": 0, "allies_near": 0, "allies": [], "flankers_other": 0, "player_swing_id": 0, "player_swing_threat": false,
		"player_swing_active": true, "player_move_class": &"", "player_combo_len": 0, "player_dashing_toward": false,
		"flare": false, "cornered": false, "knobs": {}}
	view.merge(extra, true)
	return view


## A brain that has noticed, approached and is circling at `dist`.
func _circling(enemy: String, rng_seed: int, view_extra: Dictionary = {}, defend_patch: Dictionary = {}) -> Driver:
	var driver: Driver = Driver.new()
	driver.brain = _make(enemy, rng_seed, defend_patch)
	driver.view = _view(view_extra)
	assert_true(driver.until_state(EnemyBrain.CIRCLE, 3000.0), "reaches the circle")
	return driver


func _fraction(count: int, total: int) -> float:
	return float(count) / float(total)


# ---- the defence roll ----

func test_the_roll_comes_after_the_reaction_time() -> void:
	var seen: Array[float] = []
	for rng_seed: int in range(1, 200):
		var driver: Driver = _circling(GRUNT, rng_seed, {}, {"dodge_chance": 1.0, "block_chance": 0.0})
		var answer: Dictionary = driver.swing(&"heavy")
		if not answer.is_empty():
			seen.append(float(answer["after_ms"]))
	assert_gt(float(seen.size()), 20.0, "it does answer")
	for after: float in seen:
		assert_ge(after, 80.0 - 1.0, "never before 80 ms")
		assert_le(after, 150.0 + STEP * 2.0, "never after 150 ms (plus the step grid)")
	assert_lt(seen.min(), 125.0, "some are quick")
	assert_gt(seen.max(), 140.0, "and some are slow: it varies")


func test_the_reaction_slider_slows_the_roll() -> void:
	var slow: Driver = _circling(GRUNT, 3, {"knobs": {"enemy_reaction_scale": 2.0}}, {"dodge_chance": 1.0, "block_chance": 0.0})
	var answer: Dictionary = slow.swing(&"heavy", true, 600.0)
	assert_false(answer.is_empty())
	assert_ge(float(answer["after_ms"]), 160.0 - 1.0, "twice the 80 ms minimum")


func test_no_roll_when_red_is_not_threatening_it() -> void:
	var defended: int = 0
	for rng_seed: int in range(1, 200):
		var driver: Driver = _circling(GRUNT, rng_seed, {}, {"dodge_chance": 1.0, "block_chance": 0.0})
		if not driver.swing(&"heavy", false).is_empty():
			defended += 1
	assert_eq(defended, 0, "outside the swing's zone there is no roll")


func test_a_swing_is_rolled_once() -> void:
	var driver: Driver = _circling(GRUNT, 4, {}, {"dodge_chance": 0.0, "block_chance": 0.0})
	driver.swing(&"heavy", true, 500.0)
	var extra: int = 0
	for i: int in range(40):
		if not (driver.step()["defend"] as Dictionary).is_empty():
			extra += 1
	assert_eq(extra, 0, "the same swing id never rolls again")


func test_the_grunt_dodges_sometimes_but_not_always() -> void:
	var table: Dictionary = {&"light": 0.18, &"heavy": 0.30, &"launcher": 0.24, &"air": 0.12}
	for move_class: StringName in table:
		var dodges: int = 0
		var runs: int = 400
		for rng_seed: int in range(1, runs + 1):
			var driver: Driver = _circling(GRUNT, rng_seed)
			var answer: Dictionary = driver.swing(move_class)
			if not answer.is_empty() and answer["defend"]["kind"] == &"dodge":
				dodges += 1
		assert_almost_eq(_fraction(dodges, runs), float(table[move_class]), 0.07, "dodges %s" % move_class)
		assert_gt(float(dodges), 0.0)
		assert_lt(float(dodges), float(runs) * 0.6)


func test_the_brute_blocks_lights_more_than_heavies_and_never_dodges() -> void:
	var blocks: Dictionary = {&"light": 0, &"heavy": 0}
	var dodges: int = 0
	var runs: int = 400
	for rng_seed: int in range(1, runs + 1):
		for move_class: StringName in [&"light", &"heavy"]:
			var driver: Driver = _circling(BRUTE, rng_seed * 7)
			var answer: Dictionary = driver.swing(move_class, true, 600.0)
			if not answer.is_empty():
				if answer["defend"]["kind"] == &"block":
					blocks[move_class] += 1
				else:
					dodges += 1
	assert_eq(dodges, 0)
	assert_almost_eq(_fraction(blocks[&"light"], runs), 0.45, 0.08)
	assert_almost_eq(_fraction(blocks[&"heavy"], runs), 0.225, 0.07)


func test_no_defence_while_in_hit_stun_a_flare_or_mid_attack() -> void:
	var count: int = 0
	for rng_seed: int in range(1, 120):
		# in hit-stun: the body is busy
		var stunned: Driver = _circling(GRUNT, rng_seed, {}, {"dodge_chance": 1.0, "block_chance": 0.0})
		stunned.view["state"] = &"busy"
		if not stunned.swing(&"heavy").is_empty():
			count += 1
		# a Lamp Flare is running
		var flared: Driver = _circling(GRUNT, rng_seed, {}, {"dodge_chance": 1.0, "block_chance": 0.0})
		flared.view["flare"] = true
		if not flared.swing(&"heavy").is_empty():
			count += 1
		# its own wind-up has begun
		var attacking: Driver = _circling(GRUNT, rng_seed, {"attacks_enabled": true, "has_token": true, "dist_to_player": 1.8}, {"dodge_chance": 1.0, "block_chance": 0.0})
		assert_true(attacking.until_state(EnemyBrain.ATTACK, 5000.0), "it attacks")
		if not attacking.swing(&"heavy").is_empty():
			count += 1
		# just got hit
		var reacting: Driver = _circling(GRUNT, rng_seed, {}, {"dodge_chance": 1.0, "block_chance": 0.0})
		reacting.brain.notify(&"hit")
		reacting.view["state"] = &"busy"
		if not reacting.swing(&"heavy").is_empty():
			count += 1
	assert_eq(count, 0)


func test_after_a_defence_it_cannot_do_the_same_one_again_for_the_cooldown() -> void:
	var checked: int = 0
	for rng_seed: int in range(1, 60):
		var driver: Driver = _circling(GRUNT, rng_seed, {}, {"dodge_chance": 1.0, "block_chance": 0.0, "fatigue_per_defence": 0.0})
		var first: Dictionary = driver.swing(&"heavy")
		if first.is_empty():
			continue
		driver.run(300.0)
		driver.brain.notify(&"defence_finished")
		driver.run(200.0)
		assert_true(driver.brain.state() == EnemyBrain.CIRCLE or driver.brain.state() == EnemyBrain.REPOSITION)
		assert_true(driver.swing(&"heavy").is_empty(), "inside the 2.5 s dodge cooldown")
		driver.run(2600.0)
		assert_false(driver.swing(&"heavy").is_empty(), "after it, it can dodge again")
		checked += 1
	assert_gt(float(checked), 30.0)


func test_fatigue_makes_a_second_defence_rarer() -> void:
	var first: int = 0
	var second: int = 0
	var runs: int = 400
	for rng_seed: int in range(1, runs + 1):
		var driver: Driver = _circling(GRUNT, rng_seed, {}, {"dodge_cooldown_ms": 0, "block_cooldown_ms": 0})
		var a: Dictionary = driver.swing(&"heavy")
		if a.is_empty():
			continue
		first += 1
		driver.run(300.0)
		driver.brain.notify(&"defence_finished")
		driver.run(200.0)
		if not driver.swing(&"heavy").is_empty():
			second += 1
	assert_gt(float(first), 80.0)
	assert_lt(_fraction(second, first), 0.30, "after one defence it has used up much of its nerve")


func test_dodges_are_side_steps_unless_red_is_very_close() -> void:
	var back_far: int = 0
	var back_near: int = 0
	var dodges: int = 0
	for rng_seed: int in range(1, 200):
		var far: Driver = _circling(GRUNT, rng_seed, {"dist_to_player": 3.0}, {"dodge_chance": 1.0, "block_chance": 0.0})
		var far_answer: Dictionary = far.swing(&"heavy")
		if not far_answer.is_empty() and far_answer["defend"]["variant"] == &"back":
			back_far += 1
		var near: Driver = _circling(GRUNT, rng_seed, {"dist_to_player": 4.0}, {"dodge_chance": 1.0, "block_chance": 0.0})
		near.view["dist_to_player"] = 1.2
		var near_answer: Dictionary = near.swing(&"heavy")
		if not near_answer.is_empty():
			dodges += 1
			if near_answer["defend"]["variant"] == &"back":
				back_near += 1
	assert_eq(back_far, 0)
	assert_almost_eq(_fraction(back_near, dodges), 0.30, 0.10)


func test_the_sliders_turn_dodging_and_blocking_off() -> void:
	for rng_seed: int in range(1, 100):
		var no_dodge: Driver = _circling(GRUNT, rng_seed, {"knobs": {"enemy_dodge_scale": 0.0}}, {"dodge_chance": 1.0, "block_chance": 0.0})
		assert_true(no_dodge.swing(&"heavy").is_empty())
		var no_block: Driver = _circling(BRUTE, rng_seed, {"knobs": {"enemy_block_scale": 0.0}}, {"block_chance": 1.0})
		assert_true(no_block.swing(&"light", true, 600.0).is_empty())


func test_a_dodge_intent_is_sent_once_and_the_brain_waits_in_defend() -> void:
	var driver: Driver = _circling(GRUNT, 5, {}, {"dodge_chance": 1.0, "block_chance": 0.0})
	var answer: Dictionary = driver.swing(&"heavy")
	assert_eq(answer["defend"]["kind"], &"dodge")
	assert_eq(driver.brain.state(), EnemyBrain.DEFEND)
	assert_false(driver.brain.is_fleeing())
	for i: int in range(20):
		assert_true((driver.step()["defend"] as Dictionary).is_empty(), "only one defend intent")
	assert_false(driver.last["want_token"], "a defending enemy holds no token")
	driver.brain.notify(&"defence_finished")
	driver.step()
	assert_eq(driver.brain.state(), EnemyBrain.CIRCLE)


func test_a_dodge_is_sometimes_followed_by_a_counter_swipe() -> void:
	var counters: int = 0
	var runs: int = 400
	for rng_seed: int in range(1, runs + 1):
		var driver: Driver = _circling(GRUNT, rng_seed, {"attacks_enabled": true}, {"dodge_chance": 1.0, "block_chance": 0.0})
		if driver.swing(&"heavy").is_empty():
			continue
		driver.run(300.0)
		driver.brain.notify(&"defence_finished")
		if driver.step()["want_token"]:
			counters += 1
	assert_almost_eq(_fraction(counters, runs), 0.25, 0.07, "25% take the next token at once")


func test_combo_escape_after_three_hits_in_a_gap() -> void:
	var escapes: int = 0
	var runs: int = 400
	for rng_seed: int in range(1, runs + 1):
		var driver: Driver = _circling(GRUNT, rng_seed)
		for i: int in range(3):
			driver.view["state"] = &"busy"
			driver.brain.notify(&"hit")
			driver.run(300.0)
		driver.view["state"] = &"free"        # the hit-stun ended: she left a gap
		var intent: Dictionary = driver.step()
		if not (intent["defend"] as Dictionary).is_empty():
			assert_eq(intent["defend"]["kind"], &"dodge")
			escapes += 1
	assert_almost_eq(_fraction(escapes, runs), 0.5, 0.08, "50% dodge out")


func test_a_tight_string_cannot_be_escaped() -> void:
	var escapes: int = 0
	for rng_seed: int in range(1, 200):
		var driver: Driver = _circling(GRUNT, rng_seed)
		for i: int in range(4):
			driver.view["state"] = &"busy"
			driver.brain.notify(&"hit")
			driver.run(300.0)
		driver.view["state"] = &"busy"       # still in hit-stun: she hit again
		if not (driver.step()["defend"] as Dictionary).is_empty():
			escapes += 1
	assert_eq(escapes, 0)


func test_two_hits_or_slow_hits_do_not_trigger_the_escape() -> void:
	for rng_seed: int in range(1, 120):
		var two: Driver = _circling(GRUNT, rng_seed)
		for i: int in range(2):
			two.view["state"] = &"busy"
			two.brain.notify(&"hit")
			two.run(300.0)
		two.view["state"] = &"free"
		assert_true((two.step()["defend"] as Dictionary).is_empty(), "two hits are not a combo")
		var slow: Driver = _circling(GRUNT, rng_seed)
		for i: int in range(3):
			slow.view["state"] = &"busy"
			slow.brain.notify(&"hit")
			slow.run(1500.0)         # 3 hits spread over 4.5 s
		slow.view["state"] = &"free"
		assert_true((slow.step()["defend"] as Dictionary).is_empty(), "outside the 2.5 s window")


func test_the_brute_never_escapes_a_combo() -> void:
	for rng_seed: int in range(1, 100):
		var driver: Driver = _circling(BRUTE, rng_seed)
		for i: int in range(5):
			driver.view["state"] = &"busy"
			driver.brain.notify(&"staggered")
			driver.run(300.0)
		driver.view["state"] = &"free"
		assert_true((driver.step()["defend"] as Dictionary).is_empty())


# ---- block and guard ----

func _blocking(rng_seed: int = 1, enemy: String = BRUTE) -> Driver:
	var driver: Driver = _circling(enemy, rng_seed, {}, {"block_chance": 1.0, "dodge_chance": 0.0, "read_weight": {"light": 1.0, "heavy": 1.0, "launcher": 1.0, "air": 1.0}})
	var answer: Dictionary = driver.swing(&"light", true, 700.0)
	assert_false(answer.is_empty(), "it blocks")
	assert_eq(answer["defend"]["kind"], &"block")
	return driver


func test_a_block_keeps_the_guard_up_while_red_threatens_and_drops_after_a_quiet_moment() -> void:
	var driver: Driver = _blocking()
	var up_since: float = driver.now
	assert_true(driver.last["guard"])
	driver.run(500.0)
	assert_true(driver.last["guard"], "Brute's minimum hold is 600 ms")
	driver.view["player_swing_active"] = false           # Red stopped swinging
	var dropped_at: float = -1.0
	while driver.now - up_since < 2000.0 and dropped_at < 0.0:
		if not driver.step()["guard"]:
			dropped_at = driver.now - up_since
	assert_gt(dropped_at, 590.0, "held at least 600 ms")
	assert_lt(dropped_at, 1000.0, "and let go once Red had been quiet for 300 ms")


func test_a_block_never_lasts_past_the_hold_maximum() -> void:
	var driver: Driver = _blocking(2)
	var up_since: float = driver.now
	# Red keeps threatening the whole time
	var dropped_at: float = -1.0
	while driver.now - up_since < 3000.0 and dropped_at < 0.0:
		driver.view["player_swing_threat"] = true
		driver.view["player_swing_active"] = true
		if not driver.step()["guard"]:
			dropped_at = driver.now - up_since
	assert_gt(dropped_at, 0.0)
	assert_le(dropped_at, 1200.0 + STEP * 2.0, "1200 ms is the Brute's longest hold")


func test_the_guard_drops_after_two_blocks_for_the_grunt_and_three_for_the_brute() -> void:
	var grunt: Driver = _blocking(3, GRUNT)
	grunt.view["player_swing_threat"] = true
	grunt.brain.notify(&"blocked")
	grunt.step()
	assert_true(grunt.last["guard"], "one block: still up")
	grunt.brain.notify(&"blocked")
	grunt.step()
	assert_false(grunt.last["guard"], "two blocks: the Grunt's guard drops")
	var brute: Driver = _blocking(3, BRUTE)
	brute.view["player_swing_threat"] = true
	for i: int in range(2):
		brute.brain.notify(&"blocked")
		brute.step()
	assert_true(brute.last["guard"])
	brute.brain.notify(&"blocked")
	brute.step()
	assert_false(brute.last["guard"], "three blocks: the Brute's guard drops")


func test_a_guard_break_sends_the_brain_to_react_and_starts_the_cooldown() -> void:
	var driver: Driver = _blocking(4)
	driver.brain.notify(&"guard_broken")
	driver.view["state"] = &"busy"
	driver.step()
	assert_eq(driver.brain.state(), EnemyBrain.REACT)
	assert_false(driver.brain.defence().ready(EnemyDefence.KIND_BLOCK, driver.now), "block cooldown running")


func test_the_brute_sometimes_answers_a_successful_block_with_a_slam() -> void:
	var answers: int = 0
	var runs: int = 400
	for rng_seed: int in range(1, runs + 1):
		var driver: Driver = _circling(BRUTE, rng_seed, {"attacks_enabled": true}, {"block_chance": 1.0, "dodge_chance": 0.0, "read_weight": {"light": 1.0}})
		if driver.swing(&"light", true, 700.0).is_empty():
			continue
		driver.brain.notify(&"blocked")
		driver.brain.notify(&"defence_finished")
		if driver.step()["want_token"]:
			answers += 1
	assert_almost_eq(_fraction(answers, runs), 0.45, 0.08)


func test_a_block_that_took_no_hit_earns_no_counter() -> void:
	var answers: int = 0
	for rng_seed: int in range(1, 200):
		var driver: Driver = _circling(BRUTE, rng_seed, {"attacks_enabled": true}, {"block_chance": 1.0, "dodge_chance": 0.0, "read_weight": {"light": 1.0}})
		if driver.swing(&"light", true, 700.0).is_empty():
			continue
		driver.brain.notify(&"defence_finished")
		if driver.step()["want_token"]:
			answers += 1
	assert_eq(answers, 0)


# ---- low health: the Grunt ----

func _low_health_choice(rng_seed: int, view_extra: Dictionary) -> StringName:
	var driver: Driver = _circling(GRUNT, rng_seed, view_extra)
	driver.view["hp_frac"] = 0.3
	driver.step()
	return driver.brain.state()


func test_a_wounded_grunt_alone_flees_70_percent_of_the_time_otherwise_flanks() -> void:
	var flee: int = 0
	var flank: int = 0
	var runs: int = 400
	for rng_seed: int in range(1, runs + 1):
		var state: StringName = _low_health_choice(rng_seed, {"attacks_enabled": true})
		if state == EnemyBrain.FLEE:
			flee += 1
		elif state == EnemyBrain.FLANK:
			flank += 1
	assert_almost_eq(_fraction(flee, runs), 0.70, 0.07)
	assert_eq(flee + flank, runs, "it always does one or the other")


func test_with_two_allies_close_by_it_flanks_70_percent_of_the_time() -> void:
	var flank: int = 0
	var runs: int = 400
	for rng_seed: int in range(1, runs + 1):
		if _low_health_choice(rng_seed, {"attacks_enabled": true, "allies_near": 2}) == EnemyBrain.FLANK:
			flank += 1
	assert_almost_eq(_fraction(flank, runs), 0.70, 0.07)


func test_it_does_not_run_while_it_is_healthy() -> void:
	for rng_seed: int in range(1, 60):
		var driver: Driver = _circling(GRUNT, rng_seed, {"attacks_enabled": true})
		driver.view["hp_frac"] = 0.41
		driver.run(500.0)
		assert_ne(driver.brain.state(), EnemyBrain.FLEE)
		assert_ne(driver.brain.state(), EnemyBrain.FLANK)


func test_dead_allies_raise_the_threshold_up_to_16_percent() -> void:
	var driver: Driver = _circling(GRUNT, 9, {"attacks_enabled": true})
	driver.view["hp_frac"] = 0.50
	driver.run(300.0)
	assert_ne(driver.brain.state(), EnemyBrain.FLEE)
	assert_ne(driver.brain.state(), EnemyBrain.FLANK)
	driver.brain.notify(&"ally_died")
	driver.run(100.0)
	assert_ne(driver.brain.state(), EnemyBrain.FLEE, "one death: the threshold is 48%, hp is 50%")
	driver.brain.notify(&"ally_died")
	driver.step()
	assert_true(driver.brain.state() == EnemyBrain.FLEE or driver.brain.state() == EnemyBrain.FLANK, "two deaths: 56%")
	var calm: Driver = _circling(GRUNT, 9, {"attacks_enabled": true})
	calm.view["hp_frac"] = 0.50
	calm.brain.notify(&"ally_died")
	calm.run(7000.0)
	calm.brain.notify(&"ally_died")
	calm.run(100.0)
	assert_ne(calm.brain.state(), EnemyBrain.FLEE, "a death long ago no longer counts")
	var many: Driver = _circling(GRUNT, 9, {"attacks_enabled": true})
	many.view["hp_frac"] = 0.58
	for i: int in range(5):
		many.brain.notify(&"ally_died")
	many.run(200.0)
	assert_ne(many.brain.state(), EnemyBrain.FLEE, "capped at +16%: 56%")


func _fleeing(rng_seed_start: int = 1) -> Driver:
	for rng_seed: int in range(rng_seed_start, rng_seed_start + 200):
		var driver: Driver = _circling(GRUNT, rng_seed, {"attacks_enabled": false})
		driver.view["hp_frac"] = 0.3
		driver.step()
		if driver.brain.state() == EnemyBrain.FLEE:
			return driver
	fail("no seed fled")
	return null


func test_fleeing_runs_away_at_4_6_and_holds_no_token() -> void:
	var driver: Driver = _fleeing()
	var intent: Dictionary = driver.step()
	assert_lt((intent["move_dir"] as Vector3).z, 0.0, "away from Red")
	assert_almost_eq(float(intent["speed_mps"]), 4.6, 0.001)
	assert_false(intent["want_token"], "a fleeing enemy gives its token back")
	assert_false(intent["face_player"])
	assert_true(intent["face_move"])
	assert_true(driver.brain.is_fleeing())
	assert_eq(intent["gait"], &"flee")


func test_fleeing_ends_at_9_metres_or_after_3_5_seconds() -> void:
	var far: Driver = _fleeing()
	far.view["dist_to_player"] = 8.5
	far.run(200.0)
	assert_true(far.brain.is_fleeing())
	far.view["dist_to_player"] = 9.1
	far.step()
	assert_false(far.brain.is_fleeing())
	assert_eq(far.brain.state(), EnemyBrain.CIRCLE, "it comes back")
	var slow: Driver = _fleeing(300)
	slow.view["dist_to_player"] = 5.0
	slow.run(3400.0)
	assert_true(slow.brain.is_fleeing())
	slow.run(200.0)
	assert_false(slow.brain.is_fleeing(), "3.5 s is the longest run")


func test_after_a_flee_it_is_bold_for_6_seconds_and_flees_at_most_twice() -> void:
	var driver: Driver = _fleeing(1)
	driver.view["dist_to_player"] = 9.5
	driver.step()
	assert_false(driver.brain.is_fleeing())
	driver.view["dist_to_player"] = 4.0
	driver.run(5000.0)
	assert_false(driver.brain.is_fleeing(), "bold: no fleeing for 6 s")
	assert_ne(driver.brain.state(), EnemyBrain.FLANK, "and no new plan either")
	var flees: int = 1
	for round: int in range(6):
		driver.run(6500.0)        # the bold time is over
		if driver.brain.is_fleeing():
			flees += 1
			driver.view["dist_to_player"] = 9.5
			driver.step()
			driver.view["dist_to_player"] = 4.0
		elif driver.brain.state() == EnemyBrain.FLANK:
			driver.view["dist_to_player"] = 4.0
			driver.run(3600.0)         # gives up
	assert_le(flees, 2, "a life holds at most 2 flees")


func test_a_hit_while_fleeing_ends_the_run_and_the_resolver_will_knock_it_down() -> void:
	var driver: Driver = _fleeing()
	assert_true(driver.brain.is_fleeing(), "snapshot flee_knockdown is true now")
	driver.brain.notify(&"hit")
	driver.view["state"] = &"busy"
	driver.step()
	assert_false(driver.brain.is_fleeing())
	assert_eq(driver.brain.state(), EnemyBrain.REACT)


func test_cornered_for_600_ms_it_turns_and_swipes_with_a_token() -> void:
	var driver: Driver = _fleeing()
	driver.view["cornered"] = true
	driver.view["attacks_enabled"] = true
	driver.run(400.0)
	assert_true(driver.brain.is_fleeing())
	assert_false(driver.last["want_token"], "not yet")
	driver.run(300.0)
	assert_true(driver.last["want_token"], "cornered for 0.6 s: it asks to fight")
	assert_true(driver.brain.is_fleeing(), "still no attack without a token")
	driver.view["has_token"] = true
	var intent: Dictionary = driver.step()
	assert_eq(intent["start_move"], &"swipe")
	assert_eq(driver.brain.state(), EnemyBrain.ATTACK)


func test_the_flee_and_flank_switches_in_the_feel_panel() -> void:
	var flees_off: int = 0
	var flanks_off: int = 0
	var both_off: int = 0
	for rng_seed: int in range(1, 150):
		if _low_health_choice(rng_seed, {"attacks_enabled": true, "knobs": {"enemy_flee_on": false}}) == EnemyBrain.FLEE:
			flees_off += 1
		if _low_health_choice(rng_seed, {"attacks_enabled": true, "knobs": {"enemy_flank_on": false}}) == EnemyBrain.FLANK:
			flanks_off += 1
		var state: StringName = _low_health_choice(rng_seed, {"attacks_enabled": true, "knobs": {"enemy_flee_on": false, "enemy_flank_on": false}})
		if state == EnemyBrain.FLEE or state == EnemyBrain.FLANK:
			both_off += 1
	assert_eq(flees_off, 0)
	assert_eq(flanks_off, 0)
	assert_eq(both_off, 0, "fights on to the end")


func _flanking(rng_seed_start: int = 1) -> Driver:
	for rng_seed: int in range(rng_seed_start, rng_seed_start + 200):
		var driver: Driver = _circling(GRUNT, rng_seed, {"attacks_enabled": true})
		driver.view["hp_frac"] = 0.3
		driver.step()
		if driver.brain.state() == EnemyBrain.FLANK:
			return driver
	fail("no seed flanked")
	return null


func test_a_flanker_runs_round_to_red_s_back_the_short_way() -> void:
	var driver: Driver = _flanking()
	driver.view["my_angle_deg"] = 40.0
	driver.view["dist_to_player"] = 4.5
	var intent: Dictionary = driver.step()
	assert_gt((intent["move_dir"] as Vector3).x, 0.3, "round to the side it is already on (raising the angle)")
	assert_eq(intent["gait"], &"stalk")
	assert_almost_eq(float(intent["speed_mult"]), 1.3, 0.001)
	assert_false(intent["want_token"])
	driver.view["my_angle_deg"] = -60.0
	intent = driver.step()
	assert_lt((intent["move_dir"] as Vector3).x, -0.3, "the other side: lowering the angle, since its side was fixed when it chose")
	assert_true(intent["face_player"], "it keeps its eyes on Red while it stalks")


func test_a_flanker_holds_600_ms_then_asks_for_a_token_with_the_flank_bonus() -> void:
	var driver: Driver = _flanking(1)
	driver.view["my_angle_deg"] = 160.0
	driver.view["dist_to_player"] = 3.6
	var started: float = driver.now
	var asked_at: float = -1.0
	while driver.now - started < 1500.0 and asked_at < 0.0:
		var intent: Dictionary = driver.step()
		if intent["want_token"]:
			asked_at = driver.now - started
			assert_true(intent["flank"], "it queues as a flanker")
	assert_gt(asked_at, 590.0, "the 600 ms pause is the warning")
	assert_lt(asked_at, 680.0)
	driver.view["has_token"] = true
	var attack: Dictionary = driver.step()
	assert_eq(attack["start_move"], &"swipe_flank")
	assert_eq(driver.brain.state(), EnemyBrain.ATTACK)
	assert_true(driver.brain.is_flanking(), "still the flanker while it swings")


func test_leaving_the_rear_arc_resets_the_hold() -> void:
	var driver: Driver = _flanking(1)
	driver.view["my_angle_deg"] = 160.0
	driver.view["dist_to_player"] = 3.6
	driver.run(400.0)
	driver.view["my_angle_deg"] = 60.0         # Red turned round
	driver.run(100.0)
	driver.view["my_angle_deg"] = 160.0
	var intent: Dictionary = driver.run(300.0)
	assert_false(intent["want_token"], "the hold started again")
	intent = driver.run(400.0)
	assert_true(intent["want_token"])


func test_a_flanker_gives_up_after_3_5_seconds() -> void:
	var driver: Driver = _flanking(1)
	driver.view["my_angle_deg"] = 60.0         # it never gets there
	driver.run(3400.0)
	assert_true(driver.brain.is_flanking())
	driver.run(300.0)
	assert_false(driver.brain.is_flanking())
	assert_eq(driver.brain.state(), EnemyBrain.CIRCLE)


func test_only_one_flanker_at_a_time() -> void:
	for rng_seed: int in range(1, 100):
		var driver: Driver = _circling(GRUNT, rng_seed, {"attacks_enabled": true, "flankers_other": 1})
		driver.view["hp_frac"] = 0.3
		driver.run(200.0)
		assert_ne(driver.brain.state(), EnemyBrain.FLANK)


func test_flanking_needs_attacks_to_be_on() -> void:
	for rng_seed: int in range(1, 60):
		var driver: Driver = _circling(GRUNT, rng_seed, {"attacks_enabled": false})
		driver.view["hp_frac"] = 0.3
		driver.run(200.0)
		assert_ne(driver.brain.state(), EnemyBrain.FLANK)


# ---- low health: the Brute ----

func _enraging(rng_seed: int = 1) -> Driver:
	var driver: Driver = _circling(BRUTE, rng_seed, {"attacks_enabled": true})
	driver.view["hp_frac"] = 0.3
	return driver


func test_the_brute_roars_once_under_35_percent() -> void:
	var healthy: Driver = _circling(BRUTE, 1, {"attacks_enabled": true})
	healthy.view["hp_frac"] = 0.36
	healthy.run(300.0)
	assert_ne(healthy.brain.state(), EnemyBrain.ENRAGE)
	var driver: Driver = _enraging()
	var intent: Dictionary = driver.step()
	assert_eq(driver.brain.state(), EnemyBrain.ENRAGE)
	assert_eq(intent["start_move"], &"enrage", "the roar is a move")
	assert_false(driver.brain.is_enraged(), "the buffs come when the roar ends")
	for i: int in range(10):
		assert_eq(driver.step()["start_move"], &"", "the roar starts once")
	driver.brain.notify(&"move_finished")
	assert_true(driver.brain.is_enraged())
	assert_eq(driver.brain.state(), EnemyBrain.CIRCLE)
	driver.view["hp_frac"] = 0.05
	driver.run(300.0)
	assert_ne(driver.brain.state(), EnemyBrain.ENRAGE, "once only")


func test_a_poise_break_cuts_the_roar_short_but_he_is_enraged_anyway() -> void:
	var driver: Driver = _enraging(2)
	driver.step()
	driver.brain.notify(&"staggered")
	assert_true(driver.brain.is_enraged())
	assert_eq(driver.brain.state(), EnemyBrain.REACT)


func test_enrage_buffs() -> void:
	var calm: Driver = _circling(BRUTE, 3, {"attacks_enabled": true})
	var driver: Driver = _enraging(3)
	driver.step()
	driver.brain.notify(&"move_finished")
	assert_almost_eq(driver.brain.damage_mult(), 1.15, 0.0001)
	assert_almost_eq(calm.brain.damage_mult(), 1.0, 0.0001)
	assert_false(driver.brain.poise_regen_allowed(), "no poise regeneration")
	assert_true(calm.brain.poise_regen_allowed())
	var intent: Dictionary = driver.step()
	driver.view["has_token"] = false
	intent = driver.run(100.0)
	assert_almost_eq(float(intent["speed_mult"]), 1.25, 0.0001, "1.25x speed")
	# a 35% shorter pause between attacks, on average
	var calm_total: float = 0.0
	var angry_total: float = 0.0
	for rng_seed: int in range(1, 80):
		calm_total += _first_ask_ms(_circling(BRUTE, rng_seed, {"attacks_enabled": true}))
		var angry: Driver = _enraging(rng_seed)
		angry.step()
		angry.brain.notify(&"move_finished")
		angry_total += _first_ask_ms(angry)
	assert_lt(angry_total, calm_total * 0.75, "enraged he waits about 35% less")


func _first_ask_ms(driver: Driver) -> float:
	driver.view["hp_frac"] = 1.0 if not driver.brain.is_enraged() else 0.3
	var started: float = driver.now
	while driver.now - started < 8000.0:
		if driver.step()["want_token"]:
			return driver.now - started
	return 8000.0


func test_the_enraged_brute_guards_60_percent_less() -> void:
	var calm_blocks: int = 0
	var angry_blocks: int = 0
	var runs: int = 400
	for rng_seed: int in range(1, runs + 1):
		var calm: Driver = _circling(BRUTE, rng_seed)
		if not calm.swing(&"light", true, 700.0).is_empty():
			calm_blocks += 1
		var angry: Driver = _circling(BRUTE, rng_seed)
		angry.view["hp_frac"] = 0.3
		angry.step()
		angry.brain.notify(&"move_finished")
		angry.view["attacks_enabled"] = false
		if not angry.swing(&"light", true, 700.0).is_empty():
			angry_blocks += 1
	assert_almost_eq(_fraction(calm_blocks, runs), 0.45, 0.08)
	assert_almost_eq(_fraction(angry_blocks, runs), 0.18, 0.07, "0.45 x 0.4")


func test_the_enraged_brute_chains_a_second_slam_half_the_time() -> void:
	var chained: int = 0
	var runs: int = 300
	for rng_seed: int in range(1, runs + 1):
		var driver: Driver = _enraging(rng_seed)
		driver.step()
		driver.brain.notify(&"move_finished")
		driver.view["dist_to_player"] = 2.5
		driver.view["has_token"] = true
		var started: bool = false
		for i: int in range(700):
			var intent: Dictionary = driver.step()
			if intent["start_move"] == &"slam":
				started = true
				if float(intent["chain_recover_ms"]) > 0.0:
					chained += 1
					assert_almost_eq(float(intent["chain_recover_ms"]), 350.0, 0.001)
					# the first slam ends: he keeps the token and slams again at once, without chaining again
					driver.brain.notify(&"move_finished")
					assert_true(driver.brain.keeps_token())
					var second: Dictionary = driver.step()
					assert_eq(second["start_move"], &"slam", "straight into the second wind-up")
					assert_almost_eq(float(second["chain_recover_ms"]), 0.0, 0.001, "two slams, not three")
				break
		assert_true(started)
	assert_almost_eq(_fraction(chained, runs), 0.5, 0.09)


func test_the_calm_brute_never_chains() -> void:
	for rng_seed: int in range(1, 60):
		var driver: Driver = _circling(BRUTE, rng_seed, {"attacks_enabled": true, "has_token": true, "dist_to_player": 2.5})
		for i: int in range(700):
			var intent: Dictionary = driver.step()
			if intent["start_move"] == &"slam":
				assert_almost_eq(float(intent["chain_recover_ms"]), 0.0, 0.001)
				break


func test_the_enrage_switch_in_the_feel_panel() -> void:
	var driver: Driver = _circling(BRUTE, 1, {"attacks_enabled": true, "knobs": {"enemy_enrage_on": false}})
	driver.view["hp_frac"] = 0.1
	driver.run(500.0)
	assert_ne(driver.brain.state(), EnemyBrain.ENRAGE)
	assert_false(driver.brain.is_enraged())


func test_the_brute_never_flees_or_flanks() -> void:
	for rng_seed: int in range(1, 60):
		var driver: Driver = _circling(BRUTE, rng_seed, {"attacks_enabled": true})
		driver.view["hp_frac"] = 0.02
		driver.run(2000.0)
		assert_false(driver.brain.is_fleeing())
		assert_false(driver.brain.is_flanking())


# ---- repositioning ----

func test_crowded_enemies_step_further_out() -> void:
	var driver: Driver = _circling(GRUNT, 1, {"dist_to_player": 4.3})
	assert_almost_eq((driver.step()["move_dir"] as Vector3).z, 0.0, 0.001, "4.3 m is inside the 3.2 to 5 m ring")
	assert_eq(driver.brain.state(), EnemyBrain.CIRCLE)
	driver.view["crowd_count"] = 2
	var intent: Dictionary = driver.step()
	assert_eq(driver.brain.state(), EnemyBrain.REPOSITION)
	assert_lt((intent["move_dir"] as Vector3).z, 0.0, "1.2 m further out: 4.4 m is the new inner edge")
	driver.view["crowd_count"] = 0
	driver.step()
	assert_eq(driver.brain.state(), EnemyBrain.CIRCLE)


func test_the_token_holder_does_not_back_off_and_the_brute_never_does() -> void:
	var holder: Driver = _circling(GRUNT, 1, {"dist_to_player": 4.3})
	holder.view["crowd_count"] = 3
	holder.view["has_token"] = true
	holder.step()
	assert_ne(holder.brain.state(), EnemyBrain.REPOSITION)
	var brute: Driver = _circling(BRUTE, 1, {"dist_to_player": 5.4})
	brute.view["crowd_count"] = 5
	brute.view["player_combo_len"] = 6
	brute.step()
	assert_ne(brute.brain.state(), EnemyBrain.REPOSITION)


func test_an_enemy_stays_out_of_the_way_while_red_strings_hits_on_another() -> void:
	var driver: Driver = _circling(GRUNT, 1, {"dist_to_player": 4.3})
	driver.view["player_combo_len"] = 2
	driver.step()
	assert_eq(driver.brain.state(), EnemyBrain.REPOSITION, "out of the sword's way")
	var target: Driver = _circling(GRUNT, 1, {"dist_to_player": 4.3})
	target.view["state"] = &"busy"
	target.brain.notify(&"hit")
	target.view["state"] = &"free"
	target.view["player_combo_len"] = 2
	target.run(500.0)
	assert_ne(target.brain.state(), EnemyBrain.REPOSITION, "the one being hit is the focus: no back-off")


func test_neighbours_push_each_other_apart() -> void:
	var driver: Driver = _circling(GRUNT, 1, {"dist_to_player": 4.0, "my_angle_deg": 10.0})
	driver.view["allies"] = [{"angle_deg": 5.0, "dist_m": 0.6}]
	var intent: Dictionary = driver.step()
	assert_gt((intent["move_dir"] as Vector3).x, 0.3, "the ally is at a lower angle: move the other way (higher)")
	driver.view["allies"] = [{"angle_deg": 15.0, "dist_m": 0.6}]
	intent = driver.step()
	assert_lt((intent["move_dir"] as Vector3).x, -0.3)
	driver.view["allies"] = [{"angle_deg": 120.0, "dist_m": 6.0}]
	intent = driver.step()
	assert_lt(absf((intent["move_dir"] as Vector3).x), 0.7, "a far ally changes nothing but the usual strafe")


func test_enemies_spread_round_red_not_just_apart() -> void:
	var driver: Driver = _circling(GRUNT, 1, {"dist_to_player": 4.0, "my_angle_deg": 30.0})
	driver.view["allies"] = [{"angle_deg": 50.0, "dist_m": 2.5}]
	var intent: Dictionary = driver.step()
	assert_lt((intent["move_dir"] as Vector3).x, -0.1, "20 degrees apart round Red is closer than the 70 degree spread")


func test_the_grunt_sometimes_fades_after_its_own_attack_and_the_brute_never() -> void:
	var faded: int = 0
	var runs: int = 300
	for rng_seed: int in range(1, runs + 1):
		var driver: Driver = _circling(GRUNT, rng_seed, {"attacks_enabled": true, "has_token": true, "dist_to_player": 1.8})
		assert_true(driver.until_state(EnemyBrain.ATTACK, 6000.0))
		driver.brain.notify(&"move_finished")
		driver.run(500.0)
		if driver.brain.state() == EnemyBrain.REPOSITION:
			faded += 1
			var intent: Dictionary = driver.step()
			assert_lt((intent["move_dir"] as Vector3).z, 0.0, "backpedals")
			assert_true(intent["face_player"], "facing Red")
			assert_eq(intent["gait"], &"retreat")
			driver.run(900.0)
			assert_ne(driver.brain.state(), EnemyBrain.REPOSITION, "2 m at 3.4 m/s is over in 0.6 s")
	assert_almost_eq(_fraction(faded, runs), 0.5, 0.08)
	for rng_seed: int in range(1, 60):
		var brute: Driver = _circling(BRUTE, rng_seed, {"attacks_enabled": true, "has_token": true, "dist_to_player": 2.5})
		assert_true(brute.until_state(EnemyBrain.ATTACK, 9000.0))
		brute.brain.notify(&"move_finished")
		brute.run(900.0)
		assert_ne(brute.brain.state(), EnemyBrain.REPOSITION, "he stands his ground")


func test_the_grunt_steps_away_from_a_charging_red_35_percent_of_the_time_once_per_3_seconds() -> void:
	var stepped: int = 0
	var runs: int = 400
	for rng_seed: int in range(1, runs + 1):
		var driver: Driver = _circling(GRUNT, rng_seed)
		driver.view["player_dashing_toward"] = true
		driver.step()
		if driver.brain.state() == EnemyBrain.REPOSITION:
			stepped += 1
			driver.run(900.0)
			driver.step()
			assert_ne(driver.brain.state(), EnemyBrain.REPOSITION)
			driver.step()
			assert_ne(driver.brain.state(), EnemyBrain.REPOSITION, "not again inside 3 s")
	assert_almost_eq(_fraction(stepped, runs), 0.35, 0.07)


# ---- telegraph timing ----

func _attacking_grunt(rear: bool, rng_seed: int = 1) -> Driver:
	var driver: Driver = _circling(GRUNT, rng_seed, {"attacks_enabled": true, "has_token": true, "dist_to_player": 1.8, "in_rear_arc": rear})
	var picked: StringName = &""
	var end: float = driver.now + 6000.0
	while driver.now < end and picked == &"":
		picked = driver.step()["start_move"]
	assert_ne(picked, &"", "it attacks")
	driver.view["picked"] = picked
	return driver


func test_from_behind_the_grunt_uses_the_longer_wind_up_move() -> void:
	var front: Driver = _attacking_grunt(false)
	assert_eq(front.view["picked"], &"swipe")
	var rear: Driver = _attacking_grunt(true)
	assert_eq(rear.view["picked"], &"swipe_flank", "710 ms, because she cannot see it coming")


func test_the_aim_locks_150_ms_before_impact_even_when_the_wind_up_is_stretched() -> void:
	var driver: Driver = _attacking_grunt(false)
	driver.brain.set_attack_timing(560.0, 1.0)
	var started: float = driver.now
	var locked_at: float = -1.0
	while driver.now - started < 800.0 and locked_at < 0.0:
		if not driver.step()["face_player"]:
			locked_at = driver.now - started
	assert_almost_eq(locked_at, 380.0, STEP * 1.5, "380 ms of a 560 ms wind-up")
	var slow: Driver = _attacking_grunt(false, 2)
	slow.brain.set_attack_timing(1120.0, 2.0)
	started = slow.now
	locked_at = -1.0
	while slow.now - started < 1500.0 and locked_at < 0.0:
		if not slow.step()["face_player"]:
			locked_at = slow.now - started
	assert_almost_eq(locked_at, 760.0, STEP * 1.5, "the lock stretches with the wind-up")
	var late: Driver = _attacking_grunt(false, 3)
	late.brain.set_attack_timing(300.0, 0.5)         # a hypothetical short wind-up
	started = late.now
	locked_at = -1.0
	while late.now - started < 500.0 and locked_at < 0.0:
		if not late.step()["face_player"]:
			locked_at = late.now - started
	assert_le(locked_at, 300.0 - 150.0 + STEP * 1.5, "never closer than 150 ms to impact")


func test_a_denied_attack_waits_a_moment_and_goes_back_to_circling() -> void:
	var driver: Driver = _attacking_grunt(false)
	assert_eq(driver.brain.state(), EnemyBrain.ATTACK)
	driver.brain.notify(&"attack_denied")
	var intent: Dictionary = driver.step()
	assert_eq(driver.brain.state(), EnemyBrain.CIRCLE)
	assert_eq(intent["start_move"], &"", "not again at once")
	assert_true(intent["want_token"], "it keeps its place")
	var again: StringName = &""
	for i: int in range(30):
		again = driver.step()["start_move"]
		if again != &"":
			break
	assert_eq(again, &"swipe", "and tries again a moment later")


# ---- retaliation, noticing ----

func test_after_a_flinch_the_grunt_may_hit_back_once_per_3_5_seconds() -> void:
	var counters: int = 0
	var runs: int = 600
	for rng_seed: int in range(1, runs + 1):
		var driver: Driver = _circling(GRUNT, rng_seed, {"attacks_enabled": true, "dist_to_player": 1.9})
		driver.view["state"] = &"busy"
		driver.brain.notify(&"hit")
		driver.run(300.0)
		driver.view["state"] = &"free"
		driver.run(600.0)
		if driver.last["want_token"]:
			counters += 1
	assert_almost_eq(_fraction(counters, runs), 0.15, 0.06)
	var far: int = 0
	for rng_seed: int in range(1, 200):
		var driver_far: Driver = _circling(GRUNT, rng_seed, {"attacks_enabled": true, "dist_to_player": 3.0})
		driver_far.view["state"] = &"busy"
		driver_far.brain.notify(&"hit")
		driver_far.run(300.0)
		driver_far.view["state"] = &"free"
		driver_far.run(600.0)
		if driver_far.last["want_token"]:
			far += 1
	assert_eq(far, 0, "only when Red is within 2.1 m")


func test_the_armored_brute_answers_a_hit_35_percent_of_the_time_when_red_is_close() -> void:
	var answers: int = 0
	var runs: int = 500
	for rng_seed: int in range(1, runs + 1):
		var driver: Driver = _circling(BRUTE, rng_seed, {"attacks_enabled": true, "dist_to_player": 2.4})
		driver.brain.notify(&"armored_hit")
		if driver.step()["want_token"]:
			answers += 1
	assert_almost_eq(_fraction(answers, runs), 0.35, 0.07)


func test_retaliation_is_rolled_once_per_3_5_seconds() -> void:
	var driver: Driver = Driver.new()
	driver.brain = _make(BRUTE, 1, {}, {"retaliate_chance": 1.0})
	driver.view = _view({"attacks_enabled": true, "dist_to_player": 2.4})
	assert_true(driver.until_state(EnemyBrain.CIRCLE, 3000.0))
	driver.brain.notify(&"armored_hit")
	assert_true(driver.step()["want_token"], "a sure thing answers at once")
	driver.view["has_token"] = true
	assert_true(driver.until_state(EnemyBrain.ATTACK, 2000.0))
	driver.brain.notify(&"move_finished")
	driver.view["has_token"] = false
	driver.run(1000.0)                  # recovery is over, the next pause between attacks is running
	driver.brain.notify(&"armored_hit")
	assert_false(driver.step()["want_token"], "1.5 s after the last answer: too soon to answer again")
	driver.run(2600.0)
	driver.brain.notify(&"armored_hit")
	driver.view["has_token"] = false
	assert_true(driver.step()["want_token"], "4 s after the last answer it may answer again")


func test_a_hit_ally_wakes_an_idle_enemy_faster() -> void:
	var alerted: Driver = Driver.new()
	alerted.brain = _make(GRUNT, 1)
	alerted.view = _view({"dist_to_player": 12.0})
	alerted.step()
	alerted.brain.notify(&"ally_alert")
	assert_true(alerted.until_state(EnemyBrain.APPROACH, 400.0), "noticed within 150 ms")
	var calm: Driver = Driver.new()
	calm.brain = _make(GRUNT, 1)
	calm.view = _view({"dist_to_player": 40.0})
	calm.step()
	calm.brain.notify(&"ally_alert")
	assert_eq(calm.brain.state(), EnemyBrain.NOTICE, "an ally in trouble makes it look up even from far away")
	var brute: Driver = Driver.new()
	brute.brain = _make(BRUTE, 1)
	brute.view = _view({"dist_to_player": 12.0})
	brute.step()
	brute.brain.notify(&"ally_died")
	var started: float = brute.now
	assert_true(brute.until_state(EnemyBrain.APPROACH, 800.0))
	assert_ge(brute.now - started, 300.0, "the Brute takes 350 ms")


func test_getting_up_from_a_knockdown_rolls_away_25_percent_for_the_grunt_only() -> void:
	var rolls: int = 0
	for rng_seed: int in range(1, 401):
		if _make(GRUNT, rng_seed).roll_getup_roll():
			rolls += 1
	assert_almost_eq(_fraction(rolls, 400), 0.25, 0.07)
	for rng_seed: int in range(1, 100):
		assert_false(_make(BRUTE, rng_seed).roll_getup_roll())


func test_the_step_up_event_brings_the_next_attack_forward() -> void:
	var driver: Driver = _circling(BRUTE, 1, {"attacks_enabled": true})
	var far_future: float = 0.0
	for i: int in range(3):
		driver.step()
	driver.brain.notify(&"step_up")
	var started: float = driver.now
	var asked: float = -1.0
	while driver.now - started < 1600.0 and asked < 0.0:
		if driver.step()["want_token"]:
			asked = driver.now - started
	assert_gt(asked, 0.0)
	assert_lt(asked, 1300.0 + far_future, "the Brute steps up within 1.2 s")


# ---- knobs and repeatability ----

func test_the_aggression_slider_shortens_the_pause_between_attacks() -> void:
	var slow: float = 0.0
	var fast: float = 0.0
	for rng_seed: int in range(1, 50):
		slow += _first_ask_ms(_circling(GRUNT, rng_seed, {"attacks_enabled": true}))
		fast += _first_ask_ms(_circling(GRUNT, rng_seed, {"attacks_enabled": true, "knobs": {"enemy_aggression": 2.0}}))
	assert_lt(fast, slow * 0.7, "twice the aggression, about half the wait")


func test_the_spacing_slider_scales_the_ring() -> void:
	var near: Driver = _circling(GRUNT, 1, {"dist_to_player": 3.4, "knobs": {"enemy_spacing_scale": 0.6}})
	assert_almost_eq((near.step()["move_dir"] as Vector3).z, 0.0, 0.001, "3.4 m is outside the packed ring of 1.9 m")
	var wide: Driver = _circling(GRUNT, 1, {"dist_to_player": 3.4, "knobs": {"enemy_spacing_scale": 1.6}})
	assert_lt((wide.step()["move_dir"] as Vector3).z, 0.0, "the wide ring starts at 5.1 m: back off")


func test_the_whole_new_behaviour_repeats_from_a_seed() -> void:
	var a: Array[String] = _trace(77)
	var b: Array[String] = _trace(77)
	var c: Array[String] = _trace(78)
	assert_eq(a, b)
	assert_ne(a, c)
	assert_gt(float(a.size()), 3.0)


func _trace(rng_seed: int) -> Array[String]:
	var out: Array[String] = []
	var driver: Driver = _circling(GRUNT, rng_seed, {"attacks_enabled": true})
	for i: int in range(40):
		var answer: Dictionary = driver.swing(&"heavy" if i % 2 == 0 else &"light", true, 300.0)
		if not answer.is_empty():
			out.append("%d:%s" % [int(driver.now), answer["defend"]["kind"]])
			driver.run(400.0)
			driver.brain.notify(&"defence_finished")
		driver.run(700.0 + float(i) * 3.0)
		out.append(str(driver.brain.state()))
		if driver.brain.state() == EnemyBrain.ATTACK:
			driver.brain.notify(&"move_finished")
	return out
