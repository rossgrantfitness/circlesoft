extends TestCase
## Red's dash charges in the real ActionPlayer (Ross 2026-10-09, "Dash on charges"): up to N dashes in a row, the next one refused
## with a click; spent charges refill one at a time on a timer that dashing never restarts; chained dashes are a short gap apart
## and a press made during a dash or the gap is remembered; every dash goes where the stick points. Bot-driven with press() and
## tick(), on Red's own clock. Every number is read from the feel knobs / profiles, none is pinned.

const SCENE: String = "res://scenes/actors/action_player.tscn"
const DT: float = 1.0 / 60.0

var _player: ActionPlayer = null
var _floor: StaticBody3D = null
var _frame: int = 0
var _dash_frames: Array[int] = []
var _dash_air: Array[bool] = []
var _refused: Array[int] = [0]


func _arena() -> void:
	_floor = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200, 2, 200)
	shape.shape = box
	_floor.add_child(shape)
	_floor.collision_layer = 1
	add_to_root(_floor)
	_floor.global_position = Vector3(0, -1, 0)
	_player = (load(SCENE) as PackedScene).instantiate() as ActionPlayer
	_player.read_engine_input = false
	add_to_root(_player)
	_player.set_physics_process(false)
	_player.global_position = Vector3(0, 0.02, 0)
	var cam: Camera3D = Camera3D.new()
	add_to_root(cam)
	_player.camera = cam
	await tree.physics_frame
	await tree.physics_frame
	_frame = 0
	_dash_frames = []
	_dash_air = []
	_refused = [0]
	_step(10)
	_player.dashed.connect(func(air: bool) -> void:
		_dash_frames.append(_frame)
		_dash_air.append(air))
	_player.dash_refused.connect(func() -> void: _refused[0] += 1)
	# Slowest refill, so a chain of dashes cannot be topped up on the way (the max of the knob's own range).
	_player.knobs.set_value("dash_recharge_s", float(_player.knobs.knob("dash_recharge_s")["max"]))


func _step(frames: int) -> void:
	for i: int in frames:
		_frame += 1
		_player.tick(DT)


func _step_until(condition: Callable, max_frames: int = 600) -> int:
	var frames: int = 0
	while not bool(condition.call()) and frames < max_frames:
		_step(1)
		frames += 1
	return frames


func _max_charges() -> int:
	return int(_player.knobs.get_f("dash_charges"))


func _recharge_frames() -> int:
	return int(ceil(_player.knobs.get_f("dash_recharge_s") / DT))


func _gap_frames() -> int:
	return int(ceil(_player.knobs.get_f("dash_chain_gap_s") / DT))


func _dash_frames_len() -> int:
	return int(ceil(_player.knobs.get_f("dash_time_ms") / 1000.0 / DT))


## Presses dash, runs until a new dash has started, and returns once it is over.
func _chain_one() -> void:
	var before: int = _dash_frames.size()
	_player.press(&"dash")
	_step_until(func() -> bool: return _dash_frames.size() > before)
	_step_until(func() -> bool: return _player.get_dash() == null)


# ---- N in a row, then refused ----

func test_all_the_charges_dash_in_a_row_and_the_next_is_refused() -> void:
	await _arena()
	var n: int = _max_charges()
	assert_gt(n, 1, "the data gives her a chain to run")
	for i: int in n:
		_chain_one()
		assert_eq(_dash_frames.size(), i + 1, "dash %d of %d went" % [i + 1, n])
	assert_eq(_player.get_dash_charge_count(), 0, "all spent")
	_player.press(&"dash")
	_step(40)
	assert_eq(_dash_frames.size(), n, "the dash after the last charge does nothing")
	assert_eq(_refused[0], 1, "and says so once (the dull click)")
	assert_eq(_player.get_state(), ActionPlayer.State.LOCOMOTION)


func test_each_dash_spends_exactly_one_charge() -> void:
	await _arena()
	var n: int = _max_charges()
	assert_eq(_player.get_dash_charge_count(), n, "she starts full")
	_chain_one()
	assert_eq(_player.get_dash_charge_count(), n - 1)
	_chain_one()
	assert_eq(_player.get_dash_charge_count(), n - 2)
	assert_eq(int(_player.get_dash_charges()["max"]), n, "the HUD's snapshot carries the max too")


# ---- refilling ----

func test_charges_come_back_one_at_a_time() -> void:
	await _arena()
	var n: int = _max_charges()
	for i: int in n:
		_chain_one()
	var spent_at: int = _dash_frames[0]
	_step_until(func() -> bool: return _frame - spent_at >= _recharge_frames() + 3)
	assert_eq(_player.get_dash_charge_count(), 1, "one recharge time after the first dash: one charge, not a full set")
	_step(_recharge_frames())
	assert_eq(_player.get_dash_charge_count(), 2, "one recharge time later: the next")


func test_dashing_again_does_not_restart_the_refill() -> void:
	await _arena()
	var n: int = _max_charges()
	_chain_one()
	var first_at: int = _dash_frames[0]
	_step_until(func() -> bool: return _frame - first_at >= _recharge_frames() / 2)
	_chain_one()                       # a second dash in the middle of the first charge's refill
	assert_eq(_player.get_dash_charge_count(), n - 2)
	_step_until(func() -> bool: return _frame - first_at >= _recharge_frames() + 4)
	assert_eq(_player.get_dash_charge_count(), n - 1, "the first charge was back on its original schedule")


func test_a_pip_refills_smoothly_between_charges() -> void:
	await _arena()
	_chain_one()
	_step(30)
	var early: float = float(_player.get_dash_charges()["fraction"])
	_step(60)
	var later: float = float(_player.get_dash_charges()["fraction"])
	assert_gt(early, 0.0)
	assert_gt(later, early, "the charge being refilled shows more progress")


func test_changing_the_recharge_knob_mid_refill_never_sends_the_pip_backwards() -> void:
	await _arena()
	_chain_one()
	var before: float = float(_player.get_dash_charges()["fraction"])
	_player.knobs.set_value("dash_recharge_s", float(_player.knobs.knob("dash_recharge_s")["min"]))
	_step(5)
	assert_gt(float(_player.get_dash_charges()["fraction"]), before - 0.0001, "never goes backwards on a knob change")


# ---- the chain gap and the buffered press ----

func test_a_press_during_a_dash_is_kept_and_fires_when_the_gap_ends() -> void:
	await _arena()
	_player.press(&"dash")
	_step(3)
	assert_not_null(_player.get_dash(), "the first dash is running")
	_player.press(&"dash")             # mid-dash
	_step_until(func() -> bool: return _dash_frames.size() >= 2)
	assert_eq(_dash_frames.size(), 2, "the early press was not lost")
	var between: int = _dash_frames[1] - _dash_frames[0]
	assert_ge(between, _dash_frames_len() + _gap_frames() - 1, "it waited for the dash to finish and then the gap")
	assert_le(between, _dash_frames_len() + _gap_frames() + 3, "and went as soon as the gap ended")


func test_a_press_during_the_gap_is_kept_and_fires_when_it_ends() -> void:
	await _arena()
	_chain_one()
	var ended: int = _frame
	assert_gt(_player.get_dash_cooldown_ms(), 0.0, "the gap is running")
	_step(1)
	_player.press(&"dash")
	_step_until(func() -> bool: return _dash_frames.size() >= 2)
	assert_eq(_dash_frames.size(), 2)
	assert_ge(_dash_frames[1] - ended, _gap_frames() - 1, "not before the gap is over")
	assert_le(_dash_frames[1] - ended, _gap_frames() + 3, "and right when it is")


func test_a_zero_gap_chains_back_to_back() -> void:
	await _arena()
	_player.knobs.set_value("dash_chain_gap_s", 0.0)
	_chain_one()
	assert_almost_eq(_player.get_dash_cooldown_ms(), 0.0, 0.001)
	_player.press(&"dash")
	_step(3)
	assert_eq(_dash_frames.size(), 2, "no gap, no wait")


func test_the_gap_knob_changes_the_wait() -> void:
	await _arena()
	_player.knobs.set_value("dash_chain_gap_s", float(_player.knobs.knob("dash_chain_gap_s")["max"]))
	_chain_one()
	var ended: int = _frame
	_player.press(&"dash")
	_step_until(func() -> bool: return _dash_frames.size() >= 2)
	assert_ge(_dash_frames[1] - ended, _gap_frames() - 1)
	assert_gt(_gap_frames(), 12, "the longest gap is longer than the default one")


# ---- direction ----

func test_every_chained_dash_goes_where_the_stick_points_at_that_moment() -> void:
	await _arena()
	var wanted: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	var seen: Array[Vector3] = []
	for stick: Vector2 in wanted:
		_player.set_move_input(stick)
		var before: int = _dash_frames.size()
		_player.press(&"dash")
		_step_until(func() -> bool: return _dash_frames.size() > before)
		_step(1)
		seen.append(_player.get_dash().direction)
		_step_until(func() -> bool: return _player.get_dash() == null)
	assert_gt(seen[0].dot(Vector3.RIGHT), 0.99, "right")
	assert_gt(seen[1].dot(Vector3.LEFT), 0.99, "then left")
	assert_gt(seen[2].dot(Vector3.BACK), 0.99, "then toward the camera (down on the stick)")
	assert_gt(seen[3].dot(Vector3.FORWARD), 0.99, "then away from it (up on the stick)")


func test_a_buffered_dash_takes_the_stick_held_when_it_fires_not_when_pressed() -> void:
	await _arena()
	_player.set_move_input(Vector2(1, 0))
	_player.press(&"dash")
	_step(3)
	_player.press(&"dash")             # pressed while the stick points right...
	_player.set_move_input(Vector2(-1, 0))        # ...but she steers left before it goes
	_step_until(func() -> bool: return _dash_frames.size() >= 2)
	_step(1)
	assert_gt(_player.get_dash().direction.dot(Vector3.LEFT), 0.99)


func test_with_no_stick_a_dash_goes_the_way_she_faces() -> void:
	await _arena()
	_player.rotation.y = PI * 0.5                 # faces +X
	_player.set_move_input(Vector2.ZERO)
	_player.press(&"dash")
	_step(2)
	assert_gt(_player.get_dash().direction.dot(Vector3.RIGHT), 0.99)


# ---- the air ----

func test_charges_still_apply_in_the_air_and_the_air_dash_count_caps_each_jump() -> void:
	await _arena()
	_player.knobs.set_value("air_dash_count", 2)
	_player.knobs.set_value("jump_height_m", float(_player.knobs.knob("jump_height_m")["max"]))      # plenty of hang time for three tries
	var n: int = _max_charges()
	_player.press(&"jump")
	_step(12)
	assert_true(_player.is_airborne())
	_chain_one()
	assert_true(_dash_air[0], "that was an air dash")
	assert_eq(_player.get_dash_charge_count(), n - 1, "it cost a charge")
	_step(_gap_frames() + 2)
	_chain_one()
	assert_eq(_player.get_air_dashes_left(), 0)
	assert_eq(_player.get_dash_charge_count(), n - 2)
	_step(_gap_frames() + 2)
	assert_true(_player.is_airborne(), "still in the same jump")
	_player.press(&"dash")
	_step(3)
	assert_eq(_dash_air.count(true), 2, "the third air dash of the jump is capped by air_dash_count, with charges to spare")
	assert_eq(_refused[0], 0, "it was not a charge problem")


func test_landing_gives_the_air_dash_back_but_not_the_charges() -> void:
	await _arena()
	var n: int = _max_charges()
	_player.press(&"jump")
	_step(12)
	_chain_one()
	_step_until(func() -> bool: return _player.is_on_floor(), 400)
	_step(10)
	assert_eq(_player.get_air_dashes_left(), int(_player.knobs.get_f("air_dash_count")))
	assert_eq(_player.get_dash_charge_count(), n - 1, "the charge is still spent")


# ---- resets and forms ----

func test_a_reset_gives_every_charge_back() -> void:
	await _arena()
	_chain_one()
	_chain_one()
	_player.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)))
	assert_eq(_player.get_dash_charge_count(), _max_charges())
	assert_almost_eq(_player.get_dash_cooldown_ms(), 0.0, 0.001)


func test_the_max_knob_is_live() -> void:
	await _arena()
	var before: int = _player.get_dash_charge_count()
	_player.knobs.set_value("dash_charges", before - 2)
	_step(2)
	assert_eq(_player.get_dash_charge_count(), before - 2, "lowering the knob trims her charges")
	_player.knobs.set_value("dash_charges", before)
	_step(2)
	assert_eq(_player.get_dash_charge_count(), before, "raising it hands the new slots over full")


func test_a_robot_body_brings_its_own_charges() -> void:
	await _arena()
	for form_id: StringName in [ScaleProfile.FORM_SMALL, ScaleProfile.FORM_HUGE]:
		var profile: ScaleProfile = ScaleProfile.get_form(form_id)
		_player.set_scale_profile(profile)
		assert_eq(int(_player.get_dash_charges()["max"]), int(profile.knob("dash_charges", 0.0)), "%s holds its own number" % form_id)
		assert_eq(_player.get_dash_charge_count(), int(profile.knob("dash_charges", 0.0)), "and starts full")
	_player.set_scale_profile(ScaleProfile.get_form(ScaleProfile.FORM_RED))
	assert_eq(_player.get_dash_charge_count(), _max_charges(), "back in Red's body the F12 knob is the number again")


func test_enemies_have_no_dash_charges() -> void:
	await _arena()
	var enemy: ActionEnemy = ActionEnemy.new()
	assert_false(enemy.has_method(&"get_dash_charges"), "the charge system is Red's; enemy moves stay on their own data")
	enemy.free()
