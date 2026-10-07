class_name WorldProgress
extends RefCounted
## The world's memory, in one place: which crates and pickups are open, where the party is, item
## names. Everything goes through GameState's own methods (mark_opened / is_opened / set_location);
## if a GameState does not have them (an older copy in a test), story flags stand in so nothing
## breaks. Pass a GameState as `state` to use a test copy; null means the autoload.

const PATH_GAME_STATE: NodePath = ^"/root/GameState"
const OPENED_FLAG_PREFIX: String = "opened_"


static func game_state(state: Node = null) -> Node:
	if state != null:
		return state
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null(PATH_GAME_STATE) if loop != null else null


static func is_opened(opened_id: String, state: Node = null) -> bool:
	var gs: Node = game_state(state)
	if gs == null or opened_id.is_empty():
		return false
	if gs.has_method("is_opened"):
		return bool(gs.call("is_opened", opened_id))
	return bool(gs.call("get_flag", OPENED_FLAG_PREFIX + opened_id))


static func mark_opened(opened_id: String, state: Node = null) -> void:
	var gs: Node = game_state(state)
	if gs == null or opened_id.is_empty():
		return
	if gs.has_method("mark_opened"):
		gs.call("mark_opened", opened_id)
	else:
		gs.call("set_flag", OPENED_FLAG_PREFIX + opened_id, true)


static func set_location(room_id: String, spawn_id: String, state: Node = null) -> void:
	var gs: Node = game_state(state)
	if gs != null and gs.has_method("set_location"):
		gs.call("set_location", room_id, spawn_id)


static func has_flag(flag_id: String, state: Node = null) -> bool:
	var gs: Node = game_state(state)
	return gs != null and not flag_id.is_empty() and bool(gs.call("get_flag", flag_id))


static func set_flag(flag_id: String, state: Node = null) -> void:
	var gs: Node = game_state(state)
	if gs != null and not flag_id.is_empty():
		gs.call("set_flag", flag_id, true)


static func item_name(item_id: String, state: Node = null) -> String:
	var gs: Node = game_state(state)
	if gs != null:
		return str((gs.call("get_item_info", item_id) as Dictionary).get("name", item_id))
	return item_id.replace("_", " ").capitalize()


## Gives a crate's or pickup's contents: {items: [{item, count}], credits: int} (or the pickup's
## flat {item, count, credits}). Returns {lines: Array[String], ok: bool}: the "Got X!" messages,
## and false when nothing could be taken at all because the bag is full of it.
static func grant(contents: Dictionary, state: Node = null) -> Dictionary:
	var gs: Node = game_state(state)
	var lines: Array[String] = []
	var taken_any: bool = false
	var refused: bool = false
	var entries: Array = []
	if contents.has("items"):
		entries.append_array(contents["items"] as Array)
	if contents.has("item"):
		entries.append({"item": contents["item"], "count": contents.get("count", 1)})
	for entry: Variant in entries:
		var item_id: String = str((entry as Dictionary).get("item", ""))
		var count: int = int((entry as Dictionary).get("count", 1))
		if gs == null or item_id.is_empty():
			continue
		var added: int = int(gs.call("add_item", item_id, count))
		var item_label: String = item_name(item_id, gs)
		if added <= 0:
			refused = true
			lines.append(Placements.text("bag_full", {"item": item_label}))
			continue
		taken_any = true
		if added == 1:
			lines.append(Placements.text("got_item", {"item": item_label}))
		else:
			lines.append(Placements.text("got_items", {"item": item_label, "count": added}))
	var credits: int = int(contents.get("credits", 0))
	if credits > 0 and gs != null:
		gs.call("add_credits", credits)
		taken_any = true
		lines.append(Placements.text("got_credits", {"credits": credits}))
	return {"lines": lines, "ok": taken_any or not refused}
