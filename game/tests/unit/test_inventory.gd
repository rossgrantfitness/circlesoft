extends TestCase
## M3-6: the bag (99 cap, key items), equip rules, charms, StatCalc sums, buying and selling, the
## Camp Stove only at save lamps, boosters. Each test uses its own GameState copy.

const GAME_STATE_SCRIPT: String = "res://scripts/core/game_state.gd"


func _state() -> Node:
	var state: Node = own((load(GAME_STATE_SCRIPT) as GDScript).new() as Node) as Node
	state.call("load_party", tree.root.get_node("DataDB").get_dict("party/party"))
	state.call("reset")
	return state


func _growth(char_id: String, level: int, key: String) -> int:
	return BattleData.shared().growth[char_id][level][key]


# ---- the bag ----

func test_the_bag_caps_every_item_at_99() -> void:
	var state: Node = _state()
	assert_eq(Bag.add("ration_bar", 500, state), 97, "2 in the starting bag, so 97 more fit")
	assert_eq(Bag.count("ration_bar", state), 99)
	assert_eq(Bag.add("ration_bar", 1, state), 0, "full stacks take nothing")
	assert_eq(Bag.add("mystery_goo", 3, state), 0, "unknown ids are refused")
	assert_eq(Bag.max_stack(), 99)


func test_key_items_are_kept_on_their_own_tab_and_cannot_be_dropped() -> void:
	var state: Node = _state()
	Bag.add("courier_job_slip", 1, state)
	Bag.add("kasp_access_card", 3, state)
	Bag.add("rebar_blade", 1, state)
	assert_eq(Bag.key_item_ids(state), ["courier_job_slip", "kasp_access_card"] as Array[String])
	assert_eq(Bag.gear_ids(state), ["rebar_blade"] as Array[String])
	assert_does_not_have(Bag.item_ids(state), "courier_job_slip")
	assert_has(Bag.item_ids(state), "ration_bar")
	assert_false(Bag.drop("courier_job_slip", 1, state), "key items can't be dropped")
	assert_eq(Bag.count("courier_job_slip", state), 1)
	assert_true(Bag.drop("ration_bar", 1, state), "ordinary items can")
	assert_eq(Bag.count("ration_bar", state), 1)
	assert_false(Bag.drop("ration_bar", 5, state), "can't drop more than you hold")


# ---- equip rules ----

func test_new_game_gear_is_the_starting_gear() -> void:
	var state: Node = _state()
	assert_eq(Equipment.get_equipped("red", state), {"weapon": "scrap_sword", "armor": "quilted_lining", "charm": ""})
	assert_eq(Equipment.get_equipped("otis", state)["armor"], "lucky_coveralls")
	assert_eq(state.call("get_equipment", "mox"), Equipment.get_equipped("mox", state), "GameState agrees")


func test_a_member_with_no_stored_gear_wears_the_starting_gear() -> void:
	var state: Node = _state()
	state.call("load_party", {"default_party": ["red"], "members": {"red": {"level": 3, "hp": 10, "hp_max": 10, "juice": 1, "juice_max": 1}}})
	assert_eq(Equipment.get_equipped("red", state)["weapon"], "scrap_sword")


func test_equip_swaps_gear_through_the_bag() -> void:
	var state: Node = _state()
	Bag.add("rebar_blade", 1, state)
	assert_true(Equipment.equip("red", "weapon", "rebar_blade", state))
	assert_eq(Equipment.get_equipped("red", state)["weapon"], "rebar_blade")
	assert_eq(Bag.count("rebar_blade", state), 0, "worn gear leaves the bag")
	assert_eq(Bag.count("scrap_sword", state), 1, "the old weapon goes back in")
	assert_true(Equipment.equip("red", "weapon", "scrap_sword", state), "and can be put back on")
	assert_eq(Bag.count("rebar_blade", state), 1)


func test_you_cannot_equip_what_you_do_not_have() -> void:
	var state: Node = _state()
	assert_false(Equipment.equip("red", "weapon", "rebar_blade", state))
	assert_eq(Equipment.equip_blocker("red", "weapon", "rebar_blade", state), Equipment.WHY_NOT_IN_BAG)
	assert_eq(Equipment.get_equipped("red", state)["weapon"], "scrap_sword", "nothing changed")


func test_weapons_are_locked_to_their_owner() -> void:
	var state: Node = _state()
	Bag.add("rivet_hammer", 1, state)
	Bag.add("rebar_blade", 1, state)
	assert_false(Equipment.equip("red", "weapon", "rivet_hammer", state), "Otis's hammer is not Red's")
	assert_false(Equipment.equip("mox", "weapon", "rebar_blade", state))
	assert_eq(Equipment.equip_blocker("red", "weapon", "rivet_hammer", state), Equipment.WHY_WRONG_OWNER)
	assert_true(Equipment.equip("otis", "weapon", "rivet_hammer", state))
	assert_eq(Bag.count("rivet_hammer", state), 0)
	assert_eq(Bag.count("rebar_blade", state), 1, "the refused swap changed nothing")


func test_character_only_armor_is_locked_too() -> void:
	var state: Node = _state()
	Bag.add("too_many_pockets_vest", 1, state)
	Bag.add("quilted_lining", 1, state)
	assert_false(Equipment.equip("red", "armor", "too_many_pockets_vest", state))
	assert_false(Equipment.equip("otis", "armor", "quilted_lining", state))


func test_heavy_armor_is_for_otis_only() -> void:
	var state: Node = _state()
	Bag.add("lucky_coveralls", 2, state)
	assert_false(Equipment.equip("red", "armor", "lucky_coveralls", state))
	assert_false(Equipment.equip("mox", "armor", "lucky_coveralls", state))
	assert_eq(Equipment.equip_blocker("mox", "armor", "lucky_coveralls", state), Equipment.WHY_TOO_HEAVY)
	assert_true(Equipment.equip("otis", "armor", "lucky_coveralls", state), "Otis may (a spare pair)")


func test_light_armor_and_charms_fit_anyone() -> void:
	var state: Node = _state()
	Bag.add("padded_work_vest", 3, state)
	Bag.add("lucky_bolt", 3, state)
	for who: String in ["red", "otis", "mox"]:
		assert_true(Equipment.equip(who, "armor", "padded_work_vest", state), "%s wears a work vest" % who)
		assert_true(Equipment.equip(who, "charm", "lucky_bolt", state), "%s wears a charm" % who)


func test_gear_only_goes_in_its_own_slot() -> void:
	var state: Node = _state()
	Bag.add("lucky_bolt", 1, state)
	assert_false(Equipment.equip("red", "weapon", "lucky_bolt", state))
	assert_false(Equipment.equip("red", "charm", "ration_bar", state), "items are not gear")
	assert_false(Equipment.equip("red", "hat", "lucky_bolt", state), "no such slot")
	assert_false(Equipment.equip("nobody", "charm", "lucky_bolt", state))


func test_unequip_returns_the_piece_to_the_bag() -> void:
	var state: Node = _state()
	Bag.add("earplugs", 1, state)
	Equipment.equip("red", "charm", "earplugs", state)
	assert_true(Equipment.unequip("red", "charm", state))
	assert_eq(Equipment.get_equipped("red", state)["charm"], "")
	assert_eq(Bag.count("earplugs", state), 1)


func test_equipment_is_stored_in_game_state_per_member() -> void:
	var state: Node = _state()
	Bag.add("pipe_wrench", 1, state)
	Equipment.equip("mox", "weapon", "pipe_wrench", state)
	assert_eq(state.call("get_equipment", "mox")["weapon"], "pipe_wrench")
	assert_eq(state.call("get_equipment", "red")["weapon"], "scrap_sword")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state.call("to_dict")))
	var other: Node = _state()
	other.call("from_dict", saved)
	assert_eq(Equipment.get_equipped("mox", other)["weapon"], "pipe_wrench", "gear survives a save and load")


# ---- charms ----

func test_a_charm_blocks_its_status() -> void:
	var state: Node = _state()
	Bag.add("earplugs", 1, state)
	Bag.add("oven_mitts", 1, state)
	assert_false(Equipment.blocks_status("red", "noise_ticket", state))
	Equipment.equip("red", "charm", "earplugs", state)
	assert_true(Equipment.blocks_status("red", "noise_ticket", state))
	assert_false(Equipment.blocks_status("red", "burnt_toast", state), "only its own status")
	assert_false(Equipment.blocks_status("otis", "noise_ticket", state), "only the wearer")
	Equipment.equip("red", "charm", "oven_mitts", state)
	assert_false(Equipment.blocks_status("red", "noise_ticket", state), "swapped out")
	assert_true(Equipment.blocks_status("red", "burnt_toast", state))


# ---- StatCalc ----

func test_stat_calc_is_base_plus_boosters_plus_gear() -> void:
	var state: Node = _state()
	Bag.add("hi_vis_vest", 1, state)
	Bag.add("lucky_bolt", 1, state)
	Equipment.equip("red", "armor", "hi_vis_vest", state)
	Equipment.equip("red", "charm", "lucky_bolt", state)
	state.call("update_member", "red", {"bonus": {"attack": 2}})
	var parts: Dictionary = StatCalc.breakdown("red", state)
	var total: Dictionary = StatCalc.stats("red", state)
	assert_eq(total, parts["total"])
	# Red is level 3 in party.json. Scrap Sword +3 attack, Hi-Vis +3 defense +2 luck, Lucky Bolt +4 luck.
	assert_eq(parts["base"]["attack"], _growth("red", 3, "attack"))
	assert_eq(total["attack"], _growth("red", 3, "attack") + 2 + 3, "growth + booster + weapon")
	assert_eq(total["defense"], _growth("red", 3, "defense") + 3, "growth + armor")
	assert_eq(total["luck"], _growth("red", 3, "luck") + 2 + 4, "growth + armor + charm")
	assert_eq(total["hp"], _growth("red", 3, "hp"), "no HP gear on")
	assert_eq(total["speed"], _growth("red", 3, "speed"))


func test_stat_calc_for_every_member_and_every_stat_adds_up() -> void:
	var state: Node = _state()
	var data: ItemData = ItemData.shared()
	for who: String in ["red", "otis", "mox"]:
		var worn: Dictionary = Equipment.get_equipped(who, state)
		var total: Dictionary = StatCalc.stats(who, state)
		for key: String in BattleData.STAT_KEYS:
			var expected: int = _growth(who, 3, key)
			for slot: String in ["weapon", "armor", "charm"]:
				expected += int(data.stats_of(str(worn[slot])).get(key, 0))
			assert_eq(total[key], expected, "%s %s" % [who, key])


func test_stat_calc_unknown_member_is_empty() -> void:
	assert_eq(StatCalc.stats("nobody", _state()), {})


func test_equipping_updates_the_maximums_and_only_clamps_current_hp() -> void:
	var state: Node = _state()
	state.call("update_member", "red", {"hp": 10})
	Bag.add("padded_work_vest", 1, state)
	var before: int = int(StatCalc.stats("red", state)["hp"])
	Equipment.equip("red", "armor", "padded_work_vest", state)
	var member: Dictionary = state.call("get_member", "red")
	assert_eq(member["hp_max"], before + 6 - 4, "Padded Work Vest +6 HP replaces Quilted Lining +4")
	assert_eq(member["hp"], 10, "equipping never heals")
	Equipment.unequip("red", "armor", state)
	state.call("update_member", "red", {"hp": member["hp_max"]})
	Equipment.equip("red", "armor", "quilted_lining", state)
	assert_le(int(state.call("get_member", "red")["hp"]), int(state.call("get_member", "red")["hp_max"]), "current HP is clamped to the new maximum")


func test_preview_and_arrows() -> void:
	var state: Node = _state()
	var swapped: Dictionary = StatCalc.preview("red", "weapon", "rebar_blade", state)
	assert_eq(swapped["attack"], StatCalc.stats("red", state)["attack"] + 4, "Rebar +7 replaces Scrap +3")
	var up: Dictionary = Equipment.compare("red", "rebar_blade", state)
	assert_eq(up["arrow"], 1)
	assert_eq(up["delta"], {"attack": 4})
	assert_eq(Equipment.compare("otis", "rebar_blade", state)["arrow"], 0, "Otis can't wear it: no arrow")
	assert_false(Equipment.compare("otis", "rebar_blade", state)["can_wear"])
	Bag.add("pipe_wrench", 1, state)
	Equipment.equip("mox", "weapon", "pipe_wrench", state)
	assert_eq(Equipment.compare("mox", "big_wrench", state)["arrow"], -1, "the old wrench is a downgrade")
	assert_eq(Equipment.compare("mox", "pipe_wrench", state)["arrow"], 0, "same as what he wears")
	assert_eq(Equipment.compare("red", "earplugs", state)["arrow"], 1, "a charm into an empty slot is an upgrade")


# ---- shops ----

func test_buying_spends_credits_and_fills_the_bag() -> void:
	var state: Node = _state()
	state.call("add_credits", 100)
	var before: int = Bag.count("can_of_chili", state)
	assert_true(ShopLogic.buy("can_of_chili", 2, state))
	assert_eq(state.call("get_credits"), 100 - 2 * ItemData.shared().price("can_of_chili"))
	assert_eq(Bag.count("can_of_chili", state), before + 2)


func test_buying_needs_the_credits_and_changes_nothing_when_short() -> void:
	var state: Node = _state()
	state.call("add_credits", 44)
	assert_false(ShopLogic.buy("can_of_chili", 1, state), "45 credits for a can; we have 44")
	assert_eq(ShopLogic.buy_blocker("can_of_chili", 1, state), ShopLogic.WHY_NO_CREDITS)
	assert_eq(state.call("get_credits"), 44)
	assert_eq(Bag.count("can_of_chili", state), 0)
	assert_eq(ShopLogic.max_buyable("can_of_chili", state), 0)
	assert_eq(ShopLogic.max_buyable("ration_bar", state), 2, "44 credits is two ration bars at 15")


func test_buying_respects_the_99_cap_all_or_nothing() -> void:
	var state: Node = _state()
	state.call("add_credits", 100000)
	Bag.add("ration_bar", 90, state)
	assert_eq(Bag.count("ration_bar", state), 92)
	assert_false(ShopLogic.buy("ration_bar", 8, state), "92 + 8 is over the cap")
	assert_eq(ShopLogic.buy_blocker("ration_bar", 8, state), ShopLogic.WHY_BAG_FULL)
	assert_eq(state.call("get_credits"), 100000, "no money taken")
	assert_eq(ShopLogic.max_buyable("ration_bar", state), 7)
	assert_true(ShopLogic.buy("ration_bar", 7, state))
	assert_eq(Bag.count("ration_bar", state), 99)


func test_selling_pays_half_price() -> void:
	var state: Node = _state()
	Bag.add("rebar_blade", 1, state)
	assert_eq(ShopLogic.sell_price("rebar_blade"), ItemData.shared().price("rebar_blade") / 2)
	assert_true(ShopLogic.sell("rebar_blade", 1, state))
	assert_eq(state.call("get_credits"), 190)
	assert_eq(Bag.count("rebar_blade", state), 0)
	assert_true(ShopLogic.sell("ration_bar", 2, state))
	assert_eq(state.call("get_credits"), 190 + 2 * 7, "15 credits sells for 7 (half, rounded down)")


func test_you_cannot_sell_what_you_do_not_have_or_what_you_wear() -> void:
	var state: Node = _state()
	assert_false(ShopLogic.sell("ration_bar", 3, state), "only two on hand")
	assert_false(ShopLogic.sell("scrap_sword", 1, state), "worn gear is not in the bag")
	assert_false(ShopLogic.sell("mystery_goo", 1, state))
	assert_false(ShopLogic.sell("ration_bar", 0, state))
	assert_eq(state.call("get_credits"), 0)


func test_key_items_cannot_be_bought_or_sold() -> void:
	var state: Node = _state()
	state.call("add_credits", 5000)
	Bag.add("bell_tune_napkin", 1, state)
	assert_false(ShopLogic.sell("bell_tune_napkin", 1, state))
	assert_eq(ShopLogic.sell_blocker("bell_tune_napkin", 1, state), ShopLogic.WHY_KEY_ITEM)
	assert_eq(ShopLogic.sell_price("bell_tune_napkin"), 0)
	assert_false(ShopLogic.buy("bell_tune_napkin", 1, state))
	assert_eq(Bag.count("bell_tune_napkin", state), 1)
	assert_eq(state.call("get_credits"), 5000)
	assert_eq(ShopLogic.max_sellable("bell_tune_napkin", state), 0)


func test_selling_a_spare_gear_piece_and_buying_it_back() -> void:
	var state: Node = _state()
	state.call("add_credits", 400)
	assert_true(ShopLogic.buy("rivet_hammer", 1, state))
	assert_true(Equipment.equip("otis", "weapon", "rivet_hammer", state))
	assert_true(ShopLogic.sell("dock_mallet", 1, state), "the spare mallet goes back to the shop")
	assert_eq(state.call("get_credits"), 400 - 360 + 30)


# ---- using items: the Camp Stove, heals, boosters ----

func test_the_camp_stove_only_works_at_a_save_lamp() -> void:
	var state: Node = _state()
	assert_eq(Bag.count("camp_stove", state), 1)
	assert_true(Bag.can_use_item("camp_stove", Bag.CTX_LAMP, state))
	assert_false(Bag.can_use_item("camp_stove", Bag.CTX_FIELD, state), "not out in the field")
	assert_false(Bag.can_use_item("camp_stove", Bag.CTX_BATTLE, state), "not in battle")
	var refused: Dictionary = Bag.use_item("camp_stove", "", Bag.CTX_FIELD, state)
	assert_false(refused["ok"])
	assert_eq(refused["reason"], Bag.WHY_WRONG_PLACE)
	assert_eq(Bag.count("camp_stove", state), 1, "a refused stove is not spent")
	state.call("update_member", "red", {"hp": 1, "juice": 0})
	state.call("update_member", "otis", {"hp": 0})
	assert_true(Bag.use_item("camp_stove", "", Bag.CTX_LAMP, state)["ok"])
	assert_eq(Bag.count("camp_stove", state), 0)
	for member: Dictionary in state.call("get_party"):
		assert_eq(member["hp"], member["hp_max"], "%s full HP" % member["id"])
		assert_eq(member["juice"], member["juice_max"], "%s full Juice" % member["id"])
	assert_false(Bag.can_use_item("camp_stove", Bag.CTX_LAMP, state), "and none left to use")


func test_where_each_kind_of_item_can_be_used() -> void:
	var state: Node = _state()
	for id: String in ["ration_bar", "can_of_chili", "canned_coffee", "juice_box", "smelling_salts", "burn_gel",
			"appeal_form", "ginger_chews", "firecracker_string", "hot_sauce_bomb", "smoke_bomb", "protein_shake", "camp_stove"]:
		Bag.add(id, 1, state)
	for id: String in ["ration_bar", "can_of_chili", "canned_coffee", "juice_box", "smelling_salts"]:
		assert_true(Bag.can_use_item(id, Bag.CTX_BATTLE, state), "%s in battle" % id)
		assert_true(Bag.can_use_item(id, Bag.CTX_FIELD, state), "%s in the field" % id)
		assert_true(Bag.can_use_item(id, Bag.CTX_LAMP, state), "%s at a lamp (a lamp is in the field)" % id)
	for id: String in ["burn_gel", "appeal_form", "ginger_chews", "firecracker_string", "hot_sauce_bomb", "smoke_bomb"]:
		assert_true(Bag.can_use_item(id, Bag.CTX_BATTLE, state), "%s in battle" % id)
		assert_false(Bag.can_use_item(id, Bag.CTX_FIELD, state), "%s only in battle" % id)
	assert_false(Bag.can_use_item("protein_shake", Bag.CTX_BATTLE, state))
	assert_true(Bag.can_use_item("protein_shake", Bag.CTX_FIELD, state))
	Bag.add("courier_job_slip", 1, state)
	assert_false(Bag.can_use_item("courier_job_slip", Bag.CTX_FIELD, state), "key items are never used from the menu")
	assert_false(Bag.can_use_item("can_of_chili", Bag.CTX_FIELD, _state()), "none in the bag, so greyed out")


func test_a_heal_in_the_field_heals_and_is_spent() -> void:
	var state: Node = _state()
	state.call("update_member", "red", {"hp": 10})
	var result: Dictionary = Bag.use_item("ration_bar", "red", Bag.CTX_FIELD, state)
	assert_true(result["ok"])
	assert_eq(state.call("get_member", "red")["hp"], 40)
	assert_eq(result["healed_hp"], 30)
	assert_eq(Bag.count("ration_bar", state), 1)
	state.call("update_member", "otis", {"hp": state.call("get_member", "otis")["hp_max"]})
	var full: Dictionary = Bag.use_item("ration_bar", "otis", Bag.CTX_FIELD, state)
	assert_false(full["ok"], "Otis is not hurt")
	assert_eq(full["reason"], Bag.WHY_NO_EFFECT)
	assert_eq(Bag.count("ration_bar", state), 1, "an unused heal is not spent")


func test_heals_cannot_raise_a_downed_fighter_but_smelling_salts_can() -> void:
	var state: Node = _state()
	state.call("update_member", "mox", {"hp": 0})
	Bag.add("can_of_chili", 1, state)
	assert_false(Bag.use_item("can_of_chili", "mox", Bag.CTX_FIELD, state)["ok"], "a chili can't wake the Downed")
	assert_true(Bag.use_item("smelling_salts", "mox", Bag.CTX_FIELD, state)["ok"])
	var mox: Dictionary = state.call("get_member", "mox")
	assert_eq(mox["hp"], int(round(float(mox["hp_max"]) * 0.25)), "back up with 25%")
	assert_false(Bag.use_item("smelling_salts", "red", Bag.CTX_FIELD, state)["ok"], "salts only work on the Downed")


func test_juice_items_restore_juice() -> void:
	var state: Node = _state()
	state.call("update_member", "otis", {"juice": 1})
	Bag.add("canned_coffee", 1, state)
	assert_true(Bag.use_item("canned_coffee", "otis", Bag.CTX_FIELD, state)["ok"])
	assert_eq(state.call("get_member", "otis")["juice"], 7)


func test_a_booster_raises_a_stat_for_good() -> void:
	var state: Node = _state()
	Bag.add("protein_shake", 1, state)
	var before: Dictionary = StatCalc.stats("mox", state)
	assert_true(Bag.use_item("protein_shake", "mox", Bag.CTX_FIELD, state)["ok"])
	assert_eq(StatCalc.stats("mox", state)["attack"], before["attack"] + 2)
	assert_eq(state.call("get_member", "mox")["bonus"]["attack"], 2, "kept in the member's booster bonus (saved)")
	assert_eq(Bag.count("protein_shake", state), 0)
	# Still there after a level-up and a weapon swap.
	Bag.add("pipe_wrench", 1, state)
	Equipment.equip("mox", "weapon", "pipe_wrench", state)
	state.call("update_member", "mox", {"level": 5})
	assert_eq(StatCalc.stats("mox", state)["attack"], _growth("mox", 5, "attack") + 2 + 5)
