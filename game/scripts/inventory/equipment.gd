class_name Equipment
extends RefCounted
## Who wears what. Each party member has {weapon, armor, charm} item ids ("" = nothing) stored in
## GameState; worn gear is not in the bag, spare copies are. Rules: a weapon (or any gear with an
## owner) fits only its owner, heavy armor fits only the fighters in equipment.json
## heavy_armor_wearers (Otis), the item must be in the bag, and gear never touches Clutch timing.
##
## `state` is the GameState to use (defaults to the autoload; tests pass their own copy).
## NOTE: the interface in docs/m3_plan.md calls the reader Equipment.get(); GDScript cannot give a
## static function that name (it clashes with Object.get), so it is get_equipped().

const SLOTS: Array[String] = ["weapon", "armor", "charm"]

## Reasons from equip_blocker(); "" = allowed.
const WHY_UNKNOWN_MEMBER: String = "unknown_member"
const WHY_BAD_SLOT: String = "bad_slot"
const WHY_UNKNOWN_ITEM: String = "unknown_item"
const WHY_WRONG_SLOT: String = "wrong_slot"
const WHY_WRONG_OWNER: String = "wrong_owner"
const WHY_TOO_HEAVY: String = "too_heavy"
const WHY_NOT_IN_BAG: String = "not_in_bag"
const WHY_BAG_FULL: String = "bag_full"


## {weapon, armor, charm} worn by a member. A member with no stored equipment at all wears the
## starting gear from equipment.json. Always has all three keys.
static func get_equipped(member_id: String, state: Node = null) -> Dictionary:
	var out: Dictionary = {}
	var gs: Node = Bag.resolve_state(state)
	var member: Dictionary = {}
	if gs != null:
		member = gs.call("get_member", member_id)
	var stored: Dictionary = {}
	if member.has("equipment"):
		stored = member["equipment"]
	else:
		stored = ItemData.shared().starting_gear.get(member_id, {})
	for slot: String in SLOTS:
		out[slot] = str(stored.get(slot, ""))
	return out


## Puts `item_id` in `slot` ("" takes the slot's gear off). Returns false (nothing changes) when a
## rule says no; equip_blocker() says which. The old piece goes back to the bag, the new piece
## comes out of it, and hp_max / juice_max follow the new gear (current HP is only clamped).
static func equip(member_id: String, slot: String, item_id: String, state: Node = null) -> bool:
	if not equip_blocker(member_id, slot, item_id, state).is_empty():
		return false
	var gs: Node = Bag.resolve_state(state)
	var worn: Dictionary = get_equipped(member_id, gs)
	var old_id: String = str(worn[slot])
	if old_id == item_id:
		return true
	if not item_id.is_empty():
		gs.call("remove_item", item_id, 1)
	if not old_id.is_empty():
		gs.call("add_item", old_id, 1)
	worn[slot] = item_id
	gs.call("update_member", member_id, {"equipment": worn})
	StatCalc.sync_maximums(member_id, {}, gs)
	return true


static func unequip(member_id: String, slot: String, state: Node = null) -> bool:
	return equip(member_id, slot, "", state)


## "" when the member can put this item in this slot now, else a WHY_* reason.
static func equip_blocker(member_id: String, slot: String, item_id: String, state: Node = null) -> String:
	var gs: Node = Bag.resolve_state(state)
	if gs == null or (gs.call("get_member", member_id) as Dictionary).is_empty():
		return WHY_UNKNOWN_MEMBER
	if not SLOTS.has(slot):
		return WHY_BAD_SLOT
	var worn: Dictionary = get_equipped(member_id, gs)
	if item_id.is_empty():
		return "" if str(worn[slot]).is_empty() or Bag.count(str(worn[slot]), gs) < Bag.max_stack() else WHY_BAG_FULL
	var fit: String = wear_blocker(member_id, item_id)
	if not fit.is_empty():
		return fit
	if str(ItemData.shared().gear_entry(item_id).get("slot", "")) != slot:
		return WHY_WRONG_SLOT
	var old_id: String = str(worn[slot])
	if old_id == item_id:
		return ""
	if Bag.count(item_id, gs) <= 0:
		return WHY_NOT_IN_BAG
	if not old_id.is_empty() and Bag.count(old_id, gs) >= Bag.max_stack():
		return WHY_BAG_FULL
	return ""


## Owner and armor-weight rules only (ignores the bag and the slot). Shops use this for the
## up/down arrows: a fighter who cannot wear the item gets no arrow.
static func wear_blocker(member_id: String, item_id: String) -> String:
	var data: ItemData = ItemData.shared()
	if not data.has_gear(item_id):
		return WHY_UNKNOWN_ITEM
	var g: Dictionary = data.gear_entry(item_id)
	var owner: String = str(g.get("owner", ""))
	if not owner.is_empty() and owner != member_id:
		return WHY_WRONG_OWNER
	if str(g.get("weight", "")) == ItemData.WEIGHT_HEAVY and not data.heavy_wearers.has(member_id):
		return WHY_TOO_HEAVY
	return ""


static func can_wear(member_id: String, item_id: String) -> bool:
	return wear_blocker(member_id, item_id).is_empty()


# ---- what gear does ----

## Total {stat: amount} from a {weapon, armor, charm} loadout.
static func loadout_stats(loadout: Dictionary, data: ItemData = null) -> Dictionary:
	var items: ItemData = data if data != null else ItemData.shared()
	var out: Dictionary = {}
	for slot: String in SLOTS:
		var stats: Dictionary = items.stats_of(str(loadout.get(slot, "")))
		for key: String in stats:
			out[key] = int(out.get(key, 0)) + int(stats[key])
	return out


## Status ids a loadout makes the wearer immune to.
static func loadout_blocks(loadout: Dictionary, data: ItemData = null) -> Array[String]:
	var items: ItemData = data if data != null else ItemData.shared()
	var out: Array[String] = []
	for slot: String in SLOTS:
		for status_id: Variant in items.gear_entry(str(loadout.get(slot, ""))).get("block_statuses", []):
			if not out.has(str(status_id)):
				out.append(str(status_id))
	return out


## Perks of a loadout, e.g. {payback_mult: 1.5}. Numbers from several pieces multiply.
static func loadout_perks(loadout: Dictionary, data: ItemData = null) -> Dictionary:
	var items: ItemData = data if data != null else ItemData.shared()
	var out: Dictionary = {}
	for slot: String in SLOTS:
		var perks: Dictionary = items.gear_entry(str(loadout.get(slot, ""))).get("perks", {})
		for key: String in perks:
			out[key] = float(out.get(key, 1.0)) * float(perks[key])
	return out


## Does the member's gear make them immune to this status?
static func blocks_status(member_id: String, status_id: String, state: Node = null) -> bool:
	return loadout_blocks(get_equipped(member_id, state)).has(status_id)


## How a loadout scores for the up/down arrows (see equipment.json compare).
static func loadout_score(loadout: Dictionary, data: ItemData = null) -> float:
	var items: ItemData = data if data != null else ItemData.shared()
	var rules: Dictionary = items.compare_rules
	var weights: Dictionary = rules.get("stat_weights", {})
	var score: float = 0.0
	var stats: Dictionary = loadout_stats(loadout, items)
	for key: String in stats:
		score += float(stats[key]) * float(weights.get(key, 1.0))
	score += float(rules.get("status_block_value", 2.0)) * float(loadout_blocks(loadout, items).size())
	score += float(rules.get("perk_value", 2.0)) * float(loadout_perks(loadout, items).size())
	return score


## For the shop and Equip arrows: {can_wear, slot, arrow, delta}. arrow is 1 (better than what the
## member wears in that slot), -1 (worse), 0 (same, or the member cannot wear it). delta is
## {stat: change} in the member's stats if they swapped.
static func compare(member_id: String, item_id: String, state: Node = null) -> Dictionary:
	var out: Dictionary = {"can_wear": false, "slot": "", "arrow": 0, "delta": {}}
	var data: ItemData = ItemData.shared()
	if not data.has_gear(item_id) or not can_wear(member_id, item_id):
		return out
	var slot: String = str(data.gear_entry(item_id).get("slot", ""))
	out["can_wear"] = true
	out["slot"] = slot
	var worn: Dictionary = get_equipped(member_id, state)
	var swapped: Dictionary = worn.duplicate()
	swapped[slot] = item_id
	var before: Dictionary = loadout_stats(worn, data)
	var after: Dictionary = loadout_stats(swapped, data)
	var delta: Dictionary = {}
	for key: String in BattleData.STAT_KEYS:
		var change: int = int(after.get(key, 0)) - int(before.get(key, 0))
		if change != 0:
			delta[key] = change
	out["delta"] = delta
	out["arrow"] = signi(int(round(loadout_score(swapped, data) * 100.0)) - int(round(loadout_score(worn, data) * 100.0)))
	return out
