class_name WorksData
extends RefCounted
## data/world/works.json: tuning, locks and the little messages of the Spillway and the jammer works.

const DATA_ID: String = "world/works"


static func data() -> Dictionary:
	return DataDB.get_dict(DATA_ID)


static func section(key: String) -> Dictionary:
	return data().get(key, {})


## A message with {tokens} filled in.
static func fill(text: String, tokens: Dictionary) -> String:
	var line: String = text
	for token: String in tokens:
		line = line.replace("{%s}" % token, str(tokens[token]))
	return line


static func card_item() -> String:
	return str(section("cards").get("item", "kasp_access_card"))


## How many of Kasp's cards the party holds (`state` null = the GameState autoload).
static func cards_held(state: Node = null) -> int:
	var gs: Node = WorldProgress.game_state(state)
	return int(gs.call("item_count", card_item())) if gs != null else 0
