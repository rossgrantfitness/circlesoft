extends TestCase
## Tuning v1.3 (Ross: chunky hits): the hit freeze. The numbers come from the data (moves.json, hit_feel.json, feel.json); these tests pin
## the relationships, not the values: heavy freezes longer than light, the F12 knob scales every freeze, the guard break is heavy.

const SETS: Array[String] = ["red"]


func _knob(id: String) -> Dictionary:
	for entry: Variant in CombatData.feel().get("knobs", []) as Array:
		if str((entry as Dictionary).get("id", "")) == id:
			return entry as Dictionary
	return {}


func _stop_ms(set_id: String, move_id: String) -> float:
	var moves: Dictionary = CombatData.moves()
	return float((((moves["sets"] as Dictionary)[set_id] as Dictionary)["moves"] as Dictionary)[move_id]["hit"]["hit_stop_ms"])


func _attack(hit_stop_ms: float, extra: Dictionary = {}) -> Dictionary:
	var attack: Dictionary = {"damage": 8, "hitstun_ms": 320, "knockback_m": 0.5, "launch_mps": 0.0, "knockdown": false,
		"hit_stop_ms": hit_stop_ms, "poise_damage": 8, "style_points": 10, "move_id": &"light_1", "launcher": false, "swing_id": 7, "parryable": true}
	attack.merge(extra, true)
	return attack


func _snap(id: StringName, team: StringName, extra: Dictionary = {}) -> Dictionary:
	var snap: Dictionary = {"id": id, "team": team, "airborne": false, "invulnerable": false, "poise": 30.0, "poise_max": 30.0,
		"armored": false, "juggle_count": 0, "launchable": true, "hp": 100, "position": Vector3.ZERO if team == &"player" else Vector3(0, 0, 2),
		"forward": Vector3.BACK if team == &"player" else Vector3.FORWARD, "weight": 1.0}
	snap.merge(extra, true)
	return snap


func _resolve(attack: Dictionary, feel: FeelKnobs, foe_extra: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = {"parry": {"rating": "miss"}, "lights_on": {"active": false, "damage_mult": 1.0, "super_armor": false},
		"feel": feel, "hit_feel": CombatData.hit_feel()}
	return HitResolver.resolve(attack, _snap(&"red", &"player"), _snap(&"grunt_1", &"enemy", foe_extra), ctx)


func test_the_hit_freeze_knob_is_in_the_panel_with_a_hint_and_a_sensible_range() -> void:
	var knob: Dictionary = _knob("hit_freeze_s")
	assert_false(knob.is_empty(), "the knob is in feel.json")
	assert_eq(str(knob["group"]), "hits", "it has its own tab")
	assert_eq(str(knob["label"]), "Hit freeze length")
	assert_false(FeelFormat.hint_of(knob).is_empty(), "every knob needs a hint")
	assert_le(float(knob["min"]), 0.05 + 0.0001, "down to about 0.05 s")
	assert_ge(float(knob["max"]), 0.30 - 0.0001, "up to about 0.30 s")
	assert_ge(float(knob["value"]), float(knob["min"]))
	assert_le(float(knob["value"]), float(knob["max"]))
	assert_eq(FeelFormat.groups_of(CombatData.feel().get("knobs", []) as Array)[0], "hits", "the Hit feel tab is the first one Ross sees")
	assert_false(FeelFormat.group_title("hits").is_empty())
	for id: String in ["hit_flash_on", "hit_flash_red_on"]:
		assert_false(FeelFormat.hint_of(_knob(id)).is_empty(), "%s has a hint" % id)
	assert_false(bool(_knob("hit_flash_red_on")["value"]), "Red's flash is off by default")


func test_the_reference_length_matches_the_knobs_default_so_the_data_is_the_default_feel() -> void:
	var reference: float = float((CombatData.hit_feel()["hit_freeze"] as Dictionary)["reference_s"])
	assert_almost_eq(float(_knob("hit_freeze_s")["value"]), reference, 0.0001)
	assert_almost_eq(HitResolver.freeze_scale(FeelKnobs.load_defaults(), CombatData.hit_feel()), 1.0, 0.0001, "default = the data as written")
	assert_almost_eq(HitResolver.freeze_scale(null, CombatData.hit_feel()), 1.0, 0.0001, "no knobs = the data as written")


func test_heavy_hits_freeze_longer_than_light_hits_and_both_are_noticeable() -> void:
	var light: float = _stop_ms("red", "light_1")
	for heavy_id: String in ["heavy", "launcher", "sweep", "air_3"]:
		assert_gt(_stop_ms("red", heavy_id), light, "%s freezes longer than a light hit" % heavy_id)
	assert_ge(light, 80.0, "a light hit freezes long enough to see (Ross: about a tenth of a second)")
	var reference_ms: float = float((CombatData.hit_feel()["hit_freeze"] as Dictionary)["reference_s"]) * 1000.0
	for move_id: String in ["light_1", "light_2", "light_3", "heavy", "launcher", "air_1", "air_2", "air_3", "lunge", "sweep"]:
		assert_le(_stop_ms("red", move_id), reference_ms + 0.001, "%s never freezes longer than the knob's default" % move_id)


func test_the_knob_scales_every_freeze_by_knob_over_reference() -> void:
	var feel: FeelKnobs = FeelKnobs.load_defaults()
	var reference: float = float((CombatData.hit_feel()["hit_freeze"] as Dictionary)["reference_s"])
	var base: float = float(_resolve(_attack(100.0), feel)["hit_stop_ms"])
	assert_almost_eq(base, 100.0, 0.001, "default knob: the move's own number")
	for seconds: float in [0.05, 0.10, 0.30]:
		feel.set_value("hit_freeze_s", seconds)
		assert_almost_eq(float(_resolve(_attack(100.0), feel)["hit_stop_ms"]), 100.0 * seconds / reference, 0.01, "knob %.2f s" % seconds)
	feel.set_value("hit_freeze_s", 0.10)
	var old_knob_too: float = float(_resolve(_attack(250.0), feel)["hit_stop_ms"])
	feel.set_value("hit_stop_scale", 0.0)
	assert_almost_eq(float(_resolve(_attack(250.0), feel)["hit_stop_ms"]), 0.0, 0.001, "the older multiplier still works on top")
	assert_gt(old_knob_too, 0.0)


func test_a_broken_guard_freezes_like_a_heavy_hit_whatever_broke_it() -> void:
	var guard: Dictionary = {"up": true, "arc_deg": 360.0, "meter": 60.0, "break_poise": 20.0, "break_by_launcher": true, "chip_scale": 0.25,
		"min_chip": 1, "knockback_scale": 0.35, "hit_stop_scale": 0.5, "break_ms": 1100.0, "spark": "guard", "sfx": "combat_hit_light"}
	var feel: FeelKnobs = FeelKnobs.load_defaults()
	var broke_ms: float = float((CombatData.hit_feel()["hit_freeze"] as Dictionary)["guard_break_hit_stop_ms"])
	var result: Dictionary = _resolve(_attack(40.0, {"poise_damage": 40.0}), feel, {"guard": guard})
	assert_eq(result["outcome"], &"guard_broken")
	assert_ge(float(result["hit_stop_ms"]), broke_ms - 0.001, "the break freezes for the guard-break length")
	var blocked: Dictionary = _resolve(_attack(40.0), feel, {"guard": guard})
	assert_eq(blocked["outcome"], &"blocked")
	assert_lt(float(blocked["hit_stop_ms"]), broke_ms, "a plain block stays short")
	feel.set_value("hit_freeze_s", 0.10)
	var scaled: Dictionary = _resolve(_attack(40.0, {"poise_damage": 40.0}), feel, {"guard": guard})
	assert_almost_eq(float(scaled["hit_stop_ms"]), broke_ms * 0.10 / float((CombatData.hit_feel()["hit_freeze"] as Dictionary)["reference_s"]), 0.01, "the knob scales the break too")


func test_hit_stop_is_in_real_time_and_the_longest_freeze_wins() -> void:
	var time: CombatTime = CombatTime.new()
	var ids: Array[StringName] = [&"red", &"grunt_1"]
	time.add_hit_stop(ids, _stop_ms("red", "light_1"))
	time.add_hit_stop(ids, _stop_ms("red", "heavy"))
	assert_almost_eq(time.hit_stop_left_ms(&"red"), _stop_ms("red", "heavy"), 0.001)
	time.step(0.05)
	assert_true(time.is_frozen(&"grunt_1"))
	time.step(_stop_ms("red", "heavy") / 1000.0)
	assert_false(time.is_frozen(&"grunt_1"), "and then it lets go")
