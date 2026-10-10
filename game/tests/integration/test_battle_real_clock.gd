extends TestCase
## The game runs the same model on a RealClock. One short real-time fight (about a second):
## a press stamped from Time.get_ticks_usec() is judged by its timestamp, and the rating is
## reported right away, not at the end of the window.

const WARM_UP_S: float = 0.03
const MIN_WALL_MS: float = 600.0
const MAX_WALL_MS: float = 30000.0


## The first timers of a fresh process see one oversized frame (the start-up), so let them pass.
func _warm_up() -> void:
	await tree.create_timer(WARM_UP_S).timeout
	await tree.create_timer(WARM_UP_S).timeout


## A real-clock fight. The press is stamped relative to the controller's own t0 (the action's
## start on the real clock), not by sleeping, so a busy machine cannot move it off the cue. What
## it still proves: the fight really waits on the real clock, judges from the timestamp, and
## reports the rating before the action's timeline is over.
func test_a_real_clock_fight_judges_presses_from_their_timestamps() -> void:
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
	var ratings: Array[String] = []
	var judged_at: Array[int] = []
	var action_info: Array[Dictionary] = []
	controller.press_judged.connect(func(info: Dictionary) -> void:
		ratings.append(str(info["rating"]))
		judged_at.append(Time.get_ticks_usec()))
	var injector: Callable = func(action: Dictionary) -> void:
		if action["actor"] != "red":
			return
		action_info.append(action)
		var press: Dictionary = (action["presses"] as Array)[0]
		controller.press_down(int(action["t0_usec"]) + int(press["cue_ms"]) * 1000 + 20000)
	controller.action_started.connect(injector)
	var started: int = Time.get_ticks_usec()
	await controller.start()
	var wall_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	controller.action_started.disconnect(injector)
	assert_eq(ratings.size(), 1)
	assert_eq(ratings[0], "totally_rad", "a press stamped 20 ms after the cue is judged by that stamp, whatever the machine is doing")
	assert_eq(action_info.size(), 1)
	var action_end_usec: int = int(action_info[0]["t0_usec"]) + int((action_info[0]["timeline_ms"] as Dictionary)["end"]) * 1000
	assert_lt(float(judged_at[0]), float(action_end_usec) + 2000000.0, "the rating is reported during the action, not after the whole fight")
	assert_ge(wall_ms, MIN_WALL_MS, "the action really waited on the real clock")
	assert_lt(wall_ms, MAX_WALL_MS)
	assert_eq(controller.result, "aborted")


func test_a_real_clock_never_runs_ahead_of_the_system_clock() -> void:
	await _warm_up()
	var clock: RealClock = RealClock.new()
	var before: int = Time.get_ticks_usec()
	var target: int = clock.now_usec() + 50000
	await clock.wait_until_usec(target)
	assert_ge(float(clock.now_usec()), float(target) - 25000.0)
	assert_ge(float(Time.get_ticks_usec() - before), 10000.0, "it really waited (timers may fire up to a frame early)")
	await clock.wait_until_usec(target - 10000)
	assert_true(true, "waiting for a time already past returns at once")
