extends TestCase
## RadioQueue: the radio bark box's line queue. Pure.


func test_a_line_types_out_holds_and_leaves() -> void:
	var queue: RadioQueue = RadioQueue.new()
	assert_true(queue.is_idle())
	assert_true(queue.say("vela", "Turret on your left."))
	assert_true(queue.is_showing())
	assert_eq(queue.chars_shown(), 0, "it slides in before the first letter")
	queue.tick(0.18 + 0.2)
	assert_gt(float(queue.chars_shown()), 0.0)
	assert_lt(float(queue.chars_shown()), 20.0)
	queue.tick(1.0)
	assert_eq(queue.chars_shown(), 20, "all the letters")
	queue.tick(queue.line_life_s())
	assert_false(queue.is_showing())
	assert_true(queue.is_idle())


func test_lines_wait_their_turn_in_order() -> void:
	var queue: RadioQueue = RadioQueue.new()
	queue.say("vela", "First.")
	queue.say("vela", "Second.")
	assert_eq(str(queue.current["text"]), "First.")
	assert_eq(queue.queue.size(), 1)
	queue.tick(queue.line_life_s() + 0.01)
	queue.tick(0.5)
	assert_eq(str(queue.current["text"]), "Second.")


func test_a_priority_line_jumps_the_queue() -> void:
	var queue: RadioQueue = RadioQueue.new()
	queue.say("vela", "Now showing.")
	queue.say("vela", "Waiting.")
	queue.say("vela", "Urgent!", true)
	assert_eq(str(queue.queue[0]["text"]), "Urgent!")


func test_the_same_line_is_not_queued_twice() -> void:
	var queue: RadioQueue = RadioQueue.new()
	assert_true(queue.say("vela", "Watch out."))
	assert_false(queue.say("vela", "Watch out."), "already on screen")
	queue.say("vela", "Other.")
	assert_false(queue.say("vela", "Other."), "already waiting")
	assert_true(queue.say("kasp", "Watch out."), "another speaker is another line")
	assert_false(queue.say("vela", "   "), "blank lines are ignored")


func test_the_queue_is_capped() -> void:
	var queue: RadioQueue = RadioQueue.new()
	for i: int in 20:
		queue.say("vela", "Line %d" % i)
	assert_le(float(queue.queue.size()), float(SliceUiData.whole("radio.queue_max", 6)))


func test_longer_lines_hold_longer() -> void:
	var queue: RadioQueue = RadioQueue.new()
	assert_gt(queue.hold_s("A much longer line of chatter over the radio."), queue.hold_s("Go."))


func test_presence_slides_in_and_fades_out() -> void:
	var queue: RadioQueue = RadioQueue.new()
	assert_eq(queue.presence(), 0.0)
	queue.say("vela", "Hi.")
	queue.tick(0.05)
	assert_gt(queue.presence(), 0.0)
	assert_lt(queue.presence(), 1.0)
	queue.tick(0.5)
	assert_eq(queue.presence(), 1.0)
	queue.tick(queue.line_life_s() - 0.55 - 0.1)
	assert_lt(queue.presence(), 1.0)
