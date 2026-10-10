class_name BattleState
extends RefCounted
## The fighters of one battle and the questions you ask about them.

var combatants: Array[BattleCombatant] = []
var _by_id: Dictionary = {}


func add(c: BattleCombatant) -> void:
	combatants.append(c)
	_by_id[c.id] = c


func get_c(id: String) -> BattleCombatant:
	return _by_id.get(id, null)


func side_members(side: String) -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []
	for c: BattleCombatant in combatants:
		if c.side == side:
			out.append(c)
	return out


func active_members(side: String) -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []
	for c: BattleCombatant in combatants:
		if c.side == side and c.is_active():
			out.append(c)
	return out


func opponents_of(c: BattleCombatant) -> Array[BattleCombatant]:
	return active_members(BattleCombatant.SIDE_ENEMY if c.is_party() else BattleCombatant.SIDE_PARTY)


func allies_of(c: BattleCombatant) -> Array[BattleCombatant]:
	return active_members(c.side)


func all_active() -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []
	for c: BattleCombatant in combatants:
		if c.is_active():
			out.append(c)
	return out


func party_wiped() -> bool:
	return active_members(BattleCombatant.SIDE_PARTY).is_empty()


func enemies_cleared() -> bool:
	return active_members(BattleCombatant.SIDE_ENEMY).is_empty()


func snapshot_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: BattleCombatant in combatants:
		out.append(c.to_snapshot())
	return out
