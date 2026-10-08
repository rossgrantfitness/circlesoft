extends TestCase
## AttackTokens: the cap, release, and a fair queue.

func test_cap_and_release() -> void:
	var tokens: AttackTokens = AttackTokens.create(2)
	assert_true(tokens.request(&"a"))
	assert_true(tokens.request(&"b"))
	assert_false(tokens.request(&"c"), "only two may attack at once")
	assert_eq(tokens.holders().size(), 2)
	tokens.release(&"a")
	assert_true(tokens.request(&"c"))
	assert_has(tokens.holders(), &"c")
	assert_does_not_have(tokens.holders(), &"a")


func test_asking_again_while_holding_is_fine() -> void:
	var tokens: AttackTokens = AttackTokens.create(1)
	assert_true(tokens.request(&"a"))
	assert_true(tokens.request(&"a"))
	assert_eq(tokens.holders().size(), 1)


func test_the_one_who_waited_longest_goes_next() -> void:
	var tokens: AttackTokens = AttackTokens.create(1)
	tokens.request(&"a")
	assert_false(tokens.request(&"b"))
	assert_false(tokens.request(&"c"))
	tokens.release(&"a")
	assert_false(tokens.request(&"c"), "c asked second, b was first in line")
	assert_true(tokens.request(&"b"))
	assert_has(tokens.waiting(), &"c")


func test_releasing_while_waiting_leaves_the_queue() -> void:
	var tokens: AttackTokens = AttackTokens.create(1)
	tokens.request(&"a")
	tokens.request(&"b")
	tokens.release(&"b")
	assert_eq(tokens.waiting().size(), 0)


func test_zero_means_nobody_attacks() -> void:
	var tokens: AttackTokens = AttackTokens.create(0)
	assert_false(tokens.request(&"a"))


func test_the_cap_comes_from_enemies_json() -> void:
	var tokens: AttackTokens = AttackTokens.from_data(CombatData.enemies())
	assert_eq(tokens.max_attackers, 2)


# ---- enemy_ai_design 5: token rules ----

func _ruled(max_count: int = 2) -> AttackTokens:
	var tokens: AttackTokens = AttackTokens.create(max_count)
	tokens.apply_rules(CombatData.enemies().get("token_rules", {}))
	return tokens


func test_the_rules_come_from_enemies_json() -> void:
	var tokens: AttackTokens = AttackTokens.from_data(CombatData.enemies())
	assert_almost_eq(tokens.min_impact_gap_ms, 450.0)
	assert_eq(tokens.max_rear_attackers, 1)
	assert_almost_eq(tokens.flanker_queue_bonus_ms, 1500.0)


func test_two_hits_never_land_less_than_450_ms_apart() -> void:
	var tokens: AttackTokens = _ruled()
	assert_true(tokens.begin_attack(&"a", 560.0, false))
	assert_false(tokens.begin_attack(&"b", 560.0, false), "same moment")
	tokens.step(0.2)
	assert_false(tokens.begin_attack(&"b", 560.0, false), "200 ms later its hit would land 200 ms after a's")
	tokens.step(0.3)
	assert_true(tokens.begin_attack(&"b", 560.0, false), "470 ms later is fine")


func test_the_gap_works_in_both_directions() -> void:
	var tokens: AttackTokens = _ruled()
	assert_true(tokens.begin_attack(&"slow", 900.0, false))
	assert_false(tokens.begin_attack(&"quick", 560.0, false), "560 ms is 340 ms before the slam lands")
	tokens.step(0.5)
	assert_false(tokens.begin_attack(&"quick", 560.0, false), "it would land at 1060, 160 ms after the slam")
	tokens.step(0.35)
	assert_true(tokens.begin_attack(&"quick", 560.0, false), "it would land at 1410, 510 ms after the slam")


func test_a_landed_hit_still_counts_for_the_gap() -> void:
	var tokens: AttackTokens = _ruled()
	tokens.begin_attack(&"a", 100.0, false)
	tokens.step(0.3)     # a's hit landed 200 ms ago
	assert_false(tokens.attack_allowed(&"b", 100.0, false), "b would land 200 ms after a")
	assert_true(tokens.attack_allowed(&"b", 400.0, false), "b would land 600 ms after")
	assert_false(tokens.attack_allowed(&"b", 260.0, false), "460 ms is not enough: a frame of margin keeps it above 450 in play")
	assert_true(tokens.attack_allowed(&"b", 270.0, false), "470 ms is")
	tokens.step(1.0)
	assert_true(tokens.attack_allowed(&"b", 0.0, false), "a's hit is long gone")


func test_a_cut_attack_stops_blocking_others() -> void:
	var tokens: AttackTokens = _ruled()
	tokens.begin_attack(&"a", 560.0, false)
	tokens.release(&"a")      # parried or hit before it landed
	assert_true(tokens.attack_allowed(&"b", 560.0, false))


func test_only_one_enemy_attacks_from_behind() -> void:
	var tokens: AttackTokens = _ruled(4)
	assert_true(tokens.begin_attack(&"a", 710.0, true))
	assert_eq(tokens.rear_attackers(), 1)
	assert_false(tokens.begin_attack(&"b", 2000.0, true), "a second one from behind waits even with a clear gap")
	assert_true(tokens.begin_attack(&"c", 2000.0, false), "a front attacker is fine")
	tokens.end_attack(&"a")
	assert_true(tokens.begin_attack(&"b", 3000.0, true), "once a is done")


func test_a_flanker_jumps_the_queue_but_still_uses_a_token() -> void:
	var tokens: AttackTokens = _ruled(1)
	tokens.request(&"holder")
	assert_false(tokens.request(&"early"))
	tokens.step(1.0)
	assert_false(tokens.request(&"flanker", {"flank": true}), "it still waits for a free token")
	tokens.release(&"holder")
	assert_false(tokens.request(&"early"), "the flanker waited 1 s less but counts as 1.5 s more")
	assert_true(tokens.request(&"flanker", {"flank": true}))
	assert_eq(tokens.holders().size(), 1)


func test_a_flanker_does_not_take_a_second_token() -> void:
	var tokens: AttackTokens = _ruled(2)
	assert_true(tokens.request(&"front"))
	assert_true(tokens.request(&"flanker", {"flank": true}))
	assert_false(tokens.request(&"third"), "never three on her")


func test_giving_a_token_back_clears_the_queue_place_at_once() -> void:
	var tokens: AttackTokens = _ruled(1)
	tokens.request(&"a")
	tokens.request(&"fleeing")
	tokens.release(&"fleeing")
	assert_eq(tokens.waiting().size(), 0)
	tokens.release(&"a")
	assert_true(tokens.request(&"b"))


func test_no_rules_means_old_behaviour() -> void:
	var tokens: AttackTokens = AttackTokens.create(2)
	assert_true(tokens.begin_attack(&"a", 500.0, true))
	assert_true(tokens.begin_attack(&"b", 500.0, true), "without token_rules nothing is limited")
