class_name RobotSequence
extends RefCounted
## The clock of one boarding or docking sequence (task CS-21): which phase it is in, how far through that phase, and which moments
## have just passed. Pure numbers (a list of phases from data/combat/scale_profiles.json "sequences"), so the tests can step it
## by hand and check the order of the docking: approach, doors, hop, snap, lock, power-up.
##
## Events returned by tick(): "begin:<phase>", "end:<phase>", "swap" (the moment the body changes), "control" (the player gets
## the controls back) and "done". Each fires once, in time order, even if one step jumps over several.

var kind: StringName = &""
var time_s: float = 0.0
var duration_s: float = 0.0
var swap_at_s: float = -1.0
var control_at_s: float = INF

var _phases: Array[Dictionary] = []      # {name, from, to}
var _fired: Dictionary = {}
var _frozen_left_s: float = 0.0
var _cues_done: int = 0
var _cues: Array[Dictionary] = []


## Builds a sequence from the data's block for `kind` ("board", "disembark", "dock", "undock"); null if there is none.
static func from_data(sequence_kind: StringName) -> RobotSequence:
	return from_config(sequence_kind, ScaleProfile.sequence(sequence_kind))


static func from_config(sequence_kind: StringName, cfg: Dictionary) -> RobotSequence:
	if cfg.is_empty() or not cfg.has("phases"):
		return null
	var seq: RobotSequence = RobotSequence.new()
	seq.kind = sequence_kind
	for raw: Variant in cfg["phases"] as Array:
		var row: Array = raw as Array
		seq._phases.append({"name": StringName(str(row[0])), "from": float(row[1]), "to": float(row[2])})
		seq.duration_s = maxf(seq.duration_s, float(row[2]))
	seq.swap_at_s = float(cfg.get("swap_at_s", -1.0))
	seq.control_at_s = float(cfg.get("control_at_s", seq.duration_s))
	for raw: Variant in cfg.get("camera_cues", []) as Array:
		seq._cues.append(raw as Dictionary)
	seq._cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("at_s", 0.0)) < float(b.get("at_s", 0.0)))
	return seq


func phase_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for phase: Dictionary in _phases:
		out.append(phase["name"] as StringName)
	return out


## The phase running now (the last one once the time is past the end), or &"" before the start.
func phase_name() -> StringName:
	var current: StringName = &""
	for phase: Dictionary in _phases:
		if time_s >= float(phase["from"]):
			current = phase["name"] as StringName
	return current


## 0 before the phase starts, 1 after it ends, linear in between.
func progress(phase_id: StringName) -> float:
	for phase: Dictionary in _phases:
		if phase["name"] == phase_id:
			var span: float = maxf(float(phase["to"]) - float(phase["from"]), 0.0001)
			return clampf((time_s - float(phase["from"])) / span, 0.0, 1.0)
	return 0.0


func start_of(phase_id: StringName) -> float:
	for phase: Dictionary in _phases:
		if phase["name"] == phase_id:
			return float(phase["from"])
	return -1.0


func end_of(phase_id: StringName) -> float:
	for phase: Dictionary in _phases:
		if phase["name"] == phase_id:
			return float(phase["to"])
	return -1.0


func is_done() -> bool:
	return time_s >= duration_s and _fired.has("done")


func has_fired(event: StringName) -> bool:
	return _fired.has(event)


## Stops the clock for `seconds` (the hit-stop when the loader clanks into the bay).
func freeze(seconds: float) -> void:
	_frozen_left_s = maxf(_frozen_left_s, seconds)


func is_frozen() -> bool:
	return _frozen_left_s > 0.0


## The camera cues whose time has come since the last call: dictionaries from the data ({at_s, view, blend_s, world?}).
func take_cues() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	while _cues_done < _cues.size() and float(_cues[_cues_done].get("at_s", 0.0)) <= time_s + 0.000001:
		out.append(_cues[_cues_done])
		_cues_done += 1
	return out


## Advances by `delta` seconds and returns the events that passed (in order).
func tick(delta: float) -> Array[StringName]:
	var events: Array[StringName] = []
	var step: float = maxf(delta, 0.0)
	if _frozen_left_s > 0.0:
		var used: float = minf(_frozen_left_s, step)
		_frozen_left_s -= used
		step -= used
	var before: float = time_s
	time_s += step
	# phases in time order; begin fires at its start (also at time 0 on the first tick), end at its end
	for phase: Dictionary in _phases:
		var begin_id: StringName = StringName("begin:%s" % phase["name"])
		var end_id: StringName = StringName("end:%s" % phase["name"])
		if not _fired.has(begin_id) and time_s >= float(phase["from"]):
			_fired[begin_id] = true
			events.append(begin_id)
		if not _fired.has(end_id) and time_s >= float(phase["to"]):
			_fired[end_id] = true
			events.append(end_id)
	if swap_at_s >= 0.0 and not _fired.has(&"swap") and time_s >= swap_at_s:
		_fired[&"swap"] = true
		events.append(&"swap")
	if not _fired.has(&"control") and time_s >= control_at_s:
		_fired[&"control"] = true
		events.append(&"control")
	if not _fired.has(&"done") and time_s >= duration_s and before < INF:
		_fired[&"done"] = true
		events.append(&"done")
	return events
