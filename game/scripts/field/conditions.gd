class_name Conditions
extends RefCounted
## "Is this true right now?" for data: who appears in a room, which line an NPC says, whether a
## pickup is out, what a story scene waits for. A condition is a dictionary; every key present has to hold:
##   beat: "b1_night" or ["b1_night", "b2_otis_joined"]   the story beat is one of these
##   not_beat: same, the beat is none of these
##   flag / flags: a flag or a list of flags, all set      not_flag / not_flags: none set
##   item: an item id (or list) held                       not_item: none held
##   opened / not_opened: crate or pickup ids opened (or not) through GameState
##   any: [condition, ...]                                 at least one of these holds
## An empty (or missing) condition is always true. Pass a GameState as `state` for a test copy; null
## means the autoload.


static func met(condition: Variant, state: Node = null) -> bool:
	if not condition is Dictionary or (condition as Dictionary).is_empty():
		return true
	var gs: Node = WorldProgress.game_state(state)
	if gs == null:
		return false
	var cond: Dictionary = condition
	if cond.has("beat") and not _list(cond["beat"]).has(str(gs.call("get_story_beat"))):
		return false
	if cond.has("not_beat") and _list(cond["not_beat"]).has(str(gs.call("get_story_beat"))):
		return false
	for key: String in ["flag", "flags"]:
		for flag_id: String in _list(cond.get(key, [])):
			if not bool(gs.call("get_flag", flag_id)):
				return false
	for key: String in ["not_flag", "not_flags"]:
		for flag_id: String in _list(cond.get(key, [])):
			if bool(gs.call("get_flag", flag_id)):
				return false
	for item_id: String in _list(cond.get("item", [])):
		if not bool(gs.call("has_item", item_id)):
			return false
	for item_id: String in _list(cond.get("not_item", [])):
		if bool(gs.call("has_item", item_id)):
			return false
	for opened_id: String in _list(cond.get("opened", [])):
		if not WorldProgress.is_opened(opened_id, gs):
			return false
	for opened_id: String in _list(cond.get("not_opened", [])):
		if WorldProgress.is_opened(opened_id, gs):
			return false
	if cond.has("any"):
		var one: bool = false
		for sub: Variant in cond["any"] as Array:
			one = one or met(sub, gs)
		if not one:
			return false
	return true


## The first entry of `variants` whose "if" holds (an entry with no "if" always holds), or {}.
static func pick(variants: Array, state: Node = null) -> Dictionary:
	for entry: Variant in variants:
		if entry is Dictionary and met((entry as Dictionary).get("if", {}), state):
			return entry
	return {}


static func _list(value: Variant) -> Array[String]:
	var items: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			items.append(str(entry))
	elif not str(value).is_empty():
		items.append(str(value))
	return items
