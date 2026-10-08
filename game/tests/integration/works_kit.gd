class_name WorksKit
extends RefCounted
## Helpers for the Spillway and jammer-works tests: room paths by id, a door finder, a way to win a
## card fight the way Main would report it, and the flags a player has by a given point.

const ROOMS: Array[String] = ["road_mast_road", "road_mast_foot", "tower_sump", "tower_cable_hall", "tower_bell_gallery",
		"tower_generator", "tower_jammer_deck", "tower_landing", "tower_roof"]
const CARD: String = "kasp_access_card"


static func path(room_id: String) -> String:
	return str(DataDB.get_dict("world/rooms")["rooms"][room_id]["scene"])


## A works room with its input manual, its story triggers off, entered at `spawn`.
static func load_room(test: TestCase, room_id: String, spawn: String = "") -> FieldRoom:
	return ExplorationKit.load_room_at(test, path(room_id), spawn, false)


static func door(room: FieldRoom, placement_id: String) -> Door:
	for node: Node in room.find_children("*", "Node3D", true, false):
		if node is Door and (node as Door).placement_id == placement_id:
			return node as Door
	return null


static func doors(room: FieldRoom) -> Array[Door]:
	var found: Array[Door] = []
	for node: Node in room.find_children("*", "Node3D", true, false):
		if node is Door:
			found.append(node as Door)
	return found


static func enemy(room: FieldRoom, placement_id: String) -> MapEnemy:
	for node: Node in room.find_children("*", "CharacterBody3D", true, false):
		if node is MapEnemy and (node as MapEnemy).placement_id == placement_id:
			return node as MapEnemy
	return null


## Wins the fight a map enemy would start (what Main reports back): the enemy is removed and any win
## reward (the card) is handed over.
static func win_fight(room: FieldRoom, placement_id: String) -> void:
	var foe: MapEnemy = enemy(room, placement_id)
	room.encounters.pending = foe
	room.encounters.battle_finished("win")


static func cards(state: Node) -> int:
	return int(state.call("item_count", CARD))
