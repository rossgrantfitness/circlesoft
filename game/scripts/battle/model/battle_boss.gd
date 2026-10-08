class_name BattleBoss
extends RefCounted
## Boss extras as pure functions over a combatant and its enemy data (nothing here is a balance
## value; every number is read from the enemy's entry in battle/enemies.json and the lines from
## text/boss_lines.json). An enemy becomes a "multi-part boss" when its data has:
##   parts:         [{id, name, hp, legs?}]   the rig's parts, hit in order (or the one a command names)
##   phases:        [{id, name, ...}]         the first phase is the rig; entering the last one is the topple
##   cue_scramble:  {by_pairs_broken: [...]}  the jam pulse, one row per number of broken parts
## While the first phase is on, damage to the boss goes to its parts and the boss's HP bar shows the
## parts' total; when the last part breaks the boss topples into the last phase with the HP from
## stats.hp. A boss without parts and phases is just an enemy.


static func is_multi_part(def: Dictionary) -> bool:
	return not (def.get("parts", []) as Array).is_empty() and (def.get("phases", []) as Array).size() >= 2


## Fills in a boss combatant's phase, parts and rig HP pool.
static func setup(c: BattleCombatant, def: Dictionary) -> void:
	if not is_multi_part(def):
		return
	c.phase = str((def["phases"] as Array)[0]["id"])
	c.parts = []
	var total: int = 0
	for part_variant: Variant in def["parts"]:
		var part: Dictionary = part_variant
		var hp: int = int(part.get("hp", 1))
		c.parts.append({"id": str(part["id"]), "name": str(part.get("name", part["id"])), "hp": hp, "hp_max": hp,
			"legs": int(part.get("legs", 1)), "broken": false})
		total += hp
	c.hp_max = total
	c.hp = total
	c.cooldowns = (def.get("start_cooldowns", {}) as Dictionary).duplicate()


## True while the rig still stands (damage goes to parts).
static func on_rig(c: BattleCombatant) -> bool:
	return not c.parts.is_empty() and c.phase == str(c.enemy_data["phases"][0]["id"])


static func broken_count(c: BattleCombatant) -> int:
	var n: int = 0
	for part: Dictionary in c.parts:
		if bool(part["broken"]):
			n += 1
	return n


static func legs_broken(c: BattleCombatant) -> int:
	var n: int = 0
	for part: Dictionary in c.parts:
		if bool(part["broken"]):
			n += int(part["legs"])
	return n


static func parts_total_hp(c: BattleCombatant) -> int:
	var total: int = 0
	for part: Dictionary in c.parts:
		total += int(part["hp"])
	return total


## Puts `amount` on a part: the named one if it is still standing, else the first one standing.
## Returns {dealt, part, broken: bool, all_broken: bool}. The boss's hp becomes the parts' total.
static func damage_parts(c: BattleCombatant, amount: int, wanted_part: String) -> Dictionary:
	var target: Dictionary = {}
	for part: Dictionary in c.parts:
		if not bool(part["broken"]) and str(part["id"]) == wanted_part:
			target = part
	if target.is_empty():
		for part: Dictionary in c.parts:
			if not bool(part["broken"]):
				target = part
				break
	if target.is_empty():
		return {"dealt": 0, "part": "", "broken": false, "all_broken": true}
	target["hp"] = maxi(int(target["hp"]) - amount, 0)
	var broke: bool = int(target["hp"]) <= 0
	if broke:
		target["broken"] = true
	c.hp = parts_total_hp(c)
	return {"dealt": amount, "part": str(target["id"]), "broken": broke, "all_broken": broke and broken_count(c) >= c.parts.size()}


## The jam pulse row for the number of parts broken so far (the last row repeats).
static func pulse_row(def: Dictionary, broken: int) -> Dictionary:
	var rows: Array = (def.get("cue_scramble", {}) as Dictionary).get("by_pairs_broken", [])
	if rows.is_empty():
		return {}
	return rows[clampi(broken, 0, rows.size() - 1)]


## A line for a boss event from text/boss_lines.json, or "". `key` like "rig_turn"; a key may
## hold a list of lines (one is picked) or a list per count under "by_count" (leg_break).
static func line(data: BattleData, boss_id: String, key: String, rng: RandomNumberGenerator, count: int = 0) -> String:
	var lines: Dictionary = (data.boss_lines.get(boss_id, {}) as Dictionary)
	var entry: Variant = lines.get(key, [])
	if entry is Dictionary:
		var by_count: Array = (entry as Dictionary).get("by_count", [])
		if by_count.is_empty():
			return ""
		return str(by_count[clampi(count - 1, 0, by_count.size() - 1)])
	var list: Array = entry as Array
	if list.is_empty():
		return ""
	return str(list[rng.randi_range(0, list.size() - 1)])


## Names and part states for the snapshot / HUD / stage.
static func parts_snapshot(c: BattleCombatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for part: Dictionary in c.parts:
		out.append({"id": part["id"], "name": part["name"], "hp": part["hp"], "hp_max": part["hp_max"],
			"legs": part["legs"], "broken": part["broken"]})
	return out
