class_name Progression
extends RefCounted
## XP curve, level-ups, skills learned by level, and the bench-XP and late-joiner catch-up rules
## (built and tested now, switched off in characters.json until Vela and Ruo exist).
##
## A "member" is a Dictionary: {id, level, xp, hp, hp_max, juice, juice_max, bonus (optional),
## equipment (optional, {weapon, armor, charm}: its stat bonuses count like boosters)}.

var data: BattleData


func _init(p_data: BattleData = null) -> void:
	data = p_data if p_data != null else BattleData.shared()


func max_level() -> int:
	return data.max_level


## Total XP needed to reach `level` (level 1 = 0).
func xp_for_level(level: int) -> int:
	return int(data.xp_total.get(clampi(level, 1, data.max_level), 0))


## The level a total XP amount is worth (capped at the highest level in the table).
func level_for_xp(xp: int) -> int:
	var level: int = 1
	for lv: int in range(1, data.max_level + 1):
		if xp >= xp_for_level(lv):
			level = lv
	return level


## XP still needed for the next level (0 at the cap).
func xp_to_next(level: int, xp: int) -> int:
	if level >= data.max_level:
		return 0
	return maxi(xp_for_level(level + 1) - xp, 0)


func stats_at(char_id: String, level: int, bonus: Dictionary = {}) -> Dictionary:
	return StatCalc.stats_for(data, char_id, level, bonus)


## Skill ids a character knows at a level, in learn order.
func skills_known(char_id: String, level: int) -> Array[String]:
	var out: Array[String] = []
	for entry_variant: Variant in data.character(char_id).get("skills_by_level", []):
		var entry: Dictionary = entry_variant
		if int(entry.get("level", 1)) <= level:
			out.append(str(entry.get("skill", "")))
	return out


## Skills learned by climbing from `from_level` to `to_level` (exclusive of what was already known).
func skills_learned_between(char_id: String, from_level: int, to_level: int) -> Array[String]:
	var out: Array[String] = []
	for entry_variant: Variant in data.character(char_id).get("skills_by_level", []):
		var entry: Dictionary = entry_variant
		var learn: int = int(entry.get("level", 1))
		if learn > from_level and learn <= to_level:
			out.append(str(entry.get("skill", "")))
	return out


## A fresh member at a level with full HP and Juice.
## `equipment` ({weapon, armor, charm}) is optional; with it the member wears that gear.
func new_member(char_id: String, level: int, equipment: Dictionary = {}) -> Dictionary:
	var lv: int = clampi(level, 1, data.max_level)
	var member: Dictionary = {"id": char_id, "level": lv, "xp": xp_for_level(lv)}
	if not equipment.is_empty():
		member["equipment"] = equipment.duplicate()
	var stats: Dictionary = StatCalc.stats_for_member(data, member)
	member["hp"] = stats["hp"]
	member["hp_max"] = stats["hp"]
	member["juice"] = stats["juice"]
	member["juice_max"] = stats["juice"]
	return member


## Adds XP to a member (changes the Dictionary in place). Returns the level-up record
## {id, from, to, gains: {stat: n}, learned: [skill ids]}, or {} when the level did not change.
## Living members gain current HP and Juice equal to their max increase; Down members stay Down.
func apply_xp(member: Dictionary, xp: int) -> Dictionary:
	var char_id: String = str(member.get("id", ""))
	var from_level: int = int(member.get("level", 1))
	var total: int = int(member.get("xp", xp_for_level(from_level))) + maxi(xp, 0)
	member["xp"] = total
	var to_level: int = maxi(from_level, level_for_xp(total))
	if to_level == from_level:
		return {}
	var bonus: Dictionary = StatCalc.total_bonus(member, data.item_data)
	var before: Dictionary = stats_at(char_id, from_level, bonus)
	var after: Dictionary = stats_at(char_id, to_level, bonus)
	var gains: Dictionary = {}
	for key: String in BattleData.STAT_KEYS:
		var gained: int = int(after[key]) - int(before[key])
		if gained > 0:
			gains[key] = gained
	member["level"] = to_level
	var hp_max: int = int(after["hp"])
	var juice_max: int = int(after["juice"])
	var alive: bool = int(member.get("hp", 0)) > 0
	member["hp_max"] = hp_max
	member["juice_max"] = juice_max
	if alive:
		member["hp"] = mini(int(member.get("hp", 0)) + int(gains.get("hp", 0)), hp_max)
	member["juice"] = mini(int(member.get("juice", 0)) + int(gains.get("juice", 0)), juice_max)
	return {"id": char_id, "from": from_level, "to": to_level, "gains": gains,
		"learned": skills_learned_between(char_id, from_level, to_level)}


# ---- bench XP and catch-up (rules from characters.json; both off for the slice) ----

func bench_xp_enabled() -> bool:
	return bool((data.rules.get("bench_xp", {}) as Dictionary).get("enabled", false))


func catch_up_enabled() -> bool:
	return bool((data.rules.get("catch_up", {}) as Dictionary).get("enabled", false))


## Who earns XP after a win, as {id: share of the XP}. The field party always earns the full
## amount (Down fighters included). The bench earns `share` of it only when the rule is on.
## `rules` overrides characters.json (tests use that); {} reads the data.
func xp_shares(party_ids: Array[String], bench_ids: Array[String], rules: Dictionary = {}) -> Dictionary:
	var bench_rule: Dictionary = rules.get("bench_xp", data.rules.get("bench_xp", {}))
	var shares: Dictionary = {}
	for id: String in party_ids:
		shares[id] = 1.0
	if bool(bench_rule.get("enabled", false)):
		for id: String in bench_ids:
			shares[id] = float(bench_rule.get("share", 1.0))
	return shares


## The level a late joiner starts at: the party's top level minus the offset when the catch-up
## rule is on, otherwise level 1.
func catch_up_level(party_levels: Array[int], rules: Dictionary = {}) -> int:
	var rule: Dictionary = rules.get("catch_up", data.rules.get("catch_up", {}))
	if not bool(rule.get("enabled", false)) or party_levels.is_empty():
		return 1
	var top: int = 1
	for lv: int in party_levels:
		top = maxi(top, lv)
	return clampi(top - int(rule.get("level_offset", 0)), 1, data.max_level)


## A late joiner at the caught-up level, already knowing the skills they would have learned.
func catch_up_member(char_id: String, party_levels: Array[int], rules: Dictionary = {}) -> Dictionary:
	var member: Dictionary = new_member(char_id, catch_up_level(party_levels, rules))
	member["skills"] = skills_known(char_id, int(member["level"]))
	return member
