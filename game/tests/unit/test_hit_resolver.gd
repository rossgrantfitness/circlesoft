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
	var feel: FeelKnobs = FeelKnobs.load_defaults()
	feel.set_value("enemy_damage_scale", 1.0)       # raw damage, not the tuned default
	var ctx: Dictionary = {"parry": {"rating": rating}, "lights_on": {"active": false, "damage_mult": 1.0, "super_armor": false},
		"feel": feel, "hit_feel": CombatData.hit_feel()}
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
	# The action game's table: parry.block_reduction in timing_windows.json (Nice 0.6), not the old shared 0.25.
	var nice: float = float(CombatData.parry_block_reduction()["nice"])
	assert_almost_eq(nice, 0.6, 0.0001, "the Kingdom Hearts guard soaks 60 percent")
	var result: Dictionary = _resolve_on_red(_swipe({"damage": 20}), "nice")
	assert_eq(result["outcome"], &"guarded")
	assert_eq(result["damage"], 8, "20 x (1 - 0.6)")
	assert_lt(float(result["hitstun_ms"]), 350.0, "a guard flinches less")
	assert_eq(result["launch_mps"], 0.0)


func test_row3_the_resolver_reads_the_action_tables_not_the_battle_games_shared_one() -> void:
	var windows: Dictionary = CombatData.timing_windows()
	assert_ne(float((windows.get("block_reduction", {}) as Dictionary).get("nice", 0.0)), 0.6, "the shared table is still the old one")
	assert_eq(CombatData.parry_block_reduction(), (windows["parry"] as Dictionary)["block_reduction"])


func test_row3_a_table_handed_in_by_the_caller_wins() -> void:
	var ctx_extra: Dictionary = {"parry": {"rating": "nice", "block_reduction": {"nice": 0.9}}}
	var result: Dictionary = _resolve_on_red(_swipe({"damage": 20}), "nice", {}, ctx_extra)
	assert_eq(result["damage"], 2, "20 x (1 - 0.9)")


func test_row3_rad_and_up_take_no_damage_at_all() -> void:
	var table: Dictionary = CombatData.parry_block_reduction()
	assert_almost_eq(float(table["rad"]), 1.0, 0.0001)
	assert_almost_eq(float(table["totally_rad"]), 1.0, 0.0001)
	assert_eq(_resolve_on_red(_swipe({"damage": 20}), "rad")["damage"], 0)
	assert_eq(_resolve_on_red(_swipe({"damage": 20}), "totally_rad")["damage"], 0)


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


# ---- row 3b: an enemy's raised guard (enemy_ai_design 6) ----

func _guard(extra: Dictionary = {}) -> Dictionary:
	var guard: Dictionary = {"up": true, "arc_deg": 150.0, "meter": 24.0, "break_poise": 20.0, "break_by_launcher": true,
		"chip_scale": 0.25, "min_chip": 1, "knockback_scale": 0.35, "hit_stop_scale": 0.5, "break_ms": 1100.0,
		"spark": "guard", "sfx": "combat_hit_light"}
	guard.merge(extra, true)
	return guard


func _heavy(extra: Dictionary = {}) -> Dictionary:
	var attack: Dictionary = {"damage": 22, "hitstun_ms": 450, "knockback_m": 1.4, "launch_mps": 0.0, "knockdown": false,
		"hit_stop_ms": 90, "poise_damage": 30, "style_points": 14, "move_id": &"heavy", "launcher": false, "swing_id": 9, "parryable": true}
	attack.merge(extra, true)
	return attack


func test_row3b_a_light_into_a_raised_guard_is_blocked() -> void:
	var result: Dictionary = _resolve_on_foe(_light(), {"guard": _guard()})
	assert_eq(result["outcome"], &"blocked")
	assert_eq(result["damage"], 2, "8 x 0.25 chip damage")
	assert_almost_eq(float(result["hitstun_ms"]), 0.0, 0.001, "no hit-stun on a block")
	assert_almost_eq(float(result["guard_drain"]), 8.0, 0.001, "it drains the hit's poise damage")
	assert_almost_eq(float(result["hit_stop_ms"]), 25.0, 0.001, "hit-stop halved")
	assert_almost_eq(float(result["poise_after"]), 30.0, 0.001, "poise is untouched")
	assert_almost_eq(float(result["style_points"]), 0.0, 0.001)
	assert_false(bool(result["staggered_target"]))
	assert_eq(result["feedback"]["spark"], "guard")
	assert_eq(result["feedback"]["sfx"], "combat_hit_light")


func test_row3b_a_block_pushes_back_a_little() -> void:
	var open: Dictionary = _resolve_on_foe(_light())
	var blocked: Dictionary = _resolve_on_foe(_light(), {"guard": _guard()})
	assert_almost_eq((blocked["knockback"] as Vector3).length(), (open["knockback"] as Vector3).length() * 0.35, 0.001)


func test_row3b_chip_damage_is_at_least_one() -> void:
	var result: Dictionary = _resolve_on_foe(_light({"damage": 2}), {"guard": _guard({"chip_scale": 0.15, "min_chip": 1})})
	assert_eq(result["damage"], 1)
	var none: Dictionary = _resolve_on_foe(_light({"damage": 0}), {"guard": _guard()})
	assert_eq(none["damage"], 0, "a hit with no damage stays at none")


func test_row3b_a_heavy_always_breaks_the_guard() -> void:
	for break_poise: float in [20.0, 30.0]:
		var result: Dictionary = _resolve_on_foe(_heavy(), {"guard": _guard({"break_poise": break_poise, "meter": 60.0})})
		assert_eq(result["outcome"], &"guard_broken", "break_poise %.0f" % break_poise)
		assert_true(bool(result["staggered_target"]))
		assert_almost_eq(float(result["hitstun_ms"]), 1100.0, 0.001, "the guard-break stagger")
		assert_eq(result["damage"], 6, "chip damage on the breaking hit (22 x 0.25)")


func test_row3b_a_launcher_breaks_the_guard_even_if_its_poise_is_small() -> void:
	var launcher: Dictionary = _light({"launcher": true, "poise_damage": 12, "launch_mps": 11.0, "move_id": &"launcher"})
	var result: Dictionary = _resolve_on_foe(launcher, {"guard": _guard({"meter": 60.0})})
	assert_eq(result["outcome"], &"guard_broken")
	assert_almost_eq(float(result["launch_mps"]), 0.0, 0.001, "no launch out of a guard break")
	var no_break: Dictionary = _resolve_on_foe(launcher, {"guard": _guard({"meter": 60.0, "break_by_launcher": false})})
	assert_eq(no_break["outcome"], &"blocked")


func test_row3b_an_emptied_meter_breaks_the_guard() -> void:
	var three: Dictionary = _resolve_on_foe(_light(), {"guard": _guard({"meter": 8.0})})
	assert_eq(three["outcome"], &"guard_broken", "the third Light empties a 24 meter")
	var two: Dictionary = _resolve_on_foe(_light(), {"guard": _guard({"meter": 9.0})})
	assert_eq(two["outcome"], &"blocked")


func test_row3b_a_hit_from_the_side_or_behind_ignores_the_guard() -> void:
	var foe: Dictionary = _foe({"guard": _guard()})
	var from_behind: Dictionary = HitResolver.resolve(_light(), _red({"position": Vector3(0, 0, 6)}), foe, _ctx())
	assert_eq(from_behind["outcome"], &"hit", "Red stands behind the foe (it faces -Z)")
	assert_eq(from_behind["damage"], 8)
	var from_side: Dictionary = HitResolver.resolve(_light(), _red({"position": Vector3(3, 0, 2.3)}), foe, _ctx())
	assert_eq(from_side["outcome"], &"hit", "75 degrees is the edge of a 150 degree arc: this is 90")
	var front: Dictionary = HitResolver.resolve(_light(), _red({"position": Vector3(1, 0, 0)}), foe, _ctx())
	assert_eq(front["outcome"], &"blocked")


func test_row3b_a_lowered_guard_blocks_nothing() -> void:
	var result: Dictionary = _resolve_on_foe(_light(), {"guard": _guard({"up": false})})
	assert_eq(result["outcome"], &"hit")
	var none: Dictionary = _resolve_on_foe(_light(), {"guard": {}})
	assert_eq(none["outcome"], &"hit")


func test_row3b_the_guard_comes_before_armor_and_after_i_frames() -> void:
	var brute: Dictionary = _resolve_on_foe(_light(), {"guard": _guard(), "armored": true})
	assert_eq(brute["outcome"], &"blocked", "a guarding Brute blocks instead of soaking")
	var evade: Dictionary = _resolve_on_foe(_light(), {"guard": _guard(), "invulnerable": true})
	assert_eq(evade["outcome"], &"evaded")


func test_row3b_a_guard_only_helps_the_enemy_never_red() -> void:
	var result: Dictionary = _resolve_on_red(_swipe(), "miss", {"guard": _guard()})
	assert_eq(result["outcome"], &"blocked", "the resolver trusts the snapshot: only enemies ever send a guard")


func test_a_killing_chip_is_lethal() -> void:
	var result: Dictionary = _resolve_on_foe(_light({"damage": 8}), {"guard": _guard(), "hp": 2})
	assert_true(bool(result["lethal"]))


func test_a_hit_on_a_fleeing_enemy_always_knocks_it_down() -> void:
	var plain: Dictionary = _resolve_on_foe(_light())
	assert_false(bool(plain["knockdown"]))
	var fleeing: Dictionary = _resolve_on_foe(_light(), {"flee_knockdown": true})
	assert_eq(fleeing["outcome"], &"hit")
	assert_true(bool(fleeing["knockdown"]), "caught from behind while running")
	var armored_fleeing: Dictionary = _resolve_on_foe(_light(), {"flee_knockdown": true, "armored": true})
	assert_eq(armored_fleeing["outcome"], &"armored", "armor still soaks")
