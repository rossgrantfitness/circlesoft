class_name BattleHudStub
extends RefCounted
## A stand-in for BattleController in the HUD tests: it emits exactly the signals documented in
## docs/battle_api.md and records what the HUD submits. Not a test file (it has no test_ methods).

signal battle_started(snap: Dictionary)
signal round_started(round_number: int, order: Array, next_order: Array)
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

## Every command the HUD submitted, in order.
var commands: Array[Dictionary] = []
var _snap: Dictionary = {}


func submit_command(command: Dictionary) -> void:
	commands.append(command)


func snapshot() -> Dictionary:
	return _snap


## Emits battle_started with the default fight: Red, Otis, Mox against two grunts and a drone.
func start(snap: Dictionary = {}) -> void:
	_snap = snap if not snap.is_empty() else default_snapshot()
	battle_started.emit(_snap)


static func combatant(id: String, side: String, slot: int, display_name: String, kind: String, hp: int, hp_max: int, juice: int, juice_max: int) -> Dictionary:
	return {"id": id, "side": side, "slot": slot, "name": display_name, "kind": kind, "model": "", "hp": hp, "hp_max": hp_max,
			"juice": juice, "juice_max": juice_max, "level": 3, "speed": 5, "statuses": [], "down": false, "is_boss": false}


static func default_snapshot() -> Dictionary:
	return {
		"encounter_id": "stub_fight", "can_run": true, "is_boss": false, "backdrop": "road",
		"combatants": [
			combatant("red", "party", 0, "Red", "red", 42, 42, 8, 12),
			combatant("otis", "party", 1, "Otis", "otis", 61, 66, 5, 10),
			combatant("mox", "party", 2, "Mox", "mox", 30, 34, 14, 16),
			combatant("e1", "enemy", 0, "Signals Grunt", "signals_grunt", 38, 38, 0, 0),
			combatant("e2", "enemy", 1, "Signals Grunt", "signals_grunt", 38, 38, 0, 0),
			combatant("e3", "enemy", 2, "Signals Drone", "signals_drone", 22, 22, 0, 0),
		],
	}


## The options Red gets on her turn (matches the command_needed payload in the contract).
static func default_options(can_run: bool = true) -> Dictionary:
	return {
		"attack": true,
		"skills": [
			{"id": "porch_light", "name": "Porch Light", "juice_cost": 4, "usable": true, "target": "one_enemy"},
			{"id": "sweep_the_yard", "name": "Sweep the Yard", "juice_cost": 6, "usable": true, "target": "all_enemies"},
			{"id": "big_swing", "name": "Big Swing", "juice_cost": 10, "usable": false, "target": "one_enemy"},
		],
		"items": [
			{"id": "ration_bar", "name": "Ration Bar", "count": 2, "target": "one_ally"},
			{"id": "smelling_salts", "name": "Smelling Salts", "count": 1, "target": "one_down_ally"},
			{"id": "juice_box", "name": "Juice Box", "count": 0, "target": "one_ally"},
		],
		"defend": true,
		"run": can_run,
	}


## A win report with XP, credits, a drop and one level-up that learns a skill.
static func default_report() -> Dictionary:
	return {
		"xp": 120, "credits": 85,
		"drops": [{"item": "ration_bar", "count": 1}],
		"level_ups": [{"id": "otis", "from": 3, "to": 4, "gains": {"hp": 6, "attack": 2, "heart": 1}, "learned": ["heave_ho"]}],
		"final_ko_target": "e3",
	}
