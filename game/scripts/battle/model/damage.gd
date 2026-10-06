class_name BattleDamage
extends RefCounted
## Damage and healing math. Every constant comes from formulas.json via BattleData.


## One hit. power * atk * atk / (atk + defense * weight), then variance, the rating bonus
## (attack presses), Defend, and the block reduction (block presses; 1.0 = blocked completely).
static func hit_damage(data: BattleData, atk: float, power: float, defense: float, rating_mult: float,
		defend_mult: float, block_reduction: float, rng: RandomNumberGenerator) -> int:
	var weight: float = data.f("damage", "defense_weight", 1.0)
	var base: float = power * atk * atk / maxf(atk + defense * weight, 1.0)
	base *= _variance(data, "damage", rng)
	base *= rating_mult * defend_mult
	if block_reduction >= 1.0:
		return 0
	base *= 1.0 - block_reduction
	return maxi(int(round(base)), int(data.f("damage", "min_damage", 1.0)))


## A heal: power * stat, scaled by the rating bonus.
static func heal_amount(data: BattleData, stat_value: float, power: float, flat: float, rating_mult: float,
		rng: RandomNumberGenerator) -> int:
	var amount: float = (power * stat_value + flat) * rating_mult * _variance(data, "heal", rng)
	return maxi(int(round(amount)), 1)


static func _variance(data: BattleData, section: String, rng: RandomNumberGenerator) -> float:
	var pct: float = data.f(section, "variance_pct", 0.0)
	if pct <= 0.0:
		return 1.0
	return 1.0 + rng.randf_range(-pct, pct) / 100.0
