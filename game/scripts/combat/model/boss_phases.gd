class_name BossPhases
extends RefCounted
## The phase list of a boss fight (data/combat/bosses/*.json `phases`), and the rules about moving through it. Pure.
##
## A phase has an `id`, a `form` (red / small / huge: what Red is while it runs), a `boss` (who fights, empty for a scripted
## phase) and a `retry` rule: where a knock-out inside it restarts.
##   arena_gate     the arena's `retry_phase1` marker, Red on foot, her health and battery as she walked in
##   phase_start    `retry_phase2`: already docked, full health, the boss whole (the second real phase)
##   skip_to_next   a scripted phase (the transition): nothing to restart, the fight carries on at the next phase
## A scripted phase is one with `steps` (the transition) and no `boss`.
## `retry_for(id)` answers {rule, spawn, form, full_health, restart_phase}: what ActionRoom.set_phase_checkpoint is given and
## which phase the fight resumes at after the room reloads.

const RETRY_GATE: String = "arena_gate"
const RETRY_PHASE_START: String = "phase_start"
const RETRY_SKIP: String = "skip_to_next"

var _phases: Array[Dictionary] = []
var _arena: Dictionary = {}
var _ending: Dictionary = {}
var _boss_id: StringName = &""
var _current: int = -1


static func from_data(doc: Dictionary) -> BossPhases:
	var out: BossPhases = BossPhases.new()
	for raw: Variant in doc.get("phases", []) as Array:
		if raw is Dictionary:
			out._phases.append(raw as Dictionary)
	out._boss_id = StringName(str(doc.get("id", "")))
	out._ending = (doc.get("ending", {}) as Dictionary).duplicate(true)
	for phase: Dictionary in out._phases:
		if phase.has("arena"):
			out._arena = phase["arena"] as Dictionary
			break
	return out


static func load_file(file_name: String) -> BossPhases:
	return from_data(CombatData.read_json(CombatData.DIR + "bosses/" + file_name))


func boss_id() -> StringName:
	return _boss_id


func count() -> int:
	return _phases.size()


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for phase: Dictionary in _phases:
		out.append(StringName(str(phase.get("id", ""))))
	return out


func index_of(id: StringName) -> int:
	return ids().find(id)


func phase(id: StringName) -> Dictionary:
	var index: int = index_of(id)
	return _phases[index] if index >= 0 else {}


func name_of(id: StringName) -> String:
	return str(phase(id).get("name", String(id)))


func form_of(id: StringName) -> StringName:
	return StringName(str(phase(id).get("form", "red")))


func bar_of(id: StringName) -> String:
	return str(phase(id).get("bar", ""))


## A scripted phase (the transition): steps and no boss to fight.
func is_scripted(id: StringName) -> bool:
	var data: Dictionary = phase(id)
	return data.has("steps") and str(data.get("boss", "")).is_empty()


func ending() -> Dictionary:
	return _ending


# ---- walking through ----

func current() -> StringName:
	return StringName(str(_phases[_current].get("id", ""))) if _current >= 0 and _current < _phases.size() else &""


func current_index() -> int:
	return _current


## Begins phase `id` (default: the first). False if there is no such phase.
func start(id: StringName = &"") -> bool:
	var index: int = 0 if id == &"" else index_of(id)
	if index < 0 or index >= _phases.size():
		return false
	_current = index
	return true


## The phase after `id` (the current one by default), or &"" at the end.
func next_of(id: StringName = &"") -> StringName:
	var index: int = _current if id == &"" else index_of(id)
	if index < 0 or index + 1 >= _phases.size():
		return &""
	return StringName(str(_phases[index + 1].get("id", "")))


## Moves to the next phase. Returns it, or &"" when the fight is over.
func advance() -> StringName:
	var next: StringName = next_of()
	if next == &"":
		return &""
	_current = index_of(next)
	return next


func is_last(id: StringName = &"") -> bool:
	return next_of(id) == &""


# ---- retry ----

## How many fighting phases come before (and including) this one: rig = 1, the Heap = 2. Names the arena's retry markers.
func fight_number(id: StringName) -> int:
	var number: int = 0
	for phase_data: Dictionary in _phases:
		if not str(phase_data.get("boss", "")).is_empty():
			number += 1
		if StringName(str(phase_data.get("id", ""))) == id:
			return number if not str(phase_data.get("boss", "")).is_empty() else 0
	return 0


func retry_for(id: StringName) -> Dictionary:
	var data: Dictionary = phase(id)
	var rule: String = str(data.get("retry", RETRY_GATE))
	match rule:
		RETRY_SKIP:
			return {"rule": rule, "spawn": "", "form": form_of(id), "full_health": false, "restart_phase": next_of(id)}
		RETRY_PHASE_START:
			return {"rule": rule, "spawn": str(data.get("retry_spawn", "retry_phase%d" % fight_number(id))),
					"form": form_of(id), "full_health": true, "restart_phase": id}
	var spawn: String = str(data.get("retry_spawn", _arena.get("retry_node", "retry_phase%d" % maxi(fight_number(id), 1))))
	return {"rule": rule, "spawn": spawn, "form": form_of(id), "full_health": false, "restart_phase": id}


## The phase a room entered at `spawn` resumes: the one whose retry spawn it is. &"" if none claims it.
func phase_for_spawn(spawn: String) -> StringName:
	for id: StringName in ids():
		var retry: Dictionary = retry_for(id)
		if str(retry["spawn"]) == spawn and not str(retry["spawn"]).is_empty():
			return id
	return &""


## The battery the fight tops Red up to when this phase starts or restarts (0 = leave it).
func battery_floor(id: StringName) -> float:
	return float((phase(id).get("start", {}) as Dictionary).get("battery_floor", 0.0))
