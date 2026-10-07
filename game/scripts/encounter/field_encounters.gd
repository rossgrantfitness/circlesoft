class_name FieldEncounters
extends Node
## Turns a map enemy touching Red into a battle request, and deals with the result. One per room.
##
## When a MapEnemy in the room touches Red it works out the first-turn rule from who faces whom
## (EncounterRules) and emits `battle_requested(encounter_id, enemy_id, first_turn)`; the FieldRoom
## passes that on and Main starts the fight with that first_turn. When the fight is over,
## `battle_finished(result)`: a win removes the enemy (a story fight or boss also sets its
## defeated flag so it stays beaten); running away leaves it standing, out of breath. Whatever
## happened, Red blinks and cannot be caught for a moment (FieldTuning.blink_time_s).
## Enemies that were already beaten (their flag is set) are removed when the room loads.

signal battle_requested(encounter_id: String, enemy_id: String, first_turn: String)

const RESULT_WIN: String = "win"

var room: Node3D = null
var player: PlayerController = null
## The enemy whose fight is under way.
var pending: MapEnemy = null
## GameState to use. Null means the autoload.
var game_state: Node = null


func setup(p_room: Node3D, p_player: PlayerController) -> void:
	room = p_room
	player = p_player
	for enemy: MapEnemy in enemies():
		bind(enemy)


## Hooks one enemy up (used for the room's own and for any added later). Returns false if it was
## already beaten and has been removed.
func bind(enemy: MapEnemy) -> bool:
	if enemy.is_persistent() and WorldProgress.has_flag(enemy.defeat_flag, game_state):
		enemy.defeat()
		return false
	enemy.target = player
	if not enemy.touched.is_connected(_on_touched):
		enemy.touched.connect(_on_touched)
	return true


func enemies() -> Array[MapEnemy]:
	var found: Array[MapEnemy] = []
	if room == null:
		return found
	for node: Node in room.find_children("*", "CharacterBody3D", true, false):
		if node is MapEnemy and not (node as MapEnemy).is_defeated():
			found.append(node as MapEnemy)
	return found


func is_fighting() -> bool:
	return pending != null


## Freezes or releases every enemy (a room waiting while something else has the screen).
func set_enemies_active(on: bool) -> void:
	for enemy: MapEnemy in enemies():
		enemy.active = on


func _on_touched(enemy: MapEnemy) -> void:
	if pending != null or player == null or not is_instance_valid(player) \
			or (room != null and room.has_method("is_suspended") and bool(room.call("is_suspended"))) \
			or not player.is_catchable() or player.frozen:
		enemy.reset_touch()
		return
	pending = enemy
	var first_turn: String = EncounterRules.first_turn_from_data(player.global_position, player.get_facing(),
			enemy.global_position, enemy.get_facing())
	battle_requested.emit(enemy.encounter_id, enemy.placement_id, first_turn)


## Main says how the fight ended.
func battle_finished(result: String) -> void:
	if player != null and is_instance_valid(player):
		player.start_blink()
	if pending == null:
		return
	var enemy: MapEnemy = pending
	pending = null
	if not is_instance_valid(enemy):
		return
	if result == RESULT_WIN:
		if enemy.is_persistent():
			WorldProgress.set_flag(enemy.defeat_flag, game_state)
		enemy.defeat()
	else:
		enemy.on_battle_over()
