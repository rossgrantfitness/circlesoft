class_name ClutchJudge
extends RefCounted
## Clutch press judging as pure functions of timestamps (microseconds), windows and modifiers.
## No clock, no nodes, no randomness: the controller feeds in recorded presses and the cue.
##
## Rules, in short:
##  - delta = press - (cue + timing offset). |delta| <= totally_rad half-width = TOTALLY RAD,
##    then Rad, then Nice (each boundary inclusive); anything wider is a miss.
##  - A slot only listens from listen_before_ms ahead of its cue. The FIRST press inside the
##    slot's window is the one judged, so mashing earns nothing.
##  - hold_release: the hold must START between hold_open and hold_by; the RELEASE is judged.
##  - string: every cue is its own slot; slots take presses in cue order, one press each.

const NO_PRESS: int = -1
const USEC_PER_MS: float = 1000.0
const RATING_MISS: String = "miss"
const RATING_NICE: String = "nice"
const RATING_RAD: String = "rad"
const RATING_TOTALLY_RAD: String = "totally_rad"
const TYPE_TAP: String = "tap"
const TYPE_HOLD: String = "hold_release"
const TYPE_STRING: String = "string"
const BLOCK_NONE: String = "none"
const BLOCK_PARTIAL: String = "partial"
const BLOCK_PERFECT: String = "perfect"


## Product of the window modifiers that apply right now (modifiers = timing_windows.json "modifiers").
static func window_multiplier(modifiers: Dictionary, wide_windows: bool, defending_block: bool,
		butterfingers: bool = false, fired_up: bool = false) -> float:
	var mult: float = 1.0
	if wide_windows:
		mult *= float(modifiers.get("wide_windows", 1.0))
	if defending_block:
		mult *= float(modifiers.get("defending_block", 1.0))
	if butterfingers:
		mult *= float(modifiers.get("butterfingers", 1.0))
	if fired_up:
		mult *= float(modifiers.get("fired_up", 1.0))
	return mult


## Rating for a signed offset in ms (negative = early). `window` has nice_ms, rad_ms, totally_rad_ms.
static func rating_for_delta(delta_ms: float, window: Dictionary, mult: float = 1.0) -> String:
	var distance: float = absf(delta_ms)
	if distance <= float(window.get("totally_rad_ms", 0.0)) * mult:
		return RATING_TOTALLY_RAD
	if distance <= float(window.get("rad_ms", 0.0)) * mult:
		return RATING_RAD
	if distance <= float(window.get("nice_ms", 0.0)) * mult:
		return RATING_NICE
	return RATING_MISS


## The moment the judge compares presses against: t0 + cue + the player's timing offset.
static func cue_usec(t0_usec: int, cue_ms: int, timing_offset_ms: int = 0) -> int:
	return t0_usec + (cue_ms + timing_offset_ms) * 1000


static func delta_ms(press_usec: int, cue_usec_value: int) -> float:
	return float(press_usec - cue_usec_value) / USEC_PER_MS


static func is_rad_or_better(rating: String) -> bool:
	return rating == RATING_RAD or rating == RATING_TOTALLY_RAD


## What a rating means for a block press: none / partial (Blocked!) / perfect (Perfect Block!).
static func block_tier(rating: String) -> String:
	if rating == RATING_TOTALLY_RAD:
		return BLOCK_PERFECT
	if rating == RATING_NICE or rating == RATING_RAD:
		return BLOCK_PARTIAL
	return BLOCK_NONE


## Slot parameters for one press. All times in microseconds on the battle clock.
## cue: judged moment (offset included). hold_by: latest hold start (hold_release only).
static func make_slot(press_type: String, cue: int, hold_by: int, listen_before_ms: int, window: Dictionary,
		mult: float, hold_from: int = NO_PRESS) -> Dictionary:
	var open: int = cue - listen_before_ms * 1000
	if press_type == TYPE_HOLD:
		open = hold_from if hold_from != NO_PRESS else hold_by - listen_before_ms * 1000
	var close: int = cue + int(float(window.get("nice_ms", 0.0)) * mult * USEC_PER_MS)
	return {"type": press_type, "cue": cue, "hold_by": hold_by, "open": open, "close": close,
		"window": window, "mult": mult}


## Judge one slot against the presses recorded so far.
## downs / ups: ascending press and release timestamps not yet used by an earlier slot.
## now: the clock time; presses stamped after `now` have not happened yet.
## Returns {decided, rating, delta_ms, pressed, used_down, used_up}. decided=false means wait.
static func decide(slot: Dictionary, downs: Array[int], ups: Array[int], now: int) -> Dictionary:
	if str(slot["type"]) == TYPE_HOLD:
		return _decide_hold(slot, downs, ups, now)
	return _decide_tap(slot, downs, now)


static func _decide_tap(slot: Dictionary, downs: Array[int], now: int) -> Dictionary:
	var open: int = slot["open"]
	var close: int = slot["close"]
	for t: int in downs:
		if t > now:
			break
		if t < open:
			continue
		if t > close:
			break
		return _result(slot, t, NO_PRESS, t - int(slot["cue"]))
	if now >= close:
		return _undelivered(slot)
	return {"decided": false}


static func _decide_hold(slot: Dictionary, downs: Array[int], ups: Array[int], now: int) -> Dictionary:
	var open: int = slot["open"]
	var close: int = slot["close"]
	var hold_by: int = slot["hold_by"]
	var down_at: int = NO_PRESS
	for t: int in downs:
		if t > now or t > hold_by:
			break
		if t >= open:
			down_at = t
			break
	if down_at == NO_PRESS:
		if now >= close:
			return _undelivered(slot)
		return {"decided": false}
	for u: int in ups:
		if u > now:
			break
		if u >= down_at:
			return _result(slot, down_at, u, u - int(slot["cue"]))
	if now >= close:
		return _undelivered(slot)
	return {"decided": false}


static func _result(slot: Dictionary, down_at: int, up_at: int, delta_usec: int) -> Dictionary:
	var delta: float = float(delta_usec) / USEC_PER_MS
	return {"decided": true, "rating": rating_for_delta(delta, slot["window"], float(slot["mult"])),
		"delta_ms": delta, "pressed": true, "used_down": down_at, "used_up": up_at}


static func _undelivered(_slot: Dictionary) -> Dictionary:
	return {"decided": true, "rating": RATING_MISS, "delta_ms": 0.0, "pressed": false,
		"used_down": NO_PRESS, "used_up": NO_PRESS}


## The next clock time at which decide() could return a different answer: the next relevant
## press if one is already recorded (the simulator records presses ahead of time), else the close.
static func next_decision_usec(slot: Dictionary, downs: Array[int], ups: Array[int], now: int) -> int:
	var close: int = slot["close"]
	var best: int = close
	if str(slot["type"]) == TYPE_HOLD:
		var has_down: bool = false
		for t: int in downs:
			if t <= now and t <= int(slot["hold_by"]) and t >= int(slot["open"]):
				has_down = true
				break
		var list: Array[int] = ups if has_down else downs
		for t: int in list:
			if t > now:
				if has_down or t <= int(slot["hold_by"]):
					best = mini(best, t)
				break
		return best
	for t: int in downs:
		if t > now and t >= int(slot["open"]) and t <= close:
			best = mini(best, t)
			break
	return best


## Judge a whole string: one slot per cue, taking presses in cue order, one press per cue.
## Returns one result Dictionary per cue (see decide). Pure helper for tests and the simulator.
static func judge_string(downs: Array[int], cues: Array[int], listen_before_ms: int, window: Dictionary,
		mult: float = 1.0) -> Array[Dictionary]:
	var remaining: Array[int] = downs.duplicate()
	remaining.sort()
	var empty: Array[int] = []
	var out: Array[Dictionary] = []
	for cue: int in cues:
		var slot: Dictionary = make_slot(TYPE_TAP, cue, NO_PRESS, listen_before_ms, window, mult)
		var verdict: Dictionary = decide(slot, remaining, empty, int(slot["close"]))
		if int(verdict["used_down"]) != NO_PRESS:
			remaining.erase(int(verdict["used_down"]))
		out.append(verdict)
	return out
