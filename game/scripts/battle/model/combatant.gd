class_name BattleCombatant
extends RefCounted
## One fighter in a battle: live HP/Juice/statuses plus the stats it fights with.

const SIDE_PARTY: String = "party"
const SIDE_ENEMY: String = "enemy"

var id: String = ""
var side: String = SIDE_PARTY
var slot: int = 0
var display_name: String = ""
var kind: String = ""
var model: String = ""
var level: int = 1
var xp: int = 0
var stats: Dictionary = {}
var hp: int = 0
var hp_max: int = 1
var juice: int = 0
var juice_max: int = 0
## status id -> turns left on the afflicted fighter's own turns
var statuses: Dictionary = {}
var down: bool = false
var fled: bool = false
var defending: bool = false
var is_boss: bool = false
var known_skills: Array[String] = []
var attack_skill: String = ""
var status_resist: Dictionary = {}
var flee_at_hp_pct: float = 0.0
var enemy_data: Dictionary = {}
var bonus: Dictionary = {}
## Gear perks, e.g. {payback_mult: 1.5}; gear that blocks statuses is folded into status_resist.
var perks: Dictionary = {}
## Worn gear {weapon, armor, charm} (party only); carried back out in the battle result.
var equipment: Dictionary = {}
## Boss extras (see BattleBoss): the current phase id ("" for ordinary fighters), the parts still
## to break ({id, name, hp, hp_max, legs, broken}) and skill cooldowns (skill id -> own turns left).
var phase: String = ""
var parts: Array[Dictionary] = []
var cooldowns: Dictionary = {}


func is_party() -> bool:
	return side == SIDE_PARTY


func is_active() -> bool:
	return not down and not fled


func stat(key: String) -> float:
	return float(stats.get(key, 0))


func hp_pct() -> float:
	return 100.0 * float(hp) / float(maxi(hp_max, 1))


func has_status(status_id: String) -> bool:
	return statuses.has(status_id)


func to_snapshot() -> Dictionary:
	var ids: Array[String] = []
	for status_id: String in statuses:
		ids.append(status_id)
	var snap: Dictionary = {
		"id": id, "side": side, "slot": slot, "name": display_name, "kind": kind, "model": model,
		"hp": hp, "hp_max": hp_max, "juice": juice, "juice_max": juice_max, "level": level,
		"speed": int(stat("speed")), "statuses": ids, "down": down, "is_boss": is_boss,
		"fled": fled, "defending": defending,
	}
	if not phase.is_empty():
		snap["phase"] = phase
		snap["parts"] = BattleBoss.parts_snapshot(self)
	return snap
