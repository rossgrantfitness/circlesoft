class_name ShopLogic
extends RefCounted
## Buying and selling. Buy at the item's price; sell at half (rounded down per copy); the bag
## holds at most 99 of anything; key items can be neither bought nor sold; credits never go below 0.
## What a shop stocks lives in data/shops/ (UI); this class only does the money and the bag.
##
## buy()/sell() return true when the whole order went through (nothing changes otherwise);
## buy_blocker()/sell_blocker() say why not ("" = fine) for the menu's message.

const WHY_UNKNOWN: String = "unknown_item"
const WHY_BAD_QTY: String = "bad_quantity"
const WHY_KEY_ITEM: String = "key_item"
const WHY_NOT_FOR_SALE: String = "not_for_sale"
const WHY_NO_CREDITS: String = "not_enough_credits"
const WHY_BAG_FULL: String = "bag_full"
const WHY_NOT_OWNED: String = "not_owned"


static func buy_price(item_id: String) -> int:
	return ItemData.shared().price(item_id)


static func sell_price(item_id: String) -> int:
	return ItemData.shared().sell_price(item_id)


static func buy_blocker(item_id: String, qty: int = 1, state: Node = null) -> String:
	var data: ItemData = ItemData.shared()
	if not data.knows(item_id):
		return WHY_UNKNOWN
	if qty <= 0:
		return WHY_BAD_QTY
	if data.is_key_item(item_id):
		return WHY_KEY_ITEM
	if data.price(item_id) <= 0:
		return WHY_NOT_FOR_SALE
	var gs: Node = Bag.resolve_state(state)
	if gs == null:
		return WHY_UNKNOWN
	if Bag.count(item_id, gs) + qty > data.max_stack:
		return WHY_BAG_FULL
	if int(gs.call("get_credits")) < data.price(item_id) * qty:
		return WHY_NO_CREDITS
	return ""


static func sell_blocker(item_id: String, qty: int = 1, state: Node = null) -> String:
	var data: ItemData = ItemData.shared()
	if not data.knows(item_id):
		return WHY_UNKNOWN
	if qty <= 0:
		return WHY_BAD_QTY
	if data.is_key_item(item_id):
		return WHY_KEY_ITEM
	if Bag.count(item_id, state) < qty:
		return WHY_NOT_OWNED
	return ""


static func can_buy(item_id: String, qty: int = 1, state: Node = null) -> bool:
	return buy_blocker(item_id, qty, state).is_empty()


static func can_sell(item_id: String, qty: int = 1, state: Node = null) -> bool:
	return sell_blocker(item_id, qty, state).is_empty()


## The most the player could buy right now (credits and the 99 cap), for the quantity picker.
static func max_buyable(item_id: String, state: Node = null) -> int:
	var data: ItemData = ItemData.shared()
	var gs: Node = Bag.resolve_state(state)
	if gs == null or not data.knows(item_id) or data.is_key_item(item_id) or data.price(item_id) <= 0:
		return 0
	var by_credits: int = floori(float(gs.call("get_credits")) / float(data.price(item_id)))
	return maxi(mini(by_credits, data.max_stack - Bag.count(item_id, gs)), 0)


## The most the player could sell right now.
static func max_sellable(item_id: String, state: Node = null) -> int:
	if ItemData.shared().is_key_item(item_id) or not ItemData.shared().knows(item_id):
		return 0
	return Bag.count(item_id, state)


static func buy(item_id: String, qty: int = 1, state: Node = null) -> bool:
	if not buy_blocker(item_id, qty, state).is_empty():
		return false
	var gs: Node = Bag.resolve_state(state)
	gs.call("add_credits", -buy_price(item_id) * qty)
	gs.call("add_item", item_id, qty)
	return true


static func sell(item_id: String, qty: int = 1, state: Node = null) -> bool:
	if not sell_blocker(item_id, qty, state).is_empty():
		return false
	var gs: Node = Bag.resolve_state(state)
	gs.call("remove_item", item_id, qty)
	gs.call("add_credits", sell_price(item_id) * qty)
	return true
