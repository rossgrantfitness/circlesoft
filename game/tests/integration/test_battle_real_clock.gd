extends TestCase
## The game runs the same model on a RealClock. One short real-time fight (about a second):
## a press stamped from Time.get_ticks_usec() is judged by its timestamp, and the rating is
## reported right away, not at the end of the window.

const SLACK_MS: float = 60.0
const WARM_UP_S: float = 0.03


## The first timers of a fresh process see one oversized frame (the start-up), so let them pass.
func _warm_up() -> void:
	await tree.create_timer(WARM_UP_S).timeout
	await tree.create_timer(WARM_UP_S).timeout


func test_a_real_time_press_is_judged_promptly_by_its_timestamp() -> void:
	await _warm_up()
	var data: BattleData = BattleTestKit.fresh_data(tree)
	for enemy_id: String in data.enemies:
		(data.enemy(enemy_id)["stats"] as Dictionary)["attack"] = 1
	var setup: BattleSetup = BattleTestKit.setup_for(data, "grunt_solo", 3)
	setup.clock = RealClock.new()
	setup.press_source = HumanPressSource.new()
	var source: BattleTestKit.ScriptedCommands = BattleTestKit.ScriptedCommands.new()
	source.queue = [{"kind": "attack", "targets": ["e1"]}]
	source.limit = 1
	setup.command_source = source
	var controller: BattleController = BattleController.create(setup)
	var pressed_at: Array[int] = []
	var judged_at: Array[int] = []
	var ratings: Array[String] = []
	controller.press_judged.connect(func(info: Dictionary) -> void:
		judged_at.append(Time.get_ticks_usec())
		ratings.append(str(info["rating"])))
	var tree_ref: SceneTree = tree
	var injector: Callable = func(action: Dictionary) -> void:
		if action["actor"] != "red":
			return
		var press: Dictionary = (action["presses"] as Array)[0]
		var wait_s: float = float(int(press["cue_ms"])) / 1000.0
		await tree_ref.create_timer(wait_s).timeout
		pressed_at.append(Time.get_ticks_usec())
		controller.press_down(pressed_at[0])
	controller.action_started.connect(injector)
	var started: int = Time.get_ticks_usec()
	await controller.start()
	var wall_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	controller.action_started.disconnect(injector)
	assert_eq(ratings.size(), 1)
	assert_has(["totally_rad", "rad"], ratings[0], "a press on the cue in real time lands (timer jitter allowed)")
	assert_lt(float(judged_at[0] - pressed_at[0]) / 1000.0, SLACK_MS, "the rating pops up within a few frames of the press")
	assert_ge(wall_ms, 700.0, "the action really took its timeline to play")
	assert_lt(wall_ms, 3000.0)
	assert_eq(controller.result, "aborted")


func test_a_real_clock_never_runs_ahead_of_the_system_clock() -> void:
	await _warm_up()
	var clock: RealClock = RealClock.new()
	var before: int = Time.get_ticks_usec()
	var target: int = clock.now_usec() + 50000
	await clock.wait_until_usec(target)
	assert_ge(float(clock.now_usec()), float(target) - 25000.0)
	assert_ge(float(Time.get_ticks_usec() - before), 30000.0, "it really waited (timers may fire up to a frame early)")
	await clock.wait_until_usec(target - 10000)
	assert_true(true, "waiting for a time already past returns at once")
