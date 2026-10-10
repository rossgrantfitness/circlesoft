extends TestCase
## CS-21 bot run: a scripted player does the whole robot test in the real combat sandbox, with the real controller, camera, boarding
## and docking: walks out of the arena to the loader, climbs in, walks it to the colossus, docks, takes a few huge steps (the
## footfalls, the dust and the shake come from the animation), stomps a building, climbs out of the colossus and out of the loader.
## The sandbox's clocks are stepped by hand at 60 Hz (RobotKit), so it runs in seconds and is exactly repeatable.

const DT: float = 1.0 / 60.0


func test_a_bot_boards_docks_strides_and_climbs_out_again() -> void:
	var kit: RobotKit = RobotKit.new(self)
	await kit.boot()
	var player: ActionPlayer = kit.player
	var report: Dictionary = {}
	var forms: Array[StringName] = []
	player.form_changed.connect(func(id: StringName) -> void: forms.append(id))
	var modes: Array[String] = []
	kit.boarding.mode_changed.connect(func(m: RobotBoarding.Mode) -> void: modes.append(RobotBoarding.Mode.keys()[m]))

	# 1. Red walks out of the arena (through the gate) to the loader and into its ring.
	for waypoint: Vector3 in [Vector3(14.0, 0.0, 12.0), Vector3(26.0, 0.0, 0.0), Vector3(40.0, 0.0, 0.0)]:
		assert_true(kit.walk_to(waypoint, 1.5, 900, func() -> bool: return kit.mode() != RobotBoarding.Mode.RED), "Red reaches %s" % waypoint)
	kit.walk_to(kit.yard.small_display.boarding_point(), 0.5, 100, func() -> bool: return kit.mode() != RobotBoarding.Mode.RED)
	kit.step_until(func() -> bool: return kit.mode() == RobotBoarding.Mode.SMALL, 600)
	kit.stop()
	assert_eq(kit.mode(), RobotBoarding.Mode.SMALL, "boarded")
	assert_eq(player.get_form_id(), &"small")

	# 2. She walks the loader down the street to the colossus's ring; the docking starts by itself.
	var approach: Vector3 = kit.yard.huge_display.approach_point()
	var walked: bool = kit.walk_to(approach, 1.0, 1800, func() -> bool: return kit.mode() == RobotBoarding.Mode.DOCKING)
	assert_true(walked or kit.mode() == RobotBoarding.Mode.DOCKING, "the loader reached the colossus's ring")
	assert_eq(kit.mode(), RobotBoarding.Mode.DOCKING)
	var small_speed: float = 0.0
	kit.step_until(func() -> bool: return kit.mode() == RobotBoarding.Mode.HUGE, 600)
	assert_eq(kit.mode(), RobotBoarding.Mode.HUGE, "docked and powered up")
	assert_eq(player.get_form_id(), &"huge")
	assert_gt(kit.controller.world_now()["fog_far_m"], 1000.0 - 1.0, "the haze is already the colossus's (or nearly)")
	kit.step(120)
	assert_almost_eq(float(kit.controller.world_now()["fog_far_m"]), 1500.0, 1.0)
	assert_almost_eq(kit.camera.get_camera().position.z, 75.0, 1.0, "camera 75 m back")

	# 3. A few huge steps: east along the avenue.
	var steps_before: int = kit.controller.steps_taken
	var x_before: float = player.global_position.x
	player.set_move_input(Vector2(0, -1))
	kit.camera.set_orbit_angles(-PI * 0.5, -0.12)
	kit.step(60 * 6)
	var huge_run: float = ScaleProfile.get_form(&"huge").knob("run_speed_mps", 0.0)
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	player.set_move_input(Vector2.ZERO)
	var steps: int = kit.controller.steps_taken - steps_before
	report["huge_steps"] = steps
	report["huge_speed"] = speed
	report["huge_travelled_m"] = player.global_position.x - x_before
	# Footfalls come from the walk clip: two per loop, and the loop plays at run speed over the clip's stride (all from the data).
	var walk_clip: Dictionary = CombatData.read_json(str(ScaleProfile.get_form(&"huge").block("anim")["clip_keys"]))["clips"]["walk"] as Dictionary
	var feet_per_s: float = 2.0 * (huge_run / float(walk_clip["stride_mps"])) / float(walk_clip["length_s"])
	assert_gt(steps, int(feet_per_s * 6.0 * 0.7), "six seconds of walking put down about as many huge feet as the speed and clip say (less the start-up)")
	assert_gt(steps, 1, "and at least both feet came down")
	assert_almost_eq(speed, huge_run, 0.5, "the colossus's top speed, from the data")
	assert_gt(player.global_position.x - x_before, huge_run * 6.0 * 0.7, "and covered most of six seconds at that speed")
	assert_eq(player.current_clip(), &"walk", "the walk clip even at a run")
	var step_events: Array[Dictionary] = kit.controller.events.filter(func(e: Dictionary) -> bool: return e["type"] == "step" and str(e["dust"]) == "step_huge")
	assert_gt(step_events.size(), 1, "the huge footfalls, with huge dust")
	assert_eq(str(step_events[0]["dust"]), "step_huge")
	assert_eq(str(step_events[0]["shake"]), "step_huge")
	var feet: Dictionary = {}
	for event: Dictionary in step_events:
		feet[int(event["foot"])] = true
	assert_eq(feet.size(), 2, "left and right feet both came down")
	assert_gt(kit.controller.stomps, 0, "and stomped what was underfoot")
	kit.step(60)

	# 4. A jump and a landing slam, then an attack that smashes a building.
	var slams_before: int = kit.controller.slams_taken
	player.press(&"jump")
	kit.step(200)
	assert_gt(kit.controller.slams_taken, slams_before, "the landing slam")
	var building: SmashProp = null
	var best: float = INF
	for prop: SmashProp in kit.yard.props:
		if not prop.dead and prop.kind == &"building_30m":
			var gap: float = prop.centre_world().distance_to(player.global_position)
			if gap < best:
				best = gap
				building = prop
	assert_not_null(building)
	kit.walk_to(building.centre_world(), 4.0, 1200, func() -> bool: return building.dead)
	assert_true(building.dead, "it walked into a 30 m building and flattened it")
	kit.stop()

	# 5. Climb out of the colossus (it stays where it stands), then out of the loader.
	var stand: Array[Vector3] = []
	kit.step(30)
	kit.boarding.request_disembark()
	kit.step_until(func() -> bool:
		if kit.mode() == RobotBoarding.Mode.UNDOCKING and stand.is_empty():
			stand.append(kit.yard.huge_display.global_position)
		return kit.mode() == RobotBoarding.Mode.SMALL, 600)
	assert_eq(kit.mode(), RobotBoarding.Mode.SMALL, "undocked")
	assert_false(stand.is_empty())
	assert_lt(kit.yard.huge_display.global_position.distance_to(stand[0]), 0.01, "the colossus stands where it was left")
	assert_gt(kit.yard.huge_display.global_position.x, 200.0, "far from where it started")
	assert_eq(player.get_form_id(), &"small")
	kit.step(90)
	kit.boarding.request_disembark()
	kit.step_until(func() -> bool: return kit.mode() == RobotBoarding.Mode.RED, 600)
	assert_eq(kit.mode(), RobotBoarding.Mode.RED, "back to Red")
	assert_eq(player.get_form_id(), &"red")
	assert_eq(player.hp_max, 120)
	assert_eq(forms, [&"small", &"huge", &"small", &"red"], "the bodies she wore, in order")
	assert_eq(modes, ["BOARDING", "SMALL", "DOCKING", "HUGE", "UNDOCKING", "SMALL", "DISEMBARKING", "RED"])
	print("robot bot run: ", report)
