class_name FakeSaveManager
extends Node
## Stands in for the SaveManager autoload in field menu tests: counts how often the lamp's save
## screen was asked for.

var opened: int = 0
var rest_asked: bool = false
var last_player: Node = null


func open_lamp_menu(rest: bool = false, player: Node = null) -> Node:
	opened += 1
	rest_asked = rest
	last_player = player
	return null
