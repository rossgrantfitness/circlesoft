class_name EncounterWaves
extends RefCounted
## The timing rules of one encounter's waves (data/slice/encounters.json), with no nodes: which wave starts when. The
## EncounterRunner feeds it the clock, how many of each wave are still alive and where Red is, and it answers with events:
##   {"type": "warn",  "wave": id, "bark": bark_id}   a wave is about to come (its `warning` bark goes out `warning_ms` early)
##   {"type": "spawn", "wave": id}                    spawn this wave now
##
## A wave's `start` is one of:
##   "on_trigger"                                        the moment the encounter's trigger fires
##   {"after_wave": w, "alive_at_most": n, "or_after_s": t}   w has spawned, and either at most n of it are still alive or t seconds
##                                                       have passed since it spawned (either key may be left out)
##   {"red_x_at_least": x}                               Red has walked past x (metres east); may be combined with after_wave
## A wave never starts less than `wave_gap_ms` after the one before it (rules.wave_gap_ms: "a wave never starts while the last
## one is still biting").

var _waves: Array[Dictionary] = []
var _gap_s: float = 2.5
var _warning_s: float = 0.9
var _begun: bool = false
var _begin_time: float = 0.0
var _started_at: Dictionary[String, float] = {}
var _warned_at: Dictionary[String, float] = {}
var _last_start: float = -INF


## `waves` is the encounter's "waves" list; `rules` is encounters.json "rules".
static func from_defs(waves: Array, rules: Dictionary = {}) -> EncounterWaves:
	var plan: EncounterWaves = EncounterWaves.new()
	for raw: Variant in waves:
		if raw is Dictionary:
			plan._waves.append(raw as Dictionary)
	plan._gap_s = float(rules.get("wave_gap_ms", 2500.0)) / 1000.0
	plan._warning_s = float(rules.get("wave_warning_ms", 900.0)) / 1000.0
	return plan


func wave_ids() -> Array[String]:
	var ids: Array[String] = []
	for wave: Dictionary in _waves:
		ids.append(str(wave.get("id", "")))
	return ids


func is_begun() -> bool:
	return _begun


## The trigger fired at `now` seconds.
func begin(now: float) -> void:
	if not _begun:
		_begun = true
		_begin_time = now


func has_started(wave_id: String) -> bool:
	return _started_at.has(wave_id)


func started_at(wave_id: String) -> float:
	return float(_started_at.get(wave_id, -1.0))


## True once every wave has spawned.
func all_started() -> bool:
	return _begun and _started_at.size() == _waves.size()


func wave_def(wave_id: String) -> Dictionary:
	for wave: Dictionary in _waves:
		if str(wave.get("id", "")) == wave_id:
			return wave
	return {}


## One step. `alive` maps wave id -> how many of that wave are alive. Returns the events to act on, in order.
func tick(now: float, alive: Dictionary, red_x: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _begun:
		return events
	for wave: Dictionary in _waves:
		var id: String = str(wave.get("id", ""))
		if _started_at.has(id):
			continue
		if not _condition(wave.get("start", "on_trigger"), now, alive, red_x):
			break               # waves go in order: a later one never jumps the queue
		if _last_start > -INF and now - _last_start < _gap_s:
			break
		var bark: String = str(wave.get("warning", ""))
		if not bark.is_empty():
			if not _warned_at.has(id):
				_warned_at[id] = now
				events.append({"type": "warn", "wave": id, "bark": bark})
			if now - float(_warned_at[id]) < _warning_s:
				break
		_started_at[id] = now
		_last_start = now
		events.append({"type": "spawn", "wave": id})
	return events


func _condition(start: Variant, now: float, alive: Dictionary, red_x: float) -> bool:
	if start is String:
		return str(start) == "on_trigger"
	if not start is Dictionary:
		return false
	var rule: Dictionary = start
	var after: String = str(rule.get("after_wave", ""))
	if not after.is_empty():
		if not _started_at.has(after):
			return false
		var by_count: bool = rule.has("alive_at_most") and int(alive.get(after, 0)) <= int(rule["alive_at_most"])
		var by_time: bool = rule.has("or_after_s") and now - float(_started_at[after]) >= float(rule["or_after_s"])
		if (rule.has("alive_at_most") or rule.has("or_after_s")) and not (by_count or by_time):
			return false
	if rule.has("red_x_at_least") and red_x < float(rule["red_x_at_least"]):
		return false
	return true
