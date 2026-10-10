extends RefCounted
## A stand-in for the real BattleController, used only by the battle stage tests and capture scripts. It has the
## same signals and entry points (docs/battle_api.md) but no rules: it just replays a short scripted fight so the
## stage can be tested and photographed before (and after) the real controller exists. It does NOT use the
## BattleController class name, so it never clashes with the real one.
##
## Two ways to drive it: call the emit_* helpers yourself (tests do), or await run_demo_fight() for a whole fight.
## The clock is the real one by default; set use_virtual_clock and move virtual_usec to test cue timing exactly.

signal battle_started(snap: Dictionary)
signal round_started(round: int, order: Array, next_order: Array)
signal turn_started(actor_id: String)
signal command_needed(actor_id: String, options: Dictionary)
signal action_started(action: Dictionary)
signal press_judged(info: Dictionary)
signal hit(info: Dictionary)
signal stats_changed(id: String, hp: int, hp_max: int, juice: int, juice_max: int)
signal status_changed(id: String, status_id: String, added: bool)
signal combatant_down(id: String)
signal combatant_revived(id: String)
signal combatant_fled(id: String)
signal action_finished(action: Dictionary)
signal message(text: String)
signal battle_ended(result: String, report: Dictionary)

const RED: String = "res://art/placeholder/characters/red/red_shiba.glb"
const OTIS: String = "res://art/placeholder/characters/otis/chr_otis.glb"
const MOX: String = "res://art/placeholder/characters/mox/chr_mox.glb"
const GRUNT: String = "res://art/placeholder/enemies/signals_grunt/enm_signals_grunt.glb"
const DRONE: String = "res://art/placeholder/enemies/signals_drone/enm_signals_drone.glb"
const GRUNT_V: String = "res://art/placeholder/enemies/grunt_variant/enm_grunt_variant.glb"
const DRONE_V: String = "res://art/placeholder/enemies/drone_variant/enm_drone_variant.glb"

var tree: SceneTree = null
var instant: bool = false
var is_boss: bool = false
## Combatant id whose entry gets is_boss = true (for boss-view tests).
var boss_id: String = ""
var backdrop: String = "default"
var enemy_count: int = 4
var enemy_models: Array = [GRUNT, DRONE, GRUNT_V, DRONE_V]
var enemy_kinds: Array = ["signals_grunt", "signals_drone", "grunt_variant", "drone_variant"]
var use_virtual_clock: bool = false
var virtual_usec: int = 0
var started: bool = false
var downs: Array = []
var ups: Array = []
var combatants: Array = []


static func create(_setup: RefCounted) -> RefCounted:
	return (load("res://tests/fixtures/battle_stage/stub_battle_controller.gd") as GDScript).new() as RefCounted


func now_usec() -> int:
	return virtual_usec if use_virtual_clock else Time.get_ticks_usec()


func press_down(t_usec: int) -> void:
	downs.append(t_usec)


func press_up(t_usec: int) -> void:
	ups.append(t_usec)


func submit_command(_cmd: Dictionary) -> void:
	pass


func skip_requested() -> void:
	pass


func start() -> void:
	started = true
	battle_started.emit(snapshot())


func snapshot() -> Dictionary:
	_build_combatants()
	return {
		"encounter_id": "stub_fight", "can_run": not is_boss, "is_boss": is_boss, "backdrop": backdrop,
		"combatants": combatants.duplicate(true),
	}


func _build_combatants() -> void:
	combatants.clear()
	var party: Array = [["red", "Red", RED, 62, 40], ["otis", "Otis", OTIS, 95, 30], ["mox", "Mox", MOX, 48, 50]]
	for i: int in party.size():
		var row: Array = party[i]
		combatants.append({
			"id": row[0], "side": "party", "slot": i, "name": row[1], "kind": row[0], "model": row[2],
			"hp": row[3], "hp_max": row[3], "juice": row[4], "juice_max": row[4], "level": 3, "speed": 8,
			"statuses": [], "down": false, "is_boss": false,
		})
	for i: int in mini(enemy_count, enemy_kinds.size()):
		combatants.append({
			"id": "e%d" % (i + 1), "side": "enemy", "slot": i, "name": str(enemy_kinds[i]).capitalize(), "kind": enemy_kinds[i],
			"model": enemy_models[i], "hp": 38, "hp_max": 38, "juice": 0, "juice_max": 0, "level": 2, "speed": 6,
			"statuses": [], "down": false, "is_boss": ("e%d" % (i + 1)) == boss_id,
		})


## An action dictionary like the real controller's (one press by default).
func make_action(actor: String, kind: String, targets: Array, cue_ms: int = 550, owner_id: String = "", side: String = "attack", windup: int = 300, impact: int = 600, end: int = 900) -> Dictionary:
	return {
		"actor": actor, "kind": kind, "skill_id": "", "name": "Test", "targets": targets, "t0_usec": now_usec(),
		"timeline_ms": {"windup": windup, "impact": impact, "end": end},
		"presses": [{"index": 0, "type": "tap", "side": side, "cue_ms": cue_ms, "hold_by_ms": 0, "owner_id": owner_id if not owner_id.is_empty() else actor}],
		"anim": "", "show_name": false,
	}


func _wait(ms: int) -> void:
	if instant or tree == null:
		return
	await tree.create_timer(float(ms) / 1000.0).timeout


## A whole short fight: Red hits e1 (TOTALLY RAD), e1 swings at Red (perfect block), Otis finishes everything.
func run_demo_fight() -> void:
	start()
	await _wait(300)
	round_started.emit(1, ["red", "e1", "otis", "mox"], ["red", "e1", "otis", "mox"])
	turn_started.emit("red")
	var attack: Dictionary = make_action("red", "attack", ["e1"])
	action_started.emit(attack)
	await _wait(600)
	press_judged.emit({"actor": "red", "index": 0, "side": "attack", "rating": "totally_rad", "delta_ms": 6})
	hit.emit({"source": "red", "target": "e1", "amount": 20, "kind": "damage", "blocked": "none", "payback": false})
	stats_changed.emit("e1", 18, 38, 0, 0)
	await _wait(300)
	action_finished.emit(attack)
	turn_started.emit("e1")
	var swing: Dictionary = make_action("e1", "attack", ["red"], 550, "red", "block")
	action_started.emit(swing)
	await _wait(600)
	press_judged.emit({"actor": "red", "index": 0, "side": "block", "rating": "totally_rad", "delta_ms": 3})
	hit.emit({"source": "e1", "target": "red", "amount": 0, "kind": "damage", "blocked": "perfect", "payback": true})
	await _wait(400)
	action_finished.emit(swing)
	for i: int in mini(enemy_count, enemy_kinds.size()):
		var id: String = "e%d" % (i + 1)
		turn_started.emit("otis")
		var finisher: Dictionary = make_action("otis", "attack", [id], 520)
		action_started.emit(finisher)
		await _wait(600)
		press_judged.emit({"actor": "otis", "index": 0, "side": "attack", "rating": "rad", "delta_ms": 40})
		hit.emit({"source": "otis", "target": id, "amount": 40, "kind": "damage", "blocked": "none", "payback": false})
		stats_changed.emit(id, 0, 38, 0, 0)
		combatant_down.emit(id)
		await _wait(700)
		action_finished.emit(finisher)
	battle_ended.emit("win", {"xp": 48, "credits": 100, "drops": [], "level_ups": [], "final_ko_target": "e%d" % mini(enemy_count, enemy_kinds.size())})
