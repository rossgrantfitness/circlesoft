class_name Interactable
extends Node3D
## Something Red can use with the one interact button: talk to somebody, examine a thing, or take
## something. Put one where Red should stand to use it (the node's position is the spot she is
## measured against). Red picks the nearest one in front of her within reach (pick()).
##
## Each one starts a conversation from data/dialogue/ (`conversation`). Once `after_flag` is set
## the `after_conversation` plays instead (and the icon can change with `after_kind`), so a
## character repeats themselves differently and a prize can only be taken once. `set_flag_on_start`
## sets a flag when the talk begins (e.g. otis_met).

enum Kind { TALK, EXAMINE, TAKE, OPEN, CLIMB, HOP }

const GROUP: StringName = &"interactable"
const KIND_NAMES: Dictionary[int, String] = {
	Kind.TALK: "talk", Kind.EXAMINE: "examine", Kind.TAKE: "take", Kind.OPEN: "open", Kind.CLIMB: "climb", Kind.HOP: "hop",
}
const AFTER_SAME: String = "same"
const PATH_GAME_STATE: NodePath = ^"/root/GameState"

signal talk_started(from_point: Vector3)
signal talk_finished

@export var kind: Kind = Kind.TALK
@export var conversation: String = ""
## Flag that, once set, swaps in `after_conversation` (and `after_kind`).
@export var after_flag: String = ""
@export var after_conversation: String = ""
@export_enum("same", "talk", "examine", "take", "open", "climb", "hop") var after_kind: String = "same"
## Flag set when the conversation starts.
@export var set_flag_on_start: String = ""
## Distance Red can use it from. 0 = the default from data/world/interaction.json.
@export var reach: float = 0.0
@export var enabled: bool = true

## GameState to read flags from. Null means the autoload.
var game_state: Node = null
## Set by props that act instead of talking: func(player: CharacterBody3D, interactor: PlayerInteractor) -> bool.
var handler: Callable = Callable()


func _ready() -> void:
	add_to_group(GROUP)


func _state() -> Node:
	if game_state != null:
		return game_state
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null(PATH_GAME_STATE) if loop != null else null


func is_after() -> bool:
	if after_flag.is_empty():
		return false
	var state: Node = _state()
	return state != null and bool(state.call("get_flag", after_flag))


## The conversation to play right now (the "again" one once its flag is set).
func current_conversation() -> String:
	if is_after() and not after_conversation.is_empty():
		return after_conversation
	return conversation


func current_kind() -> Kind:
	if is_after() and after_kind != AFTER_SAME:
		return KIND_NAMES.find_key(after_kind) as Kind
	return kind


## "talk", "examine" or "take": the prompt icon to show.
func current_kind_name() -> String:
	return KIND_NAMES[current_kind()]


## True when using it does something: a handler is set, or there is a conversation to play.
func has_use() -> bool:
	return handler.is_valid() or not current_conversation().is_empty()


func get_reach(tuning: InteractionTuning) -> float:
	return reach if reach > 0.0 else tuning.reach


## Called when Red starts using it.
func begin_use(from_point: Vector3) -> void:
	if not set_flag_on_start.is_empty():
		var state: Node = _state()
		if state != null:
			state.call("set_flag", set_flag_on_start, true)
	talk_started.emit(from_point)


func end_use() -> void:
	talk_finished.emit()


## Whether `point` (Red's feet) facing `facing` (flat unit vector) can use this, and how far away
## it is: returns -1 when it can't. Close things count even when she is not facing them.
func usable_distance(point: Vector3, facing: Vector3, tuning: InteractionTuning) -> float:
	if not enabled or not has_use():
		return -1.0
	var offset: Vector3 = global_position - point
	if absf(offset.y) > tuning.max_height_diff:
		return -1.0
	var flat: Vector3 = Vector3(offset.x, 0.0, offset.z)
	var distance: float = flat.length()
	if distance > get_reach(tuning):
		return -1.0
	if distance > tuning.always_in_reach_distance:
		var flat_facing: Vector3 = Vector3(facing.x, 0.0, facing.z).normalized()
		if flat_facing.dot(flat / distance) < tuning.front_min_dot:
			return -1.0
	return distance


## The nearest usable one in front of Red, or null.
static func pick(candidates: Array[Interactable], point: Vector3, facing: Vector3, tuning: InteractionTuning) -> Interactable:
	var best: Interactable = null
	var best_distance: float = INF
	for candidate: Interactable in candidates:
		var distance: float = candidate.usable_distance(point, facing, tuning)
		if distance >= 0.0 and distance < best_distance:
			best = candidate
			best_distance = distance
	return best
