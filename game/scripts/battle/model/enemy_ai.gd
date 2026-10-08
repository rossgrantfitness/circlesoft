class_name BattleEnemyAI
extends RefCounted
## Enemy decisions: a weighted list of actions, each with optional conditions, read from the
## enemy's data. Conditions (all optional, all must hold):
##   target_lacks_status: s     target_hp_below_pct: n
##   self_hp_below_pct: n       self_hp_above_pct: n
##   round_at_least: n          round_at_most: n
##   allies_alive_at_least: n   allies_alive_at_most: n   (counts the enemy itself)
##   phase_is: id   pairs_broken_at_least: n   pairs_broken_at_most: n   (multi-part bosses)
## A skill with cooldown_turns > 0 is skipped while the enemy's cooldown for it is running.
## An entry can also say "pick": "lowest_hp" to aim at the weakest target (default: random).


## {"skill_id": String, "targets": Array[String]} or {} when nothing is allowed.
static func choose(data: BattleData, enemy: BattleCombatant, state: BattleState, round_number: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[BattleCombatant] = state.opponents_of(enemy)
	if pool.is_empty():
		return {}
	var candidates: Array[Dictionary] = []
	var total: float = 0.0
	for entry_variant: Variant in enemy.enemy_data.get("ai", []):
		var entry: Dictionary = entry_variant
		var cond: Dictionary = entry.get("if", {})
		if not self_conditions_met(cond, enemy, state, round_number):
			continue
		if int(enemy.cooldowns.get(str(entry.get("skill", "")), 0)) > 0:
			continue
		var targets: Array[BattleCombatant] = valid_targets(cond, pool)
		if targets.is_empty():
			continue
		candidates.append({"entry": entry, "targets": targets})
		total += float(entry.get("weight", 1.0))
	if candidates.is_empty():
		return {}
	var roll: float = rng.randf() * total
	var picked: Dictionary = candidates[candidates.size() - 1]
	for candidate: Dictionary in candidates:
		roll -= float((candidate["entry"] as Dictionary).get("weight", 1.0))
		if roll < 0.0:
			picked = candidate
			break
	var entry: Dictionary = picked["entry"]
	var skill_id: String = str(entry.get("skill", ""))
	var skill: Dictionary = data.skill(skill_id)
	var options: Array = picked["targets"]
	var ids: Array[String] = []
	if str(skill.get("target", "one_enemy")) == "all_enemies":
		for c_variant: Variant in options:
			ids.append((c_variant as BattleCombatant).id)
	else:
		ids.append(_pick_target(entry, options, rng).id)
	return {"skill_id": skill_id, "targets": ids}


static func self_conditions_met(cond: Dictionary, enemy: BattleCombatant, state: BattleState, round_number: int) -> bool:
	if cond.has("self_hp_below_pct") and not enemy.hp_pct() < float(cond["self_hp_below_pct"]):
		return false
	if cond.has("self_hp_above_pct") and not enemy.hp_pct() > float(cond["self_hp_above_pct"]):
		return false
	if cond.has("round_at_least") and round_number < int(cond["round_at_least"]):
		return false
	if cond.has("round_at_most") and round_number > int(cond["round_at_most"]):
		return false
	if cond.has("phase_is") and enemy.phase != str(cond["phase_is"]):
		return false
	if cond.has("pairs_broken_at_least") and BattleBoss.broken_count(enemy) < int(cond["pairs_broken_at_least"]):
		return false
	if cond.has("pairs_broken_at_most") and BattleBoss.broken_count(enemy) > int(cond["pairs_broken_at_most"]):
		return false
	var allies: int = state.allies_of(enemy).size()
	if cond.has("allies_alive_at_least") and allies < int(cond["allies_alive_at_least"]):
		return false
	if cond.has("allies_alive_at_most") and allies > int(cond["allies_alive_at_most"]):
		return false
	return true


## The targets a condition set still allows (target_lacks_status, target_hp_below_pct).
static func valid_targets(cond: Dictionary, pool: Array[BattleCombatant]) -> Array[BattleCombatant]:
	var out: Array[BattleCombatant] = []
	for c: BattleCombatant in pool:
		if cond.has("target_lacks_status") and c.has_status(str(cond["target_lacks_status"])):
			continue
		if cond.has("target_hp_below_pct") and not c.hp_pct() < float(cond["target_hp_below_pct"]):
			continue
		out.append(c)
	return out


static func _pick_target(entry: Dictionary, options: Array, rng: RandomNumberGenerator) -> BattleCombatant:
	if str(entry.get("pick", "random")) == "lowest_hp":
		var weakest: BattleCombatant = options[0]
		for c_variant: Variant in options:
			var c: BattleCombatant = c_variant
			if c.hp < weakest.hp:
				weakest = c
		return weakest
	return options[rng.randi_range(0, options.size() - 1)]
