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
