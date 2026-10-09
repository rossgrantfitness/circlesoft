extends TestCase
## EnemyDefence: the defence roll's numbers (chance by Red's move, sliders, fatigue, cooldowns, reaction time)
## and that a seeded roll repeats. The numbers are the real enemies.json `behaviour.defend` blocks.

## The studio's design table (docs/pivot/enemy_ai_design.md). The shipped enemies.json is tuned from here
## (see docs/pivot/tuning_log.md), so these tests pin their own copy and keep proving the mechanics.
const DESIGN: Dictionary = {
	"grunt": {"defend": {"dodge_chance": 0.30, "block_chance": 0.08, "combo_escape": {"chance": 0.5}, "dodge": {"counter_chance": 0.25}},
		"reactions": {"retaliate_chance": 0.15},
		"low_health": {"threshold_frac": 0.40, "flee_chance_alone": 0.70, "flee_chance_pack": 0.30,
			"flee": {"max_per_life": 2}, "flank": {"hold_ms": 600}}},
	"brute": {"defend": {"block_chance": 0.45}, "guard": {"counter_chance": 0.45}, "reactions": {"retaliate_chance": 0.35}},
}


static func _pin_design(data: Dictionary, enemy: String) -> void:
	_merge_deep(data.get("behaviour", {}) as Dictionary, DESIGN.get(enemy, {}) as Dictionary)


static func _merge_deep(into: Dictionary, patch: Dictionary) -> void:
	for key: Variant in patch.keys():
		if patch[key] is Dictionary and into.get(key) is Dictionary:
			_merge_deep(into[key] as Dictionary, patch[key] as Dictionary)
		else:
			into[key] = patch[key]


func _defence(enemy: String, rng_seed: int = 1) -> EnemyDefence:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var data: Dictionary = ((CombatData.enemies().get("enemies", {}) as Dictionary).get(enemy, {}) as Dictionary).duplicate(true)
	_pin_design(data, enemy)
	var cfg: Dictionary = (data.get("behaviour", {}) as Dictionary).get("defend", {})
	return EnemyDefence.create(cfg, rng)


func test_grunt_chances_match_the_design_table() -> void:
	var grunt: EnemyDefence = _defence("grunt")
	var table: Dictionary = {&"light": [0.18, 0.048], &"heavy": [0.30, 0.08], &"launcher": [0.24, 0.064], &"air": [0.12, 0.032]}
	for move_class: StringName in table:
		var odds: Dictionary = grunt.chances(move_class, 0.0, 1.0, 1.0)
		assert_almost_eq(float(odds["dodge"]), float(table[move_class][0]), 0.0001, "dodge vs %s" % move_class)
		assert_almost_eq(float(odds["block"]), float(table[move_class][1]), 0.0001, "block vs %s" % move_class)


func test_brute_blocks_the_fast_moves_and_never_dodges() -> void:
	var brute: EnemyDefence = _defence("brute")
	var light: Dictionary = brute.chances(&"light", 0.0, 1.0, 1.0)
	var heavy: Dictionary = brute.chances(&"heavy", 0.0, 1.0, 1.0)
	assert_almost_eq(float(light["block"]), 0.45, 0.0001)
	assert_almost_eq(float(heavy["block"]), 0.225, 0.0001)
	assert_almost_eq(float(light["dodge"]), 0.0)
	assert_gt(float(light["block"]), float(heavy["block"]), "he does not bother with moves he knows break guard")


func test_a_move_it_does_not_read_gets_no_defence() -> void:
	var grunt: EnemyDefence = _defence("grunt")
	var odds: Dictionary = grunt.chances(&"", 0.0, 1.0, 1.0)
	assert_almost_eq(float(odds["dodge"]) + float(odds["block"]), 0.0)
	assert_eq(grunt.roll(&"", 0.0, 1.0, 1.0), EnemyDefence.KIND_NONE)


func test_the_sliders_scale_each_kind() -> void:
	var grunt: EnemyDefence = _defence("grunt")
	var off: Dictionary = grunt.chances(&"heavy", 0.0, 0.0, 0.0)
	assert_almost_eq(float(off["dodge"]) + float(off["block"]), 0.0, 0.0001, "0 turns defending off")
	var double: Dictionary = grunt.chances(&"heavy", 0.0, 2.0, 2.0)
	assert_almost_eq(float(double["dodge"]), 0.6, 0.0001)
	assert_almost_eq(float(double["block"]), 0.16, 0.0001)
	var brute: EnemyDefence = _defence("brute")
	var enraged: Dictionary = brute.chances(&"light", 0.0, 1.0, 1.0, 0.4)
	assert_almost_eq(float(enraged["block"]), 0.18, 0.0001, "the enraged Brute guards 60% less")


func test_fatigue_cuts_the_chance_and_fades_with_time() -> void:
	var grunt: EnemyDefence = _defence("grunt")
	assert_almost_eq(grunt.fatigue(0.0), 0.0)
	grunt.add_fatigue(0.0)
	assert_almost_eq(grunt.fatigue(0.0), 0.4, 0.0001)
	var after_one: Dictionary = grunt.chances(&"heavy", 0.0, 1.0, 1.0)
	assert_almost_eq(float(after_one["dodge"]), 0.30 * 0.6, 0.0001)
	grunt.add_fatigue(100.0)
	assert_gt(grunt.fatigue(100.0), 0.7, "two defences in a row")
	var after_two: Dictionary = grunt.chances(&"heavy", 100.0, 1.0, 1.0)
	assert_lt(float(after_two["dodge"]), 0.30 * 0.35, "a third of the chance or less")
	assert_almost_eq(grunt.fatigue(100.0 + 4000.0 * 4.0), 0.0, 0.0001, "gone after the decay time")


func test_each_kind_has_its_own_cooldown_from_the_end_of_the_defence() -> void:
	var grunt: EnemyDefence = _defence("grunt")
	assert_true(grunt.ready(EnemyDefence.KIND_DODGE, 0.0))
	grunt.end_defence(EnemyDefence.KIND_DODGE, 1000.0)
	assert_false(grunt.ready(EnemyDefence.KIND_DODGE, 3000.0), "2.5 s dodge cooldown")
	assert_true(grunt.ready(EnemyDefence.KIND_DODGE, 3500.0))
	assert_true(grunt.ready(EnemyDefence.KIND_BLOCK, 3000.0), "the block is a separate cooldown")
	var odds: Dictionary = grunt.chances(&"heavy", 3000.0, 1.0, 1.0)
	assert_almost_eq(float(odds["dodge"]), 0.0, 0.0001, "no dodge while it cools down")
	assert_gt(float(odds["block"]), 0.0)
	grunt.end_defence(EnemyDefence.KIND_BLOCK, 3000.0)
	assert_false(grunt.ready(EnemyDefence.KIND_BLOCK, 4700.0), "1.8 s block cooldown")
	assert_true(grunt.ready(EnemyDefence.KIND_BLOCK, 4801.0))


func test_reaction_time_is_inside_the_data_range_and_scaled() -> void:
	var grunt: EnemyDefence = _defence("grunt", 3)
	var brute: EnemyDefence = _defence("brute", 3)
	for i: int in range(60):
		assert_ge(grunt.reaction_ms(1.0), 80.0)
		assert_le(grunt.reaction_ms(1.0), 150.0)
		assert_ge(brute.reaction_ms(1.0), 160.0)
		assert_le(brute.reaction_ms(1.0), 260.0)
		assert_le(grunt.reaction_ms(2.0), 300.0)
	assert_ge(grunt.reaction_ms(2.0), 160.0, "the slider doubles it")


func test_the_roll_hits_the_design_numbers_over_many_swings() -> void:
	var dodges: int = 0
	var blocks: int = 0
	var runs: int = 1500
	for i: int in range(runs):
		var grunt: EnemyDefence = _defence("grunt", 1000 + i)
		var kind: StringName = grunt.roll(&"heavy", 0.0, 1.0, 1.0)
		if kind == EnemyDefence.KIND_DODGE:
			dodges += 1
		elif kind == EnemyDefence.KIND_BLOCK:
			blocks += 1
	assert_almost_eq(float(dodges) / float(runs), 0.30, 0.04, "30% dodge a Heavy")
	assert_almost_eq(float(blocks) / float(runs), 0.08, 0.03, "8% block a Heavy")
	assert_gt(float(dodges), 0.0)
	assert_lt(float(dodges), float(runs), "sometimes but not always")


func test_a_successful_roll_adds_fatigue_and_a_miss_does_not() -> void:
	var grunt: EnemyDefence = _defence("grunt", 5)
	var got_one: bool = false
	for i: int in range(200):
		var fresh: EnemyDefence = _defence("grunt", 200 + i)
		var kind: StringName = fresh.roll(&"heavy", 0.0, 1.0, 1.0)
		if kind != EnemyDefence.KIND_NONE:
			assert_gt(fresh.fatigue(0.0), 0.0, "a defence tires it")
			got_one = true
		else:
			assert_almost_eq(fresh.fatigue(0.0), 0.0, 0.0001, "no defence, no fatigue")
	assert_true(got_one)
	assert_not_null(grunt)


func test_the_same_seed_rolls_the_same() -> void:
	var a: Array[StringName] = []
	var b: Array[StringName] = []
	var first: EnemyDefence = _defence("grunt", 77)
	var second: EnemyDefence = _defence("grunt", 77)
	for i: int in range(40):
		a.append(first.roll(&"launcher", float(i) * 10000.0, 1.0, 1.0))
		b.append(second.roll(&"launcher", float(i) * 10000.0, 1.0, 1.0))
	assert_eq(a, b)


func test_back_rolls_only_happen_when_red_is_close() -> void:
	var back_close: int = 0
	var back_far: int = 0
	for i: int in range(300):
		var near: EnemyDefence = _defence("grunt", 500 + i)
		if near.dodge_variant(1.0) == &"back":
			back_close += 1
		var far: EnemyDefence = _defence("grunt", 500 + i)
		if far.dodge_variant(2.5) == &"back":
			back_far += 1
	assert_eq(back_far, 0, "beyond 1.6 m it always side-steps")
	assert_almost_eq(float(back_close) / 300.0, 0.30, 0.08, "30% back-rolls when Red is inside 1.6 m")


func test_a_swing_2_9_s_after_a_dodge_began_is_still_inside_the_cooldown() -> void:
	# Why a bot that swings every 2.9 s sees far fewer dodges than the roll says (tuning_log.md, "defence gate"): the
	# cooldown (2.5 s) starts when the dodge ENDS (~0.6 s after it began), so the next free roll is ~3.1 s later.
	var grunt: EnemyDefence = _defence("grunt")
	grunt.end_defence(EnemyDefence.KIND_DODGE, 600.0)
	assert_false(grunt.ready(EnemyDefence.KIND_DODGE, 2900.0 + 100.0), "the roll for the next swing comes ~100 ms after it began")
	assert_eq(float(grunt.chances(&"heavy", 3000.0, 1.0, 1.0)["dodge"]), 0.0, "no dodge chance at all while the cooldown runs")
	assert_true(grunt.ready(EnemyDefence.KIND_DODGE, 3101.0))
