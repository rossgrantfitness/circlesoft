class_name CombatClock
extends BattleClock
## One fighter's own clock. It advances by real time times that fighter's scale, so it stands still in
## hit-stop and runs slow in a Lamp Flare. Everything a fighter does (its MoveRunner, input buffer, brain,
## AI timers) reads this clock, which is why a freeze or slow-mo can never shift a timing window.
##
## The clock also remembers where it has been, so a press stamped in real time by `_input` (say 9 ms ago)
## can be turned into this clock's time with local_at_real(), even if the scale changed since.

const MAX_SEGMENTS: int = 600
const USEC_PER_MS: float = 1000.0

var _local_usec: int = 0
var _real_usec: int = 0
var _scale: float = 1.0
var _frac: float = 0.0
## Parallel arrays: a segment starts at real_starts[i] / local_starts[i] and runs at scales[i].
var _real_starts: PackedInt64Array = PackedInt64Array()
var _local_starts: PackedInt64Array = PackedInt64Array()
var _scales: PackedFloat64Array = PackedFloat64Array()


func _init(start_real_usec: int = 0, start_local_usec: int = 0) -> void:
	_real_usec = start_real_usec
	_local_usec = start_local_usec


## Advance by a real step. scale 0 = frozen, 1 = normal, 0.25 = quarter speed.
func step(real_delta_usec: int, scale: float) -> void:
	var s: float = maxf(scale, 0.0)
	var real_delta: int = maxi(real_delta_usec, 0)
	_real_starts.append(_real_usec)
	_local_starts.append(_local_usec)
	_scales.append(s)
	if _real_starts.size() > MAX_SEGMENTS:
		_real_starts = _real_starts.slice(1)
		_local_starts = _local_starts.slice(1)
		_scales = _scales.slice(1)
	var exact: float = float(real_delta) * s + _frac
	var whole: int = int(floorf(exact))
	_frac = exact - float(whole)
	_local_usec += whole
	_real_usec += real_delta
	_scale = s


func now_usec() -> int:
	return _local_usec


func now_ms() -> float:
	return float(_local_usec) / USEC_PER_MS


## The scale used by the latest step.
func scale() -> float:
	return _scale


## The real-time axis this clock has reached (same axis as `Time.get_ticks_usec()` once anchored).
func real_now_usec() -> int:
	return _real_usec


## Pin the real-time axis to the engine clock, e.g. anchor_real(Time.get_ticks_usec()). Forgets history.
func anchor_real(real_usec: int) -> void:
	_real_usec = real_usec
	_real_starts = PackedInt64Array()
	_local_starts = PackedInt64Array()
	_scales = PackedFloat64Array()


## Nudge the real axis to the engine clock after a step (the director does this every tick so a press
## stamped by `_input` lines up). Local time is not changed.
func sync_real(real_usec: int) -> void:
	if real_usec > _real_usec:
		_real_usec = real_usec


## Turns a real timestamp into this clock's time. Works for the recent past (through freezes and slow-mo)
## and, for a stamp newer than the last step, carries on at the current scale.
func local_at_real(real_usec: int) -> int:
	if real_usec >= _real_usec:
		return _local_usec + int(roundf(float(real_usec - _real_usec) * _scale))
	var index: int = _real_starts.size() - 1
	while index > 0 and _real_starts[index] > real_usec:
		index -= 1
	if index < 0:
		return _local_usec + int(roundf(float(real_usec - _real_usec) * _scale))
	var seg_scale: float = _scales[index]
	var local: int = _local_starts[index] + int(roundf(float(real_usec - _real_starts[index]) * seg_scale))
	var upper: int = _local_starts[index + 1] if index + 1 < _local_starts.size() else _local_usec
	return clampi(local, _local_starts[index], upper)


func poll_usec() -> int:
	return DEFAULT_POLL_USEC
