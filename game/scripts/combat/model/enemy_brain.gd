class_name EnemyBrain
extends RefCounted
## What an enemy decides to do (contract 4.2, docs/pivot/enemy_ai_design.md). Pure: time and a small `view` of
## the world go in, an intent comes out, and a seeded random generator makes every run repeatable. The numbers
## are the enemy's `brain`, `attacks` and `behaviour` blocks in enemies.json; the feel knobs arrive in the view.
##
## States: idle -> notice -> approach -> circle -> (token) -> attack -> recover -> react -> dead, plus
##   defend      a dodge or a block (one defence roll per Red swing that threatens it, EnemyDefence)
##   reposition  back off (crowded, Red mid-combo), retreat after an attack, keep away from a dash
##   flee, flank low health (Cyberwolf): run away, or circle to Red's back and hit from there
##   enrage      the Brute's roar at low health (then enraged for the rest of the fight)
## Without a `behaviour` block the brain plays the original circle-and-attack fight.
##
## view   = {dist_to_player, player_airborne, player_attacking, has_token, state, poise_frac, attacks_enabled,
##           hp_frac, my_angle_deg, in_rear_arc, crowd_count, allies_near, allies: [{angle_deg, dist_m}], flankers_other,
##           player_swing_id, player_swing_threat, player_swing_active, player_move_class, player_combo_len,
##           player_dashing_toward, flare, cornered, knobs: {enemy_aggression, enemy_reaction_scale, ...}}
##          `state` is what the body is doing: &"free", &"busy" (hit-stun, launched, down, getting up) or &"dead".
## intent = {move_dir, face_player, want_token, start_move, state, defend, guard, gait, speed_mps, speed_mult,
##           flank, chain_recover_ms, face_move}
##          `move_dir` is in the PLAYER'S frame: z = toward the player (negative = back off), x = sideways
##          around the player (the body turns it into a world direction; positive x raises my_angle_deg),
##          length 0..1 of the walk speed. `defend` = {kind: dodge|block, variant: side|back, sign: 1|-1} once, when
##          a defence starts; `guard` = keep the guard up.
## Events: hit, launched, landed, parried, staggered, token_granted, move_finished, attack_denied, defence_finished,
##         blocked, guard_broken, armored_hit, ally_alert, ally_died, step_up.

const IDLE: StringName = &"idle"
const NOTICE: StringName = &"notice"
const APPROACH: StringName = &"approach"
const CIRCLE: StringName = &"circle"
const ATTACK: StringName = &"attack"
const RECOVER: StringName = &"recover"
const REACT: StringName = &"react"
const DEAD: StringName = &"dead"
const DEFEND: StringName = &"defend"
const REPOSITION: StringName = &"reposition"
const FLEE: StringName = &"flee"
const FLANK: StringName = &"flank"
const ENRAGE: StringName = &"enrage"
const FREE: StringName = &"free"
const BUSY: StringName = &"busy"
const KIND_RETREAT: StringName = &"retreat"
const KIND_BACK_OFF: StringName = &"back_off"
const ATTACK_SAFETY_MS: float = 12000.0
const TOKEN_PATIENCE_MS: float = 3500.0
const DEFEND_SAFETY_MS: float = 4000.0
const ROAR_SAFETY_MS: float = 3000.0
const ATTACK_RETRY_MS: float = 150.0
const RETALIATE_FLAG_MS: float = 1500.0
const STRING_TARGET_MS: float = 1500.0
const DEFAULT_RETREAT_SPEED: float = 3.4

var _brain: Dictionary = {}
var _attacks: Array = []
var _beh: Dictionary = {}
var _gaits: Dictionary = {}
var _rules: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _defence: EnemyDefence = null
var _state: StringName = IDLE
var _since_ms: float = 0.0
var _now_ms: float = 0.0
var _next_attack_ms: float = 0.0
var _circle_sign: float = 1.0
var _flip_at_ms: float = 0.0
var _react_free_since_ms: float = -1.0
var _react_hold_ms: float = 250.0
var _chosen: Dictionary = {}
var _token_wait_since_ms: float = -1.0
var _started: bool = false
var _knobs: Dictionary = {}

var _notice_ms_override: float = -1.0
var _return_state: StringName = CIRCLE
var _attack_retry_ms: float = -1.0
var _track_ms_eff: float = -1.0
var _seen_swing: int = 0
var _roll_at_ms: float = -1.0
var _roll_class: StringName = &""
var _roll_swing: int = 0
var _hit_times: Array[float] = []
var _last_hit_ms: float = -1.0e9
var _escape_checked_hit_ms: float = -1.0

var _defend_kind: StringName = &""
var _defend_variant: StringName = &"side"
var _defend_sign: float = 1.0
var _defend_sent: bool = false
var _guard_up: bool = false
var _hold_min_ms: float = 350.0
var _hold_max_ms: float = 550.0
var _blocks_in_hold: int = 0
var _last_threat_ms: float = -1.0e9

var _repo_kind: StringName = KIND_BACK_OFF
var _repo_until_ms: float = 0.0
var _repo_keeps_timer: bool = false
var _repo_saved_attack_ms: float = 0.0
var _keep_away_next_ms: float = 0.0
var _counter_until_ms: float = -1.0
var _retaliate_since_ms: float = -1.0
var _last_retaliate_ms: float = -1.0e9

var _lowhp_cd_until_ms: float = -1.0e9
var _bold_until_ms: float = -1.0e9
var _flees_used: int = 0
var _cornered_since_ms: float = -1.0
var _flank_since_ms: float = 0.0
var _flank_hold_since_ms: float = -1.0
var _flank_ready: bool = false
var _flank_side: float = 1.0
var _ally_deaths: Array[float] = []

var _enraged_once: bool = false
var _enraged: bool = false
var _roar_sent: bool = false
var _chain_next: bool = false
var _chain_followup: bool = false


static func create(data: Dictionary, rng_seed: int) -> EnemyBrain:
	var brain: EnemyBrain = EnemyBrain.new()
	brain._brain = (data.get("brain", {}) as Dictionary).duplicate(true)
	brain._attacks = (data.get("attacks", []) as Array).duplicate(true)
	brain._beh = (data.get("behaviour", {}) as Dictionary).duplicate(true)
	brain._gaits = (data.get("gaits", {}) as Dictionary).duplicate(true)
	brain._rules = (data.get("telegraph_rules", {}) as Dictionary).duplicate(true)
	brain._rng.seed = rng_seed
	brain._circle_sign = 1.0 if brain._rng.randf() < 0.5 else -1.0
	brain._defence = EnemyDefence.create(brain._beh.get("defend", {}), brain._rng)
	return brain


func state() -> StringName:
	return _state


func is_fleeing() -> bool:
	return _state == FLEE


func is_flanking() -> bool:
	return _state == FLANK or (_state == ATTACK and bool(_chosen.get("flank", false)))


func is_defending() -> bool:
	return _state == DEFEND


func is_enraged() -> bool:
	return _enraged


## Enrage: slam damage multiplier (1.0 when calm).
func damage_mult() -> float:
	return float(_enrage_cfg().get("damage_mult", 1.0)) if _enraged else 1.0


## Enrage: no poise regeneration.
func poise_regen_allowed() -> bool:
	return not (_enraged and bool(_enrage_cfg().get("no_poise_regen", false)))


## True when the body should hold on to the token after a move (the Brute's chained second slam).
func keeps_token() -> bool:
	return _chain_next and _state == CIRCLE


func defence() -> EnemyDefence:
	return _defence


## 25% (Grunt) to roll away instead of standing up after a knockdown.
func roll_getup_roll() -> bool:
	var chance: float = float((_beh.get("reactions", {}) as Dictionary).get("getup_roll_chance", 0.0))
	return chance > 0.0 and _rng.randf() < chance


## The body tells the brain how long the wind-up it just started really is (the feel knob and the minimum
## are already applied), so the aim can lock at least `min_aim_lock_before_impact_ms` before impact.
func set_attack_timing(effective_impact_ms: float, scale: float) -> void:
	_track_ms_eff = EnemyRules.aim_lock_ms(float(_chosen.get("track_ms", 300.0)) * scale, effective_impact_ms, _rules)


func chosen_move() -> StringName:
	return StringName(str(_chosen.get("move", "")))


# ---- stepping ----

func step(now_ms: float, view: Dictionary) -> Dictionary:
	_now_ms = now_ms
	_knobs = view.get("knobs", {})
	if not _started:
		_started = true
		_since_ms = now_ms
		_next_attack_ms = now_ms + _interval_ms()
	var body: StringName = view.get("state", FREE)
	if body == &"dead":
		_enter(DEAD)
	if _state == DEAD:
		return _intent(Vector3.ZERO, false, false, &"")
	var dist: float = float(view.get("dist_to_player", 999.0))
	var has_token: bool = bool(view.get("has_token", false))
	var attacks_enabled: bool = bool(view.get("attacks_enabled", true))
	_watch_swing(view)
	if _roll_at_ms >= 0.0 and now_ms >= _roll_at_ms:
		_roll_at_ms = -1.0
		var defended: Dictionary = _try_defend(view, dist)
		if not defended.is_empty():
			return defended
	match _state:
		IDLE:
			if dist <= float(_brain.get("notice_range_m", 14.0)):
				_enter(NOTICE)
			return _intent(Vector3.ZERO, false, false, &"")
		NOTICE:
			var need: float = _notice_ms_override if _notice_ms_override >= 0.0 else float(_brain.get("notice_ms", 450.0))
			if now_ms - _since_ms >= need:
				_notice_ms_override = -1.0
				_enter(APPROACH)
			return _intent(Vector3.ZERO, true, false, &"", {"gait": &"notice"})
		APPROACH:
			if dist <= float(_brain.get("circle_range_m", 4.5)):
				_enter_circle()
			return _intent(Vector3(0, 0, 1), true, false, &"", {"gait": &"approach", "speed_mult": _speed_mult()})
		CIRCLE, REPOSITION:
			if _state == REPOSITION and _repo_kind == KIND_RETREAT:
				return _step_retreat(now_ms, view)
			return _step_circle(now_ms, view, dist, has_token, attacks_enabled)
		ATTACK:
			var track_ms: float = _track_ms_eff if _track_ms_eff >= 0.0 else float(_chosen.get("track_ms", 300.0))
			if now_ms - _since_ms > ATTACK_SAFETY_MS:
				_enter(RECOVER)
			return _intent(Vector3.ZERO, now_ms - _since_ms < track_ms, has_token, &"")
		RECOVER:
			if now_ms - _since_ms >= float(_brain.get("recover_ms", 450.0)):
				if _try_hit_and_fade(now_ms):
					return _step_retreat(now_ms, view)
				_enter_circle()
			return _intent(Vector3.ZERO, true, false, &"")
		REACT:
			if body == FREE:
				if _react_free_since_ms < 0.0:
					_react_free_since_ms = now_ms
					var escape: Dictionary = _try_combo_escape(view, dist)
					if not escape.is_empty():
						return escape
				if now_ms - _react_free_since_ms >= _react_hold_ms:
					if dist <= float(_brain.get("circle_range_m", 4.5)):
						_enter_circle()
					else:
						_enter(APPROACH)
			else:
				_react_free_since_ms = -1.0
			return _intent(Vector3.ZERO, false, false, &"")
		DEFEND:
			return _step_defend(now_ms, view, dist)
		FLEE:
			return _step_flee(now_ms, view, dist, has_token, attacks_enabled)
		FLANK:
			return _step_flank(now_ms, view, dist, has_token, attacks_enabled)
		ENRAGE:
			return _step_enrage(now_ms)
	return _intent(Vector3.ZERO, false, false, &"")


## Something happened to the body. Hits, launches, parries and staggers all send the brain to `react`
## (it waits until the body is free again plus a short pause); a finished move sends it to `recover`.
func notify(event: StringName) -> void:
	if _state == DEAD:
		return
	match event:
		&"hit", &"launched", &"parried", &"staggered", &"guard_broken":
			if _state == ENRAGE:
				_enraged = true          # the roar was cut short; he is enraged all the same
			if event == &"hit" or event == &"staggered":
				_note_hit()
			if event == &"hit":
				_retaliate_since_ms = _now_ms
			_chain_next = false
			_react_hold_ms = float(_brain.get("react_ms", 250.0))
			_enter(REACT)
		&"landed":
			_react_hold_ms = float(_brain.get("land_react_ms", 300.0))
			_chain_next = false
			if _state != REACT:
				_enter(REACT)
		&"move_finished":
			if _state == ATTACK:
				if _chain_next:
					# the Brute's second slam: no pause, he keeps the token
					_chain_followup = true
					_enter_circle()
					_next_attack_ms = _now_ms
				else:
					_enter(RECOVER)
			elif _state == ENRAGE:
				_enraged = true
				_enter_circle()
		&"attack_denied":
			if _state == ATTACK:
				_state = _return_state if _return_state != ATTACK else CIRCLE
				_since_ms = _now_ms
				_attack_retry_ms = _now_ms + ATTACK_RETRY_MS
				_chain_next = false
		&"defence_finished":
			if _state == DEFEND:
				_finish_defence()
		&"blocked":
			if _state == DEFEND and _defend_kind == EnemyDefence.KIND_BLOCK:
				_blocks_in_hold += 1
				_last_threat_ms = _now_ms
		&"armored_hit":
			_retaliate_since_ms = _now_ms
		&"ally_alert", &"ally_died":
			if event == &"ally_died":
				_ally_deaths.append(_now_ms)
			var alert: Dictionary = _beh.get("alert", {})
			if not alert.is_empty() and _state == IDLE:
				_notice_ms_override = float(alert.get("ally_notice_ms", 150.0))
				_enter(NOTICE)
			elif not alert.is_empty() and _state == NOTICE:
				var left: float = float(alert.get("ally_notice_ms", 150.0))
				_notice_ms_override = minf(_notice_ms_override if _notice_ms_override >= 0.0 else float(_brain.get("notice_ms", 450.0)), left)
		&"step_up":
			# Red moved on from an ally: the nearest waiting enemy takes over as the next attacker
			if _state == CIRCLE or _state == REPOSITION:
				var soon: float = _now_ms + float((_beh.get("alert", {}) as Dictionary).get("step_up_ms", 900.0))
				_next_attack_ms = minf(_next_attack_ms, soon)
		&"token_granted":
			pass


# ---- circle, spacing and the attack ----

func _step_circle(now_ms: float, view: Dictionary, dist: float, has_token: bool, attacks_enabled: bool) -> Dictionary:
	var low: Dictionary = _check_low_health(now_ms, view, attacks_enabled)
	if not low.is_empty():
		return low
	var ring: Vector2 = _ring()
	var speed: float = float(_brain.get("circle_speed_mult", 0.55))
	# crowded, or Red is busy with another enemy: stand further out (the "reposition: back off" state)
	var extra: float = _back_off_extra(view, has_token, now_ms)
	if extra > 0.0:
		if _state != REPOSITION:
			_state = REPOSITION
			_since_ms = now_ms
			_repo_kind = KIND_BACK_OFF
		ring += Vector2(extra, extra)
	elif _state == REPOSITION:
		_state = CIRCLE
		_since_ms = now_ms
	if not has_token and _try_keep_away(now_ms, view):
		return _step_retreat(now_ms, view)
	if now_ms >= _flip_at_ms:
		_circle_sign = -_circle_sign
		_flip_at_ms = now_ms + _range_ms("circle_flip_ms")
	_consume_retaliation(now_ms, dist)
	var want_token: bool = false
	if attacks_enabled and now_ms >= _next_attack_ms:
		want_token = true
		if _token_wait_since_ms < 0.0:
			_token_wait_since_ms = now_ms
		if has_token:
			if now_ms < _attack_retry_ms:
				return _intent(Vector3.ZERO, true, true, &"", {"gait": &"walk"})
			var pick: Dictionary = _pick_attack(dist, bool(view.get("player_airborne", false)), bool(view.get("in_rear_arc", false)))
			if not pick.is_empty():
				return _begin_attack(pick, CIRCLE)
			# Holding a token but out of reach: close in.
			var reach: float = _shortest_reach()
			if now_ms - _token_wait_since_ms > TOKEN_PATIENCE_MS:
				_token_wait_since_ms = -1.0
				_next_attack_ms = now_ms + _interval_ms()
				return _intent(Vector3.ZERO, true, false, &"")
			return _intent(Vector3(0.0, 0.0, 1.0 if dist > reach else 0.0), true, true, &"", {"gait": &"approach", "speed_mult": _speed_mult()})
		if now_ms - _token_wait_since_ms > TOKEN_PATIENCE_MS:
			_token_wait_since_ms = -1.0
			_next_attack_ms = now_ms + _interval_ms()
	else:
		_token_wait_since_ms = -1.0
	var z: float = 0.0
	if dist > ring.y + 0.5:
		z = 1.0
	elif dist < ring.x:
		z = -0.6
	var side: float = _circle_sign * speed
	var push: float = _separation_push(view)
	if absf(push) > 0.05:
		side = clampf(push, -1.0, 1.0) * maxf(speed, 0.5)
		_circle_sign = signf(push)
	return _intent(Vector3(side, 0.0, z), true, want_token, &"", {"gait": &"strafe", "speed_mult": _speed_mult()})


## The ring a waiting enemy keeps round Red: [near, far] metres, scaled by the spacing knob. Without a
## `behaviour.reposition` block it is the original circle_range_m / min_range_m.
func _ring() -> Vector2:
	var spacing: float = float(_knobs.get("enemy_spacing_scale", 1.0))
	var repo: Dictionary = _beh.get("reposition", {})
	var ring_m: Array = repo.get("ring_m", [])
	if ring_m.size() >= 2:
		return Vector2(float(ring_m[0]), float(ring_m[1])) * spacing
	return Vector2(float(_brain.get("min_range_m", 2.2)), float(_brain.get("circle_range_m", 4.5))) * spacing


## How much further out to stand: 1.2 m when crowded, or when Red is stringing hits on someone else.
func _back_off_extra(view: Dictionary, has_token: bool, now_ms: float) -> float:
	var repo: Dictionary = _beh.get("reposition", {})
	var extra: float = float(repo.get("back_off_extra_m", 0.0))
	if has_token or extra <= 0.0:
		return 0.0
	if int(view.get("crowd_count", 0)) >= int(repo.get("crowd_count", 99)):
		return extra
	if int(view.get("player_combo_len", 0)) >= int(repo.get("back_off_red_combo_len", 99)) and now_ms - _last_hit_ms > STRING_TARGET_MS:
		return extra
	return 0.0


## Sideways push away from neighbours that stand too close (metres) or too near in angle round Red.
func _separation_push(view: Dictionary) -> float:
	var repo: Dictionary = _beh.get("reposition", {})
	var allies: Array = view.get("allies", [])
	if allies.is_empty() or repo.is_empty():
		return 0.0
	var spacing: float = float(_knobs.get("enemy_spacing_scale", 1.0))
	var separation: float = float(repo.get("separation_m", 0.0)) * spacing
	var spread: float = float(repo.get("slot_spread_deg", 0.0))
	var mine: float = float(view.get("my_angle_deg", 0.0))
	var push: float = 0.0
	for entry: Variant in allies:
		var ally: Dictionary = entry
		var gap: float = wrapf(mine - float(ally.get("angle_deg", 0.0)), -180.0, 180.0)
		var near: float = 0.0
		if separation > 0.0 and float(ally.get("dist_m", 99.0)) < separation:
			near = 1.0 - float(ally.get("dist_m", 99.0)) / separation
		elif spread > 0.0 and absf(gap) < spread:
			near = 0.5 * (1.0 - absf(gap) / spread)
		if near > 0.0:
			var away: float = signf(gap) if absf(gap) > 0.5 else _circle_sign
			push += away * near
	return push


func _try_hit_and_fade(now_ms: float) -> bool:
	var repo: Dictionary = _beh.get("reposition", {})
	if repo.is_empty() or float(repo.get("retreat_after_attack_chance", 0.0)) <= 0.0:
		return false
	if _rng.randf() >= float(repo["retreat_after_attack_chance"]):
		return false
	_begin_retreat(now_ms, false)
	return true


func _try_keep_away(now_ms: float, view: Dictionary) -> bool:
	var repo: Dictionary = _beh.get("reposition", {})
	if repo.is_empty() or float(repo.get("keep_away_chance", 0.0)) <= 0.0:
		return false
	if not bool(view.get("player_dashing_toward", false)) or now_ms < _keep_away_next_ms:
		return false
	_keep_away_next_ms = now_ms + float(repo.get("keep_away_cooldown_ms", 3000.0))
	if _rng.randf() >= float(repo["keep_away_chance"]):
		return false
	_begin_retreat(now_ms, true)
	return true


## Back away `retreat_m` metres, facing Red. `keep_timer`: keep the attack timer (keep-away) or start a fresh
## pause (hit and fade after the enemy's own attack).
func _begin_retreat(now_ms: float, keep_timer: bool) -> void:
	var repo: Dictionary = _beh.get("reposition", {})
	var speed: float = float(_gaits.get("retreat", DEFAULT_RETREAT_SPEED))
	_repo_kind = KIND_RETREAT
	_repo_keeps_timer = keep_timer
	_repo_saved_attack_ms = _next_attack_ms
	_repo_until_ms = now_ms + float(repo.get("retreat_m", 2.0)) / maxf(speed, 0.1) * 1000.0
	_enter(REPOSITION)


func _step_retreat(now_ms: float, _view: Dictionary) -> Dictionary:
	if now_ms >= _repo_until_ms:
		_enter_circle()
		if _repo_keeps_timer:
			_next_attack_ms = _repo_saved_attack_ms
		return _intent(Vector3.ZERO, true, false, &"")
	return _intent(Vector3(0.0, 0.0, -1.0), true, false, &"", {"gait": &"retreat", "speed_mps": float(_gaits.get("retreat", DEFAULT_RETREAT_SPEED))})


## Answering a hit: after a flinch (Grunt) or an armored hit (Brute) the enemy may take the next token at once.
func _consume_retaliation(now_ms: float, dist: float) -> void:
	if _retaliate_since_ms < 0.0:
		return
	var since: float = _retaliate_since_ms
	_retaliate_since_ms = -1.0
	var react: Dictionary = _beh.get("reactions", {})
	if react.is_empty() or now_ms - since > RETALIATE_FLAG_MS:
		return
	if now_ms - _last_retaliate_ms < float(react.get("retaliate_cooldown_ms", 3500.0)):
		return
	_last_retaliate_ms = now_ms
	if dist <= float(react.get("retaliate_range_m", 0.0)) and _rng.randf() < float(react.get("retaliate_chance", 0.0)):
		_start_counter(now_ms)


func _start_counter(now_ms: float) -> void:
	_counter_until_ms = now_ms + 2500.0
	_next_attack_ms = now_ms


func _begin_attack(pick: Dictionary, return_state: StringName) -> Dictionary:
	_chosen = pick
	_return_state = return_state
	_track_ms_eff = -1.0
	_chain_next = false
	var extra: Dictionary = {}
	var enrage: Dictionary = _enrage_cfg()
	if _chain_followup:
		_chain_followup = false          # the second slam of a chain never chains again
	elif _enraged and float(enrage.get("chain_slam_chance", 0.0)) > 0.0 and _rng.randf() < float(enrage["chain_slam_chance"]):
		_chain_next = true
		extra["chain_recover_ms"] = float(enrage.get("chain_recover_ms", 350.0))
	if bool(pick.get("flank", false)):
		extra["flank"] = true
	_enter(ATTACK)
	return _intent(Vector3.ZERO, true, true, StringName(str(pick["move"])), extra)


func _pick_attack(dist: float, player_airborne: bool, rear: bool = false) -> Dictionary:
	var options: Array[Dictionary] = []
	var total: float = 0.0
	for entry: Variant in _attacks:
		var attack: Dictionary = entry
		var when: Dictionary = attack.get("when", {})
		if dist > float(when.get("max_dist_m", 999.0)):
			continue
		if when.has("player_airborne") and bool(when["player_airborne"]) != player_airborne:
			continue
		options.append(attack)
		total += maxf(float(attack.get("weight", 1.0)), 0.0)
	if options.is_empty() or total <= 0.0:
		return {}
	var roll: float = _rng.randf() * total
	var picked: Dictionary = options.back()
	for attack: Dictionary in options:
		roll -= maxf(float(attack.get("weight", 1.0)), 0.0)
		if roll <= 0.0:
			picked = attack
			break
	# From behind Red a wind-up must be longer (650 ms): use the rear move (the Grunt's swipe_flank)
	var rear_move: String = str(_beh.get("rear_move", ""))
	if rear and rear_move != "" and str(picked.get("move", "")) != rear_move:
		picked = picked.duplicate(true)
		picked["move"] = rear_move
		picked["track_ms"] = float((_low_cfg().get("flank", {}) as Dictionary).get("track_ms", picked.get("track_ms", 300.0)))
	return picked


func _shortest_reach() -> float:
	var best: float = 999.0
	for entry: Variant in _attacks:
		best = minf(best, float(((entry as Dictionary).get("when", {}) as Dictionary).get("max_dist_m", 999.0)))
	return best * 0.9


# ---- the defence roll ----

func _watch_swing(view: Dictionary) -> void:
	var swing: int = int(view.get("player_swing_id", 0))
	if swing == 0 or swing == _seen_swing:
		return
	_seen_swing = swing
	_roll_at_ms = -1.0
	if not _defence.configured():
		return
	var move_class: StringName = StringName(str(view.get("player_move_class", "")))
	if bool(view.get("player_swing_threat", false)) and move_class != EnemyRules.CLASS_NONE:
		_roll_class = move_class
		_roll_swing = swing
		_roll_at_ms = _now_ms + _defence.reaction_ms(float(_knobs.get("enemy_reaction_scale", 1.0)))


func _can_defend(view: Dictionary) -> bool:
	if not _defence.configured() or StringName(str(view.get("state", FREE))) != FREE:
		return false
	if _state != APPROACH and _state != CIRCLE and _state != REPOSITION and _state != FLANK:
		return false
	if bool(view.get("flare", false)) and bool((_beh.get("defend", {}) as Dictionary).get("no_defence_in_flare", true)):
		return false
	return true


func _try_defend(view: Dictionary, dist: float) -> Dictionary:
	if not _can_defend(view) or int(view.get("player_swing_id", 0)) != _roll_swing:
		return {}
	if not bool(view.get("player_swing_active", true)):
		return {}
	var kind: StringName = _defence.roll(_roll_class, _now_ms, float(_knobs.get("enemy_dodge_scale", 1.0)),
			float(_knobs.get("enemy_block_scale", 1.0)), _block_mult())
	if kind == EnemyDefence.KIND_NONE:
		return {}
	return _begin_defend(kind, view, dist)


func _try_combo_escape(view: Dictionary, dist: float) -> Dictionary:
	var escape: Dictionary = _defence.combo_escape()
	if escape.is_empty() or str(escape.get("move", "dodge")) != "dodge":
		return {}
	if _last_hit_ms <= _escape_checked_hit_ms:
		return {}
	_escape_checked_hit_ms = _last_hit_ms
	if _recent_hits(float(escape.get("window_ms", 0.0))) < int(escape.get("after_hits", 99)):
		return {}
	if float(_knobs.get("enemy_dodge_scale", 1.0)) <= 0.0 or not _defence.ready(EnemyDefence.KIND_DODGE, _now_ms):
		return {}
	if bool(view.get("flare", false)) or _rng.randf() >= float(escape.get("chance", 0.0)):
		return {}
	_defence.add_fatigue(_now_ms)
	return _begin_defend(EnemyDefence.KIND_DODGE, view, dist)


func _begin_defend(kind: StringName, view: Dictionary, dist: float) -> Dictionary:
	_defend_kind = kind
	_defend_sent = false
	_defend_sign = 1.0 if _rng.randf() < 0.5 else -1.0
	_defend_variant = _defence.dodge_variant(dist) if kind == EnemyDefence.KIND_DODGE else &"side"
	_blocks_in_hold = 0
	_guard_up = kind == EnemyDefence.KIND_BLOCK
	_last_threat_ms = _now_ms
	var guard: Dictionary = _beh.get("guard", {})
	var hold: Variant = guard.get("hold_ms", [350, 550])
	_hold_min_ms = float((hold as Array)[0]) if hold is Array and (hold as Array).size() > 0 else 350.0
	_hold_max_ms = float((hold as Array)[1]) if hold is Array and (hold as Array).size() > 1 else _hold_min_ms
	_enter(DEFEND)
	return _step_defend(_now_ms, view, dist)


func _step_defend(now_ms: float, view: Dictionary, _dist: float) -> Dictionary:
	var elapsed: float = now_ms - _since_ms
	if elapsed > DEFEND_SAFETY_MS:
		_finish_defence()
		return _intent(Vector3.ZERO, true, false, &"")
	var extra: Dictionary = {}
	if not _defend_sent:
		_defend_sent = true
		extra["defend"] = {"kind": _defend_kind, "variant": _defend_variant, "sign": _defend_sign}
	if _defend_kind == EnemyDefence.KIND_BLOCK:
		if bool(view.get("player_swing_threat", false)) and bool(view.get("player_swing_active", true)):
			_last_threat_ms = now_ms
		if _guard_up:
			var max_blocks: int = int((_beh.get("guard", {}) as Dictionary).get("max_in_row", 99))
			var drop_after: float = float((_beh.get("guard", {}) as Dictionary).get("drop_after_threat_ms", 300.0))
			if _blocks_in_hold >= max_blocks or elapsed >= _hold_max_ms \
					or (elapsed >= _hold_min_ms and now_ms - _last_threat_ms >= drop_after):
				_guard_up = false
		extra["guard"] = _guard_up
	return _intent(Vector3.ZERO, true, false, &"", extra)


func _finish_defence() -> void:
	var kind: StringName = _defend_kind
	var blocked: int = _blocks_in_hold
	_enter_circle()
	var counter_chance: float = 0.0
	if kind == EnemyDefence.KIND_DODGE:
		counter_chance = float(_defence.dodge_cfg().get("counter_chance", 0.0))
	elif kind == EnemyDefence.KIND_BLOCK and blocked > 0:
		counter_chance = float((_beh.get("guard", {}) as Dictionary).get("counter_chance", 0.0))
	if counter_chance > 0.0 and _rng.randf() < counter_chance:
		_start_counter(_now_ms)


func _block_mult() -> float:
	if _enraged:
		return float(_enrage_cfg().get("block_chance_mult", 1.0))
	return 1.0


# ---- low health ----

func _low_cfg() -> Dictionary:
	return _beh.get("low_health", {})


func _enrage_cfg() -> Dictionary:
	return (_low_cfg().get("enrage", {}) as Dictionary)


## Morale: allies that died in the last few seconds raise the hp threshold (Grunt).
func _morale_bonus(now_ms: float) -> float:
	var alert: Dictionary = _beh.get("alert", {})
	var window_ms: float = float(alert.get("morale_window_s", 6.0)) * 1000.0
	var count: int = 0
	for at: float in _ally_deaths:
		if now_ms - at <= window_ms:
			count += 1
	return minf(float(count) * float(alert.get("ally_down_morale_hit", 0.0)), float(alert.get("morale_max_bonus", 0.0)))


func _check_low_health(now_ms: float, view: Dictionary, attacks_enabled: bool) -> Dictionary:
	var low: Dictionary = _low_cfg()
	if low.is_empty():
		return {}
	var hp_frac: float = float(view.get("hp_frac", 1.0))
	var mode: String = str(low.get("mode", ""))
	if mode == "enrage":
		if _enraged_once or hp_frac >= float(low.get("threshold_frac", 0.0)) or not bool(_knobs.get("enemy_enrage_on", true)):
			return {}
		_enraged_once = true
		_roar_sent = false
		_enter(ENRAGE)
		return _step_enrage(now_ms)
	if mode != "flee_or_flank":
		return {}
	if hp_frac >= float(low.get("threshold_frac", 0.0)) + _morale_bonus(now_ms) or now_ms < _lowhp_cd_until_ms:
		return {}
	var flee_cfg: Dictionary = low.get("flee", {})
	var flank_cfg: Dictionary = low.get("flank", {})
	var pack: bool = int(view.get("allies_near", 0)) >= 2
	var flee_p: float = float(low.get("flee_chance_pack" if pack else "flee_chance_alone", 0.5))
	var can_flee: bool = bool(_knobs.get("enemy_flee_on", true)) and not flee_cfg.is_empty() \
			and _flees_used < int(flee_cfg.get("max_per_life", 2)) and now_ms >= _bold_until_ms
	var can_flank: bool = bool(_knobs.get("enemy_flank_on", true)) and not flank_cfg.is_empty() and attacks_enabled \
			and int(view.get("flankers_other", 0)) < int(flank_cfg.get("max_flankers", 1))
	var want_flee: bool = _rng.randf() < flee_p
	if want_flee and can_flee:
		return _begin_flee(now_ms, flee_cfg)
	if can_flank and (not want_flee or not can_flee):
		return _begin_flank(now_ms, view)
	if can_flee and not want_flee:
		return _begin_flee(now_ms, flee_cfg)
	_lowhp_cd_until_ms = now_ms + 3000.0       # nothing allowed right now: fight on, ask again soon
	return {}


func _begin_flee(now_ms: float, _cfg: Dictionary) -> Dictionary:
	_flees_used += 1
	_cornered_since_ms = -1.0
	_enter(FLEE)
	return _step_flee(now_ms, {}, 0.0, false, false)


func _step_flee(now_ms: float, view: Dictionary, dist: float, has_token: bool, attacks_enabled: bool) -> Dictionary:
	var cfg: Dictionary = _low_cfg().get("flee", {})
	if now_ms > _since_ms and view.has("dist_to_player"):
		if dist >= float(cfg.get("until_dist_m", 9.0)) or now_ms - _since_ms >= float(cfg.get("max_ms", 3500.0)):
			_enter_circle()
			return _intent(Vector3.ZERO, true, false, &"")
	# cornered against a wall: after a moment it turns and swipes (full wind-up, needs a token)
	if bool(view.get("cornered", false)):
		if _cornered_since_ms < 0.0:
			_cornered_since_ms = now_ms
	else:
		_cornered_since_ms = -1.0
	if _cornered_since_ms >= 0.0 and now_ms - _cornered_since_ms >= float(cfg.get("cornered_after_ms", 600.0)) and attacks_enabled:
		var move: String = str(cfg.get("cornered_move", "swipe"))
		if has_token:
			return _begin_attack({"move": move, "track_ms": _track_of(move, 380.0)}, FLEE)
		return _intent(Vector3.ZERO, true, true, &"", {"gait": &"walk"})
	return _intent(Vector3(0.0, 0.0, -1.0), false, false, &"", {"gait": &"flee", "speed_mps": float(cfg.get("speed_mps", 4.6)), "face_move": true})


func _track_of(move: String, fallback: float) -> float:
	for entry: Variant in _attacks:
		if str((entry as Dictionary).get("move", "")) == move:
			return float((entry as Dictionary).get("track_ms", fallback))
	return fallback


func _begin_flank(now_ms: float, view: Dictionary) -> Dictionary:
	_flank_since_ms = now_ms
	_flank_hold_since_ms = -1.0
	_flank_ready = false
	var mine: float = float(view.get("my_angle_deg", 0.0))
	_flank_side = signf(mine) if absf(mine) > 1.0 else _circle_sign
	_enter(FLANK)
	return _step_flank(now_ms, view, float(view.get("dist_to_player", 4.0)), false, true)


func _step_flank(now_ms: float, view: Dictionary, dist: float, has_token: bool, attacks_enabled: bool) -> Dictionary:
	var cfg: Dictionary = _low_cfg().get("flank", {})
	var committed: bool = _flank_ready and has_token
	if not attacks_enabled or (not committed and now_ms - _flank_since_ms >= float(cfg.get("max_ms", 3500.0))):
		_enter_circle()
		return _intent(Vector3.ZERO, true, false, &"")
	var arc: Array = cfg.get("arc_deg", [135.0, 225.0])
	var arc_min: float = float(arc[0])
	var arc_max: float = minf(float(arc[1]), 360.0 - arc_min)
	var target_abs: float = (arc_min + arc_max) * 0.5
	var radius: float = float(cfg.get("radius_m", 3.6))
	var angle: float = float(view.get("my_angle_deg", 0.0))
	var speed_mult: float = float(cfg.get("speed_mult", 1.3))
	# With the token in hand it closes in from behind to striking range, then swings (the wind-up is 710 ms).
	if committed:
		if dist > _shortest_reach() and now_ms - _flank_hold_since_ms < 8000.0:
			return _intent(Vector3(0.0, 0.0, 1.0), true, true, &"", {"gait": &"stalk", "speed_mult": speed_mult, "flank": true})
		if now_ms >= _attack_retry_ms:
			return _begin_attack({"move": str(cfg.get("move", "swipe_flank")), "track_ms": float(cfg.get("track_ms", 480.0)), "flank": true}, FLANK)
		return _intent(Vector3.ZERO, true, true, &"", {"gait": &"stalk", "flank": true})
	var error: float = wrapf(_flank_side * target_abs - angle, -180.0, 180.0)
	var in_position: bool = absf(angle) >= arc_min and absf(dist - radius) < 0.9
	if in_position:
		if _flank_hold_since_ms < 0.0:
			_flank_hold_since_ms = now_ms
		_flank_ready = now_ms - _flank_hold_since_ms >= float(cfg.get("hold_ms", 600.0))
		return _intent(Vector3(0.0, 0.0, clampf(dist - radius, -0.5, 0.5)), true, _flank_ready, &"",
				{"gait": &"stalk", "speed_mult": speed_mult, "flank": true})
	_flank_hold_since_ms = -1.0
	_flank_ready = false
	var side: float = clampf(error / 40.0, -1.0, 1.0)
	var radial: float = clampf((dist - radius) * 1.2, -1.0, 1.0)
	return _intent(Vector3(side, 0.0, radial), true, false, &"", {"gait": &"stalk", "speed_mult": speed_mult, "flank": true})


func _step_enrage(now_ms: float) -> Dictionary:
	if now_ms - _since_ms > ROAR_SAFETY_MS:
		_enraged = true
		_enter_circle()
		return _intent(Vector3.ZERO, true, false, &"")
	var extra: Dictionary = {}
	var start: StringName = &""
	if not _roar_sent:
		_roar_sent = true
		start = StringName(str(_enrage_cfg().get("move", "enrage")))
	return _intent(Vector3.ZERO, true, false, start, extra)


func _speed_mult() -> float:
	return float(_enrage_cfg().get("speed_mult", 1.0)) if _enraged else 1.0


# ---- helpers ----

func _note_hit() -> void:
	_last_hit_ms = _now_ms
	_hit_times.append(_now_ms)
	while _hit_times.size() > 12:
		_hit_times.pop_front()


func _recent_hits(window_ms: float) -> int:
	var count: int = 0
	for at: float in _hit_times:
		if _now_ms - at <= window_ms:
			count += 1
	return count


func _enter(next: StringName) -> void:
	if _state != next:
		if _state == DEFEND:
			_defence.end_defence(_defend_kind, _now_ms)
		elif _state == FLEE:
			_bold_until_ms = _now_ms + float((_low_cfg().get("flee", {}) as Dictionary).get("bold_after_ms", 6000.0))
			_lowhp_cd_until_ms = maxf(_lowhp_cd_until_ms, _bold_until_ms)
		elif _state == FLANK:
			_lowhp_cd_until_ms = maxf(_lowhp_cd_until_ms, _now_ms + float((_low_cfg().get("flee", {}) as Dictionary).get("bold_after_ms", 6000.0)))
	_state = next
	_since_ms = _now_ms
	_react_free_since_ms = -1.0


func _enter_circle() -> void:
	_enter(CIRCLE)
	_next_attack_ms = _now_ms + _interval_ms()
	_flip_at_ms = _now_ms + _range_ms("circle_flip_ms")
	_token_wait_since_ms = -1.0


## The pause between attacks: the data range, shorter with the aggression knob and when enraged.
func _interval_ms() -> float:
	var aggression: float = maxf(float(_knobs.get("enemy_aggression", 1.0)), 0.05)
	var mult: float = float(_enrage_cfg().get("attack_interval_mult", 1.0)) if _enraged else 1.0
	return _range_ms("attack_interval_ms") * mult / aggression


func _range_ms(key: String) -> float:
	var range_ms: Array = _brain.get(key, [1000.0, 2000.0])
	if range_ms.size() < 2:
		return float(range_ms[0]) if range_ms.size() == 1 else 1000.0
	return _rng.randf_range(float(range_ms[0]), float(range_ms[1]))


func _intent(move_dir: Vector3, face: bool, want_token: bool, start_move: StringName, extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"move_dir": move_dir, "face_player": face, "want_token": want_token, "start_move": start_move, "state": _state,
			"defend": {}, "guard": false, "gait": &"idle", "speed_mps": 0.0, "speed_mult": 1.0, "flank": false,
			"chain_recover_ms": 0.0, "face_move": false}
	if not extra.is_empty():
		out.merge(extra, true)
	return out
