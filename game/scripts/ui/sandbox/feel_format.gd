class_name FeelFormat
extends RefCounted
## The pure part of the feel-knobs panel: how a knob from data/combat/feel.json is stepped, snapped,
## shown (units, On/Off, plain choice names) and explained (hints). Nothing here touches the
## screen, so it is tested without any scene (tests/unit/test_feel_format.gd).
##
## A knob is the dictionary the file uses: {id, group, label, type ("float" / "int" / "bool" /
## "choice"), value, min, max, step, unit, options, hint}. Words come from data/text/sandbox.json
## ("feel"); a knob's own "hint" wins over the fallback table there.

const KIND_FLOAT: String = "float"
const KIND_INT: String = "int"
const KIND_BOOL: String = "bool"
const KIND_CHOICE: String = "choice"
const MAX_DECIMALS: int = 4
const WHOLE_EPSILON: float = 0.000001


## "float", "int", "bool" or "choice" (anything else counts as a float).
static func kind_of(knob: Dictionary) -> String:
	var declared: String = str(knob.get("type", KIND_FLOAT))
	if declared == KIND_INT or declared == KIND_BOOL or declared == KIND_CHOICE:
		return declared
	return KIND_FLOAT


static func is_slider(knob: Dictionary) -> bool:
	var kind: String = kind_of(knob)
	return kind == KIND_FLOAT or kind == KIND_INT


static func min_of(knob: Dictionary) -> float:
	return float(knob.get("min", 0.0))


static func max_of(knob: Dictionary) -> float:
	return maxf(float(knob.get("max", 1.0)), min_of(knob))


## The step between slider positions: the knob's own, or a hundredth of the range (whole numbers for ints).
static func step_of(knob: Dictionary) -> float:
	var step: float = float(knob.get("step", 0.0))
	if step > 0.0:
		return step
	if kind_of(knob) == KIND_INT:
		return 1.0
	return maxf((max_of(knob) - min_of(knob)) / 100.0, 0.0001)


## How many decimals a step needs to be written exactly (0.25 -> 2, 1 -> 0).
static func decimals_for(step: float) -> int:
	for decimals: int in range(MAX_DECIMALS + 1):
		var scaled: float = step * pow(10.0, float(decimals))
		if absf(scaled - roundf(scaled)) < WHOLE_EPSILON:
			return decimals
	return MAX_DECIMALS


## `value` clamped into the range and moved onto the nearest step.
static func snap(knob: Dictionary, value: float) -> float:
	var low: float = min_of(knob)
	var high: float = max_of(knob)
	var step: float = step_of(knob)
	var clamped: float = clampf(value, low, high)
	var snapped: float = low + roundf((clamped - low) / step) * step
	snapped = clampf(snapped, low, high)
	var scale: float = pow(10.0, float(decimals_for(step)))
	return roundf(snapped * scale) / scale


## 0..1 position of a value along the slider.
static func fraction(knob: Dictionary, value: float) -> float:
	var span: float = max_of(knob) - min_of(knob)
	if span <= 0.0:
		return 0.0
	return clampf((value - min_of(knob)) / span, 0.0, 1.0)


## The (snapped) value at a 0..1 slider position.
static func value_at(knob: Dictionary, fraction_along: float) -> float:
	return snap(knob, min_of(knob) + clampf(fraction_along, 0.0, 1.0) * (max_of(knob) - min_of(knob)))


## The value after `steps` steps (negative = down). Stops at the ends.
static func step_number(knob: Dictionary, value: float, steps: int) -> float:
	return snap(knob, snap(knob, value) + float(steps) * step_of(knob))


## The next / previous option of a choice knob (wraps). Unknown current values start at the first option.
static func cycle_choice(knob: Dictionary, current: String, direction: int) -> String:
	var options: Array = knob.get("options", [])
	if options.is_empty():
		return current
	var index: int = options.find(current)
	if index < 0:
		return str(options[0])
	return str(options[posmod(index + direction, options.size())])


## True when two values of this knob are the same (numbers within half a step).
static func same_value(knob: Dictionary, a: Variant, b: Variant) -> bool:
	if is_slider(knob):
		return absf(float(a) - float(b)) < step_of(knob) * 0.5
	return a == b


# ---- words ----

## The number alone, with the decimals its step needs: "4.25", "180".
static func number_text(knob: Dictionary, value: float) -> String:
	return "%.*f" % [decimals_for(step_of(knob)), value]


## The unit as shown ("mps" -> "m/s"), or "".
static func unit_text(knob: Dictionary) -> String:
	var unit: String = str(knob.get("unit", ""))
	if unit.is_empty():
		return ""
	return str(DataDB.get_value(SandboxUiData.TEXT_ID, "feel.units.%s" % unit, unit))


## What the value column shows: "4.25 m", "On", "Hold Heavy".
static func value_text(knob: Dictionary, value: Variant) -> String:
	match kind_of(knob):
		KIND_BOOL:
			return SandboxUiData.text("feel.on") if bool(value) else SandboxUiData.text("feel.off")
		KIND_CHOICE:
			return option_label(str(knob.get("id", "")), str(value))
		_:
			var unit: String = unit_text(knob)
			var number: String = number_text(knob, float(value))
			return number if unit.is_empty() else "%s %s" % [number, unit]


## The plain name of a choice option ("hold_heavy" -> "Hold Heavy"); a prettified id when no name is written.
static func option_label(knob_id: String, option: String) -> String:
	var named: String = str(DataDB.get_value(SandboxUiData.TEXT_ID, "feel.choice_labels.%s.%s" % [knob_id, option], ""))
	if not named.is_empty():
		return named
	return option.replace("_", " ").capitalize()


## The knob's label (its own, else the id made readable).
static func label_of(knob: Dictionary) -> String:
	var label: String = str(knob.get("label", ""))
	if not label.is_empty():
		return label
	return str(knob.get("id", "")).replace("_", " ").capitalize()


## One-line hint: the knob's own "hint", else the fallback table in sandbox.json, else "".
static func hint_of(knob: Dictionary) -> String:
	var own: String = str(knob.get("hint", ""))
	if not own.is_empty():
		return own
	return SandboxUiData.text("feel.knob_hints.%s" % str(knob.get("id", "")))


## What the current choice means, in a short line ("" when nothing is written for it).
static func choice_hint_of(knob: Dictionary, value: String) -> String:
	return SandboxUiData.text("feel.choice_hints.%s.%s" % [str(knob.get("id", "")), value])


static func group_title(group: String) -> String:
	var title: String = SandboxUiData.text("feel.groups.%s" % group)
	if not title.is_empty():
		return title
	return group.replace("_", " ").capitalize()


## The groups of a knob list, in the order they first appear.
static func groups_of(knobs: Array) -> Array[String]:
	var out: Array[String] = []
	for knob: Variant in knobs:
		var group: String = str((knob as Dictionary).get("group", ""))
		if not out.has(group):
			out.append(group)
	return out


static func knobs_in_group(knobs: Array, group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for knob: Variant in knobs:
		if str((knob as Dictionary).get("group", "")) == group:
			out.append(knob as Dictionary)
	return out


## A path shortened from the left to at most `max_chars` characters ("...app/feel/feel_current.json").
static func shorten_path(path: String, max_chars: int) -> String:
	if path.length() <= max_chars:
		return path
	return "..." + path.substr(path.length() - (max_chars - 3))
