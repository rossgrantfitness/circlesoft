class_name StatCalc
extends RefCounted
## A fighter's seven stats: the growth-table row for the level (base + growth), plus permanent
## boosters (member "bonus"), plus gear (member "equipment", read through equipment.json).
## Pure functions, except stats()/sync_maximums() which read and write GameState.

const BONUS_KEY: String = "bonus"
const EQUIPMENT_KEY: String = "equipment"


## Base stats for a character at a level (clamped to the table). `bonus` is {stat: flat amount}.
static func stats_for(data: BattleData, char_id: String, level: int, bonus: Dictionary = {}) -> Dictionary:
	var rows: Dictionary = data.growth.get(char_id, {})
	var lv: int = clampi(level, 1, data.max_level)
	var row: Dictionary = rows.get(lv, {})
	var out: Dictionary = {}
	for key: String in BattleData.STAT_KEYS:
		out[key] = int(row.get(key, 1)) + int(bonus.get(key, 0))
	return out


## Adds two {stat: amount} dictionaries.
static func add_bonuses(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate()
	for key: String in b:
		out[key] = int(out.get(key, 0)) + int(b[key])
	return out


## Boosters plus gear for a member dictionary ({bonus, equipment}), as one flat {stat: amount}.
## `items` defaults to the shared item data.
static func total_bonus(member: Dictionary, items: ItemData = null) -> Dictionary:
	var data: ItemData = items if items != null else ItemData.shared()
	var gear: Dictionary = Equipment.loadout_stats(member.get(EQUIPMENT_KEY, {}), data)
	return add_bonuses(member.get(BONUS_KEY, {}), gear)


## A member dictionary's stats at its level with boosters and gear: what a battle fights with.
static func stats_for_member(data: BattleData, member: Dictionary) -> Dictionary:
	return stats_for(data, str(member.get("id", "")), int(member.get("level", 1)), total_bonus(member, data.item_data))


## Stats of a party member in GameState: base + growth + boosters + gear. {} for an unknown member.
## A member with no stored equipment wears the starting gear.
static func stats(member_id: String, state: Node = null) -> Dictionary:
	var parts: Dictionary = breakdown(member_id, state)
	return parts.get("total", {})


## {base, boosters, gear, total}, each {stat: int}, for the Status and Equip screens.
static func breakdown(member_id: String, state: Node = null) -> Dictionary:
	var gs: Node = Bag.resolve_state(state)
	if gs == null:
		return {}
	var member: Dictionary = gs.call("get_member", member_id)
	if member.is_empty():
		return {}
	var data: BattleData = BattleData.shared()
	var base: Dictionary = stats_for(data, member_id, int(member.get("level", 1)))
	var boosters: Dictionary = {}
	var raw_boosters: Dictionary = member.get(BONUS_KEY, {})
	var gear: Dictionary = Equipment.loadout_stats(Equipment.get_equipped(member_id, gs), data.item_data)
	var total: Dictionary = {}
	for key: String in BattleData.STAT_KEYS:
		boosters[key] = int(raw_boosters.get(key, 0))
		if not gear.has(key):
			gear[key] = 0
		total[key] = int(base[key]) + int(boosters[key]) + int(gear[key])
	return {"base": base, "boosters": boosters, "gear": gear, "total": total}


## Stats if `item_id` were worn in `slot` instead of what is there now (for the Equip menu
## preview and the shop arrows). Ignores whether the member may actually wear it.
static func preview(member_id: String, slot: String, item_id: String, state: Node = null) -> Dictionary:
	var gs: Node = Bag.resolve_state(state)
	if gs == null or (gs.call("get_member", member_id) as Dictionary).is_empty():
		return {}
	var data: BattleData = BattleData.shared()
	var member: Dictionary = gs.call("get_member", member_id)
	var worn: Dictionary = Equipment.get_equipped(member_id, gs)
	worn[slot] = item_id
	member[EQUIPMENT_KEY] = worn
	return stats_for(data, member_id, int(member.get("level", 1)), total_bonus(member, data.item_data))


## Brings a member's stored hp_max / juice_max in line with stats() (after equipping or a
## booster). `fill` = {hp: n, juice: n} is added to the current values (a booster fills the part it
## raised); either way the current values are clamped to the new maximums. Down members stay at 0 HP.
static func sync_maximums(member_id: String, fill: Dictionary = {}, state: Node = null) -> void:
	var gs: Node = Bag.resolve_state(state)
	if gs == null:
		return
	var member: Dictionary = gs.call("get_member", member_id)
	if member.is_empty():
		return
	var total: Dictionary = stats(member_id, gs)
	var hp_max: int = int(total["hp"])
	var juice_max: int = int(total["juice"])
	var hp: int = int(member.get("hp", hp_max))
	var juice: int = int(member.get("juice", juice_max))
	if hp > 0:
		hp += int(fill.get("hp", 0))
	juice += int(fill.get("juice", 0))
	gs.call("update_member", member_id, {"hp_max": hp_max, "juice_max": juice_max,
		"hp": clampi(hp, 0, hp_max), "juice": clampi(juice, 0, juice_max)})
