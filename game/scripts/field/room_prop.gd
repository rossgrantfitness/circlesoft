class_name RoomProp
extends Node3D
## Base for the things Red uses in a room with the one button: doors, pickups, crates, climb and
## hop spots. It makes the prop's Interactable (the pop-up icon and the reach come from there), finds
## the FieldRoom it stands in, and keeps the hooks tests need (a GameState copy).
##
## A prop scene may supply its own look: a child called "Model" replaces the placeholder boxes.

const MODEL_NODE: NodePath = ^"Model"
const NODE_INTERACTABLE: String = "Interactable"

## The key in data/world/placements.json.
@export var placement_id: String = ""
## GameState to use. Null means the autoload (tests pass their own).
var game_state: Node = null
var tuning: ExplorationTuning = null
var interactable: Interactable = null

## The last messages this prop showed (tests read them).
var last_messages: Array[String] = []

var _room_cache: FieldRoom = null


func _init() -> void:
	tuning = ExplorationTuning.from_db()


func has_custom_model() -> bool:
	return get_node_or_null(MODEL_NODE) != null


## The FieldRoom this prop is part of (null when it stands alone, as in a unit test).
func get_room() -> FieldRoom:
	if _room_cache == null or not is_instance_valid(_room_cache):
		var node: Node = get_parent()
		while node != null and not node is FieldRoom:
			node = node.get_parent()
		_room_cache = node as FieldRoom
	return _room_cache


func get_player() -> PlayerController:
	var room: FieldRoom = get_room()
	return room.player if room != null else null


func get_interactor() -> PlayerInteractor:
	var room: FieldRoom = get_room()
	return room.interactor if room != null else null


## Adds the Interactable child that Red's button finds.
func make_interactable(kind: Interactable.Kind, reach: float, use: Callable) -> Interactable:
	interactable = Interactable.new()
	interactable.name = NODE_INTERACTABLE
	interactable.kind = kind
	interactable.reach = reach
	interactable.handler = use
	interactable.game_state = game_state
	add_child(interactable)
	return interactable


func set_usable(on: bool) -> void:
	if interactable == null:
		return
	interactable.enabled = on
	if on:
		if not interactable.is_in_group(Interactable.GROUP):
			interactable.add_to_group(Interactable.GROUP)
	elif interactable.is_in_group(Interactable.GROUP):
		interactable.remove_from_group(Interactable.GROUP)


func state() -> Node:
	return WorldProgress.game_state(game_state)


## Shows messages through the room's interactor (and remembers them in last_messages).
func say(lines: Array[String], interactor: PlayerInteractor = null) -> bool:
	last_messages = lines.duplicate()
	var talker: PlayerInteractor = interactor if interactor != null else get_interactor()
	if talker == null or lines.is_empty():
		return false
	return talker.show_messages(lines, interactable)
