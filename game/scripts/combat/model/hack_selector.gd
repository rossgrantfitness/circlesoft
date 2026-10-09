class_name HackSelector
extends RefCounted
## Which hack the hack button fires (the tech plan's Decision 1, both options built; docs/slice/hacks_design.md).
## Pure: no nodes, no clock.
##
## PICK (option A, the default): the HUD shows a selected hack; `step(+1/-1)` (d-pad, mouse wheel) and `select_index`
## (keys 1 to 4) change it; the button fires it. Order and wrap come from hacks.json `selection`.
##
## AUTO (option C): `pick_auto(situation, knobs)` reads the situation and walks the rules in hacks.json `auto.rules`
## top to bottom. The first rule whose `when` is all true AND that Red can afford is the hack. A rule that matches but
## cannot be afforded either tries the next one (`if_short: next`) or fizzes (`fizz`: nothing fires, nothing is spent).
##
## situation (all keys optional):
##   held_ms           float   how long the button was held (a tap is small)
##   enemy_dists       Array   flat distance in metres of every living enemy from Red
##   lock              Dict    {exists, tags: Array, hijackable: bool}: what she is hard-locked on to
##   cone              Array   free hijackable things: [{dist, angle_deg, tags}] (angle from the way she is aiming)
##   affordable        Dict    hack id -> bool: can the battery (and the rules) pay for it right now
## `when` keys: held_ms_min, enemies_within_m + count_min, lock_has_tag_any + lock_hijackable,
## hijackable_in_cone {range_m, cone_deg, tags_any}. `cone_deg` is the half angle each side, as everywhere in lock-on.
## An unknown `when` key fails its rule, so a typo in the data shows up in the tests.
##
## result of pick_auto: {hack, rule, fizz}. `hack` is &"" when nothing fits at all; `fizz` is true when the matching
## rule could not be afforded and said fizz (the hack field then names what she tried).

const MODE_PICK: StringName = &"pick"
const MODE_AUTO: StringName = &"auto"
const KNOB_PICK: String = "pick_then_fire"
const KNOB_AUTO: String = "automatic"

var mode: StringName = MODE_PICK
var wrap: bool = true

var _order: Array[StringName] = []
var _index: int = 0
var _rules: Array[Dictionary] = []
var _last_used: StringName = &""
var _show_last: bool = true


static func from_data(doc: Dictionary) -> HackSelector:
	var out: HackSelector = HackSelector.new()
	var selection: Dictionary = doc.get("selection", {}) as Dictionary
	for raw: Variant in selection.get("order", []) as Array:
		out._order.append(StringName(str(raw)))
	if out._order.is_empty():
		for id: Variant in (doc.get("hacks", {}) as Dictionary).keys():
			out._order.append(StringName(str(id)))
	out.mode = MODE_AUTO if str(selection.get("mode", "pick")) == "auto" else MODE_PICK
	out.wrap = bool(selection.get("wrap", true))
	var start: int = out._order.find(StringName(str(selection.get("start_selected", ""))))
	out._index = maxi(start, 0)
	var auto: Dictionary = doc.get("auto", {}) as Dictionary
	out._show_last = bool(auto.get("show_last_used", true))
	for raw: Variant in auto.get("rules", []) as Array:
		if raw is Dictionary:
			out._rules.append((raw as Dictionary).duplicate(true))
	return out


static func load_default() -> HackSelector:
	return from_data(CombatData.hacks())


## The knob value ("pick_then_fire" / "automatic") as a mode. Anything else keeps the data's mode.
func set_mode_from_knob(value: String) -> void:
	if value == KNOB_AUTO:
		mode = MODE_AUTO
	elif value == KNOB_PICK:
		mode = MODE_PICK


func order() -> Array[StringName]:
	return _order.duplicate()


func count() -> int:
	return _order.size()


func rule_count() -> int:
	return _rules.size()


func rule_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for rule: Dictionary in _rules:
		out.append(StringName(str(rule.get("id", ""))))
	return out


# ---- option A: pick, then fire ----

func selected() -> StringName:
	return _order[_index] if not _order.is_empty() else &""


func selected_index() -> int:
	return _index


## Moves the selection one step (+1 right, -1 left). Wraps round when `wrap`. Returns the new selection.
func step(direction: int) -> StringName:
	if _order.is_empty() or direction == 0:
		return selected()
	var next: int = _index + (1 if direction > 0 else -1)
	if wrap:
		next = posmod(next, _order.size())
	else:
		next = clampi(next, 0, _order.size() - 1)
	_index = next
	return selected()


## Keys 1 to 4: choose by position. False if there is no such slot.
func select_index(index: int) -> bool:
	if index < 0 or index >= _order.size():
		return false
	_index = index
	return true


func select_id(id: StringName) -> bool:
	return select_index(_order.find(id))


# ---- what the HUD shows ----

## Pick: the selected hack. Auto: the last one used (the HUD never lets the guess be a surprise), else the selected one.
func shown() -> StringName:
	if mode == MODE_AUTO and _show_last and _last_used != &"":
		return _last_used
	return selected()


func last_used() -> StringName:
	return _last_used


func note_used(id: StringName) -> void:
	_last_used = id


# ---- option C: automatic ----

func pick_auto(situation: Dictionary, knobs: Dictionary = {}) -> Dictionary:
	var affordable: Dictionary = situation.get("affordable", {}) as Dictionary
	for rule: Dictionary in _rules:
		if not _when_holds(rule, situation, knobs):
			continue
		var hack: StringName = StringName(str(rule.get("hack", "")))
		if bool(affordable.get(String(hack), false)):
			return {"hack": hack, "rule": StringName(str(rule.get("id", ""))), "fizz": false}
		if str(rule.get("if_short", "next")) == "fizz":
			return {"hack": hack, "rule": StringName(str(rule.get("id", ""))), "fizz": true}
	return {"hack": &"", "rule": &"", "fizz": true}


## Every key of the rule's `when` must hold. The knobs `auto_hold_ms` and `auto_crowd` replace the data numbers of the
## rules named reboot_hold and crowd (so the feel panel's sliders work).
func _when_holds(rule: Dictionary, situation: Dictionary, knobs: Dictionary) -> bool:
	var when: Dictionary = rule.get("when", {}) as Dictionary
	var rule_id: String = str(rule.get("id", ""))
	for key: Variant in when.keys():
		var wanted: Variant = when[key]
		match str(key):
			"held_ms_min":
				var need: float = float(wanted)
				if rule_id == "reboot_hold" and float(knobs.get("auto_hold_ms", 0.0)) > 0.0:
					need = float(knobs["auto_hold_ms"])
				if float(situation.get("held_ms", 0.0)) < need:
					return false
			"enemies_within_m":
				var count_min: int = int(when.get("count_min", 1))
				if rule_id == "crowd" and int(knobs.get("auto_crowd", 0)) > 0:
					count_min = int(knobs["auto_crowd"])
				if _count_within(situation, float(wanted)) < count_min:
					return false
			"count_min":
				pass                # read together with enemies_within_m
			"lock_has_tag_any":
				var lock: Dictionary = situation.get("lock", {}) as Dictionary
				if not bool(lock.get("exists", false)) or not _shares(lock.get("tags", []) as Array, wanted as Array):
					return false
			"lock_hijackable":
				var lock_now: Dictionary = situation.get("lock", {}) as Dictionary
				if bool(lock_now.get("hijackable", false)) != bool(wanted):
					return false
			"hijackable_in_cone":
				if not _cone_has(situation, wanted as Dictionary):
					return false
			_:
				return false
	return true


static func _count_within(situation: Dictionary, range_m: float) -> int:
	var count: int = 0
	for item: Variant in situation.get("enemy_dists", []) as Array:
		if float(item) <= range_m:
			count += 1
	return count


static func _shares(tags: Array, wanted: Array) -> bool:
	for tag: Variant in tags:
		if wanted.has(str(tag)) or wanted.has(tag):
			return true
	return false


static func _cone_has(situation: Dictionary, spec: Dictionary) -> bool:
	var range_m: float = float(spec.get("range_m", 10.0))
	var half_deg: float = float(spec.get("cone_deg", 60.0))
	var tags_any: Array = spec.get("tags_any", []) as Array
	for item: Variant in situation.get("cone", []) as Array:
		var entry: Dictionary = item as Dictionary
		if float(entry.get("dist", INF)) > range_m or float(entry.get("angle_deg", 180.0)) > half_deg:
			continue
		if tags_any.is_empty() or _shares(entry.get("tags", []) as Array, tags_any):
			return true
	return false
