extends TestCase
## ComboString: where Red is in her string, and when the string forgets itself.

const MS: int = 1000


func test_a_fresh_string_is_idle() -> void:
	var string: ComboString = ComboString.create(500.0)
	assert_eq(string.from_move(0, false), &"idle")
	assert_eq(string.pos(), 0)


func test_each_move_of_the_string_counts_one_hit() -> void:
	var string: ComboString = ComboString.create(500.0)
	string.begin(&"light_1", true)
	assert_eq(string.pos(), 1)
	string.begin(&"light_2", false)
	string.begin(&"light_3", false)
	assert_eq(string.pos(), 3)
	assert_eq(string.last_move(), &"light_3")


func test_restart_puts_the_count_back_to_one() -> void:
	var string: ComboString = ComboString.create(500.0)
	for id: StringName in [&"light_1", &"light_2", &"light_3", &"launcher"]:
		string.begin(id, id == &"light_1")
	assert_eq(string.pos(), 4)
	string.begin(&"light_1", true)
	assert_eq(string.pos(), 1)


func test_while_a_move_plays_the_string_stays_however_long_it_takes() -> void:
	var string: ComboString = ComboString.create(500.0)
	string.begin(&"heavy", true)
	assert_eq(string.from_move(5000 * MS, true), &"heavy", "still playing")
	assert_eq(string.from_move(5000 * MS, false), &"heavy", "not ended yet, so it is not timing out")


func test_the_string_forgets_itself_500_ms_after_the_move_ends() -> void:
	var string: ComboString = ComboString.create(500.0)
	string.begin(&"light_2", true)
	string.end(1000 * MS)
	assert_eq(string.from_move(1500 * MS, false), &"light_2", "exactly at the limit still counts")
	assert_eq(string.from_move(1501 * MS, false), &"idle")
	assert_true(string.expired(1501 * MS))
	assert_false(string.expired(1400 * MS))


func test_end_is_remembered_once() -> void:
	var string: ComboString = ComboString.create(500.0)
	string.begin(&"light_1", true)
	string.end(100 * MS)
	string.end(300 * MS)                 # a second call must not push the timeout later
	assert_eq(string.from_move(601 * MS, false), &"idle")


func test_a_new_move_cancels_the_timeout() -> void:
	var string: ComboString = ComboString.create(500.0)
	string.begin(&"light_1", true)
	string.end(100 * MS)
	string.begin(&"light_2", false)
	assert_eq(string.from_move(9000 * MS, true), &"light_2")


func test_reset_clears_everything() -> void:
	var string: ComboString = ComboString.create(500.0)
	string.begin(&"light_1", true)
	string.reset()
	assert_eq(string.pos(), 0)
	assert_eq(string.from_move(0, true), &"idle")


func test_the_timeout_comes_from_the_data() -> void:
	var doc: Dictionary = CombatData.combo()
	var string: ComboString = ComboString.create(ComboSelector.from_data(doc).param("string_timeout_ms", 0.0))
	assert_almost_eq(string.timeout_ms, 500.0)
