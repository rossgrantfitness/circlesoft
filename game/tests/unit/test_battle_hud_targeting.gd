extends TestCase
## BattleTargeting and BattleRoster: who a move can hit and how the pointer hops (no nodes needed).

const ENEMY_POINTS: Dictionary = {
	"e1": Vector2(160, 76), "e2": Vector2(124, 96), "e3": Vector2(196, 96), "e4": Vector2(160, 116),
	"red": Vector2(300, 80), "otis": Vector2(320, 100), "mox": Vector2(280, 100),
}


func _roster() -> BattleRoster:
	var roster: BattleRoster = BattleRoster.new()
	var snap: Dictionary = BattleHudStub.default_snapshot()
	(snap["combatants"] as Array).append(BattleHudStub.combatant("e4", "enemy", 3, "Hegemony Grunt", "hegemony_grunt", 30, 30, 0, 0))
	roster.load_snapshot(snap)
	return roster


func _pos(id: String) -> Vector2:
	return ENEMY_POINTS.get(id, Vector2.ZERO)


func _start(kind: String, roster: BattleRoster, remembered: String = "") -> BattleTargeting:
	var targeting: BattleTargeting = BattleTargeting.new()
	targeting.start(kind, roster, "red", _pos, remembered)
	return targeting


func test_candidates_for_every_target_kind() -> void:
	var roster: BattleRoster = _roster()
	roster.set_down("otis", true)
	roster.set_down("e2", true)
	assert_eq(BattleTargeting.candidates_for("one_enemy", roster, "red"), ["e1", "e3", "e4"])
	assert_eq(BattleTargeting.candidates_for("all_enemies", roster, "red"), ["e1", "e3", "e4"])
	assert_eq(BattleTargeting.candidates_for("one_ally", roster, "red"), ["red", "mox"])
	assert_eq(BattleTargeting.candidates_for("all_allies", roster, "red"), ["red", "mox"])
	assert_eq(BattleTargeting.candidates_for("one_down_ally", roster, "red"), ["otis"])
	assert_eq(BattleTargeting.candidates_for("self", roster, "red"), ["red"])


func test_an_unknown_kind_is_treated_as_one_enemy() -> void:
	assert_eq(BattleTargeting.normalize("primary"), "one_enemy")
	assert_eq(BattleTargeting.normalize("all_allies"), "all_allies")
	assert_true(BattleTargeting.is_all_kind("all_enemies"))
	assert_false(BattleTargeting.is_all_kind("one_enemy"))
	assert_true(BattleTargeting.needs_no_pick("self"))


func test_all_kinds_select_the_whole_side_and_never_move() -> void:
	var targeting: BattleTargeting = _start("all_enemies", _roster())
	assert_true(targeting.is_all)
	assert_eq(targeting.selected_ids(), ["e1", "e2", "e3", "e4"])
	assert_false(targeting.move(Vector2i(1, 0)))


func test_single_kinds_select_one_and_start_on_the_remembered_target() -> void:
	var roster: BattleRoster = _roster()
	assert_eq(_start("one_enemy", roster).selected_ids(), ["e1"])
	assert_eq(_start("one_enemy", roster, "e3").selected_ids(), ["e3"])
	assert_eq(_start("one_enemy", roster, "nobody").selected_ids(), ["e1"])
	roster.set_down("e3", true)
	assert_eq(_start("one_enemy", roster, "e3").selected_ids(), ["e1"], "a fallen target is not remembered")


func test_start_reports_when_nobody_can_be_aimed_at() -> void:
	var roster: BattleRoster = _roster()
	var targeting: BattleTargeting = BattleTargeting.new()
	assert_false(targeting.start("one_down_ally", roster, "red", _pos))
	assert_eq(targeting.selected_ids(), [])


func test_the_pointer_hops_to_the_nearest_enemy_in_the_pressed_direction() -> void:
	var targeting: BattleTargeting = _start("one_enemy", _roster())
	targeting.move(Vector2i(0, 1))  # down from e1 (160,76): e4 (160,116) is straight below
	assert_eq(targeting.get_selected(), "e4")
	targeting.move(Vector2i(-1, 0))  # left of e4
	assert_eq(targeting.get_selected(), "e2")
	targeting.move(Vector2i(1, 0))
	assert_eq(targeting.get_selected(), "e3", "right of e2 is e3 (same row), not e4")


func test_the_pointer_wraps_when_nothing_lies_further_that_way() -> void:
	var targeting: BattleTargeting = _start("one_enemy", _roster())
	targeting.move(Vector2i(0, -1))  # nothing above e1: wraps to the previous in the list (the last)
	assert_eq(targeting.get_selected(), "e4")
	targeting.move(Vector2i(0, 1))  # nothing below e4: wraps to the next in the list (the first)
	assert_eq(targeting.get_selected(), "e1")


func test_when_positions_are_unknown_the_arrows_still_walk_the_list() -> void:
	var roster: BattleRoster = _roster()
	var targeting: BattleTargeting = BattleTargeting.new()
	targeting.start("one_enemy", roster, "red", func(_id: String) -> Vector2: return Vector2.ZERO)
	targeting.move(Vector2i(1, 0))
	assert_eq(targeting.get_selected(), "e2")
	targeting.move(Vector2i(-1, 0))
	targeting.move(Vector2i(-1, 0))
	assert_eq(targeting.get_selected(), "e4")


func test_pick_at_finds_the_nearest_candidate_in_range() -> void:
	var targeting: BattleTargeting = _start("one_enemy", _roster())
	assert_eq(targeting.pick_at(Vector2(125, 98), 20.0), "e2")
	assert_eq(targeting.pick_at(Vector2(10, 10), 20.0), "")


func test_roster_tracks_hp_status_down_and_fled() -> void:
	var roster: BattleRoster = _roster()
	roster.set_stats("red", 5, 42, 2, 12)
	assert_eq(roster.get_member("red")["hp"], 5)
	roster.set_status("red", "wobbly", true)
	roster.set_status("red", "wobbly", true)
	assert_eq(roster.statuses_of("red"), ["wobbly"], "no duplicates")
	roster.set_status("red", "wobbly", false)
	assert_false(roster.has_status("red", "wobbly"))
	roster.set_down("mox", true)
	assert_eq(roster.live_ids("party"), ["red", "otis"])
	assert_eq(roster.down_ids("party"), ["mox"])
	roster.set_fled("e1")
	assert_true(roster.is_out("e1"))
	assert_false(roster.is_down("e1"))
	assert_eq(roster.down_ids("enemy"), [])
	assert_false(roster.all_out("enemy"))
	for id: String in ["e2", "e3", "e4"]:
		roster.set_down(id, true)
	assert_true(roster.all_out("enemy"))


func test_a_snapshot_member_with_zero_hp_starts_down() -> void:
	var snap: Dictionary = BattleHudStub.default_snapshot()
	(snap["combatants"] as Array)[2]["hp"] = 0
	var roster: BattleRoster = BattleRoster.new()
	roster.load_snapshot(snap)
	assert_true(roster.is_down("mox"))


func test_enemy_heads_number_duplicates_and_tell_kinds_apart() -> void:
	var roster: BattleRoster = _roster()
	assert_eq(BattleHeads.ordinal_for("e1", roster), 1)
	assert_eq(BattleHeads.ordinal_for("e2", roster), 2)
	assert_eq(BattleHeads.ordinal_for("e3", roster), 0, "the lone drone needs no number")
	assert_eq(BattleHeads.ordinal_for("red", roster), 0)
	assert_eq(BattleHeads.initial_for("e1", roster), "G")
	assert_eq(BattleHeads.initial_for("e3", roster), "D")
	assert_eq(BattleHeads.initial_for("red", roster), "R")
