extends TestCase
## M3 dialogue: mid-line expression tags, the portrait slot, crowd NPCs in the plain box,
## fast-forward and auto-advance, on a single bubble and through the runner.

const SCENE_PATH: String = "res://scenes/ui/speech_bubble.tscn"

var _audio: FakeAudio = null


func after_each() -> void:
	for action: String in ["cancel", "confirm"]:
		Input.action_release(action)


func _make(speaker: String = "mox", listening: bool = false) -> SpeechBubble:
	_audio = FakeAudio.new()
	var bubble: SpeechBubble = (load(SCENE_PATH) as PackedScene).instantiate() as SpeechBubble
	bubble.manual_ticks = true
	bubble.listen_input = listening
	bubble.chars_per_second_override = 20.0
	bubble.audio.target = _audio
	bubble.speaker_id = speaker
	add_to_root(bubble)
	return bubble


func _open(bubble: SpeechBubble) -> void:
	for i: int in 20:
		if bubble.get_state() != SpeechBubble.State.OPENING:
			return
		bubble.tick(0.1)


func _type_all(bubble: SpeechBubble) -> void:
	for i: int in 600:
		if bubble.get_state() != SpeechBubble.State.TYPING:
			return
		bubble.tick(0.05)


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


## Ticks until the runner finishes the conversation, never pressing confirm. Returns seconds used.
func _run_hands_off(runner: DialogueRunner, limit_s: float = 120.0) -> float:
	var elapsed: float = 0.0
	while runner.is_running() and elapsed < limit_s:
		runner.tick(0.05)
		elapsed += 0.05
	return elapsed


# ---- expression tags ----

func test_a_face_tag_is_stripped_and_the_face_changes_where_it_stood() -> void:
	var bubble: SpeechBubble = _make("mox")
	bubble.setup_text("mox", "Hi {face:panicking}there")
	_open(bubble)
	assert_eq(bubble.get_face(), "boasting", "starts on Mox's default face")
	var seen_at: Array[String] = []
	bubble.face_changed.connect(func(_speaker: String, _face: String) -> void: seen_at.append(bubble.get_visible_text()))
	bubble.tick(0.0)
	assert_eq(bubble.get_face(), "boasting", "not yet")
	_type_all(bubble)
	assert_eq(bubble.get_face(), "panicking")
	assert_eq(seen_at, ["Hi"], "it changed right after 'Hi', before the space and 'there'")
	assert_eq(bubble.get_visible_text(), "Hi there", "the tag never shows in the text")
	assert_false(bubble.get_pages()[0].contains("{"))


func test_face_changed_names_the_speaker_and_the_face() -> void:
	var bubble: SpeechBubble = _make("otis")
	bubble.setup_text("otis", "Oh. {face:laughing}Ha!")
	_open(bubble)
	var heard: Array[String] = []
	bubble.face_changed.connect(func(speaker: String, face: String) -> void: heard.append("%s:%s" % [speaker, face]))
	_type_all(bubble)
	assert_eq(heard, ["otis:laughing"])


func test_several_tags_play_in_order() -> void:
	var bubble: SpeechBubble = _make("mox")
	bubble.setup_text("mox", "{face:focused}One {face:sheepish}two {face:proud}three")
	_open(bubble)
	var heard: Array[String] = []
	bubble.face_changed.connect(func(_speaker: String, face: String) -> void: heard.append(face))
	bubble.tick(0.0)
	assert_eq(bubble.get_face(), "focused", "a tag at the very start applies as the page starts")
	_type_all(bubble)
	assert_eq(heard, ["sheepish", "proud"], "the starting tag fired before the listener was attached")
	assert_eq(bubble.get_face(), "proud")


func test_skipping_the_typing_still_applies_every_tag() -> void:
	var bubble: SpeechBubble = _make("mox")
	bubble.setup_text("mox", "A {face:sheepish}b {face:proud}c")
	_open(bubble)
	bubble.tick(0.0)
	bubble.confirm()
	assert_eq(bubble.get_state(), SpeechBubble.State.WAITING)
	assert_eq(bubble.get_face(), "proud", "the last expression wins when you skip ahead")


func test_a_tag_on_the_second_page_fires_when_that_page_starts() -> void:
	var bubble: SpeechBubble = _make("otis")
	bubble.setup_text("otis", "Line one\nLine two\nLine three\n{face:stern}Line four")
	_open(bubble)
	_type_all(bubble)
	assert_eq(bubble.get_pages().size(), 2)
	assert_eq(bubble.get_face(), "calm", "page one has no tag")
	bubble.confirm()
	assert_eq(bubble.get_page_index(), 1)
	assert_eq(bubble.get_face(), "stern", "turning the page starts the tag at once")


func test_a_line_can_start_on_a_chosen_face() -> void:
	var bubble: SpeechBubble = _make("mox")
	bubble.setup_text("mox", "Hello.", [], "", {"face": "sheepish"})
	assert_eq(bubble.get_face(), "sheepish")


func test_tags_work_for_speakers_without_a_portrait_too() -> void:
	var bubble: SpeechBubble = _make("enemy_grunt")
	bubble.setup_text("enemy_grunt", "Halt! {face:angry}Now!")
	_open(bubble)
	var heard: Array[String] = []
	bubble.face_changed.connect(func(_speaker: String, face: String) -> void: heard.append(face))
	_type_all(bubble)
	assert_eq(heard, ["angry"], "listeners (a 3D face swap, say) still hear it")
	assert_false(bubble.has_portrait())
	assert_eq(bubble.get_visible_text(), "Halt! Now!")


# ---- portrait slot ----

func test_named_cast_get_a_portrait_slot_inside_the_bubble() -> void:
	var bubble: SpeechBubble = _make("otis")
	bubble.setup_text("otis", "Hello there.")
	assert_true(bubble.has_portrait())
	assert_eq(bubble.get_portrait_key(), "otis")
	var rect: Rect2 = bubble.get_portrait_rect()
	assert_eq(rect.size, Vector2(32, 32))
	assert_true(bubble.get_body_rect().encloses(rect), "the slot sits inside the bubble body")


func test_the_portrait_makes_the_bubble_wider_and_pushes_the_text_right() -> void:
	var plain: SpeechBubble = _make("enemy_grunt")
	plain.setup_text("enemy_grunt", "Hello there.")
	var named: SpeechBubble = _make("otis")
	named.setup_text("otis", "Hello there.")
	assert_ge(named.get_body_size().x - plain.get_body_size().x, 32, "room for the slot")
	assert_ge(named.get_body_size().y, 32, "tall enough for the slot")


func test_a_longer_line_wraps_sooner_when_there_is_a_portrait() -> void:
	var text: String = "A fairly long sentence that needs a good amount of room to be said in one go, really, truly."
	var plain: SpeechBubble = _make("enemy_grunt")
	plain.setup_text("enemy_grunt", text)
	var named: SpeechBubble = _make("otis")
	named.setup_text("otis", text)
	assert_le(named.get_body_size().x, int(DataDB.get_value("ui/dialogue_ui", "bubble.max_text_width", 0)) + 16 + 1, "still capped")
	assert_ge(named.get_pages()[0].count("\n"), plain.get_pages()[0].count("\n"))


func test_the_extras_can_hide_the_portrait_or_pick_another_character() -> void:
	var hidden: SpeechBubble = _make("otis")
	hidden.setup_text("otis", "Hi", [], "", {"portrait": "none"})
	assert_false(hidden.has_portrait())
	var other: SpeechBubble = _make("enemy_grunt")
	other.setup_text("enemy_grunt", "Hi", [], "", {"portrait": "kasp"})
	assert_eq(other.get_portrait_key(), "kasp")
	assert_eq(other.get_face(), "smug", "starts on that character's default face")


func test_the_box_shows_a_portrait_for_named_cast_with_no_body() -> void:
	var box: SpeechBubble = _make("kasp")
	box.setup_text("kasp", "Stand down.", [], "box")
	assert_eq(box.get_style(), "box")
	assert_true(box.has_portrait())
	var rect: Rect2 = box.get_portrait_rect()
	assert_eq(rect.size, Vector2(48, 48))
	assert_true(box.get_body_rect().encloses(rect))
	assert_gt(rect.end.x, box.get_body_rect().position.x)


func test_portrait_choices_still_fit_below_the_slot() -> void:
	var bubble: SpeechBubble = _make("otis")
	bubble.setup_text("otis", "Which way?", ["Thumbs-up: This way", "Head shake: That way"])
	_open(bubble)
	_type_all(bubble)
	assert_eq(bubble.get_state(), SpeechBubble.State.CHOOSING)
	assert_true(bubble.get_body_rect().size.y >= 32 + 16 * 2, "the bubble grew to fit the slot and both choices")


# ---- crowd box ----

func test_a_crowd_npc_gets_the_plain_box_with_no_portrait_and_a_name_from_its_id() -> void:
	var bubble: SpeechBubble = _make("crowd_dockhand")
	bubble.setup_text("crowd_dockhand", "Mind the cranes.")
	assert_eq(bubble.get_style(), "box")
	assert_false(bubble.has_portrait())
	assert_eq(bubble.get_name_text(), "Dockhand")


func test_a_line_can_name_a_crowd_npc() -> void:
	var bubble: SpeechBubble = _make("crowd_townsfolk")
	bubble.setup_text("crowd_townsfolk", "Fresh rolls!", [], "", {"name": "Baker"})
	assert_eq(bubble.get_name_text(), "Baker")


func test_the_runner_picks_the_box_for_crowd_npcs_by_data() -> void:
	var runner: DialogueRunner = _runner({})
	var body: Node3D = Node3D.new()
	add_to_root(body)
	runner.register_speaker("crowd_dockhand", body)
	runner.register_speaker("otis", body)
	assert_eq(runner.style_for("crowd_dockhand"), "box", "even with a body in the room")
	assert_eq(runner.style_for("otis"), "bubble")
	assert_eq(runner.style_for("kasp"), "box", "named cast with no body in the room")
	assert_eq(runner.style_for("narrator"), "box")
	assert_eq(runner.style_for("crowd_dockhand", {"style": "bubble"}), "bubble", "a line can override")
	assert_eq(runner.style_for("otis", {"style": "box"}), "box")


func test_a_crowd_conversation_plays_in_the_box() -> void:
	var runner: DialogueRunner = _runner({"c": [{"speaker": "crowd_dockhand", "text": "Evening."}, {"speaker": "crowd_townsfolk", "name": "Baker", "text": "Rolls!"}]})
	runner.fast_forward_override = 0
	runner.start("c")
	var first: SpeechBubble = runner.get_current_bubble()
	assert_eq(first.get_style(), "box")
	assert_false(first.has_portrait())
	assert_eq(first.get_name_text(), "Dockhand")
	for i: int in 40:
		runner.tick(0.05)
	runner.confirm()
	var second: SpeechBubble = runner.get_current_bubble()
	assert_eq(second.get_name_text(), "Baker")


func test_the_runner_relays_face_changes_and_start_faces() -> void:
	var runner: DialogueRunner = _runner({"c": [{"speaker": "mox", "face": "sheepish", "text": "Oops. {face:proud}Ha!"}]})
	var heard: Array[String] = []
	runner.face_changed.connect(func(speaker: String, face: String) -> void: heard.append("%s:%s" % [speaker, face]))
	runner.start("c")
	assert_eq(runner.get_current_bubble().get_face(), "sheepish")
	for i: int in 80:
		runner.tick(0.05)
	assert_eq(heard, ["mox:proud"])


func test_validate_flags_bad_tags_faces_and_styles() -> void:
	var problems: Array[String] = DialogueRunner.validate({"c": [
		{"speaker": "otis", "text": "Fine {face:laughing}."},
		{"speaker": "otis", "text": "Bad {face:sparkly}."},
		{"speaker": "otis", "text": "Bad {shake:hard}."},
		{"speaker": "otis", "face": "grinning", "text": "Hi"},
		{"speaker": "otis", "style": "megaphone", "text": "Hi"},
		{"speaker": "crowd_baker", "text": "Free {face:anything}."}]})
	assert_eq(problems.size(), 4, str(problems))


# ---- fast-forward ----

func test_fast_forward_shows_each_page_at_once_without_a_burst_of_voice() -> void:
	var bubble: SpeechBubble = _make("mox")
	bubble.fast_forward_override = 1
	bubble.setup_text("mox", "A long line of talk that would take a while to type out at twenty letters a second.")
	_open(bubble)
	var typed: Array[String] = []
	bubble.char_typed.connect(func(_speaker: String, character: String) -> void: typed.append(character))
	bubble.tick(0.01)
	assert_eq(bubble.get_state(), SpeechBubble.State.WAITING)
	assert_eq(bubble.get_visible_text(), bubble.get_pages()[0])
	assert_eq(typed.size(), 0, "no voice for the hurried letters")


func test_fast_forward_turns_pages_and_ends_the_line_by_itself() -> void:
	var bubble: SpeechBubble = _make("enemy_grunt")
	bubble.fast_forward_override = 1
	bubble.setup_text("enemy_grunt", "One\nTwo\nThree\nFour\nFive")
	var ended: Array[bool] = []
	bubble.advanced.connect(func() -> void: ended.append(true))
	_open(bubble)
	var elapsed: float = 0.0
	while ended.is_empty() and elapsed < 3.0:
		bubble.tick(0.05)
		elapsed += 0.05
	assert_eq(ended.size(), 1, "the line ended without a press")
	assert_lt(elapsed, 1.0, "and it was quick")
	assert_eq(bubble.get_page_index(), 1)


func test_fast_forward_never_picks_a_choice() -> void:
	var bubble: SpeechBubble = _make("otis")
	bubble.fast_forward_override = 1
	bubble.setup_text("otis", "Which?", ["Thumbs-up: This", "Head shake: That"])
	var chosen: Array[int] = []
	bubble.choice_made.connect(func(index: int) -> void: chosen.append(index))
	_open(bubble)
	for i: int in 100:
		bubble.tick(0.05)
	assert_eq(bubble.get_state(), SpeechBubble.State.CHOOSING)
	assert_eq(chosen.size(), 0)


func test_fast_forward_cuts_a_gesture_short() -> void:
	var bubble: SpeechBubble = _make("red")
	bubble.fast_forward_override = 1
	bubble.setup_gesture("red", "thumbs_up")
	var ended: Array[bool] = []
	bubble.advanced.connect(func() -> void: ended.append(true))
	_open(bubble)
	var elapsed: float = 0.0
	while ended.is_empty() and elapsed < 2.0:
		bubble.tick(0.05)
		elapsed += 0.05
	assert_lt(elapsed, float(DataDB.get_value("ui/dialogue_ui", "gesture.hold_s", 1.2)) - 0.3)


func test_holding_cancel_fast_forwards_after_the_hold_time() -> void:
	var bubble: SpeechBubble = _make("mox", true)
	bubble.setup_text("mox", "A long line of talk that would take a while to type out at twenty letters a second.")
	_open(bubble)
	var hold: float = float(DataDB.get_value("ui/dialogue_ui", "fast_forward.actions.cancel", 0.12))
	Input.action_press("cancel")
	bubble.tick(hold * 0.4)
	assert_false(bubble.is_fast_forwarding(), "a quick tap is not a fast-forward")
	bubble.tick(hold)
	assert_true(bubble.is_fast_forwarding())
	bubble.tick(0.01)
	assert_eq(bubble.get_state(), SpeechBubble.State.WAITING, "the page is shown at once")
	Input.action_release("cancel")
	bubble.tick(0.01)
	assert_false(bubble.is_fast_forwarding(), "letting go stops it")


func test_a_button_already_held_when_the_bubble_opens_does_not_fast_forward() -> void:
	Input.action_press("cancel")
	var bubble: SpeechBubble = _make("mox", true)
	bubble.setup_text("mox", "Some words that take a moment to type.")
	_open(bubble)
	for i: int in 10:
		bubble.tick(0.1)
	assert_false(bubble.is_fast_forwarding(), "held from before the bubble: ignored until let go")
	Input.action_release("cancel")
	bubble.tick(0.01)
	Input.action_press("cancel")
	bubble.tick(0.5)
	assert_true(bubble.is_fast_forwarding(), "a fresh press works")


func test_holding_confirm_needs_a_longer_hold_than_cancel() -> void:
	var bubble: SpeechBubble = _make("mox", true)
	bubble.setup_text("mox", "Some words that take a moment to type.")
	_open(bubble)
	var cancel_hold: float = float(DataDB.get_value("ui/dialogue_ui", "fast_forward.actions.cancel", 0.12))
	var confirm_hold: float = float(DataDB.get_value("ui/dialogue_ui", "fast_forward.actions.confirm", 0.45))
	assert_gt(confirm_hold, cancel_hold, "a normal press of confirm never counts as a hold")
	Input.action_press("confirm")
	bubble.tick(confirm_hold * 0.5)
	assert_false(bubble.is_fast_forwarding())
	bubble.tick(confirm_hold * 0.6)
	assert_true(bubble.is_fast_forwarding())


func test_the_runner_keeps_fast_forwarding_from_line_to_line() -> void:
	var lines: Array = []
	for i: int in 6:
		lines.append({"speaker": "enemy_grunt", "text": "Line number %d goes by." % i})
	var runner: DialogueRunner = _runner({"c": lines})
	runner.fast_forward_override = 1
	runner.start("c")
	var elapsed: float = _run_hands_off(runner)
	assert_false(runner.is_running(), "the whole conversation played with no presses")
	assert_lt(elapsed, 6.0)


func test_the_runner_stops_fast_forwarding_at_a_choice() -> void:
	var runner: DialogueRunner = _runner({"c": [
		{"speaker": "otis", "text": "Pick.", "choice": ["Thumbs-up: Yes", "Head shake: No"], "next": ["", ""]}]})
	runner.fast_forward_override = 1
	runner.start("c")
	_run_hands_off(runner, 10.0)
	assert_true(runner.is_running(), "still waiting for the player's answer")
	assert_eq(runner.get_current_bubble().get_state(), SpeechBubble.State.CHOOSING)


# ---- auto-advance ----

func test_auto_advance_turns_a_finished_page_after_a_read_time() -> void:
	var bubble: SpeechBubble = _make("enemy_grunt")
	bubble.auto_advance_override = 1
	bubble.setup_text("enemy_grunt", "Short line.")
	var ended: Array[bool] = []
	bubble.advanced.connect(func() -> void: ended.append(true))
	_open(bubble)
	_type_all(bubble)
	assert_eq(bubble.get_state(), SpeechBubble.State.WAITING)
	var wait: float = bubble.get_auto_wait_s()
	var auto: Dictionary = DataDB.get_dict("ui/dialogue_ui")["auto_advance"]
	assert_ge(wait, float(auto["min_s"]))
	assert_le(wait, float(auto["max_s"]))
	bubble.tick(wait - 0.05)
	assert_eq(ended.size(), 0, "not yet")
	bubble.tick(0.1)
	assert_eq(ended.size(), 1, "turned by itself")
	bubble.tick(1.0)
	assert_eq(ended.size(), 1, "and only once")


func test_a_longer_page_is_given_longer_to_read() -> void:
	var short_bubble: SpeechBubble = _make("enemy_grunt")
	short_bubble.auto_advance_override = 1
	short_bubble.setup_text("enemy_grunt", "Hi.")
	_open(short_bubble)
	_type_all(short_bubble)
	var long_bubble: SpeechBubble = _make("enemy_grunt")
	long_bubble.auto_advance_override = 1
	long_bubble.setup_text("enemy_grunt", "This page has quite a lot more to read than the other one,\nso it should hold on for longer before moving along.")
	_open(long_bubble)
	_type_all(long_bubble)
	assert_gt(long_bubble.get_auto_wait_s(), short_bubble.get_auto_wait_s())


func test_auto_advance_off_waits_for_the_player() -> void:
	var bubble: SpeechBubble = _make("enemy_grunt")
	bubble.auto_advance_override = 0
	bubble.setup_text("enemy_grunt", "Short line.")
	var ended: Array[bool] = []
	bubble.advanced.connect(func() -> void: ended.append(true))
	_open(bubble)
	_type_all(bubble)
	for i: int in 200:
		bubble.tick(0.1)
	assert_eq(ended.size(), 0)
	assert_eq(bubble.get_auto_wait_s(), INF)


func test_auto_advance_does_not_choose_for_the_player() -> void:
	var bubble: SpeechBubble = _make("otis")
	bubble.auto_advance_override = 1
	bubble.setup_text("otis", "Which?", ["Thumbs-up: This", "Head shake: That"])
	var chosen: Array[int] = []
	bubble.choice_made.connect(func(index: int) -> void: chosen.append(index))
	_open(bubble)
	for i: int in 300:
		bubble.tick(0.1)
	assert_eq(bubble.get_state(), SpeechBubble.State.CHOOSING)
	assert_eq(chosen.size(), 0)


func test_auto_advance_follows_the_config_setting() -> void:
	var config: Node = tree.root.get_node("Config")
	var before: bool = bool(config.get("auto_advance"))
	var bubble: SpeechBubble = _make("enemy_grunt")
	bubble.setup_text("enemy_grunt", "Short line.")
	_open(bubble)
	_type_all(bubble)
	config.set("auto_advance", false)
	assert_eq(bubble.get_auto_wait_s(), INF, "Config says off")
	config.set("auto_advance", true)
	assert_lt(bubble.get_auto_wait_s(), INF, "Config says on")
	config.set("auto_advance", before)


func test_the_runner_plays_a_whole_conversation_by_itself_with_auto_advance() -> void:
	var runner: DialogueRunner = _runner({"c": [
		{"speaker": "enemy_grunt", "text": "First."},
		{"speaker": "red", "gesture": "thumbs_up"},
		{"speaker": "crowd_dockhand", "text": "Second."},
		{"speaker": "enemy_grunt", "text": "Third."}]})
	runner.fast_forward_override = 0
	runner.auto_advance_override = 1
	runner.start("c")
	var elapsed: float = _run_hands_off(runner)
	assert_false(runner.is_running(), "ended with no presses")
	assert_gt(elapsed, 2.0, "but it gave time to read")


func test_text_speed_still_changes_the_typing_rate() -> void:
	var slow: SpeechBubble = _make("enemy_grunt")
	slow.chars_per_second_override = 0.0
	var config: Node = tree.root.get_node("Config")
	var before: String = str(config.get("text_speed"))
	config.call("set_text_speed", "slow")
	slow.setup_text("enemy_grunt", "abcdefghijklmnopqrstuvwxyz")
	_open(slow)
	slow.tick(0.0)
	slow.tick(1.0)
	var slow_count: int = slow.get_visible_text().length()
	var fast: SpeechBubble = _make("enemy_grunt")
	fast.chars_per_second_override = 0.0
	config.call("set_text_speed", "fast")
	fast.setup_text("enemy_grunt", "abcdefghijklmnopqrstuvwxyz")
	_open(fast)
	fast.tick(0.0)
	fast.tick(1.0)
	config.call("set_text_speed", before)
	assert_gt(fast.get_visible_text().length(), slow_count)
