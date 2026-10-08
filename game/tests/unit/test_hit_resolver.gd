extends TestCase
## HitResolver: every row of the outcome table in order, the numbers each outcome carries, and "one swing
## hits each target once".

const RED_POS: Vector3 = Vector3(0, 0, 0)
const FOE_POS: Vector3 = Vector3(0, 0, 2)


func _red(extra: Dictionary = {}) -> Dictionary:
	var snap: Dictionary = {"id": &"red", "team": &"player", "airborne": false, "invulnerable": false, "poise": 0.0,
		"poise_max": 0.0, "armored": false, "juggle_count": 0, "launchable": true, "hp": 120,
		"position": RED_POS, "forward": Vector3.BACK, "weight": 1.0}
	snap.merge(extra, true)
	return snap


func _foe(extra: Dictionary = {}) -> Dictionary:
	var snap: Dictionary = {"id": &"grunt_1", "team": &"enemy", "airborne": false, "invulnerable": false, "poise": 30.0,
		"poise_max": 30.0, "armored": false, "juggle_count": 0, "launchable": true, "hp": 48,
		"position": FOE_POS, "forward": Vector3.FORWARD, "weight": 1.0}
	snap.merge(extra, true)
	return snap


func _light(extra: Dictionary = {}) -> Dictionary:
	var attack: Dictionary = {"damage": 8, "hitstun_ms": 320, "knockback_m": 0.5, "launch_mps": 0.0, "knockdown": false,
		"hit_stop_ms": 50, "poise_damage": 8, "style_points": 10, "move_id": &"light_1", "launcher": false, "swing_id": 7, "parryable": true}
	attack.merge(extra, true)
	return attack


func _swipe(extra: Dictionary = {}) -> Dictionary:
	var attack: Dictionary = {"damage": 10, "hitstun_ms": 350, "knockback_m": 1.2, "launch_mps": 0.0, "knockdown": false,
		"hit_stop_ms": 60, "poise_damage": 10, "style_points": 0, "move_id": &"swipe", "launcher": false, "swing_id": 3, "parryable": true}
	attack.merge(extra, true)
	return attack


func _ctx(rating: String = "miss", extra: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = {"parry": {"rating": rating}, "lights_on": {"active": false, "damage_mult": 1.0, "super_armor": false},
		"feel": FeelKnobs.load_defaults(), "hit_feel": CombatData.hit_feel()}
	ctx.merge(extra, true)
	return ctx


func _resolve_on_foe(attack: Dictionary, target_extra: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	return HitResolver.resolve(attack, _red(), _foe(target_extra), ctx if not ctx.is_empty() else _ctx())


func _resolve_on_red(attack: Dictionary, rating: String = "miss", red_extra: Dictionary = {}, ctx_extra: Dictionary = {}) -> Dictionary:
	return HitResolver.resolve(attack, _foe(), _red(red_extra), _ctx(rating, ctx_extra))


# ---- row 1: ignored ----

func test_row1_same_team_is_ignored() -> void:
	var result: Dictionary = HitResolver.resolve(_light(), _red(), _red({"id": &"other"}), _ctx())
	assert_eq(result["outcome"], &"ignored")
	assert_eq(result["damage"], 0)


func test_row1_a_dead_target_is_ignored() -> void:
	var result: Dictionary = _resolve_on_foe(_light(), {"hp": 0})
	assert_eq(result["outcome"], &"ignored")


# ---- row 2: evaded beats parry and armor ----

func test_row2_invulnerable_target_evades_before_anything_else() -> void:
	var result: Dictionary = _resolve_on_red(_swipe(), "totally_rad", {"invulnerable": true})
	assert_eq(result["outcome"], &"evaded", "i-frames win over a perfect parry")
	assert_eq(result["damage"], 0)
	assert_almost_eq(float(result["hit_stop_ms"]), 0.0)
	var armored_foe: Dictionary = _resolve_on_foe(_light(), {"invulnerable": true, "armored": true})
	assert_eq(armored_foe["outcome"], &"evaded", "and over armor")


# ---- row 3: Red's parry ----

func test_row3_perfect_parry_does_no_damage_and_staggers_the_attacker() -> void:
	var result: Dictionary = _resolve_on_red(_swipe(), "totally_rad")
	assert_eq(result["outcome"], &"perfect_parry")
	assert_eq(result["damage"], 0)
	assert_true(result["staggered_attacker"])
	assert_gt(float(result["hit_stop_ms"]), 0.0)


func test_row3_parry_does_no_damage_and_recoils_the_attacker() -> void:
	var result: Dictionary = _resolve_on_red(_swipe(), "rad")
	assert_eq(result["outcome"], &"parried")
	assert_eq(result["damage"], 0)
	assert_false(result["staggered_attacker"])


func test_row3_a_nice_guard_cuts_damage_by_the_block_reduction() -> void:
	var result: Dictionary = _resolve_on_red(_swipe({"damage": 20}), "nice")
	assert_eq(result["outcome"], &"guarded")
	assert_eq(result["damage"], 15, "20 x (1 - 0.25)")
	assert_lt(float(result["hitstun_ms"]), 350.0, "a guard flinches less")
	assert_eq(result["launch_mps"], 0.0)


func test_row3_only_applies_to_red_and_to_parryable_attacks() -> void:
	var on_enemy: Dictionary = _resolve_on_foe(_light(), {}, _ctx("totally_rad"))
	assert_eq(on_enemy["outcome"], &"hit", "a parry rating does nothing for an enemy")
	var unparryable: Dictionary = _resolve_on_red(_swipe({"parryable": false}), "totally_rad")
	assert_eq(unparryable["outcome"], &"hit")


func test_row3_a_miss_rating_is_just_a_hit() -> void:
	var result: Dictionary = _resolve_on_red(_swipe(), "miss")
	assert_eq(result["outcome"], &"hit")
	assert_eq(result["damage"], 10)


# ---- row 4: armor ----

func test_row4_armor_takes_damage_and_poise_but_no_flinch() -> void:
	var result: Dictionary = _resolve_on_foe(_light({"launch_mps": 11.0, "knockdown": true}), {"armored": true, "poise": 30.0})
	assert_eq(result["outcome"], &"armored")
	assert_eq(result["damage"], 8)
	assert_almost_eq(float(result["poise_after"]), 22.0)
	assert_almost_eq(float(result["hitstun_ms"]), 0.0)
	assert_almost_eq(float(result["launch_mps"]), 0.0)
	assert_false(result["knockdown"])
	assert_eq(result["knockback"], Vector3.ZERO)


func test_row5_armor_gives_way_when_poise_breaks() -> void:
	var result: Dictionary = _resolve_on_foe(_light({"poise_damage": 30}), {"armored": true, "poise": 30.0})
	assert_eq(result["outcome"], &"stagger")
	assert_true(result["staggered_target"])
	assert_almost_eq(float(result["poise_after"]), 30.0, 0.0001, "poise refills after the break")
	assert_ge(float(result["hitstun_ms"]), 1100.0, "a poise break stuns for stagger_ms")


func test_lights_on_makes_red_armored_and_hit_harder() -> void:
	var armor: Dictionary = _resolve_on_red(_swipe(), "miss", {}, {"lights_on": {"active": true, "damage_mult": 1.5, "super_armor": true}})
	assert_eq(armor["outcome"], &"armored")
	var off: Dictionary = _resolve_on_red(_swipe(), "miss", {}, {"lights_on": {"active": false, "damage_mult": 1.5, "super_armor": true}})
	assert_eq(off["outcome"], &"hit")
	var strong: Dictionary = _resolve_on_foe(_light(), {}, _ctx("miss", {"lights_on": {"active": true, "damage_mult": 1.5, "super_armor": true}}))
	assert_eq(strong["damage"], 12, "8 x 1.5")


# ---- row 5: hits ----

func test_row5_a_plain_hit_carries_the_numbers() -> void:
	var result: Dictionary = _resolve_on_foe(_light())
	assert_eq(result["outcome"], &"hit")
	assert_eq(result["damage"], 8)
	assert_almost_eq(float(result["hitstun_ms"]), 320.0)
	assert_almost_eq(float(result["hit_stop_ms"]), 50.0)
	assert_almost_eq(float(result["poise_after"]), 22.0)
	assert_almost_eq(float(result["style_points"]), 10.0)
	assert_eq(result["move_id"], &"light_1")
	assert_eq(result["attacker"], &"red")
	assert_eq(result["target"], &"grunt_1")


func test_knockback_points_away_from_the_attacker_and_scales_with_weight() -> void:
	var light: Dictionary = _resolve_on_foe(_light({"knockback_m": 1.0}))
	var push: Vector3 = light["knockback"]
	assert_almost_eq(push.z, 1.0, 0.0001)
	assert_almost_eq(push.x, 0.0, 0.0001)
	assert_almost_eq(push.y, 0.0, 0.0001)
	var heavy_target: Dictionary = _resolve_on_foe(_light({"knockback_m": 1.0}), {"weight": 4.0})
	assert_almost_eq((heavy_target["knockback"] as Vector3).length(), 0.25, 0.0001)


func test_launch_goes_to_launchable_targets_only() -> void:
	var launcher: Dictionary = _light({"launch_mps": 11.0, "launcher": true})
	var grunt: Dictionary = _resolve_on_foe(launcher)
	assert_almost_eq(float(grunt["launch_mps"]), 11.0)
	assert_true(grunt["launched"])
	assert_eq(grunt["juggle_count"], 1)
	var brute: Dictionary = _resolve_on_foe(launcher, {"launchable": false})
	assert_almost_eq(float(brute["launch_mps"]), 0.0)
	assert_false(brute["launched"])


func test_the_launch_height_knob_scales_the_lift() -> void:
	var feel: FeelKnobs = FeelKnobs.load_defaults()
	feel.set_value("launch_height_scale", 1.5)
	var result: Dictionary = _resolve_on_foe(_light({"launch_mps": 10.0}), {}, _ctx("miss", {"feel": feel}))
	assert_almost_eq(float(result["launch_mps"]), 15.0, 0.001)


func test_hit_stop_knob_scales_the_freeze() -> void:
	var feel: FeelKnobs = FeelKnobs.load_defaults()
	feel.set_value("hit_stop_scale", 2.0)
	var result: Dictionary = _resolve_on_foe(_light(), {}, _ctx("miss", {"feel": feel}))
	assert_almost_eq(float(result["hit_stop_ms"]), 100.0)
	feel.set_value("hit_stop_scale", 0.0)
	assert_almost_eq(float(_resolve_on_foe(_light(), {}, _ctx("miss", {"feel": feel}))["hit_stop_ms"]), 0.0)


func test_air_hits_lift_a_little_less_each_time_and_count_up() -> void:
	var previous: float = 1.0e9
	for count: int in range(0, 5):
		var result: Dictionary = _resolve_on_foe(_light(), {"airborne": true, "juggle_count": count})
		assert_eq(result["juggle_count"], count + 1)
		assert_gt(float(result["launch_mps"]), 0.0)
		assert_le(float(result["launch_mps"]), previous)
		previous = float(result["launch_mps"])


func test_the_juggle_cap_drops_the_target() -> void:
	var capped: Dictionary = _resolve_on_foe(_light(), {"airborne": true, "juggle_count": 10})
	assert_almost_eq(float(capped["launch_mps"]), 0.0)
	assert_true(capped["knockdown"])


func test_a_grounded_hit_resets_the_juggle_count() -> void:
	var result: Dictionary = _resolve_on_foe(_light(), {"juggle_count": 4})
	assert_eq(result["juggle_count"], 0)


func test_knockdown_follows_the_move_for_launchable_targets() -> void:
	var slam: Dictionary = _light({"knockdown": true})
	assert_true(_resolve_on_foe(slam)["knockdown"])
	assert_false(_resolve_on_foe(slam, {"launchable": false})["knockdown"], "a brute stays on its feet unless poise breaks")
	var broken: Dictionary = _resolve_on_foe(_light({"knockdown": true, "poise_damage": 99}), {"launchable": false})
	assert_true(broken["knockdown"])


func test_a_hit_that_breaks_poise_staggers() -> void:
	var result: Dictionary = _resolve_on_foe(_light({"poise_damage": 40}))
	assert_eq(result["outcome"], &"stagger")
	assert_true(result["staggered_target"])


func test_damage_is_at_least_one_and_lethal_is_flagged() -> void:
	var tiny: Dictionary = _resolve_on_foe(_light({"damage": 1}), {}, _ctx("miss", {"lights_on": {"active": false, "damage_mult": 0.1, "super_armor": false}}))
	assert_eq(tiny["damage"], 1)
	var kill: Dictionary = _resolve_on_foe(_light({"damage": 99}))
	assert_true(kill["lethal"])


func test_enemy_damage_scale_knob_changes_what_red_takes() -> void:
	var feel: FeelKnobs = FeelKnobs.load_defaults()
	feel.set_value("enemy_damage_scale", 0.5)
	var result: Dictionary = _resolve_on_red(_swipe({"damage": 10}), "miss", {}, {"feel": feel})
	assert_eq(result["damage"], 5)


# ---- one swing, one hit per target ----

func test_one_swing_hits_each_target_once() -> void:
	var ledger: Dictionary = {}
	assert_true(HitResolver.may_hit(ledger, 1, &"a", 0.0))
	assert_false(HitResolver.may_hit(ledger, 1, &"a", 10.0), "same swing, same target")
	assert_true(HitResolver.may_hit(ledger, 1, &"b", 10.0), "another target is fine")
	assert_true(HitResolver.may_hit(ledger, 2, &"a", 20.0), "a new swing hits again")


func test_rehit_ms_allows_a_multi_hit_move_to_repeat() -> void:
	var ledger: Dictionary = {}
	assert_true(HitResolver.may_hit(ledger, 1, &"a", 0.0, 100.0))
	assert_false(HitResolver.may_hit(ledger, 1, &"a", 99.0, 100.0))
	assert_true(HitResolver.may_hit(ledger, 1, &"a", 100.0, 100.0))
	assert_false(HitResolver.may_hit(ledger, 1, &"a", 150.0, 100.0))


func test_the_real_numbers_kill_a_grunt_in_about_five_hits() -> void:
	var moves: MoveSet = MoveSet.load_default()
	var grunt_hp: int = int(((CombatData.enemies()["enemies"] as Dictionary)["grunt"] as Dictionary)["hp"])
	var light_only: int = 0
	var hp: int = grunt_hp
	for move_id: StringName in [&"light_1", &"light_2", &"light_3", &"light_1", &"light_2", &"light_3"]:
		hp -= int((moves.get_move(&"red", move_id)["hit"] as Dictionary)["damage"])
		light_only += 1
		if hp <= 0:
			break
	assert_between_hits(light_only)
	hp = grunt_hp
	var combo: int = 0
	for move_id: StringName in [&"light_1", &"light_2", &"light_3", &"heavy", &"launcher"]:
		hp -= int((moves.get_move(&"red", move_id)["hit"] as Dictionary)["damage"])
		combo += 1
		if hp <= 0:
			break
	assert_between_hits(combo)


func assert_between_hits(count: int) -> void:
	assert_ge(float(count), 4.0, "not dead too fast")
	assert_le(float(count), 6.0, "not too slow")
