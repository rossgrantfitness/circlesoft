extends TestCase
## CS-21: RobotSequence, the clock of the boarding and docking sequences: phases in order, each event once, hit-stop, camera cues.

const DT: float = 1.0 / 60.0


func _run_dock() -> Array[StringName]:
	var seq: RobotSequence = RobotSequence.from_data(&"dock")
	assert_not_null(seq)
	var events: Array[StringName] = []
	var guard: int = 0
	while not seq.is_done() and guard < 1000:
		events.append_array(seq.tick(DT))
		guard += 1
	return events


func test_the_docking_states_come_in_the_technical_artists_order() -> void:
	var events: Array[StringName] = _run_dock()
	var order: Array[StringName] = []
	for event: StringName in events:
		if str(event).begins_with("begin:"):
			order.append(StringName(str(event).trim_prefix("begin:")))
	assert_eq(order, [&"approach", &"doors", &"hop", &"snap", &"lock", &"power_up"])
	var ends: Array[StringName] = []
	for event: StringName in events:
		if str(event).begins_with("end:"):
			ends.append(StringName(str(event).trim_prefix("end:")))
	assert_eq(ends, [&"approach", &"doors", &"hop", &"snap", &"lock", &"power_up"], "each phase ends before the next ends")


func test_every_event_fires_exactly_once() -> void:
	var events: Array[StringName] = _run_dock()
	var seen: Dictionary = {}
	for event: StringName in events:
		assert_false(seen.has(event), "%s fired twice" % event)
		seen[event] = true
	assert_true(seen.has(&"swap"))
	assert_true(seen.has(&"control"))
	assert_true(seen.has(&"done"))


func test_the_swap_comes_at_the_start_of_the_power_up_and_control_just_before_the_end() -> void:
	var seq: RobotSequence = RobotSequence.from_data(&"dock")
	var swap_time: float = -1.0
	var control_time: float = -1.0
	var done_time: float = -1.0
	var guard: int = 0
	while not seq.is_done() and guard < 1000:
		for event: StringName in seq.tick(DT):
			if event == &"swap":
				swap_time = seq.time_s
			elif event == &"control":
				control_time = seq.time_s
			elif event == &"done":
				done_time = seq.time_s
		guard += 1
	assert_almost_eq(swap_time, 3.6, 0.03, "the huge robot takes over when the power-up begins")
	assert_gt(control_time, swap_time)
	assert_lt(control_time, done_time, "the player has the controls before the sequence is over")
	assert_almost_eq(done_time, 4.5, 0.03)


func test_progress_is_zero_before_one_after_and_linear_inside() -> void:
	var seq: RobotSequence = RobotSequence.from_data(&"dock")
	assert_almost_eq(seq.progress(&"hop"), 0.0, 0.0001)
	seq.tick(1.6 + 0.6)
	assert_almost_eq(seq.progress(&"hop"), 0.5, 0.0001, "halfway through the 1.2 s hop")
	assert_almost_eq(seq.progress(&"approach"), 1.0, 0.0001)
	assert_almost_eq(seq.progress(&"lock"), 0.0, 0.0001)
	assert_eq(seq.phase_name(), &"hop")
	assert_almost_eq(seq.progress(&"no_such_phase"), 0.0, 0.0001)


func test_freeze_holds_the_clock_for_the_hit_stop() -> void:
	var seq: RobotSequence = RobotSequence.from_data(&"dock")
	seq.tick(2.9)
	var before: float = seq.time_s
	seq.freeze(0.08)
	assert_true(seq.is_frozen())
	seq.tick(0.05)
	assert_almost_eq(seq.time_s, before, 0.0001, "frozen")
	seq.tick(0.05)
	assert_almost_eq(seq.time_s, before + 0.02, 0.0001, "the rest of that step runs after the freeze")
	assert_false(seq.is_frozen())


func test_a_big_step_still_fires_everything_in_order() -> void:
	var seq: RobotSequence = RobotSequence.from_data(&"dock")
	var events: Array[StringName] = seq.tick(10.0)
	assert_true(events.has(&"done"))
	assert_true(events.find(&"begin:doors") < events.find(&"begin:hop"))
	assert_true(seq.is_done())


func test_camera_cues_come_out_once_when_their_time_comes() -> void:
	var seq: RobotSequence = RobotSequence.from_data(&"dock")
	assert_eq(seq.take_cues().size(), 0)
	seq.tick(1.5)
	assert_eq(seq.take_cues().size(), 0, "not yet")
	seq.tick(0.2)
	var cues: Array[Dictionary] = seq.take_cues()
	assert_eq(cues.size(), 1)
	assert_eq(str(cues[0]["view"]), "dock_lift")
	assert_eq(seq.take_cues().size(), 0, "once")


func test_a_missing_sequence_is_null_and_a_config_can_be_built_by_hand() -> void:
	assert_null(RobotSequence.from_data(&"no_such"))
	var seq: RobotSequence = RobotSequence.from_config(&"test", {"phases": [["a", 0.0, 1.0], ["b", 1.0, 2.0]], "control_at_s": 1.5})
	var events: Array[StringName] = seq.tick(2.0)
	assert_eq(events, [&"begin:a", &"end:a", &"begin:b", &"end:b", &"control", &"done"])
