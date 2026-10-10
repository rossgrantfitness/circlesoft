class_name JuggleRules
extends RefCounted
## How a juggle behaves (contract 4.2). Pure functions; the numbers are the "juggle" block of hit_feel.json.
##  - Each extra air hit lifts the target a little less (lift_falloff).
##  - Right after a hit, gravity is low for a moment (the float), so a combo keeps the target up.
##  - After max_hits the target can no longer be juggled and drops.
## `cfg` is that block; leave it empty to read the file.


static func _cfg(cfg: Dictionary) -> Dictionary:
	if not cfg.is_empty():
		return cfg
	return CombatData.hit_feel().get("juggle", {})


## Launch speed (m/s up) for a hit with `launch_mps` on a target that has already taken `juggle_count` hits
## in this juggle. The first hit gets the full speed; each later one is falloff times the one before,
## but never under min_lift_mps (while launch_mps itself is above zero).
static func lift_for(launch_mps: float, juggle_count: int, cfg: Dictionary = {}) -> float:
	if launch_mps <= 0.0:
		return 0.0
	var c: Dictionary = _cfg(cfg)
	var falloff: float = float(c.get("lift_falloff", 0.8))
	var floor_mps: float = float(c.get("min_lift_mps", 3.0))
	return maxf(launch_mps * pow(falloff, float(maxi(juggle_count, 0))), minf(floor_mps, launch_mps))


## The small lift an ordinary air hit gives a target that is already airborne.
static func air_lift_for(juggle_count: int, cfg: Dictionary = {}) -> float:
	var c: Dictionary = _cfg(cfg)
	return lift_for(float(c.get("air_hit_lift_mps", 4.2)), juggle_count, c)


## Multiplier on gravity `ms_since_hit` after an air hit. Low (float_gravity_scale) for float_ms, then it
## eases back to 1 over float_ramp_ms. `juggle_float` is the feel knob: 0 = no float, 2 = twice as long.
static func gravity_scale_after_hit(ms_since_hit: float, juggle_float: float, cfg: Dictionary = {}) -> float:
	if juggle_float <= 0.0 or ms_since_hit < 0.0:
		return 1.0
	var c: Dictionary = _cfg(cfg)
	var float_ms: float = float(c.get("float_ms", 380.0)) * juggle_float
	var low: float = float(c.get("float_gravity_scale", 0.22))
	var ramp_ms: float = maxf(float(c.get("float_ramp_ms", 220.0)), 1.0)
	if ms_since_hit <= float_ms:
		return low
	return lerpf(low, 1.0, clampf((ms_since_hit - float_ms) / ramp_ms, 0.0, 1.0))


## May another air hit keep the target up?
static func can_juggle(juggle_count: int, cfg: Dictionary = {}) -> bool:
	return juggle_count < int(_cfg(cfg).get("max_hits", 10))
