class_name Bag
extends RefCounted
## Rules for the one shared bag: the 99 cap, key items kept on their own tab (never sold or
## dropped), and where each item may be used. The counts themselves live in GameState (the
## `state` argument defaults to the GameState autoload; tests pass their own copy).
##
## Contexts for can_use_item / use_item: "battle", "field" (the field menu anywhere) and "lamp"
## (the field menu while standing at a save lamp). The Camp Stove works in "lamp" only.

const CTX_BATTLE: String = "battle"
const CTX_FIELD: String = "field"
const CTX_LAMP: String = "lamp"
const GAME_STATE_NODE: NodePath = ^"GameState"

## Reasons returned by use_item / can_use_reason ("" = fine).
const WHY_UNKNOWN: String = "unknown_item"
const WHY_NOT_OWNED: String = "not_owned"
const WHY_WRONG_PLACE: String = "wrong_place"
const WHY_NO_TARGET: String = "no_target"
const WHY_NO_EFFECT: String = "no_effect"


## The GameState to use: the one passed in, else the autoload.
static func resolve_state(state: Node = null) -> Node:
	if state != null:
		return state
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(GAME_STATE_NODE)


static func max_stack() -> int:
	return ItemData.shared().max_stack


static func count(item_id: String, state: Node = null) -> int:
	var gs: Node = resolve_state(state)
	return int(gs.call("item_count", item_id)) if gs != null else 0


## Everything in the bag for one tab. Tabs: "items" (consumables and boosters), "gear" (spare
## weapons, armor, charms) and "key" (key items).
static func ids_for_tab(tab: String, state: Node = null) -> Array[String]:
	var out: Array[String] = []
	var gs: Node = resolve_state(state)
	if gs == null:
		return out
	var data: ItemData = ItemData.shared()
	for id: String in gs.call("get_item_ids"):
		var in_tab: String = "items"
		if data.is_key_item(id):
			in_tab = "key"
		elif data.is_gear(id):
			in_tab = "gear"
		if in_tab == tab and int(gs.call("item_count", id)) > 0:
			out.append(id)
	return out


static func item_ids(state: Node = null) -> Array[String]:
	return ids_for_tab("items", state)


static func gear_ids(state: Node = null) -> Array[String]:
	return ids_for_tab("gear", state)


static func key_item_ids(state: Node = null) -> Array[String]:
	return ids_for_tab("key", state)


## Adds copies, capped at 99. Returns how many were added (0 for unknown ids).
static func add(item_id: String, qty: int = 1, state: Node = null) -> int:
	var gs: Node = resolve_state(state)
	if gs == null or qty <= 0 or not ItemData.shared().knows(item_id):
		return 0
	return int(gs.call("add_item", item_id, qty))


## Removes copies. False (and nothing changes) when the bag has fewer.
static func remove(item_id: String, qty: int = 1, state: Node = null) -> bool:
	var gs: Node = resolve_state(state)
	return gs != null and bool(gs.call("remove_item", item_id, qty))


## Throws copies away. Key items can never be dropped.
static func can_drop(item_id: String, qty: int = 1, state: Node = null) -> bool:
	var data: ItemData = ItemData.shared()
	return data.knows(item_id) and not data.is_key_item(item_id) and qty > 0 and count(item_id, state) >= qty


static func drop(item_id: String, qty: int = 1, state: Node = null) -> bool:
	if not can_drop(item_id, qty, state):
		return false
	return remove(item_id, qty, state)


# ---- where an item can be used ----

## True when the item may be used in this context right now (so menus can grey it out): it is a
## real, non-key item, the bag has one, and its use_in list allows the place. "lamp" is a "field"
## place too, so "lamp" accepts items marked field or lamp; "field" accepts only items marked field.
static func can_use_item(item_id: String, context: String, state: Node = null) -> bool:
	return use_blocker(item_id, context, state).is_empty()


## "" when the item can be used here, else why not (WHY_*).
static func use_blocker(item_id: String, context: String, state: Node = null) -> String:
	var data: ItemData = ItemData.shared()
	if not data.has_item(item_id) or data.is_key_item(item_id):
		return WHY_UNKNOWN
	if count(item_id, state) <= 0:
		return WHY_NOT_OWNED
	if not place_allows(item_id, context):
		return WHY_WRONG_PLACE
	return ""


## Does the item's use_in list allow this context (ignoring the bag)? Use this for shops and tooltips.
static func place_allows(item_id: String, context: String) -> bool:
	var use_in: Array = ItemData.shared().item(item_id).get("use_in", [])
	if context == CTX_LAMP:
		return use_in.has(CTX_LAMP) or use_in.has(CTX_FIELD)
	return use_in.has(context)


# ---- using an item from the field menu ----

## Uses one item outside battle on `target_id` (ignored for party-wide items like the Camp Stove).
## Returns {ok, reason, healed_hp, restored_juice}. Nothing is spent unless ok. Battle use goes
## through the BattleController instead.
static func use_item(item_id: String, target_id: String, context: String = CTX_FIELD, state: Node = null) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "healed_hp": 0, "restored_juice": 0}
	var why: String = use_blocker(item_id, context, state)
	if not why.is_empty():
		result["reason"] = why
		return result
	var gs: Node = resolve_state(state)
	var effect: Dictionary = ItemData.shared().item(item_id).get("effect", {})
	if bool(effect.get("rest", false)):
		_rest_everyone(gs)
		remove(item_id, 1, state)
		result["ok"] = true
		return result
	var member: Dictionary = gs.call("get_member", target_id)
	if member.is_empty():
		result["reason"] = WHY_NO_TARGET
		return result
	var fields: Dictionary = {}
	var spent: bool = _apply_to_member(effect, member, fields, result)
	if not spent:
		result["reason"] = WHY_NO_EFFECT
		return result
	gs.call("update_member", target_id, fields)
	if fields.has("bonus"):
		var boost: Dictionary = effect.get("boost", {})
		StatCalc.sync_maximums(target_id, {"hp": int(boost.get("hp", 0)), "juice": int(boost.get("juice", 0))}, state)
	remove(item_id, 1, state)
	result["ok"] = true
	return result


static func _rest_everyone(gs: Node) -> void:
	if gs.has_method("rest_party"):
		gs.call("rest_party")
		return
	for member: Dictionary in gs.call("get_party"):
		gs.call("update_member", str(member["id"]), {"hp": member.get("hp_max", 0), "juice": member.get("juice_max", 0)})


## Works out the new member fields for a field effect. False when it would do nothing.
static func _apply_to_member(effect: Dictionary, member: Dictionary, fields: Dictionary, result: Dictionary) -> bool:
	var hp: int = int(member.get("hp", 0))
	var hp_max: int = int(member.get("hp_max", 1))
	var juice: int = int(member.get("juice", 0))
	var juice_max: int = int(member.get("juice_max", 0))
	var alive: bool = hp > 0
	var changed: bool = false
	if effect.has("revive_hp_pct"):
		if alive:
			return false
		fields["hp"] = maxi(int(round(float(hp_max) * float(effect["revive_hp_pct"]) / 100.0)), 1)
		result["healed_hp"] = fields["hp"]
		return true
	var heal: int = int(effect.get("heal_hp", 0)) + int(round(float(hp_max) * float(effect.get("heal_hp_pct", 0.0)) / 100.0))
	if heal > 0 and alive and hp < hp_max:
		fields["hp"] = mini(hp + heal, hp_max)
		result["healed_hp"] = int(fields["hp"]) - hp
		changed = true
	var sip: int = int(effect.get("restore_juice", 0)) + int(round(float(juice_max) * float(effect.get("restore_juice_pct", 0.0)) / 100.0))
	if sip > 0 and alive and juice < juice_max:
		fields["juice"] = mini(juice + sip, juice_max)
		result["restored_juice"] = int(fields["juice"]) - juice
		changed = true
	if effect.has("boost") and alive:
		var bonus: Dictionary = (member.get("bonus", {}) as Dictionary).duplicate()
		var boost: Dictionary = effect["boost"]
		for stat: String in boost:
			bonus[stat] = int(bonus.get(stat, 0)) + int(boost[stat])
		fields["bonus"] = bonus
		changed = true
	return changed
