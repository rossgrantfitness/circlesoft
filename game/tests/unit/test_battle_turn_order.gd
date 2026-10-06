extends TestCase
## Turn order: fastest first every round, ties go to the party, then by slot.


func _fighter(id: String, side: String, slot: int, speed: int) -> BattleCombatant:
	var c: BattleCombatant = BattleCombatant.new()
	c.id = id
	c.side = side
	c.slot = slot
	c.stats = {"speed": speed}
	return c


func _line_up(specs: Array) -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []
	for spec: Array in specs:
		out.append(_fighter(str(spec[0]), str(spec[1]), int(spec[2]), int(spec[3])))
	return out


func test_fastest_acts_first() -> void:
	var members: Array[BattleCombatant] = _line_up([["red", "party", 0, 9], ["e1", "enemy", 0, 5], ["otis", "party", 1, 4], ["e2", "enemy", 1, 11]])
	assert_eq(BattleTurnOrder.ids(members), ["e2", "red", "e1", "otis"] as Array[String])


func test_ties_go_to_the_party_first() -> void:
	var members: Array[BattleCombatant] = _line_up([["e1", "enemy", 0, 7], ["mox", "party", 2, 7], ["e2", "enemy", 1, 7], ["red", "party", 0, 7]])
	assert_eq(BattleTurnOrder.ids(members), ["red", "mox", "e1", "e2"] as Array[String], "party first, then by slot")


func test_a_tie_inside_a_side_goes_by_slot() -> void:
	var members: Array[BattleCombatant] = _line_up([["e3", "enemy", 2, 6], ["e1", "enemy", 0, 6], ["e2", "enemy", 1, 6]])
	assert_eq(BattleTurnOrder.ids(members), ["e1", "e2", "e3"] as Array[String])


func test_the_input_order_does_not_matter() -> void:
	var a: Array[BattleCombatant] = _line_up([["red", "party", 0, 9], ["e1", "enemy", 0, 9], ["otis", "party", 1, 4]])
	var b: Array[BattleCombatant] = [a[2], a[1], a[0]]
	assert_eq(BattleTurnOrder.ids(a), BattleTurnOrder.ids(b))


func test_free_first_turn_puts_a_whole_side_ahead() -> void:
	var members: Array[BattleCombatant] = _line_up([["red", "party", 0, 3], ["e1", "enemy", 0, 12], ["otis", "party", 1, 2]])
	assert_eq(BattleTurnOrder.ids(members, "party"), ["red", "otis", "e1"] as Array[String], "party gets the free first turn")
	assert_eq(BattleTurnOrder.ids(members, "enemies"), ["e1", "red", "otis"] as Array[String], "caught from behind")
	assert_eq(BattleTurnOrder.ids(members, "normal"), ["e1", "red", "otis"] as Array[String])


func test_the_order_inside_a_free_first_turn_still_follows_speed() -> void:
	var members: Array[BattleCombatant] = _line_up([["otis", "party", 1, 2], ["red", "party", 0, 9], ["e1", "enemy", 0, 12]])
	assert_eq(BattleTurnOrder.ids(members, "party"), ["red", "otis", "e1"] as Array[String])


func test_real_party_speeds_put_red_before_mox_before_otis() -> void:
	var data: BattleData = BattleData.shared()
	var progression: Progression = Progression.new(data)
	var order: Array[BattleCombatant] = []
	for char_id: String in data.character_order:
		var c: BattleCombatant = BattleCombatant.new()
		c.id = char_id
		c.stats = progression.stats_at(char_id, 1)
		order.append(c)
	assert_eq(BattleTurnOrder.ids(order), ["red", "mox", "otis"] as Array[String])
