class_name BattleResults
extends RefCounted
## Writes a finished battle back into GameState: each member's level, xp, hp, juice; the bag
## (items used come out, drops go in); and credits. Works on any object shaped like GameState
## (update_member, add_item, remove_item, add_credits), so tests can use their own copy.


static func apply(game_state: Node, outcome: Dictionary) -> void:
	var members: Array = []
	members.append_array(outcome.get("party", []))
	members.append_array(outcome.get("bench", []))
	for member_variant: Variant in members:
		var member: Dictionary = member_variant
		game_state.call("update_member", str(member["id"]), {
			"level": int(member["level"]), "xp": int(member["xp"]),
			"hp": int(member["hp"]), "hp_max": int(member["hp_max"]),
			"juice": int(member["juice"]), "juice_max": int(member["juice_max"])})
	var used: Dictionary = outcome.get("items_used", {})
	for item_id: String in used:
		game_state.call("remove_item", item_id, int(used[item_id]))
	var report: Dictionary = outcome.get("report", {})
	for drop_variant: Variant in report.get("drops", []):
		var drop: Dictionary = drop_variant
		game_state.call("add_item", str(drop["item"]), int(drop["count"]))
	var credits: int = int(report.get("credits", 0))
	if credits > 0:
		game_state.call("add_credits", credits)
