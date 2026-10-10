class_name TapAlong
extends RefCounted
## The maths behind the Config screen's tap-along test (no nodes, no clock, easy to test).
##
## The screen flashes and dings on a steady beat and the player taps on every one. Each tap is
## paired with the beat it was nearest to, giving a list of "how late was the tap" values in
## milliseconds (negative = early). A steady lag in that list is the lag of the player's TV,
## headphones or controller, so the suggested timing offset is simply that average, rounded to the
## Config step and kept inside the allowed range. Positive means "count presses later".
##
## Shaky data is handled honestly: the first taps are ignored (people are still finding the beat),
## wild outliers are thrown away, and when too few good taps are left there is no suggestion.

const REASON_OK: String = "ok"
const REASON_TOO_FEW: String = "too_few"
const REASON_UNSTEADY: String = "unsteady"

## Defaults used when the data gives no number (see data/ui/config_screen.json, "tap_along").
const DEFAULTS: Dictionary = {"ignore_first": 1, "min_taps": 4, "outlier_ms": 100.0, "steady_ms": 60.0, "bias_ms": 0.0}


## Pairs every beat with the nearest unused tap within `max_match_ms` of it. Returns the lateness of
## each paired tap (tap time minus beat time) in beat order. Beats nobody tapped near are skipped.
static func match_taps(beat_ms: Array, tap_ms: Array, max_match_ms: float) -> Array[float]:
	var deltas: Array[float] = []
	var used: Dictionary[int, bool] = {}
	for beat: Variant in beat_ms:
		var best: int = -1
		var best_gap: float = max_match_ms
		for i: int in tap_ms.size():
			if used.has(i):
				continue
			var gap: float = absf(float(tap_ms[i]) - float(beat))
			if gap <= best_gap:
				best_gap = gap
				best = i
		if best >= 0:
			used[best] = true
			deltas.append(float(tap_ms[best]) - float(beat))
	return deltas


## {"ok": bool, "reason": String, "offset_ms": int, "mean_ms": float, "spread_ms": float,
##  "used": int, "steady": bool}. `params` may hold ignore_first, min_taps, outlier_ms, steady_ms
## and bias_ms (a number taken off the average, to allow for people tapping slightly early).
static func suggest(deltas: Array, params: Dictionary, step_ms: int, min_ms: int, max_ms: int) -> Dictionary:
	var settings: Dictionary = DEFAULTS.duplicate()
	settings.merge(params, true)
	var result: Dictionary = {"ok": false, "reason": REASON_TOO_FEW, "offset_ms": 0, "mean_ms": 0.0, "spread_ms": 0.0, "used": 0, "steady": false}
	var skip: int = int(settings["ignore_first"])
	var min_taps: int = int(settings["min_taps"])
	var pool: Array[float] = []
	for i: int in deltas.size():
		if i >= skip:
			pool.append(float(deltas[i]))
	# Not enough left after skipping the warm-up taps? Use them all rather than give up.
	if pool.size() < min_taps and deltas.size() >= min_taps:
		pool.clear()
		for value: Variant in deltas:
			pool.append(float(value))
	if pool.size() < min_taps:
		return result
	var middle: float = median(pool)
	var kept: Array[float] = []
	for value: float in pool:
		if absf(value - middle) <= float(settings["outlier_ms"]):
			kept.append(value)
	if kept.size() < min_taps:
		result["reason"] = REASON_UNSTEADY
		return result
	var mean: float = 0.0
	for value: float in kept:
		mean += value
	mean /= float(kept.size())
	var spread: float = 0.0
	for value: float in kept:
		spread += (value - mean) * (value - mean)
	spread = sqrt(spread / float(kept.size()))
	var step: int = maxi(1, step_ms)
	var snapped_ms: int = int(snappedf(mean - float(settings["bias_ms"]), float(step)))
	result["ok"] = true
	result["reason"] = REASON_OK
	result["offset_ms"] = clampi(snapped_ms, min_ms, max_ms)
	result["mean_ms"] = mean
	result["spread_ms"] = spread
	result["used"] = kept.size()
	result["steady"] = spread <= float(settings["steady_ms"])
	return result


static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var count: int = sorted.size()
	if count % 2 == 1:
		return float(sorted[count / 2])
	return (float(sorted[count / 2 - 1]) + float(sorted[count / 2])) / 2.0
