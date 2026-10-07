class_name DialogueRunner
extends Node
## Plays a conversation from data/dialogue/*.json, one line at a time, in speech bubbles over the
## speakers' heads.
##
## Data (see docs/tech_plan.md): {"conversations": {"<id>": [line, ...]}}. A line is
##   {"speaker": "otis", "text": "..."}                       a text bubble
##   {"speaker": "red", "gesture": "thumbs_up"}               a gesture pop-up (Red never types text)
##   {"speaker": "mox", "text": "...", "choice": ["Yes!", "No way"], "next": ["conv_a", "conv_b"]}
##   plus optional "set_flag": "x" and "give_item": "ration_bar" (applied when the line starts),
##   and a plain "next": "conv_id" on a non-choice line to jump to another conversation after it.
## Text lines may also carry "face" (the starting expression of the speaker's portrait), "name"
## (the name tag, handy for crowd NPCs), "style" ("box" or "bubble") and "portrait" ("none" to
## hide it). Inside the text, {face:grin} changes the expression from that point on.
## A choice label such as "Thumbs-up: Grand tour" shows Red's thumbs-up icon in front of the label,
## and Red answers with that gesture after the pick. A missing or empty "next" entry ends the talk.
##
## The room fills the speaker registry (register_speaker) with the 3D node for each speaker id.
## A speaker with no node in the room, a "box" style speaker (narrator, sign) and any crowd NPC
## (see DialogueSpeakers) is shown in a plain text box at the bottom of the screen.
##
## While a conversation runs the player is frozen (set `player`; Red is registered as "red"
## automatically). The freeze and the "ui_modal" group are released two frames after the last
## line so the button press that closed the last bubble cannot also start a jump or a new talk.
##
## Voice: on every typed character AudioManager.play_voice(speaker_id, character) is called (when
## the speaker has a voice), and reset_voice() at the start of every line.

signal conversation_started(conversation_id: String)
signal line_started(speaker_id: String, text: String)
signal char_typed(speaker_id: String, character: String)
## A speaker's portrait expression changed mid-line (a {face:...} tag).
signal face_changed(speaker_id: String, face: String)
signal line_finished(speaker_id: String)
signal choice_made(index: int, next_conversation: String)
signal conversation_finished(conversation_id: String)

const BUBBLE_SCENE_PATH: String = "res://scenes/ui/speech_bubble.tscn"
const DIALOGUE_PREFIX: String = "dialogue/"
const UI_ID: String = "ui/dialogue_ui"
const KEY_CONVERSATIONS: String = "conversations"
const RELEASE_FRAMES: int = 2
const RED_ID: String = "red"
const STYLE_BOX: String = "box"

## The player to freeze while talking (also registered as speaker "red" unless already registered).
var player: PlayerController = null:
	set(value):
		player = value
		if player != null and not _speakers.has(RED_ID):
			register_speaker(RED_ID, player)
## The room's world camera for projecting speaker heads (optional; falls back to the speaker's camera).
var camera: Camera3D = null
## On: bubbles do not run themselves; call tick(delta). Used by tests.
var manual_ticks: bool = false
var audio: UiAudio = UiAudio.new()
## Add bubbles here instead of the UiStage root (tests).
var parent_override: Control = null
## Overrides the typing speed of every bubble (characters per second; 0 = use Config).
var chars_per_second_override: float = 0.0
## Forwarded to every bubble: fast-forward (-1 buttons, 0 off, 1 on) and auto-advance (-1 Config).
var fast_forward_override: int = -1
var auto_advance_override: int = -1
## GameState to call for set_flag / give_item. Null means the autoload.
var game_state: Node = null

var _conversations: Dictionary = {}
var _indexed: bool = false
var _speakers: Dictionary[String, Dictionary] = {}
var _running: bool = false
var _root_id: String = ""
var _conv_id: String = ""
var _lines: Array = []
var _line_index: int = 0
var _bubble: SpeechBubble = null
var _closing: Array[SpeechBubble] = []
var _release_left: int = -1
var _frozen_by_us: bool = false
var _was_frozen: bool = false
var _ui: Dictionary = {}


func _init() -> void:
	_ui = DataDB.get_dict(UI_ID)


func _process(_delta: float) -> void:
	_count_down_release()


## Makes a runner as a child of `host` (usually the room), wired to Red and the room camera.
## Then register the room's speakers and call start("conversation_id").
static func create(host: Node, red: PlayerController = null, room_camera: Camera3D = null) -> DialogueRunner:
	var runner: DialogueRunner = DialogueRunner.new()
	runner.name = "DialogueRunner"
	runner.camera = room_camera
	host.add_child(runner)
	runner.player = red
	return runner


# ---- data ----

## Adds conversations from a document (the "conversations" dictionary). Later ids replace earlier ones.
func add_conversations(conversations: Dictionary) -> void:
	for id: String in conversations:
		_conversations[id] = conversations[id]
	_indexed = true


## Loads every conversation under data/dialogue/ (every file's "conversations" block).
func index_from_data() -> void:
	for doc_id: String in DataDB.json_ids():
		if not doc_id.begins_with(DIALOGUE_PREFIX):
			continue
		var doc: Dictionary = DataDB.get_dict(doc_id)
		var block: Dictionary = doc.get(KEY_CONVERSATIONS, {})
		for id: String in block:
			if _conversations.has(id):
				push_warning("DialogueRunner: conversation '%s' is defined twice (second one in %s wins)" % [id, doc_id])
			_conversations[id] = block[id]
	_indexed = true


func has_conversation(conversation_id: String) -> bool:
	_ensure_index()
	return _conversations.has(conversation_id)


func get_conversation_ids() -> Array[String]:
	_ensure_index()
	var ids: Array[String] = []
	ids.assign(_conversations.keys())
	return ids


func _ensure_index() -> void:
	if not _indexed:
		index_from_data()


## Problems in a conversations dictionary: lines with no speaker, no text or gesture, choices and
## next lists of different lengths, and next ids that name no conversation. Empty means clean.
static func validate(conversations: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for id: String in conversations:
		var lines: Variant = conversations[id]
		if not lines is Array or (lines as Array).is_empty():
			problems.append("%s: not a non-empty list of lines" % id)
			continue
		for i: int in (lines as Array).size():
			var line: Variant = (lines as Array)[i]
			var where: String = "%s[%d]" % [id, i]
			if not line is Dictionary:
				problems.append("%s: line is not an object" % where)
				continue
			var dict: Dictionary = line
			if str(dict.get("speaker", "")).is_empty():
				problems.append("%s: no speaker" % where)
			if not dict.has("text") and not dict.has("gesture"):
				problems.append("%s: needs text or gesture" % where)
			for problem: String in _markup_problems(dict):
				problems.append("%s: %s" % [where, problem])
			if dict.has("choice"):
				var next: Variant = dict.get("next", [])
				if next is Array and (next as Array).size() != (dict["choice"] as Array).size():
					problems.append("%s: choice and next have different lengths" % where)
			var targets: Array = []
			if dict.has("next"):
				targets = dict["next"] if dict["next"] is Array else [dict["next"]]
			for target: Variant in targets:
				if not str(target).is_empty() and not conversations.has(str(target)):
					problems.append("%s: next '%s' is not a conversation" % [where, str(target)])
	return problems


## Bad inline tags, faces the speaker's portrait does not have, and unknown styles in one line.
static func _markup_problems(line: Dictionary) -> Array[String]:
	var list: Array[String] = []
	var style: String = str(line.get("style", ""))
	if not style.is_empty() and style != DialogueSpeakers.STYLE_BOX and style != DialogueSpeakers.STYLE_BUBBLE:
		list.append("style '%s' is not box or bubble" % style)
	var ui: Dictionary = DataDB.get_dict(UI_ID)
	var key: String = DialogueSpeakers.portrait_key(ui, str(line.get("speaker", "")))
	if str(line.get("portrait", "")) == "none":
		key = ""
	var faces: Array[String] = PortraitLibrary.faces_of(key) if not key.is_empty() else ([] as Array[String])
	var names: Array = DataDB.get_value(UI_ID, "markup.tags", ["face"])
	list.append_array(DialogueMarkup.problems(str(line.get("text", "")), names, faces))
	if line.has("face") and not faces.is_empty() and not faces.has(str(line["face"])):
		list.append("unknown face '%s'" % str(line["face"]))
	return list


# ---- speakers ----

## Tells the runner which 3D node a speaker id is. `head_height` is how far above the node's
## origin the bubble tail should point (-1 = the speaker's value in data/ui/dialogue_ui.json).
func register_speaker(speaker_id: String, node: Node3D, head_height: float = -1.0) -> void:
	_speakers[speaker_id] = {"node": node, "head_height": head_height}


func unregister_speaker(speaker_id: String) -> void:
	_speakers.erase(speaker_id)


func clear_speakers() -> void:
	_speakers.clear()
	if player != null:
		register_speaker(RED_ID, player)


func has_speaker(speaker_id: String) -> bool:
	if not _speakers.has(speaker_id):
		return false
	return is_instance_valid(_speakers[speaker_id]["node"])


# ---- playing ----

## Starts a conversation. Returns false if one is already running or the id is unknown.
func start(conversation_id: String) -> bool:
	_ensure_index()
	if _running:
		return false
	if not _conversations.has(conversation_id):
		push_warning("DialogueRunner: unknown conversation '%s'" % conversation_id)
		return false
	_running = true
	_root_id = conversation_id
	_conv_id = conversation_id
	_lines = _conversations[conversation_id]
	_line_index = 0
	_release_left = -1
	add_to_group(UiStage.MODAL_GROUP)
	if player != null and not _frozen_by_us:
		_was_frozen = player.frozen
		player.frozen = true
		_frozen_by_us = true
	conversation_started.emit(conversation_id)
	_play_line()
	return true


func is_running() -> bool:
	return _running


func get_current_conversation() -> String:
	return _conv_id


func get_current_bubble() -> SpeechBubble:
	return _bubble


## Pass-through for the confirm button (the bubble reads input itself; tests and cutscenes call this).
func confirm() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.confirm()


## Drives bubbles and the release countdown by hand (only needed with manual_ticks).
func tick(delta: float) -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.tick(delta)
	for old: SpeechBubble in _closing.duplicate():
		if is_instance_valid(old):
			old.tick(delta)
	_count_down_release()


## Ends the conversation right now (a room change, a cutscene taking over).
func stop() -> void:
	if not _running:
		return
	_end()


func _play_line() -> void:
	if _line_index >= _lines.size():
		_end()
		return
	var line: Dictionary = _lines[_line_index]
	var speaker: String = str(line.get("speaker", ""))
	_apply_actions(line)
	audio.reset_voice()
	var previous: SpeechBubble = _bubble
	var bubble: SpeechBubble = _make_bubble(speaker, line)
	_bubble = bubble
	if previous != null and is_instance_valid(previous):
		_retire(previous)
	if line.has("gesture"):
		bubble.setup_gesture(speaker, str(line["gesture"]))
		bubble.advanced.connect(_on_line_advanced.bind(speaker))
		line_started.emit(speaker, "")
		return
	var text: String = str(line.get("text", ""))
	var choices: Array = line.get("choice", [])
	bubble.setup_text(speaker, text, choices, style_for(speaker, line), _extras_for(line))
	if choices.is_empty():
		bubble.advanced.connect(_on_line_advanced.bind(speaker))
	else:
		bubble.choice_made.connect(_on_choice_made.bind(speaker, line))
	line_started.emit(speaker, text)


func _make_bubble(speaker: String, _line: Dictionary) -> SpeechBubble:
	var scene: PackedScene = load(BUBBLE_SCENE_PATH) as PackedScene
	var bubble: SpeechBubble = scene.instantiate() as SpeechBubble
	bubble.manual_ticks = manual_ticks
	bubble.chars_per_second_override = chars_per_second_override
	bubble.fast_forward_override = fast_forward_override
	bubble.auto_advance_override = auto_advance_override
	bubble.audio = audio
	bubble.camera = camera
	bubble.char_typed.connect(_on_char_typed)
	bubble.face_changed.connect(_on_face_changed)
	_stage_parent().add_child(bubble)
	bubble.inherit_fast_forward(_bubble)
	if has_speaker(speaker):
		var entry: Dictionary = _speakers[speaker]
		bubble.set_target(entry["node"] as Node3D, float(entry["head_height"]))
	return bubble


func _stage_parent() -> Control:
	if parent_override != null:
		return parent_override
	return UiStage.get_or_create(get_tree()).get_stage_root()


## "box" for the narrator, signs, crowd NPCs (by data) and anyone without a body in the room; "bubble"
## for everyone else. A line's own "style" overrides both. See DialogueSpeakers.
func style_for(speaker: String, line: Dictionary = {}) -> String:
	return DialogueSpeakers.style_for(_ui, speaker, has_speaker(speaker), str(line.get("style", "")))


## The per-line extras a bubble understands (name tag, starting face, portrait choice).
func _extras_for(line: Dictionary) -> Dictionary:
	var extras: Dictionary = {}
	for key: String in ["name", "face", "portrait"]:
		if line.has(key):
			extras[key] = str(line[key])
	return extras


func _voice_enabled(speaker: String) -> bool:
	return bool(DialogueSpeakers.entry(_ui, speaker).get("voice", true))


func _retire(old: SpeechBubble) -> void:
	old.active = false
	_closing.append(old)
	old.closed.connect(_on_old_closed.bind(old))
	old.close()


func _on_old_closed(old: SpeechBubble) -> void:
	_closing.erase(old)


func _on_face_changed(speaker: String, face: String) -> void:
	face_changed.emit(speaker, face)


func _on_char_typed(speaker: String, character: String) -> void:
	if _voice_enabled(speaker):
		audio.voice(speaker, character)
	char_typed.emit(speaker, character)


func _on_line_advanced(speaker: String) -> void:
	line_finished.emit(speaker)
	_next_line()


func _next_line() -> void:
	var line: Dictionary = _lines[_line_index]
	var jump: String = ""
	if line.has("next") and not line["next"] is Array:
		jump = str(line["next"])
	if not jump.is_empty():
		_go_to(jump)
		return
	_line_index += 1
	_play_line()


func _on_choice_made(index: int, speaker: String, line: Dictionary) -> void:
	var next_ids: Array = line.get("next", []) if line.get("next", []) is Array else []
	var next_id: String = str(next_ids[index]) if index < next_ids.size() else ""
	line_finished.emit(speaker)
	choice_made.emit(index, next_id)
	var picked: Dictionary = GestureIcons.split_choice(str((line["choice"] as Array)[index]))
	var after: Callable = _go_to.bind(next_id) if not next_id.is_empty() else _end_or_continue
	var gesture: String = str(picked["gesture"])
	if gesture.is_empty():
		after.call()
		return
	# Red answers with the gesture she was offered, then the conversation moves on.
	var previous: SpeechBubble = _bubble
	var answer: SpeechBubble = _make_bubble(RED_ID, {})
	_bubble = answer
	if previous != null and is_instance_valid(previous):
		_retire(previous)
	answer.setup_gesture(RED_ID, gesture)
	answer.advanced.connect(after, CONNECT_ONE_SHOT)


func _end_or_continue() -> void:
	_line_index += 1
	_play_line()


func _go_to(conversation_id: String) -> void:
	if not _conversations.has(conversation_id):
		push_warning("DialogueRunner: next conversation '%s' does not exist" % conversation_id)
		_end()
		return
	_conv_id = conversation_id
	_lines = _conversations[conversation_id]
	_line_index = 0
	_play_line()


func _end() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_retire(_bubble)
	_bubble = null
	_running = false
	var finished_id: String = _root_id
	_release_left = RELEASE_FRAMES
	conversation_finished.emit(finished_id)


func _count_down_release() -> void:
	if _release_left < 0:
		return
	_release_left -= 1
	if _release_left > 0:
		return
	_release_left = -1
	if _running:
		return
	remove_from_group(UiStage.MODAL_GROUP)
	if _frozen_by_us and player != null and is_instance_valid(player):
		player.frozen = _was_frozen
	_frozen_by_us = false


# ---- line actions ----

func _apply_actions(line: Dictionary) -> void:
	var state: Node = _get_game_state()
	if state == null:
		return
	for flag: String in _as_list(line.get("set_flag", [])):
		state.call("set_flag", flag, true)
	for item: String in _as_list(line.get("give_item", [])):
		state.call("add_item", item, 1)
		audio.sfx_id(str(_ui.get("sfx", {}).get("item", "")))


func _get_game_state() -> Node:
	if game_state != null:
		return game_state
	return get_node_or_null("/root/GameState")


static func _as_list(value: Variant) -> Array[String]:
	var list: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			list.append(str(entry))
	elif not str(value).is_empty():
		list.append(str(value))
	return list
