class_name BattleTurnOrder
extends RefCounted
## Turn order: fastest first, every round. Ties go to the party, then by slot.

const FIRST_TURN_PARTY: String = "party"
const FIRST_TURN_ENEMIES: String = "enemies"


## Fighters sorted into acting order. `first_turn` ("normal" / "party" / "enemies") puts that
## whole side ahead of the other (the free first turn from touching an enemy from behind).
static func order(members: Array[BattleCombatant], first_turn: String = "normal") -> Array[BattleCombatant]:
	var sorted: Array[BattleCombatant] = members.duplicate()
	sorted.sort_custom(func(a: BattleCombatant, b: BattleCombatant) -> bool:
		return _before(a, b, first_turn))
	return sorted


static func ids(members: Array[BattleCombatant], first_turn: String = "normal") -> Array[String]:
	var out: Array[String] = []
	for c: BattleCombatant in order(members, first_turn):
		out.append(c.id)
	return out


static func _before(a: BattleCombatant, b: BattleCombatant, first_turn: String) -> bool:
	if first_turn == FIRST_TURN_PARTY and a.side != b.side:
		return a.is_party()
	if first_turn == FIRST_TURN_ENEMIES and a.side != b.side:
		return not a.is_party()
	var speed_a: float = a.stat("speed")
	var speed_b: float = b.stat("speed")
	if speed_a != speed_b:
		return speed_a > speed_b
	if a.side != b.side:
		return a.is_party()
	if a.slot != b.slot:
		return a.slot < b.slot
	return a.id < b.id
