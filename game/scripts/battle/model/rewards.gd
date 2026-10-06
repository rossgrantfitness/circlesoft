class_name BattleRewards
extends RefCounted
## What a win pays: XP, credits and item drops. Drops are rolled with the party's Luck.
## Enemies that waved a white flag and left pay what formulas.json "rewards.flee" says.


## {xp, credits, drops: [{item, count}]}. `enemies` is every enemy of the fight (down or fled).
static func compute(data: BattleData, enemies: Array[BattleCombatant], party_luck: float,
		rng: RandomNumberGenerator) -> Dictionary:
	var flee: Dictionary = (data.formulas.get("rewards", {}) as Dictionary).get("flee", {})
	var xp: float = 0.0
	var credits: float = 0.0
	var drop_counts: Dictionary = {}
	var drop_order: Array[String] = []
	for enemy: BattleCombatant in enemies:
		var xp_mult: float = 1.0
		var credit_mult: float = 1.0
		var drop_mult: float = 1.0
		if enemy.fled:
			xp_mult = float(flee.get("xp", 1.0))
			credit_mult = float(flee.get("credits", 1.0))
			drop_mult = float(flee.get("drops", 0.0))
		elif not enemy.down:
			continue
		xp += float(enemy.enemy_data.get("xp", 0)) * xp_mult
		credits += float(enemy.enemy_data.get("credits", 0)) * credit_mult
		if drop_mult <= 0.0:
			continue
		for drop_variant: Variant in enemy.enemy_data.get("drops", []):
			var drop: Dictionary = drop_variant
			if rng.randf() < drop_chance(data, float(drop.get("chance", 0.0)), party_luck):
				var item_id: String = str(drop.get("item", ""))
				if not drop_counts.has(item_id):
					drop_counts[item_id] = 0
					drop_order.append(item_id)
				drop_counts[item_id] = int(drop_counts[item_id]) + 1
	var drops: Array[Dictionary] = []
	for item_id: String in drop_order:
		drops.append({"item": item_id, "count": int(drop_counts[item_id])})
	return {"xp": int(round(xp)), "credits": int(round(credits)), "drops": drops}


## Luck raises a drop's chance (capped).
static func drop_chance(data: BattleData, base: float, luck: float) -> float:
	var chance: float = base * (1.0 + luck * data.f("drops", "luck_per_point", 0.0))
	return minf(chance, data.f("drops", "max_chance", 1.0))
