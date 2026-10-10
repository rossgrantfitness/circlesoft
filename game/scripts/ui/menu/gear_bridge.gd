class_name GearBridge
extends RefCounted
## The menus' one door to the party, the bag, gear, skills and shop money. It wraps the Battle
## Programmer's logic (Bag, Equipment, StatCalc, ShopLogic, ItemData, all in scripts/inventory and
## scripts/progression) and the GameState, so the field menu pages and the shop never touch those
## rules directly and every "why can't I" comes back as a ready-to-show sentence from
## data/text/field_menu.json ("reasons").
##
## `state` is the GameState to act on (null = the autoload); tests pass their own copy.

const TEXT_ID: String = "text/field_menu"
const SLOTS: Array[String] = ["weapon", "armor", "charm"]
const TAB_ITEMS: String = "items"
const TAB_GEAR: String = "gear"
const TAB_KEY: String = "key"
const TARGET_PARTY: String = "party"
const TARGET_DOWN: String = "one_down_ally"

var state: Node = null


func _init(p_state: Node = null) -> void:
	state = p_state


func st() -> Node:
	return Bag.resolve_state(state)


func data() -> ItemData:
	return ItemData.shared()


func reasons() -> Dictionary:
	return DataDB.get_value(TEXT_ID, "reasons", {})


## One reason sentence by id, with {tokens} filled in from `fill`.
func reason_text(id: String, fill: Dictionary = {}) -> String:
	var line: String = str(reasons().get(id, id))
	for key: String in fill:
		line = line.replace("{%s}" % key, str(fill[key]))
	return line


# ---- the party and the money ----

func party() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gs: Node = st()
	if gs != null:
		out.assign(gs.call("get_party"))
	return out


func party_ids() -> Array[String]:
	var out: Array[String] = []
	for member: Dictionary in party():
		out.append(str(member["id"]))
	return out


func member(member_id: String) -> Dictionary:
	var gs: Node = st()
	return gs.call("get_member", member_id) if gs != null else {}


func member_name(member_id: String) -> String:
	return str(member(member_id).get("name", member_id.capitalize()))


func credits() -> int:
	var gs: Node = st()
	return int(gs.call("get_credits")) if gs != null else 0


func play_time_s() -> int:
	var gs: Node = st()
	return int(floorf(float(gs.call("get_play_time_s")))) if gs != null and gs.has_method("get_play_time_s") else 0


## The room the party is in: {room, spawn}.
func location() -> Dictionary:
	var gs: Node = st()
	return gs.call("get_location") if gs != null and gs.has_method("get_location") else {}


## Writes a new party order. False when GameState has no way to (see docs/m3_plan.md Changes).
func set_party_order(ids: Array[String]) -> bool:
	var gs: Node = st()
	if gs == null or not gs.has_method("set_party_order"):
		return false
	return bool(gs.call("set_party_order", ids))


func can_reorder_party() -> bool:
	var gs: Node = st()
	return gs != null and gs.has_method("set_party_order")


# ---- item facts ----

func entry(item_id: String) -> Dictionary:
	return data().entry(item_id)


func item_name(item_id: String) -> String:
	return data().display_name(item_id)


func item_desc(item_id: String) -> String:
	return data().description(item_id)


func owned(item_id: String) -> int:
	return Bag.count(item_id, st())


func tab_ids(tab: String) -> Array[String]:
	return Bag.ids_for_tab(tab, st())


func is_gear(item_id: String) -> bool:
	return data().is_gear(item_id)


func is_key(item_id: String) -> bool:
	return data().is_key_item(item_id)


func slot_of(item_id: String) -> String:
	return str(data().gear_entry(item_id).get("slot", ""))


# ---- using items ----

## The Bag context for the menu: "lamp" at a save spot, else "field".
static func context_for(at_save_spot: bool) -> String:
	return Bag.CTX_LAMP if at_save_spot else Bag.CTX_FIELD


## "" when the item can be used right now (somewhere), else why not, as a sentence.
func item_reason(item_id: String, context: String) -> String:
	var gs: Node = st()
	if is_key(item_id):
		return reason_text("key_item")
	var why: String = Bag.use_blocker(item_id, context, gs)
	match why:
		"":
			pass
		Bag.WHY_WRONG_PLACE:
			if Bag.place_allows(item_id, Bag.CTX_LAMP):
				return reason_text("lamp_only")
			return reason_text("battle_only")
		Bag.WHY_NOT_OWNED:
			return reason_text("not_owned")
		_:
			return reason_text("cant_use")
	if item_targets(item_id).is_empty():
		return reason_text(_nobody_reason(item_id))
	return ""


func _nobody_reason(item_id: String) -> String:
	var effect: Dictionary = data().item(item_id).get("effect", {})
	if bool(effect.get("rest", false)):
		return "all_rested"
	if effect.has("revive_hp_pct"):
		return "nobody_down"
	return "nobody_needs"


## Party members the item would do something for right now (everyone, for a Camp Stove, when any
## of them needs rest).
func item_targets(item_id: String) -> Array[String]:
	var out: Array[String] = []
	var effect: Dictionary = data().item(item_id).get("effect", {})
	var members: Array[Dictionary] = party()
	if bool(effect.get("rest", false)):
		for who: Dictionary in members:
			if int(who.get("hp", 0)) < int(who.get("hp_max", 0)) or int(who.get("juice", 0)) < int(who.get("juice_max", 0)):
				return party_ids()
		return out
	for who: Dictionary in members:
		if benefits(effect, who):
			out.append(str(who["id"]))
	return out


## Would this effect change anything for this member? (Mirrors Bag.use_item's rules.)
func benefits(effect: Dictionary, who: Dictionary) -> bool:
	var hp: int = int(who.get("hp", 0))
	var hp_max: int = int(who.get("hp_max", 1))
	var juice: int = int(who.get("juice", 0))
	var juice_max: int = int(who.get("juice_max", 0))
	if effect.has("revive_hp_pct"):
		return hp <= 0
	if hp <= 0:
		return false
	if (int(effect.get("heal_hp", 0)) > 0 or float(effect.get("heal_hp_pct", 0.0)) > 0.0) and hp < hp_max:
		return true
	if (int(effect.get("restore_juice", 0)) > 0 or float(effect.get("restore_juice_pct", 0.0)) > 0.0) and juice < juice_max:
		return true
	return effect.has("boost")


## "party" (all at once), "one_down_ally" or "one_ally" (the item's target kind).
func target_kind(item_id: String) -> String:
	return str(data().item(item_id).get("target", "one_ally"))


## Why this member is not a good target ("" = fine), as a sentence.
func member_reason(item_id: String, member_id: String) -> String:
	var effect: Dictionary = data().item(item_id).get("effect", {})
	var who: Dictionary = member(member_id)
	if benefits(effect, who):
		return ""
	if effect.has("revive_hp_pct"):
		return reason_text("not_down", {"name": str(who.get("name", ""))})
	if int(who.get("hp", 0)) <= 0:
		return reason_text("is_down", {"name": str(who.get("name", ""))})
	return reason_text("already_full", {"name": str(who.get("name", ""))})


## Uses the item. Returns Bag.use_item's result {ok, reason, healed_hp, restored_juice}.
func use_item(item_id: String, target_id: String, context: String) -> Dictionary:
	return Bag.use_item(item_id, target_id, context, st())


# ---- gear ----

func equipped(member_id: String) -> Dictionary:
	return Equipment.get_equipped(member_id, st())


## The seven stats with boosters and gear: {hp, juice, attack, defense, heart, speed, luck}.
func stats(member_id: String) -> Dictionary:
	return StatCalc.stats(member_id, st())


func stats_preview(member_id: String, slot: String, item_id: String) -> Dictionary:
	return StatCalc.preview(member_id, slot, item_id, st())


## Spare gear in the bag for a slot, in bag order.
func spare_gear(slot: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in Bag.gear_ids(st()):
		if slot_of(id) == slot:
			out.append(id)
	return out


## "" when the member can wear it now, else a sentence ("Only Otis can wear this.").
func equip_reason(member_id: String, slot: String, item_id: String) -> String:
	var why: String = Equipment.equip_blocker(member_id, slot, item_id, st())
	return _equip_text(why, member_id, item_id)


func _equip_text(why: String, member_id: String, item_id: String) -> String:
	match why:
		"":
			return ""
		Equipment.WHY_WRONG_OWNER:
			var owner: String = str(data().gear_entry(item_id).get("owner", ""))
			return reason_text("wrong_owner", {"owner": member_name(owner)})
		Equipment.WHY_TOO_HEAVY:
			var names: PackedStringArray = PackedStringArray()
			for who: String in data().heavy_wearers:
				names.append(member_name(who))
			return reason_text("too_heavy", {"names": " and ".join(names)})
		Equipment.WHY_NOT_IN_BAG:
			return reason_text("not_in_bag")
		Equipment.WHY_BAG_FULL:
			return reason_text("bag_full_gear")
		_:
			return reason_text("cant_equip")


func equip(member_id: String, slot: String, item_id: String) -> bool:
	return Equipment.equip(member_id, slot, item_id, st())


## {can_wear, slot, arrow, delta} from Equipment.compare (the shop arrows).
func compare(member_id: String, item_id: String) -> Dictionary:
	return Equipment.compare(member_id, item_id, st())


# ---- skills ----

## A member's skills in the order they were learned: [{id, name, cost, desc, usable, reason}].
## Only heals and Juice restores can be cast outside battle.
func skills_of(member_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var who: Dictionary = member(member_id)
	if who.is_empty():
		return out
	var battle: BattleData = BattleData.shared()
	var known: Array[String] = Progression.new(battle).skills_known(member_id, int(who.get("level", 1)))
	for skill_id: String in known:
		var skill: Dictionary = battle.skill(skill_id)
		if skill.is_empty():
			continue
		var row: Dictionary = {"id": skill_id, "name": str(skill.get("name", skill_id)), "cost": int(skill.get("juice_cost", 0)),
			"desc": str(skill.get("desc", "")), "usable": false, "reason": ""}
		var plan: Dictionary = field_skill_plan(skill)
		if plan.is_empty():
			row["reason"] = reason_text("battle_only")
		elif int(who.get("juice", 0)) < int(row["cost"]):
			row["reason"] = reason_text("no_juice")
		elif skill_targets(skill_id).is_empty():
			row["reason"] = reason_text("nobody_needs")
		else:
			row["usable"] = true
		out.append(row)
	return out


## {kind, target, effects} when a skill can be cast in the field (all its effects heal HP or restore
## Juice on allies), else {}.
func field_skill_plan(skill: Dictionary) -> Dictionary:
	var target: String = str(skill.get("target", ""))
	if target != "one_ally" and target != "all_allies" and target != "self":
		return {}
	var effects: Array = skill.get("effects", [])
	if effects.is_empty():
		return {}
	for fx_variant: Variant in effects:
		var kind: String = str((fx_variant as Dictionary).get("kind", ""))
		if kind != "heal" and kind != "restore_juice":
			return {}
	return {"target": target, "effects": effects}


## Who a field skill would help right now (members below full HP / Juice).
func skill_targets(skill_id: String) -> Array[String]:
	var out: Array[String] = []
	var skill: Dictionary = BattleData.shared().skill(skill_id)
	var plan: Dictionary = field_skill_plan(skill)
	if plan.is_empty():
		return out
	for who: Dictionary in party():
		for fx_variant: Variant in plan["effects"]:
			var kind: String = str((fx_variant as Dictionary).get("kind", ""))
			var hurt: bool = int(who.get("hp", 0)) > 0 and int(who.get("hp", 0)) < int(who.get("hp_max", 0))
			var dry: bool = int(who.get("hp", 0)) > 0 and int(who.get("juice", 0)) < int(who.get("juice_max", 0))
			if (kind == "heal" and hurt) or (kind == "restore_juice" and dry):
				out.append(str(who["id"]))
				break
	return out


## Casts a field skill: pays the Juice and heals. Returns {ok, reason, healed: {member_id: hp}}.
func use_skill(user_id: String, skill_id: String, target_id: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "healed": {}}
	var gs: Node = st()
	var battle: BattleData = BattleData.shared()
	var skill: Dictionary = battle.skill(skill_id)
	var plan: Dictionary = field_skill_plan(skill)
	var user: Dictionary = member(user_id)
	if gs == null or plan.is_empty() or user.is_empty():
		result["reason"] = reason_text("battle_only")
		return result
	var cost: int = int(skill.get("juice_cost", 0))
	if int(user.get("juice", 0)) < cost:
		result["reason"] = reason_text("no_juice")
		return result
	var targets: Array[String] = []
	if str(plan["target"]) == "all_allies":
		targets = skill_targets(skill_id)
	elif str(plan["target"]) == "self":
		targets = [user_id]
	else:
		targets = [target_id]
	if targets.is_empty() or (str(plan["target"]) == "one_ally" and not skill_targets(skill_id).has(target_id)):
		result["reason"] = reason_text("nobody_needs")
		return result
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var stat_cache: Dictionary = stats(user_id)
	var healed: Dictionary = {}
	for fx_variant: Variant in plan["effects"]:
		var fx: Dictionary = fx_variant
		var amount: int = BattleDamage.heal_amount(battle, float(stat_cache.get(str(fx.get("stat", "heart")), 1)),
				float(fx.get("power", 0.0)), float(fx.get("flat", 0.0)), 1.0, rng)
		for who_id: String in targets:
			var who: Dictionary = member(who_id)
			if str(fx.get("kind", "")) == "heal":
				var now_hp: int = int(who.get("hp", 0))
				var new_hp: int = mini(now_hp + amount, int(who.get("hp_max", now_hp)))
				gs.call("update_member", who_id, {"hp": new_hp})
				healed[who_id] = int(healed.get(who_id, 0)) + (new_hp - now_hp)
			else:
				var now_juice: int = int(who.get("juice", 0))
				gs.call("update_member", who_id, {"juice": mini(now_juice + amount, int(who.get("juice_max", now_juice)))})
	gs.call("update_member", user_id, {"juice": int(member(user_id).get("juice", 0)) - cost})
	result["ok"] = true
	result["healed"] = healed
	return result


## XP still needed for the next level (0 at the cap).
func xp_to_next(member_id: String) -> int:
	var who: Dictionary = member(member_id)
	return Progression.new().xp_to_next(int(who.get("level", 1)), int(who.get("xp", 0)))


# ---- shop money ----

func buy_price(item_id: String) -> int:
	return ShopLogic.buy_price(item_id)


func sell_price(item_id: String) -> int:
	return ShopLogic.sell_price(item_id)


func max_buyable(item_id: String) -> int:
	return ShopLogic.max_buyable(item_id, st())


func max_sellable(item_id: String) -> int:
	return ShopLogic.max_sellable(item_id, st())


func buy(item_id: String, qty: int) -> bool:
	return ShopLogic.buy(item_id, qty, st())


func sell(item_id: String, qty: int) -> bool:
	return ShopLogic.sell(item_id, qty, st())


func max_stack() -> int:
	return data().max_stack


## "" when `qty` of the item can be bought, else a sentence for the shop message.
func buy_reason(item_id: String, qty: int) -> String:
	return _shop_text(ShopLogic.buy_blocker(item_id, qty, st()))


func sell_reason(item_id: String, qty: int) -> String:
	return _shop_text(ShopLogic.sell_blocker(item_id, qty, st()))


func _shop_text(why: String) -> String:
	if why.is_empty():
		return ""
	return str(DataDB.get_value("text/shop", "reasons.%s" % why, why))
