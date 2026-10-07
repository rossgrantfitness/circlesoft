extends TestCase
## Speech bubbles: typing letter by letter, skipping, pages, the blinking arrow, choices,
## gesture pop-ups, the plain box for narrator lines, following a 3D speaker, flipping near the
## top of the screen, and closing.

const SCENE_PATH: String = "res://scenes/ui/speech_bubble.tscn"
const SHORT: String = "Hello there, friend."
const LONG: String = "One line of talk\nTwo lines of talk\nThree lines of talk\nFour lines of talk"

var _audio: FakeAudio = null


func _make(name: String = "otis") -> SpeechBubble:
	_audio = FakeAudio.new()
	var bubble: SpeechBubble = (load(SCENE_PATH) as PackedScene).instantiate() as SpeechBubble
	bubble.manual_ticks = true
	bubble.listen_input = false
	bubble.chars_per_second_override = 20.0
	bubble.audio.target = _audio
	bubble.speaker_id = name
	add_to_root(bubble)
	return bubble


## Runs the pop-in animation to its end.
func _open(bubble: SpeechBubble) -> void:
	for i: int in 20:
		if bubble.get_state() != SpeechBubble.State.OPENING:
			return
		bubble.tick(0.1)


func _type_all(bubble: SpeechBubble) -> void:
	for i: int in 400:
		if bubble.get_state() != SpeechBubble.State.TYPING:
			return
		bubble.tick(0.1)


func test_pops_in_then_starts_typing() -> void:
	var bubble: SpeechBubble = _make()
	bubble.setup_text("otis", SHORT)
	assert_eq(bubble.get_state(), SpeechBubble.State.OPENING)
	assert_eq(bubble.get_visible_text(), "", "no text during the pop")
	_open(bubble)
	assert_eq(bubble.get_state(), SpeechBubble.State.TYPING)
	assert_has(_audio.sfx_ids, "bubble_open")


func test_text_types_out_letter_by_letter_at_the_set_speed() -> void:
	var bubble: SpeechBubble = _make()
	bubble.setup_text("otis", SHORT)
	_open(bubble)
	var typed: Array[String] = []
	bubble.char_typed.connect(func(_speaker: String, character: String) -> void: typed.append(character))
	bubble.tick(0.0)
	assert_eq(bubble.get_visible_text(), "H")
	bubble.tick(0.5)  # 20 cps: ten more characters
	assert_eq(bubble.get_visible_text().length(), 11)
	assert_eq(bubble.get_state(), SpeechBubble.State.TYPING)
	_type_all(bubble)
	assert_eq(bubble.get_visible_text(), SHORT)
	assert_eq("".join(typed), SHORT, "every character was announced, in order")


func test_char_typed_carries_the_speaker_id() -> void:
	var bubble: SpeechBubble = _make("mox")
	bubble.setup_text("mox", "Hi")
	_open(bubble)
	var speakers: Array[String] = []
	bubble.char_typed.connect(func(speaker: String, _character: String) -> void: speakers.append(speaker))
	_type_all(bubble)
	assert_eq(speakers, ["mox", "mox"])


func test_confirm_while_typing_skips_to_the_end_without_a_burst_of_voice() -> void:
	var bubble: SpeechBubble = _make()
	bubble.setup_text("otis", SHORT)
	_open(bubble)
	var typed: Array[String] = []
	bubble.char_typed.connect(func(_speaker: String, character: String) -> void: typed.append(character))
	bubble.tick(0.1)
	var before: int = typed.size()
	bubble.confirm()
	assert_eq(bubble.get_visible_text(), SHORT)
	assert_eq(bubble.get_state(), SpeechBubble.State.WAITING)
	assert_eq(typed.size(), before, "skipped letters make no sound")


func test_confirm_when_done_advances() -> void:
	var bubble: SpeechBubble = _make()
	bubble.setup_text("otis", SHORT)
	_open(bubble)
	_type_all(bubble)
	assert_true(bubble.is_finished())
	var advanced: Array[bool] = []
	bubble.advanced.connect(func() -> void: advanced.append(true))
	bubble.confirm()
	assert_eq(advanced.size(), 1)
	assert_has(_audio.sfx_ids, "bubble_next")


func test_long_text_is_split_into_pages_of_three_lines() -> void:
	var bubble: SpeechBubble = _make()
	bubble.setup_text("otis", LONG)
	assert_eq(bubble.get_pages().size(), 2)
	assert_eq(bubble.get_pages()[0].count("\n"), 2, "three lines on page one")
	_open(bubble)
	_type_all(bubble)
	assert_eq(bubble.get_state(), SpeechBubble.State.WAITING)
	assert_false(bubble.is_finished(), "another page follows")
	var advanced: Array[bool] = []
	bubble.advanced.connect(func() -> void: advanced.append(true))
	bubble.confirm()
	assert_eq(advanced.size(), 0, "turning the page is not the end of the line")
	assert_eq(bubble.get_page_index(), 1)
	assert_eq(bubble.get_state(), SpeechBubble.State.TYPING)
	assert_eq(bubble.get_visible_text().length() <= 1, true, "the new page starts typing from scratch")
	_type_all(bubble)
	assert_true(bubble.is_finished())


func test_bubble_size_fits_the_text_and_is_capped_in_width() -> void:
	var small: SpeechBubble = _make("enemy_grunt")
	small.setup_text("enemy_grunt", "Hi")
	var big: SpeechBubble = _make("enemy_grunt")
	big.setup_text("enemy_grunt", "A fairly long sentence that needs a good amount of room to be said in one go, really.")
	assert_lt(small.get_body_size().x, big.get_body_size().x)
	var max_text: int = int(DataDB.get_value("ui/dialogue_ui", "bubble.max_text_width", 0))
	assert_le(big.get_body_size().x, max_text + 2 * int(DataDB.get_value("ui/dialogue_ui", "bubble.pad_x", 0)) + 1)
	assert_gt(big.get_body_size().y, small.get_body_size().y, "wrapping adds lines")


func test_choices_appear_after_the_text_and_navigation_wraps() -> void:
	var bubble: SpeechBubble = _make("mox")
	bubble.setup_text("mox", "Press it?", ["Thumbs-up: Press it", "Head shake: Don't"])
	_open(bubble)
	_type_all(bubble)
	assert_eq(bubble.get_state(), SpeechBubble.State.CHOOSING)
	assert_eq(bubble.get_choices().size(), 2)
	assert_eq(bubble.get_choices()[0]["gesture"], "thumbs_up")
	assert_eq(bubble.get_choices()[1]["label"], "Don't")
	assert_eq(bubble.get_choice_index(), 0)
	bubble.move_choice(1)
	assert_eq(bubble.get_choice_index(), 1)
	bubble.move_choice(1)
	assert_eq(bubble.get_choice_index(), 0, "wraps around")
	bubble.move_choice(-1)
	assert_eq(bubble.get_choice_index(), 1)


func test_confirm_picks_the_highlighted_choice() -> void:
	var bubble: SpeechBubble = _make("mox")
	bubble.setup_text("mox", "Press it?", ["Yes", "No"])
	_open(bubble)
	_type_all(bubble)
	var picked: Array[int] = []
	bubble.choice_made.connect(func(index: int) -> void: picked.append(index))
	bubble.move_choice(1)
	bubble.confirm()
	assert_eq(picked, [1])
	assert_has(_audio.sfx_ids, "menu_confirm")


func test_choices_grow_the_bubble() -> void:
	var bubble: SpeechBubble = _make("mox")
	bubble.setup_text("mox", "Press it?", ["Yes", "No"])
	var before: int = bubble.get_body_size().y
	_open(bubble)
	_type_all(bubble)
	assert_gt(bubble.get_body_size().y, before)


func test_gesture_bubble_holds_then_reports_advanced() -> void:
	var bubble: SpeechBubble = _make("red")
	bubble.setup_gesture("red", "thumbs-up")
	assert_eq(bubble.get_kind(), SpeechBubble.Kind.GESTURE)
	assert_eq(bubble.get_gesture_id(), "thumbs_up", "aliases resolve")
	_open(bubble)
	assert_eq(bubble.get_state(), SpeechBubble.State.HOLDING)
	assert_has(_audio.sfx_ids, "red_thumbs_up")
	var advanced: Array[bool] = []
	bubble.advanced.connect(func() -> void: advanced.append(true))
	bubble.tick(0.5)
	assert_eq(advanced.size(), 0, "still holding")
	bubble.tick(1.0)
	assert_eq(advanced.size(), 1)
	bubble.tick(1.0)
	assert_eq(advanced.size(), 1, "reports once")


func test_confirm_cuts_a_gesture_short() -> void:
	var bubble: SpeechBubble = _make("red")
	bubble.setup_gesture("red", "heart")
	_open(bubble)
	var advanced: Array[bool] = []
	bubble.advanced.connect(func() -> void: advanced.append(true))
	bubble.confirm()
	assert_eq(advanced.size(), 1)


func test_gesture_bubble_is_the_small_pop_up_size() -> void:
	var bubble: SpeechBubble = _make("red")
	bubble.setup_gesture("red", "question")
	assert_eq(bubble.get_body_size(), Vector2i(28, 26))
	assert_false(bubble.has_name_tag(), "Red's pop-up has no name tag")


func test_narrator_uses_the_plain_box_at_the_bottom() -> void:
	var bubble: SpeechBubble = _make("narrator")
	bubble.setup_text("narrator", "A stone pillar.")
	assert_eq(bubble.get_style(), SpeechBubble.STYLE_BOX)
	var box: Dictionary = DataDB.get_value("ui/dialogue_ui", "box", {})
	assert_eq(bubble.get_body_rect().position, Vector2(float(box["x"]), float(box["y"])))
	assert_eq(bubble.get_body_rect().size, Vector2(float(box["w"]), float(box["h"])))
	assert_false(bubble.has_name_tag(), "the narrator has no name")
	_open(bubble)
	_type_all(bubble)
	assert_true(bubble.is_finished())


func test_a_sign_gets_a_box_with_its_name() -> void:
	var bubble: SpeechBubble = _make("sign")
	bubble.setup_text("sign", "TEST ROOM")
	assert_eq(bubble.get_style(), SpeechBubble.STYLE_BOX)
	assert_true(bubble.has_name_tag())
	assert_eq(bubble.get_name_text(), "Sign")


func test_speaker_names_and_accents_come_from_data() -> void:
	var bubble: SpeechBubble = _make("zero_old")
	bubble.setup_text("zero_old", "SOUND OFF!")
	assert_eq(bubble.get_name_text(), "Old Zero")
	var stranger: SpeechBubble = _make("old_man_jenkins")
	stranger.setup_text("old_man_jenkins", "Hm.")
	assert_eq(stranger.get_name_text(), "Old_man_jenkins".capitalize(), "unknown speakers get a tidied id")


func test_close_pops_out_frees_the_node_and_leaves_the_modal_group() -> void:
	var bubble: SpeechBubble = _make()
	bubble.setup_text("otis", SHORT)
	_open(bubble)
	assert_true(bubble.is_in_group(UiStage.MODAL_GROUP))
	var closed: Array[bool] = []
	bubble.closed.connect(func() -> void: closed.append(true))
	bubble.close()
	assert_eq(bubble.get_state(), SpeechBubble.State.CLOSING)
	bubble.tick(0.2)
	assert_eq(closed.size(), 1)
	assert_false(bubble.is_in_group(UiStage.MODAL_GROUP))
	assert_true(bubble.is_queued_for_deletion())


# ---- following a speaker in 3D ----

func _world(position: Vector3) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(384, 216)
	add_to_root(viewport)
	var camera: Camera3D = Camera3D.new()
	viewport.add_child(camera)
	camera.fov = 30.0
	camera.look_at_from_position(Vector3(0, 7, 7), Vector3.ZERO)
	var speaker: Node3D = Node3D.new()
	viewport.add_child(speaker)
	speaker.position = position
	return {"camera": camera, "speaker": speaker}


func test_bubble_sits_above_the_speakers_head_and_follows_it() -> void:
	var world: Dictionary = _world(Vector3.ZERO)
	var speaker: Node3D = world["speaker"]
	var bubble: SpeechBubble = _make("otis")
	bubble.camera = world["camera"]
	bubble.set_target(speaker, 1.25)
	bubble.setup_text("otis", "Hi")
	bubble.tick(0.0)
	var head: Vector2 = BubblePlacement.project_to_stage(world["camera"], Vector3(0, 1.25, 0), Vector2(384, 216))
	var placement: BubblePlacement.Result = bubble.get_placement()
	assert_false(bubble.is_flipped())
	assert_almost_eq(placement.tail_x, head.x, 0.01, "tail points at the head's x")
	assert_lt(placement.rect.end.y, head.y, "the body is above the head")
	assert_almost_eq(placement.tail_tip.y, head.y - float(DataDB.get_value("ui/dialogue_ui", "bubble.tail_gap", 0)), 0.01)
	# Walk the speaker to the right: the bubble follows.
	speaker.position = Vector3(2.0, 0, 0)
	bubble.tick(0.0)
	assert_gt(bubble.get_placement().tail_x, placement.tail_x)


func test_bubble_flips_below_when_the_speaker_is_at_the_top_of_the_screen() -> void:
	var world: Dictionary = _world(Vector3(0, 0, -4.5))
	var bubble: SpeechBubble = _make("otis")
	bubble.camera = world["camera"]
	bubble.set_target(world["speaker"], 1.25)
	bubble.setup_text("otis", "Hello there, this is a bubble with some text in it.")
	bubble.tick(0.0)
	assert_true(bubble.is_flipped())
	assert_gt(bubble.get_placement().rect.position.y, bubble.get_placement().tail_tip.y)


func test_bubble_is_kept_inside_the_screen_for_a_speaker_near_the_edge() -> void:
	var world: Dictionary = _world(Vector3(-4.2, 0, 0))
	var bubble: SpeechBubble = _make("otis")
	bubble.camera = world["camera"]
	bubble.set_target(world["speaker"], 1.25)
	bubble.setup_text("otis", "Hello there, this is a bubble with some text in it.")
	bubble.tick(0.0)
	var rect: Rect2 = bubble.get_body_rect()
	assert_ge(rect.position.x, 0.0)
	assert_le(rect.end.x, 384.0)
	assert_ge(rect.position.y, 0.0)


func test_without_a_speaker_the_bubble_uses_a_fixed_anchor() -> void:
	var bubble: SpeechBubble = _make("otis")
	bubble.set_anchor_point(Vector2(100, 150))
	bubble.setup_text("otis", "Hi")
	bubble.tick(0.0)
	assert_almost_eq(bubble.get_placement().tail_x, 100.0, 0.01)


func test_confirm_press_through_input_advances_when_listening() -> void:
	var bubble: SpeechBubble = _make()
	bubble.listen_input = true
	bubble.setup_text("otis", SHORT)
	_open(bubble)
	await tree.process_frame  # the guard ignores input on the frame the bubble was made
	var event: InputEventAction = InputEventAction.new()
	event.action = &"confirm"
	event.pressed = true
	tree.root.push_input(event)
	assert_eq(bubble.get_state(), SpeechBubble.State.WAITING, "confirm skipped the typing")
