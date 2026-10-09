class_name ActionEnemy
extends CombatActor
## A sandbox enemy (the Grunt or the Brute), driven by data/combat/enemies.json and moves.json.
## The EnemyBrain decides, the MoveRunner plays the attack on this fighter's own clock (so hit-stop and the
## Lamp Flare slow it correctly), the Hitbox does the damage, and the body reacts to hits with a small
## state machine: free, dodge, block, hurt, stagger, recoil, launched, down, getting up, dead. Reactions are
## procedural (a lean, a tumble, a flash) so a blockout works today and Ross's rigged model drops in later by
## path; clips are looked up by the names in `behaviour.clips` and a missing one is simply skipped.
##
## enemy_ai_design: the brain also dodges (i-frames, then a punish window), blocks (front arc, guard meter,
## guard break), repositions, flees, flanks and enrages; this body carries those out, keeps the guard meter,
## enforces the wind-up floors (500 ms, 650 ms from behind) and asks the AttackTokens before every wind-up.
##
## Everything per-frame is in tick(delta); _physics_process only calls it, so tests can step it by hand.

const ENEMIES_FILE: String = "enemies.json"
const DEFAULT_RESPAWN_S: float = 6.0
const FACE_TURN_EPS: float = 0.02
const KNOCK_DECAY: float = 12.0
const AIR_DRAG: float = 1.5
const FAST_TURN_DEG_PER_S: float = 1500.0
const CORNERED_SPEED_RATIO: float = 0.3
const ST_FREE: StringName = &"free"
const ST_HURT: StringName = &"hurt"
const ST_STAGGER: StringName = &"stagger"
const ST_RECOIL: StringName = &"recoil"
const ST_LAUNCHED: StringName = &"launched"
const ST_DOWN: StringName = &"down"
const ST_GETUP: StringName = &"getup"
const ST_DODGE: StringName = &"dodge"
const ST_BLOCK: StringName = &"block"
const ST_DEAD: StringName = &"dead"
const PHASE_RAISE: StringName = &"raise"
const PHASE_HOLD: StringName = &"hold"
const PHASE_LOWER: StringName = &"lower"
const MOVE_DODGE: StringName = &"dodge"
const MOVE_GETUP_ROLL: StringName = &"getup_roll"
const MOVE_BLOCK_START: StringName = &"block_start"
const MOVE_BLOCK_HOLD: StringName = &"block_hold"
const MOVE_BLOCK_BREAK: StringName = &"block_break"
const TELEGRAPH_HZ: float = 8.0
const PATROL_LEG_M: float = 4.0
const PATROL_SPEED_MULT: float = 0.4
const DODGE_TELL_COLOR: Color = Color(0.3, 0.95, 1.0)

static var _spawn_counts: Dictionary = {}

@export var enemy_id: StringName = &"grunt"
@export var rng_seed: int = 0

var data: Dictionary = {}
var brain: EnemyBrain = null
var runner: MoveRunner = null
var guard: GuardMeter = null
var spawn_position: Vector3 = Vector3.ZERO
var spawn_yaw: float = 0.0
var body_state: StringName = ST_FREE
var model_root: Node3D = null
## Pose of the last intent, for tests and the debug overlay.
var last_intent: Dictionary = {}
var test_target: CombatActor = null        ## tests may aim an enemy at a stand-in; normally the player
## What the hacks read about it (enemies.json `tags`: drone, turret, robot, relay, boss): bonus damage, EMP stun time.
var tags: PackedStringArray = PackedStringArray()
## Set while Overclock has taken it over (Red's side, fights the nearest enemy); null otherwise. See on_hijack_begin().
var hijacked_by: CombatActor = null
var hijackable: Hijackable = null
## False = it never attacks Red (the Hushmaster arena's powered-down turrets). A hijacked unit fights anyway.
var attacks_allowed: bool = true
## What the encounter runner gave it (data/slice/encounters.json): `tune` numbers laid over its data, and a `state`
## (idle, idle_at_barrel, patrol, ambush). See apply_tune() and apply_state().
var tune: Dictionary = {}
var behaviour_state: StringName = &""

var _moves: MoveSet = null
var _hit_feel: Dictionary = {}
var _beh: Dictionary = {}
var _rules: Dictionary = {}
var _state_ms: float = 0.0
var _stun_ms: float = 0.0
var _knock: Vector3 = Vector3.ZERO
var _knockdown_on_land: bool = false
var _slam: bool = false
var _move_start_usec: int = 0
var _prev_move_ms: float = 0.0
var _vt_ms: float = 0.0                    # the move's own time: the wind-up can be stretched by the feel knob
var _windup_scale: float = 1.0
var _chain_cut_ms: float = -1.0
var _dead_real_s: float = 0.0
var _respawn_s: float = DEFAULT_RESPAWN_S
## Does this enemy come back `respawn_s` after it dies? True for the sandbox arena (as always). The slice's ActionRoom turns it
## off for every enemy it spawns, so an encounter's dead stay dead and a fight can clear (bug B7).
var respawns: bool = true
var _anim: AnimationPlayer = null
var _overlay: StandardMaterial3D = null
var _overlay_meshes: Array[MeshInstance3D] = []
var _flash: float = 0.0
var _telegraph_left_ms: float = 0.0
var _telegraph_total_ms: float = 0.0
var _telegraph_color: Color = Color(1.0, 0.3, 0.2)
var _enrage_color: Color = Color(1.0, 0.23, 0.1)
var _current_clip: StringName = &""
var _pitch: float = 0.0
var _drop: float = 0.0
var _visual_kind: String = ""
var _rng_fx: RandomNumberGenerator = RandomNumberGenerator.new()
var _hp_scale_applied: float = 1.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _dodge_prev_ms: float = 0.0
var _block_phase: StringName = PHASE_RAISE
var _block_phase_ms: float = 0.0
var _block_raise_ms: float = 100.0
var _block_lower_ms: float = 160.0
var _guard_from_ms: float = 60.0
var _guard_break_ms: float = 1100.0
var _flinch_clip: StringName = &"hurt"
var _stagger_clip: StringName = &"stagger"
var _face_red_ms: float = 0.0
var _cornered: bool = false
var _commanded_speed: float = 0.0
var _clip_speed: float = 1.0
var _brain_overrides: Dictionary = {}
var _pending_tune: Dictionary = {}
var _pending_state: StringName = &""
var _patrol_to: Vector3 = Vector3.ZERO
var _patrol_flip: bool = false
var _hijack_color: Color = Color(0.2, 0.95, 1.0)
var _hijack_end_stun_ms: float = 800.0
var _hijack_damage_scale: float = 1.0


func _ready() -> void:
	_load_data()
	super._ready()
	spawn_position = global_position
	spawn_yaw = rotation.y
	_build_body_shape()
	_build_visual()
	runner = MoveRunner.create(_moves, move_set_id)
	_make_hijackable()
	brain = _make_brain()
	if not _pending_tune.is_empty():
		apply_tune(_pending_tune)
		_pending_tune = {}
	if _pending_state != &"":
		apply_state(_pending_state)
		_pending_state = &""
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	tick(delta)


## What the visual ended up being: "model", "fallback" or "blockout" (for tests and the debug overlay).
func visual_kind() -> String:
	return _visual_kind


func current_swing_id() -> int:
	return runner.swing_id() if runner != null else 0


## Untouchable: dead, the first moments of getting up, and the i-frames of a dodge or a get-up roll.
func is_invulnerable() -> bool:
	match body_state:
		ST_DEAD:
			return true
		ST_GETUP:
			return _state_ms < float((_beh.get("reactions", {}) as Dictionary).get("getup_invuln_ms", 250.0))
		ST_DODGE:
			if runner != null and runner.is_busy():
				var frames: Dictionary = runner.data().get("iframes", {})
				var ms: float = runner.elapsed_ms()
				return not frames.is_empty() and ms >= float(frames.get("from_ms", 0.0)) and ms < float(frames.get("to_ms", 0.0))
	return false


func is_armored() -> bool:
	if body_state != ST_FREE and body_state != ST_HURT:
		return false
	return bool(data.get("base_armor", false)) or (runner != null and runner.armor_active())


func is_attacking() -> bool:
	return runner != null and runner.is_busy() and body_state == ST_FREE


## Is the guard up right now (and covering the front)?
func is_guarding() -> bool:
	return body_state == ST_BLOCK and _block_phase != PHASE_LOWER and _state_ms >= _guard_from_ms


func is_dodging() -> bool:
	return body_state == ST_DODGE


func is_enraged() -> bool:
	return brain != null and brain.is_enraged()


## The resolver also reads the raised guard and "running away" (a hit then always knocks it down).
func snapshot() -> Dictionary:
	var snap: Dictionary = super.snapshot()
	snap["guard"] = _guard_snapshot()
	snap["flee_knockdown"] = brain != null and brain.is_fleeing()
	return snap


func _guard_snapshot() -> Dictionary:
	if not is_guarding() or guard == null:
		return {}
	var cfg: Dictionary = _beh.get("guard", {})
	return {"up": true, "arc_deg": float(cfg.get("arc_deg", 150.0)), "meter": guard.meter,
			"break_poise": float(cfg.get("break_poise", 999.0)), "break_by_launcher": bool(cfg.get("break_by_launcher", true)),
			"chip_scale": float(cfg.get("chip_damage_scale", 0.25)), "min_chip": int(cfg.get("min_chip_damage", 1)),
			"knockback_scale": float(cfg.get("knockback_scale", 0.35)), "hit_stop_scale": float(cfg.get("hit_stop_scale", 0.5)),
			"break_ms": _guard_break_ms, "spark": str(cfg.get("spark", "guard")), "sfx": str(cfg.get("sfx", "combat_hit_light"))}


# ---- per-frame ----

func tick(delta: float) -> void:
	if runner == null:
		return
	var director: CombatDirector = find_director()
	if director == null:
		clock.step(int(roundf(delta * 1000000.0)), 1.0)
	var dt: float = local_delta(delta)
	if body_state == ST_DEAD:
		_tick_dead(delta)
		return
	if dt <= 0.0:
		return
	_apply_hp_scale(director)
	_state_ms += dt * 1000.0
	_stun_ms = maxf(_stun_ms - dt * 1000.0, 0.0)
	get_hitbox().tick(dt)
	if brain.poise_regen_allowed():
		tick_poise(dt)
	var now_ms: float = clock.now_ms()
	guard.step(dt, now_ms)
	match body_state:
		ST_FREE:
			_tick_free(dt, now_ms, director)
		ST_DODGE:
			_tick_dodge(dt, now_ms, director)
		ST_BLOCK:
			_tick_block(dt, now_ms, director)
		ST_HURT, ST_STAGGER, ST_RECOIL:
			_tick_stun(dt)
		ST_LAUNCHED:
			_tick_launched(dt)
		ST_DOWN, ST_GETUP:
			_tick_down(dt)
	_update_visual(dt)
	slide_scaled(dt / delta if delta > 0.0 else 1.0)
	_note_cornered(dt)


func _target() -> CombatActor:
	if test_target != null:
		return test_target
	var director: CombatDirector = find_director()
	if hijacked_by != null:
		return _nearest_enemy(director)       # taken over by Overclock: it fights Red's enemies now
	return director.player() if director != null else null


## The living enemy nearest to this one (what a hijacked unit goes for), or null. If the director lists
## `hijack_priority_tags` (the boss arena: the Hushmaster's relays) and any living enemy has one, the nearest of those wins.
func _nearest_enemy(director: CombatDirector) -> CombatActor:
	if director == null:
		return null
	var best: CombatActor = null
	var best_dist: float = INF
	var best_priority: CombatActor = null
	var best_priority_dist: float = INF
	for other: CombatActor in director.living_enemies():
		if other == self:
			continue
		var gap: float = other.global_position.distance_squared_to(global_position)
		if gap < best_dist:
			best_dist = gap
			best = other
		if gap < best_priority_dist and not director.hijack_priority_tags.is_empty() and _has_any_tag(other, director.hijack_priority_tags):
			best_priority_dist = gap
			best_priority = other
	return best_priority if best_priority != null else best


static func _has_any_tag(other: CombatActor, wanted: Array) -> bool:
	for tag: Variant in HackCaster.tags_of(other):
		if wanted.has(str(tag)):
			return true
	return false


## The geometry of the moment: the unit vector toward Red on the floor, and how far she is.
func _toward(target: CombatActor) -> Dictionary:
	var to_target: Vector3 = Vector3.ZERO
	var dist: float = 999.0
	if target != null:
		to_target = target.global_position - global_position
		to_target.y = 0.0
		dist = to_target.length()
	return {"dist": dist, "dir": to_target.normalized() if dist > 0.001 else forward()}


func _tick_free(dt: float, now_ms: float, director: CombatDirector) -> void:
	var target: CombatActor = _target()
	var geo: Dictionary = _toward(target)
	var dist: float = geo["dist"]
	var dir_to: Vector3 = geo["dir"]
	_apply_gravity(dt)
	var tokens: AttackTokens = director.tokens if director != null else null
	var has_token: bool = tokens != null and tokens.has_token(actor_id)
	var enabled: bool = director.feel.get_b("enemies_attack") if director != null else true
	if hijacked_by != null:
		tokens = null            # a hijacked unit queues for nothing: it is on Red's side and attacks when it likes
		has_token = true
		enabled = true
	elif not attacks_allowed:
		enabled = false
	enabled = enabled and target != null and not target.dead
	var view: Dictionary = _make_view(target, dist, has_token, enabled, EnemyBrain.FREE, director)
	if runner.is_busy():
		_tick_attack(dt, dir_to, target, view)
		return
	var intent: Dictionary = brain.step(now_ms, view)
	last_intent = intent
	if bool(intent["want_token"]) and not has_token and tokens != null:
		if tokens.request(actor_id, {"flank": bool(intent.get("flank", false))}):
			brain.notify(&"token_granted")
	elif not bool(intent["want_token"]) and has_token and tokens != null and brain.state() != EnemyBrain.ATTACK:
		tokens.release(actor_id)       # defending, fleeing and idle enemies hold no token
	var defend: Dictionary = intent.get("defend", {})
	if not defend.is_empty():
		_begin_defence(defend, dir_to, tokens)
		return
	if target != null and bool(intent["face_player"]):
		_turn_toward(dir_to, dt)
	var wanted: Vector3 = _wanted_velocity(intent, dir_to)
	if behaviour_state == &"patrol" and hijacked_by == null and brain.state() == EnemyBrain.IDLE:
		wanted = _patrol_velocity()            # nobody has noticed Red yet: it walks its beat
		intent["face_move"] = true
	_commanded_speed = wanted.length()
	if bool(intent.get("face_move", false)) and wanted.length() > 0.3:
		_turn_toward(wanted.normalized(), dt)
	velocity.x = move_toward(velocity.x, wanted.x, 30.0 * dt)
	velocity.z = move_toward(velocity.z, wanted.z, 30.0 * dt)
	if StringName(intent["start_move"]) != &"":
		_start_attack(StringName(intent["start_move"]), intent, view, tokens)


## The brain's move_dir (player frame) as a world velocity. `speed_mps` (flee, retreat) wins over the walk speed.
func _wanted_velocity(intent: Dictionary, dir_to: Vector3) -> Vector3:
	var world: Vector3 = _world_move(intent["move_dir"], dir_to)
	var speed_mps: float = float(intent.get("speed_mps", 0.0))
	if speed_mps > 0.0:
		return world.normalized() * speed_mps if world.length() > 0.001 else Vector3.ZERO
	return world * float(data.get("move_speed_mps", 2.8)) * float(intent.get("speed_mult", 1.0))


func _tick_attack(dt: float, dir_to: Vector3, target: CombatActor, view: Dictionary) -> void:
	last_intent = brain.step(clock.now_ms(), view)
	if target != null and bool(last_intent.get("face_player", false)):
		_turn_toward(dir_to, dt)
	var events: Array[Dictionary] = runner.step(_advance_move_clock(dt))
	_handle_events(events)
	if runner.is_busy() and _chain_cut_ms >= 0.0 and runner.elapsed_ms() >= _chain_cut_ms:
		_handle_events(runner.interrupt())
		_finish_attack()
	if runner.is_busy():
		var ms: float = runner.elapsed_ms()
		var lunge_m: float = runner.forward_between(_prev_move_ms, ms)
		_prev_move_ms = ms
		var along: Vector3 = forward() * (lunge_m / maxf(dt, 0.0001))
		velocity.x = along.x
		velocity.z = along.z
	else:
		velocity.x = 0.0
		velocity.z = 0.0


## The move's own clock: the wind-up (everything before the impact) runs at 1 / windup_scale, then normal speed.
func _advance_move_clock(dt: float) -> int:
	var remaining: float = dt * 1000.0
	var impact: float = float(runner.data().get("impact_ms", 0.0)) if runner.is_busy() else 0.0
	var rate: float = 1.0 / maxf(_windup_scale, 0.01)
	while remaining > 0.0:
		if _vt_ms < impact and not is_equal_approx(rate, 1.0):
			var to_impact: float = (impact - _vt_ms) / rate
			var used: float = minf(remaining, to_impact)
			_vt_ms += used * rate
			remaining -= used
		else:
			_vt_ms += remaining
			remaining = 0.0
	return _move_start_usec + int(_vt_ms * 1000.0)


func _handle_events(events: Array[Dictionary]) -> void:
	var director: CombatDirector = find_director()
	for event: Dictionary in events:
		match String(event["type"]):
			"telegraph":
				var impact_eff: float = float(runner.data().get("impact_ms", 0.0)) * _windup_scale
				_telegraph_total_ms = maxf(impact_eff - float(event["t_ms"]) * _windup_scale, 0.0)
				_telegraph_left_ms = _telegraph_total_ms
				if director != null:
					director.telegraph(self, runner.current_move(), _move_start_usec + int(impact_eff * 1000.0),
							StringName(str(runner.data().get("telegraph_kind", ""))))
			"swing":
				if director != null:
					director.notify_move_started(self, runner.current_move(), event.get("swing", {}))
			"hitbox_on":
				var attack: Dictionary = runner.attack_data()
				attack["damage"] = int(roundf(float(attack.get("damage", 0)) * brain.damage_mult() * _hijack_damage_scale))
				if hijacked_by != null:
					attack["source"] = "hijacked"
				else:
					attack["damage"] = int(roundf(float(attack["damage"]) * _vs_form_damage_mult()))
				get_hitbox().activate(event["box"], attack, runner.swing_id())
			"hitbox_off":
				get_hitbox().deactivate(int(event["index"]))
			"interrupted":
				get_hitbox().clear()
			"pose":
				_play_pose(StringName(event["clip"]), float(event["clip_s"]))
			"done":
				get_hitbox().clear()
				_telegraph_left_ms = 0.0
				if body_state == ST_DODGE:
					_finish_dodge(StringName(event.get("move_id", &"")))
				else:
					_finish_attack()


## An attack (or the roar) ended: tell the brain, give the token back (unless the Brute chains a second slam).
func _finish_attack() -> void:
	var director: CombatDirector = find_director()
	_telegraph_left_ms = 0.0
	_chain_cut_ms = -1.0
	_windup_scale = 1.0
	brain.notify(&"move_finished")
	if director != null and director.tokens != null:
		if brain.keeps_token():
			director.tokens.end_attack(actor_id)
		else:
			director.tokens.release(actor_id)


## Start a move the brain asked for. An attack first asks the tokens (no two hits closer than 450 ms, one attacker
## at a time from Red's rear arc); the wind-up never gets shorter than the floors, whatever the knob says.
func _start_attack(move_id: StringName, intent: Dictionary, view: Dictionary, tokens: AttackTokens) -> void:
	var move: Dictionary = _moves.get_move(move_set_id, move_id)
	if move.is_empty():
		push_warning("ActionEnemy %s: unknown move %s" % [actor_id, move_id])
		brain.notify(&"move_finished")
		return
	var is_attack: bool = not (move.get("hit", {}) as Dictionary).is_empty()
	var scale: float = 1.0
	if is_attack:
		var director: CombatDirector = find_director()
		var knob: float = director.feel.get_f("enemy_windup_scale") if director != null and director.feel.has("enemy_windup_scale") else 1.0
		var rear: bool = bool(view.get("in_rear_arc", false))
		scale = EnemyRules.windup_scale(knob, EnemyRules.windup_ms(move), EnemyRules.min_windup_ms(_rules, rear))
		if tokens != null and not tokens.begin_attack(actor_id, float(move.get("impact_ms", 0.0)) * scale, rear):
			brain.notify(&"attack_denied")
			return
		brain.set_attack_timing(float(move.get("impact_ms", 0.0)) * scale, scale)
	if not runner.start(move_id, clock.now_usec()):
		brain.notify(&"move_finished")
		return
	_windup_scale = scale
	_vt_ms = 0.0
	_move_start_usec = clock.now_usec()
	_prev_move_ms = 0.0
	var chain_ms: float = float(intent.get("chain_recover_ms", 0.0))
	_chain_cut_ms = float(move.get("startup_ms", 0.0)) + float(move.get("active_ms", 0.0)) + chain_ms if chain_ms > 0.0 else -1.0
	_start_move_clip(move, float(move.get("impact_ms", 0.0)) * scale)
	_handle_events(runner.step(_move_start_usec))


# ---- dodge and block ----

func _begin_defence(defend: Dictionary, dir_to: Vector3, tokens: AttackTokens) -> void:
	if tokens != null:
		tokens.release(actor_id)
	if StringName(defend.get("kind", &"")) == EnemyDefence.KIND_BLOCK:
		_begin_block()
		return
	var back: bool = StringName(defend.get("variant", &"side")) == &"back"
	var direction: Vector3 = -dir_to if back else dir_to.cross(Vector3.UP) * float(defend.get("sign", 1.0))
	_begin_dodge(MOVE_DODGE, direction, &"dodge_back" if back else &"dodge_side")


func _begin_dodge(move_id: StringName, direction: Vector3, clip_key: StringName) -> void:
	if not runner.start(move_id, clock.now_usec()):
		brain.notify(&"defence_finished")
		return
	_vt_ms = 0.0
	_windup_scale = 1.0
	_move_start_usec = clock.now_usec()
	_dodge_prev_ms = 0.0
	_dodge_dir = Vector3(direction.x, 0.0, direction.z).normalized()
	_set_state(ST_DODGE)
	_play_once(_clip_for(clip_key))
	_handle_events(runner.step(_move_start_usec))


func _tick_dodge(dt: float, _now_ms: float, _director: CombatDirector) -> void:
	_apply_gravity(dt)
	var target: CombatActor = _target()
	var geo: Dictionary = _toward(target)
	if not runner.is_busy():
		_set_state(ST_FREE)
		brain.notify(&"defence_finished")
		return
	if target != null and runner.current_move() == MOVE_DODGE:
		_turn_toward(geo["dir"], dt)
	var events: Array[Dictionary] = runner.step(clock.now_usec())
	var ms: float = runner.elapsed_ms()
	var travel: float = _travel_between(_dodge_prev_ms, ms, runner.data().get("motion", {}))
	_dodge_prev_ms = ms
	velocity.x = _dodge_dir.x * travel / maxf(dt, 0.0001)
	velocity.z = _dodge_dir.z * travel / maxf(dt, 0.0001)
	_handle_events(events)
	if body_state == ST_DODGE:
		last_intent = brain.step(clock.now_ms(), _make_view(target, geo["dist"], false, false, EnemyBrain.BUSY, find_director()))


## Metres moved between two times of a dodge: `travel_m` spread over `from_ms`..`to_ms`.
func _travel_between(prev_ms: float, cur_ms: float, motion: Dictionary) -> float:
	var travel_m: float = float(motion.get("travel_m", 0.0))
	if travel_m == 0.0:
		return 0.0
	var from_ms: float = float(motion.get("from_ms", 0.0))
	var to_ms: float = float(motion.get("to_ms", from_ms))
	if to_ms <= from_ms:
		return travel_m if (prev_ms < from_ms and cur_ms >= from_ms) else 0.0
	var a: float = clampf((prev_ms - from_ms) / (to_ms - from_ms), 0.0, 1.0)
	var b: float = clampf((cur_ms - from_ms) / (to_ms - from_ms), 0.0, 1.0)
	return travel_m * (b - a)


func _finish_dodge(move_id: StringName) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_set_state(ST_FREE)
	if move_id == MOVE_GETUP_ROLL:
		brain.notify(&"landed")
	else:
		brain.notify(&"defence_finished")


func _begin_block() -> void:
	var start: Dictionary = _moves.get_move(move_set_id, MOVE_BLOCK_START)
	var hold: Dictionary = _moves.get_move(move_set_id, MOVE_BLOCK_HOLD)
	_block_raise_ms = float(start.get("total_ms", 100.0))
	_guard_from_ms = float((start.get("guard", {}) as Dictionary).get("from_ms", 60.0))
	_block_lower_ms = float(hold.get("recovery_ms", 160.0))
	_block_phase = PHASE_RAISE
	_block_phase_ms = 0.0
	_set_state(ST_BLOCK)
	_play_once(_clip_for(&"block_start"))


func _tick_block(dt: float, now_ms: float, director: CombatDirector) -> void:
	_apply_gravity(dt)
	var target: CombatActor = _target()
	var geo: Dictionary = _toward(target)
	if target != null:
		_turn_toward(geo["dir"], dt)
	var view: Dictionary = _make_view(target, geo["dist"], false, false, EnemyBrain.BUSY, director)
	var intent: Dictionary = brain.step(now_ms, view)
	last_intent = intent
	_block_phase_ms += dt * 1000.0
	match _block_phase:
		PHASE_RAISE:
			if not bool(intent.get("guard", false)):
				_start_lowering()
			elif _state_ms >= _block_raise_ms:
				_block_phase = PHASE_HOLD
				_block_phase_ms = 0.0
				_play_loop(_clip_for(&"block_hold"), 1.0)
		PHASE_HOLD:
			if not bool(intent.get("guard", false)) or brain.state() != EnemyBrain.DEFEND:
				_start_lowering()
		PHASE_LOWER:
			if _block_phase_ms >= _block_lower_ms:
				_set_state(ST_FREE)
				brain.notify(&"defence_finished")
	_knock *= exp(-KNOCK_DECAY * dt)
	velocity.x = _knock.x
	velocity.z = _knock.z


func _start_lowering() -> void:
	_block_phase = PHASE_LOWER
	_block_phase_ms = 0.0


# ---- stun, launch, get-up ----

func _tick_stun(dt: float) -> void:
	_apply_gravity(dt)
	var decay: float = exp(-KNOCK_DECAY * dt)
	_knock *= decay
	velocity.x = _knock.x
	velocity.z = _knock.z
	if _face_red_ms > 0.0:
		# a light flinch turns to face Red within turn_to_red_ms
		_face_red_ms = maxf(_face_red_ms - dt * 1000.0, 0.0)
		var target: CombatActor = _target()
		if target != null:
			_turn_toward_fast(_toward(target)["dir"], dt)
	if _stun_ms <= 0.0:
		_set_state(ST_FREE)
		velocity.x = 0.0
		velocity.z = 0.0


func _tick_launched(dt: float) -> void:
	var director: CombatDirector = find_director()
	var juggle: float = director.feel.get_f("juggle_float") if director != null else 1.0
	var gravity: float = float(_hit_feel.get("gravity_mps2", 26.0)) * JuggleRules.gravity_scale_after_hit(ms_since_air_hit(), juggle, _hit_feel.get("juggle", {}))
	velocity.y -= gravity * dt
	_knock *= exp(-AIR_DRAG * dt)
	velocity.x = _knock.x
	velocity.z = _knock.z
	if _state_ms > 80.0 and is_on_floor() and velocity.y <= 0.0:
		_land()


func _tick_down(dt: float) -> void:
	_apply_gravity(dt)
	velocity.x = move_toward(velocity.x, 0.0, 40.0 * dt)
	velocity.z = move_toward(velocity.z, 0.0, 40.0 * dt)
	var reaction: Dictionary = _hit_feel.get("reaction", {})
	if body_state == ST_DOWN and _state_ms >= float(reaction.get("knockdown_ms", 900.0)):
		if brain.roll_getup_roll() and _moves.has_move(move_set_id, MOVE_GETUP_ROLL):
			# 25% (Grunt): roll away instead of standing up; the roll has its own i-frames
			var target: CombatActor = _target()
			var away: Vector3 = -_toward(target)["dir"] if target != null else -forward()
			_begin_dodge(MOVE_GETUP_ROLL, away, &"dodge_back")
		else:
			_set_state(ST_GETUP)
			_play_once(_clip_for(&"getup"))
	elif body_state == ST_GETUP and _state_ms >= float(reaction.get("getup_ms", 600.0)):
		_set_state(ST_FREE)
		brain.notify(&"landed")


func _tick_dead(real_delta: float) -> void:
	_dead_real_s += real_delta
	_apply_gravity(real_delta)
	velocity.x = 0.0
	velocity.z = 0.0
	slide_scaled(1.0)
	_update_visual(real_delta)
	if respawns and _dead_real_s >= _respawn_s:
		respawn()


func respawn() -> void:
	if hijackable != null and hijackable.is_hijacked():
		hijackable.end_hijack()
	hijacked_by = null
	team = &"enemy"
	global_position = spawn_position
	rotation.y = spawn_yaw
	velocity = Vector3.ZERO
	revive(true)
	_dead_real_s = 0.0
	_knock = Vector3.ZERO
	_set_state(ST_FREE)
	brain = _make_brain()
	guard.refill()
	_windup_scale = 1.0
	_chain_cut_ms = -1.0
	_cornered = false
	runner.interrupt()
	get_hitbox().clear()
	get_hurtbox().collision_layer = CombatLayers.bit(CombatLayers.hurtbox_layer(team))
	collision_layer = CombatLayers.bit(CombatLayers.body_layer(team))
	poise_regen_per_s = float(data.get("poise_regen_per_s", 15.0))
	if model_root != null:
		model_root.visible = true


# ---- being hit ----

func _on_hit_reaction(result: Dictionary) -> void:
	var outcome: StringName = result.get("outcome", &"hit")
	_flash = 1.0
	if outcome == HitResolver.OUTCOME_EVADED or body_state == ST_DEAD:
		return
	if body_state == ST_GETUP and is_invulnerable():
		return
	if outcome == HitResolver.OUTCOME_ARMORED:
		brain.notify(&"armored_hit")        # the Brute does not flinch, but it may answer
		_alert_allies(&"hit")
		return
	_alert_allies(&"hit")
	if outcome == HitResolver.OUTCOME_BLOCKED:
		_on_blocked(result)
		return
	if outcome == HitResolver.OUTCOME_GUARD_BROKEN:
		_on_guard_broken(result)
		return
	_cut_attack()
	var launch: float = float(result.get("launch_mps", 0.0))
	var push: Vector3 = result.get("knockback", Vector3.ZERO)
	var stagger: bool = outcome == HitResolver.OUTCOME_STAGGER
	if launch > 0.0:
		velocity.y = launch
		_knock = push * KNOCK_DECAY * 0.35
		_knockdown_on_land = true
		_set_state(ST_LAUNCHED)
		brain.notify(&"launched")
		return
	if body_state == ST_LAUNCHED:
		# an air hit with no lift left, or a slam
		_knock = push * KNOCK_DECAY * 0.35
		if bool(result.get("knockdown", false)):
			velocity.y = -float((_hit_feel.get("reaction", {}) as Dictionary).get("slam_down_mps", 18.0))
			_slam = true
		return
	if bool(result.get("knockdown", false)):
		_knock = push * KNOCK_DECAY
		_set_state(ST_DOWN)
		_play_once(_clip_for(&"knockdown"))
		brain.notify(&"hit")
		return
	var reactions: Dictionary = _beh.get("reactions", {})
	var stun: float = float(result.get("hitstun_ms", 0.0))
	if stagger:
		stun = maxf(stun, float(reactions.get("stagger_ms", stun)))
	var heavy: bool = stagger or stun > float(reactions.get("flinch_max_hitstun_ms", 400.0))
	_knock = push * KNOCK_DECAY
	if body_state == ST_STAGGER or body_state == ST_RECOIL:
		_stun_ms = maxf(_stun_ms, stun)
	else:
		_stun_ms = stun
		_set_state(ST_STAGGER if stagger else ST_HURT)
		_stagger_clip = &"stagger"
		_flinch_clip = _pick_flinch_clip()
		_face_red_ms = 0.0 if heavy else float(reactions.get("turn_to_red_ms", 120.0))
	brain.notify(&"staggered" if stagger else &"hit")


## A raised guard took the hit: the meter drains, no hit-stun, a little push, and the string goes on.
func _on_blocked(result: Dictionary) -> void:
	guard.absorb(float(result.get("guard_drain", 0.0)), clock.now_ms())
	_knock = (result.get("knockback", Vector3.ZERO) as Vector3) * KNOCK_DECAY
	_play_once(_clip_for(&"block_impact"))
	brain.notify(&"blocked")


## The guard broke: a long stagger with the armor off (the punish window), and a fresh meter afterwards.
func _on_guard_broken(result: Dictionary) -> void:
	guard.refill()
	_cut_attack()
	_stun_ms = maxf(float(result.get("hitstun_ms", _guard_break_ms)), 1.0)
	_knock = (result.get("knockback", Vector3.ZERO) as Vector3) * KNOCK_DECAY
	_stagger_clip = &"block_break"
	_set_state(ST_STAGGER)
	brain.notify(&"guard_broken")


func _pick_flinch_clip() -> StringName:
	var names: Array = (_beh.get("reactions", {}) as Dictionary).get("flinch_anims", [])
	if names.is_empty():
		return &"hurt"
	return _clip_for(StringName(str(names[_rng_fx.randi() % names.size()])))


func _on_parried(result: Dictionary) -> void:
	if body_state == ST_DEAD:
		return
	_cut_attack()
	var parry: Dictionary = _hit_feel.get("parry", {})
	var perfect: bool = result.get("outcome", &"") == HitResolver.OUTCOME_PERFECT_PARRY
	_stun_ms = float(parry.get("stagger_ms", 1500.0)) if perfect else float(parry.get("recoil_ms", 700.0))
	_knock = Vector3.ZERO
	_flash = 1.0
	_stagger_clip = &"stagger"
	_set_state(ST_STAGGER if perfect else ST_RECOIL)
	brain.notify(&"staggered" if perfect else &"parried")


func _on_death(_result: Dictionary) -> void:
	_cut_attack()
	_set_state(ST_DEAD)
	_dead_real_s = 0.0
	_play_once(_clip_for(&"death"))
	get_hurtbox().collision_layer = 0
	collision_layer = 0
	var director: CombatDirector = find_director()
	if director != null and director.tokens != null:
		director.tokens.release(actor_id)
	_alert_allies(&"died")


func _cut_attack() -> void:
	if runner != null and runner.is_busy():
		runner.interrupt()
	get_hitbox().clear()
	_telegraph_left_ms = 0.0
	_windup_scale = 1.0
	_chain_cut_ms = -1.0
	var director: CombatDirector = find_director()
	if director != null and director.tokens != null:
		director.tokens.release(actor_id)


func _land() -> void:
	juggle_count = 0
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO
	_slam = false
	_set_state(ST_DOWN)
	_play_once(_clip_for(&"knockdown"))
	brain.notify(&"landed")


func _set_state(next: StringName) -> void:
	body_state = next
	_state_ms = 0.0


# ---- what the encounter runner hands over (data/slice/encounters.json `tune` and `state`) ----

## Lays numbers over this enemy's data: a key that is one of its brain numbers (attack_interval_ms, notice_range_m ...) changes
## the brain; one that is a defence number (block_chance, dodge_chance ...) changes how it defends. Anything else is kept in `tune`
## and warned about. Safe to call before the enemy is in the tree (it is applied when it is).
func apply_tune(values: Dictionary) -> void:
	if data.is_empty():
		_pending_tune.merge(values, true)
		return
	var numbers: Dictionary = data.get("brain", {}) as Dictionary
	var defend: Dictionary = (_beh.get("defend", {}) as Dictionary)
	for key: Variant in values.keys():
		var name_key: String = str(key)
		if numbers.has(name_key):
			_brain_overrides[name_key] = values[key]
		elif defend.has(name_key):
			defend[name_key] = values[key]
		else:
			push_warning("ActionEnemy %s: no tuning number called '%s'" % [actor_id, name_key])
		tune[name_key] = values[key]
	if brain != null:
		brain = _make_brain()


## The enemy's starting behaviour: idle and idle_at_barrel (stands until it notices Red: the default), patrol (walks a short beat
## round its spawn point until it notices her) and ambush (notices only when she is close, then goes at once).
func apply_state(state_name: StringName) -> void:
	if data.is_empty():
		_pending_state = state_name
		return
	behaviour_state = state_name
	match state_name:
		&"ambush":
			var near: float = float((data.get("brain", {}) as Dictionary).get("notice_range_m", 14.0)) * 0.5
			_brain_overrides["notice_range_m"] = near
			_brain_overrides["notice_ms"] = 150
		&"patrol":
			_patrol_to = spawn_position + forward() * PATROL_LEG_M
			_patrol_flip = false
	if brain != null:
		brain = _make_brain()


func _patrol_velocity() -> Vector3:
	var to: Vector3 = _patrol_to - global_position
	to.y = 0.0
	if to.length() < 0.5:
		_patrol_flip = not _patrol_flip
		_patrol_to = spawn_position + forward() * (PATROL_LEG_M if not _patrol_flip else -PATROL_LEG_M)
		to = _patrol_to - global_position
		to.y = 0.0
	return to.normalized() * float(data.get("move_speed_mps", 2.8)) * PATROL_SPEED_MULT


## The damage scale for hits on Red in her current body (encounters.json rules.vs_form): the loader chips rather than dies.
func _vs_form_damage_mult() -> float:
	var target: CombatActor = _target()
	if target == null or not target.has_method(&"get_form_id"):
		return 1.0
	var table: Dictionary = (CombatData.read_json("res://data/slice/encounters.json").get("rules", {}) as Dictionary).get("vs_form", {}) as Dictionary
	return float((table.get(str(target.call(&"get_form_id")), {}) as Dictionary).get("damage_mult", 1.0))


# ---- Overclock: hijacked and stunned (slice tech plan 4.4) ----

## Does the data say Overclock can take this enemy? (enemies.json `hijackable`; bosses say no.)
func hijack_allowed() -> bool:
	return bool(data.get("hijackable", false)) and not tags.has("boss")


func _make_hijackable() -> void:
	if not bool(data.get("hijackable", false)):
		return
	hijackable = get_node_or_null("Hijackable") as Hijackable
	if hijackable == null:
		hijackable = Hijackable.new()
		hijackable.name = "Hijackable"
		hijackable.allowed = hijack_allowed()
		hijackable.aim_height_m = height_m * 0.9
		add_child(hijackable)
	var spec: Dictionary = data.get("hijack", {}) as Dictionary
	_hijack_color = Color.html(str(spec.get("color", "#33f2ff")))


## Overclock took it over: Red's side for `duration_s`, it fights the nearest enemy, gives up its attack token and
## glows cyan. Its hits go through the director as a player-team attacker (so they hurt enemies and boss parts).
func on_hijack_begin(by: CombatActor, duration_s: float) -> bool:
	if dead or hijacked_by != null or body_state == ST_DEAD:
		return false
	hijacked_by = by
	team = by.team if by != null else CombatDirector.PLAYER_TEAM
	var director: CombatDirector = find_director()
	_cut_attack()
	if director != null and director.tokens != null:
		director.tokens.release(actor_id)
	brain.notify(&"move_finished")
	var spec: Dictionary = data.get("hijack", {}) as Dictionary
	if spec.has("interval_ms"):
		brain = _make_brain({"attack_interval_ms": spec["interval_ms"], "recover_ms": 100})     # a hijacked turret fires about every 1.4 s
	_hijack_end_stun_ms = float(CombatData.hacks().get("hacks", {}).get("overclock", {}).get("effect", {}).get("end_stun_ms", 800.0))
	_hijack_damage_scale = 1.0
	if director != null and director.feel != null and director.feel.has("hack_damage_scale"):
		_hijack_damage_scale = director.feel.get_f("hack_damage_scale")
	_hijack_damage_scale *= float(CombatData.hacks().get("hacks", {}).get("overclock", {}).get("effect", {}).get("ally_damage_scale", 1.0))
	if body_state == ST_STAGGER or body_state == ST_RECOIL or body_state == ST_HURT:
		_stun_ms = minf(_stun_ms, 200.0)          # shaken awake: it fights for Red almost at once
	return true


## Time is up (or the link broke): back to its owners, dazed for a moment (no instant revenge). A dead one just stays dead.
func on_hijack_end() -> void:
	if hijacked_by == null:
		return
	hijacked_by = null
	team = &"enemy"
	_hijack_damage_scale = 1.0
	if (data.get("hijack", {}) as Dictionary).has("interval_ms"):
		brain = _make_brain()
	var director: CombatDirector = find_director()
	if dead or body_state == ST_DEAD:
		return
	_cut_attack()
	if director != null and director.tokens != null:
		director.tokens.release(actor_id)
	apply_stun(_hijack_end_stun_ms)


## Knocks it out for `ms` (EMP, the end of a hijack): it stands dazed, attacks cancelled, and cannot act until the time is up.
## A longer stun already running is kept. No effect on the dead.
func apply_stun(ms: float) -> void:
	if dead or body_state == ST_DEAD or ms <= 0.0:
		return
	_cut_attack()
	if body_state == ST_LAUNCHED or body_state == ST_DOWN or body_state == ST_GETUP:
		return                  # already out of the fight; the stun would only cut its get-up short
	if body_state == ST_STAGGER or body_state == ST_RECOIL or body_state == ST_HURT:
		_stun_ms = maxf(_stun_ms, ms)
	else:
		_stun_ms = ms
		_set_state(ST_STAGGER)
		_stagger_clip = &"stagger"
		brain.notify(&"staggered")
	if body_state == ST_HURT:
		_set_state(ST_STAGGER)


# ---- allies ----

func _alert_allies(event: StringName) -> void:
	var director: CombatDirector = find_director()
	if director != null:
		director.alert_allies(self, event)


## Another enemy was hit or died at `at`. True if this one heard it (inside its own alert radius).
func hear_ally(at: Vector3, event: StringName) -> bool:
	if dead or brain == null:
		return false
	var alert: Dictionary = _beh.get("alert", {})
	if alert.is_empty():
		return false
	if event == &"died" and not bool(alert.get("on_ally_death", true)):
		return false
	if event != &"died" and not bool(alert.get("on_ally_hit", true)):
		return false
	if global_position.distance_to(at) > float(alert.get("radius_m", 9.0)):
		return false
	brain.notify(&"ally_died" if event == &"died" else &"ally_alert")
	return true


# ---- the brain's eyes ----

## What the brain gets to see this frame (the `view` of EnemyBrain).
func _make_view(target: CombatActor, dist: float, has_token: bool, enabled: bool, body: StringName, director: CombatDirector) -> Dictionary:
	var view: Dictionary = {"dist_to_player": dist, "player_airborne": target != null and target.is_airborne(),
			"player_attacking": false, "has_token": has_token, "state": body,
			"poise_frac": poise / poise_max if poise_max > 0.0 else 1.0, "attacks_enabled": enabled,
			"hp_frac": float(hp) / float(maxi(hp_max, 1)), "knobs": _knob_view(director), "cornered": _cornered}
	if target == null or director == null or hijacked_by != null:
		return view            # (a hijacked unit has no use for what Red's swing looks like)
	var angle: float = EnemyRules.relative_angle_deg(target.global_position, target.forward(), global_position)
	view["my_angle_deg"] = angle
	view["in_rear_arc"] = EnemyRules.in_rear_arc(angle, float(_rules.get("rear_arc_deg", 120.0)))
	var info: Dictionary = director.player_swing_info(self)
	var defend: Dictionary = _beh.get("defend", {})
	view["player_swing_id"] = info["id"]
	view["player_move_class"] = info["class"]
	view["player_swing_active"] = info["active"]
	view["player_swing_threat"] = bool(info["threat"]) and dist <= float(defend.get("threat_range_m", 3.2))
	view["player_attacking"] = bool(info["active"]) and info["class"] != EnemyRules.CLASS_NONE
	view["player_combo_len"] = int(info["combo_len"])
	view["player_dashing_toward"] = director.player_dash_toward(self)
	view["flare"] = director.time.is_slowed(actor_id)
	var repo: Dictionary = _beh.get("reposition", {})
	var crowd_radius: float = float(repo.get("crowd_radius_m", 2.6))
	var pack_radius: float = float((_beh.get("low_health", {}) as Dictionary).get("pack_radius_m", 8.0))
	var crowd: int = 0
	var near: int = 0
	var flankers: int = 0
	var allies: Array[Dictionary] = []
	for other: CombatActor in director.living_enemies():
		if other == self:
			continue
		var gap: float = other.global_position.distance_to(global_position)
		allies.append({"angle_deg": EnemyRules.relative_angle_deg(target.global_position, target.forward(), other.global_position), "dist_m": gap})
		if other.global_position.distance_to(target.global_position) <= crowd_radius:
			crowd += 1
		if gap <= pack_radius:
			near += 1
		var buddy: ActionEnemy = other as ActionEnemy
		if buddy != null and buddy.brain != null and buddy.brain.is_flanking():
			flankers += 1
	view["crowd_count"] = crowd
	view["allies_near"] = near
	view["flankers_other"] = flankers
	view["allies"] = allies
	return view


func _knob_view(director: CombatDirector) -> Dictionary:
	if director == null or director.feel == null:
		return {}
	var out: Dictionary = {}
	for id: String in ["enemy_aggression", "enemy_reaction_scale", "enemy_dodge_scale", "enemy_block_scale", "enemy_spacing_scale"]:
		if director.feel.has(id):
			out[id] = director.feel.get_f(id)
	for id: String in ["enemy_flee_on", "enemy_flank_on", "enemy_enrage_on"]:
		if director.feel.has(id):
			out[id] = director.feel.get_b(id)
	return out


## Running into a wall while fleeing: the commanded speed is there but the body is not getting anywhere.
func _note_cornered(_dt: float) -> void:
	if brain == null or not brain.is_fleeing() or _commanded_speed < 1.0:
		_cornered = false
		return
	var actual: float = Vector2(get_real_velocity().x, get_real_velocity().z).length()
	_cornered = actual < _commanded_speed * CORNERED_SPEED_RATIO


## The Grunt's hp can be scaled live by the "Enemy health" knob (hp keeps its share).
func _apply_hp_scale(director: CombatDirector) -> void:
	if director == null or director.feel == null or not director.feel.has("enemy_hp_scale"):
		return
	var scale: float = director.feel.get_f("enemy_hp_scale")
	if is_equal_approx(scale, _hp_scale_applied):
		return
	var share: float = float(hp) / float(maxi(hp_max, 1))
	hp_max = maxi(int(roundf(float(data.get("hp", 40)) * scale)), 1)
	hp = clampi(int(roundf(share * float(hp_max))), 1 if hp > 0 else 0, hp_max)
	_hp_scale_applied = scale
	director.hp_changed.emit(actor_id, hp, hp_max)


# ---- movement helpers ----

func _apply_gravity(dt: float) -> void:
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = -1.0
	else:
		velocity.y -= float(_hit_feel.get("gravity_mps2", 26.0)) * dt


func _turn_toward(direction: Vector3, dt: float) -> void:
	if direction.length() < FACE_TURN_EPS:
		return
	var wanted: float = atan2(direction.x, direction.z)
	var step: float = deg_to_rad(float(data.get("turn_rate_deg_per_s", 420.0))) * dt
	rotation.y = rotate_toward(rotation.y, wanted, step)


func _turn_toward_fast(direction: Vector3, dt: float) -> void:
	if direction.length() < FACE_TURN_EPS:
		return
	rotation.y = rotate_toward(rotation.y, atan2(direction.x, direction.z), deg_to_rad(FAST_TURN_DEG_PER_S) * dt)


## The brain's move_dir (player frame) in world space.
func _world_move(move_dir: Vector3, dir_to_player: Vector3) -> Vector3:
	var side: Vector3 = dir_to_player.cross(Vector3.UP)
	return dir_to_player * move_dir.z + side * move_dir.x


# ---- data ----

func _load_data() -> void:
	var all: Dictionary = CombatData.enemies()
	data = ((all.get("enemies", {}) as Dictionary).get(String(enemy_id), {}) as Dictionary).duplicate(true)
	_rules = (all.get("telegraph_rules", {}) as Dictionary).duplicate(true)
	_hit_feel = CombatData.hit_feel()
	_moves = MoveSet.load_default()
	if data.is_empty():
		push_error("ActionEnemy: no enemy '%s' in enemies.json" % enemy_id)
		return
	_beh = data.get("behaviour", {})
	if actor_id == &"":
		_spawn_counts[enemy_id] = int(_spawn_counts.get(enemy_id, 0)) + 1
		actor_id = StringName("%s_%d" % [enemy_id, int(_spawn_counts[enemy_id])])
	team = &"enemy"
	move_set_id = StringName(str(data.get("move_set", enemy_id)))
	hp_max = int(data.get("hp", 40))
	hp = hp_max
	poise_max = float(data.get("poise", 0.0))
	poise = poise_max
	poise_regen_per_s = float(data.get("poise_regen_per_s", 15.0))
	poise_regen_delay_ms = float(data.get("poise_regen_delay_ms", 1500.0))
	weight = float(data.get("weight", 1.0))
	launchable = bool(data.get("launchable", true))
	height_m = float(data.get("height_m", 1.2))
	radius_m = float(data.get("radius_m", 0.36))
	for tag: Variant in data.get("tags", []) as Array:
		tags.append(str(tag))
	_telegraph_color = Color.html(str(data.get("telegraph_color", "#ff4a3a")))
	var enrage: Dictionary = ((_beh.get("low_health", {}) as Dictionary).get("enrage", {}) as Dictionary)
	_enrage_color = Color.html(str(enrage.get("color", "#ff3a1a")))
	guard = GuardMeter.from_data(_beh.get("guard", {}))
	_guard_break_ms = float(_moves.get_move(move_set_id, MOVE_BLOCK_BREAK).get("total_ms", 1100.0))
	_rng_fx.seed = (rng_seed if rng_seed != 0 else hash(String(actor_id))) + 7
	var sandbox: Dictionary = CombatData.combat_file(CombatData.FILE_SANDBOX)
	_respawn_s = float(sandbox.get("respawn_s", DEFAULT_RESPAWN_S))


func _make_brain(brain_override: Dictionary = {}) -> EnemyBrain:
	var brain_data: Dictionary = data.duplicate(true)
	var combined: Dictionary = _brain_overrides.duplicate()
	combined.merge(brain_override, true)
	if not combined.is_empty():
		var numbers: Dictionary = (brain_data.get("brain", {}) as Dictionary)
		numbers.merge(combined, true)
		brain_data["brain"] = numbers
	var gaits: Dictionary = {}
	for gait: String in ["strafe", "retreat", "flee"]:
		var move: Dictionary = _moves.get_move(move_set_id, StringName(gait))
		if move.has("speed_mps"):
			gaits[gait] = float(move["speed_mps"])
	brain_data["gaits"] = gaits
	brain_data["telegraph_rules"] = _rules
	return EnemyBrain.create(brain_data, rng_seed if rng_seed != 0 else hash(String(actor_id)))


func _build_body_shape() -> void:
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		add_child(shape_node)
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius_m
	capsule.height = maxf(height_m, radius_m * 2.0)
	shape_node.shape = capsule
	shape_node.position = Vector3(0.0, capsule.height * 0.5, 0.0)
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)


func _build_visual() -> void:
	model_root = Node3D.new()
	model_root.name = "Model"
	add_child(model_root)
	var node: Node3D = null
	for key: String in ["model", "fallback_model"]:
		var path: String = str(data.get(key, ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			continue
		node = scene.instantiate() as Node3D
		if node != null:
			_visual_kind = "model" if key == "model" else "fallback"
			break
	if node == null:
		node = _make_blockout()
		_visual_kind = "blockout"
	model_root.add_child(node)
	if _visual_kind == "fallback":
		_fit_to_height(node)
	_anim = _find_animation_player(model_root)
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1, 1, 1, 0)
	_collect_meshes(model_root)
	for mesh: MeshInstance3D in _overlay_meshes:
		mesh.material_overlay = _overlay


func _make_blockout() -> Node3D:
	var spec: Dictionary = data.get("blockout", {})
	var root: Node3D = Node3D.new()
	root.name = "Blockout"
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var body_material: StandardMaterial3D = StandardMaterial3D.new()
	body_material.albedo_color = Color.html(str(spec.get("color", "#6b7280")))
	if str(spec.get("shape", "capsule")) == "box":
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(radius_m * 2.0, height_m, radius_m * 2.0)
		mesh_node.mesh = box
	else:
		var capsule: CapsuleMesh = CapsuleMesh.new()
		capsule.radius = radius_m
		capsule.height = maxf(height_m, radius_m * 2.0)
		mesh_node.mesh = capsule
	mesh_node.material_override = body_material
	mesh_node.position = Vector3(0.0, height_m * 0.5, 0.0)
	root.add_child(mesh_node)
	# a bright "face" on the +Z side so the facing (and the wind-up turn) can be read
	var face: MeshInstance3D = MeshInstance3D.new()
	var face_mesh: BoxMesh = BoxMesh.new()
	face_mesh.size = Vector3(radius_m * 1.1, height_m * 0.16, radius_m * 0.5)
	face.mesh = face_mesh
	var face_material: StandardMaterial3D = StandardMaterial3D.new()
	face_material.albedo_color = Color.html(str(spec.get("face_color", "#e8d36a")))
	face_material.emission_enabled = true
	face_material.emission = face_material.albedo_color
	face_material.emission_energy_multiplier = 0.6
	face.material_override = face_material
	face.position = Vector3(0.0, height_m * 0.82, radius_m * 0.85)
	root.add_child(face)
	return root


## Scale a model of unknown size to the enemy's height and stand its feet on the floor.
func _fit_to_height(node: Node3D) -> void:
	var bounds: AABB = _merged_bounds(node)
	if bounds.size.y <= 0.001:
		return
	var factor: float = height_m / bounds.size.y
	node.scale = Vector3.ONE * factor
	node.position = Vector3(-(bounds.position.x + bounds.size.x * 0.5) * factor, -bounds.position.y * factor, -(bounds.position.z + bounds.size.z * 0.5) * factor)


func _merged_bounds(node: Node) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D:
			var mesh_node: MeshInstance3D = current
			var local: AABB = mesh_node.get_aabb()
			var xform: Transform3D = _relative_transform(mesh_node, node)
			var box: AABB = xform * local
			result = box if first else result.merge(box)
			first = false
		for child: Node in current.get_children():
			stack.append(child)
	return result


func _relative_transform(node: Node3D, ancestor: Node) -> Transform3D:
	var xform: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor.get_parent():
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child: Node in root.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null


func _collect_meshes(root: Node) -> void:
	if root is MeshInstance3D:
		_overlay_meshes.append(root)
	for child: Node in root.get_children():
		_collect_meshes(child)


# ---- clips ----

## The clip a behaviour name maps to: `behaviour.clips.<key>.clip` from enemies.json, else the key itself.
func _clip_for(key: StringName) -> StringName:
	var clips: Dictionary = _beh.get("clips", {})
	if clips.has(String(key)):
		return StringName(str((clips[String(key)] as Dictionary).get("clip", key)))
	return key


func _has_clip(clip: StringName) -> bool:
	return _anim != null and _anim.has_animation(String(clip))


func _play_pose(clip: StringName, clip_s: float) -> void:
	if not _has_clip(clip):
		return
	_anim.play(String(clip))
	_anim.seek(clip_s, true)
	_anim.pause()
	_current_clip = &""


## Play a one-shot clip from its start (skipped when the model does not have it: the lean and the flash still run).
func _play_once(clip: StringName) -> void:
	if not _has_clip(clip):
		return
	_anim.play(String(clip), 0.05)
	_anim.speed_scale = 1.0
	_current_clip = clip


func _play_loop(clip: StringName, speed: float, backwards: bool = false) -> void:
	if not _has_clip(clip):
		return
	var tag: StringName = StringName(String(clip) + ("<" if backwards else ""))
	if _current_clip != tag:
		if backwards:
			_anim.play_backwards(String(clip), 0.1)
		else:
			_anim.play(String(clip), 0.1)
		_current_clip = tag
	_anim.speed_scale = speed


## A move with no pose keys (the Brute's slam) stretches its clip over the move so the strike lands on the impact.
func _start_move_clip(move: Dictionary, windup_ms: float) -> void:
	_clip_speed = 1.0
	var anim: Dictionary = move.get("anim", {})
	var clip: StringName = StringName(str(anim.get("clip", "")))
	if not (anim.get("keys", []) as Array).is_empty() or not _has_clip(clip):
		return
	var total_s: float = (float(move.get("total_ms", 1000.0)) + maxf(windup_ms - float(move.get("impact_ms", 0.0)), 0.0)) / 1000.0
	_clip_speed = _anim.get_animation(String(clip)).length / maxf(total_s, 0.1)
	_anim.play(String(clip), 0.05)
	_anim.speed_scale = _clip_speed
	_current_clip = clip


func _play_locomotion(speed: float) -> void:
	var flat: float = Vector2(velocity.x, velocity.z).length()
	var gait: StringName = StringName(str(last_intent.get("gait", "idle")))
	var key: StringName = &"idle"
	if flat > 0.3:
		if gait == &"strafe" or gait == &"walk" or gait == &"approach" or gait == &"retreat" or gait == &"flee" or gait == &"stalk":
			key = gait
		else:
			key = &"approach" if flat > 2.0 else &"walk"
	elif gait == &"notice":
		key = &"notice"
	var clips: Dictionary = _beh.get("clips", {})
	var entry: Dictionary = clips.get(String(key), {})
	var clip: StringName = _clip_for(key)
	if not _has_clip(clip):
		# fall back to what any wolf has: walk, run, idle
		for fallback: StringName in ([&"run", &"walk", &"idle"] if key == &"flee" or key == &"approach" else [&"walk", &"idle"]):
			if _has_clip(fallback):
				clip = fallback
				break
		entry = {}
	_play_loop(clip, speed * float(entry.get("speed_scale", 1.0)), bool(entry.get("reverse", false)))


func _update_visual(dt: float) -> void:
	if model_root == null:
		return
	var ratio: float = clampf(dt / maxf(get_physics_process_delta_time(), 0.0001), 0.0, 2.0)
	# clips for the loops (idle / walk / reactions) when the model has them
	if _anim != null:
		match body_state:
			ST_FREE:
				if runner.is_busy():
					if _clip_speed != 1.0:
						_anim.speed_scale = _clip_speed * ratio
				else:
					_play_locomotion(ratio)
			ST_DODGE, ST_BLOCK:
				_anim.speed_scale = ratio
			ST_HURT, ST_RECOIL:
				_play_loop(_flinch_clip, ratio)
			ST_STAGGER:
				_play_loop(_clip_for(_stagger_clip), ratio)
			ST_LAUNCHED:
				_play_loop(_clip_for(&"launched"), ratio)
			ST_DOWN:
				_play_loop(_clip_for(&"knockdown"), ratio)
			ST_GETUP:
				_play_loop(_clip_for(&"getup"), ratio)
	# procedural lean / tumble: always on, small on a rigged model, the whole show on a blockout
	var target_pitch: float = 0.0
	var target_drop: float = 0.0
	var move: Dictionary = runner.data() if runner.is_busy() else {}
	match body_state:
		ST_FREE:
			if not move.is_empty():
				var ms: float = runner.elapsed_ms()
				var startup: float = float(move.get("startup_ms", 1.0))
				if ms < startup:
					target_pitch = -0.4 * smoothstep(0.0, 1.0, ms / maxf(startup * 0.8, 1.0))
					target_drop = -0.08 * target_pitch / -0.4
				elif runner.phase() == &"active":
					target_pitch = 0.5
				else:
					target_pitch = 0.1
		ST_DODGE:
			target_pitch = 0.25
		ST_BLOCK:
			target_pitch = -0.18 if is_guarding() else 0.0
		ST_HURT, ST_RECOIL:
			target_pitch = -0.3
		ST_STAGGER:
			target_pitch = -0.55
		ST_LAUNCHED:
			target_pitch = -1.1
		ST_DOWN:
			target_pitch = -1.5
			target_drop = 0.12
	if _anim != null and body_state != ST_FREE:
		target_pitch *= 0.0      # a rigged model plays its own reaction clips
	_pitch = lerpf(_pitch, target_pitch, clampf(dt * 18.0, 0.0, 1.0))
	_drop = lerpf(_drop, target_drop, clampf(dt * 18.0, 0.0, 1.0))
	model_root.rotation.x = _pitch
	model_root.position.y = _drop
	if body_state == ST_DEAD:
		model_root.visible = fmod(_dead_real_s * 12.0, 1.0) < 0.5 and _dead_real_s < 0.7
	_update_overlay(dt)


## The colour overlay: white flash on a hit; a cyan blink just before a Grunt dodge; the wind-up flash in the
## enemy's colour pulsing 8 times a second and getting brighter toward the impact; a steady glow when enraged.
func _update_overlay(dt: float) -> void:
	_flash = maxf(_flash - dt * 7.0, 0.0)
	if _telegraph_left_ms > 0.0:
		_telegraph_left_ms = maxf(_telegraph_left_ms - dt * 1000.0, 0.0)
	if _overlay == null:
		return
	if _flash > 0.0:
		_overlay.albedo_color = Color(1.0, 1.0, 1.0, 0.6 * _flash)
		return
	if body_state == ST_DODGE and runner.is_busy():
		var tell: Dictionary = runner.data().get("tell", {})
		var ms: float = runner.elapsed_ms()
		if not tell.is_empty() and ms >= float(tell.get("from_ms", 0.0)) and ms < float(tell.get("to_ms", 0.0)):
			_overlay.albedo_color = Color(DODGE_TELL_COLOR.r, DODGE_TELL_COLOR.g, DODGE_TELL_COLOR.b, 0.7)
			return
	if _telegraph_left_ms > 0.0 and _telegraph_total_ms > 0.0:
		var progress: float = 1.0 - _telegraph_left_ms / _telegraph_total_ms
		var pulse: float = 0.5 + 0.5 * sin(TAU * TELEGRAPH_HZ * clock.now_ms() / 1000.0)
		var alpha: float = lerpf(0.2, 0.65, progress) * (0.45 + 0.55 * pulse)
		_overlay.albedo_color = Color(_telegraph_color.r, _telegraph_color.g, _telegraph_color.b, alpha)
		return
	if hijacked_by != null and body_state != ST_DEAD:
		_overlay.albedo_color = Color(_hijack_color.r, _hijack_color.g, _hijack_color.b, 0.32)       # cyan edge: Red's for now
		return
	if is_enraged() and body_state != ST_DEAD:
		_overlay.albedo_color = Color(_enrage_color.r, _enrage_color.g, _enrage_color.b, 0.2)
		return
	_overlay.albedo_color = Color(_telegraph_color.r, _telegraph_color.g, _telegraph_color.b, 0.0)
