extends TestCase
## CS-21: data/combat/scale_profiles.json and the pure rules of ScaleProfile. The numbers are guesses for Ross to retune by
## playing, so these tests check their SHAPE (bigger body: further camera, faster and heavier, slower to turn, more haze) and that
## every file, sound and effect the data names is really there.

const FORMS: Array[StringName] = [&"red", &"small", &"huge"]


func _form(id: StringName) -> ScaleProfile:
	var profile: ScaleProfile = ScaleProfile.get_form(id)
	assert_not_null(profile, "form %s" % id)
	return profile if profile != null else ScaleProfile.new()


func test_the_three_forms_are_in_the_data() -> void:
	for id: StringName in FORMS:
		assert_not_null(ScaleProfile.get_form(id), "form %s" % id)
	assert_null(ScaleProfile.get_form(&"no_such_form"))
	assert_eq(ScaleProfile.start_form(), &"red")
	assert_eq(ScaleProfile.form_ids().size(), 3)


func test_bigger_bodies_have_a_further_camera_and_a_wider_world() -> void:
	var red: Dictionary = _form(&"red").block("camera")
	var small: Dictionary = _form(&"small").block("camera")
	var huge: Dictionary = _form(&"huge").block("camera")
	assert_lt(float(red["distance_m"]), float(small["distance_m"]))
	assert_lt(float(small["distance_m"]), float(huge["distance_m"]))
	assert_lt(float(red["min_distance_m"]), float(small["min_distance_m"]))
	assert_lt(float(small["min_distance_m"]), float(huge["min_distance_m"]))
	assert_lt(float(red["pivot_height_m"]), float(small["pivot_height_m"]))
	assert_lt(float(small["pivot_height_m"]), float(huge["pivot_height_m"]))
	assert_lt(float(red["far_m"]), float(small["far_m"]), "the draw distance grows with the body")
	assert_lt(float(small["far_m"]), float(huge["far_m"]))
	assert_lt(float(red["near_m"]), float(huge["near_m"]), "and the near plane, so depth stays clean")
	assert_gt(float(huge["far_m"]), 10.0 * float(huge["distance_m"]), "the colossus sees far past its own camera")
	assert_lt(float(red["shake_cap_m"]), float(huge["shake_cap_m"]), "a far camera may shake further than 0.25 m")
	assert_gt(float(_form(&"huge").block("camera")["pitch_offset_deg"]), 0.0, "the huge camera sits lower (shallower pitch)")


func test_fog_and_shadow_range_scale_with_the_body_and_never_hide_the_robot() -> void:
	var red: Dictionary = _form(&"red").world()
	var small: Dictionary = _form(&"small").world()
	var huge: Dictionary = _form(&"huge").world()
	assert_almost_eq(float(red["fog_near_m"]), 30.0, 0.001, "Red keeps the arena's haze: 30 to 150 m")
	assert_almost_eq(float(red["fog_far_m"]), 150.0, 0.001)
	assert_lt(float(red["fog_near_m"]), float(small["fog_near_m"]))
	assert_lt(float(small["fog_near_m"]), float(huge["fog_near_m"]))
	assert_lt(float(red["fog_far_m"]), float(small["fog_far_m"]))
	assert_lt(float(small["fog_far_m"]), float(huge["fog_far_m"]))
	assert_lt(float(huge["env_fog_density"]), float(small["env_fog_density"]))
	assert_lt(float(small["env_fog_density"]), float(red["env_fog_density"]))
	# the colossus is seen from its camera distance: the haze must still be clear there
	var camera_m: float = float(_form(&"huge").block("camera")["distance_m"])
	assert_gt(float(huge["fog_near_m"]), camera_m, "the haze starts beyond the camera distance")
	var seen_through_exp_fog: float = exp(-float(huge["env_fog_density"]) * camera_m)
	assert_gt(seen_through_exp_fog, 0.85, "less than 15 percent real fog between the camera and the colossus")
	var small_cam: float = float(_form(&"small").block("camera")["distance_m"])
	assert_gt(float(small["fog_near_m"]), small_cam)
	assert_lt(float(red["shadow_max_distance_m"]), float(huge["shadow_max_distance_m"]))
	assert_gt(float(huge["shadow_max_distance_m"]), camera_m, "the robot still casts a shadow at its own camera distance")


func test_bigger_bodies_are_faster_heavier_and_slower_to_turn() -> void:
	var small: ScaleProfile = _form(&"small")
	var huge: ScaleProfile = _form(&"huge")
	assert_gt(small.knob("run_speed_mps", 0.0), 6.0, "faster than Red (6 m/s)")
	assert_gt(huge.knob("run_speed_mps", 0.0), small.knob("run_speed_mps", 0.0))
	# in body lengths per second the colossus is far slower: that is what makes it feel heavy
	assert_lt(huge.knob("run_speed_mps", 0.0) / huge.height_m(), small.knob("run_speed_mps", 0.0) / small.height_m())
	assert_lt(small.knob("run_speed_mps", 0.0) / small.height_m(), 6.0 / 0.95)
	var small_move: Dictionary = small.block("move")
	var huge_move: Dictionary = huge.block("move")
	assert_lt(float(huge_move["turn_rate_deg_per_s"]), float(small_move["turn_rate_deg_per_s"]))
	assert_lt(float(small_move["turn_rate_deg_per_s"]), 1200.0, "slower to turn than Red")
	assert_lt(float(huge_move["ground_accel_mps2"]), float(small_move["ground_accel_mps2"]))
	assert_lt(float(small_move["ground_accel_mps2"]), 95.0)
	assert_gt(small.knob("jump_height_m", 0.0), 1.6)
	assert_gt(huge.knob("jump_height_m", 0.0), small.knob("jump_height_m", 0.0))
	assert_gt(huge.knob("dash_distance_m", 0.0), small.knob("dash_distance_m", 0.0))
	assert_gt(huge.knob("dash_time_ms", 0.0), small.knob("dash_time_ms", 0.0), "a bigger dash takes longer")
	assert_lt(huge.attack_time_scale(), small.attack_time_scale(), "heavier swings")
	assert_lt(small.attack_time_scale(), 1.0)
	assert_lt(huge.idle_speed(), 1.0, "even standing still is slow")


func test_bigger_bodies_sound_lower_and_hit_harder() -> void:
	assert_almost_eq(_form(&"red").sound_pitch(), 1.0, 0.0001)
	assert_lt(_form(&"small").sound_pitch(), 1.0)
	assert_lt(_form(&"huge").sound_pitch(), _form(&"small").sound_pitch())
	assert_gt(float(_form(&"huge").audio()["lowpass_hz"]), 0.0, "the colossus is also muffled")
	assert_gt(_form(&"huge").hitbox_scale(), _form(&"small").hitbox_scale())
	assert_gt(_form(&"small").hitbox_scale(), 1.0)
	assert_gt(_form(&"huge").attack_value("damage_mult", 1.0), _form(&"small").attack_value("damage_mult", 1.0))
	assert_gt(_form(&"huge").attack_value("hit_stop_mult", 1.0), _form(&"small").attack_value("hit_stop_mult", 1.0))
	assert_almost_eq(_form(&"small").f("sword_scale", 1.0), 3.68, 0.001, "the sword grows by the body's factor")
	assert_almost_eq(_form(&"huge").f("sword_scale", 1.0), 52.6, 0.001)


func test_every_knob_the_data_overrides_is_a_real_feel_knob() -> void:
	var knobs: FeelKnobs = FeelKnobs.load_defaults()
	for id: StringName in [&"small", &"huge"]:
		for knob_id: Variant in _form(id).knob_overrides().keys():
			assert_true(knobs.has(str(knob_id)), "%s overrides unknown knob %s" % [id, knob_id])


func test_everything_the_data_names_exists() -> void:
	var fx: Dictionary = DataDB.get_dict("combat/fx")
	var sfx: Dictionary = (DataDB.get_dict("audio/sfx").get("sfx", {}) as Dictionary)
	for id: StringName in [&"small", &"huge"]:
		var profile: ScaleProfile = _form(id)
		assert_true(ResourceLoader.exists(profile.model_path()), "model %s" % profile.model_path())
		var keys_path: String = str(profile.block("anim").get("clip_keys", ""))
		assert_true(FileAccess.file_exists(keys_path), "clip keys %s" % keys_path)
		assert_true((fx["scale_sets"] as Dictionary).has(profile.fx_set()), "fx.json scale_sets.%s" % profile.fx_set())
		assert_true(sfx.has(profile.s("step_sound")), "step sound %s" % profile.s("step_sound"))
		assert_true(sfx.has(profile.s("land_sound")), "land sound %s" % profile.s("land_sound"))
		var set_cfg: Dictionary = (fx["scale_sets"] as Dictionary)[profile.fx_set()] as Dictionary
		assert_true((fx["shake"] as Dictionary).has(str(set_cfg["step_shake"])))
		assert_true((fx["dust"] as Dictionary).has(str(set_cfg["step_dust"])))
	for key: Variant in ScaleProfile.sounds().keys():
		if str(key).begins_with("_"):
			continue
		assert_true(sfx.has(str(ScaleProfile.sounds()[key])), "sequence sound %s" % key)
	assert_true(DataDB.get_dict("text/robot_test").has("board"))
	assert_true(InputMap.has_action("disembark"), "the disembark button exists")


func test_every_camera_cue_names_a_known_view() -> void:
	for kind: StringName in [&"dock", &"undock"]:
		for cue: Variant in ScaleProfile.sequence(kind).get("camera_cues", []) as Array:
			var view: StringName = StringName(str((cue as Dictionary)["view"]))
			assert_false(ScaleProfile.camera_block(view).is_empty(), "view %s exists" % view)
			if (cue as Dictionary).has("world"):
				assert_not_null(ScaleProfile.get_form(StringName(str((cue as Dictionary)["world"]))))


func test_the_docking_timeline_is_the_technical_artists() -> void:
	var dock: Dictionary = ScaleProfile.sequence(&"dock")
	var expected: Dictionary = {"approach": [0.0, 1.0], "doors": [1.0, 1.6], "hop": [1.6, 2.8], "snap": [2.8, 3.0], "lock": [3.0, 3.6], "power_up": [3.6, 4.5]}
	for row: Variant in dock["phases"] as Array:
		var phase: Array = row as Array
		var want: Array = expected[str(phase[0])] as Array
		assert_almost_eq(float(phase[1]), float(want[0]), 0.0001, "%s starts" % phase[0])
		assert_almost_eq(float(phase[2]), float(want[1]), 0.0001, "%s ends" % phase[0])
	assert_eq((dock["phases"] as Array).size(), expected.size())


func test_every_sequence_is_in_order_and_hands_control_back_before_the_end() -> void:
	for kind: StringName in [&"board", &"disembark", &"dock", &"undock"]:
		var seq: RobotSequence = RobotSequence.from_data(kind)
		assert_not_null(seq, "sequence %s" % kind)
		if seq == null:
			continue
		var last_end: float = 0.0
		for phase: StringName in seq.phase_names():
			assert_ge(seq.start_of(phase), 0.0)
			assert_ge(seq.end_of(phase), seq.start_of(phase))
			last_end = maxf(last_end, seq.end_of(phase))
		assert_almost_eq(seq.duration_s, last_end, 0.0001)
		assert_le(seq.control_at_s, seq.duration_s, "%s gives the controls back before it ends" % kind)
		assert_lt(seq.duration_s, 5.0, "no long cutscenes: %s" % kind)


func test_scale_box_grows_the_shape_and_lifts_the_swing_separately() -> void:
	var box: Dictionary = {"shape": "capsule", "radius": 0.45, "height": 1.4, "offset": [0.35, 0.8, 0.8], "rot_deg": [0, 0, 70]}
	assert_eq(ScaleProfile.scale_box(box, 1.0), box, "Red's swing is untouched")
	var big: Dictionary = ScaleProfile.scale_box(box, 10.0, 2.0, 5.0)
	assert_almost_eq(float(big["radius"]), 4.5, 0.0001)
	assert_almost_eq(float(big["height"]), 14.0, 0.0001)
	var offset: Array = big["offset"] as Array
	assert_almost_eq(float(offset[0]), 1.75, 0.0001, "sideways by the reach factor")
	assert_almost_eq(float(offset[1]), 1.6, 0.0001, "height by the lift factor")
	assert_almost_eq(float(offset[2]), 4.0, 0.0001, "forward by the reach factor")
	assert_eq(big["rot_deg"], [0, 0, 70], "the angle never changes")
	assert_almost_eq(float((box["offset"] as Array)[0]), 0.35, 0.0001, "the original is not edited")
	var cube: Dictionary = ScaleProfile.scale_box({"shape": "box", "size": [1.0, 2.0, 3.0], "offset": [0.0, 1.0, 1.0]}, 2.0)
	assert_eq(cube["size"], [2.0, 4.0, 6.0])
	assert_eq(cube["offset"], [0.0, 2.0, 2.0])


func test_scale_attack_scales_damage_knockback_and_hit_stop_and_leaves_red_alone() -> void:
	var attack: Dictionary = {"damage": 8, "knockback_m": 0.6, "hit_stop_ms": 50.0, "hitstun_ms": 320.0, "move_id": &"light_1"}
	assert_eq(_form(&"red").scale_attack(attack), attack)
	var huge: Dictionary = _form(&"huge").scale_attack(attack)
	assert_eq(int(huge["damage"]), 8 * int(_form(&"huge").attack_value("damage_mult", 1.0)))
	assert_almost_eq(float(huge["knockback_m"]), 0.6 * _form(&"huge").attack_value("knockback_mult", 1.0), 0.0001)
	assert_almost_eq(float(huge["hit_stop_ms"]), 50.0 * _form(&"huge").attack_value("hit_stop_mult", 1.0), 0.0001)
	assert_eq(float(huge["hitstun_ms"]), 320.0, "stun is the victim's business")
	assert_eq(huge["move_id"], &"light_1")
	assert_eq(int(attack["damage"]), 8, "the original is not edited")
	var tickle: Dictionary = _form(&"small").scale_attack({"damage": 1})
	assert_ge(int(tickle["damage"]), 1)


func test_merged_player_data_lays_the_form_over_red_and_keeps_the_rest() -> void:
	var base: Dictionary = DataDB.get_dict("combat/player_action")
	var merged: Dictionary = _form(&"huge").merged_player_data(base)
	assert_almost_eq(float((merged["body"] as Dictionary)["radius_m"]), 11.0, 0.001)
	assert_almost_eq(float((merged["move"] as Dictionary)["turn_rate_deg_per_s"]), 70.0, 0.001)
	assert_true((merged["move"] as Dictionary).has("lock_strafe"), "keys the form does not mention stay")
	assert_eq(int(merged["hp_max"]), 6000)
	assert_almost_eq(float((base["body"] as Dictionary)["radius_m"]), 0.3, 0.001, "Red's file is not edited")
	var red: Dictionary = _form(&"red").merged_player_data(base)
	assert_eq(red["move"], base["move"], "the red form changes nothing")
	assert_eq(red["hp_max"], base["hp_max"])


func test_camera_view_is_relative_to_reds_so_the_panels_distance_still_counts() -> void:
	var red: Dictionary = _form(&"red").block("camera")
	var view: Dictionary = ScaleProfile.camera_view(_form(&"huge").block("camera"), red)
	assert_almost_eq(float(view["distance_mult"]), 75.0 / 4.5, 0.001)
	assert_almost_eq(float(view["pivot_mult"]), 26.0 / 0.8, 0.001)
	assert_almost_eq(float(view["fov_mult"]), 56.0 / 62.0, 0.001)
	assert_almost_eq(float(view["min_distance_m"]), 30.0, 0.001)
	var red_view: Dictionary = ScaleProfile.camera_view(red, red)
	assert_almost_eq(float(red_view["distance_mult"]), 1.0, 0.0001)
	assert_almost_eq(float(red_view["fov_mult"]), 1.0, 0.0001)


func test_blend_and_the_easing_curves() -> void:
	var mid: Dictionary = ScaleProfile.blend({"a": 0.0, "only_a": 3.0}, {"a": 10.0, "only_b": 7.0}, 0.5)
	assert_almost_eq(float(mid["a"]), 5.0, 0.0001)
	assert_almost_eq(float(mid["only_a"]), 3.0, 0.0001)
	assert_almost_eq(float(mid["only_b"]), 7.0, 0.0001)
	assert_almost_eq(ScaleProfile.smooth(0.0), 0.0, 0.0001)
	assert_almost_eq(ScaleProfile.smooth(1.0), 1.0, 0.0001)
	assert_almost_eq(ScaleProfile.smooth(0.5), 0.5, 0.0001)
	assert_lt(ScaleProfile.smooth(0.1), 0.1, "eases in")
	assert_gt(ScaleProfile.ease_out(0.1), 0.1, "eases out")
