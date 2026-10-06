extends TestCase
## The ends of a fight: the K.O.! beat on the final hit, the victory screen (XP, credits, drops and
## level-ups counting up, one press skips), Ran, and the game over screen with Retry / Back to title.

const HUD_SCENE: String = "res://scenes/ui/battle/battle_hud.tscn"
const OK: MenuInput.Cmd = MenuInput.Cmd.CONFIRM
const DOWN: MenuInput.Cmd = MenuInput.Cmd.DOWN
const BACK: MenuInput.Cmd = MenuInput.Cmd.CANCEL

var _audio: FakeAudio = null
var _hud: BattleHud = null
var _stub: BattleHudStub = null
var _finished: Array = []


func _setup() -> void:
	_audio = FakeAudio.new()
	_hud = (load(HUD_SCENE) as PackedScene).instantiate() as BattleHud
	_hud.manual_ticks = true
	_hud.animations_enabled = false
	_hud.audio.target = _audio
	add_to_root(_hud)
	_stub = BattleHudStub.new()
	_hud.bind(_stub)
	_stub.start()
	_finished.clear()
	_hud.finished.connect(func(result: String, choice: String) -> void: _finished.append([result, choice]))


func _knock_out_everyone() -> void:
	_stub.combatant_down.emit("e1")
	_stub.combatant_down.emit("e2")
	_stub.combatant_down.emit("e3")


func _ko_popups() -> Array[BattlePopup]:
	var out: Array[BattlePopup] = []
	for popup: BattlePopup in _hud.get_popups():
		if popup.kind == BattlePopup.Kind.KO:
			out.append(popup)
	return out


# ---- K.O.! ----

func test_the_final_enemy_going_down_slams_a_ko_with_a_freeze_signal() -> void:
	_setup()
	var freezes: Array = []
	_hud.ko_started.connect(func(target: String, seconds: float) -> void: freezes.append([target, seconds]))
	_stub.combatant_down.emit("e1")
	_stub.combatant_down.emit("e2")
	assert_eq(_ko_popups().size(), 0, "not the last one yet")
	_stub.combatant_down.emit("e3")
	assert_eq(_ko_popups().size(), 1)
	assert_eq(_ko_popups()[0].text, "K.O.!")
	assert_eq(freezes.size(), 1)
	assert_eq(freezes[0][0], "e3")
	assert_gt(freezes[0][1], 0.0)
	assert_has(_audio.sfx_ids, "battle_ko")
	assert_eq(_hud.get_mode(), BattleHud.Mode.KO)


func test_ko_does_not_fire_for_a_fallen_friend_or_when_enemies_flee() -> void:
	_setup()
	_stub.combatant_down.emit("otis")
	_stub.combatant_down.emit("e1")
	_stub.combatant_down.emit("e2")
	_stub.combatant_fled.emit("e3")
	assert_eq(_ko_popups().size(), 0)


func test_ko_flashes_the_screen_white_in_steps() -> void:
	_setup()
	_knock_out_everyone()
	var flash: ColorRect = _hud.get_node("Flash") as ColorRect
	assert_gt(flash.color.a, 0.5)
	_hud.tick(0.0834)
	var second: float = flash.color.a
	assert_lt(second, 0.7)
	_hud.tick(1.0)
	assert_eq(flash.color.a, 0.0)


func test_ko_color_cycles_and_the_letters_overshoot_in() -> void:
	var popup: BattlePopup = BattlePopup.make_ko()
	own(popup)
	popup.set_age(0.01)
	assert_eq(popup.get_pop_scale(), 0.5)
	popup.set_age(0.0834 + 0.01)
	assert_eq(popup.get_pop_scale(), 1.3)


func test_the_ko_is_only_shown_once_even_when_battle_ended_names_the_target() -> void:
	_setup()
	_knock_out_everyone()
	_stub.battle_ended.emit("win", BattleHudStub.default_report())
	assert_eq(_ko_popups().size(), 1)


func test_ko_from_the_report_when_the_hud_missed_the_down_signal() -> void:
	_setup()
	_stub.battle_ended.emit("win", BattleHudStub.default_report())
	assert_eq(_ko_popups().size(), 1, "final_ko_target in the report triggers it")


# ---- the victory screen ----

func test_victory_waits_for_the_ko_beat_then_shows() -> void:
	_setup()
	var victory: BattleVictoryScreen = _hud.get_victory_screen()
	_knock_out_everyone()
	_stub.battle_ended.emit("win", BattleHudStub.default_report())
	assert_false(victory.is_showing(), "the K.O. gets its beat first")
	assert_eq(_hud.get_mode(), BattleHud.Mode.KO)
	_hud.tick(0.5)
	assert_false(victory.is_showing())
	_hud.tick(1.2)
	assert_true(victory.is_showing())
	assert_eq(_hud.get_mode(), BattleHud.Mode.VICTORY)
	assert_has(_audio.sfx_ids, "battle_victory")


func _victory() -> BattleVictoryScreen:
	_setup()
	_knock_out_everyone()
	_stub.battle_ended.emit("win", BattleHudStub.default_report())
	_hud.tick(3.0)
	var screen: BattleVictoryScreen = _hud.get_victory_screen()
	return screen


func test_totals_count_up_instead_of_appearing() -> void:
	_setup()
	_stub.battle_ended.emit("win", {"xp": 400, "credits": 200, "drops": [], "level_ups": [], "final_ko_target": ""})
	var screen: BattleVictoryScreen = _hud.get_victory_screen()
	assert_true(screen.is_counting())
	assert_eq(screen.get_shown_xp(), 0)
	_hud.tick(0.2)
	assert_gt(screen.get_shown_xp(), 0)
	assert_lt(screen.get_shown_xp(), 400)
	assert_eq(screen.get_shown_credits(), 0, "credits start after the XP")
	_hud.tick(0.9)
	assert_eq(screen.get_shown_xp(), 400)
	assert_gt(screen.get_shown_credits(), 0)
	assert_lt(screen.get_shown_credits(), 200)
	_hud.tick(0.9)
	assert_eq(screen.get_shown_credits(), 200)


func test_counting_is_fast() -> void:
	var screen: BattleVictoryScreen = _victory()
	assert_lt(screen.get_total_time(), 3.0, "a few seconds at most, with a drop and a level-up")


func test_drops_and_level_ups_are_revealed_after_the_counts() -> void:
	_setup()
	_stub.battle_ended.emit("win", BattleHudStub.default_report())
	_hud.tick(3.0)  # past the K.O. beat
	var screen: BattleVictoryScreen = _hud.get_victory_screen()
	assert_eq(screen.get_shown_drop_count(), 0)
	assert_eq(screen.get_shown_level_up_count(), 0)
	screen.skip()
	assert_eq(screen.get_shown_drop_count(), 1)
	assert_eq(screen.get_shown_level_up_count(), 1)
	var lines: Array[String] = screen.get_lines()
	assert_has(lines, "Victory!")
	assert_has(lines, "XP 120")
	assert_has(lines, "Credits 85")
	assert_has(lines, "Ration Bar")
	assert_has(lines, "Otis is now Lv 4!")
	assert_has(lines, "Learned Heave-Ho!")


func test_level_up_gains_list_in_stat_order_with_signs() -> void:
	var screen: BattleVictoryScreen = _victory()
	var up: Dictionary = {"gains": {"speed": 1, "hp": 6, "attack": 2, "luck": 0}}
	assert_eq(screen.gain_entries(up), ["HP +6", "Atk +2", "Spd +1"])


func test_one_press_skips_the_counting_to_the_final_numbers() -> void:
	_setup()
	_stub.battle_ended.emit("win", {"xp": 900, "credits": 500, "drops": [{"item": "ration_bar", "count": 2}], "level_ups": [], "final_ko_target": ""})
	_hud.tick(0.5)  # let the input grace pass while still counting
	var screen: BattleVictoryScreen = _hud.get_victory_screen()
	assert_true(screen.is_counting())
	_hud.handle_command(OK)
	assert_false(screen.is_counting())
	assert_eq(screen.get_shown_xp(), 900)
	assert_eq(screen.get_shown_credits(), 500)
	assert_eq(screen.get_shown_drop_count(), 1)
	assert_has(screen.get_lines(), "Ration Bar x2")
	assert_true(screen.is_showing(), "the first press only skips the counting")
	assert_true(_finished.is_empty())


func test_the_next_press_leaves_and_finished_fires_once() -> void:
	_setup()
	_stub.battle_ended.emit("win", {"xp": 100, "credits": 50, "drops": [], "level_ups": [], "final_ko_target": ""})
	_hud.tick(0.5)
	_hud.handle_command(OK)
	_hud.handle_command(OK)
	assert_eq(_finished, [["win", "continue"]])
	_hud.handle_command(OK)
	_hud.tick(5.0)
	assert_eq(_finished.size(), 1)
	assert_eq(_hud.get_mode(), BattleHud.Mode.ENDED)
	assert_false(_hud.get_victory_screen().visible)
	assert_false(_hud.is_in_group(UiStage.MODAL_GROUP))


func test_it_closes_by_itself_after_a_beat() -> void:
	_setup()
	_stub.battle_ended.emit("win", {"xp": 100, "credits": 50, "drops": [], "level_ups": [], "final_ko_target": ""})
	_hud.tick(3.0)
	assert_eq(_finished.size(), 1)


func test_presses_in_the_first_moments_are_ignored() -> void:
	_setup()
	_stub.battle_ended.emit("win", {"xp": 900, "credits": 500, "drops": [], "level_ups": [], "final_ko_target": ""})
	_hud.tick(0.1)
	_hud.handle_command(OK)
	assert_true(_hud.get_victory_screen().is_counting(), "the Clutch press that landed the last hit cannot skip it")
	_hud.tick(0.4)
	_hud.handle_command(OK)
	assert_false(_hud.get_victory_screen().is_counting())


func test_cancel_and_a_left_click_also_count_as_a_press() -> void:
	_setup()
	_stub.battle_ended.emit("win", {"xp": 900, "credits": 500, "drops": [], "level_ups": [], "final_ko_target": ""})
	_hud.tick(0.5)
	_hud.handle_command(BACK)
	assert_false(_hud.get_victory_screen().is_counting())
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert_true(_hud.handle_mouse(click))
	assert_eq(_finished.size(), 1)


func test_skipping_gives_the_same_final_state_as_watching() -> void:
	var watched: BattleVictoryScreen = _victory()
	_hud.tick(1.3)
	var watched_lines: Array[String] = watched.get_lines()
	assert_true(watched.is_showing())
	_setup()
	_stub.battle_ended.emit("win", BattleHudStub.default_report())
	_hud.tick(3.0)
	_hud.get_victory_screen().skip()
	assert_eq(_hud.get_victory_screen().get_lines(), watched_lines)


func test_the_party_thumbs_up_placeholder_exists() -> void:
	assert_gt(GestureIcons.get_frames("thumbs_up").size(), 0, "the placeholder icon the screen shows")


# ---- ran ----

func test_running_away_shows_a_message_then_finishes() -> void:
	_setup()
	_stub.battle_ended.emit("ran", {})
	assert_eq(_hud.get_banner().get_current_text(), "Got away safely!")
	assert_true(_finished.is_empty())
	_hud.tick(1.2)
	assert_eq(_finished, [["ran", ""]])
	assert_false(_hud.get_victory_screen().is_showing())


# ---- game over ----

func test_losing_shows_game_over_after_a_beat_with_retry_and_back_to_title() -> void:
	_setup()
	var screen: BattleGameOverScreen = _hud.get_game_over_screen()
	_stub.battle_ended.emit("lose", {"xp": 0, "credits": 0, "drops": [], "level_ups": [], "final_ko_target": "mox"})
	assert_false(screen.is_showing())
	_hud.tick(1.0)
	assert_true(screen.is_showing())
	assert_eq(_hud.get_mode(), BattleHud.Mode.GAME_OVER)
	assert_has(_audio.sfx_ids, "battle_game_over")
	var labels: Array[String] = []
	for row: Dictionary in screen.get_list().get_items():
		labels.append(str(row["label"]))
	assert_eq(labels, ["Retry", "Back to title"])


func test_retry_emits_the_stub_signal_and_finishes() -> void:
	_setup()
	var retries: Array[int] = [0]
	_hud.retry_requested.connect(func() -> void: retries[0] += 1)
	_stub.battle_ended.emit("lose", {})
	_hud.tick(1.0)
	_hud.tick(0.4)
	_hud.handle_command(OK)
	assert_eq(retries[0], 1)
	assert_eq(_finished, [["lose", "retry"]])
	assert_false(_hud.get_game_over_screen().is_showing())


func test_back_to_title_emits_its_signal() -> void:
	_setup()
	var titles: Array[int] = [0]
	_hud.title_requested.connect(func() -> void: titles[0] += 1)
	_stub.battle_ended.emit("lose", {})
	_hud.tick(1.0)
	_hud.tick(0.4)
	_hud.handle_command(DOWN)
	_hud.handle_command(OK)
	assert_eq(titles[0], 1)
	assert_eq(_finished, [["lose", "title"]])


func test_game_over_ignores_input_in_its_first_moments() -> void:
	_setup()
	_stub.battle_ended.emit("lose", {})
	_hud.tick(0.9)  # the screen just appeared
	_hud.handle_command(OK)
	assert_true(_hud.get_game_over_screen().is_showing())
	assert_true(_finished.is_empty())


func test_game_over_works_with_the_mouse() -> void:
	_setup()
	_stub.battle_ended.emit("lose", {})
	_hud.tick(1.0)
	_hud.tick(0.4)
	var list: MenuList = _hud.get_game_over_screen().get_list()
	var at: Vector2 = list.get_global_transform() * list.get_row_rect(1).get_center()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = at
	assert_true(_hud.handle_mouse(click))
	assert_eq(_finished, [["lose", "title"]])


func test_battle_started_again_resets_the_end_state() -> void:
	_setup()
	_knock_out_everyone()
	_stub.battle_ended.emit("win", BattleHudStub.default_report())
	_hud.tick(5.0)
	_stub.start()
	assert_false(_hud.has_shown_ko())
	assert_eq(_hud.get_mode(), BattleHud.Mode.IDLE)
