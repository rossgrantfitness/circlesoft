class_name LightsOn
extends RefCounted
## Lights On (sandbox stub, contract 4.5): when the Noise meter is full, Red powers up for a while.
## While it runs the meter drains smoothly to empty, and Red hits harder and cannot be flinched.
## The look (lamp blaze, brighter edge light) belongs to the Technical Artist, driven by `lights_on_changed`.
## Runs on Red's clock.

var _duration_s: float = 12.0
var _damage_mult: float = 1.5
var _super_armor: bool = true
var _meter: StyleMeter = null
var _active: bool = false
var _start_ms: float = 0.0
var _start_points: float = 0.0
var _remaining_s: float = 0.0


static func from_data(style: Dictionary, meter: StyleMeter) -> LightsOn:
	var lights: LightsOn = LightsOn.new()
	var data: Dictionary = style.get("lights_on", {})
	lights._duration_s = maxf(float(data.get("duration_s", 12.0)), 0.1)
	lights._damage_mult = float(data.get("damage_mult", 1.5))
	lights._super_armor = bool(data.get("super_armor", true))
	lights._meter = meter
	return lights


func can_start(meter: StyleMeter = null) -> bool:
	var m: StyleMeter = meter if meter != null else _meter
	return not _active and m != null and m.is_full()


func start(now_ms: float) -> void:
	_active = true
	_start_ms = now_ms
	_remaining_s = _duration_s
	_start_points = _meter.points() if _meter != null else 0.0


## Returns true on the step it ends.
func step(now_ms: float) -> bool:
	if not _active:
		return false
	var elapsed_s: float = maxf(now_ms - _start_ms, 0.0) / 1000.0
	_remaining_s = maxf(_duration_s - elapsed_s, 0.0)
	if _meter != null:
		_meter.set_points(_start_points * (_remaining_s / _duration_s))
	if _remaining_s <= 0.0:
		_active = false
		if _meter != null:
			_meter.reset()
		return true
	return false


func end() -> void:
	if _active:
		_active = false
		_remaining_s = 0.0
		if _meter != null:
			_meter.reset()


func is_active() -> bool:
	return _active


func remaining_s() -> float:
	return _remaining_s if _active else 0.0


func duration_s() -> float:
	return _duration_s


func buffs() -> Dictionary:
	if not _active:
		return {"damage_mult": 1.0, "super_armor": false}
	return {"damage_mult": _damage_mult, "super_armor": _super_armor}
