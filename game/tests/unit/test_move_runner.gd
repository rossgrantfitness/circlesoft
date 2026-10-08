extends TestCase
## MoveSet + MoveRunner + LauncherInput: phases, hitbox events, chain windows, cancels, the launcher rules.

const MS: int = 1000


func _moves() -> MoveSet:
	return MoveSet.from_data({"sets": {"t": {
		"entries": {"ground": {"light": "a"}, "air": {"light": "air"}},
		"moves": {
			"a": {"startup_ms": 100, "active_ms": 60, "recovery_ms": 240,
				"cancels": {"chain": [130, 380], "dash": 150, "jump": 150, "parry": 150},
				"links": {"light": "b", "heavy": "h", "launch": "l"},
				"hit": {"damage": 8},
				"hitboxes": [{"from_ms": 100, "to_ms": 130, "shape": "sphere", "radius": 0.5},
					{"from_ms": 130, "to_ms": 160, "shape": "sphere", "radius": 0.5}],
				"swing": {"sfx": "s"},
				"anim": {"clip": "a", "keys": [{"at_ms": 0, "clip_s": 0.0}, {"at_ms": 100, "clip_s": 0.2}, {"at_ms": 160, "clip_s": 0.4}]}},
			"b": {"startup_ms": 50, "active_ms": 50, "recovery_ms": 100, "links": {},
				"hitboxes": [{"from_ms": 50, "to_ms": 100, "shape": "sphere", "radius": 0.5}]},
			"h": {"startup_ms": 200, "active_ms": 50, "recovery_ms": 100, "hit": {"damage": 20}},
			"l": {"startup_ms": 150, "active_ms": 50, "recovery_ms": 100, "launcher": true},
			"air": {"state": "air", "startup_ms": 60, "active_ms": 40, "recovery_ms": 100,
				"motion": {"forward_m": 1.0, "from_ms": 0, "to_ms": 100, "up_mps": 2.0, "hang_ms": 150}},
			"telegraphed": {"startup_ms": 500, "active_ms": 100, "recovery_ms": 300, "telegraph_ms": 50,
				"armor": {"from_ms": 100, "to_ms": 600},
				"hitboxes": [{"from_ms": 500, "to_ms": 600, "shape": "box", "size": [1, 1, 1]}]},
		}}}})


func _runner() -> MoveRunner:
	return MoveRunner.create(_moves(), &"t")


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in events:
		var label: String = String(event["type"])
		if label == "phase":
			label += ":" + String(event["phase"])
		elif label == "hitbox_on" or label == "hitbox_off":
			label += ":" + str(event["index"])
		out.append(label)
	return out


# ---- MoveSet ----

func test_moveset_normalises_missing_fields() -> void:
	var set: MoveSet = _moves()
	var b: Dictionary = set.get_move(&"t", &"b")
	assert_eq(b["total_ms"], 200.0)
	assert_eq(b["launcher"], false)
	assert_eq(b["parryable"], true)
	assert_eq(b["telegraph_ms"], -1.0)
	assert_eq(b["chain_from_ms"], -1.0)
	assert_eq(b["impact_ms"], 50.0, "default impact = first hitbox from_ms")
	assert_eq(set.get_move(&"t", &"a")["chain_to_ms"], 380.0)
	assert_eq(set.get_move(&"t", &"telegraphed")["telegraph_ms"], 50.0)
	assert_true(set.get_move(&"t", &"nope").is_empty())


func test_moveset_entries_and_links() -> void:
	var set: MoveSet = _moves()
	assert_eq(set.entry(&"t", &"ground", &"light"), &"a")
	assert_eq(set.entry(&"t", &"air", &"light"), &"air")
	assert_eq(set.entry(&"t", &"ground", &"heavy"), &"")
	assert_eq(set.link(&"t", &"a", &"light"), &"b")
	assert_eq(set.link(&"t", &"b", &"light"), &"")


func test_the_real_data_has_every_move_the_contract_names() -> void:
	var set: MoveSet = MoveSet.load_default()
	for id: StringName in [&"light_1", &"light_2", &"light_3", &"heavy", &"launcher", &"air_1", &"air_2", &"air_3", &"parry"]:
		assert_true(set.has_move(&"red", id), String(id))
	assert_true(set.has_move(&"grunt", &"swipe"))
	assert_true(set.has_move(&"brute", &"slam"))
	assert_true(set.get_move(&"red", &"launcher")["launcher"])
	assert_true(set.get_move(&"red", &"air_3")["hit"]["knockdown"])


# ---- phases and events ----

func test_phases_change_at_the_right_milliseconds() -> void:
	var runner: MoveRunner = _runner()
	assert_true(runner.start(&"a", 0))
	assert_true(runner.is_busy())
	assert_eq(runner.current_move(), &"a")
	runner.step(0)
	assert_eq(runner.phase(), &"startup")
	runner.step(99 * MS)
	assert_eq(runner.phase(), &"startup")
	runner.step(100 * MS)
	assert_eq(runner.phase(), &"active")
	runner.step(159 * MS)
	assert_eq(runner.phase(), &"active")
	runner.step(160 * MS)
	assert_eq(runner.phase(), &"recovery")
	runner.step(399 * MS)
	assert_true(runner.is_busy())
	runner.step(400 * MS)
	assert_false(runner.is_busy())
	assert_eq(runner.phase(), &"idle")
	assert_eq(runner.current_move(), &"")


func test_events_come_in_order_with_hitboxes_on_and_off_at_their_times() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"a", 0)
	var all: Array[Dictionary] = runner.step(1000 * MS)
	assert_eq(_types(all), [
		"phase:startup", "pose", "phase:active", "swing", "hitbox_on:0", "pose",
		"hitbox_off:0", "hitbox_on:1", "hitbox_off:1", "phase:recovery", "pose", "done"] as Array[String])
	var on_times: Array[float] = []
	for event: Dictionary in all:
		if event["type"] == "hitbox_on" or event["type"] == "hitbox_off":
			on_times.append(float(event["t_ms"]))
	assert_eq(on_times, [100.0, 130.0, 130.0, 160.0] as Array[float])


func test_stepping_in_small_frames_delivers_each_event_once_at_its_frame() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"a", 0)
	var on_frame: int = -1
	var off_frame: int = -1
	var count: int = 0
	for frame: int in range(30):
		var now: int = int(round(float(frame) * 16.667 * MS))
		for event: Dictionary in runner.step(now):
			if event["type"] == "hitbox_on" and int(event["index"]) == 0:
				on_frame = frame
				count += 1
			if event["type"] == "hitbox_off" and int(event["index"]) == 1:
				off_frame = frame
	assert_eq(on_frame, 6, "100 ms is the 7th frame at 16.7 ms")
	assert_eq(off_frame, 10, "160 ms")
	assert_eq(count, 1)


func test_pose_events_carry_clip_and_seconds() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"a", 0)
	var poses: Array[Dictionary] = []
	for event: Dictionary in runner.step(1000 * MS):
		if event["type"] == "pose":
			poses.append(event)
	assert_eq(poses.size(), 3)
	assert_eq(poses[1]["clip"], &"a")
	assert_almost_eq(float(poses[1]["clip_s"]), 0.2)
	assert_almost_eq(float(poses[1]["t_ms"]), 100.0)


func test_telegraph_event_fires_at_telegraph_ms_and_armor_follows_the_window() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"telegraphed", 0)
	var events: Array[Dictionary] = runner.step(49 * MS)
	assert_false("telegraph" in _types(events))
	events = runner.step(50 * MS)
	assert_true("telegraph" in _types(events))
	assert_false(runner.armor_active(), "armor starts at 100 ms")
	runner.step(100 * MS)
	assert_true(runner.armor_active())
	runner.step(700 * MS)
	assert_false(runner.armor_active())


func test_the_swing_event_marks_the_start_of_the_active_phase() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"a", 0)
	runner.step(99 * MS)
	var events: Array[Dictionary] = runner.step(100 * MS)
	assert_true("swing" in _types(events))


func test_each_started_move_gets_its_own_swing_id() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"a", 0)
	var first: int = runner.swing_id()
	runner.start(&"a", 500 * MS)
	assert_ne(runner.swing_id(), first)
	var attack: Dictionary = runner.attack_data()
	assert_eq(attack["move_id"], &"a")
	assert_eq(attack["damage"], 8)
	assert_eq(attack["swing_id"], runner.swing_id())


func test_start_on_an_unknown_move_fails_cleanly() -> void:
	var runner: MoveRunner = _runner()
	assert_false(runner.start(&"nope", 0))
	assert_false(runner.is_busy())


# ---- interrupt ----

func test_interrupt_turns_off_hitboxes_that_were_on() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"a", 0)
	runner.step(110 * MS)
	var events: Array[Dictionary] = runner.interrupt()
	assert_eq(_types(events), ["hitbox_off:0", "interrupted"] as Array[String])
	assert_false(runner.is_busy())
	assert_true(runner.step(300 * MS).is_empty())


func test_starting_over_a_running_move_reports_the_cut_move_first() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"a", 0)
	runner.step(110 * MS)
	runner.start(&"h", 110 * MS)
	var events: Array[Dictionary] = runner.step(110 * MS)
	var labels: Array[String] = _types(events)
	assert_eq(labels[0], "hitbox_off:0")
	assert_eq(labels[1], "interrupted")
	assert_eq(labels[2], "phase:startup")


# ---- chain windows ----

func test_chain_window_gates_the_link() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"a", 0)
	runner.step(100 * MS)
	assert_false(runner.can_chain(&"light", 129 * MS), "window opens at 130")
	assert_eq(runner.offer(&"light", 129 * MS), &"")
	assert_true(runner.can_chain(&"light", 130 * MS))
	assert_false(runner.can_chain(&"launch_nope", 200 * MS), "no such link")
	assert_false(runner.can_chain(&"light", 381 * MS), "window closed at 380")
	assert_eq(runner.offer(&"light", 200 * MS), &"b")
	assert_eq(runner.current_move(), &"b")


func test_an_early_press_fires_exactly_at_chain_from() -> void:
	# Press at 100 ms (buffered), the first frame where the window is open is 140 ms.
	var runner: MoveRunner = _runner()
	runner.start(&"a", 0)
	runner.step(100 * MS)
	var started: StringName = runner.offer(&"light", 140 * MS, 100 * MS)
	assert_eq(started, &"b")
	var events: Array[Dictionary] = runner.step(140 * MS)
	assert_almost_eq(runner.elapsed_ms(), 10.0, 0.001, "the new move began at 130 ms, so 10 ms in at 140")
	assert_true(_types(events).has("interrupted"))
	assert_false(runner.can_chain(&"light", 140 * MS), "b has no chain window")


func test_a_press_inside_the_window_starts_at_the_press() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"a", 0)
	runner.step(200 * MS)
	runner.offer(&"light", 216 * MS, 200 * MS)
	runner.step(216 * MS)
	assert_almost_eq(runner.elapsed_ms(), 16.0, 0.001)


func test_light_light_heavy_follows_the_links_in_the_real_data() -> void:
	var runner: MoveRunner = MoveRunner.create(MoveSet.load_default(), &"red")
	var set: MoveSet = MoveSet.load_default()
	var now: int = 0
	runner.start(set.entry(&"red", &"ground", &"light"), now)
	assert_eq(runner.current_move(), &"light_1")
	runner.step(now)
	now = 200 * MS
	runner.step(now)
	assert_eq(runner.offer(&"light", now), &"light_2")
	runner.step(now)
	now += 200 * MS
	runner.step(now)
	assert_eq(runner.offer(&"heavy", now), &"heavy")
	assert_eq(runner.current_move(), &"heavy")


func test_a_move_without_a_chain_window_never_chains() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"h", 0)
	runner.step(100 * MS)
	assert_false(runner.can_chain(&"light", 100 * MS))
	assert_eq(runner.offer(&"light", 100 * MS), &"")


func test_chain_works_with_the_input_buffer() -> void:
	var runner: MoveRunner = _runner()
	var buffer: InputBuffer = InputBuffer.new()
	runner.start(&"a", 0)
	buffer.push(&"light", 60 * MS)       # pressed during startup
	var accept: Callable = func(token: StringName) -> bool: return runner.can_chain(token, 90 * MS)
	assert_eq(buffer.take(90 * MS, accept), &"", "window is not open yet, the press waits")
	accept = func(token: StringName) -> bool: return runner.can_chain(token, 130 * MS)
	assert_eq(buffer.take(130 * MS, accept), &"light", "and fires once the window opens")


# ---- cancels ----

func test_dash_jump_parry_cancels_open_at_their_times() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"a", 0)
	assert_false(runner.can_cancel(&"dash", 149 * MS))
	assert_true(runner.can_cancel(&"dash", 150 * MS))
	assert_true(runner.can_cancel(&"jump", 150 * MS))
	assert_true(runner.can_cancel(&"parry", 400 * MS))
	runner.start(&"h", 0)
	assert_false(runner.can_cancel(&"dash", 250 * MS), "missing cancel = not until the move ends")
	runner.step(400 * MS)
	assert_true(runner.can_cancel(&"dash", 400 * MS), "idle can always dash")


# ---- motion helpers ----

func test_forward_motion_is_spread_over_its_window() -> void:
	var runner: MoveRunner = _runner()
	runner.start(&"air", 0)
	assert_almost_eq(runner.forward_between(0.0, 50.0), 0.5)
	assert_almost_eq(runner.forward_between(50.0, 400.0), 0.5)
	assert_almost_eq(runner.forward_between(0.0, 400.0), 1.0)
	assert_almost_eq(runner.up_mps(), 2.0)
	assert_true(runner.is_hanging())
	runner.step(150 * MS)
	assert_false(runner.is_hanging())


# ---- launcher input ----

func test_hold_heavy_makes_a_launcher_only_after_the_hold() -> void:
	assert_eq(LauncherInput.token_for_heavy_press("hold_heavy", {"stick_back": true}), &"heavy")
	assert_false(LauncherInput.should_upgrade_heavy("hold_heavy", &"heavy", &"heavy", true, 100.0, 170.0))
	assert_true(LauncherInput.should_upgrade_heavy("hold_heavy", &"heavy", &"heavy", true, 170.0, 170.0))
	assert_false(LauncherInput.should_upgrade_heavy("hold_heavy", &"heavy", &"heavy", false, 300.0, 170.0), "only during startup")
	assert_false(LauncherInput.should_upgrade_heavy("hold_heavy", &"light_1", &"heavy", true, 300.0, 170.0))
	assert_false(LauncherInput.should_upgrade_heavy("back_heavy", &"heavy", &"heavy", true, 300.0, 170.0), "other modes never upgrade")


func test_back_heavy_needs_the_stick_pulled_back() -> void:
	assert_eq(LauncherInput.token_for_heavy_press("back_heavy", {"stick_back": true}), &"launch")
	assert_eq(LauncherInput.token_for_heavy_press("back_heavy", {"stick_back": false}), &"heavy")
	assert_eq(LauncherInput.token_for_heavy_press("back_heavy", {}), &"heavy")


func test_string_end_needs_heavy_inside_the_string_end_chain_window() -> void:
	var ctx: Dictionary = {"current_move": &"light_2", "chain_open": true, "string_end_move": &"light_2"}
	assert_eq(LauncherInput.token_for_heavy_press("string_end", ctx), &"launch")
	ctx["chain_open"] = false
	assert_eq(LauncherInput.token_for_heavy_press("string_end", ctx), &"heavy")
	ctx["chain_open"] = true
	ctx["current_move"] = &"light_1"
	assert_eq(LauncherInput.token_for_heavy_press("string_end", ctx), &"heavy")
	assert_eq(LauncherInput.token_for_heavy_press("hold_heavy", {"current_move": &"light_2", "chain_open": true, "string_end_move": &"light_2"}), &"heavy")


func test_launch_token_reaches_the_launcher_from_the_real_data() -> void:
	var set: MoveSet = MoveSet.load_default()
	assert_eq(set.entry(&"red", &"ground", &"launch"), &"launcher")
	assert_eq(set.link(&"red", &"light_2", &"launch"), &"launcher")
	assert_eq(set.link(&"red", &"light_1", &"launch"), &"launcher")
