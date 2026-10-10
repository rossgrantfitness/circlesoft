extends TestCase
## VS-4, Decision 3: how Red talks and uses things. Option A (the attack button talks when a prompt shows and no enemy is
## near) is the default; option B (its own button) is the data switch. Pure rules, no scene.


func _a(clear_m: float = 5.0) -> InteractRules:
	return InteractRules.from_data({"mode": "attack_button", "clear_m": clear_m})


func _b() -> InteractRules:
	return InteractRules.from_data({"mode": "own_button"})


func test_the_data_default_is_option_a() -> void:
	var rules: InteractRules = InteractRules.load_default()
	assert_eq(rules.mode, InteractRules.MODE_ATTACK_BUTTON, "the recommended option is on until Ross decides")
	assert_gt(rules.clear_m, 0.0)
	assert_eq(rules.attack_action, &"light")


func test_unknown_or_missing_data_falls_back_to_option_a() -> void:
	assert_eq(InteractRules.from_data({}).mode, InteractRules.MODE_ATTACK_BUTTON)
	assert_eq(InteractRules.from_data({"mode": "nonsense"}).mode, InteractRules.MODE_ATTACK_BUTTON)
	assert_eq(InteractRules.from_data({}).clear_m, InteractRules.DEFAULT_CLEAR_M)
	assert_eq(InteractRules.from_data({"mode": "own_button"}).mode, InteractRules.MODE_OWN_BUTTON)


func test_in_town_the_attack_button_only_talks() -> void:
	var rules: InteractRules = _a()
	assert_true(rules.attack_press_interacts(true, INF, false), "a prompt is showing")
	assert_true(rules.attack_press_interacts(true, 0.5, false), "town has no fights, so an enemy distance does not matter")
	assert_false(rules.attack_press_interacts(false, INF, false), "no prompt, nothing to talk to")


func test_in_a_dungeon_a_close_enemy_means_attack() -> void:
	var rules: InteractRules = _a(5.0)
	assert_true(rules.attack_press_interacts(true, INF, true), "no enemy at all: use the thing")
	assert_true(rules.attack_press_interacts(true, 5.0, true), "exactly at the clear distance counts as clear")
	assert_false(rules.attack_press_interacts(true, 4.9, true), "an enemy inside the distance: swing")
	assert_false(rules.attack_press_interacts(false, INF, true), "no prompt: swing")


func test_the_clear_distance_is_data() -> void:
	assert_false(_a(8.0).attack_press_interacts(true, 6.0, true))
	assert_true(_a(3.0).attack_press_interacts(true, 6.0, true))


func test_option_b_never_uses_the_attack_button() -> void:
	var rules: InteractRules = _b()
	assert_false(rules.uses_attack_button())
	assert_false(rules.attack_press_interacts(true, INF, false))
	assert_false(rules.attack_press_interacts(true, INF, true))
