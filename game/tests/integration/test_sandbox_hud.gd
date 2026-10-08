extends TestCase
## The sandbox HUD (CS-15): it reacts to every signal in docs/pivot/combat_api.md 4.6 that it uses, from
## a stub that emits them (tests/fixtures/ui/fake_combat_sandbox.gd): Red's HP, small enemy bars,
## damage numbers, parry / Lamp Flare / stagger pop-ups in the stencil lettering, the Noise meter and
## rank pop-ups, Lights On, the lock-on reticle, the camera tag, and the pause menu with the controls card.

const HUD_SCENE: String = "res://scenes/ui/sandbox/sandbox_hud.tscn"
const STEP: float = 0.0833

var _audio: FakeAudio = null
var _sandbox: FakeCombatSandbox = null
var _hud: SandboxHud = null


func _setup() -> void:
	_audio = FakeAudio.new()
	_sandbox = FakeCombatSandbox.new()
	_sandbox.add_enemy(&"grunt_1", Vector2(320, 180))
	_hud = (load(HUD_SCENE) as PackedScene).instantiate() as SandboxHud
	_hud.manual_ticks = true
	_hud.animations_enabled = false
	_hud.listen_input = false
	_hud.auto_quit = false
	_hud.audio.target = _audio
	add_to_root(_hud)
	_hud.get_pause_menu().pause_game = false
	_hud.get_feel_panel().pause_game = false
	_hud.bind(_sandbox)


func after_each() -> void:
	SandboxPauseGate.clear(tree)
	if _sandbox != null:
		if is_instance_valid(_hud) and _hud.is_inside_tree():
			_hud.unbind()
		_sandbox.free_nodes()


func _numbers() -> Array[BattlePopup]:
	var out: Array[BattlePopup] = []
	for popup: BattlePopup in _hud.get_popups():
		if popup.kind == BattlePopup.Kind.NUMBER:
			out.append(popup)
	return out


func _letters() -> Array[BattlePopup]:
	var out: Array[BattlePopup] = []
	for popup: BattlePopup in _hud.get_popups():
		if popup.kind == BattlePopup.Kind.RATING:
			out.append(popup)
	return out


# ---- HP ----

func test_red_hp_starts_from_the_registered_fighter_and_follows_the_signal() -> void:
	_setup()
	assert_eq(_hud.get_hp(), 120)
	assert_eq(_hud.get_hp_max(), 120)
	_sandbox.director.hp_changed.emit(&"red", 80, 120)
	assert_eq(_hud.get_hp(), 80)
	_sandbox.director.hp_changed.emit(&"red", 120, 120)
	assert_eq(_hud.get_hp(), 120, "healed")


func test_enemies_get_a_small_bar_only_while_hurt() -> void:
	_setup()
	_sandbox.director.hp_changed.emit(&"grunt_1", 30, 40)
	assert_eq(_hud.get_enemy_bar_ids(), ["grunt_1"] as Array[String])
	_sandbox.director.hp_changed.emit(&"grunt_1", 40, 40)
	assert_eq(_hud.get_enemy_bar_ids().size(), 0, "full health: no bar")
	_sandbox.director.hp_changed.emit(&"grunt_1", 10, 40)
	_sandbox.director.actor_died.emit(&"grunt_1")
	assert_eq(_hud.get_enemy_bar_ids().size(), 0, "dead: no bar")


func test_an_enemy_bar_fades_away_by_itself() -> void:
	_setup()
	_sandbox.director.hp_changed.emit(&"grunt_1", 30, 40)
	_hud.tick(float(SandboxUiData.ui("hud.enemy_bar.show_s", 3.0)) + float(SandboxUiData.ui("hud.enemy_bar.fade_s", 0.5)) + 0.1)
	assert_eq(_hud.get_enemy_bar_ids().size(), 0)


func test_red_is_not_given_an_enemy_bar() -> void:
	_setup()
	_sandbox.director.hp_changed.emit(&"red", 50, 120)
	assert_eq(_hud.get_enemy_bar_ids().size(), 0)


# ---- damage numbers ----

func test_a_hit_pops_a_damage_number_over_the_target_in_stage_pixels() -> void:
	_setup()
	_sandbox.director.hit_landed.emit({"attacker": &"red", "target": &"grunt_1", "outcome": "hit", "damage": 12})
	var numbers: Array[BattlePopup] = _numbers()
	assert_eq(numbers.size(), 1)
	assert_eq(numbers[0].text, "12")
	var scale: Vector2 = _hud.world_scale()
	assert_almost_eq(scale.x, 0.6, 0.001, "640 wide picture onto the 384 wide stage")
	assert_almost_eq(numbers[0].position.x, 320.0 * scale.x + 6.0 * float((1 % 3) - 1) + 0.0, 8.0)
	assert_lt(numbers[0].position.y, 180.0 * scale.y, "it sits above the target")


func test_no_number_for_a_miss_an_evade_or_zero_damage() -> void:
	_setup()
	_sandbox.director.hit_landed.emit({"target": &"grunt_1", "outcome": "evaded", "damage": 9})
	_sandbox.director.hit_landed.emit({"target": &"grunt_1", "outcome": "ignored", "damage": 9})
	_sandbox.director.hit_landed.emit({"target": &"red", "outcome": "perfect_parry", "damage": 0})
	assert_eq(_numbers().size(), 0)


func test_damage_to_red_is_not_drawn_white() -> void:
	_setup()
	_sandbox.director.hit_landed.emit({"target": &"grunt_1", "outcome": "hit", "damage": 5})
	_sandbox.director.hit_landed.emit({"target": &"red", "outcome": "hit", "damage": 7})
	var numbers: Array[BattlePopup] = _numbers()
	assert_eq(numbers[0].get_fill_color(), Color.html("#FFFFFF"))
	assert_ne(numbers[1].get_fill_color(), Color.html("#FFFFFF"))


func test_numbers_on_one_target_stack_up_instead_of_overlapping() -> void:
	_setup()
	for i: int in 3:
		_sandbox.director.hit_landed.emit({"target": &"grunt_1", "outcome": "hit", "damage": 3 + i})
	var numbers: Array[BattlePopup] = _numbers()
	assert_lt(numbers[2].position.y, numbers[0].position.y, "later hits sit higher")


func test_pop_ups_end_and_are_freed() -> void:
	_setup()
	_sandbox.director.hit_landed.emit({"target": &"grunt_1", "outcome": "hit", "damage": 3})
	assert_eq(_hud.get_popups().size(), 1)
	_hud.tick(3.0)
	assert_eq(_hud.get_popups().size(), 0)


func test_a_hit_with_no_known_position_still_pops_in_the_middle() -> void:
	_setup()
	_sandbox.director.hit_landed.emit({"target": &"ghost", "outcome": "hit", "damage": 4})
	var number: BattlePopup = _numbers()[0]
	assert_true(number.position.x > 100.0 and number.position.x < 300.0)


# ---- parry, Lamp Flare, stagger ----

func test_each_parry_rating_has_its_own_words_and_the_stencil_look() -> void:
	_setup()
	var cases: Dictionary = {"nice": "Guard!", "rad": "Parry!", "totally_rad": "Perfect Parry!", "miss": "Missed"}
	for rating: String in cases:
		_sandbox.positions["red"] = Vector2(320, 200)
		_sandbox.director.parry_judged.emit({"attacker": &"grunt_1", "rating": rating, "outcome": "parried", "delta_ms": 10})
		var popup: BattlePopup = _letters().back()
		assert_eq(popup.text, cases[rating], rating)
		assert_eq(popup.kind, BattlePopup.Kind.RATING, "it is the battle HUD's stencil lettering")


func test_a_perfect_parry_is_the_loud_cycling_lettering() -> void:
	_setup()
	_sandbox.director.parry_judged.emit({"rating": "totally_rad"})
	var popup: BattlePopup = _letters().back()
	assert_eq(popup.style_id, "totally_rad")


func test_a_perfect_dodge_pops_lamp_flare() -> void:
	_setup()
	_sandbox.director.perfect_dodge.emit({"attacker": &"grunt_1", "move_id": &"swipe"})
	assert_eq(_letters().back().text, SandboxUiData.text("popups.lamp_flare"))
	_sandbox.director.flare_started.emit({"source": "dodge", "duration_s": 2.5, "enemy_scale": 0.25})
	assert_eq(_letters().size(), 1, "the flare that follows a dodge does not pop a second one")
	assert_true(_hud.is_flaring())


func test_a_parry_flare_pops_lamp_flare_itself() -> void:
	_setup()
	_sandbox.director.flare_started.emit({"source": "parry", "duration_s": 2.5, "enemy_scale": 0.25})
	assert_eq(_letters().size(), 1)
	assert_eq(_letters()[0].text, SandboxUiData.text("popups.lamp_flare"))


func test_the_flare_timer_runs_down_and_ends() -> void:
	_setup()
	_sandbox.director.flare_started.emit({"source": "dodge", "duration_s": 2.0})
	_hud.tick(1.0)
	assert_true(_hud.is_flaring())
	_sandbox.director.flare_ended.emit()
	assert_false(_hud.is_flaring())


func test_a_stagger_pops_over_the_enemy() -> void:
	_setup()
	_sandbox.director.stagger.emit({"target": &"grunt_1", "by": "parry"})
	assert_eq(_letters().back().text, "Staggered!")
	_sandbox.director.stagger.emit({"target": &"grunt_1", "by": "poise"})
	assert_eq(_letters().back().text, "Poise Break!")


# ---- Noise and Lights On ----

func test_the_noise_meter_follows_the_signal() -> void:
	_setup()
	_sandbox.director.noise_changed.emit(240.0, 0.4, &"nice", "Nice!")
	var noise: Dictionary = _hud.get_noise()
	assert_almost_eq(float(noise["points"]), 240.0, 0.01)
	assert_almost_eq(float(noise["fill"]), 0.4, 0.001)
	assert_eq(noise["rank_name"], "Nice!")


func test_a_rank_up_pops_the_rank_name_and_plays_its_sound() -> void:
	_setup()
	_sandbox.director.noise_rank_changed.emit(&"rad", "Rad!", true)
	assert_eq(_letters().back().text, "Rad!")
	assert_eq(_letters().back().style_id, "rad")
	assert_has(_audio.sfx_ids, "combat_noise_rank_up")
	_sandbox.director.noise_rank_changed.emit(&"totally_rad", "TOTALLY RAD!", true)
	assert_eq(_letters().back().style_id, "totally_rad")


func test_a_rank_down_is_quiet() -> void:
	_setup()
	_sandbox.director.noise_rank_changed.emit(&"nice", "Nice!", false)
	assert_eq(_letters().size(), 0)
	assert_does_not_have(_audio.sfx_ids, "combat_noise_rank_up")


func test_an_unknown_rank_still_gets_a_pop_up_in_the_default_style() -> void:
	_setup()
	_sandbox.director.noise_rank_changed.emit(&"mystery_rank", "Whoa!", true)
	assert_eq(_letters().back().text, "Whoa!")


func test_lights_on_shows_and_runs_down() -> void:
	_setup()
	assert_false(_hud.is_lights_on())
	_sandbox.director.lights_on_changed.emit(true, 8.0)
	assert_true(_hud.is_lights_on())
	_hud.tick(2.0)
	assert_true(_hud.is_lights_on())
	_sandbox.director.lights_on_changed.emit(false, 0.0)
	assert_false(_hud.is_lights_on())


# ---- lock-on and camera ----

func test_the_reticle_follows_the_lock_target_and_plays_its_sound() -> void:
	_setup()
	var target: CombatActor = _sandbox.director.get_actor(&"grunt_1")
	_sandbox.lock_on.target_changed.emit(target)
	assert_eq(_hud.get_lock_id(), "grunt_1")
	assert_has(_audio.sfx_ids, "combat_lock_on")
	assert_true(_hud.position_of("grunt_1", &"center").is_finite())
	_sandbox.lock_on.target_changed.emit(null)
	assert_eq(_hud.get_lock_id(), "")


func test_letting_go_does_not_play_the_lock_sound() -> void:
	_setup()
	_sandbox.lock_on.target_changed.emit(null)
	assert_does_not_have(_audio.sfx_ids, "combat_lock_on")


func test_a_dead_lock_target_clears_the_reticle() -> void:
	_setup()
	_sandbox.lock_on.target_changed.emit(_sandbox.director.get_actor(&"grunt_1"))
	_sandbox.director.actor_died.emit(&"grunt_1")
	assert_eq(_hud.get_lock_id(), "")


func test_the_camera_tag_follows_the_mode() -> void:
	_setup()
	assert_eq(_hud.get_camera_text(), SandboxUiData.text("hud.camera_orbit"))
	_sandbox.camera.mode_changed.emit(1)
	assert_eq(_hud.get_camera_text(), SandboxUiData.text("hud.camera_diorama"))
	assert_eq(_hud.get_pause_menu().get_card().camera_mode_text, SandboxUiData.text("hud.camera_diorama"), "the card shows it too")


# ---- the whole thing draws ----

func test_everything_draws_with_every_state_on() -> void:
	_setup()
	_sandbox.director.hp_changed.emit(&"red", 20, 120)
	_sandbox.director.hp_changed.emit(&"grunt_1", 10, 40)
	_sandbox.director.noise_changed.emit(900.0, 1.0, &"rad", "Rad!")
	_sandbox.director.lights_on_changed.emit(true, 8.0)
	_sandbox.director.flare_started.emit({"source": "dodge", "duration_s": 2.5})
	_sandbox.lock_on.target_changed.emit(_sandbox.director.get_actor(&"grunt_1"))
	_sandbox.director.hit_landed.emit({"target": &"grunt_1", "outcome": "hit", "damage": 14})
	for i: int in 3:
		_hud.tick(0.1)
		await tree.process_frame
	assert_eq(_hud.get_hp(), 20)


func test_unbinding_disconnects_everything() -> void:
	_setup()
	_hud.unbind()
	_sandbox.director.hp_changed.emit(&"red", 5, 120)
	assert_eq(_hud.get_hp(), 120, "no longer listening")


# ---- the pause menu ----

func test_the_pause_menu_opens_and_lists_its_four_rows() -> void:
	_setup()
	var pause: SandboxPause = _hud.get_pause_menu()
	assert_false(pause.is_open())
	_hud.open_pause()
	assert_true(pause.is_open())
	assert_true(_hud.is_menu_open())
	var ids: Array[String] = []
	for i: int in SandboxPause.ITEM_IDS.size():
		ids.append(pause.get_item_id(i))
	assert_eq(ids, ["resume", "reset", "controls", "quit"] as Array[String])
	for id: String in ids:
		assert_ne(SandboxUiData.text("pause.%s" % id), "", "%s has words" % id)


func test_resume_closes_it() -> void:
	_setup()
	var pause: SandboxPause = _hud.get_pause_menu()
	_hud.open_pause()
	pause.handle_command(MenuInput.Cmd.CONFIRM)
	assert_false(pause.is_open(), "the first row is Resume")


func test_cancel_closes_it() -> void:
	_setup()
	_hud.open_pause()
	_hud.get_pause_menu().handle_command(MenuInput.Cmd.CANCEL)
	assert_false(_hud.get_pause_menu().is_open())


func test_reset_arena_asks_the_sandbox_and_closes_the_menu() -> void:
	_setup()
	var pause: SandboxPause = _hud.get_pause_menu()
	var asked: Array[bool] = []
	_hud.reset_requested.connect(func() -> void: asked.append(true))
	_hud.open_pause()
	pause.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(pause.get_item_id(pause.get_cursor_index()), "reset")
	pause.handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_sandbox.reset_calls, 1)
	assert_eq(asked.size(), 1)
	assert_false(pause.is_open())


func test_a_reset_clears_leftover_pop_ups_and_bars() -> void:
	_setup()
	_sandbox.director.hp_changed.emit(&"grunt_1", 10, 40)
	_sandbox.director.hit_landed.emit({"target": &"grunt_1", "outcome": "hit", "damage": 3})
	_hud.open_pause()
	_hud.get_pause_menu().handle_command(MenuInput.Cmd.DOWN)
	_hud.get_pause_menu().handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(_hud.get_enemy_bar_ids().size(), 0)
	assert_eq(_hud.get_popups().size(), 0)


func test_quit_says_so_without_closing_the_test_runner() -> void:
	_setup()
	var quits: Array[bool] = []
	_hud.quit_requested.connect(func() -> void: quits.append(true))
	_hud.open_pause()
	for i: int in 3:
		_hud.get_pause_menu().handle_command(MenuInput.Cmd.DOWN)
	_hud.get_pause_menu().handle_command(MenuInput.Cmd.CONFIRM)
	assert_eq(quits.size(), 1)


func test_the_cursor_wraps() -> void:
	_setup()
	var pause: SandboxPause = _hud.get_pause_menu()
	_hud.open_pause()
	pause.handle_command(MenuInput.Cmd.UP)
	assert_eq(pause.get_item_id(pause.get_cursor_index()), "quit")
	pause.handle_command(MenuInput.Cmd.DOWN)
	assert_eq(pause.get_item_id(pause.get_cursor_index()), "resume")


func test_the_mouse_hovers_and_clicks_a_row() -> void:
	_setup()
	var pause: SandboxPause = _hud.get_pause_menu()
	_hud.open_pause()
	var layout: Dictionary = SandboxUiData.ui("pause", {})
	var rect: Rect2 = pause._row_rect(1)
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = rect.get_center()
	pause.handle_event(move)
	assert_eq(pause.get_cursor_index(), 1)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = rect.get_center()
	pause.handle_event(click)
	assert_eq(_sandbox.reset_calls, 1, "clicking Reset arena resets")
	assert_gt(float(layout["w"]), 0.0)


func test_controls_opens_the_card_with_every_button_and_cancel_comes_back() -> void:
	_setup()
	var pause: SandboxPause = _hud.get_pause_menu()
	_hud.open_pause()
	pause.handle_command(MenuInput.Cmd.DOWN)
	pause.handle_command(MenuInput.Cmd.DOWN)
	pause.handle_command(MenuInput.Cmd.CONFIRM)
	var card: ControlsCard = pause.get_card()
	assert_true(card.is_open())
	assert_true(pause.is_sub_page_open())
	card.handle_command(MenuInput.Cmd.CANCEL)
	assert_false(card.is_open())
	assert_true(pause.is_open(), "back at the pause menu")


func test_the_card_lists_every_row_from_the_contract_table() -> void:
	_setup()
	var card: ControlsCard = _hud.get_pause_menu().get_card()
	var labels: Array[String] = []
	for row: Dictionary in card.get_rows():
		labels.append(str(row["label"]))
		assert_ne(str(row["key"]), "", "%s has a keyboard button" % row["label"])
		assert_ne(str(row["pad"]), "", "%s has a controller button" % row["label"])
	for need: String in ["Move", "Camera", "Jump", "Light attack", "Heavy attack", "Dash", "Parry", "Lock on", "Camera style", "Feel knobs", "Pause"]:
		assert_has(labels, need)


func test_the_card_shows_the_real_bindings() -> void:
	_setup()
	var rows: Dictionary = {}
	for row: Dictionary in _hud.get_pause_menu().get_card().get_rows():
		rows[row["action"]] = row
	assert_true(str(rows["light"]["key"]).contains("J"), "light is on J")
	assert_true(str(rows["light"]["pad"]).contains("Square"), "and the pad's square button")
	assert_true(str(rows["parry"]["pad"]).contains("L1"))
	assert_true(str(rows["feel_panel"]["key"]).contains("F12"))
	assert_eq(rows["move"]["key"], "W A S D / Arrows", "fixed rows use the written words")


func test_confirm_on_the_card_opens_the_remap_page() -> void:
	_setup()
	var pause: SandboxPause = _hud.get_pause_menu()
	_hud.open_pause()
	pause.handle_command(MenuInput.Cmd.DOWN)
	pause.handle_command(MenuInput.Cmd.DOWN)
	pause.handle_command(MenuInput.Cmd.CONFIRM)
	pause.get_card().handle_command(MenuInput.Cmd.CONFIRM)
	var config_screen: ConfigScreen = pause.get_config_screen()
	assert_not_null(config_screen)
	assert_true(config_screen.is_open())
	assert_eq(config_screen.get_state(), ConfigScreen.State.CONTROLS, "it is the Controls page")
	config_screen.close()
	assert_true(pause.get_card().is_open(), "closing the page returns to the card")


func test_the_hint_line_follows_the_last_device_used() -> void:
	_setup()
	assert_eq(_hud.get_hint_text(), SandboxUiData.text("hud.hint_keys"))
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	_hud._input(pad)
	assert_eq(_hud.get_hint_text(), SandboxUiData.text("hud.hint_pad"))


func test_the_feel_panel_is_bound_to_the_directors_knobs() -> void:
	_setup()
	var panel: FeelPanel = _hud.get_feel_panel()
	assert_gt(panel.get_knob_list().size(), 0)
	panel.open_panel()
	panel.focus_knob("shake_scale")
	panel.handle_command(MenuInput.Cmd.RIGHT)
	assert_almost_eq(_sandbox.director.feel.get_f("shake_scale"), 1.05, 0.0001)
