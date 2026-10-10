extends "res://scripts/core/game_state.gd"
## A GameState copy for the menu tests that can also reorder the party, so the Party page can be
## tested before (or without) the real set_party_order(). Overrides it harmlessly if GameState has it.


func set_party_order(ids: Array[String]) -> bool:
	if ids.size() != _party_ids.size():
		return false
	for id: String in ids:
		if not _party_ids.has(id):
			return false
	_party_ids = ids.duplicate()
	return true
