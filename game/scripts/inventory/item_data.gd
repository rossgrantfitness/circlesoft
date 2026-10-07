class_name ItemData
extends RefCounted
## Loader and validator for data/items/items.json (consumables, boosters, key items) and
## data/items/equipment.json (weapons, armor, charms). Nothing here is a balance value.
##
## ItemData.shared() reads through the DataDB autoload (or a throw-away DataDB when there is none).
## Tests can build one from any provider with get_dict(id) via ItemData.load_from().

const ID_ITEMS: String = "items/items"
const ID_EQUIPMENT: String = "items/equipment"
const DATA_DB_SCRIPT: String = "res://scripts/core/data_db.gd"
const DATA_DB_NODE: NodePath = ^"DataDB"

const SLOT_WEAPON: String = "weapon"
const SLOT_ARMOR: String = "armor"
const SLOT_CHARM: String = "charm"
const SLOTS: Array[String] = ["weapon", "armor", "charm"]
const WEIGHT_HEAVY: String = "heavy"
const WEIGHT_LIGHT: String = "light"
const KINDS: Array[String] = ["heal", "juice", "revive", "cure", "rest", "throwable", "escape", "booster", "key"]
const USE_CONTEXTS: Array[String] = ["battle", "field", "lamp"]
const ITEM_TARGETS: Array[String] = ["one_ally", "one_down_ally", "all_enemies", "one_enemy", "self", "party"]
const EFFECT_KEYS: Array[String] = ["heal_hp", "heal_hp_pct", "restore_juice", "restore_juice_pct", "revive_hp_pct",
		"cure", "damage", "statuses", "escape", "rest", "boost"]
## The shared icon families (about 12 in the design doc, plus one for key items).
const ICON_IDS: Array[String] = ["sword", "hammer", "mace", "staff", "knives", "vest", "charm", "food", "can",
		"bottle", "bomb", "part", "key"]

static var _shared: ItemData = null

## id -> item entry (consumables, boosters and key items), in file order in item_order.
var items: Dictionary = {}
var item_order: Array[String] = []
## id -> gear entry
var gear: Dictionary = {}
var gear_order: Array[String] = []
var starting_gear: Dictionary = {}
var heavy_wearers: Array[String] = []
var max_stack: int = 99
var sell_divisor: int = 2
## The compare block of equipment.json (arrow scoring).
var compare_rules: Dictionary = {}


static func shared() -> ItemData:
	if _shared == null:
		_shared = _load_default()
	return _shared


## Forget the cached copy (tests that edit data call this).
static func clear_shared() -> void:
	_shared = null


static func _load_default() -> ItemData:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var autoload: Node = tree.root.get_node_or_null(DATA_DB_NODE)
		if autoload != null:
			return load_from(autoload)
	var script: GDScript = load(DATA_DB_SCRIPT) as GDScript
	var db: Node = script.new() as Node
	db.call("load_all")
	var data: ItemData = load_from(db)
	db.free()
	return data


static func load_from(provider: Object) -> ItemData:
	var data: ItemData = ItemData.new()
	data._read(provider)
	return data


func _read(provider: Object) -> void:
	var item_doc: Dictionary = (provider.call("get_dict", ID_ITEMS) as Dictionary).duplicate(true)
	max_stack = int(item_doc.get("max_stack", 99))
	sell_divisor = maxi(int(item_doc.get("sell_divisor", 2)), 1)
	for entry_variant: Variant in item_doc.get("items", []):
		var entry: Dictionary = entry_variant
		var id: String = str(entry.get("id", ""))
		items[id] = entry
		item_order.append(id)
	var gear_doc: Dictionary = (provider.call("get_dict", ID_EQUIPMENT) as Dictionary).duplicate(true)
	starting_gear = gear_doc.get("starting_gear", {})
	compare_rules = gear_doc.get("compare", {})
	for who: Variant in gear_doc.get("heavy_armor_wearers", []):
		heavy_wearers.append(str(who))
	for entry_variant: Variant in gear_doc.get("gear", []):
		var entry: Dictionary = entry_variant
		var id: String = str(entry.get("id", ""))
		gear[id] = entry
		gear_order.append(id)


# ---- lookups ----

func has_item(id: String) -> bool:
	return items.has(id)


func item(id: String) -> Dictionary:
	return items.get(id, {})


func has_gear(id: String) -> bool:
	return gear.has(id)


func gear_entry(id: String) -> Dictionary:
	return gear.get(id, {})


## True for any id this data knows (item, key item or gear).
func knows(id: String) -> bool:
	return items.has(id) or gear.has(id)


## The entry for an id from either file, or {} when unknown.
func entry(id: String) -> Dictionary:
	if items.has(id):
		return items[id]
	return gear.get(id, {})


func is_key_item(id: String) -> bool:
	return bool(item(id).get("key", false))


func is_gear(id: String) -> bool:
	return gear.has(id)


func display_name(id: String) -> String:
	var found: Dictionary = entry(id)
	return str(found.get("name", id.replace("_", " ").capitalize()))


func description(id: String) -> String:
	return str(entry(id).get("desc", ""))


func price(id: String) -> int:
	return int(entry(id).get("price", 0))


## Credits one copy sells for: half the price, rounded down. 0 when it cannot be sold.
func sell_price(id: String) -> int:
	if not knows(id) or is_key_item(id):
		return 0
	return floori(float(price(id)) / float(sell_divisor))


## Item ids by kind, in file order.
func ids_of_kind(kind: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in item_order:
		if str(items[id].get("kind", "")) == kind:
			out.append(id)
	return out


func key_item_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in item_order:
		if bool(items[id].get("key", false)):
			out.append(id)
	return out


func gear_ids(slot: String = "") -> Array[String]:
	var out: Array[String] = []
	for id: String in gear_order:
		if slot.is_empty() or str(gear[id].get("slot", "")) == slot:
			out.append(id)
	return out


## Items the battle menu can use: the entries whose use_in has "battle".
func battle_item_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in item_order:
		if (items[id].get("use_in", []) as Array).has("battle"):
			out.append(id)
	return out


func stats_of(id: String) -> Dictionary:
	return (gear.get(id, {}) as Dictionary).get("stats", {})


# ---- validation (the data tests call this) ----

## Cross-reference and range checks. `status_ids` are the ids from statuses.json, `character_ids`
## from characters.json. One message per problem; empty = clean.
func validate(status_ids: Array[String], character_ids: Array[String]) -> Array[String]:
	var errs: Array[String] = []
	var seen: Dictionary = {}
	for id: String in item_order:
		var it: Dictionary = items[id]
		var tag: String = "item %s" % id
		if seen.has(id) or gear.has(id):
			errs.append("%s: id used twice" % tag)
		seen[id] = true
		for key: String in ["name", "desc", "icon", "kind"]:
			if str(it.get(key, "")).is_empty():
				errs.append("%s: missing %s" % [tag, key])
		if not KINDS.has(str(it.get("kind", ""))):
			errs.append("%s: bad kind" % tag)
		if not ICON_IDS.has(str(it.get("icon", ""))):
			errs.append("%s: unknown icon" % tag)
		if not str(it.get("tint", "#FFFFFF")).is_valid_html_color():
			errs.append("%s: bad tint" % tag)
		if int(it.get("price", -1)) < 0:
			errs.append("%s: price must be set (0 or more)" % tag)
		var is_key: bool = bool(it.get("key", false))
		if is_key != (str(it.get("kind", "")) == "key"):
			errs.append("%s: key flag and kind disagree" % tag)
		for ctx: Variant in it.get("use_in", []):
			if not USE_CONTEXTS.has(str(ctx)):
				errs.append("%s: unknown use_in '%s'" % [tag, str(ctx)])
		if is_key:
			if not (it.get("use_in", []) as Array).is_empty() or int(it.get("price", 0)) != 0:
				errs.append("%s: key items are free and never used from the Items menu" % tag)
			continue
		if int(it.get("price", 0)) <= 0:
			errs.append("%s: needs a price above 0" % tag)
		if not ITEM_TARGETS.has(str(it.get("target", ""))):
			errs.append("%s: bad target" % tag)
		var effect: Dictionary = it.get("effect", {})
		if effect.is_empty():
			errs.append("%s: no effect" % tag)
		for key: String in effect:
			if not EFFECT_KEYS.has(key):
				errs.append("%s: unknown effect '%s'" % [tag, key])
		for status_id: Variant in effect.get("cure", []):
			if not status_ids.has(str(status_id)):
				errs.append("%s: cures unknown status %s" % [tag, str(status_id)])
		for entry_variant: Variant in effect.get("statuses", []):
			if not status_ids.has(str((entry_variant as Dictionary).get("id", ""))):
				errs.append("%s: inflicts unknown status" % tag)
		for stat: Variant in (effect.get("boost", {}) as Dictionary):
			if not BattleData.STAT_KEYS.has(str(stat)):
				errs.append("%s: boosts unknown stat %s" % [tag, str(stat)])
		if (it.get("use_in", []) as Array).is_empty():
			errs.append("%s: can be used nowhere" % tag)
	for id: String in gear_order:
		var g: Dictionary = gear[id]
		var tag: String = "gear %s" % id
		if seen.has(id):
			errs.append("%s: id used twice" % tag)
		seen[id] = true
		for key: String in ["name", "desc", "icon", "type"]:
			if str(g.get(key, "")).is_empty():
				errs.append("%s: missing %s" % [tag, key])
		if not ICON_IDS.has(str(g.get("icon", ""))):
			errs.append("%s: unknown icon" % tag)
		if not str(g.get("tint", "#FFFFFF")).is_valid_html_color():
			errs.append("%s: bad tint" % tag)
		if int(g.get("price", 0)) <= 0:
			errs.append("%s: needs a price above 0" % tag)
		var slot: String = str(g.get("slot", ""))
		if not SLOTS.has(slot):
			errs.append("%s: bad slot" % tag)
		var owner: String = str(g.get("owner", ""))
		if not owner.is_empty() and not character_ids.has(owner):
			errs.append("%s: owner %s is not a party member" % [tag, owner])
		if slot == SLOT_WEAPON and owner.is_empty():
			errs.append("%s: weapons belong to one fighter" % tag)
		if slot == SLOT_ARMOR and not [WEIGHT_LIGHT, WEIGHT_HEAVY].has(str(g.get("weight", ""))):
			errs.append("%s: armor needs weight light or heavy" % tag)
		if slot != SLOT_ARMOR and g.has("weight"):
			errs.append("%s: only armor has a weight" % tag)
		for stat: Variant in (g.get("stats", {}) as Dictionary):
			if not BattleData.STAT_KEYS.has(str(stat)):
				errs.append("%s: unknown stat %s" % [tag, str(stat)])
		for status_id: Variant in g.get("block_statuses", []):
			if not status_ids.has(str(status_id)):
				errs.append("%s: blocks unknown status %s" % [tag, str(status_id)])
		if (g.get("stats", {}) as Dictionary).is_empty() and (g.get("block_statuses", []) as Array).is_empty() \
				and (g.get("perks", {}) as Dictionary).is_empty():
			errs.append("%s: does nothing" % tag)
	for who: String in starting_gear:
		if not character_ids.has(who):
			errs.append("starting gear for unknown fighter %s" % who)
		var loadout: Dictionary = starting_gear[who]
		for slot: String in SLOTS:
			var gear_id: String = str(loadout.get(slot, ""))
			if gear_id.is_empty():
				continue
			if not gear.has(gear_id) or str(gear[gear_id].get("slot", "")) != slot:
				errs.append("starting gear %s/%s: '%s' is not %s gear" % [who, slot, gear_id, slot])
	for who: String in heavy_wearers:
		if not character_ids.has(who):
			errs.append("heavy armor wearer %s is not a party member" % who)
	return errs
