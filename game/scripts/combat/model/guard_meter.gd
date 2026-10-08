class_name GuardMeter
extends RefCounted
## An enemy's guard meter (enemy_ai_design section 6). Every blocked hit drains the hit's poise damage;
## it refills after a quiet moment. An empty meter breaks the guard. Pure: time goes in as numbers.

var meter_max: float = 24.0
var meter: float = 24.0
var regen_per_s: float = 12.0
var regen_delay_ms: float = 800.0

var _last_hit_ms: float = -1.0e9


static func from_data(guard: Dictionary) -> GuardMeter:
	var out: GuardMeter = GuardMeter.new()
	out.meter_max = maxf(float(guard.get("meter", 24.0)), 0.0)
	out.meter = out.meter_max
	out.regen_per_s = float(guard.get("meter_regen_per_s", 12.0))
	out.regen_delay_ms = float(guard.get("regen_delay_ms", 800.0))
	return out


## A blocked hit with `poise_damage`. Returns the meter left.
func absorb(poise_damage: float, now_ms: float) -> float:
	meter = maxf(meter - maxf(poise_damage, 0.0), 0.0)
	_last_hit_ms = now_ms
	return meter


## Refill after `regen_delay_ms` without a hit. `dt_s` is the owner's own time step.
func step(dt_s: float, now_ms: float) -> void:
	if meter >= meter_max or dt_s <= 0.0:
		return
	if now_ms - _last_hit_ms < regen_delay_ms:
		return
	meter = minf(meter + regen_per_s * dt_s, meter_max)


func refill() -> void:
	meter = meter_max


func is_empty() -> bool:
	return meter <= 0.0


func fraction() -> float:
	return meter / meter_max if meter_max > 0.0 else 0.0
