class_name EnemyBrain
extends RefCounted
## What an enemy decides to do (contract 4.2). Pure: time and a small `view` of the world go in, an intent
## comes out, and a seeded random generator makes every run repeatable. The numbers are the enemy's `brain`
## and `attacks` blocks in enemies.json.
##
## States: idle -> notice -> approach -> circle -> (token) -> attack -> recover -> react -> dead.
## view   = {dist_to_player, player_airborne, player_attacking, has_token, state, poise_frac, attacks_enabled}
##          `state` is what the body is doing: &"free", &"busy" (hit-stun, launched, down, getting up) or &"dead".
## intent = {move_dir, face_player, want_token, start_move, state}
##          `move_dir` is in the PLAYER'S frame: z = toward the player (negative = back off), x = sideways
##          around the player (the body turns it into a world direction), length 0..1 of the walk speed.
## Events: hit, launched, landed, parried, staggered, token_granted, move_finished.

const IDLE: StringName = &"idle"
const NOTICE: StringName = &"notice"
const APPROACH: StringName = &"approach"
const CIRCLE: StringName = &"circle"
const ATTACK: StringName = &"attack"
const RECOVER: StringName = &"recover"
const REACT: StringName = &"react"
const DEAD: StringName = &"dead"
const FREE: StringName = &"free"
const BUSY: StringName = &"busy"
const ATTACK_SAFETY_MS: float = 12000.0
const TOKEN_PATIENCE_MS: float = 3500.0

var _brain: Dictionary = {}
var _attacks: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
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


static func create(data: Dictionary, rng_seed: int) -> EnemyBrain:
	var brain: EnemyBrain = EnemyBrain.new()
	brain._brain = (data.get("brain", {}) as Dictionary).duplicate(true)
	brain._attacks = (data.get("attacks", []) as Array).duplicate(true)
	brain._rng.seed = rng_seed
	brain._circle_sign = 1.0 if brain._rng.randf() < 0.5 else -1.0
	return brain


func state() -> StringName:
	return _state


func step(now_ms: float, view: Dictionary) -> Dictionary:
	_now_ms = now_ms
	if not _started:
		_started = true
		_since_ms = now_ms
		_next_attack_ms = now_ms + _range_ms("attack_interval_ms")
	var body: StringName = view.get("state", FREE)
	if body == &"dead":
		_enter(DEAD)
	if _state == DEAD:
		return _intent(Vector3.ZERO, false, false, &"")
	var dist: float = float(view.get("dist_to_player", 999.0))
	var has_token: bool = bool(view.get("has_token", false))
	var attacks_enabled: bool = bool(view.get("attacks_enabled", true))
	match _state:
		IDLE:
			if dist <= float(_brain.get("notice_range_m", 14.0)):
				_enter(NOTICE)
			return _intent(Vector3.ZERO, false, false, &"")
		NOTICE:
			if now_ms - _since_ms >= float(_brain.get("notice_ms", 450.0)):
				_enter(APPROACH)
			return _intent(Vector3.ZERO, true, false, &"")
		APPROACH:
			if dist <= float(_brain.get("circle_range_m", 4.5)):
				_enter_circle()
			return _intent(Vector3(0, 0, 1), true, false, &"")
		CIRCLE:
			return _step_circle(now_ms, view, dist, has_token, attacks_enabled)
		ATTACK:
			var track_ms: float = float(_chosen.get("track_ms", 300.0))
			if now_ms - _since_ms > ATTACK_SAFETY_MS:
				_enter(RECOVER)
			return _intent(Vector3.ZERO, now_ms - _since_ms < track_ms, has_token, &"")
		RECOVER:
			if now_ms - _since_ms >= float(_brain.get("recover_ms", 450.0)):
				_enter_circle()
			return _intent(Vector3.ZERO, true, false, &"")
		REACT:
			if body == FREE:
				if _react_free_since_ms < 0.0:
					_react_free_since_ms = now_ms
				if now_ms - _react_free_since_ms >= _react_hold_ms:
					if dist <= float(_brain.get("circle_range_m", 4.5)):
						_enter_circle()
					else:
						_enter(APPROACH)
			else:
				_react_free_since_ms = -1.0
			return _intent(Vector3.ZERO, false, false, &"")
	return _intent(Vector3.ZERO, false, false, &"")


## Something happened to the body. Hits, launches, parries and staggers all send the brain to `react`
## (it waits until the body is free again plus a short pause); a finished move sends it to `recover`.
func notify(event: StringName) -> void:
	if _state == DEAD:
		return
	match event:
		&"hit", &"launched", &"parried", &"staggered":
			_react_hold_ms = float(_brain.get("react_ms", 250.0))
			_enter(REACT)
		&"landed":
			_react_hold_ms = float(_brain.get("land_react_ms", 300.0))
			if _state != REACT:
				_enter(REACT)
		&"move_finished":
			if _state == ATTACK:
				_enter(RECOVER)
		&"token_granted":
			pass


func _step_circle(now_ms: float, view: Dictionary, dist: float, has_token: bool, attacks_enabled: bool) -> Dictionary:
	var circle_range: float = float(_brain.get("circle_range_m", 4.5))
	var min_range: float = float(_brain.get("min_range_m", 2.2))
	var speed: float = float(_brain.get("circle_speed_mult", 0.55))
	if now_ms >= _flip_at_ms:
		_circle_sign = -_circle_sign
		_flip_at_ms = now_ms + _range_ms("circle_flip_ms")
	var want_token: bool = false
	var start_move: StringName = &""
	if attacks_enabled and now_ms >= _next_attack_ms:
		want_token = true
		if _token_wait_since_ms < 0.0:
			_token_wait_since_ms = now_ms
		if has_token:
			var pick: Dictionary = _pick_attack(dist, bool(view.get("player_airborne", false)))
			if not pick.is_empty():
				_chosen = pick
				start_move = StringName(str(pick["move"]))
				_enter(ATTACK)
				return _intent(Vector3.ZERO, true, true, start_move)
			# Holding a token but out of reach: close in.
			var reach: float = _shortest_reach()
			if now_ms - _token_wait_since_ms > TOKEN_PATIENCE_MS:
				_token_wait_since_ms = -1.0
				_next_attack_ms = now_ms + _range_ms("attack_interval_ms")
				return _intent(Vector3.ZERO, true, false, &"")
			return _intent(Vector3(0.0, 0.0, 1.0 if dist > reach else 0.0), true, true, &"")
		if now_ms - _token_wait_since_ms > TOKEN_PATIENCE_MS:
			_token_wait_since_ms = -1.0
			_next_attack_ms = now_ms + _range_ms("attack_interval_ms")
	else:
		_token_wait_since_ms = -1.0
	var z: float = 0.0
	if dist > circle_range + 0.5:
		z = 1.0
	elif dist < min_range:
		z = -0.6
	return _intent(Vector3(_circle_sign * speed, 0.0, z), true, want_token, &"")


func _pick_attack(dist: float, player_airborne: bool) -> Dictionary:
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
	for attack: Dictionary in options:
		roll -= maxf(float(attack.get("weight", 1.0)), 0.0)
		if roll <= 0.0:
			return attack
	return options.back()


func _shortest_reach() -> float:
	var best: float = 999.0
	for entry: Variant in _attacks:
		best = minf(best, float(((entry as Dictionary).get("when", {}) as Dictionary).get("max_dist_m", 999.0)))
	return best * 0.9


func _enter(next: StringName) -> void:
	_state = next
	_since_ms = _now_ms
	_react_free_since_ms = -1.0


func _enter_circle() -> void:
	_enter(CIRCLE)
	_next_attack_ms = _now_ms + _range_ms("attack_interval_ms")
	_flip_at_ms = _now_ms + _range_ms("circle_flip_ms")
	_token_wait_since_ms = -1.0


func _range_ms(key: String) -> float:
	var range_ms: Array = _brain.get(key, [1000.0, 2000.0])
	if range_ms.size() < 2:
		return float(range_ms[0]) if range_ms.size() == 1 else 1000.0
	return _rng.randf_range(float(range_ms[0]), float(range_ms[1]))


func _intent(move_dir: Vector3, face: bool, want_token: bool, start_move: StringName) -> Dictionary:
	return {"move_dir": move_dir, "face_player": face, "want_token": want_token, "start_move": start_move, "state": _state}
