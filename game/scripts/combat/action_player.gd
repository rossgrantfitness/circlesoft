class_name ActionPlayer
extends CombatActor
## Red in the combat sandbox (docs/pivot/combat_api.md 4.2): the state machine over PlayerMotion.
##
## States: LOCOMOTION, AIR, DASH, AIR_DASH, ATTACK, PARRY, HURT, KNOCKDOWN, GETUP.
##   * Camera-relative run (no tank controls: the stick is "toward the top of the screen" and she
##     turns to where she is going), jump with coyote time, a buffered jump press and a release-cut.
##   * A ground dash and one air-dash per jump, with i-frames, through enemies (their body layer is
##     switched off in her mask while she dashes).
##   * Attacks and the parry run on a MoveRunner (data/combat/moves.json) on HER OWN CombatClock, so
##     hit-stop freezes her and a flare never shifts a window. Presses go through an InputBuffer, so a
##     press a little early still counts, and the chain, dash, jump and parry cancels follow the data.
##   * Hit reactions (apply_hit), knockdown, get-up. Red can't lose: at 0 HP she drops, and after 2 s
##     she gets up at full health.
##
## Movement numbers are the feel knobs (run_speed_mps, jump_height_m, gravity_scale, dash_distance_m,
## dash_time_ms, dash_iframes_ms, air_dash_count), read every frame so the panel works live; the rest
## is data/combat/player_action.json. Her model is picked from that file's "models" list.
##
## Bots and tests: set read_engine_input = false, then press() / release() / set_move_input() and call
## tick(delta) by hand. The game polls the actions in tick() and takes real press timestamps from the
## sandbox's input relay through handle_input_event().

enum State { LOCOMOTION, AIR, DASH, AIR_DASH, ATTACK, PARRY, HURT, KNOCKDOWN, GETUP }

signal jumped(air: bool)
signal landed
signal dashed(air: bool)
signal move_started(move_id: StringName)
signal swing_started(move_id: StringName, swing: Dictionary)
signal state_changed(state: State)

const DATA_ID: String = "combat/player_action"
const SET_ID: StringName = &"red"
const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_UP: StringName = &"move_up"
const ACTION_DOWN: StringName = &"move_down"
const BUTTONS: Array[StringName] = [&"jump", &"light", &"heavy", &"dash", &"parry"]
const TOKEN_JUMP: StringName = &"jump"
const TOKEN_DASH: StringName = &"dash"
const TOKEN_PARRY: StringName = &"parry"
const TOKEN_LIGHT: StringName = &"light"
const TOKEN_HEAVY: StringName = &"heavy"
const TOKEN_LAUNCH: StringName = &"launch"
const ATTACK_TOKENS: Array[StringName] = [&"light", &"heavy", &"launch"]
const MOVE_PARRY: StringName = &"parry"
const MOVE_HEAVY: StringName = &"heavy"
const NODE_VISUAL: NodePath = ^"Visual"
const NODE_PLACEHOLDER: NodePath = ^"Visual/PlaceholderCapsule"
const USEC: float = 1000000.0
const STICK_TO_FLOOR: float = -0.5

## Poll Input in tick() (the game). Bots and tests turn it off and use press() / release() / set_move_input().
@export var read_engine_input: bool = true

## FeelKnobs (the director's when there is one, else the defaults). Read every frame, never cached.
var knobs: FeelKnobs = null:
	set(value):
		knobs = value
		if _buffer != null:
			_buffer = InputBuffer.create(knobs)
## What movement is relative to: the OrbitCamera's Camera3D. Null = the viewport's current camera.
var camera: Camera3D = null
var lock_on: LockOn = null
var orbit_camera: OrbitCamera = null

var _data: Dictionary = {}
var _hit_feel: Dictionary = {}
var _moves: MoveSet = null
var _runner: MoveRunner = null
var _buffer: InputBuffer = null
var _state: State = State.LOCOMOTION
var _stick: Vector2 = Vector2.ZERO
var _held: Dictionary[StringName, bool] = {}
var _presses: Array[Dictionary] = []
var _press_local: Dictionary[StringName, int] = {}
var _heavy_down_local: int = -1
## Real timestamps of parry presses still waiting in the buffer, oldest first. The judge gets THESE, not the
## moment the parry move happens to begin (a press can wait up to input_buffer_ms for a cancel window).
var _parry_stamps: Array[int] = []
var _event_fed: bool = false
var _vy: float = 0.0
var _coyote_left: float = 0.0
var _dash: DashRun = null
var _dash_cooldown_left_s: float = 0.0
var _air_dashes_left: int = 1
var _was_airborne: bool = false
var _invuln_left_s: float = 0.0
var _hurt_left_s: float = 0.0
var _down_left_s: float = 0.0
var _getup_left_s: float = 0.0
var _downed_for_good: bool = false
var _launched: bool = false
var _knock_velocity: Vector3 = Vector3.ZERO
var _combat_delta: float = 0.0
var _last_scale: float = 1.0
var _attack_dir: Vector3 = Vector3.FORWARD
var _attack_lunge_cap: float = INF
var _prev_move_ms: float = 0.0
var _hit_landed_in_move: bool = false
var _hanging: bool = false
var _move_clip_scale: float = 1.0
var _visual: Node3D = null
var _model: Node3D = null
var _animation_player: AnimationPlayer = null
var _strides: Dictionary = {}
var _strides_loaded: bool = false
var _current_clip: StringName = &""
var _model_path: String = ""
var _warned_clips: Dictionary[StringName, bool] = {}
var _missing_clips: Array[StringName] = []
var _bob_time: float = 0.0
var _gear: Node = null


func _init() -> void:
	actor_id = &"red"
	team = &"player"
	move_set_id = SET_ID


func _ready() -> void:
	var db: Node = get_node_or_null("/root/DataDB")
	_data = (db.call("get_dict", DATA_ID) as Dictionary) if db != null else {}
	_hit_feel = CombatData.hit_feel()
	hp_max = int(_data.get("hp_max", hp_max))
	hp = hp_max
	var body: Dictionary = _data.get("body", {}) as Dictionary
	radius_m = float(body.get("radius_m", 0.3))
	height_m = float(body.get("height_m", 0.9))
	super._ready()          # groups, collision layers, Hurtbox and Hitbox, registration with the director
	_restore_enemy_collision()
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	if knobs == null:
		var found: CombatDirector = find_director()
		knobs = found.feel if found != null and found.feel != null else FeelKnobs.load_defaults()
	_moves = MoveSet.load_default()
	_runner = MoveRunner.create(_moves, SET_ID)
	_buffer = InputBuffer.create(knobs)
	if find_director() == null:
		clock.anchor_real(Time.get_ticks_usec())
	_air_dashes_left = int(_knob("air_dash_count"))
	_visual = get_node_or_null(NODE_VISUAL) as Node3D
	_size_body()
	_load_model()
	_play_clip(&"idle")


func _physics_process(delta: float) -> void:
	tick(delta)


# ---- the bot / input API ----

## A button went down. `usec` is its real timestamp; omitted = now on her real-time axis.
func press(action: StringName, usec: int = -1) -> void:
	_held[action] = true
	_presses.append({"action": action, "usec": usec if usec >= 0 else clock.real_now_usec()})


func release(action: StringName) -> void:
	_held[action] = false
	if action == TOKEN_HEAVY:
		_heavy_down_local = -1


## The stick (x right, y down, as Input.get_vector gives it).
func set_move_input(stick: Vector2) -> void:
	_stick = stick.limit_length(1.0)


func is_held(action: StringName) -> bool:
	return bool(_held.get(action, false))


## The sandbox's relay hands over events from `_input`, with real timestamps.
func handle_input_event(event: InputEvent) -> void:
	if event.is_echo():
		return
	for action: StringName in BUTTONS:
		if event.is_action_pressed(action):
			_event_fed = true
			press(action, Time.get_ticks_usec())
		elif event.is_action_released(action):
			release(action)


# ---- the contract surface (CombatActor) ----

func get_state() -> State:
	return _state


func is_airborne() -> bool:
	return not is_on_floor()


## True during the dash i-frames and the get-up grace.
func is_invulnerable() -> bool:
	return (_dash != null and _dash.invulnerable()) or _invuln_left_s > 0.0


## Lights On gives super armor.
func is_armored() -> bool:
	var director: CombatDirector = find_director()
	if director == null or director.lights_on == null or not director.lights_on.is_active():
		return false
	return bool(director.lights_on.buffs().get("super_armor", false))


func current_swing_id() -> int:
	return _runner.swing_id() if _runner != null and _runner.is_busy() else 0


## The unit direction her model faces (flat).
func get_facing() -> Vector3:
	return global_basis.z


func get_air_dashes_left() -> int:
	return _air_dashes_left


func get_dash_cooldown_ms() -> float:
	return _dash_cooldown_left_s * 1000.0


## The dash that is running (null when not dashing).
func get_dash() -> DashRun:
	return _dash


func get_runner() -> MoveRunner:
	return _runner


func get_buffer() -> InputBuffer:
	return _buffer


func get_move_direction() -> Vector3:
	return PlayerMotion.camera_relative_direction(_stick, _camera_basis())


## Clips of the contract that her model lacks (the fallbacks cover them); filled while she plays.
func get_missing_clips() -> Array[StringName]:
	return _missing_clips.duplicate()


## A point on her in world space: &"head", &"center", &"feet", &"lamp".
func anchor(point: StringName) -> Vector3:
	var skeleton: Skeleton3D = _find_skeleton()
	match point:
		&"feet":
			return global_position
		&"head":
			var head: Vector3 = _bone_position(skeleton, "head")
			return head if head != Vector3.INF else global_position + Vector3.UP * _body_height()
		&"lamp":
			for bone: String in ["lamp_socket", "chest"]:
				var spot: Vector3 = _bone_position(skeleton, bone)
				if spot != Vector3.INF:
					return spot
			var lamp: Dictionary = _data.get("lamp", {}) as Dictionary
			var offset: Array = lamp.get("offset", [0.0, 0.1, 0.15]) as Array
			return global_position + Vector3.UP * _body_height() * 0.6 \
					+ global_basis * Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
		_:
			return super.anchor(point)


## Swap the sword in her hand (GearVisuals, when the Technical Artist's file is there).
func equip_sword(sword_id: StringName) -> bool:
	var gear: Node = _gear_visuals()
	return gear != null and bool(gear.call("equip_sword", sword_id))


func current_sword() -> StringName:
	var gear: Node = _gear_visuals()
	return StringName(gear.call("current_sword")) if gear != null else &""


## The victim side: the base class has taken the damage; this is how she reacts. Guards and armor
## take damage but don't stagger her; a hit or stagger interrupts whatever she is doing.
func _on_hit_reaction(result: Dictionary) -> void:
	var outcome: String = str(result.get("outcome", "hit"))
	if outcome == "perfect_parry" or outcome == "parried":
		_invuln_left_s = maxf(_invuln_left_s, 0.25)
		if _has_clip(&"parry_success"):
			_play_clip(&"parry_success")
		return
	if outcome == "ignored" or outcome == "evaded" or outcome == "guarded" or outcome == "armored" or hp <= 0:
		return
	_interrupt_move()
	_end_dash_state()
	var launch: float = float(result.get("launch_mps", 0.0))
	var knock: Vector3 = result.get("knockback", Vector3.ZERO) as Vector3
	_knock_velocity = Vector3(knock.x, 0.0, knock.z)
	var stun: float = float(result.get("hitstun_ms", _hurt_cfg("default_hitstun_ms", 320.0))) / 1000.0
	if launch > 0.0 or bool(result.get("knockdown", false)):
		_vy = maxf(launch, 0.0)
		_launched = true
		_down_left_s = _hurt_cfg("knockdown_ms", 700.0) / 1000.0
		_set_state(State.KNOCKDOWN)
		_play_clip(&"knockdown")
	else:
		_hurt_left_s = stun
		_set_state(State.HURT)
		_play_clip(&"hurt")


## She can't lose: at 0 HP she drops, Noise resets, and after a couple of seconds she gets up at full health.
func _on_death(_result: Dictionary) -> void:
	_go_down(true)
	var director: CombatDirector = find_director()
	if director != null and director.style != null:
		director.style.reset()


## The attacker side: one of her swings connected.
func _on_hit_landed(_result: Dictionary) -> void:
	_hit_landed_in_move = true


## Back to full health, standing at `where`, nothing queued (a reset, a respawn).
func reset_to(where: Transform3D) -> void:
	global_transform = where
	velocity = Vector3.ZERO
	_vy = 0.0
	_interrupt_move()
	_dash = null
	_dash_cooldown_left_s = 0.0
	_presses.clear()
	_parry_stamps.clear()
	if _buffer != null:
		_buffer.clear()
	_invuln_left_s = 0.0
	_hurt_left_s = 0.0
	_down_left_s = 0.0
	_getup_left_s = 0.0
	_downed_for_good = false
	_launched = false
	_knock_velocity = Vector3.ZERO
	_air_dashes_left = int(_knob("air_dash_count"))
	revive(true)
	_restore_enemy_collision()
	_set_state(State.LOCOMOTION)
	_current_clip = &""


# ---- the per-frame step ----

## One physics step. `delta` is real time; her own combat time is worked out inside.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	var director: CombatDirector = find_director()
	var scale: float = director.time.step_scale_for(actor_id, delta) if director != null else 1.0
	_last_scale = scale
	if read_engine_input:
		_read_engine_input()
	if director == null:
		# A bare run (no director): she steps her own clock. With one, it steps it before us (priority -100).
		clock.step(int(delta * USEC), scale)
	_combat_delta = delta * scale
	# Presses always reach the buffer, even in hit-stop (the buffer runs on Red's clock).
	_ingest_presses()
	if _animation_player != null:
		_animation_player.speed_scale = scale * _anim_speed_factor()
	if _combat_delta <= 0.0:
		velocity = Vector3.ZERO
		return
	var dt: float = _combat_delta
	var now: int = clock.now_usec()
	_invuln_left_s = maxf(_invuln_left_s - dt, 0.0)
	_dash_cooldown_left_s = maxf(_dash_cooldown_left_s - dt, 0.0)
	match _state:
		State.DASH, State.AIR_DASH:
			_tick_dash(dt, scale, now)
		State.ATTACK, State.PARRY:
			_tick_move(dt, scale, now)
		State.HURT:
			_tick_hurt(dt, scale, now)
		State.KNOCKDOWN:
			_tick_knockdown(dt, scale, now)
		State.GETUP:
			_tick_getup(dt, scale, now)
		_:
			_tick_free(dt, scale, now)
	_hitbox.tick(dt)
	_update_animation(dt)


func _read_engine_input() -> void:
	_stick = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)
	for action: StringName in BUTTONS:
		_held[action] = Input.is_action_pressed(action)
		if not _event_fed and Input.is_action_just_pressed(action):
			press(action, Time.get_ticks_usec())


## Turns queued presses into buffered tokens on her own clock.
func _ingest_presses() -> void:
	for entry: Dictionary in _presses:
		var action: StringName = StringName(entry["action"])
		var local: int = clock.local_at_real(int(entry["usec"]))
		var token: StringName = _token_for(action, local)
		if token == &"":
			continue
		if token == TOKEN_PARRY:
			_parry_stamps.append(int(entry["usec"]))
		_buffer.push(token, local)
		_press_local[token] = local
		if action == TOKEN_HEAVY:
			_heavy_down_local = local
	_presses.clear()
	# Stamps whose token has expired from the buffer go with it.
	var keep_usec: int = int(_buffer.window_ms() * 1000.0) + 20000
	while not _parry_stamps.is_empty() and clock.real_now_usec() - _parry_stamps[0] > keep_usec:
		_parry_stamps.pop_front()


func _token_for(action: StringName, _local_usec: int) -> StringName:
	match action:
		TOKEN_JUMP, TOKEN_DASH, TOKEN_PARRY, TOKEN_LIGHT:
			return action
		TOKEN_HEAVY:
			var now: int = clock.now_usec()
			var ctx: Dictionary = {
				"stick_back": _stick_is_back(),
				"current_move": _runner.current_move(),
				"chain_open": _runner.chain_window_open(now),
				"string_end_move": StringName(str(_hit_feel.get("string_end_move", "light_2"))),
			}
			return LauncherInput.token_for_heavy_press(_knob_s("launcher_input", LauncherInput.MODE_HOLD), ctx)
	return &""


func _stick_is_back() -> bool:
	if _stick.length() < 0.3:
		return false
	return get_move_direction().dot(get_facing()) < -0.5


# ---- locomotion and air ----

func _tick_free(dt: float, scale: float, now: int) -> void:
	var direction: Vector3 = PlayerMotion.camera_relative_direction(_stick, _camera_basis())
	var on_floor: bool = is_on_floor() and _vy <= 0.0
	if on_floor:
		_coyote_left = _jump_cfg("coyote_s", 0.1)
		_air_dashes_left = int(_knob("air_dash_count"))
	else:
		_coyote_left -= dt
	_set_state(State.LOCOMOTION if on_floor else State.AIR)

	# Buffered presses first. Whatever starts a new state ends this step (a dash or move moves her itself).
	var accept: Callable = func(token: StringName) -> bool: return _free_accepts(token, on_floor, now)
	var token: StringName = _buffer.take(now, accept)
	var jumping_now: bool = false
	var jump_height: float = _knob("jump_height_m")
	while token != &"":
		match token:
			TOKEN_DASH:
				_start_dash(direction, not on_floor, now)
				_tick_dash(dt, scale, now)
				return
			TOKEN_PARRY:
				if _begin_move(MOVE_PARRY, now, direction):
					_tick_move(dt, scale, now)
					return
			TOKEN_JUMP:
				jumping_now = true
			_:
				var entry: StringName = _moves.entry(SET_ID, &"ground" if on_floor else &"air", token)
				if entry != &"" and _begin_move(entry, now, direction):
					_tick_move(dt, scale, now)
					return
		token = _buffer.take(now, accept)

	var gravity: float = ActionMotion.gravity_for(jump_height, _jump_cfg("rise_time_s", 0.36), _knob("gravity_scale"))
	var launch: float = ActionMotion.launch_speed(jump_height, gravity)
	if jumping_now:
		_coyote_left = 0.0
		on_floor = false
	var wanted: Vector2 = Vector2(direction.x, direction.z) * _knob("run_speed_mps") * _stick.length()
	var flat: Vector2 = ActionMotion.flat_velocity(Vector2(velocity.x, velocity.z), wanted, on_floor,
			_data.get("move", {}) as Dictionary, dt)
	velocity.x = flat.x
	velocity.z = flat.y

	var vy_before: float = launch if jumping_now else _vy
	if on_floor:
		velocity.y = STICK_TO_FLOOR            # stay pressed to the floor so snapping and slopes work
		_vy = 0.0
	else:
		var step: Dictionary = ActionMotion.vertical_step(vy_before, gravity, _jump_cfg("fall_gravity_mult", 1.35),
				_jump_cfg("max_fall_mps", 28.0), dt, is_held(TOKEN_JUMP), launch * _jump_cfg("release_cut_mult", 0.45))
		_vy = float(step["vy"])
		velocity.y = float(step["avg"])

	_turn_toward_motion(direction, dt)
	_slide(scale)
	if is_on_ceiling() and _vy > 0.0:
		_vy = 0.0
	if jumping_now:
		jumped.emit(false)
	_note_landing()


## Is this buffered token something she can do right now (as a free-moving Red)?
func _free_accepts(token: StringName, on_floor: bool, _now: int) -> bool:
	match token:
		TOKEN_JUMP:
			return _coyote_left > 0.0
		TOKEN_DASH:
			return _dash_cooldown_left_s <= 0.0 and (on_floor or _air_dashes_left > 0)
		TOKEN_PARRY:
			return on_floor and _moves.has_move(SET_ID, MOVE_PARRY)
		_:
			return _moves.entry(SET_ID, &"ground" if on_floor else &"air", token) != &""


func _note_landing() -> void:
	var airborne: bool = not is_on_floor()
	if _was_airborne and not airborne:
		landed.emit()
	_was_airborne = airborne


## Faces where she is going; while locked on (and lock_strafe is on) she faces the target instead.
func _turn_toward_motion(direction: Vector3, dt: float) -> void:
	var move: Dictionary = _data.get("move", {}) as Dictionary
	var rate: float = float(move.get("turn_rate_deg_per_s", 1200.0))
	var face: Vector3 = Vector3.ZERO
	var target: Node3D = lock_on.get_target() if lock_on != null else null
	if target != null and bool(move.get("lock_strafe", true)):
		face = target.global_position - global_position
		face.y = 0.0
	elif direction.length() > 0.001:
		face = direction
	if face.length() > 0.001:
		rotation.y = PlayerMotion.turn_toward(rotation.y, PlayerMotion.yaw_for_direction(face), rate, dt)


# ---- dash ----

func _start_dash(stick_direction: Vector3, in_air: bool, _now: int) -> void:
	var cfg: Dictionary = _data.get("dash", {}) as Dictionary
	var direction: Vector3 = ActionMotion.dash_direction(stick_direction, get_facing(), str(cfg.get("no_stick", "facing")))
	var distance: float = _knob("dash_distance_m") * (float(cfg.get("air_distance_mult", 0.85)) if in_air else 1.0)
	_dash = DashRun.create(direction, distance, _knob("dash_time_ms"), _knob("dash_iframes_ms"), float(cfg.get("decay", 0.45)), in_air)
	if in_air:
		_air_dashes_left -= 1
		_vy = 0.0
	rotation.y = PlayerMotion.yaw_for_direction(direction)
	collision_mask = CombatLayers.body_mask(team, true)
	_set_state(State.AIR_DASH if in_air else State.DASH)
	_play_clip(&"air_dash" if in_air and _has_clip(&"air_dash") else &"dash")
	var director: CombatDirector = find_director()
	if director != null:
		director.report_dash(clock.real_now_usec())
	dashed.emit(in_air)


func _tick_dash(dt: float, scale: float, now: int) -> void:
	var run: DashRun = _dash
	if run == null:
		_set_state(State.AIR if not is_on_floor() else State.LOCOMOTION)
		return
	# Cancels: a dash can be cut into an attack or a jump once the data allows.
	var cfg: Dictionary = _data.get("dash", {}) as Dictionary
	var elapsed: float = run.elapsed_ms()
	var can_jump: bool = elapsed >= float(cfg.get("jump_cancel_ms", 70.0))
	var can_attack: bool = elapsed >= float(cfg.get("attack_cancel_ms", 110.0))
	if can_jump or can_attack:
		var on_floor: bool = is_on_floor()
		var accept: Callable = func(token: StringName) -> bool:
			if token == TOKEN_JUMP:
				return can_jump and on_floor
			return can_attack and token in ATTACK_TOKENS \
					and _moves.entry(SET_ID, &"ground" if on_floor else &"air", token) != &""
		var token: StringName = _buffer.take(now, accept)
		if token != &"":
			var dash_dir: Vector3 = run.direction
			_end_dash_state(true)
			if token == TOKEN_JUMP:
				var height: float = _knob("jump_height_m")
				var g: float = ActionMotion.gravity_for(height, _jump_cfg("rise_time_s", 0.36), _knob("gravity_scale"))
				_vy = ActionMotion.launch_speed(height, g)
				velocity = Vector3(dash_dir.x, 0.0, dash_dir.z) * _knob("run_speed_mps")
				_set_state(State.AIR)
				_current_clip = &""
				jumped.emit(false)
				return
			var entry: StringName = _moves.entry(SET_ID, &"ground" if on_floor else &"air", token)
			if entry != &"" and _begin_move(entry, now, dash_dir):
				_tick_move(dt, scale, now)
				return
			_set_state(State.LOCOMOTION if on_floor else State.AIR)
			return
	var v: Vector3 = run.advance(dt)
	velocity = Vector3(v.x, 0.0 if run.air else STICK_TO_FLOOR, v.z)
	_slide(scale)
	if run.is_done():
		_finish_dash(run)


func _finish_dash(run: DashRun) -> void:
	var cfg: Dictionary = _data.get("dash", {}) as Dictionary
	_end_dash_state(true)
	var keep: Vector3 = run.direction * _knob("run_speed_mps") * float(cfg.get("end_speed_mult", 0.6))
	velocity = Vector3(keep.x, 0.0, keep.z)
	_vy = 0.0
	_set_state(State.AIR if not is_on_floor() else State.LOCOMOTION)
	_current_clip = &""


## Drops the dash (enemy collision back on). `start_cooldown` false when something else interrupted it.
func _end_dash_state(start_cooldown: bool = false) -> void:
	if _dash == null:
		return
	var cfg: Dictionary = _data.get("dash", {}) as Dictionary
	_dash = null
	_restore_enemy_collision()
	if start_cooldown:
		_dash_cooldown_left_s = float(cfg.get("cooldown_ms", 220.0)) / 1000.0


func _restore_enemy_collision() -> void:
	collision_mask = CombatLayers.body_mask(team, false)


# ---- attacks and the parry ----

## Starts a move: faces it (the lock target, else the soft target, else the stick, else her facing),
## starts the runner and the clip. False if the move does not exist.
func _begin_move(move_id: StringName, now: int, stick_direction: Vector3) -> bool:
	if not _runner.start(move_id, now):
		return false
	_on_move_began(move_id, stick_direction, now)
	return true


func _on_move_began(move_id: StringName, stick_direction: Vector3, now: int) -> void:
	var move: Dictionary = _runner.data()
	_prev_move_ms = 0.0
	_hit_landed_in_move = false
	_hanging = false
	_attack_lunge_cap = INF
	# Which way does the swing go? Lock-on target or the nearest enemy in the magnet cone wins.
	var facing: Vector3 = get_facing()
	var magnet: Dictionary = move.get("magnet", {}) as Dictionary
	var dir: Vector3 = stick_direction if stick_direction.length() > 0.001 else Vector3.ZERO
	var target: Node3D = null
	if lock_on != null and not magnet.is_empty():
		target = lock_on.magnet_target(dir, facing, float(magnet.get("range_m", 3.5)), float(magnet.get("cone_deg", 70.0)))
	if target != null:
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() > 0.001:
			dir = to_target.normalized()
			_attack_lunge_cap = maxf(to_target.length() - float((_data.get("attack", {}) as Dictionary).get("stop_short_m", 0.8)), 0.0)
	if dir.length() < 0.001:
		dir = Vector3(facing.x, 0.0, facing.z).normalized()
	_attack_dir = dir.normalized()
	rotation.y = PlayerMotion.yaw_for_direction(_attack_dir)
	# Air moves pop her up a little, then hold the fall (hang).
	if bool(move.get("state", "ground") == "air") or not is_on_floor():
		var up: float = _runner.up_mps()
		if up > 0.0:
			_vy = maxf(_vy, up)
	_set_state(State.PARRY if move_id == MOVE_PARRY else State.ATTACK)
	if move_id == MOVE_PARRY:
		var director: CombatDirector = find_director()
		if director != null:
			# The ORIGINAL press time, carried through the buffer; only a parry that began without a recorded press
			# (a bot calling the runner directly) falls back to now.
			var stamp: int = _parry_stamps.pop_front() if not _parry_stamps.is_empty() else clock.real_now_usec()
			director.report_parry_press(stamp)
	var anim: Dictionary = move.get("anim", {}) as Dictionary
	_start_move_clip(anim, float(move.get("total_ms", 500.0)))
	move_started.emit(move_id)


func _tick_move(dt: float, scale: float, now: int) -> void:
	if not _runner.is_busy():
		_finish_move()
		return
	var on_floor: bool = is_on_floor()
	var direction: Vector3 = PlayerMotion.camera_relative_direction(_stick, _camera_basis())
	_handle_move_inputs(now, direction, on_floor)
	if _state != State.ATTACK and _state != State.PARRY:
		return       # a cancel started a dash or a jump; it takes over next step
	var cur_ms: float = _runner.elapsed_ms_at(now)
	var fwd: float = minf(_runner.forward_between(_prev_move_ms, cur_ms), _attack_lunge_cap)
	if fwd > 0.0:
		_attack_lunge_cap = maxf(_attack_lunge_cap - fwd, 0.0)
	_prev_move_ms = cur_ms
	var events: Array[Dictionary] = _runner.step(now)
	for event: Dictionary in events:
		_handle_runner_event(event)
	# Motion: the lunge along the swing direction; air moves hang or fall.
	var gravity: float = ActionMotion.gravity_for(_knob("jump_height_m"), _jump_cfg("rise_time_s", 0.36), _knob("gravity_scale"))
	var flat: Vector3 = _attack_dir * (fwd / dt)
	velocity.x = flat.x
	velocity.z = flat.z
	var airborne: bool = not on_floor or _vy > 0.0
	if airborne:
		_hanging = _runner.is_busy() and _runner.is_hanging()
		if _hanging:
			_vy = 0.0
			velocity.y = 0.0
		else:
			var step: Dictionary = ActionMotion.vertical_step(_vy, gravity, _jump_cfg("fall_gravity_mult", 1.35),
					_jump_cfg("max_fall_mps", 28.0), dt, true, 1.0e9)
			_vy = float(step["vy"])
			velocity.y = float(step["avg"])
	else:
		_vy = 0.0
		velocity.y = STICK_TO_FLOOR
	_slide(scale)
	if is_on_ceiling() and _vy > 0.0:
		_vy = 0.0
	_note_landing()
	# An air move that touches the floor ends early into the landing.
	if _runner.is_busy() and str(_runner.data().get("state", "ground")) == "air" and is_on_floor() and _vy <= 0.0 \
			and _runner.elapsed_ms() > 40.0:
		_interrupt_move()
		_set_state(State.LOCOMOTION)
		_current_clip = &""
		return
	if not _runner.is_busy() and (_state == State.ATTACK or _state == State.PARRY):
		_finish_move()


## Chains, cancels and the heavy-to-launcher upgrade, from the buffered presses.
func _handle_move_inputs(now: int, direction: Vector3, on_floor: bool) -> void:
	# The hold_heavy launcher: heavy still held late in its startup becomes the launcher.
	var mode: String = _knob_s("launcher_input", LauncherInput.MODE_HOLD)
	if _heavy_down_local >= 0 and is_held(TOKEN_HEAVY):
		var held_ms: float = float(now - _heavy_down_local) / 1000.0
		if LauncherInput.should_upgrade_heavy(mode, _runner.current_move(), MOVE_HEAVY, _runner.phase() == MoveRunner.PHASE_STARTUP,
				held_ms, float(_hit_feel.get("launcher_hold_ms", 170.0))) and _moves.has_move(SET_ID, &"launcher"):
			_heavy_down_local = -1
			_begin_move(&"launcher", now, direction)
			return
	var accept: Callable = func(token: StringName) -> bool: return _move_accepts(token, now, on_floor)
	var token: StringName = _buffer.take(now, accept)
	while token != &"":
		match token:
			TOKEN_DASH:
				var events: Array[Dictionary] = _runner.interrupt()
				for event: Dictionary in events:
					_handle_runner_event(event)
				_start_dash(direction, not on_floor, now)
				return
			TOKEN_PARRY:
				_begin_move(MOVE_PARRY, now, direction)
				return
			TOKEN_JUMP:
				var follow: bool = _follow_jump_ready()
				var jump_events: Array[Dictionary] = _runner.interrupt()
				for event: Dictionary in jump_events:
					_handle_runner_event(event)
				_start_jump_from_move(follow)
				return
			_:
				var chained: StringName = _runner.offer(token, now, int(_press_local.get(token, now)))
				if chained != &"":
					_on_move_began(chained, direction, now)
		token = _buffer.take(now, accept)


func _move_accepts(token: StringName, now: int, on_floor: bool) -> bool:
	match token:
		TOKEN_DASH:
			return _runner.can_cancel(&"dash", now) and _dash_cooldown_left_s <= 0.0 and (on_floor or _air_dashes_left > 0)
		TOKEN_PARRY:
			return _runner.can_cancel(&"parry", now) and on_floor
		TOKEN_JUMP:
			return _runner.can_cancel(&"jump", now) and (on_floor or _follow_jump_ready())
		_:
			return _runner.can_chain(token, now)


## The launcher's follow-up: a jump pressed after a hit lands makes her follow the target up.
func _follow_jump_ready() -> bool:
	return _hit_landed_in_move and bool(_runner.data().get("launcher", false))


## A jump out of a move. `follow` (a launcher that hit): she goes up with the target, higher than a normal jump.
func _start_jump_from_move(follow: bool) -> void:
	var height: float = _knob("jump_height_m")
	if follow:
		height = float((_hit_feel.get("follow_jump", {}) as Dictionary).get("height_m", height))
	var gravity: float = ActionMotion.gravity_for(height, _jump_cfg("rise_time_s", 0.36), _knob("gravity_scale"))
	_vy = ActionMotion.launch_speed(height, gravity)
	_set_state(State.AIR)
	_current_clip = &""
	jumped.emit(follow)


func _handle_runner_event(event: Dictionary) -> void:
	match str(event["type"]):
		"hitbox_on":
			var box: Dictionary = (event["box"] as Dictionary).duplicate()
			box["index"] = int(event["index"])
			_hitbox.activate(box, _runner.attack_data(), _runner.swing_id())
		"hitbox_off":
			_hitbox.deactivate(int(event["index"]))
		"swing":
			var swing: Dictionary = event.get("swing", {}) as Dictionary
			swing_started.emit(_runner.current_move(), swing)
			var director: CombatDirector = find_director()
			if director != null:
				director.notify_move_started(self, _runner.current_move(), swing)
		"pose":
			_seek_pose(StringName(event["clip"]), float(event["clip_s"]))
		"interrupted", "done":
			_hitbox.clear()


func _finish_move() -> void:
	_set_state(State.LOCOMOTION if is_on_floor() else State.AIR)
	_current_clip = &""


## Cuts the move short (hitboxes off).
func _interrupt_move() -> void:
	if _runner == null or not _runner.is_busy():
		return
	for event: Dictionary in _runner.interrupt():
		_handle_runner_event(event)
	_hitbox.clear()


# ---- being hit ----

func _tick_hurt(dt: float, scale: float, _now: int) -> void:
	_hurt_left_s -= dt
	var fade: float = clampf(_hurt_left_s / 0.25, 0.0, 1.0)
	velocity = Vector3(_knock_velocity.x * fade, STICK_TO_FLOOR if is_on_floor() else _fall_step(dt), _knock_velocity.z * fade)
	_slide(scale)
	if _hurt_left_s <= 0.0:
		_knock_velocity = Vector3.ZERO
		_set_state(State.LOCOMOTION if is_on_floor() else State.AIR)
		_current_clip = &""


func _tick_knockdown(dt: float, scale: float, _now: int) -> void:
	if _launched or not is_on_floor():
		_knock_velocity = _knock_velocity.move_toward(Vector3.ZERO, 6.0 * dt)
		velocity = Vector3(_knock_velocity.x, _fall_step(dt, _hurt_cfg("launch_gravity_mult", 0.8)), _knock_velocity.z)
		_slide(scale)
		if is_on_floor() and _vy <= 0.0:
			_launched = false
			_knock_velocity = Vector3.ZERO
			velocity = Vector3.ZERO
			_note_landing()
		return
	velocity = Vector3(0.0, STICK_TO_FLOOR, 0.0)
	_slide(scale)
	_down_left_s -= dt
	if _down_left_s <= 0.0:
		if _downed_for_good:
			_downed_for_good = false
			revive(true)
		_getup_left_s = _hurt_cfg("getup_ms", 450.0) / 1000.0
		_invuln_left_s = (_hurt_cfg("getup_ms", 450.0) + _hurt_cfg("invuln_after_getup_ms", 500.0)) / 1000.0
		_set_state(State.GETUP)
		_play_clip(&"getup" if _has_clip(&"getup") else &"idle")


func _tick_getup(dt: float, scale: float, _now: int) -> void:
	velocity = Vector3(0.0, STICK_TO_FLOOR, 0.0)
	_slide(scale)
	_getup_left_s -= dt
	if _getup_left_s <= 0.0:
		_set_state(State.LOCOMOTION)
		_current_clip = &""


## One step of falling for states that don't use the jump maths.
func _fall_step(dt: float, gravity_mult: float = 1.0) -> float:
	var gravity: float = ActionMotion.gravity_for(_knob("jump_height_m"), _jump_cfg("rise_time_s", 0.36), _knob("gravity_scale")) * gravity_mult
	var step: Dictionary = ActionMotion.vertical_step(_vy, gravity, _jump_cfg("fall_gravity_mult", 1.35),
			_jump_cfg("max_fall_mps", 28.0), dt, true, 1.0e9)
	_vy = float(step["vy"])
	return float(step["avg"])


func _go_down(for_good: bool) -> void:
	_interrupt_move()
	_end_dash_state()
	_downed_for_good = for_good
	_launched = false
	_knock_velocity = Vector3.ZERO
	_down_left_s = _hurt_cfg("downed_respawn_s", 2.0) if for_good else _hurt_cfg("knockdown_ms", 700.0) / 1000.0
	_set_state(State.KNOCKDOWN)
	_play_clip(&"knockdown")


# ---- shared helpers ----

## Velocity is scaled around the slide so hit-stop and slow-mo slow her whole motion, then scaled back.
func _slide(scale: float) -> void:
	if scale <= 0.001:
		return
	velocity *= scale
	move_and_slide()
	velocity /= scale


func _set_state(new_state: State) -> void:
	if new_state == _state:
		return
	_state = new_state
	state_changed.emit(new_state)


func _camera_basis() -> Basis:
	var cam: Camera3D = camera
	if cam == null and is_inside_tree():
		cam = get_viewport().get_camera_3d()
	return cam.global_basis if cam != null else Basis.IDENTITY


## A feel-knob value: the panel's when the knob exists, else player_action.json "knob_defaults".
func _knob(id: String) -> float:
	if knobs != null and knobs.has(id):
		return knobs.get_f(id)
	return float((_data.get("knob_defaults", {}) as Dictionary).get(id, 0.0))


func _knob_s(id: String, fallback: String) -> String:
	if knobs != null and knobs.has(id):
		return knobs.get_s(id)
	return fallback


func _jump_cfg(key: String, fallback: float) -> float:
	return float((_data.get("jump", {}) as Dictionary).get(key, fallback))


func _hurt_cfg(key: String, fallback: float) -> float:
	return float((_data.get("hurt", {}) as Dictionary).get(key, fallback))


func _body_height() -> float:
	return float((_data.get("body", {}) as Dictionary).get("height_m", 0.9))


func _size_body() -> void:
	var body: Dictionary = _data.get("body", {}) as Dictionary
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = shape_node.shape as CapsuleShape3D
		capsule.radius = float(body.get("radius_m", 0.3))
		capsule.height = float(body.get("height_m", 0.9))
		shape_node.position.y = capsule.height * 0.5


# ---- model and animation ----

func _load_model() -> void:
	if _visual == null:
		return
	for raw: Variant in _data.get("models", []) as Array:
		var entry: Dictionary = raw as Dictionary
		var path: String = str(entry.get("path", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			continue
		var model: Node3D = scene.instantiate() as Node3D
		if model == null:
			continue
		var placeholder: Node = get_node_or_null(NODE_PLACEHOLDER)
		if placeholder != null:
			placeholder.queue_free()
			_visual.remove_child(placeholder)
		model.name = "Model"
		var model_scale: float = float(_data.get("model_scale", 1.0))
		model.scale = Vector3.ONE * model_scale
		if str(entry.get("origin", "feet")) == "middle":
			model.position.y = float(entry.get("height_m", 0.95)) * 0.5 * model_scale
		_visual.add_child(model)
		# The PS2 look: models on the old PSX shader get the PS2 one (a no-op in the old game's profiles),
		# then the edge light from the profile's character block.
		Ps2Look.upgrade_model(model, path, LookProfiles.active())
		LookProfiles.dress_model(model, path, "player")
		_model = model
		_model_path = path
		_animation_player = _find_animation_player(model)
		_gear = _make_gear(model)
		return


func _make_gear(model: Node3D) -> Node:
	var path: String = "res://scripts/combat/gear_visuals.gd"
	if not ResourceLoader.exists(path):
		return null
	var script: GDScript = load(path) as GDScript
	if script == null or not script.can_instantiate():
		return null
	var gear: Node = script.new() as Node
	if gear == null:
		return null
	gear.name = "GearVisuals"
	add_child(gear)
	gear.set("model_root", gear.get_path_to(model))
	if gear.has_method("default_sword"):
		var first: StringName = gear.call("default_sword")
		if first != &"":
			gear.call("equip_sword", first)
	return gear


func _gear_visuals() -> Node:
	return _gear if _gear != null and is_instance_valid(_gear) else null


func get_model_path() -> String:
	return _model_path


func get_model() -> Node3D:
	return _model


func get_animation_player() -> AnimationPlayer:
	return _animation_player


func current_clip() -> StringName:
	return _current_clip


func _has_clip(clip: StringName) -> bool:
	return _animation_player != null and _animation_player.has_animation(clip)


func _note_missing(clip: StringName) -> void:
	if not _warned_clips.has(clip):
		_warned_clips[clip] = true
		_missing_clips.append(clip)
		push_warning("ActionPlayer: the model has no '%s' clip (a procedural fallback covers it)" % clip)


func _play_clip(clip: StringName) -> void:
	if clip == _current_clip or clip == &"":
		return
	_current_clip = clip
	if _animation_player == null:
		return
	if _animation_player.has_animation(clip):
		_animation_player.play(clip, float((_data.get("anim", {}) as Dictionary).get("blend_s", 0.08)))
	else:
		_note_missing(clip)


## Starts a move's clip: with pose keys the pose events snap it; without keys it is stretched to the
## move's length. Missing clips are noted and left to the procedural fallback.
func _start_move_clip(anim: Dictionary, total_ms: float) -> void:
	var clip: StringName = StringName(str(anim.get("clip", "")))
	_current_clip = clip
	_move_clip_scale = 1.0
	if clip == &"" or _animation_player == null:
		return
	if not _animation_player.has_animation(clip):
		_note_missing(clip)
		return
	_animation_player.play(clip, 0.0)
	var keys: Array = anim.get("keys", []) as Array
	if keys.is_empty():
		var length: float = _animation_player.get_animation(clip).length
		_move_clip_scale = length / maxf(total_ms / 1000.0, 0.05)


func _anim_speed_factor() -> float:
	if _state == State.ATTACK or _state == State.PARRY:
		return _move_clip_scale
	if _current_clip == &"run" or _current_clip == &"walk":
		# Foot-slide fix: play the loop at ground speed / the clip's stride (clip_keys.json stride_mps), inside the data's limits.
		var anim: Dictionary = _data.get("anim", {}) as Dictionary
		var limits: Vector2 = Vector2(float(anim.get("playback_scale_min", LocomotionSpeed.DEFAULT_MIN)),
				float(anim.get("playback_scale_max", LocomotionSpeed.DEFAULT_MAX)))
		return LocomotionSpeed.playback_scale(Vector2(velocity.x, velocity.z).length(), _stride_of(_current_clip), limits)
	return 1.0


## A locomotion clip's natural ground speed from the model's clip-key file (player_action.json anim.clip_keys); 0.0 if unknown.
func _stride_of(clip: StringName) -> float:
	if not _strides_loaded:
		_strides_loaded = true
		var path: String = str((_data.get("anim", {}) as Dictionary).get("clip_keys", ""))
		if path != "":
			_strides = LocomotionSpeed.load_strides(path)
	return LocomotionSpeed.stride_for(_strides, clip)


## Walk at a slow stick, run otherwise (a little hysteresis so the clip does not flicker at the border).
func _locomotion_clip(ground_speed: float) -> StringName:
	var anim: Dictionary = _data.get("anim", {}) as Dictionary
	var border: float = float(anim.get("walk_below_mps", 0.0))
	if border <= 0.0 or not _has_clip(&"walk"):
		return &"run"
	var walking: bool = _current_clip == &"walk"
	return &"walk" if ground_speed < (border + 0.2 if walking else border) else &"run"


func _seek_pose(clip: StringName, clip_s: float) -> void:
	if _animation_player == null or not _animation_player.has_animation(clip):
		return
	if _animation_player.current_animation != String(clip):
		_animation_player.play(clip, 0.0)
	_animation_player.seek(clip_s, true)


## Chooses the locomotion clip. Missing clips fall back to a plain lean and bob on the Visual node
## until the Technical Artist's procedural moves take over.
func _update_animation(dt: float) -> void:
	var airborne: bool = not is_on_floor()
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.5
	match _state:
		State.LOCOMOTION, State.AIR:
			if airborne:
				_play_clip(&"jump_up" if _vy > 0.0 else &"fall")
			elif moving:
				_play_clip(_locomotion_clip(Vector2(velocity.x, velocity.z).length()))
			else:
				_play_clip(&"idle")
		_:
			pass
	if _visual != null and _model != null and (_animation_player == null or not _animation_player.has_animation(&"run")):
		_bob_time += dt
		var lean: float = deg_to_rad(12.0) if moving else 0.0
		_visual.rotation.x = lerpf(_visual.rotation.x, lean, clampf(dt * 12.0, 0.0, 1.0))
		_visual.position.y = absf(sin(_bob_time * 14.0)) * 0.04 if moving and not airborne else 0.0


func _find_animation_player(root: Node) -> AnimationPlayer:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is AnimationPlayer:
			return node as AnimationPlayer
		stack.append_array(node.get_children())
	return null


func _find_skeleton() -> Skeleton3D:
	if _model == null:
		return null
	var stack: Array[Node] = [_model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Skeleton3D:
			return node as Skeleton3D
		stack.append_array(node.get_children())
	return null


## A bone's world position, or Vector3.INF when there is no such bone.
func _bone_position(skeleton: Skeleton3D, bone: String) -> Vector3:
	if skeleton == null:
		return Vector3.INF
	var index: int = skeleton.find_bone(bone)
	if index < 0:
		return Vector3.INF
	return skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
