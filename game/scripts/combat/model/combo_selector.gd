class_name ComboSelector
extends RefCounted
## The one-button combo (docs/pivot/kh_combo_design.md). Pure: a situation goes in, the next move comes out.
## The rules are data (data/combat/combo.json "rules"); this class only reads them.
##
## Each attack press asks: "where am I in the string, and what is going on?". The answer is the first rule,
## top to bottom, whose `from` is the move that last played (`idle` when there is no live string) and whose
## `when` is true. A rule without a `when` always fits.
##
## situation (all keys optional; a missing key reads as false / 0 / no target):
##   from                 StringName  the move that is playing or just played, &"idle" for no live string
##   player_airborne      bool
##   target_exists        bool        a target in front within params.lunge_max_dist_m
##   target_dist_m        float       flat distance to it (ignored when there is no target)
##   target_airborne      bool
##   target_launchable    bool
##   target_guarding      bool        armored, or its guard is up
##   enemies_near         int         living enemies within params.near_radius_m of Red
##   string_pos           int         attack hits this string has started, counting the move that just played
##   last_hit_connected   bool        the move that just played hit something
##
## result: {move, prefix, rule, restart}. `move` is &"" when nothing should start. `prefix` is a lead-in action
## the caller performs first (&"follow_jump"). `restart` means the string begins again with `move` (position 1): a rule marked restart, or any start from idle.
## `rule` is the id of the rule that fired (for logs and tests).

const IDLE: StringName = &"idle"
const NONE: StringName = &""
## What a missing situation key means. A target that is not there cannot be a "heavy target" that refuses a launcher.
const DEFAULTS: Dictionary = {"target_launchable": true}

var _rules: Array[Dictionary] = []
var _params: Dictionary = {}


static func from_data(doc: Dictionary) -> ComboSelector:
	var out: ComboSelector = ComboSelector.new()
	out._params = (doc.get("params", {}) as Dictionary).duplicate(true)
	for raw: Variant in doc.get("rules", []) as Array:
		if raw is Dictionary:
			out._rules.append((raw as Dictionary).duplicate(true))
	return out


static func load_default() -> ComboSelector:
	return from_data(CombatData.combo())


## A number from combo.json `params` (near_radius_m, string_timeout_ms, ...).
func param(key: String, fallback: float) -> float:
	return float(_params.get(key, fallback))


func rule_count() -> int:
	return _rules.size()


## Is this move one that ends a string (launcher, heavy, sweep, air_3)?
func is_finisher(move_id: StringName) -> bool:
	return (_params.get("finishers", []) as Array).has(String(move_id))


func select(situation: Dictionary) -> Dictionary:
	var from: StringName = StringName(str(situation.get("from", IDLE)))
	var hit: Dictionary = _first_fit(from, situation)
	# A string that ends ("next": "") or a move with no rule for it: the next press starts a fresh string.
	if (hit.is_empty() or StringName(str(hit.get("next", ""))) == NONE) and from != IDLE:
		var fresh: Dictionary = situation.duplicate()
		fresh["from"] = IDLE
		fresh["string_pos"] = 0
		hit = _first_fit(IDLE, fresh)
		if not hit.is_empty():
			return _result(hit, true)
	if hit.is_empty():
		return {"move": NONE, "prefix": NONE, "rule": NONE, "restart": false}
	return _result(hit, from == IDLE)


func _result(rule: Dictionary, from_fresh: bool) -> Dictionary:
	return {
		"move": StringName(str(rule.get("next", ""))),
		"prefix": StringName(str(rule.get("prefix", ""))),
		"rule": StringName(str(rule.get("id", ""))),
		"restart": bool(rule.get("restart", false)) or from_fresh,
	}


func _first_fit(from: StringName, situation: Dictionary) -> Dictionary:
	for rule: Dictionary in _rules:
		if StringName(str(rule.get("from", ""))) != from:
			continue
		if _when_holds(rule.get("when", {}) as Dictionary, situation):
			return rule
	return {}


## Every key of `when` must hold. Unknown keys fail the rule, so a typo in the data shows up in the tests.
func _when_holds(when: Dictionary, situation: Dictionary) -> bool:
	for key: Variant in when.keys():
		var wanted: Variant = when[key]
		match str(key):
			"player_airborne", "target_airborne", "target_launchable", "target_guarding", "target_exists", "last_hit_connected":
				if bool(situation.get(key, DEFAULTS.get(key, false))) != bool(wanted):
					return false
			"target_dist_m":
				if not bool(situation.get("target_exists", false)) or not _in_range(float(situation.get("target_dist_m", INF)), wanted):
					return false
			"enemies_near_min":
				if int(situation.get("enemies_near", 0)) < int(wanted):
					return false
			"string_pos":
				if not _in_range(float(situation.get("string_pos", 0)), wanted):
					return false
			_:
				return false
	return true


static func _in_range(value: float, bounds: Variant) -> bool:
	if not bounds is Array or (bounds as Array).size() < 2:
		return false
	return value >= float((bounds as Array)[0]) and value <= float((bounds as Array)[1])
