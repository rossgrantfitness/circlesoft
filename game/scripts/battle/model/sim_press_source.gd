class_name SimPressSource
extends PressSource
## Simulated players for the battle simulator. Each press is planned from the cue:
##   perfect: exactly on the cue.        good: normally distributed around the cue (sigma_ms),
##   with an occasional lapse (lapse_chance) where the press is skipped.
##   miss: never presses.                (Auto-Timing is AutoTimingPressSource.)
## Hold presses start the hold hold_lead_ms before the cue (but never after hold_by).

const MODE_PERFECT: String = "perfect"
const MODE_GOOD: String = "good"
const MODE_MISS: String = "miss"
const HOLD_SAFETY_USEC: int = 20000

var mode: String = MODE_PERFECT
var sigma_ms: float = 40.0
var hold_lead_ms: float = 450.0
## Chance a press is skipped entirely (a lapse of attention); only the good player has any.
var lapse_chance: float = 0.0


static func make(p_mode: String, p_sigma_ms: float = 40.0, p_hold_lead_ms: float = 450.0, p_lapse_chance: float = 0.0) -> SimPressSource:
	var source: SimPressSource = SimPressSource.new()
	source.mode = p_mode
	source.sigma_ms = p_sigma_ms
	source.hold_lead_ms = p_hold_lead_ms
	source.lapse_chance = p_lapse_chance if p_mode == MODE_GOOD else 0.0
	return source


func plan(slot: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var downs: Array[int] = []
	var ups: Array[int] = []
	if mode == MODE_MISS:
		return {"downs": downs, "ups": ups}
	if lapse_chance > 0.0 and rng.randf() < lapse_chance:
		return {"downs": downs, "ups": ups}
	var cue: int = slot["cue"]
	var error_usec: int = 0
	if mode == MODE_GOOD:
		error_usec = int(rng.randfn(0.0, sigma_ms) * ClutchJudge.USEC_PER_MS)
	if str(slot["type"]) == ClutchJudge.TYPE_HOLD:
		var start: int = mini(cue - int(hold_lead_ms * ClutchJudge.USEC_PER_MS), int(slot["hold_by"]) - HOLD_SAFETY_USEC)
		downs.append(maxi(start, int(slot["open"])))
		ups.append(maxi(cue + error_usec, downs[0] + 1))
	else:
		downs.append(cue + error_usec)
	return {"downs": downs, "ups": ups}
