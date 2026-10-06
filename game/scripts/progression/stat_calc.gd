class_name StatCalc
extends RefCounted
## A fighter's seven stats at a level: the growth-table row plus any flat bonuses (permanent
## boosters, gear) handed in by the caller. Pure function; gear and boosters live elsewhere.


## Base stats for a character at a level (clamped to the table). `bonus` is {stat: flat amount}.
static func stats_for(data: BattleData, char_id: String, level: int, bonus: Dictionary = {}) -> Dictionary:
	var rows: Dictionary = data.growth.get(char_id, {})
	var lv: int = clampi(level, 1, data.max_level)
	var row: Dictionary = rows.get(lv, {})
	var out: Dictionary = {}
	for key: String in BattleData.STAT_KEYS:
		out[key] = int(row.get(key, 1)) + int(bonus.get(key, 0))
	return out
