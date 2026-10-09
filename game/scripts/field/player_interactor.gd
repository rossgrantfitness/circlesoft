class_name PlayerInteractor
extends Node
## Red's one interact button. Every physics frame it finds the nearest Interactable in front of her
## (within reach), shows the matching prompt icon over her head, and starts that thing's
## conversation when `interact` is pressed. It does nothing while a bubble or the menu is up
## (UiStage.is_busy), while Red is frozen, or while she is in the air.
##
## Characters (anything in group "npc" with a speaker_id) turn to face Red whenever they speak and
## turn back when the conversation ends.

const ACTION_INTERACT: StringName = &"interact"
const NPC_GROUP: StringName = &"npc"
const NARRATOR: String = "narrator"
const MESSAGE_PREFIX: String = "__message_"

signal target_changed(target: Interactable)
signal interacted(target: Interactable, conversation_id: String)

var player: CharacterBody3D = null
var runner: DialogueRunner = null
var prompt: InteractPrompt = null
var tuning: InteractionTuning = InteractionTuning.new()
## Off in tests that drive the interactor by hand.
var read_engine_input: bool = true

var _target: Interactable = null
var _blocked_frames: int = 0
var _active: Interactable = null


func _ready() -> void:
	tuning = InteractionTuning.from_db(get_node_or_null("/root/DataDB"))
	if prompt != null:
		prompt.tuning = tuning
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	refresh()
	if _blocked_frames > 0:
		_blocked_frames -= 1
		return
	if read_engine_input and player != null and HeroLink.reads_engine_input(player) \
			and Input.is_action_just_pressed(ACTION_INTERACT):
		try_interact()


## Ignores the interact button for a few physics frames (coming back from a battle, where the same
## button dismissed the victory screen).
func block_for_frames(frames: int) -> void:
	_blocked_frames = maxi(_blocked_frames, frames)


func get_target() -> Interactable:
	return _target


## True when Red may use something right now.
func can_interact() -> bool:
	if player == null or not is_instance_valid(player) or HeroLink.is_frozen(player) or HeroLink.is_scripted(player) or not HeroLink.is_on_floor(player):
		return false
	if runner != null and runner.is_running():
		return false
	return not UiStage.is_busy(get_tree())


## Re-picks the target and updates the prompt icon.
func refresh() -> void:
	var picked: Interactable = null
	if can_interact():
		var candidates: Array[Interactable] = []
		for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
			if node is Interactable:
				candidates.append(node as Interactable)
		picked = Interactable.pick(candidates, player.global_position, HeroLink.get_facing(player), tuning)
	if picked != _target:
		_target = picked
		target_changed.emit(_target)
	if prompt != null:
		prompt.show_icon(_target.current_kind_name() if _target != null else "")


## Uses the current target. Returns true if something started (a conversation or the prop's action).
func try_interact() -> bool:
	refresh()
	if _target == null:
		return false
	var used: Interactable = _target
	if used.handler.is_valid():
		used.begin_use(player.global_position)
		var done: bool = bool(used.handler.call(player, self))
		interacted.emit(used, "")
		refresh()
		return done
	if runner == null:
		return false
	var conversation_id: String = used.current_conversation()
	if not runner.has_conversation(conversation_id):
		push_warning("PlayerInteractor: no conversation '%s'" % conversation_id)
		return false
	used.begin_use(player.global_position)
	if not start_conversation(conversation_id, used):
		return false
	interacted.emit(used, conversation_id)
	refresh()
	return true


## Starts a conversation and tracks it so `used` gets end_use() when it finishes.
func start_conversation(conversation_id: String, used: Interactable = null) -> bool:
	if runner == null or not runner.has_conversation(conversation_id) or not runner.start(conversation_id):
		return false
	_active = used
	if not runner.conversation_finished.is_connected(_on_finished):
		runner.conversation_finished.connect(_on_finished)
	if not runner.line_started.is_connected(_on_line_started):
		runner.line_started.connect(_on_line_started)
	return true


## Shows plain text lines in the narrator box (a locked door's message, "Got a Ration Bar!").
func show_messages(texts: Array[String], used: Interactable = null, speaker: String = NARRATOR) -> bool:
	if runner == null or texts.is_empty():
		return false
	var lines: Array = []
	for text: String in texts:
		lines.append({"speaker": speaker, "text": text})
	var conversation_id: String = MESSAGE_PREFIX + str(hash(texts))
	runner.get_conversation_ids()  # index the data first: add_conversations marks the runner as indexed
	runner.add_conversations({conversation_id: lines})
	return start_conversation(conversation_id, used)


func show_message(text: String, used: Interactable = null) -> bool:
	return show_messages([text], used)


func _on_line_started(speaker_id: String, _text: String) -> void:
	var npc: Node = _find_npc(speaker_id)
	if npc != null and player != null:
		npc.call("face_point", player.global_position)


func _on_finished(_conversation_id: String) -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(NPC_GROUP):
		node.call("release_facing")
	if _active != null and is_instance_valid(_active):
		_active.end_use()
	_active = null


func _find_npc(speaker_id: String) -> Node:
	for node: Node in get_tree().get_nodes_in_group(NPC_GROUP):
		if str(node.get("speaker_id")) == speaker_id:
			return node
	return null
