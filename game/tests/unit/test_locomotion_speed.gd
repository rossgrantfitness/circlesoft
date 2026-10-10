extends TestCase
## LocomotionSpeed: the foot-slide fix. Playback scale = ground speed / the clip's stride, inside the clamp.

const LIMITS: Vector2 = Vector2(0.6, 2.0)


func test_the_scale_tracks_ground_speed() -> void:
	assert_almost_eq(LocomotionSpeed.playback_scale(2.52, 2.52, LIMITS), 1.0)
	assert_almost_eq(LocomotionSpeed.playback_scale(3.78, 2.52, LIMITS), 1.5, 0.001)
	assert_almost_eq(LocomotionSpeed.playback_scale(1.89, 2.52, LIMITS), 0.75, 0.001)
	assert_gt(LocomotionSpeed.playback_scale(4.0, 2.52, LIMITS), LocomotionSpeed.playback_scale(3.0, 2.52, LIMITS))


func test_the_scale_respects_the_clamp() -> void:
	assert_almost_eq(LocomotionSpeed.playback_scale(6.0, 2.52, LIMITS), 2.0, 0.0001, "Red at full run is capped")
	assert_almost_eq(LocomotionSpeed.playback_scale(0.0, 2.52, LIMITS), 0.6, 0.0001, "standing still is floored")
	assert_almost_eq(LocomotionSpeed.playback_scale(-3.0, 2.52, LIMITS), 0.6, 0.0001)
	assert_almost_eq(LocomotionSpeed.playback_scale(1.5, 0.47, Vector2(0.5, 1.5)), 1.5, 0.0001, "custom limits")


func test_the_default_clamp_is_point_six_to_two() -> void:
	assert_almost_eq(LocomotionSpeed.playback_scale(100.0, 1.0), 2.0)
	assert_almost_eq(LocomotionSpeed.playback_scale(0.01, 1.0), 0.6)


func test_an_unknown_stride_leaves_the_clip_alone() -> void:
	assert_almost_eq(LocomotionSpeed.playback_scale(5.0, 0.0, LIMITS), 1.0)
	assert_almost_eq(LocomotionSpeed.playback_scale(5.0, LocomotionSpeed.stride_for({}, &"attack_swing"), LIMITS), 1.0)


func test_the_sprint_blend_starts_past_the_top_of_the_range() -> void:
	assert_almost_eq(LocomotionSpeed.overspeed_blend(5.0, 2.52, LIMITS), 0.0, 0.0001, "1.98x is inside")
	assert_gt(LocomotionSpeed.overspeed_blend(6.0, 2.52, LIMITS), 0.0)
	assert_almost_eq(LocomotionSpeed.overspeed_blend(60.0, 2.52, LIMITS), 1.0, 0.0001)


func test_every_locomotion_clip_has_a_stride_in_the_data() -> void:
	var expected: Dictionary = {
		"res://data/combat/red_clip_keys.json": [&"walk", &"run"],
		"res://data/combat/wolf_clip_keys.json": [&"walk", &"run", &"retreat", &"flee", &"stalk", &"strafe", &"strafe_l", &"strafe_r"],
		"res://data/combat/brute_clip_keys.json": [&"walk", &"run", &"retreat", &"strafe", &"strafe_l", &"strafe_r"],
	}
	for path: String in expected:
		var strides: Dictionary = LocomotionSpeed.load_strides(path)
		for clip: StringName in expected[path]:
			assert_gt(LocomotionSpeed.stride_for(strides, clip), 0.1, "%s %s" % [path, clip])
			assert_lt(LocomotionSpeed.stride_for(strides, clip), 6.0, "%s %s" % [path, clip])
	# attack, dodge and hurt clips carry no stride, so they are never rescaled
	var wolf: Dictionary = LocomotionSpeed.load_strides("res://data/combat/wolf_clip_keys.json")
	for clip: StringName in [&"attack_swing", &"dodge_side", &"hurt", &"knockdown"]:
		assert_false(wolf.has(clip), str(clip))
	assert_almost_eq(LocomotionSpeed.stride_for(LocomotionSpeed.load_strides("res://data/combat/red_clip_keys.json"), &"run"), 2.52, 0.001)
