class_name BossBrain
extends RefCounted
## Chooses a boss's next pattern (docs/slice/slice_tech_plan.md 6.4; data/combat/bosses/*.json `patterns`, `opening`, `stages`,
## `rules`). Pure: time is a number (the boss's own combat clock, ms), the world arrives as a `view` dictionary, the answer
## is a plain dictionary. The boss body runs the moves; this decides which one and when.
##
## The rules, all from the data:
##   * the first attack waits `start.first_attack_delay_ms`;
##   * the first attacks are the `opening` list, in order (everyone meets the ring, then the line, then the mix); an opening
##     attack whose conditions do not hold yet waits (the boss walks into range); after `OPENING_PATIENCE_MS` it is dropped;
##   * after that, a weighted pick among the patterns whose `needs` and `when` hold;
##   * never the same pattern twice in a row (`rules.no_pattern_twice_in_a_row`);
##   * after a pattern ends the next waits `stages.min_gap_ms_by_pairs_lost[pairs lost]` (the wind-ups never shorten; the gap does);
##   * a pattern named in another pattern's `while_locked.blocked_patterns` is not picked while the hacks are locked;
##   * `disable(id)` takes a pattern out for good (a broken dish ends Dish Sweep and Quiet Hours).
##
## view keys: dist_m (Red to the body), pairs_lost, pairs_standing, parts_alive {part id: bool}, drones_alive,
## since_start_s, hacks_locked. A `needs`/`when` key this class does not know fails its pattern, so a typo in the data shows up
## in the tests.
##
## pick = {pattern, move, spec, repeat, repeat_gap_ms}. `repeat` is 1, or `chain.count` once `chain.pairs_lost_min` pairs are down.

const OPENING_PATIENCE_MS: float = 4000.0

var _patterns: Array[Dictionary] = []
var _opening: Array[StringName] = []
var _opening_left: Array[StringName] = []
var _gaps: Array = [1900.0, 1700.0, 1500.0, 1300.0]
var _first_delay_ms: float = 2500.0
var _no_repeat: bool = true
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _busy: bool = false
var _last: StringName = &""
var _next_ok_ms: float = 0.0
var _opening_wait_since: float = -1.0
var _ended_at: Dictionary = {}              # pattern id -> ms its last run ended
var _disabled: Dictionary = {}


## `phase` is one entry of `phases` (the rig phase); `rules` the file's `rules` block.
static func from_data(phase: Dictionary, rules: Dictionary = {}, rng_seed: int = 1) -> BossBrain:
	var out: BossBrain = BossBrain.new()
	for raw: Variant in phase.get("patterns", []) as Array:
		if raw is Dictionary:
			out._patterns.append((raw as Dictionary).duplicate(true))
	for raw: Variant in (phase.get("opening", {}) as Dictionary).get("patterns", []) as Array:
		out._opening.append(StringName(str(raw)))
	var stages: Dictionary = phase.get("stages", {}) as Dictionary
	if stages.has("min_gap_ms_by_pairs_lost"):
		out._gaps = (stages["min_gap_ms_by_pairs_lost"] as Array).duplicate()
	out._first_delay_ms = float((phase.get("start", {}) as Dictionary).get("first_attack_delay_ms", 2500.0))
	out._no_repeat = bool(rules.get("no_pattern_twice_in_a_row", true))
	out._rng.seed = rng_seed
	out.start(0.0)
	return out


## A fresh start (or a retry): the opening list again, the first-attack delay from `now_ms`.
func start(now_ms: float) -> void:
	_opening_left = _opening.duplicate()
	_busy = false
	_last = &""
	_next_ok_ms = now_ms + _first_delay_ms
	_opening_wait_since = -1.0
	_ended_at.clear()


func pattern_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for pattern: Dictionary in _patterns:
		out.append(StringName(str(pattern.get("id", ""))))
	return out


func pattern(id: StringName) -> Dictionary:
	for entry: Dictionary in _patterns:
		if StringName(str(entry.get("id", ""))) == id:
			return entry
	return {}


func gap_ms(pairs_lost: int) -> float:
	return float(_gaps[clampi(pairs_lost, 0, _gaps.size() - 1)])


func is_busy() -> bool:
	return _busy


func last_pattern() -> StringName:
	return _last


func opening_left() -> Array[StringName]:
	return _opening_left.duplicate()


func disable(id: StringName) -> void:
	_disabled[String(id)] = true


func is_disabled(id: StringName) -> bool:
	return bool(_disabled.get(String(id), false))


func next_ok_ms() -> float:
	return _next_ok_ms


# ---- the loop ----

## The boss started `id` at `now_ms`.
func begin(id: StringName, _now_ms: float) -> void:
	_busy = true
	_last = id
	_opening_wait_since = -1.0


## The pattern finished (its recovery too). The next one waits the stage's gap.
func finish(now_ms: float, pairs_lost: int) -> void:
	if _last != &"":
		_ended_at[String(_last)] = now_ms
	_busy = false
	_next_ok_ms = maxf(_next_ok_ms, now_ms + gap_ms(pairs_lost))


## Delays the next pick (a reaction like a leg drop: "it cannot start an attack for 1.4 s").
func hold_until(ms: float) -> void:
	_next_ok_ms = maxf(_next_ok_ms, ms)


## The next pattern to run, or {} (busy, still waiting, nothing fits).
func step(now_ms: float, view: Dictionary) -> Dictionary:
	if _busy or now_ms < _next_ok_ms:
		return {}
	if not _opening_left.is_empty():
		var want: StringName = _opening_left[0]
		var spec: Dictionary = pattern(want)
		if not spec.is_empty() and not is_disabled(want) and _eligible(spec, view, now_ms, false):
			_opening_left.remove_at(0)
			return _pick(spec, view)
		if spec.is_empty() or is_disabled(want):
			_opening_left.remove_at(0)
			return step(now_ms, view)
		if _opening_wait_since < 0.0:
			_opening_wait_since = now_ms
		if now_ms - _opening_wait_since < OPENING_PATIENCE_MS:
			return {}                    # the boss is walking into range for it
		_opening_left.remove_at(0)       # it never became possible: carry on with the mix
		_opening_wait_since = -1.0
	var options: Array[Dictionary] = _options(view, now_ms, true)
	if options.is_empty():
		options = _options(view, now_ms, false)       # only the pattern that just ran fits: better it repeats than the boss stands idle
	var total: float = 0.0
	for entry: Dictionary in options:
		total += maxf(float(entry.get("weight", 1.0)), 0.0)
	if options.is_empty():
		return {}
	var roll: float = _rng.randf() * total
	for entry: Dictionary in options:
		roll -= maxf(float(entry.get("weight", 1.0)), 0.0)
		if roll <= 0.0:
			return _pick(entry, view)
	return _pick(options[options.size() - 1], view)


func _options(view: Dictionary, now_ms: float, skip_last: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in _patterns:
		var id: StringName = StringName(str(entry.get("id", "")))
		if is_disabled(id) or (skip_last and _no_repeat and id == _last and _patterns.size() > 1):
			continue
		if _eligible(entry, view, now_ms, true):
			out.append(entry)
	return out


func _pick(spec: Dictionary, view: Dictionary) -> Dictionary:
	var chain: Dictionary = spec.get("chain", {}) as Dictionary
	var repeat: int = 1
	if not chain.is_empty() and int(view.get("pairs_lost", 0)) >= int(chain.get("pairs_lost_min", 99)):
		repeat = int(chain.get("count", 1))
	return {"pattern": StringName(str(spec.get("id", ""))), "move": StringName(str(spec.get("move", ""))), "spec": spec,
			"repeat": repeat, "repeat_gap_ms": float(chain.get("gap_ms", 0.0))}


## Do the pattern's `needs` and `when` hold? `check_when` false (the opening) skips the distance and timing conditions only
## to the extent the opening waits for them; they are still checked, but the caller treats "no" as "wait".
func _eligible(spec: Dictionary, view: Dictionary, now_ms: float, _check_when: bool) -> bool:
	if bool(view.get("hacks_locked", false)) and _blocked_while_locked(StringName(str(spec.get("id", "")))):
		return false
	var needs: Dictionary = spec.get("needs", {}) as Dictionary
	for key: Variant in needs.keys():
		match str(key):
			"pairs_standing_min":
				if int(view.get("pairs_standing", 0)) < int(needs[key]):
					return false
			"part_alive":
				if not bool((view.get("parts_alive", {}) as Dictionary).get(str(needs[key]), false)):
					return false
			_:
				return false
	var when: Dictionary = spec.get("when", {}) as Dictionary
	for key: Variant in when.keys():
		match str(key):
			"dist_max_m":
				if float(view.get("dist_m", INF)) > float(when[key]):
					return false
			"dist_min_m":
				if float(view.get("dist_m", 0.0)) < float(when[key]):
					return false
			"drones_alive_max":
				if int(view.get("drones_alive", 0)) > int(when[key]):
					return false
			"since_phase_start_s_min":
				if float(view.get("since_start_s", 0.0)) < float(when[key]):
					return false
			"cooldown_s":
				var id: String = str(spec.get("id", ""))
				if _ended_at.has(id) and now_ms - float(_ended_at[id]) < float(when[key]) * 1000.0:
					return false
			"hacks_not_locked":
				if bool(when[key]) and bool(view.get("hacks_locked", false)):
					return false
			_:
				return false
	return true


func _blocked_while_locked(id: StringName) -> bool:
	for entry: Dictionary in _patterns:
		var blocked: Array = (entry.get("while_locked", {}) as Dictionary).get("blocked_patterns", []) as Array
		if blocked.has(String(id)):
			return true
	return false
