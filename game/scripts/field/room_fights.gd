class_name RoomFights
extends Node
## Fights in a room: watches the room's conversations and, when Red answers an enemy's challenge
## with Fight!, asks for that enemy's encounter once the last bubble has closed (battle_requested).
## After a win it removes that enemy and sets its defeated flag; running away leaves it standing.
## All of it comes from data/world/room_fights.json.

signal battle_requested(encounter_id: String, fight_id: String)

const DATA_ID: String = "world/room_fights"
const MAX_WAIT_FRAMES: int = 240
const RESULT_WIN: String = "win"

var runner: DialogueRunner = null
var interactor: PlayerInteractor = null
var room: Node = null
## The fight whose battle is under way (set when it is requested).
var pending_fight_id: String = ""

var _alive: bool = true
var _active_fight_id: String = ""
var _picked_next: String = ""


static func data() -> Dictionary:
	return DataDB.get_dict(DATA_ID)


## One fight's entry, or an empty dictionary.
static func fight(fight_id: String) -> Dictionary:
	return (data().get("fights", {}) as Dictionary).get(fight_id, {})


static func fight_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign((data().get("fights", {}) as Dictionary).keys())
	return ids


static func defeated_flag(fight_id: String) -> String:
	return str(data().get("defeated_flag_prefix", "defeated_")) + fight_id


## Hooks the room's runner and interactor up. Enemies already beaten stay gone, unless the data
## says a freshly loaded room starts with everyone back.
func setup(p_room: Node, p_runner: DialogueRunner, p_interactor: PlayerInteractor) -> void:
	room = p_room
	runner = p_runner
	interactor = p_interactor
	interactor.interacted.connect(_on_interacted)
	runner.choice_made.connect(_on_choice_made)
	runner.conversation_finished.connect(_on_conversation_finished)
	var respawn: bool = bool(data().get("respawn_on_room_load", true))
	for enemy: FieldEnemy in enemies():
		if respawn:
			_set_flag(defeated_flag(enemy.fight_id), false)
		elif _flag(defeated_flag(enemy.fight_id)):
			enemy.defeat()


func enemies() -> Array[FieldEnemy]:
	var found: Array[FieldEnemy] = []
	if room == null:
		return found
	for node: Node in room.find_children("*", "Node3D", true, false):
		if node is FieldEnemy and not node.is_queued_for_deletion():
			found.append(node as FieldEnemy)
	return found


func enemy_for(fight_id: String) -> FieldEnemy:
	for enemy: FieldEnemy in enemies():
		if enemy.fight_id == fight_id:
			return enemy
	return null


## The battle for `pending_fight_id` is over. A win removes that enemy.
func battle_finished(result: String) -> void:
	if pending_fight_id.is_empty():
		return
	if result == RESULT_WIN:
		_set_flag(defeated_flag(pending_fight_id), true)
		var enemy: FieldEnemy = enemy_for(pending_fight_id)
		if enemy != null:
			if runner != null:
				runner.unregister_speaker(enemy.speaker_id)
			enemy.defeat()
	pending_fight_id = ""


func _on_interacted(target: Interactable, _conversation_id: String) -> void:
	var enemy: FieldEnemy = target.get_parent() as FieldEnemy
	_active_fight_id = enemy.fight_id if enemy != null else ""
	_picked_next = ""


func _on_choice_made(_index: int, next_conversation: String) -> void:
	_picked_next = next_conversation


## The room is going away: no more fights get requested.
func shut_down() -> void:
	_alive = false
	pending_fight_id = ""


func _on_conversation_finished(_conversation_id: String) -> void:
	if not _alive:
		return
	var fight_id: String = _active_fight_id
	var yes: bool = not fight_id.is_empty() and _picked_next == str(fight(fight_id).get("yes", "-"))
	_active_fight_id = ""
	_picked_next = ""
	if yes:
		_request(fight_id)


## Waits until the bubbles and Red's freeze are fully gone, then asks for the fight.
func _request(fight_id: String) -> void:
	pending_fight_id = fight_id
	var waited: int = 0
	while UiStage.is_busy(get_tree()) and waited < MAX_WAIT_FRAMES and _alive:
		await get_tree().process_frame
		waited += 1
	if pending_fight_id != fight_id or not _alive:
		return
	battle_requested.emit(str(fight(fight_id).get("encounter", "")), fight_id)


func _flag(flag_id: String) -> bool:
	var state: Node = get_node_or_null("/root/GameState")
	return state != null and bool(state.call("get_flag", flag_id))


func _set_flag(flag_id: String, value: bool) -> void:
	var state: Node = get_node_or_null("/root/GameState")
	if state != null:
		state.call("set_flag", flag_id, value)
