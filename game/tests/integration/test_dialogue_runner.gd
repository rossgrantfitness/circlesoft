extends TestCase
## The dialogue runner: lines play in order with the right signals, speakers resolve to nodes,
## gestures and choices work, flags and items are applied, Red is frozen while talking, the voice
## hook fires per typed character, and the real dialogue data is clean.

const PLAYER_SCENE: String = "res://scenes/actors/player.tscn"
const GAME_STATE_SCRIPT: String = "res://scripts/core/game_state.gd"

var _audio: FakeAudio = null


func _runner(conversations: Dictionary) -> DialogueRunner:
	_audio = FakeAudio.new()
	var runner: DialogueRunner = DialogueRunner.new()
	runner.manual_ticks = true
	runner.audio.target = _audio
	runner.chars_per_second_override = 100.0
	var stage_root: Control = Control.new()
	stage_root.size = Vector2(384, 216)
	add_to_root(stage_root)
	runner.parent_override = stage_root
	add_to_root(runner)
	runner.add_conversations(conversations)
	return runner


func _state() -> Node:
	var state: Node = own((load(GAME_STATE_SCRIPT) as GDScript).new() as Node) as Node
	state.call("load_party", DataDB.get_dict("party/party"))
	state.call("reset")
	return state


## Ticks the runner until the current bubble waits for the player (or `limit` ticks pass).
func _until_waiting(runner: DialogueRunner, limit: int = 300) -> void:
	for i: int in limit:
		var bubble: SpeechBubble = runner.get_current_bubble()
		if bubble != null:
			var state: SpeechBubble.State = bubble.get_state()
			if state == SpeechBubble.State.WAITING or state == SpeechBubble.State.CHOOSING or state == SpeechBubble.State.HOLDING:
				return
		if not runner.is_running():
			return
		runner.tick(0.05)


func _run_to_end(runner: DialogueRunner, limit: int = 60) -> void:
	for i: int in limit:
		if not runner.is_running():
			return
		_until_waiting(runner)
		runner.confirm()


func test_plays_lines_in_order_and_finishes() -> void:
	var runner: DialogueRunner = _runner({"c": [
		{"speaker": "otis", "text": "One."},
		{"speaker": "mox", "text": "Two."},
		{"speaker": "otis", "text": "Three."}]})
	var events: Array[String] = []
	runner.line_started.connect(func(speaker: String, text: String) -> void: events.append("start:%s:%s" % [speaker, text]))
	runner.line_finished.connect(func(speaker: String) -> void: events.append("end:%s" % speaker))
	runner.conversation_finished.connect(func(id: String) -> void: events.append("done:%s" % id))
	assert_true(runner.start("c"))
	assert_true(runner.is_running())
	_run_to_end(runner)
	assert_false(runner.is_running())
	assert_eq(events, ["start:otis:One.", "end:otis", "start:mox:Two.", "end:mox", "start:otis:Three.", "end:otis", "done:c"])


func test_start_refuses_unknown_ids_and_double_starts() -> void:
	var runner: DialogueRunner = _runner({"c": [{"speaker": "otis", "text": "Hi"}]})
	assert_false(runner.start("nope"))
	assert_true(runner.start("c"))
	assert_false(runner.start("c"), "already running")


func test_char_typed_signal_and_voice_hook_fire_per_character() -> void:
	var runner: DialogueRunner = _runner({"c": [{"speaker": "otis", "text": "Hey!"}]})
	var typed: Array[String] = []
	runner.char_typed.connect(func(speaker: String, character: String) -> void: typed.append("%s%s" % [speaker, character]))
	runner.start("c")
	_until_waiting(runner)
	assert_eq(typed, ["otisH", "otise", "otisy", "otis!"])
	assert_eq(_audio.voices, ["H", "e", "y", "!"])
	assert_eq(_audio.voice_speakers, ["otis", "otis", "otis", "otis"])
	assert_ge(_audio.reset_count, 1, "voice state resets at the start of the line")


func test_no_voice_for_the_narrator_box() -> void:
	var runner: DialogueRunner = _runner({"c": [{"speaker": "narrator", "text": "A pillar."}]})
	runner.start("c")
	_until_waiting(runner)
	assert_eq(_audio.voices.size(), 0)


func test_red_gesture_line_shows_a_gesture_with_no_text() -> void:
	var runner: DialogueRunner = _runner({"c": [{"speaker": "red", "gesture": "thumbs_up"}, {"speaker": "otis", "text": "Good."}]})
	var texts: Array[String] = []
	runner.line_started.connect(func(_speaker: String, text: String) -> void: texts.append(text))
	runner.start("c")
	assert_eq(runner.get_current_bubble().get_kind(), SpeechBubble.Kind.GESTURE)
	_until_waiting(runner)
	runner.confirm()
	assert_eq(texts[0], "", "no text for a gesture")
	assert_eq(runner.get_current_bubble().get_kind(), SpeechBubble.Kind.TEXT, "the next line is a text bubble")
	assert_eq(_audio.voices.size(), 0, "Red's gesture makes no voice blips")


func test_speakers_resolve_to_registered_nodes() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(384, 216)
	add_to_root(viewport)
	var camera: Camera3D = Camera3D.new()
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0, 7, 7), Vector3.ZERO)
	var otis: Node3D = Node3D.new()
	viewport.add_child(otis)
	otis.position = Vector3(-2, 0, 0)
	var mox: Node3D = Node3D.new()
	viewport.add_child(mox)
	mox.position = Vector3(2, 0, 0)
	var runner: DialogueRunner = _runner({"c": [{"speaker": "otis", "text": "Hi"}, {"speaker": "mox", "text": "Yo"}]})
	runner.camera = camera
	runner.register_speaker("otis", otis)
	runner.register_speaker("mox", mox)
	assert_true(runner.has_speaker("otis"))
	runner.start("c")
	runner.tick(0.0)
	var otis_x: float = runner.get_current_bubble().get_placement().tail_x
	_until_waiting(runner)
	runner.confirm()
	runner.tick(0.0)
	var mox_x: float = runner.get_current_bubble().get_placement().tail_x
	assert_lt(otis_x, mox_x, "each bubble points at its own speaker")
	assert_eq(runner.get_current_bubble().get_style(), SpeechBubble.STYLE_BUBBLE)


func test_a_speaker_with_no_node_in_the_room_gets_the_box() -> void:
	var runner: DialogueRunner = _runner({"c": [{"speaker": "zero_old", "text": "SOUND OFF!"}]})
	runner.start("c")
	assert_eq(runner.get_current_bubble().get_style(), SpeechBubble.STYLE_BOX)


func test_unregistering_a_speaker() -> void:
	var runner: DialogueRunner = _runner({})
	var node: Node3D = Node3D.new()
	add_to_root(node)
	runner.register_speaker("mox", node)
	assert_true(runner.has_speaker("mox"))
	runner.unregister_speaker("mox")
	assert_false(runner.has_speaker("mox"))


func test_choices_branch_to_the_chosen_conversation() -> void:
	var conversations: Dictionary = {
		"ask": [{"speaker": "mox", "text": "Press it?", "choice": ["Yes!", "No way"], "next": ["yes", "no"]},
			{"speaker": "mox", "text": "Never shown."}],
		"yes": [{"speaker": "otis", "text": "Boom."}],
		"no": [{"speaker": "otis", "text": "Phew."}]}
	for pick: int in [0, 1]:
		var runner: DialogueRunner = _runner(conversations)
		var seen: Array[String] = []
		runner.line_started.connect(func(_speaker: String, text: String) -> void: seen.append(text))
		var made: Array = []
		runner.choice_made.connect(func(index: int, next_id: String) -> void: made.append([index, next_id]))
		runner.start("ask")
		_until_waiting(runner)
		assert_eq(runner.get_current_bubble().get_state(), SpeechBubble.State.CHOOSING)
		runner.get_current_bubble().move_choice(pick)
		runner.confirm()
		assert_eq(made, [[pick, ["yes", "no"][pick]]])
		_run_to_end(runner)
		assert_eq(seen, ["Press it?", ["Boom.", "Phew."][pick]], "pick %d" % pick)
		assert_false(runner.is_running())


func test_a_choice_with_no_next_continues_with_the_following_line() -> void:
	var runner: DialogueRunner = _runner({"c": [
		{"speaker": "mox", "text": "Well?", "choice": ["A", "B"]},
		{"speaker": "mox", "text": "After."}]})
	var seen: Array[String] = []
	runner.line_started.connect(func(_speaker: String, text: String) -> void: seen.append(text))
	runner.start("c")
	_until_waiting(runner)
	runner.confirm()
	_run_to_end(runner)
	assert_eq(seen, ["Well?", "After."])


func test_red_answers_with_the_gesture_she_was_offered() -> void:
	var runner: DialogueRunner = _runner({
		"ask": [{"speaker": "otis", "text": "Tour?", "choice": ["Thumbs-up: Tour", "Head shake: Poke"], "next": ["tour", "poke"]}],
		"tour": [{"speaker": "otis", "text": "Right!"}],
		"poke": [{"speaker": "otis", "text": "Ha!"}]})
	runner.start("ask")
	_until_waiting(runner)
	runner.get_current_bubble().move_choice(1)
	runner.confirm()
	var answer: SpeechBubble = runner.get_current_bubble()
	assert_eq(answer.get_kind(), SpeechBubble.Kind.GESTURE)
	assert_eq(answer.speaker_id, "red")
	assert_eq(answer.get_gesture_id(), "head_shake")
	var seen: Array[String] = []
	runner.line_started.connect(func(_speaker: String, text: String) -> void: seen.append(text))
	_run_to_end(runner)
	assert_eq(seen, ["Ha!"])


func test_a_plain_next_jumps_to_another_conversation() -> void:
	var runner: DialogueRunner = _runner({
		"a": [{"speaker": "otis", "text": "First.", "next": "b"}, {"speaker": "otis", "text": "Skipped."}],
		"b": [{"speaker": "otis", "text": "Second."}]})
	var seen: Array[String] = []
	runner.line_started.connect(func(_speaker: String, text: String) -> void: seen.append(text))
	var finished: Array[String] = []
	runner.conversation_finished.connect(func(id: String) -> void: finished.append(id))
	runner.start("a")
	_run_to_end(runner)
	assert_eq(seen, ["First.", "Second."])
	assert_eq(finished, ["a"], "finished is reported under the id that was started")


func test_set_flag_and_give_item_call_game_state() -> void:
	var runner: DialogueRunner = _runner({"c": [
		{"speaker": "zero_old", "text": "Take this.", "give_item": "canned_coffee", "set_flag": "zero_gift"}]})
	var state: Node = _state()
	runner.game_state = state
	runner.start("c")
	assert_true(state.call("get_flag", "zero_gift"), "applied when the line starts")
	assert_eq(state.call("item_count", "canned_coffee"), 1)
	assert_has(_audio.sfx_ids, "item_get")


func test_player_is_frozen_during_the_conversation_and_released_after_a_short_wait() -> void:
	var player: PlayerController = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	add_to_root(player)
	var runner: DialogueRunner = _runner({"c": [{"speaker": "otis", "text": "Hi"}]})
	runner.player = player
	assert_false(player.frozen)
	runner.start("c")
	assert_true(player.frozen)
	assert_true(UiStage.is_busy(tree), "the UI reports busy")
	_run_to_end(runner)
	assert_false(runner.is_running())
	assert_true(player.frozen, "still frozen on the frame the last bubble closed")
	assert_true(UiStage.is_busy(tree))
	runner.tick(0.1)
	runner.tick(0.1)
	runner.tick(0.1)
	assert_false(player.frozen, "released a couple of frames later")
	assert_false(UiStage.is_busy(tree))


func test_a_player_who_was_already_frozen_stays_frozen() -> void:
	var player: PlayerController = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	add_to_root(player)
	player.frozen = true
	var runner: DialogueRunner = _runner({"c": [{"speaker": "otis", "text": "Hi"}]})
	runner.player = player
	runner.start("c")
	_run_to_end(runner)
	for i: int in 4:
		runner.tick(0.016)
	assert_true(player.frozen)


func test_stop_ends_the_conversation_immediately() -> void:
	var runner: DialogueRunner = _runner({"c": [{"speaker": "otis", "text": "Hi"}]})
	var finished: Array[String] = []
	runner.conversation_finished.connect(func(id: String) -> void: finished.append(id))
	runner.start("c")
	runner.stop()
	assert_false(runner.is_running())
	assert_eq(finished, ["c"])


func test_old_bubbles_close_and_are_freed_between_lines() -> void:
	var runner: DialogueRunner = _runner({"c": [{"speaker": "otis", "text": "One."}, {"speaker": "otis", "text": "Two."}]})
	runner.start("c")
	_until_waiting(runner)
	var first: SpeechBubble = runner.get_current_bubble()
	runner.confirm()
	assert_ne(runner.get_current_bubble(), first)
	assert_eq(first.get_state(), SpeechBubble.State.CLOSING)
	for i: int in 5:
		runner.tick(0.1)
	assert_true(first.is_queued_for_deletion())


# ---- the data ----

func test_create_helper_wires_red_and_the_camera() -> void:
	var host: Node = Node.new()
	add_to_root(host)
	var camera: Camera3D = Camera3D.new()
	host.add_child(camera)
	var player: PlayerController = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	host.add_child(player)
	var runner: DialogueRunner = DialogueRunner.create(host, player, camera)
	assert_eq(runner.get_parent(), host)
	assert_eq(runner.camera, camera)
	assert_true(runner.has_speaker("red"), "Red is registered as a speaker automatically")


func test_validate_catches_broken_conversations() -> void:
	var problems: Array[String] = DialogueRunner.validate({
		"a": [{"text": "no speaker"}, {"speaker": "x"}, {"speaker": "x", "text": "y", "choice": ["1", "2"], "next": ["b"]},
			{"speaker": "x", "text": "z", "next": "ghost"}]})
	assert_eq(problems.size(), 5, str(problems))


func test_real_dialogue_data_has_no_orphan_next_ids_or_unknown_speakers() -> void:
	var runner: DialogueRunner = DialogueRunner.new()
	own(runner)
	runner.index_from_data()
	assert_gt(runner.get_conversation_ids().size(), 0, "dialogue data is loaded")
	var conversations: Dictionary = {}
	for doc_id: String in DataDB.json_ids():
		if doc_id.begins_with("dialogue/"):
			conversations.merge(DataDB.get_dict(doc_id).get("conversations", {}))
	assert_eq(DialogueRunner.validate(conversations), [] as Array[String])
	var speakers: Dictionary = DataDB.get_value("ui/dialogue_ui", "speakers", {})
	for conv: String in conversations:
		for line: Dictionary in conversations[conv]:
			var known: bool = speakers.has(str(line["speaker"])) or DialogueSpeakers.is_crowd(DataDB.get_dict("ui/dialogue_ui"), str(line["speaker"]))
			assert_true(known, "%s: speaker %s is in data/ui/dialogue_ui.json (or a crowd id)" % [conv, str(line["speaker"])])
			if line.has("gesture"):
				assert_eq(str(line["speaker"]), "red", "%s: only Red gestures" % conv)


func test_real_dialogue_items_exist_in_the_item_data() -> void:
	var state: Node = _state()
	for doc_id: String in DataDB.json_ids():
		if not doc_id.begins_with("dialogue/"):
			continue
		var conversations: Dictionary = DataDB.get_dict(doc_id).get("conversations", {})
		for conv: String in conversations:
			for line: Dictionary in conversations[conv]:
				if line.has("give_item"):
					var info: Dictionary = state.call("get_item_info", str(line["give_item"]))
					assert_false(str(info["desc"]).is_empty(), "%s gives '%s', which needs an entry in data/items/items.json" % [conv, line["give_item"]])


func test_every_real_conversation_plays_to_the_end() -> void:
	var ids: Array[String] = []
	var runner: DialogueRunner = _runner({})
	runner.index_from_data()
	ids = runner.get_conversation_ids()
	runner.game_state = _state()
	for id: String in ids:
		var lines_seen: Array[int] = [0]
		var counter: Callable = func(_s: String, _t: String) -> void: lines_seen[0] += 1
		runner.line_started.connect(counter)
		assert_true(runner.start(id), id)
		_run_to_end(runner, 200)
		assert_false(runner.is_running(), "%s finished" % id)
		assert_gt(lines_seen[0], 0, id)
		runner.line_started.disconnect(counter)
		for i: int in 4:
			runner.tick(0.05)
