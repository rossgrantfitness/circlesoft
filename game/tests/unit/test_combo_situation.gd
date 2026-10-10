extends TestCase
## ComboSituation: what the world looks like to the combo selector.

const PARAMS: Dictionary = {"near_radius_m": 3.0, "lunge_max_dist_m": 12.0}


## A stand-in fighter.
class Fighter extends Node3D:
	var launchable: bool = true
	var airborne: bool = false
	var armored: bool = false
	var guarding: bool = false

	func is_airborne() -> bool:
		return airborne

	func is_armored() -> bool:
		return armored

	func is_guarding() -> bool:
		return guarding


func _fighter(at: Vector3) -> Fighter:
	var node: Fighter = Fighter.new()
	add_to_root(node)
	node.global_position = at
	return node


func test_a_plain_target_reports_its_distance() -> void:
	var target: Fighter = _fighter(Vector3(0, 0, -6))
	var sit: Dictionary = ComboSituation.describe(Vector3.ZERO, target, [target], PARAMS)
	assert_true(sit["target_exists"])
	assert_almost_eq(float(sit["target_dist_m"]), 6.0)
	assert_false(sit["target_airborne"])
	assert_true(sit["target_launchable"])
	assert_false(sit["target_guarding"])


func test_height_does_not_count_in_the_distance() -> void:
	var target: Fighter = _fighter(Vector3(3, 4, 0))
	var sit: Dictionary = ComboSituation.describe(Vector3.ZERO, target, [target], PARAMS)
	assert_almost_eq(float(sit["target_dist_m"]), 3.0)


func test_no_target_means_none_exists_and_it_can_be_launched() -> void:
	var sit: Dictionary = ComboSituation.describe(Vector3.ZERO, null, [], PARAMS)
	assert_false(sit["target_exists"])
	assert_true(sit["target_launchable"], "nothing there must not read as a target that refuses a launcher")
	assert_eq(sit["enemies_near"], 0)


func test_a_target_past_the_lunge_range_does_not_exist() -> void:
	var target: Fighter = _fighter(Vector3(0, 0, 12.5))
	assert_false(ComboSituation.describe(Vector3.ZERO, target, [target], PARAMS)["target_exists"])
	var edge: Fighter = _fighter(Vector3(0, 0, 12.0))
	assert_true(ComboSituation.describe(Vector3.ZERO, edge, [edge], PARAMS)["target_exists"])


func test_airborne_armored_and_guarding_targets_are_read_from_the_fighter() -> void:
	var target: Fighter = _fighter(Vector3(0, 0, 2))
	target.airborne = true
	assert_true(ComboSituation.describe(Vector3.ZERO, target, [target], PARAMS)["target_airborne"])
	target.armored = true
	assert_true(ComboSituation.describe(Vector3.ZERO, target, [target], PARAMS)["target_guarding"], "armored counts as guarding")
	target.armored = false
	target.guarding = true
	assert_true(ComboSituation.describe(Vector3.ZERO, target, [target], PARAMS)["target_guarding"], "a raised guard counts")


func test_a_target_that_cannot_be_launched_says_so() -> void:
	var target: Fighter = _fighter(Vector3(0, 0, 2))
	target.launchable = false
	assert_false(ComboSituation.describe(Vector3.ZERO, target, [target], PARAMS)["target_launchable"])


func test_enemies_near_counts_everyone_inside_the_near_radius() -> void:
	var list: Array = [_fighter(Vector3(1, 0, 0)), _fighter(Vector3(0, 0, 2.9)), _fighter(Vector3(3.1, 0, 0)), _fighter(Vector3(0, 0, -10))]
	var sit: Dictionary = ComboSituation.describe(Vector3.ZERO, list[0] as Node3D, list, PARAMS)
	assert_eq(sit["enemies_near"], 2)


func test_pick_target_without_a_lock_takes_the_enemy_in_the_cone_nearest_the_aim() -> void:
	var red: Node3D = _fighter(Vector3.ZERO)
	var ahead: Fighter = _fighter(Vector3(0, 0, 8))
	var side: Fighter = _fighter(Vector3(5, 0, 0))
	var picked: Node3D = ComboSituation.pick_target(red, [ahead, side], null, Vector3.ZERO, Vector3(0, 0, 1), 12.0, 140.0)
	assert_eq(picked, ahead, "no stick: she aims along her facing")
	var stick_side: Node3D = ComboSituation.pick_target(red, [ahead, side], null, Vector3(1, 0, 0), Vector3(0, 0, 1), 12.0, 140.0)
	assert_eq(stick_side, side, "the stick points at the other one")


func test_pick_target_ignores_enemies_behind_her_or_out_of_range() -> void:
	var red: Node3D = _fighter(Vector3.ZERO)
	var behind: Fighter = _fighter(Vector3(0, 0, -5))
	var far: Fighter = _fighter(Vector3(0, 0, 15))
	assert_null(ComboSituation.pick_target(red, [behind, far], null, Vector3.ZERO, Vector3(0, 0, 1), 12.0, 140.0))
