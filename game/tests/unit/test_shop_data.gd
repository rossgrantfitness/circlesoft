extends TestCase
## The shop files in data/shops/: every stocked item resolves in the item data, shops sell the right
## kind of thing, nothing is free or a key item, the layout fits the screen and every shop message
## the logic can give has text.

const STAGE: Vector2 = Vector2(384, 216)


func test_the_slice_has_a_general_store_and_a_gear_shop() -> void:
	var ids: Array[String] = ShopData.shop_ids()
	assert_has(ids, "test_general")
	assert_has(ids, "test_gear")
	assert_eq(ShopData.load_shop("test_general")["kind"], "general")
	assert_eq(ShopData.load_shop("test_gear")["kind"], "gear")


func test_every_shop_file_validates() -> void:
	for id: String in ShopData.shop_ids():
		var errs: Array[String] = ShopData.validate(ShopData.load_shop(id))
		assert_eq(errs, [] as Array[String], id)


func test_every_stocked_item_resolves_and_has_a_price() -> void:
	var items: ItemData = ItemData.shared()
	for id: String in ShopData.shop_ids():
		var shop: Dictionary = ShopData.load_shop(id)
		assert_gt(shop["stock"].size(), 0, id)
		for item_id: String in shop["stock"]:
			assert_true(items.knows(item_id), "%s sells unknown %s" % [id, item_id])
			assert_gt(items.price(item_id), 0, "%s: %s needs a price" % [id, item_id])
			assert_false(items.is_key_item(item_id), "%s: %s is a key item" % [id, item_id])


func test_the_general_store_sells_the_slice_basics() -> void:
	var stock: Array = ShopData.load_shop("test_general")["stock"]
	for id: String in ["ration_bar", "can_of_chili", "canned_coffee", "juice_box", "smelling_salts", "camp_stove"]:
		assert_has(stock, id)


func test_the_gear_shop_sells_the_three_shop_weapons_vests_and_charms() -> void:
	var stock: Array = ShopData.load_shop("test_gear")["stock"]
	for id: String in ["rebar_blade", "rivet_hammer", "pipe_wrench", "padded_work_vest", "hi_vis_vest", "lucky_bolt"]:
		assert_has(stock, id)
	var items: ItemData = ItemData.shared()
	var weapons: int = 0
	for id: String in stock:
		if str(items.gear_entry(id).get("slot", "")) == "weapon":
			weapons += 1
	assert_eq(weapons, 3, "one weapon per fighter, each from a different owner")


func test_validate_catches_bad_shops() -> void:
	var bad: Dictionary = {"id": "bad", "name": "Bad", "kind": "general",
		"stock": ["ration_bar", "ration_bar", "no_such_item", "delivery_crate", "rebar_blade"]}
	var errs: Array[String] = ShopData.validate(bad)
	var joined: String = "\n".join(errs)
	assert_true(joined.contains("twice"), "a repeat")
	assert_true(joined.contains("unknown item no_such_item"), "an unknown item")
	assert_true(joined.contains("key item"), "a key item")
	assert_true(joined.contains("does not sell gear"), "gear in a general store")
	var gear_with_food: Dictionary = {"id": "g", "name": "G", "kind": "gear", "stock": ["ration_bar"]}
	assert_eq(ShopData.validate(gear_with_food).size(), 1)
	assert_gt(ShopData.validate({}).size(), 0)
	assert_gt(ShopData.validate({"id": "x", "name": "X", "kind": "general", "stock": []}).size(), 0, "an empty shelf")


func test_an_unknown_shop_loads_as_nothing() -> void:
	assert_true(ShopData.load_shop("nowhere").is_empty())
	assert_false(ShopData.has_shop("nowhere"))
	assert_true(ShopData.has_shop("test_gear"))


func test_every_shop_window_fits_the_stage() -> void:
	var layout: Dictionary = DataDB.get_dict("ui/shop_ui")
	for key: String in ["command_window", "credits_window", "owned_window", "list_window", "info_window", "quantity_window"]:
		var rect: Dictionary = layout[key]
		assert_ge(float(rect["x"]), 0.0, key)
		assert_ge(float(rect["y"]), 0.0, key)
		assert_le(float(rect["x"]) + float(rect["w"]), STAGE.x, key)
		assert_le(float(rect["y"]) + float(rect["h"]), STAGE.y, key)


func test_every_shop_logic_message_has_text() -> void:
	var reasons: Dictionary = DataDB.get_dict("text/shop")["reasons"]
	for id: String in [ShopLogic.WHY_UNKNOWN, ShopLogic.WHY_BAD_QTY, ShopLogic.WHY_KEY_ITEM, ShopLogic.WHY_NOT_FOR_SALE,
			ShopLogic.WHY_NO_CREDITS, ShopLogic.WHY_BAG_FULL, ShopLogic.WHY_NOT_OWNED]:
		assert_has(reasons, id)
		assert_false(str(reasons[id]).is_empty(), id)


func test_shop_names_and_greetings_fit_the_text_limits() -> void:
	for id: String in ShopData.shop_ids():
		var shop: Dictionary = ShopData.load_shop(id)
		assert_le(str(shop["name"]).length(), 20, id)
		assert_le(str(shop["greeting"]).length(), 88, "%s: greetings are two lines of about 44 characters" % id)
