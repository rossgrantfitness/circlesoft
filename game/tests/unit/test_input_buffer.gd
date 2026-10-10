extends TestCase
## InputBuffer: a press made a little early still counts, and it waits on Red's clock.

const MS: int = 1000


func _any(_token: StringName) -> bool:
	return true


func test_take_returns_the_oldest_accepted_token_and_removes_it() -> void:
	var buffer: InputBuffer = InputBuffer.new()
	buffer.push(&"light", 0)
	buffer.push(&"heavy", 10 * MS)
	assert_eq(buffer.take(20 * MS, _any), &"light")
	assert_eq(buffer.take(20 * MS, _any), &"heavy")
	assert_eq(buffer.take(20 * MS, _any), &"")


func test_tokens_the_caller_refuses_stay_for_later() -> void:
	var buffer: InputBuffer = InputBuffer.new()
	buffer.push(&"light", 0)
	buffer.push(&"jump", 5 * MS)
	var only_jump: Callable = func(token: StringName) -> bool: return token == &"jump"
	assert_eq(buffer.take(10 * MS, only_jump), &"jump")
	assert_eq(buffer.size(), 1)
	assert_eq(buffer.take(20 * MS, _any), &"light")


func test_buffered_presses_expire_after_input_buffer_ms() -> void:
	var buffer: InputBuffer = InputBuffer.new()
	buffer.buffer_ms = 150.0
	buffer.push(&"light", 0)
	assert_true(buffer.has_token(&"light", 150 * MS), "exactly at the limit is still inside")
	assert_false(buffer.has_token(&"light", 151 * MS), "one ms later it is gone")
	assert_eq(buffer.take(151 * MS, _any), &"")


func test_nothing_expires_while_red_is_frozen_in_hit_stop() -> void:
	# Red's clock does not move in hit-stop, so `now` stays put however long it lasts in real time.
	var clock: CombatClock = CombatClock.new()
	var buffer: InputBuffer = InputBuffer.new()
	buffer.buffer_ms = 150.0
	clock.step(100 * MS, 1.0)
	buffer.push(&"light", clock.now_usec())
	for i: int in range(30):
		clock.step(16667, 0.0)      # half a second of real hit-stop
	assert_eq(buffer.take(clock.now_usec(), _any), &"light")


func test_a_press_made_during_hit_stop_is_stamped_in_local_time() -> void:
	var clock: CombatClock = CombatClock.new(0)
	clock.step(100 * MS, 1.0)
	clock.step(200 * MS, 0.0)
	var stamp: int = clock.local_at_real(250 * MS)
	assert_eq(stamp, 100 * MS)
	var buffer: InputBuffer = InputBuffer.new()
	buffer.push(&"light", stamp)
	clock.step(100 * MS, 1.0)
	assert_eq(buffer.take(clock.now_usec(), _any), &"light", "only 100 ms of Red's time passed")


func test_length_is_read_from_the_knob_at_take_time() -> void:
	var knobs: FeelKnobs = FeelKnobs.load_defaults()
	var buffer: InputBuffer = InputBuffer.create(knobs)
	buffer.push(&"light", 0)
	knobs.set_value("input_buffer_ms", 50)
	assert_false(buffer.has_token(&"light", 80 * MS), "shortened knob applies at once")
	buffer.push(&"heavy", 100 * MS)
	knobs.set_value("input_buffer_ms", 400)
	assert_true(buffer.has_token(&"heavy", 450 * MS))


func test_clear_and_cap() -> void:
	var buffer: InputBuffer = InputBuffer.new()
	for i: int in range(40):
		buffer.push(&"light", i)
	assert_le(buffer.size(), InputBuffer.MAX_TOKENS)
	buffer.clear()
	assert_eq(buffer.size(), 0)


func test_peek_leaves_the_token_in_place() -> void:
	var buffer: InputBuffer = InputBuffer.new()
	buffer.push(&"dash", 0)
	assert_eq(buffer.peek(MS, _any), &"dash")
	assert_eq(buffer.size(), 1)


func test_hold_latest_keeps_one_waiting_press_alive_past_the_buffer_time() -> void:
	var buffer: InputBuffer = InputBuffer.new()
	buffer.buffer_ms = 150.0
	buffer.push(&"light", 0)
	buffer.push(&"light", 40 * MS)
	buffer.push(&"jump", 50 * MS)
	assert_true(buffer.hold_latest(&"light", 100 * MS))
	assert_eq(buffer.size(), 2, "the older light was dropped, the jump is untouched")
	assert_true(buffer.has_token(&"light", 240 * MS), "re-stamped at 100 ms, so it lives until 250 ms")
	assert_false(buffer.has_token(&"light", 260 * MS))


func test_hold_latest_with_nothing_waiting_does_nothing() -> void:
	var buffer: InputBuffer = InputBuffer.new()
	buffer.push(&"jump", 0)
	assert_false(buffer.hold_latest(&"light", 10 * MS))
	assert_eq(buffer.size(), 1)
