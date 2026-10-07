class_name FakeTitleSaves
extends Node
## Stands in for the SaveManager autoload in title screen tests: answers the three questions the
## title asks (has_any_save, newest_slot, slot_summary) from fields the test sets.

var saves_exist: bool = false
var newest: int = 0
var summary: Dictionary = {}


func has_any_save() -> bool:
	return saves_exist


func newest_slot() -> int:
	return newest if saves_exist else -1


func slot_summary(_slot: int) -> Dictionary:
	return summary
