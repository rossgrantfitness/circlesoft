extends TestCase
## CS-21: which footfalls of a looping walk or run clip the playhead passed since last look (ScaleSteps.crossed).

const WALK_TIMES: Array = [0.333, 1.0]
const RUN_TIMES: Array = [0.033, 0.367]


func test_a_step_is_when_the_playhead_passes_a_footfall() -> void:
	assert_eq(ScaleSteps.crossed(0.30, 0.35, 1.0, WALK_TIMES), [0])
	assert_eq(ScaleSteps.crossed(0.10, 0.20, 1.0, WALK_TIMES), [])
	assert_eq(ScaleSteps.crossed(0.40, 0.90, 1.0, WALK_TIMES), [])


func test_the_footfall_at_the_end_of_the_loop_is_the_wrap() -> void:
	assert_eq(ScaleSteps.crossed(0.95, 0.05, 1.0, WALK_TIMES), [1], "wrapping the loop plants the right foot")
	assert_eq(ScaleSteps.crossed(0.98, 0.99, 1.0, WALK_TIMES), [], "not before the wrap")


func test_a_wrap_can_also_pass_a_footfall_early_in_the_next_loop() -> void:
	assert_eq(ScaleSteps.crossed(0.90, 0.10, 1.0, RUN_TIMES), [0], "run: 0.033 just after the wrap")
	assert_eq(ScaleSteps.crossed(0.30, 0.40, 1.0, RUN_TIMES), [1])


func test_one_pass_counts_once() -> void:
	var steps: int = 0
	var pos: float = 0.0
	for i: int in 300:
		var next: float = fposmod(pos + 0.02, 1.0)
		steps += ScaleSteps.crossed(pos, next, 1.0, WALK_TIMES).size()
		pos = next
	assert_eq(steps, 12, "six seconds of a 1 s loop at two steps per loop")


func test_no_steps_from_a_missing_clip() -> void:
	assert_eq(ScaleSteps.crossed(0.0, 0.5, 0.0, WALK_TIMES), [])
	assert_eq(ScaleSteps.crossed(0.0, 0.5, 1.0, []), [])


func test_a_huge_robot_steps_slowly() -> void:
	var walk_at_huge: float = ScaleSteps.loop_period_s(1.0, 0.7)
	var run_at_small: float = ScaleSteps.loop_period_s(0.6, 0.65)
	assert_gt(walk_at_huge, 1.3, "one foot every 1.4 s at playback 0.7: a step every 0.7 s")
	assert_gt(walk_at_huge, run_at_small)
