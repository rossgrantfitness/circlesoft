class_name Features
extends RefCounted
## Feature switches (slice tech plan section 7): `data/slice/features.json` says which of the cut or
## undecided mechanics are on (all on by default). Pure: no nodes, so the model, the FX and any UI can ask
## `Features.is_on(Features.LAMP_FLARE)`. A switch that is off disables its system cleanly everywhere, and
## nothing is removed: flipping it back brings it all back. Only Ross decides to flip one in the file.
##
##   lights_on   the Lights On power-up (never starts, no damage bonus or super armour, no glow or sound, no HUD part,
##               its feel knob is hidden)
##   lamp_flare  perfect dodges and parries no longer start the slow-mo (no call-out, no flare look or sound, its knobs hidden);
##               the dodge is still detected (`CombatDirector.perfect_dodge_detected`)
##   noise_meter the Noise meter stops scoring and its HUD element hides (Lights On needs a full meter, so it never starts either)
##
## `set_on` is a runtime override (tests, a debug menu); the file is never written. The director watches `version()`
## and announces a flip with `CombatDirector.feature_changed(id, on)`, which HUD and FX listen to.

const PATH: String = "res://data/slice/features.json"
const LIGHTS_ON: StringName = &"lights_on"
const LAMP_FLARE: StringName = &"lamp_flare"
const NOISE_METER: StringName = &"noise_meter"
const IDS: Array[StringName] = [LIGHTS_ON, LAMP_FLARE, NOISE_METER]

static var _overrides: Dictionary = {}
static var _version: int = 0


## Pure: the switch `id` in a parsed features document. A missing key (or a missing file) means on.
static func flag_in(doc: Dictionary, id: StringName) -> bool:
	var value: Variant = doc.get(String(id), true)
	return bool(value) if value is bool else true


## Is the feature on? Unknown ids count as on, so a typo never silently disables a system.
static func is_on(id: StringName) -> bool:
	if _overrides.has(id):
		return bool(_overrides[id])
	return flag_in(CombatData.read_json(PATH), id)


## {id: bool} for every switch.
static func states() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in IDS:
		out[id] = is_on(id)
	return out


## Override a switch for this run. Bumps `version()` when it changes the answer.
static func set_on(id: StringName, on: bool) -> void:
	if is_on(id) == on and _overrides.has(id):
		return
	var before: bool = is_on(id)
	_overrides[id] = on
	if before != on:
		_version += 1


## Drops every override: the file decides again.
static func clear_overrides() -> void:
	var before: Dictionary = states()
	_overrides.clear()
	if before != states():
		_version += 1


## Goes up by one whenever any switch changes. Watchers compare it to the last number they saw.
static func version() -> int:
	return _version
