class_name ParryJudge
extends RefCounted
## Rates a parry press against the moment an enemy hit lands. It wraps ClutchJudge, with two differences
## that suit action: it is ONE-SIDED (a press after contact is a miss, because the hit has already landed)
## and the times are on the ATTACKER'S combat clock (the director converts Red's real-time press stamps
## with `local_at_real`), so a hit-stop or a Lamp Flare between wind-up and hit never shifts the window.
## Like Clutch: only the FIRST press inside the listening time counts, so mashing earns nothing.

const MISS: String = ClutchJudge.RATING_MISS


## presses_usec: press stamps on the attacker's clock (any order).
## impact_usec: the contact moment on that clock.
## window: {nice_ms, rad_ms, totally_rad_ms}. mult: window multiplier (Wide Windows x parry_window_scale).
## offset_ms: Config's timing offset. listen_before_ms: how early a press is still listened to.
## Returns {rating, delta_ms, pressed, press_usec}; delta_ms is press minus (impact + offset), so early is negative.
static func judge(presses_usec: Array[int], impact_usec: int, window: Dictionary, mult: float,
		offset_ms: int, listen_before_ms: int) -> Dictionary:
	var open_usec: int = impact_usec - listen_before_ms * 1000
	var sorted: Array[int] = presses_usec.duplicate()
	sorted.sort()
	for press: int in sorted:
		if press < open_usec:
			continue
		if press > impact_usec:
			break       # after contact: too late (and so is every later press)
		var delta: float = ClutchJudge.delta_ms(press, impact_usec + offset_ms * 1000)
		return {"rating": ClutchJudge.rating_for_delta(delta, window, mult), "delta_ms": delta,
				"pressed": true, "press_usec": press}
	return {"rating": MISS, "delta_ms": 0.0, "pressed": false, "press_usec": ClutchJudge.NO_PRESS}


## The window multiplier for the current settings: Config's Wide Windows times the parry_window_scale knob.
static func window_mult(modifiers: Dictionary, wide_windows: bool, parry_window_scale: float) -> float:
	return ClutchJudge.window_multiplier(modifiers, wide_windows, false) * maxf(parry_window_scale, 0.0)
