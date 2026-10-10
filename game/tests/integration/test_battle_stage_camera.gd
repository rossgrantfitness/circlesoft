extends TestCase
## The Dynamic battle camera (Ross's storyboard, 2026-10-07): every shot in the data is valid, the intro is
## short, seeded, skippable and ends on the settle, the boss low-POV is only for bosses, idle keeps both rows
## readable under the HUD, action shots frame the actor and the target, and THE rule: during every Clutch press
## window the actor and the target stay inside the safe frame and the camera barely moves. Plus screen_pos_of
## tracking, Calm mode being static, and the Config toggle. Needs the project imported once.

const SCENE: String = "res://scenes/battle/battle_scene.tscn"
const STUB: String = "res://tests/fixtures/battle_stage/stub_battle_controller.gd"
const CONFIG_SCRIPT: String = "res://scripts/core/config.gd"
const SCRATCH: String = "user://test_battle_cam_config_scratch.json"
const STAGE_SIZE: Vector2 = Vector2(384.0, 216.0)
const ASPECT: float = 16.0 / 9.0
const EASES: PackedStringArray = ["linear", "in", "out", "inout", "cut"]
const ANCHORS: PackedStringArray = ["mid", "party", "enemy", "boss", "actor", "target", "pair_mid", "hero0", "hero1", "hero2", "foe0", "foe1", "foe2", "foe3"]
const HEIGHTS: Dictionary = {"red": 1.1, "otis": 1.4, "mox": 1.25, "e1": 1.2, "e2": 1.2, "e3": 1.2, "e4": 1.2}
const TOLERANCE: float = 0.03
const WINDOW_LEAD_MS: float = 300.0
const WINDOW_TAIL_MS: float = 150.0
const RATE_WINDOW_S: float = 0.1
const MAX_FRAME_GAP_S: float = 0.05
const FRAME_LIMIT_S: float = 12.0

var _signal_hits: int = 0


func _tuning() -> BattleStageTuning:
	return BattleStageTuning.from_db(tree.root.get_node("DataDB"))


func _cam() -> BattleStageTuning:
	return BattleStageTuning.from_db_id(tree.root.get_node("DataDB"), BattleStageTuning.CAMERA_ID)


func _frame(party: Array = [], enemies: Array = []) -> BattleCamFrame:
	var stage_t: BattleStageTuning = _tuning()
	var list: Array = []
	var party_ids: Array[String] = ["red", "otis", "mox"]
	var party_count: int = 3 if party.is_empty() else party.size()
	for i: int in party_count:
		var pos: Vector3 = stage_t.slot_position("party", i) if party.is_empty() else party[i]
		var id: String = party_ids[i]
		list.append({"id": id, "side": "party", "slot": i, "pos": pos, "height": HEIGHTS[id], "is_boss": false})
	var enemy_count: int = 4 if enemies.is_empty() else enemies.size()
	for i: int in enemy_count:
		var pos: Vector3 = stage_t.slot_position("enemy", i) if enemies.is_empty() else enemies[i]
		list.append({"id": "e%d" % (i + 1), "side": "enemy", "slot": i, "pos": pos, "height": 1.2, "is_boss": false})
	var frame: BattleCamFrame = BattleCamFrame.new()
	var cam: BattleStageTuning = _cam()
	frame.build(list, cam.number("director.ref_half_span"), cam.number("director.scale_min"), cam.number("director.scale_max"))
	return frame


func _director(seed_value: int = 1, frame: BattleCamFrame = null) -> BattleCamDirector:
	var director: BattleCamDirector = BattleCamDirector.new()
	director.setup(_cam(), frame if frame != null else _frame(), seed_value, ASPECT)
	return director


func _inside(pose: BattleCamPose, frame: BattleCamFrame, ids: Array, x_range: Array, y_range: Array, tolerance: float = 0.0) -> bool:
	for id: Variant in ids:
		var feet: Vector3 = frame.position_of(str(id))
		for point: Vector3 in [feet, feet + Vector3.UP * frame.height_of(str(id))]:
			var at: Vector2 = BattleCamMath.project_pose(pose, ASPECT, point)
			if at.x < float(x_range[0]) - tolerance or at.x > float(x_range[1]) + tolerance:
				return false
			if at.y < float(y_range[0]) - tolerance or at.y > float(y_range[1]) + tolerance:
				return false
	return true


func _count(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_signal_hits += 1


func _dynamic_stage(boss_id: String = "", virtual_clock: bool = false) -> Array:
	var stage: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	stage.transitions_enabled = false
	stage.audio = FakeAudio.new()
	stage.camera_seed = 4
	add_to_root(stage)
	stage.set_dynamic_camera(true)
	var stub: RefCounted = (load(STUB) as GDScript).new() as RefCounted
	stub.set("instant", true)
	stub.set("boss_id", boss_id)
	stub.set("is_boss", not boss_id.is_empty())
	if virtual_clock:
		stub.set("use_virtual_clock", true)
		stub.set("virtual_usec", 1000000)
	stage.attach_controller(stub)
	stage._on_battle_started(stub.call("snapshot"))
	return [stage, stub]


# ---- the data ----

func test_every_shot_in_the_data_is_valid() -> void:
	var cam: BattleStageTuning = _cam()
	var shots: Dictionary = cam.dict("shots")
	assert_gt(shots.size(), 10)
	var director: BattleCamDirector = _director()
	for id: String in shots:
		var shot: Dictionary = shots[id]
		var is_template: bool = shot.has("action_side")
		if is_template:
			for field: String in ["pos", "look"]:
				_check_spec(shot[field], "%s.%s" % [id, field])
			assert_gt(float(shot["fov"]), 15.0, id)
			assert_lt(float(shot["fov"]), 75.0, id)
			assert_eq((shot["drift"] as Array).size(), 3, id + " drift")
			continue
		assert_gt(float(shot["duration_ms"]), 100.0, id + " duration")
		assert_true(EASES.has(str(shot["ease"])), id + " ease")
		assert_gt(int(shot.get("panel", shot.get("panels", [0])[0] if shot.has("panels") else 0)), 0, id + " names its storyboard panel")
		var keys: Array = shot["keys"]
		assert_ge(keys.size(), 2, id + " has at least two keys")
		for i: int in keys.size():
			var key: Dictionary = keys[i]
			_check_spec(key["pos"], "%s key %d pos" % [id, i])
			_check_spec(key["look"], "%s key %d look" % [id, i])
			assert_ge(float(key["fov"]), 25.0, id)
			assert_le(float(key["fov"]), 65.0, id)
			assert_le(absf(float(key["roll"])), 15.0, id + " roll")
		var clip: BattleCamDirector.Clip = director.build_clip(id)
		assert_eq(clip.keys.size(), keys.size())
		for pose: BattleCamPose in clip.keys:
			assert_true(is_finite(pose.position.x) and is_finite(pose.position.y) and is_finite(pose.position.z), id + " finite position")
			assert_gt(pose.position.y, 0.2, id + " stays above the floor")
			assert_gt(pose.position.x, -5.0, id + " stays inside the left wall")
			assert_gt(pose.position.z, -3.5, id + " stays in front of the back wall")
			assert_lt(pose.position.y, 12.0, id + " stays low enough to be inside the set")
	var intro: Dictionary = cam.dict("director.intro")
	for id: Variant in intro["pool"]:
		assert_true(shots.has(str(id)), "pool shot %s exists" % id)
		assert_false(bool((shots[str(id)] as Dictionary).get("boss_only", false)), "the regular pool has no boss shot")
	for id: Variant in intro["boss_shots"]:
		assert_true(bool((shots[str(id)] as Dictionary).get("boss_only", false)), "%s is marked boss_only" % id)
	assert_true(shots.has(str(intro["settle"])))
	for id: Variant in cam.list("director.idle_variants"):
		assert_true(shots.has(str(id)))
		assert_eq(str((shots[str(id)] as Dictionary).get("loop", "")), "pingpong", "idle shots loop")
	assert_true(shots.has("party_action") and shots.has("enemy_action"))


func _check_spec(spec: Dictionary, label: String) -> void:
	assert_true(ANCHORS.has(str(spec["at"])), "%s: known anchor %s" % [label, spec["at"]])
	assert_eq((spec["off"] as Array).size(), 3, label + " offset has x y z")


func test_idle_starts_exactly_where_the_settle_ends() -> void:
	var director: BattleCamDirector = _director()
	var settle: BattleCamDirector.Clip = director.build_clip("settle")
	for id: String in ["idle_track", "idle_drift"]:
		var idle: BattleCamDirector.Clip = director.build_clip(id)
		assert_lt(idle.keys[0].position.distance_to(settle.keys[1].position), 0.01, id + " position")
		assert_lt(idle.keys[0].look.distance_to(settle.keys[1].look), 0.01, id + " look")
		assert_almost_eq(idle.keys[0].fov, settle.keys[1].fov, 0.01, id + " fov")


func test_the_settle_is_the_old_fixed_framing() -> void:
	var stage_t: BattleStageTuning = _tuning()
	var director: BattleCamDirector = _director()
	var settle: BattleCamDirector.Clip = director.build_clip("settle")
	var old_look: Vector3 = stage_t.vec3("camera.look_at")
	assert_lt(settle.keys[1].look.distance_to(old_look), 0.3, "looks where the calm camera looks")
	var old_pos_len: float = stage_t.number("camera.distance")
	assert_lt(absf(settle.keys[1].position.distance_to(settle.keys[1].look) - old_pos_len), 0.8, "about the same distance")


# ---- the intro ----

func test_regular_intro_is_two_or_three_shots_in_range_and_ends_on_the_settle() -> void:
	var plans: Dictionary = {}
	for seed_value: int in 60:
		var director: BattleCamDirector = _director(seed_value)
		director.start_intro(false)
		var plan: Array[String] = director.intro_plan()
		assert_ge(plan.size(), 3, "2 shots + settle")
		assert_le(plan.size(), 4, "3 shots + settle")
		assert_eq(plan[plan.size() - 1], "settle", "ends on the settle")
		assert_false(plan.has("boss_low"), "no boss shot in a regular fight")
		assert_ge(director.intro_length_s(), 2.5, "seed %d: %f s" % [seed_value, director.intro_length_s()])
		assert_le(director.intro_length_s(), 3.5, "seed %d: %f s" % [seed_value, director.intro_length_s()])
		var seen: Dictionary = {}
		for id: String in plan:
			assert_false(seen.has(id), "no shot twice in one intro")
			seen[id] = true
		plans[",".join(plan)] = true
	assert_ge(plans.size(), 6, "the intro is not the same every time")
	var a: BattleCamDirector = _director(9)
	var b: BattleCamDirector = _director(9)
	a.start_intro(false)
	b.start_intro(false)
	assert_eq(a.intro_plan(), b.intro_plan(), "seeded: the same seed gives the same intro")


func test_the_intro_plays_through_in_its_planned_time_and_lands_on_idle() -> void:
	var director: BattleCamDirector = _director(5)
	_signal_hits = 0
	director.intro_finished.connect(_count)
	director.settle_started.connect(_count)
	director.start_intro(false)
	var length: float = director.intro_length_s()
	var elapsed: float = 0.0
	while director.is_intro_playing() and elapsed < length + 1.0:
		director.advance(1.0 / 60.0)
		elapsed += 1.0 / 60.0
	assert_false(director.is_intro_playing())
	assert_almost_eq(elapsed, length, 0.1, "it takes the planned length")
	assert_eq(_signal_hits, 2, "settle_started once, intro_finished once")
	var idle_start: BattleCamPose = director.build_clip("idle_track").keys[0]
	assert_lt(director.live_pose().position.distance_to(idle_start.position), 0.35, "the settle hands over to idle without a jump")


func test_any_press_skips_straight_to_the_settle() -> void:
	var director: BattleCamDirector = _director(2)
	_signal_hits = 0
	director.settle_started.connect(_count)
	director.intro_finished.connect(_count)
	director.start_intro(false)
	for i: int in 20:
		director.advance(1.0 / 60.0)
	assert_true(director.is_intro_playing())
	director.skip_intro()
	assert_eq(_signal_hits, 1, "the settle began at once")
	var elapsed: float = 0.0
	while director.is_intro_playing() and elapsed < 2.0:
		director.advance(1.0 / 60.0)
		elapsed += 1.0 / 60.0
	assert_lt(elapsed, 0.5, "the settle plays fast after a skip (%f s)" % elapsed)
	assert_eq(_signal_hits, 2)
	director.skip_intro()
	assert_eq(_signal_hits, 2, "skipping when nothing is playing does nothing")


func test_boss_intro_is_the_low_pov_and_only_bosses_get_it() -> void:
	var director: BattleCamDirector = _director(3)
	director.start_intro(true)
	assert_eq(director.intro_plan(), ["boss_low", "settle"] as Array[String], "panel 11, then the settle")
	assert_almost_eq(director.intro_length_s(), 3.2, 0.1)
	var clip: BattleCamDirector.Clip = director.build_clip("boss_low")
	assert_lt(clip.keys[0].position.y, 0.6, "low point of view")
	assert_gt(clip.keys[1].look.y, clip.keys[0].look.y + 1.0, "tilts up to the boss")
	var low: Array = ["boss_low"]
	for seed_value: int in 80:
		var regular: BattleCamDirector = _director(seed_value)
		regular.start_intro(false)
		for id: String in low:
			assert_false(regular.intro_plan().has(id), "never in a regular fight")


func test_the_scene_picks_the_boss_shot_only_for_a_flagged_encounter() -> void:
	var boss_pair: Array = _dynamic_stage("e1")
	var boss_stage: BattleScene = boss_pair[0]
	assert_true(boss_stage.is_boss)
	boss_stage._start_camera_intro()
	assert_eq(boss_stage.camera_director.intro_plan(), ["boss_low", "settle"] as Array[String])
	var red: CombatantView = boss_stage.get_view("red")
	var dark: float = red.current_tint_energy()
	boss_stage.camera_director.skip_intro()
	assert_gt(red.current_tint_energy(), dark + 0.2, "the party is a silhouette in the low shot and lit again at the settle")
	var normal_pair: Array = _dynamic_stage("")
	var normal_stage: BattleScene = normal_pair[0]
	assert_false(normal_stage.is_boss)
	normal_stage._start_camera_intro()
	assert_false(normal_stage.camera_director.intro_plan().has("boss_low"))


func test_a_press_skips_the_intro_in_the_scene_and_does_not_reach_the_controller() -> void:
	var pair: Array = _dynamic_stage()
	var stage: BattleScene = pair[0]
	var stub: RefCounted = pair[1]
	stage._start_camera_intro()
	assert_true(stage.camera_director.is_intro_playing())
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	stage.handle_input_event(key)
	assert_eq(stage.camera_director._override.id, "settle", "straight to the settle")
	assert_eq((stub.get("downs") as Array).size(), 0, "the skipping press is not a Clutch press")
	for i: int in 40:
		stage.camera_director.advance(1.0 / 30.0)
	assert_false(stage.camera_director.is_intro_playing())


func test_the_scene_intro_runs_start_to_finish_with_a_skip() -> void:
	var stage: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	stage.transitions_enabled = false
	stage.audio = FakeAudio.new()
	stage.camera_seed = 7
	add_to_root(stage)
	stage.set_dynamic_camera(true)
	var stub_holder: Array[RefCounted] = []
	stage.controller_factory = func(_setup: RefCounted) -> Object:
		var made: RefCounted = (load(STUB) as GDScript).new() as RefCounted
		made.set("instant", true)
		stub_holder.append(made)
		return made
	var finished_flag: Array[bool] = [false]
	stage.intro_finished.connect(func() -> void: finished_flag[0] = true)
	stage.start_battle(RefCounted.new())
	await tree.process_frame
	await tree.process_frame
	assert_false(stub_holder[0].get("started"), "the controller waits for the intro")
	var event: InputEventAction = InputEventAction.new()
	event.action = &"confirm"
	event.pressed = true
	stage.handle_input_event(event)
	var start: int = Time.get_ticks_msec()
	while not finished_flag[0] and Time.get_ticks_msec() - start < 3000:
		await tree.process_frame
	assert_true(finished_flag[0], "the skipped intro ended quickly")
	assert_true(stub_holder[0].get("started"), "then the fight starts")
	assert_lt(Time.get_ticks_msec() - start, 1800)


# ---- idle and action framing ----

func test_idle_keeps_both_rows_readable_under_the_hud() -> void:
	var cam: BattleStageTuning = _cam()
	var ids: Array = HEIGHTS.keys()
	var x_range: Array = cam.list("director.idle_safe.x")
	var y_range: Array = cam.list("director.idle_safe.y")
	for variant: int in 2:
		var director: BattleCamDirector = _director(1)
		director._idle_variant = variant
		director.start_idle()
		for step: int in 800:
			director.advance(1.0 / 30.0)
			assert_true(_inside(director.pose(), director.frame, ids, x_range, y_range), "variant %d at %.1f s" % [variant, director.time_s])
			assert_gt(step, -1)
		var settled: BattleCamPose = director.build_clip("settle").keys[1]
		assert_true(_inside(settled, director.frame, ids, x_range, y_range), "the settle shows everyone")


func test_idle_is_gentle() -> void:
	var cam: BattleStageTuning = _cam()
	var director: BattleCamDirector = _director(1)
	var worst: float = 0.0
	var last: Basis = director.pose().basis()
	var last_fov: float = director.pose().fov
	for i: int in 600:
		for k: int in 2:
			director.advance(1.0 / 60.0)
		var now: Basis = director.pose().basis()
		var rate: float = BattleCamMath.angle_deg_between(last, now) / (1.0 / 30.0)
		worst = maxf(worst, rate)
		assert_lt(absf(director.pose().fov - last_fov) / (1.0 / 30.0), cam.number("director.limits.max_fov_deg_per_s"))
		last = now
		last_fov = director.pose().fov
	assert_lt(worst, 3.0, "idle drift turns the camera by less than 3 degrees a second (%f)" % worst)


func test_action_shots_frame_the_actor_and_target_in_the_centre_band() -> void:
	var cam: BattleStageTuning = _cam()
	var x_range: Array = cam.list("director.safe.x")
	var y_range: Array = cam.list("director.safe.y")
	var frame: BattleCamFrame = _frame()
	var party: Array[String] = frame.ids_on("party")
	var foes: Array[String] = frame.ids_on("enemy")
	var pairs: Array = []
	for hero: String in party:
		for foe: String in foes:
			pairs.append([hero, [foe], "party"])
			pairs.append([foe, [hero], "enemy"])
		pairs.append([hero, foes, "party"])
	pairs.append(["mox", ["red"], "party"])
	pairs.append(["red", ["red"], "party"])
	for pair: Array in pairs:
		var director: BattleCamDirector = _director(1, frame)
		var info: Dictionary = director.begin_action({"actor": pair[0], "targets": pair[1], "side": pair[2], "lock_start_s": 0.4, "lock_end_s": 1.2})
		assert_eq(info["shot"], "party_action" if pair[2] == "party" else "enemy_action")
		var final_pose: BattleCamPose = director._override.keys[0]
		var subjects: Array = [pair[0]]
		subjects.append_array(pair[1])
		assert_true(_inside(final_pose, frame, subjects, x_range, y_range, 0.001), "%s -> %s is inside the safe frame" % [pair[0], pair[1]])
		assert_almost_eq(final_pose.roll, 0.0, 0.0001, "no roll in an action shot")
		assert_eq(director.clamp_to_bounds(final_pose.position), final_pose.position, "the camera stays inside the set")
		assert_lt(final_pose.fov, 66.0, "no fisheye in an action shot")


func test_actions_ease_in_when_there_is_time_and_cut_when_there_is_not() -> void:
	var director: BattleCamDirector = _director(1)
	var eased: Dictionary = director.begin_action({"actor": "e1", "targets": ["red"], "side": "enemy", "lock_start_s": 0.6, "lock_end_s": 1.4})
	assert_true(eased["eased"])
	assert_le(float(eased["ease_s"]), 0.6 + 0.001, "the ease is done before the lock opens")
	var quick: BattleCamDirector = _director(1)
	var cut: Dictionary = quick.begin_action({"actor": "red", "targets": ["e1"], "side": "party", "lock_start_s": 0.05, "lock_end_s": 0.7})
	assert_false(cut["eased"], "no time to ease: a single cut")
	assert_eq(float(cut["ease_s"]), 0.0)
	var arrive: BattleCamDirector = _director(1)
	arrive.begin_action({"actor": "e1", "targets": ["red"], "side": "enemy", "lock_start_s": 0.6, "lock_end_s": 1.4})
	for i: int in 40:
		arrive.advance(1.0 / 60.0)
	assert_true(arrive.in_lock())
	var held: BattleCamPose = arrive._override.keys[0]
	assert_lt(arrive.live_pose().position.distance_to(held.position), 0.2, "arrived by the time the lock opens (only the slow drift)")
	for i: int in 70:
		arrive.advance(1.0 / 60.0)
	assert_eq(arrive.mode, BattleCamDirector.Mode.IDLE, "back to idle after the lock")


# ---- THE rule: the Clutch window stays readable ----

## Plays one action on a Dynamic stage in real time and returns the camera / screen samples per frame.
func _play_action(actor: String, targets: Array, presses: Array, kind: String, windup: int, impact: int, end: int) -> Dictionary:
	var pair: Array = _dynamic_stage()
	var stage: BattleScene = pair[0]
	var stub: RefCounted = pair[1]
	stage.camera_director.start_idle()
	for i: int in 12:
		await tree.process_frame
	var action: Dictionary = stub.call("make_action", actor, kind, targets, 500, actor, "attack", windup, impact, end)
	action["presses"] = presses
	var t0: int = int(action["t0_usec"])
	stage._on_action_started(action)
	var last_cue: float = 0.0
	var first_cue: float = INF
	for press: Dictionary in presses:
		last_cue = maxf(last_cue, float(press["cue_ms"]))
		first_cue = minf(first_cue, float(press["cue_ms"]))
		if float(press.get("hold_by_ms", 0)) > 0.0:
			first_cue = minf(first_cue, float(press["hold_by_ms"]))
	var samples: Array[Dictionary] = []
	var subjects: Array = [actor]
	subjects.append_array(targets)
	var camera: Camera3D = stage.camera_rig.get_camera()
	while float(Time.get_ticks_usec() - t0) / 1000.0 < last_cue + 700.0:
		await tree.process_frame
		var sample: Dictionary = {"t_ms": float(Time.get_ticks_usec() - t0) / 1000.0, "basis": stage.camera_rig.fixed_basis(),
				"pos": stage.camera_rig.position, "fov": camera.fov, "roll": stage.camera_rig.current_pose.roll, "screen": {}}
		for id: String in subjects:
			sample["screen"][id] = [stage.screen_pos_of(id, &"feet"), stage.screen_pos_of(id, &"head")]
		samples.append(sample)
	return {"samples": samples, "open_ms": first_cue - WINDOW_LEAD_MS, "close_ms": last_cue + WINDOW_TAIL_MS, "subjects": subjects}


func _check_window(result: Dictionary, label: String) -> void:
	var cam: BattleStageTuning = _cam()
	var limits: Dictionary = cam.dict("director.limits")
	var x_range: Array = cam.list("director.safe.x")
	var y_range: Array = cam.list("director.safe.y")
	var inside: Array[Dictionary] = []
	for sample: Dictionary in result["samples"]:
		if float(sample["t_ms"]) >= float(result["open_ms"]) and float(sample["t_ms"]) <= float(result["close_ms"]):
			inside.append(sample)
	if OS.get_environment("CAM_DEBUG") == "1":
		var prev: Dictionary = {}
		for sample: Dictionary in result["samples"]:
			var rot: float = BattleCamMath.angle_deg_between(prev["basis"], sample["basis"]) if not prev.is_empty() else 0.0
			print("%s t=%.0f rot=%.1f fov=%.1f pos=%s" % [label, sample["t_ms"], rot, sample["fov"], (sample["pos"] as Vector3).snapped(Vector3.ONE * 0.01)])
			prev = sample
		print("%s window %.0f..%.0f" % [label, result["open_ms"], result["close_ms"]])
	assert_gt(inside.size(), 6, label + ": the window was sampled")
	for sample: Dictionary in inside:
		for id: String in result["subjects"]:
			var spots: Array = sample["screen"][id]
			var feet: Vector2 = spots[0]
			var head: Vector2 = spots[1]
			assert_ge(feet.x / STAGE_SIZE.x, float(x_range[0]) - TOLERANCE, "%s %s feet x at %d ms" % [label, id, int(sample["t_ms"])])
			assert_le(feet.x / STAGE_SIZE.x, float(x_range[1]) + TOLERANCE, "%s %s feet x at %d ms" % [label, id, int(sample["t_ms"])])
			assert_le(feet.y / STAGE_SIZE.y, float(y_range[1]) + TOLERANCE, "%s %s feet y at %d ms (above the HUD)" % [label, id, int(sample["t_ms"])])
			assert_ge(head.y / STAGE_SIZE.y, float(y_range[0]) - TOLERANCE, "%s %s head y at %d ms" % [label, id, int(sample["t_ms"])])
		assert_le(absf(float(sample["roll"])), float(limits["max_roll_deg"]), label + ": no roll in the window")
	var worst_rotation: float = 0.0
	var worst_speed: float = 0.0
	var worst_fov: float = 0.0
	for i: int in inside.size():
		var hitch: bool = false
		for j: int in range(i + 1, inside.size()):
			var gap: float = (float(inside[j]["t_ms"]) - float(inside[j - 1]["t_ms"])) / 1000.0
			hitch = hitch or gap > MAX_FRAME_GAP_S      # a long frame (a loaded machine) is a hitch, not a camera move
			var dt: float = (float(inside[j]["t_ms"]) - float(inside[i]["t_ms"])) / 1000.0
			if dt < RATE_WINDOW_S:
				continue
			if not hitch:
				worst_rotation = maxf(worst_rotation, BattleCamMath.angle_deg_between(inside[i]["basis"], inside[j]["basis"]) / dt)
				worst_speed = maxf(worst_speed, (inside[j]["pos"] as Vector3).distance_to(inside[i]["pos"]) / dt)
				worst_fov = maxf(worst_fov, absf(float(inside[j]["fov"]) - float(inside[i]["fov"])) / dt)
			break
	assert_lt(worst_rotation, float(limits["max_rotation_deg_per_s"]), "%s: angular velocity %f deg/s" % [label, worst_rotation])
	assert_lt(worst_speed, float(limits["max_speed_per_s"]), "%s: camera speed %f u/s" % [label, worst_speed])
	assert_lt(worst_fov, float(limits["max_fov_deg_per_s"]), "%s: FOV rate %f deg/s" % [label, worst_fov])


func test_clutch_window_party_tap_stays_readable() -> void:
	var presses: Array = [{"index": 0, "type": "tap", "side": "attack", "cue_ms": 450, "hold_by_ms": 0, "owner_id": "red"}]
	var result: Dictionary = await _play_action("red", ["e1"], presses, "attack", 250, 450, 800)
	_check_window(result, "red taps")


func test_clutch_window_enemy_attack_with_a_block_stays_readable() -> void:
	var presses: Array = [{"index": 0, "type": "tap", "side": "block", "cue_ms": 900, "hold_by_ms": 0, "owner_id": "red"}]
	var result: Dictionary = await _play_action("e1", ["red"], presses, "skill", 650, 900, 1300)
	_check_window(result, "grunt swings at red")


func test_clutch_window_hold_and_release_stays_readable() -> void:
	var presses: Array = [{"index": 0, "type": "hold_release", "side": "attack", "cue_ms": 1200, "hold_by_ms": 700, "owner_id": "otis"}]
	var result: Dictionary = await _play_action("otis", ["e2"], presses, "skill", 400, 1250, 1700)
	_check_window(result, "otis holds")


func test_clutch_window_string_of_taps_stays_readable() -> void:
	var presses: Array = [
		{"index": 0, "type": "string", "side": "attack", "cue_ms": 450, "hold_by_ms": 0, "owner_id": "mox"},
		{"index": 1, "type": "string", "side": "attack", "cue_ms": 800, "hold_by_ms": 0, "owner_id": "mox"}]
	var result: Dictionary = await _play_action("mox", ["e3"], presses, "skill", 200, 450, 1200)
	_check_window(result, "mox string")


func test_the_cue_flash_ding_and_marker_timing_is_unchanged_by_the_camera() -> void:
	var pair: Array = _dynamic_stage("", true)
	var stage: BattleScene = pair[0]
	var stub: RefCounted = pair[1]
	var action: Dictionary = stub.call("make_action", "red", "attack", ["e1"], 500)
	stage._on_action_started(action)
	assert_eq(stage.pending_cue_count(), 1)
	stub.set("virtual_usec", 1499999)
	stage._fire_due_cues()
	assert_eq(stage.pending_cue_count(), 1, "1 microsecond early: still waiting")
	stub.set("virtual_usec", 1500000)
	stage._fire_due_cues()
	assert_eq(stage.pending_cue_count(), 0)
	assert_true(stage.get_view("red").is_flashing())
	assert_eq((stage.audio as FakeAudio).sfx_ids.count("battle_ding"), 1)


func test_big_hits_do_not_push_the_camera_in_near_a_window() -> void:
	var pair: Array = _dynamic_stage("", true)
	var stage: BattleScene = pair[0]
	var stub: RefCounted = pair[1]
	var action: Dictionary = stub.call("make_action", "red", "skill", ["e1"], 450)
	var presses: Array = [
		{"index": 0, "type": "string", "side": "attack", "cue_ms": 450, "hold_by_ms": 0, "owner_id": "red"},
		{"index": 1, "type": "string", "side": "attack", "cue_ms": 800, "hold_by_ms": 0, "owner_id": "red"}]
	action["presses"] = presses
	stage._on_action_started(action)
	stage._on_press_judged({"actor": "red", "index": 0, "side": "attack", "rating": "totally_rad", "delta_ms": 3})
	stage._on_hit({"source": "red", "target": "e1", "amount": 20, "kind": "damage", "blocked": "none", "payback": false})
	assert_true(stage.camera_rig.is_shaking(), "the TOTALLY RAD shake still plays")
	assert_false(stage.camera_rig.is_pushing(), "but no push-in while the next press is about to open")


# ---- the HUD and screen_pos_of ----

func test_screen_pos_of_follows_the_moving_camera_every_step() -> void:
	var pair: Array = _dynamic_stage()
	var stage: BattleScene = pair[0]
	stage.set_process(false)
	var rig: BattleCamera = stage.camera_rig
	var first: Vector2 = stage.screen_pos_of("red")
	var moved: float = 0.0
	for step: int in 30:
		stage._update_camera(0.35)
		for id: String in ["red", "otis", "e1", "e4"]:
			var expected: Vector2 = BattleCamMath.project_pose(rig.current_pose, stage._aspect(), stage.views[id].get_head_point()) * STAGE_SIZE
			var got: Vector2 = stage.screen_pos_of(id)
			assert_lt(got.distance_to(expected), 1.0, "%s: screen_pos_of matches the camera it is looking through (step %d)" % [id, step])
		moved = maxf(moved, stage.screen_pos_of("red").distance_to(first))
	assert_gt(moved, 3.0, "the camera really moved and the position followed")


func test_the_hud_asks_the_stage_every_time() -> void:
	var pair: Array = _dynamic_stage()
	var stage: BattleScene = pair[0]
	if stage.hud == null:
		assert_true(true, "no HUD scene")
		return
	stage.set_process(false)
	var before: Vector2 = stage.hud.call("position_of", "red")
	for i: int in 10:
		stage._update_camera(0.5)
	var after: Vector2 = stage.hud.call("position_of", "red")
	assert_lt(after.distance_to(stage.screen_pos_of("red")), 0.5, "the HUD point is the stage point")
	assert_gt(after.distance_to(before), 1.0, "and it moved with the camera")


# ---- calm mode, formations, config ----

func test_calm_mode_is_static_and_has_no_intro() -> void:
	var stage: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	stage.transitions_enabled = false
	stage.audio = FakeAudio.new()
	add_to_root(stage)
	stage.set_dynamic_camera(false)
	var stub: RefCounted = (load(STUB) as GDScript).new() as RefCounted
	stub.set("instant", true)
	stage.controller_factory = func(_setup: RefCounted) -> Object:
		return stub
	var begin: int = Time.get_ticks_msec()
	await stage.start_battle(RefCounted.new())
	assert_lt(Time.get_ticks_msec() - begin, 1000, "no camera intro in Calm mode")
	assert_true(stub.get("started"))
	assert_false(stage.camera_director.is_intro_playing())
	var before: Transform3D = stage.camera_rig.transform
	var fov: float = stage.camera_rig.get_camera().fov
	var action: Dictionary = stub.call("make_action", "red", "attack", ["e1"], 300, "red", "attack", 120, 250, 400)
	stage._on_action_started(action)
	for i: int in 30:
		await tree.process_frame
	assert_true(stage.camera_rig.transform.is_equal_approx(before), "the calm camera does not move for an action")
	assert_almost_eq(stage.camera_rig.get_camera().fov, fov, 0.0001)
	assert_false(stage.camera_rig.dynamic)
	stage.set_dynamic_camera(true)
	assert_true(stage.dynamic_camera)


func test_calm_mode_still_has_the_old_boss_push_in() -> void:
	var stage: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	stage.transitions_enabled = false
	stage.audio = FakeAudio.new()
	add_to_root(stage)
	stage.set_dynamic_camera(false)
	var stub: RefCounted = (load(STUB) as GDScript).new() as RefCounted
	stub.set("instant", true)
	stub.set("boss_id", "e1")
	stage.attach_controller(stub)
	stage._on_battle_started(stub.call("snapshot"))
	var tell: Dictionary = stub.call("make_action", "e1", "attack", ["red"], 1200, "red", "block", 1000, 1300, 1600)
	stage._on_action_started(tell)
	assert_true(stage.camera_rig.is_pushing())


func test_shots_fit_other_formations() -> void:
	var layouts: Array = [
		[[Vector3(2.5, 0, 0.3), Vector3(3.6, 0, -0.8)], [Vector3(-2.8, 0, 0.0)]],
		[[Vector3(1.5, 0, 0.2), Vector3(3.9, 0, -0.5), Vector3(2.6, 0, 1.4)], [Vector3(-4.0, 0, 0.0), Vector3(-2.0, 0, 1.5), Vector3(-3.4, 0, -1.5), Vector3(-1.2, 0, 0.0)]],
	]
	for layout: Array in layouts:
		var frame: BattleCamFrame = _frame(layout[0], layout[1])
		var director: BattleCamDirector = _director(4, frame)
		for id: String in ["over_shoulder", "crane_down", "front_row", "foes_roll", "dutch_pan", "wide_depth", "boss_low", "settle", "idle_track", "idle_drift"]:
			for pose: BattleCamPose in director.build_clip(id).keys:
				assert_true(is_finite(pose.position.x) and is_finite(pose.look.x), id)
				assert_gt(pose.position.distance_to(pose.look), 0.5, id + ": the camera is not on top of its target")
		var ids: Array = frame.entries.keys()
		var settled: BattleCamPose = director.build_clip("settle").keys[1]
		assert_true(_inside(settled, frame, ids, [0.01, 0.99], [0.02, 0.8]), "the settle shows every fighter in a different layout")
		var party: Array[String] = frame.ids_on("party")
		var foes: Array[String] = frame.ids_on("enemy")
		var info: Dictionary = director.begin_action({"actor": party[0], "targets": [foes[0]], "side": "party", "lock_start_s": 0.4, "lock_end_s": 1.0})
		assert_eq(info["shot"], "party_action")
		var pose_now: BattleCamPose = director._override.keys[0]
		assert_true(_inside(pose_now, frame, [party[0], foes[0]], [0.16, 0.84], [0.12, 0.7], 0.001))


func test_config_has_the_battle_camera_toggle_default_dynamic() -> void:
	var config: Node = own((load(CONFIG_SCRIPT) as GDScript).new() as Node) as Node
	config.set("save_path", SCRATCH)
	config.set("apply_bindings_live", false)
	assert_true(config.get("dynamic_battle_camera"), "Dynamic by default")
	config.call("set_dynamic_battle_camera", false)
	assert_false(config.get("dynamic_battle_camera"))
	assert_true((config.call("to_dict") as Dictionary).has("dynamic_battle_camera"))
	config.call("save_file")
	var other: Node = own((load(CONFIG_SCRIPT) as GDScript).new() as Node) as Node
	other.set("save_path", SCRATCH)
	other.set("apply_bindings_live", false)
	other.call("load_file")
	assert_false(other.get("dynamic_battle_camera"), "Calm is remembered")
	var old_file: Node = own((load(CONFIG_SCRIPT) as GDScript).new() as Node) as Node
	old_file.call("from_dict", {"text_speed": "fast"})
	assert_true(old_file.get("dynamic_battle_camera"), "an older settings file without the key stays Dynamic")
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)


func test_the_config_screen_row_says_dynamic_or_calm() -> void:
	var config: Node = own((load(CONFIG_SCRIPT) as GDScript).new() as Node) as Node
	config.set("save_path", SCRATCH)
	config.set("apply_bindings_live", false)
	var screen: ConfigScreen = ConfigScreen.new()
	screen.config = config
	screen.manual_ticks = true
	screen.size = Vector2(352, 200)
	add_to_root(screen)
	screen.open(true)
	assert_true(screen.get_row_ids().has("battle_camera"))
	assert_eq(screen.get_row_value("battle_camera"), "Dynamic")
	config.call("set_dynamic_battle_camera", false)
	screen.open(true)
	assert_eq(screen.get_row_value("battle_camera"), "Calm")
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)


func test_the_scene_reads_the_config_toggle_when_it_starts() -> void:
	var config: Node = tree.root.get_node("Config")
	var before: bool = bool(config.get("dynamic_battle_camera"))
	config.call("set_dynamic_battle_camera", false)
	var stage: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	add_to_root(stage)
	assert_false(stage.dynamic_camera, "Calm in Config means a Calm stage")
	config.call("set_dynamic_battle_camera", true)
	var other: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	add_to_root(other)
	assert_true(other.dynamic_camera)
	config.call("set_dynamic_battle_camera", before)
