extends TestCase
## PerfectDodge: the window, the threat zone, and the director's cooldown and one-flare-per-attack rules.

func test_inside_and_outside_the_window() -> void:
	var impact: int = 1000000
	assert_true(PerfectDodge.is_perfect(impact - 120000, impact, 120.0, true), "exactly the window")
	assert_true(PerfectDodge.is_perfect(impact - 1000, impact, 120.0, true))
	assert_true(PerfectDodge.is_perfect(impact, impact, 120.0, true), "dash at the instant of impact")
	assert_false(PerfectDodge.is_perfect(impact - 121000, impact, 120.0, true), "too early")
	assert_false(PerfectDodge.is_perfect(impact + 1000, impact, 120.0, true), "after the hit landed")


func test_outside_the_threat_zone_is_no_dodge() -> void:
	assert_false(PerfectDodge.is_perfect(900000, 1000000, 120.0, false))


func test_point_in_zone_for_each_shape() -> void:
	var xform: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	var sphere: Dictionary = {"shape": "sphere", "radius": 1.0, "offset": [0.0, 0.5, 1.5], "rot_deg": [0, 0, 0]}
	assert_true(PerfectDodge.point_in_box(Vector3(0, 0.5, 1.5), xform, sphere, 0.0))
	assert_true(PerfectDodge.point_in_box(Vector3(0, 0.5, 2.4), xform, sphere, 0.0))
	assert_false(PerfectDodge.point_in_box(Vector3(0, 0.5, 2.6), xform, sphere, 0.0))
	assert_true(PerfectDodge.point_in_box(Vector3(0, 0.5, 2.6), xform, sphere, 0.2), "the margin grows it")
	var box: Dictionary = {"shape": "box", "size": [2.0, 1.0, 2.0], "offset": [0.0, 0.5, 2.0], "rot_deg": [0, 0, 0]}
	assert_true(PerfectDodge.point_in_box(Vector3(0.9, 0.5, 2.9), xform, box, 0.0))
	assert_false(PerfectDodge.point_in_box(Vector3(1.2, 0.5, 2.0), xform, box, 0.0))
	var capsule: Dictionary = {"shape": "capsule", "radius": 0.5, "height": 2.0, "offset": [0.0, 0.5, 1.0], "rot_deg": [0, 0, 90]}
	assert_true(PerfectDodge.point_in_box(Vector3(0.9, 0.5, 1.0), xform, capsule, 0.0), "lying on its side, it reaches along x")
	assert_false(PerfectDodge.point_in_box(Vector3(0.0, 1.5, 1.0), xform, capsule, 0.0))


func test_the_zone_follows_the_attackers_facing() -> void:
	var facing_x: Transform3D = Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(90), 0)), Vector3(5, 0, 0))
	var sphere: Dictionary = {"shape": "sphere", "radius": 0.5, "offset": [0.0, 0.5, 2.0], "rot_deg": [0, 0, 0]}
	assert_true(PerfectDodge.point_in_zone(Vector3(7, 0.5, 0), facing_x, [sphere], 0.0), "+Z turned to +X")
	assert_false(PerfectDodge.point_in_zone(Vector3(5, 0.5, 2), facing_x, [sphere], 0.0))
	assert_false(PerfectDodge.point_in_zone(Vector3(7, 0.5, 0), facing_x, [], 0.0), "no boxes, no zone")
