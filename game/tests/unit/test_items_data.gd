extends TestCase
## M3-6: items.json and equipment.json hold the design doc's slice list, every reference is valid,
## and battles read their item effects from the same file (one source of truth).

const WEAPONS: Array[String] = ["scrap_sword", "rebar_blade", "bread_knife", "dock_mallet", "rivet_hammer", "big_wrench", "pipe_wrench"]
const ARMOR: Array[String] = ["quilted_lining", "lucky_coveralls", "too_many_pockets_vest", "padded_work_vest", "hi_vis_vest"]
const CHARMS: Array[String] = ["lucky_bolt", "earplugs", "oven_mitts", "sore_loser_patch"]
const ITEMS: Array[String] = ["ration_bar", "can_of_chili", "canned_coffee", "juice_box", "smelling_salts", "burn_gel",
		"appeal_form", "ginger_chews", "camp_stove", "firecracker_string", "hot_sauce_bomb", "smoke_bomb", "protein_shake"]
const KEY_ITEMS: Array[String] = ["courier_job_slip", "delivery_crate", "side_job_parcel", "kasp_access_card",
		"bell_tune_napkin", "beacon_part", "courier_pass"]


func _data() -> ItemData:
	return ItemData.load_from(tree.root.get_node("DataDB"))


func test_the_slice_list_is_all_there() -> void:
	var data: ItemData = _data()
	assert_eq(data.gear_ids("weapon"), WEAPONS, "7 weapons")
	assert_eq(data.gear_ids("armor"), ARMOR, "5 armor")
	assert_eq(data.gear_ids("charm"), CHARMS, "4 charms")
	var consumables: Array[String] = []
	for id: String in data.item_order:
		if not data.is_key_item(id):
			consumables.append(id)
	assert_eq(consumables, ITEMS, "13 items")
	assert_eq(data.key_item_ids(), KEY_ITEMS, "7 key items (the Courier Pass joined at VS-14)")


func test_data_validates_with_no_problems() -> void:
	var battle: BattleData = BattleTestKit.fresh_data(tree)
	assert_eq(battle.validate(), [] as Array[String], "battle data including items and gear")
	var status_ids: Array[String] = []
	status_ids.assign(battle.statuses.keys())
	assert_eq(_data().validate(status_ids, battle.character_order), [] as Array[String])


func test_every_entry_has_a_name_price_description_and_icon() -> void:
	var data: ItemData = _data()
	for id: String in data.item_order + data.gear_order:
		var e: Dictionary = data.entry(id)
		assert_false(str(e.get("name", "")).is_empty(), "%s name" % id)
		assert_false(str(e.get("desc", "")).is_empty(), "%s description" % id)
		assert_true(ItemData.ICON_IDS.has(str(e.get("icon", ""))), "%s icon id" % id)
		if data.is_key_item(id):
			assert_eq(data.price(id), 0, "%s is free (never sold)" % id)
		else:
			assert_gt(data.price(id), 0, "%s has a price" % id)


func test_icons_stay_a_small_shared_set() -> void:
	var data: ItemData = _data()
	var used: Dictionary = {}
	for id: String in data.item_order + data.gear_order:
		used[str(data.entry(id)["icon"])] = true
	assert_le(used.size(), 13, "about 12 icons for Ross, recolored per item")


func test_weapons_belong_to_one_fighter_and_every_fighter_has_starting_gear() -> void:
	var data: ItemData = _data()
	var battle: BattleData = BattleTestKit.fresh_data(tree)
	for id: String in data.gear_ids("weapon"):
		assert_true(battle.character_order.has(str(data.gear_entry(id)["owner"])), "%s has an owner" % id)
	for who: String in battle.character_order:
		var loadout: Dictionary = data.starting_gear.get(who, {})
		assert_false(str(loadout.get("weapon", "")).is_empty(), "%s starts with a weapon" % who)
		assert_false(str(loadout.get("armor", "")).is_empty(), "%s starts with armor" % who)
		for slot: String in ItemData.SLOTS:
			var gear_id: String = str(loadout.get(slot, ""))
			assert_true(gear_id.is_empty() or Equipment.can_wear(who, gear_id), "%s may wear their own %s" % [who, slot])


func test_party_json_starts_everyone_in_the_starting_gear() -> void:
	var data: ItemData = _data()
	var members: Dictionary = tree.root.get_node("DataDB").get_dict("party/party")["members"]
	for who: String in data.starting_gear:
		assert_eq(members[who]["equipment"], data.starting_gear[who], "%s in party.json" % who)


func test_the_four_slice_statuses_have_a_cure_and_a_charm() -> void:
	var data: ItemData = _data()
	var cured: Array[String] = []
	for id: String in data.item_order:
		for status_id: Variant in (data.item(id).get("effect", {}) as Dictionary).get("cure", []):
			cured.append(str(status_id))
	for status_id: String in ["burnt_toast", "noise_ticket", "wobbly"]:
		assert_has(cured, status_id, "an item cures %s" % status_id)
	var blocked: Array[String] = []
	for id: String in data.gear_ids("charm"):
		for status_id: Variant in data.gear_entry(id).get("block_statuses", []):
			blocked.append(str(status_id))
	assert_has(blocked, "noise_ticket")
	assert_has(blocked, "burnt_toast")


func test_battle_items_come_from_items_json() -> void:
	var battle: BattleData = BattleTestKit.fresh_data(tree)
	var data: ItemData = _data()
	assert_eq(battle.battle_items.keys(), data.battle_item_ids())
	for id: String in data.battle_item_ids():
		var entry: Dictionary = battle.battle_item(id)
		assert_eq(entry["name"], data.display_name(id), "%s: one name" % id)
		assert_eq(entry["effect"], data.item(id)["effect"], "%s: one effect" % id)
	for id: String in ["camp_stove", "protein_shake"]:
		assert_false(battle.battle_items.has(id), "%s is not a battle item" % id)
	for id: String in KEY_ITEMS:
		assert_false(battle.battle_items.has(id), "key items never show in battle")
	assert_eq(tree.root.get_node("DataDB").get_dict("battle/battle_items")["items"], [], "the old file is retired, not a second source")


func test_every_enemy_drop_is_a_real_item() -> void:
	var battle: BattleData = BattleTestKit.fresh_data(tree)
	var data: ItemData = _data()
	for enemy_id: String in battle.enemies:
		for drop: Dictionary in battle.enemy(enemy_id).get("drops", []):
			assert_true(data.has_item(str(drop["item"])) or data.has_gear(str(drop["item"])), "%s drops %s" % [enemy_id, drop["item"]])


func test_prices_follow_the_economy_targets() -> void:
	var data: ItemData = _data()
	# Healing stays cheap; the three shop weapons plus both shop vests cost more than the ~1,500
	# credits the player has by the Kasp fight, so there is one real choice.
	for id: String in ["ration_bar", "can_of_chili", "canned_coffee", "juice_box", "smelling_salts"]:
		assert_le(data.price(id), 60, "%s stays cheap" % id)
	var weapons: int = data.price("rebar_blade") + data.price("rivet_hammer") + data.price("pipe_wrench")
	var vests: int = data.price("padded_work_vest") + data.price("hi_vis_vest")
	assert_le(weapons, 1500, "the three shop weapons are affordable")
	assert_gt(weapons + vests, 1500, "...but not with every vest as well")
	for id: String in data.gear_ids():
		assert_eq(data.sell_price(id), floori(float(data.price(id)) / 2.0), "%s sells for half" % id)
