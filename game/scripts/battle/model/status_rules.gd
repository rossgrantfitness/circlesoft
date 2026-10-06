class_name BattleStatusRules
extends RefCounted
## Status effect rules as pure functions over the data in statuses.json and formulas.json.


## Chance a status lands. base >= 1.0 always lands (unless resisted); otherwise Luck shifts it.
static func landing_chance(data: BattleData, base: float, attacker_luck: float, target_luck: float, resist: float) -> float:
	var keep: float = clampf(1.0 - resist, 0.0, 1.0)
	if base >= 1.0:
		return keep
	var luck_step: float = data.f("status", "luck_per_point", 0.0)
	var chance: float = base * (1.0 + (attacker_luck - target_luck) * luck_step)
	chance = clampf(chance, data.f("status", "min_chance", 0.0), data.f("status", "max_chance", 1.0))
	return chance * keep


static func flag(data: BattleData, status_id: String, key: String) -> Variant:
	return data.status(status_id).get(key, null)


## True if any status on the fighter stops them using Skills (Noise Ticket).
static func blocks_skills(data: BattleData, c: BattleCombatant) -> bool:
	for status_id: String in c.statuses:
		if bool(data.status(status_id).get("blocks_skills", false)):
			return true
	return false


## True if a status makes the fighter skip the turn (Stunned).
static func skips_turn(data: BattleData, c: BattleCombatant) -> bool:
	for status_id: String in c.statuses:
		if bool(data.status(status_id).get("skips_turn", false)):
			return true
	return false


## Highest random_target_chance among the fighter's statuses (Wobbly), 0 when none.
static func random_target_chance(data: BattleData, c: BattleCombatant) -> float:
	var best: float = 0.0
	for status_id: String in c.statuses:
		best = maxf(best, float(data.status(status_id).get("random_target_chance", 0.0)))
	return best


## Product of the Clutch window multipliers from the fighter's statuses (Butterfingers, Fired Up).
static func window_mult(data: BattleData, c: BattleCombatant) -> float:
	var mult: float = 1.0
	for status_id: String in c.statuses:
		var key: String = str(data.status(status_id).get("window_mult_key", ""))
		if not key.is_empty():
			mult *= data.window_modifier(key)
	return mult


## HP lost at the start of the fighter's turn from Burnt Toast-style statuses.
static func tick_damage(data: BattleData, c: BattleCombatant) -> int:
	var total: int = 0
	var can_down: bool = true
	for status_id: String in c.statuses:
		var def: Dictionary = data.status(status_id)
		var pct: float = float(def.get("hp_loss_pct", 0.0))
		if pct <= 0.0:
			continue
		total += maxi(int(round(float(c.hp_max) * pct / 100.0)), int(def.get("min_hp_loss", 1)))
		if not bool(def.get("can_down", true)):
			can_down = false
	if not can_down:
		total = mini(total, maxi(c.hp - 1, 0))
	return total


## Statuses that end when the battle does.
static func clears_after_battle(data: BattleData, status_id: String) -> bool:
	return bool(data.status(status_id).get("clears_after_battle", true))
