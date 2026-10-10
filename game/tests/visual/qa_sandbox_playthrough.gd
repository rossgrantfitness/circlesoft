extends SceneTree
## CS-18 real-renderer playthrough of the combat sandbox, with injected keyboard and mouse input the way Ross plays it.
## Names no game classes (they load after compile); it reaches the game through the tree, groups and method names.
## Run:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/qa_sandbox_playthrough.gd -- --sandbox
## Prints QA PASS / QA FAIL lines, frame-time stats and QA SUMMARY. Screenshots go to docs/screenshots/qa_sandbox_*.png.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SHOTS: String = "res://../docs/screenshots/"
const SANDBOX_GROUP: StringName = &"combat_sandbox"
const BOOT_LIMIT_S: float = 10.0
const FIGHT_MIN_S: float = 185.0
const FIGHT_CAP_S: float = 480.0
const FEEL_FILE: String = "user://feel/feel_current.json"
const PAUSE_ITEM_RESET: int = 1
const PAUSE_ITEM_CONTROLS: int = 2
const PAUSE_ITEM_QUIT: int = 3
const ZONE_BUTTONS: int = 2
const WAYPOINTS: Array = [Vector3(-9.0, 0.0, -10.0), Vector3(-9.0, 0.0, -13.5), Vector3(0.0, 0.0, -17.0),
		Vector3(0.0, 0.0, -10.0), Vector3(-17.0, 0.0, 8.0), Vector3(0.0, 0.0, 6.0)]

var _failures: int = 0
var _t0_ms: int = 0
var _last_usec: int = 0
var _frame_ms: Array[float] = []
var _sandbox: Node = null
var _player: Node3D = null
var _director: Node = null
var _held: Dictionary = {}
var _counts: Dictionary = {}
var _outcomes: Dictionary = {}
var _moves_seen: Array[String] = []
var _judged: Array[Dictionary] = []
var _last_tel: Dictionary = {}
var _tel_usec: int = 0
var _min_y: float = 999.0
var _stuck_notes: Array[String] = []
var _still_since: Dictionary = {}
var _last_pos: Dictionary = {}
var _living_last: int = -1


func _initialize() -> void:
	_t0_ms = Time.get_ticks_msec()
	print("QA START unix=%.3f" % Time.get_unix_time_from_system())
	_run()


func _run() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)

	# --- 1. Boot to the arena -------------------------------------------------------------------------------------
	for i: int in 900:
		await _tick()
		_sandbox = get_first_node_in_group(SANDBOX_GROUP)
		if _sandbox != null and _sandbox.call("get_player") != null:
			break
	var boot_s: float = float(Time.get_ticks_msec() - _t0_ms) / 1000.0
	_check(_sandbox != null and boot_s < BOOT_LIMIT_S, "boots to the arena in under 10 s (%.2f s after script start)" % boot_s)
	if _sandbox == null:
		_finish()
		return
	_player = _sandbox.call("get_player") as Node3D
	_director = _sandbox.call("get_director") as Node
	_wire_signals()
	await _frames(60)
	print("QA INFO  sandbox missing parts: %s" % str(_sandbox.get("missing")))
	_check((_sandbox.get("missing") as Array).is_empty(), "no optional sandbox part is missing")
	_check(_find_method(root, "get_hp") != null, "sandbox HUD is on screen and bound")
	_check(_director != null and _player != null, "director and Red are registered")
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse is captured in the arena")
	_shot("01_arena_boot")
	# Teal corner check: hide the sword racks (their trail-coloured rings) and compare the same frame.
	var racks: Array = _sandbox.call("get_racks") as Array
	for rack: Variant in racks:
		(rack as Node3D).visible = false
	await _frames(12)
	_shot("01b_arena_racks_hidden")
	for rack: Variant in racks:
		(rack as Node3D).visible = true
	await _frames(12)

	# --- 2. Run in all eight directions relative to the camera ----------------------------------------------------
	var all_dirs: Array = [["move_up"], ["move_up", "move_right"], ["move_right"], ["move_down", "move_right"],
			["move_down"], ["move_down", "move_left"], ["move_left"], ["move_up", "move_left"]]
	var dir_names: Array[String] = ["forward", "forward-right", "right", "back-right", "back", "back-left", "left", "forward-left"]
	var dirs_ok: int = 0
	for i: int in all_dirs.size():
		await _release_moves()
		await _wait(0.25)
		var start: Vector3 = _player.global_position
		var want: Vector3 = Vector3.ZERO
		var fwd: Vector3 = _cam_fwd()
		var right: Vector3 = _cam_right()
		for action: String in all_dirs[i]:
			_set_key(StringName(action), true)
			match action:
				"move_up": want += fwd
				"move_down": want -= fwd
				"move_right": want += right
				"move_left": want -= right
		await _wait(0.7)
		await _release_moves()
		var moved: Vector3 = _player.global_position - start
		moved.y = 0.0
		var good: bool = moved.length() > 0.5 and moved.normalized().dot(want.normalized()) > 0.6
		if good:
			dirs_ok += 1
		else:
			print("QA INFO  direction '%s' moved %.2f m, dot %.2f" % [dir_names[i], moved.length(), moved.normalized().dot(want.normalized()) if moved.length() > 0.01 else 0.0])
		if i == 0:
			_set_key(&"move_up", true)
			await _wait(0.3)
			_shot("02_running")
			await _release_moves()
	_check(dirs_ok == all_dirs.size(), "runs in all 8 directions relative to the camera (%d/8)" % dirs_ok)

	# --- 3. Jump, dash, air-dash ----------------------------------------------------------------------------------
	await _wait(0.3)
	var jumps_before: int = _count("jump")
	await _tap(&"jump", 0.05)
	var was_air: bool = false
	for i: int in 12:
		await _tick()
		if _player.call("is_airborne"):
			was_air = true
	_check(was_air and _count("jump") > jumps_before, "jump leaves the ground")
	await _tap(&"jump", 0.05)
	await _wait(0.12)
	var dash_air_before: int = _count("dash_air")
	await _tap(&"dash", 0.1)
	await _wait(0.2)
	_shot("03_air_dash")
	_check(_count("dash_air") > dash_air_before, "air-dash works in the air")
	await _wait(1.0)
	var dash_before: int = _count("dash_ground")
	await _tap(&"dash", 0.6)
	_check(_count("dash_ground") > dash_before, "ground dash works")

	# --- 4. Walk the arena: ramp, ledge, pillar, far ledge (falls and stuck checks) -------------------------------
	var waypoints_ok: int = 0
	for wp: Vector3 in WAYPOINTS:
		var reached: bool = await _walk_to(wp, 14.0)
		if reached:
			waypoints_ok += 1
		else:
			_stuck_notes.append("could not reach waypoint %s from %s" % [str(wp), str(_player.global_position)])
	await _release_moves()
	_check(waypoints_ok == WAYPOINTS.size(), "walks the ramp, both ledges and the pillar route (%d/%d)" % [waypoints_ok, WAYPOINTS.size()])
	_check(_min_y > -0.5, "Red never falls off the world (lowest y %.2f)" % _min_y)

	# --- 5. Light string, heavy, against the nearest grunt --------------------------------------------------------
	var seen_before: int = _moves_seen.size()
	var foe: Node3D = await _approach_nearest(1.7, 10.0)
	print("QA INFO  before the string: Red state %s, hp %s, foe at %.2f m" % [str(_player.call("get_state")), str(_player.get("hp")), _flat(foe.global_position, _player.global_position) if foe != null else -1.0])
	await _tap(&"light", 0.2)
	await _tap(&"light", 0.2)
	await _tap(&"light", 0.6)
	print("QA INFO  after the string: Red state %s, moves %s" % [str(_player.call("get_state")), str(_moves_seen.slice(seen_before))])
	var ready_t0: float = _now()
	while int(_player.call("get_state")) != 0 and _now() - ready_t0 < 4.0:
		await _tick()
	print("QA INFO  heavy: Red state %s after waiting %.1f s" % [str(_player.call("get_state")), _now() - ready_t0])
	await _tap(&"heavy", 0.9)
	var recent: Array = _moves_seen.slice(seen_before)
	_check(_has_sequence(recent, ["light_1", "light_2", "light_3"]), "3-hit light string chains 1, 2, 3 (moves: %s)" % str(recent))
	_check(recent.has("heavy"), "heavy attack fires")
	_shot("04_light_string")

	# --- 6. Lock-on, target switching, V camera toggle --------------------------------------------------------------
	await _approach_nearest(3.5, 6.0)
	var lock: Object = _sandbox.call("get_lock_on") as Object
	await _tap(&"lock_on", 0.4)
	var target_a: Variant = lock.call("get_target")
	_check(target_a != null, "lock-on (Tab) locks a target in range")
	_shot("05_lock_on")
	var cam_obj: Object = _sandbox.call("get_camera") as Object
	var target_b: Variant = target_a
	for i: int in 2:
		await _mouse_flick(Vector2(-260.0 if i == 0 else 260.0, 0.0))
		await _wait(0.5)
		target_b = lock.call("get_target")
		if target_b != target_a:
			break
	var living_now: int = _living().size()
	if living_now >= 2:
		_check(target_b != target_a, "flicking the camera switches the lock to another enemy")
	else:
		print("QA INFO  only %d enemy alive, target switch not testable" % living_now)
	await _tap(&"lock_on", 0.3)
	_check(lock.call("get_target") == null, "lock-on (Tab) lets go again")
	var mode_before: Variant = cam_obj.call("get_mode")
	await _tap(&"camera_toggle", 0.6)
	_shot("06_diorama")
	_check(cam_obj.call("get_mode") != mode_before, "V switches the camera to the action diorama")
	await _tap(&"camera_toggle", 0.6)
	_check(cam_obj.call("get_mode") == mode_before, "V switches the camera back")

	# --- 7. Parry a wind-up (timed from the telegraphed signal) ---------------------------------------------------
	var parry_hits: int = 0
	var parry_tries: int = 0
	for attempt: int in 3:
		var before_count: int = _judged.size()
		_last_tel = {}
		var t_wait: float = _now()
		while _last_tel.is_empty() and _now() - t_wait < 30.0:
			var close_foe: Node3D = _nearest_living()
			if close_foe != null:
				_steer_keep_range(close_foe.global_position, 2.2)
			await _tick()
		await _release_moves()
		if _last_tel.is_empty():
			print("QA INFO  no wind-up arrived in 30 s (attempt %d)" % attempt)
			continue
		parry_tries += 1
		var impact_ms: float = float(_last_tel.get("impact_in_ms", 500.0))
		print("QA INFO  parry attempt %d: Red state %s hp %s at the wind-up, attacker %s" % [attempt, str(_player.call("get_state")), str(_player.get("hp")), str(_last_tel.get("attacker", "?"))])
		var press_at: int = _tel_usec + int((impact_ms - 70.0) * 1000.0)
		while Time.get_ticks_usec() < press_at:
			await _tick()
		_shot("07_parry_window_%d" % attempt)
		await _tap(&"parry", 0.8)
		var ratings: Array[String] = []
		for judged: Dictionary in _judged.slice(before_count):
			ratings.append(str(judged.get("rating", "?")))
		print("QA INFO  parry attempt %d: impact %.0f ms after telegraph, ratings %s, Red state %s hp %s" % [attempt, impact_ms, str(ratings), str(_player.call("get_state")), str(_player.get("hp"))])
		for rating: String in ratings:
			if rating != "miss" and rating != "?":
				parry_hits += 1
				break
		await _wait(0.6)
	_check(parry_tries > 0 and parry_hits > 0, "parry against a wolf wind-up is rated (%d of %d tries rated nice or better)" % [parry_hits, parry_tries])

	# --- 8. Launcher into an air combo ---------------------------------------------------------------------------
	var launched_before: int = _count("launched")
	var launcher_moves_before: int = _moves_seen.size()
	await _approach_nearest(1.7, 8.0)
	await _set_key_wait(&"heavy", 0.32)
	await _tap(&"jump", 0.25)
	await _tap(&"light", 0.3)
	_shot("08_launcher_air")
	await _tap(&"light", 0.4)
	await _tap(&"light", 0.6)
	var launch_recent: Array = _moves_seen.slice(launcher_moves_before)
	_check(launch_recent.has("launcher"), "holding heavy throws the launcher")
	_check(_count("launched") > launched_before, "launcher lifts an enemy (launched event fired)")
	_check(launch_recent.has("air_1"), "air light connects in the air combo (moves: %s)" % str(launch_recent))

	# --- 9. Sword stands: walk onto each, the sword in hand changes -----------------------------------------------
	var sword_data: Array = (_sandbox.call("get_data") as Dictionary).get("racks", {}).get("stands", []) as Array
	var swaps_ok: int = 0
	var trail_ok: int = 0
	for index: int in racks.size():
		var rack: Node3D = racks[index] as Node3D
		var want_id: StringName = StringName(str(rack.get("sword_id")))
		var reached_rack: bool = await _walk_to(rack.global_position, 25.0, 0.6)
		await _wait(0.5)
		var now_id: StringName = StringName(str(_player.call("current_sword")))
		if reached_rack and now_id == want_id:
			swaps_ok += 1
		else:
			print("QA INFO  stand %d: wanted %s, in hand %s, reached %s" % [index, want_id, now_id, reached_rack])
		if index == 0 or index == racks.size() - 1:
			_shot("09_sword_%s" % str(want_id))
		# A swing with the new sword: its trail must be in the new colour and gone once the swing ends.
		var fx: Object = _find_method(root, "trail_active") as Object
		await _tap(&"light", 1.3)
		var trail: Object = fx.call("get_trail", &"red") as Object if fx != null else null
		var left_over: bool = true
		if trail != null:
			left_over = bool(trail.call("is_active")) or int(trail.call("sample_count")) > 0
		if not left_over:
			trail_ok += 1
		else:
			print("QA INFO  trail still showing %d samples after swap to %s" % [int(trail.call("sample_count")), want_id])
	_check(swaps_ok == racks.size(), "all %d sword stands swap the sword in hand (%d/%d)" % [racks.size(), swaps_ok, racks.size()])
	_check(trail_ok == racks.size(), "no sword trail is left behind after a swap or swing (%d/%d)" % [trail_ok, racks.size()])
	print("QA INFO  stand data count %d" % sword_data.size())

	# --- 10. Fight until enemies die and respawn; watch for stuck enemies and errors ------------------------------
	var fight_t0: float = _now()
	var step: int = 0
	var ops: Array[String] = ["light", "light", "light", "heavy", "light", "launch", "light", "dash", "light", "light"]
	var fight_shot: bool = false
	while true:
		var elapsed: float = _now() - fight_t0
		if elapsed >= FIGHT_CAP_S:
			break
		if elapsed >= FIGHT_MIN_S and _count("death") >= 1 and _count("respawn") >= 1:
			break
		_track_enemies()
		if not fight_shot and elapsed > 40.0:
			_shot("10_fight_midway")
			fight_shot = true
		var target: Node3D = _nearest_living()
		if target == null:
			await _release_moves()
			await _tick()
			continue
		if _flat(target.global_position, _player.global_position) > 1.6:
			_steer(target.global_position)
			await _tick()
			continue
		await _release_moves()
		var op: String = ops[step % ops.size()]
		step += 1
		match op:
			"light":
				await _tap(&"light", 0.4)
			"heavy":
				await _tap(&"heavy", 0.7)
			"launch":
				await _set_key_wait(&"heavy", 0.32)
				await _tap(&"jump", 0.25)
				await _tap(&"light", 0.35)
				await _tap(&"light", 0.4)
			"dash":
				await _tap(&"dash", 0.3)
				await _tap(&"light", 0.4)
	var fight_s: float = _now() - fight_t0
	print("QA INFO  fight ran %.0f s; deaths %d, respawns %d, hits on Red %d, outcomes %s" % [fight_s, _count("death"), _count("respawn"), _count("hits_on_red"), str(_outcomes)])
	_check(_count("death") >= 1, "enemies die in the fight (%d deaths)" % _count("death"))
	_check(_count("respawn") >= 1, "dead enemies respawn (%d respawns)" % _count("respawn"))
	_check(fight_s >= FIGHT_MIN_S or _count("death") >= 1, "fight lasted %.0f s" % fight_s)
	_check(_stuck_notes.is_empty(), "no enemy stuck on a pillar, ledge or wall (%s)" % str(_stuck_notes))
	_shot("11_after_fight")
	_frame_stats()

	# --- 11. Esc pause: Controls, Reset arena, Resume; mouse capture ---------------------------------------------------
	await _release_moves()
	for i: int in 3:
		await _tap(&"light", 0.4)
	var hud_obj: Object = _find_method(root, "get_noise") as Object
	var pause: Object = _find_method(root, "get_card") as Object
	await _tap_key(&"start", KEY_ESCAPE, 0.4)
	_check(pause != null and bool(pause.call("is_open")), "Esc opens the pause menu")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the mouse is freed while paused")
	_check(paused, "the game is paused behind the menu")
	await _tap(&"move_down", 0.2)
	await _tap(&"move_down", 0.2)
	await _tap(&"confirm", 0.5)
	_check(bool(pause.call("is_sub_page_open")), "Controls opens the controls card")
	_shot("12_controls_card")
	await _tap(&"cancel", 0.5)
	_check(not bool(pause.call("is_sub_page_open")), "cancel closes the controls card")
	await _tap(&"move_up", 0.2)
	_check(int(pause.call("get_cursor_index")) == PAUSE_ITEM_RESET, "cursor is on Reset arena")
	await _tap(&"confirm", 0.8)
	_check(not bool(pause.call("is_open")), "Reset arena closes the menu")
	var player_hp: Variant = _player.get("hp")
	var hp_max: Variant = _player.get("hp_max")
	await _wait(0.8)
	var noise_after: float = float((hud_obj.call("get_noise") as Dictionary).get("points", 0.0))
	_check(noise_after == 0.0, "Reset arena empties the Noise meter on screen (HUD shows %.0f points)" % noise_after)
	var lights_model: Object = _director.get("lights_on") as Object
	_check(lights_model == null or not bool(lights_model.call("is_active")), "Reset arena ends any running Lights On")
	var enemy_registered: int = (_director.call("actors", &"enemy") as Array).size()
	_check(enemy_registered == (_sandbox.call("get_data") as Dictionary).get("enemy_spawns", []).size(), "after Reset the director knows exactly the new enemies (%d registered)" % enemy_registered)
	_check(_living().size() == (_sandbox.call("get_data") as Dictionary).get("enemy_spawns", []).size(), "Reset arena puts every enemy back (%d alive)" % _living().size())
	_check(int(player_hp) == int(hp_max), "Reset arena gives Red full health")
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "the mouse is captured again after Reset")
	_shot("13_after_reset")
	await _tap_key(&"start", KEY_ESCAPE, 0.4)
	await _tap(&"light", 0.3)
	var moves_while_paused: int = _moves_seen.size()
	_check(int(pause.call("get_cursor_index")) == 0, "the pause menu opens with the cursor on Resume")
	await _tap(&"confirm", 0.6)
	_check(not bool(pause.call("is_open")) and not paused, "Resume returns to the game")
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "the mouse is captured after Resume")
	await _wait(0.8)
	_check(_moves_seen.size() == moves_while_paused, "a button pressed while paused does not fire an attack after Resume")

	# --- 12. F12 feel panel: move a slider, save, close ----------------------------------------------------------
	var hud: Object = _find_method(root, "get_feel_panel") as Object
	var panel: Object = hud.call("get_feel_panel") as Object if hud != null else null
	await _tap(&"feel_panel", 0.5)
	_check(panel != null and bool(panel.call("is_open")), "F12 opens the feel panel")
	_shot("14_feel_panel")
	var knob: Dictionary = panel.call("get_cursor_knob") as Dictionary
	var knob_id: String = str(knob.get("id", ""))
	var before_value: Variant = panel.call("get_value", knob_id)
	for i: int in 3:
		await _tap(&"move_right", 0.15)
	var after_value: Variant = panel.call("get_value", knob_id)
	_check(str(after_value) != str(before_value), "a feel slider moves (%s: %s -> %s)" % [knob_id, str(before_value), str(after_value)])
	var file_before: bool = FileAccess.file_exists(FEEL_FILE)
	var stamp_before: int = FileAccess.get_modified_time(FEEL_FILE) if file_before else 0
	for i: int in 60:
		if int(panel.call("get_zone")) == ZONE_BUTTONS:
			break
		await _tap(&"move_down", 0.05)
	await _tap(&"confirm", 0.8)
	var saved: bool = FileAccess.file_exists(FEEL_FILE)
	_check(saved and (not file_before or FileAccess.get_modified_time(FEEL_FILE) >= stamp_before), "Save writes the feel file (%s)" % ProjectSettings.globalize_path(FEEL_FILE))
	_shot("15_feel_saved")
	await _tap(&"feel_panel", 0.5)
	_check(not bool(panel.call("is_open")), "F12 closes the feel panel")

	# --- 13. Esc > Quit ----------------------------------------------------------------------------------------------
	await _tap_key(&"start", KEY_ESCAPE, 0.4)
	await _tap(&"move_down", 0.2)
	await _tap(&"move_down", 0.2)
	await _tap(&"move_down", 0.2)
	_check(int(pause.call("get_cursor_index")) == PAUSE_ITEM_QUIT, "cursor is on Quit")
	_finish_summary()
	await _tap(&"confirm", 0.2)
	for i: int in 120:
		await _tick()
	print("QA FAIL  Quit did not close the game")
	quit(1)


# ---- finishing ----

func _finish() -> void:
	_finish_summary()
	quit(0 if _failures == 0 else 1)


func _finish_summary() -> void:
	_frame_stats()
	print("QA SUMMARY: %d failure(s)" % _failures)


func _frame_stats() -> void:
	var total: float = 0.0
	var worst: float = 0.0
	var over33: int = 0
	var over50: int = 0
	for ms: float in _frame_ms:
		total += ms
		worst = maxf(worst, ms)
		if ms > 33.4:
			over33 += 1
		if ms > 50.0:
			over50 += 1
	var count: int = _frame_ms.size()
	var avg: float = total / float(maxi(count, 1))
	print("QA FRAMES  %d frames: average %.1f ms (%.0f fps), worst %.1f ms, over 33 ms: %d, over 50 ms: %d" % [count, avg, 1000.0 / maxf(avg, 0.001), worst, over33, over50])


# ---- signal wiring and the event counters ----

func _wire_signals() -> void:
	if _director == null:
		return
	_director.connect("hit_landed", _on_hit_landed)
	_director.connect("launched", _on_launched)
	_director.connect("telegraphed", _on_telegraphed)
	_director.connect("parry_judged", _on_parry_judged)
	_director.connect("perfect_dodge", _on_perfect_dodge)
	_director.connect("actor_died", _on_actor_died)
	_player.connect("move_started", _on_move_started)
	_player.connect("jumped", _on_jumped)
	_player.connect("dashed", _on_dashed)


func _on_hit_landed(info: Dictionary) -> void:
	var outcome: String = str(info.get("outcome", "?"))
	_outcomes[outcome] = int(_outcomes.get(outcome, 0)) + 1
	_bump("hit")
	if str(info.get("target", "")) == "red":
		_bump("hits_on_red")
	if bool(info.get("airborne", false)):
		_bump("air_hit")


func _on_launched(_info: Dictionary) -> void:
	_bump("launched")


func _on_telegraphed(info: Dictionary) -> void:
	_last_tel = info.duplicate()
	_tel_usec = Time.get_ticks_usec()
	_bump("telegraph")


func _on_parry_judged(info: Dictionary) -> void:
	_judged.append(info.duplicate())
	_bump("parry_judged")


func _on_perfect_dodge(_info: Dictionary) -> void:
	_bump("perfect_dodge")


func _on_actor_died(_actor_id: StringName) -> void:
	_bump("death")


func _on_move_started(move_id: StringName) -> void:
	_moves_seen.append(str(move_id))


func _on_jumped(air: bool) -> void:
	_bump("jump_air" if air else "jump")


func _on_dashed(air: bool) -> void:
	_bump("dash_air" if air else "dash_ground")


func _bump(key: String) -> void:
	_counts[key] = int(_counts.get(key, 0)) + 1


func _count(key: String) -> int:
	return int(_counts.get(key, 0))


# ---- input injection: the same events a keyboard, mouse or pad would make ----

func _event_for(action: StringName, keycode: int = -1) -> InputEvent:
	var fallback: InputEvent = null
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			if keycode < 0 or (event as InputEventKey).physical_keycode == keycode or (event as InputEventKey).keycode == keycode:
				return event
			if fallback == null:
				fallback = event
		elif fallback == null:
			fallback = event
	return fallback


func _set_key(action: StringName, down: bool, keycode: int = -1) -> void:
	if bool(_held.get(action, false)) == down and keycode < 0:
		return
	_held[action] = down
	var source: InputEvent = _event_for(action, keycode)
	if source == null:
		print("QA FAIL  no input bound to %s" % str(action))
		return
	var event: InputEvent = source.duplicate() as InputEvent
	event.set("pressed", down)
	if event is InputEventKey:
		event.set("echo", false)
	Input.parse_input_event(event)


func _tap(action: StringName, after_s: float) -> void:
	_set_key(action, true)
	await _tick()
	_set_key(action, false)
	await _wait(after_s)


func _tap_key(action: StringName, keycode: int, after_s: float) -> void:
	_set_key(action, true, keycode)
	await _tick()
	await _tick()
	_set_key(action, false, keycode)
	await _wait(after_s)


func _set_key_wait(action: StringName, hold_s: float) -> void:
	_set_key(action, true)
	await _wait(hold_s)
	_set_key(action, false)


func _release_moves() -> void:
	for action: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		_set_key(action, false)
	await _tick()


func _mouse_flick(relative: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.relative = relative
	event.position = Vector2(960.0, 540.0)
	Input.parse_input_event(event)
	await _frames(4)


# ---- steering: keys chosen from the camera's view, so "forward" means what the player sees ----

func _cam() -> Camera3D:
	var orbit: Object = _sandbox.call("get_camera") as Object
	if orbit == null:
		return null
	return orbit.call("get_camera") as Camera3D


func _cam_fwd() -> Vector3:
	var cam: Camera3D = _cam()
	if cam == null:
		return Vector3.FORWARD
	var forward: Vector3 = -cam.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()


func _cam_right() -> Vector3:
	var cam: Camera3D = _cam()
	if cam == null:
		return Vector3.RIGHT
	var right: Vector3 = cam.global_transform.basis.x
	right.y = 0.0
	return right.normalized()


func _steer(target: Vector3) -> void:
	_steer_keep_range(target, 0.3)


func _steer_keep_range(target: Vector3, stop_m: float) -> void:
	var pos: Vector3 = _player.global_position
	var d: Vector3 = Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	if d.length() < stop_m:
		_set_key(&"move_up", false)
		_set_key(&"move_down", false)
		_set_key(&"move_left", false)
		_set_key(&"move_right", false)
		return
	var fwd: Vector3 = _cam_fwd()
	var right: Vector3 = _cam_right()
	var f: float = d.dot(fwd)
	var s: float = d.dot(right)
	var lim: float = d.length() * 0.35
	_set_key(&"move_up", f > lim)
	_set_key(&"move_down", f < -lim)
	_set_key(&"move_right", s > lim)
	_set_key(&"move_left", s < -lim)


func _walk_to(target: Vector3, timeout_s: float, reach_m: float = 0.9) -> bool:
	var t0: float = _now()
	while _now() - t0 < timeout_s:
		if _flat(target, _player.global_position) < reach_m:
			await _release_moves()
			return true
		_steer(target)
		await _tick()
	await _release_moves()
	return _flat(target, _player.global_position) < reach_m


func _approach_nearest(stop_m: float, timeout_s: float) -> Node3D:
	var t0: float = _now()
	var foe: Node3D = _nearest_living()
	while foe != null and _now() - t0 < timeout_s:
		if _flat(foe.global_position, _player.global_position) <= stop_m:
			break
		_steer(foe.global_position)
		await _tick()
		foe = _nearest_living()
	await _release_moves()
	return foe


# ---- enemies ----

func _living() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _sandbox == null:
		return out
	for item: Variant in _sandbox.call("get_enemies") as Array:
		var node: Node3D = item as Node3D
		if node != null and node.is_inside_tree() and not bool(node.get("dead")):
			out.append(node)
	return out


func _nearest_living() -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for node: Node3D in _living():
		var d: float = _flat(node.global_position, _player.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


## Counts respawns and notes enemies that stop dead against an obstacle while Red is close.
func _track_enemies() -> void:
	var living: int = _living().size()
	if _living_last >= 0 and living > _living_last and _count("death") > 0:
		for i: int in living - _living_last:
			_bump("respawn")
	_living_last = living
	var data: Dictionary = _sandbox.call("get_data") as Dictionary
	var pillars: Array = (data.get("arena", {}) as Dictionary).get("pillars", []) as Array
	for node: Node3D in _living():
		var key: String = str(node.get_instance_id())
		var pos: Vector3 = node.global_position
		for pillar: Variant in pillars:
			var p: Array = (pillar as Dictionary).get("pos", [0, 0, 0]) as Array
			var radius: float = float((pillar as Dictionary).get("radius", 1.0))
			if Vector2(pos.x - float(p[0]), pos.z - float(p[2])).length() < radius * 0.6 and pos.y < 4.0:
				var note: String = "enemy %s inside pillar at %s" % [key, str(pos)]
				if not _stuck_notes.has(note):
					_stuck_notes.append(note)
		if _last_pos.has(key) and (pos - (_last_pos[key] as Vector3)).length() > 0.05:
			_still_since[key] = _now()
		elif not _still_since.has(key):
			_still_since[key] = _now()
		_last_pos[key] = pos
		if _now() - float(_still_since[key]) > 6.0 and _flat(pos, _player.global_position) < 7.0 and bool(node.call("is_airborne")) == false:
			var stuck_note: String = "enemy %s stood still for 6 s at %s with Red 7 m away" % [key, str(pos)]
			if not _stuck_notes.has(stuck_note):
				_stuck_notes.append(stuck_note)
				print("QA INFO  " + stuck_note)
	_min_y = minf(_min_y, _player.global_position.y)


# ---- small helpers ----

func _has_sequence(moves: Array, wanted: Array) -> bool:
	var at: int = 0
	for move: String in moves:
		if at < wanted.size() and move == wanted[at]:
			at += 1
	return at == wanted.size()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _find_method(node: Node, method: StringName) -> Object:
	if node.has_method(method):
		return node
	for child: Node in node.get_children():
		var hit: Object = _find_method(child, method)
		if hit != null:
			return hit
	return null


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _tick() -> void:
	await process_frame
	var now: int = Time.get_ticks_usec()
	if _last_usec > 0:
		_frame_ms.append(float(now - _last_usec) / 1000.0)
	_last_usec = now
	if _sandbox != null and _player != null and is_instance_valid(_player):
		_min_y = minf(_min_y, _player.global_position.y)


func _frames(n: int) -> void:
	for i: int in n:
		await _tick()


func _wait(seconds: float) -> void:
	var end: float = _now() + seconds
	while _now() < end:
		await _tick()


func _shot(shot_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(SHOTS + "qa_sandbox_" + shot_name + ".png")


func _check(ok: bool, what: String) -> void:
	print(("QA PASS  " if ok else "QA FAIL  ") + what)
	if not ok:
		_failures += 1
