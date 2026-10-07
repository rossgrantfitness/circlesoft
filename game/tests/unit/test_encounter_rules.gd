extends TestCase
## First-turn rules from facing: touch an enemy from behind and the party goes first; get caught from
## behind and the enemies go first; face to face (or both turned away) is a normal start.

const RED_AT: Vector3 = Vector3(0.0, 0.0, 0.0)
const ENEMY_AT: Vector3 = Vector3(2.0, 0.0, 0.0)
const EAST: Vector3 = Vector3(1.0, 0.0, 0.0)
const WEST: Vector3 = Vector3(-1.0, 0.0, 0.0)
const NORTH: Vector3 = Vector3(0.0, 0.0, -1.0)


func test_red_sneaks_up_on_an_enemy_facing_away_and_the_party_goes_first() -> void:
	# The enemy is east of Red. Red looks east at it; it also looks east, away from her.
	assert_eq(EncounterRules.first_turn(RED_AT, EAST, ENEMY_AT, EAST), EncounterRules.FIRST_PARTY)


func test_an_enemy_catching_red_from_behind_means_the_enemies_go_first() -> void:
	# The enemy chases (it faces west, toward her); Red is running away, looking west too.
	assert_eq(EncounterRules.first_turn(RED_AT, WEST, ENEMY_AT, WEST), EncounterRules.FIRST_ENEMIES)


func test_face_to_face_is_a_normal_start() -> void:
	assert_eq(EncounterRules.first_turn(RED_AT, EAST, ENEMY_AT, WEST), EncounterRules.FIRST_NORMAL)


func test_both_backs_turned_is_normal() -> void:
	# Red faces west (away from the enemy), the enemy faces east (away from her).
	assert_eq(EncounterRules.first_turn(RED_AT, WEST, ENEMY_AT, EAST), EncounterRules.FIRST_NORMAL)


func test_side_on_meetings_are_normal() -> void:
	# Both look north: neither has a back to the other.
	assert_eq(EncounterRules.first_turn(RED_AT, NORTH, ENEMY_AT, NORTH), EncounterRules.FIRST_NORMAL)
	# Red faces the enemy but it is only side-on (looking north).
	assert_eq(EncounterRules.first_turn(RED_AT, EAST, ENEMY_AT, NORTH), EncounterRules.FIRST_NORMAL)


func test_red_has_to_face_the_enemy_to_ambush_it() -> void:
	# The enemy has its back to her, but she is looking north, not at it.
	assert_eq(EncounterRules.first_turn(RED_AT, NORTH, ENEMY_AT, EAST), EncounterRules.FIRST_NORMAL)


func test_height_is_ignored_and_stacked_positions_are_normal() -> void:
	assert_eq(EncounterRules.first_turn(Vector3(0, 0.5, 0), EAST, Vector3(2, 3.0, 0), EAST), EncounterRules.FIRST_PARTY)
	assert_eq(EncounterRules.first_turn(RED_AT, EAST, RED_AT, EAST), EncounterRules.FIRST_NORMAL, "same spot: no line between them")


func test_the_cutoffs_come_from_data_and_match_the_defaults() -> void:
	var cfg: Dictionary = DataDB.get_dict("world/map_enemies")["first_turn"]
	assert_almost_eq(float(cfg["back_dot"]), EncounterRules.DEFAULT_BACK_DOT)
	assert_almost_eq(float(cfg["facing_dot"]), EncounterRules.DEFAULT_FACING_DOT)
	assert_eq(EncounterRules.first_turn_from_data(RED_AT, EAST, ENEMY_AT, EAST), EncounterRules.FIRST_PARTY)
	assert_eq(EncounterRules.first_turn_from_data(RED_AT, WEST, ENEMY_AT, WEST), EncounterRules.FIRST_ENEMIES)


func test_a_wider_back_cone_catches_more_angles() -> void:
	# The enemy's facing is rotated off "straight away from Red" by 50 and by 70 degrees.
	var near: Vector3 = Vector3(cos(deg_to_rad(50.0)), 0.0, sin(deg_to_rad(50.0)))
	var far: Vector3 = Vector3(cos(deg_to_rad(70.0)), 0.0, sin(deg_to_rad(70.0)))
	assert_eq(EncounterRules.first_turn(RED_AT, EAST, ENEMY_AT, near), EncounterRules.FIRST_PARTY, "50 degrees off is still its back")
	assert_eq(EncounterRules.first_turn(RED_AT, EAST, ENEMY_AT, far), EncounterRules.FIRST_NORMAL, "70 degrees off is too much side-on")
	assert_eq(EncounterRules.first_turn(RED_AT, EAST, ENEMY_AT, far, -0.3), EncounterRules.FIRST_PARTY, "unless the cut-off is looser")
