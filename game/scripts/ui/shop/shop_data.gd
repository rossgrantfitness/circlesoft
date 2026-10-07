class_name ShopData
extends RefCounted
## What each shop sells, read from data/shops/*.json (one file per shop, id "shops/<name>"). A shop
## file holds an id, a display name, a kind (general or gear), a greeting and a `stock` list of item
## ids. Prices are not in the shop file: they come from the item data (ItemData), so the shop, the
## sell-back price and the sim never disagree.

const ID_PREFIX: String = "shops/"
const KIND_GENERAL: String = "general"
const KIND_GEAR: String = "gear"
const KINDS: Array[String] = ["general", "gear"]


## Every shop id in the data folder ("test_general", ...), sorted.
static func shop_ids() -> Array[String]:
	var out: Array[String] = []
	for doc_id: String in DataDB.json_ids():
		if doc_id.begins_with(ID_PREFIX):
			out.append(doc_id.trim_prefix(ID_PREFIX))
	out.sort()
	return out


static func has_shop(shop_id: String) -> bool:
	return DataDB.has_json(ID_PREFIX + shop_id)


## {id, name, kind, greeting, stock: Array[String]}, or {} for an unknown shop.
static func load_shop(shop_id: String) -> Dictionary:
	var doc: Dictionary = DataDB.get_dict(ID_PREFIX + shop_id)
	if doc.is_empty():
		return {}
	var stock: Array[String] = []
	for id: Variant in doc.get("stock", []):
		stock.append(str(id))
	return {
		"id": str(doc.get("id", shop_id)),
		"name": str(doc.get("name", shop_id.capitalize())),
		"kind": str(doc.get("kind", KIND_GENERAL)),
		"greeting": str(doc.get("greeting", "")),
		"stock": stock,
	}


## Problems with a shop file, one message each (empty = clean): unknown or duplicate items, a key
## item on the shelf, gear in a general store (or the reverse), a price of 0, a bad kind.
static func validate(shop: Dictionary, items: ItemData = null) -> Array[String]:
	var data: ItemData = items if items != null else ItemData.shared()
	var errs: Array[String] = []
	var tag: String = "shop %s" % str(shop.get("id", "?"))
	if shop.is_empty():
		errs.append("%s: missing" % tag)
		return errs
	var kind: String = str(shop.get("kind", ""))
	if not KINDS.has(kind):
		errs.append("%s: kind must be general or gear" % tag)
	if str(shop.get("name", "")).is_empty():
		errs.append("%s: needs a name" % tag)
	var stock: Array = shop.get("stock", [])
	if stock.is_empty():
		errs.append("%s: sells nothing" % tag)
	var seen: Dictionary = {}
	for id_variant: Variant in stock:
		var id: String = str(id_variant)
		if seen.has(id):
			errs.append("%s: lists %s twice" % [tag, id])
		seen[id] = true
		if not data.knows(id):
			errs.append("%s: unknown item %s" % [tag, id])
			continue
		if data.is_key_item(id):
			errs.append("%s: %s is a key item and can't be sold" % [tag, id])
		if data.price(id) <= 0:
			errs.append("%s: %s has no price" % [tag, id])
		if kind == KIND_GEAR and not data.is_gear(id):
			errs.append("%s: a gear shop only sells gear (%s)" % [tag, id])
		if kind == KIND_GENERAL and data.is_gear(id):
			errs.append("%s: a general store does not sell gear (%s)" % [tag, id])
	return errs
