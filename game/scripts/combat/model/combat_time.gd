class_name CombatTime
extends RefCounted
## The rules of time for a fight (contract 4.1), as numbers only. The director owns one.
##  - A fighter in hit-stop has scale 0. Hit-stop counts down in REAL time. Several hits at once freeze
##    for the longest one, not the sum.
##  - In a Lamp Flare the enemies caught in the glare run at flare_enemy_speed. Red runs at full speed.
##  - The flare's own timer runs on Red's clock: it pauses while Red is in hit-stop.
## Nothing here touches Engine.time_scale.

signal flare_started
signal flare_ended

## Whose clock the flare timer follows.
var player_id: StringName = &"red"

var _hit_stop_left: Dictionary = {}     # id -> seconds of real time left
var _run_fraction: Dictionary = {}      # id -> share of the latest step the fighter was NOT frozen
var _flare_left_s: float = 0.0
var _flare_scale: float = 1.0
var _flare_ids: Dictionary = {}         # id -> true
var _flaring: bool = false


## Advance by one real step (seconds).
func step(real_delta_s: float) -> void:
	var delta: float = maxf(real_delta_s, 0.0)
	_run_fraction.clear()
	for id: Variant in _hit_stop_left.keys():
		var left: float = _hit_stop_left[id]
		var frac: float = 0.0
		if delta > 0.0:
			frac = clampf((delta - left) / delta, 0.0, 1.0)
		_run_fraction[id] = frac
		left -= delta
		if left <= 0.0:
			_hit_stop_left.erase(id)
		else:
			_hit_stop_left[id] = left
	if _flaring:
		_flare_left_s -= delta * float(_run_fraction.get(player_id, 1.0))
		if _flare_left_s <= 0.0:
			_end_flare()


## Freeze these fighters for `ms` (real time). A longer freeze already running wins.
func add_hit_stop(ids: Array[StringName], ms: float) -> void:
	if ms <= 0.0:
		return
	var seconds: float = ms / 1000.0
	for id: StringName in ids:
		_hit_stop_left[id] = maxf(float(_hit_stop_left.get(id, 0.0)), seconds)


func hit_stop_left_ms(id: StringName) -> float:
	return float(_hit_stop_left.get(id, 0.0)) * 1000.0


func is_frozen(id: StringName) -> bool:
	return _hit_stop_left.has(id)


## Start (or restart) a flare: the listed fighters run at enemy_scale for duration_s of Red's time.
func start_flare(duration_s: float, enemy_scale: float, slowed_ids: Array[StringName]) -> void:
	_flare_left_s = maxf(duration_s, 0.0)
	_flare_scale = clampf(enemy_scale, 0.0, 1.0)
	_flare_ids.clear()
	for id: StringName in slowed_ids:
		_flare_ids[id] = true
	var was: bool = _flaring
	_flaring = _flare_left_s > 0.0
	if _flaring and not was:
		flare_started.emit()


func end_flare() -> void:
	if _flaring:
		_end_flare()


func is_flaring() -> bool:
	return _flaring


func flare_left_s() -> float:
	return maxf(_flare_left_s, 0.0) if _flaring else 0.0


func flare_enemy_scale() -> float:
	return _flare_scale if _flaring else 1.0


func is_slowed(id: StringName) -> bool:
	return _flaring and _flare_ids.has(id)


## The speed of a fighter right now: 0 in hit-stop, the flare speed if caught in the glare, else 1.
func scale_for(actor_id: StringName) -> float:
	if _hit_stop_left.has(actor_id):
		return 0.0
	if _flaring and _flare_ids.has(actor_id):
		return _flare_scale
	return 1.0


## How much of `real_delta` (seconds) this fighter actually lives through in the latest step. Counts the
## part of the step after a hit-stop ended, so total frozen time is exactly the hit-stop asked for.
func delta_for(actor_id: StringName, real_delta: float) -> float:
	var frac: float = float(_run_fraction.get(actor_id, 1.0))
	var flare_scale: float = _flare_scale if (_flaring and _flare_ids.has(actor_id)) else 1.0
	return real_delta * frac * flare_scale


## The scale to hand a CombatClock for this step (delta_for / real_delta, safe at zero).
func step_scale_for(actor_id: StringName, real_delta: float) -> float:
	if real_delta <= 0.0:
		return scale_for(actor_id)
	return delta_for(actor_id, real_delta) / real_delta


func _end_flare() -> void:
	_flaring = false
	_flare_left_s = 0.0
	_flare_ids.clear()
	_flare_scale = 1.0
	flare_ended.emit()
