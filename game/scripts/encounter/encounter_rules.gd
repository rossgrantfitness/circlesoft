class_name EncounterRules
extends RefCounted
## Who goes first when a map enemy catches Red, decided from who is facing whom (a standard of
## visible-enemy RPGs, Exploration > Encounters in the design doc):
##   Red touches an enemy that has its back to her while she faces it   -> "party" (free first turn)
##   an enemy catches Red while her back is to it                       -> "enemies" (ambushed)
##   anything else (face to face, or both backs turned)                 -> "normal"
## The cut-offs are in data/world/map_enemies.json ("first_turn"). The result is passed to
## Main.start_battle(..., first_turn) and on to BattleSetup.first_turn.

const FIRST_NORMAL: String = "normal"
const FIRST_PARTY: String = "party"
const FIRST_ENEMIES: String = "enemies"
const DATA_ID: String = "world/map_enemies"
const DEFAULT_BACK_DOT: float = -0.5
const DEFAULT_FACING_DOT: float = 0.0


## `back_dot`: a facing counts as "turned away" when its dot with the line to the other one is at or
## below this (-0.5 = more than 120 degrees away). `facing_dot`: Red must face the enemy at least this much.
static func first_turn(red_pos: Vector3, red_facing: Vector3, enemy_pos: Vector3, enemy_facing: Vector3,
		back_dot: float = DEFAULT_BACK_DOT, facing_dot: float = DEFAULT_FACING_DOT) -> String:
	var to_enemy: Vector3 = _flat(enemy_pos - red_pos)
	if to_enemy.length() < PlayerMotion.MIN_FLAT_LENGTH:
		return FIRST_NORMAL
	to_enemy = to_enemy.normalized()
	var red_dot: float = _flat(red_facing).normalized().dot(to_enemy)
	var enemy_dot: float = _flat(enemy_facing).normalized().dot(-to_enemy)
	var red_turned_away: bool = red_dot <= back_dot
	var enemy_turned_away: bool = enemy_dot <= back_dot
	if red_turned_away and not enemy_turned_away:
		return FIRST_ENEMIES
	if enemy_turned_away and not red_turned_away and red_dot > facing_dot:
		return FIRST_PARTY
	return FIRST_NORMAL


## Same, with the cut-offs read from data/world/map_enemies.json.
static func first_turn_from_data(red_pos: Vector3, red_facing: Vector3, enemy_pos: Vector3, enemy_facing: Vector3) -> String:
	var cfg: Dictionary = DataDB.get_dict(DATA_ID).get("first_turn", {})
	return first_turn(red_pos, red_facing, enemy_pos, enemy_facing,
			float(cfg.get("back_dot", DEFAULT_BACK_DOT)), float(cfg.get("facing_dot", DEFAULT_FACING_DOT)))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
