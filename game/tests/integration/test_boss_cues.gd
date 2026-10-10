extends TestCase
## The boss cues that were in the design but never reached the screen (bugs B10, B11, B12), through the slice HUD bound to
## a stand-in host (the real CombatDirector) and through the real BossFight / Hushmaster signals:
##   B10  Quiet Hours: the screen edges fizz and the hack panel says "Jamming" while the dish hums; it clears when the lock
##        lands, when the dish is hit, or when time runs out; while locked the panel shows the lock and its static.
##   B11  "Jack in": the hack button's prompt follows hack_prompt_changed, with the words from data and the live button name.
##   B12  The boss bar's leg pips: a label with the count, bigger pips, a hint until the first drop, and a flash on a drop.

const HUD_SCENE: String = "res://scenes/ui/slice/action_hud.tscn"

var _audio: FakeAudio = null
var _host: FakeSliceHost = null
var _hud: ActionHud = null
var _kit: BossKit = null


func _setup() -> void:
	Features.clear_overrides()
	_audio = FakeAudio.new()
	_host = FakeSliceHost.new()
	_hud = (load(HUD_SCENE) as PackedScene).instantiate() as ActionHud
	_hud.manual_ticks = true
	_hud.animations_enabled = false
	_hud.listen_input = false
	_hud.relocate_to_window = false
	_hud.auto_router = false
	_hud.audio.target = _audio
	add_to_root(_hud)
	_hud.get_slice_pause().pause_game = false
	_hud.get_continue_screen().pause_game = false
	_hud.get_feel_panel().pause_game = false
	_hud.bind(_host)


func after_each() -> void:
	SandboxPauseGate.clear(tree)
	Features.clear_overrides()
	if _host != null:
		if is_instance_valid(_hud) and _hud.is_inside_tree():
			_hud.unbind()
		_host.free_nodes()
		_host = null


func _model() -> HackPanelModel:
	return _hud.get_hack_panel().model


# ---- B10: the Quiet Hours warning ----

func test_the_warning_shows_on_the_signal() -> void:
	_setup()
	assert_false(_model().is_jamming())
	assert_false(_hud.get_quiet_fx().is_showing())
	_host.boss.quiet_hours_warning.emit(1400.0)
	_hud.tick(0.1)
	assert_true(_model().is_jamming(), "the hack panel shows the jamming state")
	assert_gt(_model().fizz_level(), 0.0, "static over the panel and the deck")
	assert_gt(_hud.get_quiet_fx().target_level(), 0.0, "the screen edges fizz")
	assert_true(_hud.get_quiet_fx().is_showing())
	assert_false(_model().is_locked(), "not locked yet: that comes 1.4 s later")


func test_the_warning_also_comes_from_the_director_when_there_is_no_boss_fight_object() -> void:
	_setup()
	_host.director.quiet_hours_warning.emit(1400.0)
	assert_false(_model().is_jamming(), "the HUD follows the boss source (the director only carries it when it IS the source)")
	assert_true(_host.director.has_signal(&"quiet_hours_warning"))
	assert_true(_host.director.has_signal(&"quiet_hours_cleared"))


func test_the_fizz_thickens_as_the_lock_gets_close() -> void:
	_setup()
	_host.boss.quiet_hours_warning.emit(1400.0)
	var early: float = _model().edge_fizz_level()
	_hud.tick(1.0)
	var late: float = _model().edge_fizz_level()
	assert_gt(late, early)
	assert_le(late, 1.0)
	assert_ge(early, 0.3)


func test_the_warning_clears_when_the_dish_is_hit() -> void:
	_setup()
	_host.boss.quiet_hours_warning.emit(1400.0)
	_hud.tick(0.3)
	_host.boss.quiet_hours_cleared.emit()
	assert_false(_model().is_jamming())
	assert_eq(_model().fizz_level(), 0.0)
	_hud.tick(0.1)
	assert_eq(_hud.get_quiet_fx().target_level(), 0.0)
	_hud.tick(1.0)
	assert_false(_hud.get_quiet_fx().is_showing(), "the edges ease out and are gone")


func test_the_warning_hands_over_to_the_lock() -> void:
	_setup()
	_host.boss.quiet_hours_warning.emit(1400.0)
	_hud.tick(1.4)
	_host.director.hack_locked.emit(true, 5000.0)
	assert_false(_model().is_jamming(), "the warning is over")
	assert_true(_model().is_locked(), "hacks show as locked")
	assert_eq(_model().fizz_level(), 1.0, "with the full lockout static")
	_hud.tick(0.1)
	assert_eq(_hud.get_quiet_fx().target_level(), 0.0, "no edge fizz once the lock is on")
	_host.director.hack_locked.emit(false, 0.0)
	assert_false(_model().is_locked())
	assert_eq(_model().fizz_level(), 0.0)


func test_a_warning_the_lock_never_follows_runs_out_by_itself() -> void:
	_setup()
	_host.boss.quiet_hours_warning.emit(1400.0)
	_hud.tick(1.0)
	assert_true(_model().is_jamming())
	_hud.tick(1.2)
	assert_false(_model().is_jamming(), "1.4 s plus the grace is up")
	_hud.tick(1.0)
	assert_false(_hud.get_quiet_fx().is_showing())


func test_the_panel_and_the_deck_draw_the_jamming_state_without_errors() -> void:
	_setup()
	_hud.size = Vector2(SandboxStyle.REFERENCE_SIZE)
	_hud.get_hack_panel().size = _hud.size
	_hud.get_deck().size = _hud.size
	_host.boss.quiet_hours_warning.emit(1400.0)
	for i: int in 6:
		_hud.tick(0.1)
		_hud.get_hack_panel().queue_redraw()
		_hud.get_deck().queue_redraw()
		await tree.process_frame
	assert_true(_hud.get_hack_panel().is_inside_tree())


func test_the_fizz_layer_sits_under_the_readouts_and_fills_the_hud() -> void:
	_setup()
	var fx: QuietHoursFx = _hud.get_quiet_fx()
	assert_eq(fx.get_index(), 0, "first child: drawn under everything")
	assert_eq(fx.size, _hud.size)
	assert_eq(fx.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_fx_eases_in_and_out_in_steps_of_time_not_frames() -> void:
	var fx: QuietHoursFx = QuietHoursFx.new()
	add_to_root(fx)
	fx.size = Vector2(384, 216)
	fx.set_level(1.0)
	fx.tick(0.05)
	assert_gt(fx.shown_level(), 0.0)
	assert_lt(fx.shown_level(), 1.0, "eases in")
	fx.tick(0.5)
	assert_eq(fx.shown_level(), 1.0)
	fx.set_level(0.0)
	fx.tick(0.1)
	assert_gt(fx.shown_level(), 0.0, "eases out")
	fx.tick(1.0)
	assert_false(fx.is_showing())


func test_the_real_fight_sends_the_warning_with_the_datas_length_and_clears_it_on_a_cut() -> void:
	_kit = BossKit.new(self)
	await _kit.arena()
	var warnings: Array[float] = []
	var clears: Array[bool] = []
	var director_warnings: Array[float] = []
	_kit.fight.quiet_hours_warning.connect(func(ms: float) -> void: warnings.append(ms))
	_kit.fight.quiet_hours_cleared.connect(func() -> void: clears.append(true))
	_kit.director.quiet_hours_warning.connect(func(ms: float) -> void: director_warnings.append(ms))
	assert_true(_kit.boss.force_pattern(&"quiet_hours"))
	await _kit.frames(5)
	assert_eq(warnings, [1400.0] as Array[float], "lock_at_ms from the boss file")
	assert_eq(director_warnings, [1400.0] as Array[float], "and the director carries it too")
	assert_eq(_kit.boss.quiet_warning_ms(), 1400.0)
	assert_true(clears.is_empty())
	_kit.boss.part(&"dish").apply_hit({"damage": 12, "source": "hack", "outcome": &"hit", "move_id": &"hack_zap"})
	await _kit.frames(5)
	assert_eq(clears.size(), 1, "one Zap on the dish ends the warning")


# ---- B11: the "Jack in" prompt ----

func test_the_jack_in_prompt_follows_the_directors_signal() -> void:
	_setup()
	var deck: CommandDeck = _hud.get_deck()
	assert_false(_model().has_prompt())
	assert_eq(deck.prompt_rect(), Rect2(), "nothing offered: no chip")
	_host.director.set_hack_prompt({"id": "jack_in", "text_key": "boss_jack_in", "button": "hack"})
	assert_true(_model().has_prompt())
	assert_eq(_model().prompt_text(), "Jack in", "the words come from data/text/slice_ui.json")
	assert_eq(_model().prompt_button(), "hack")
	_hud.tick(0.1)
	assert_gt(deck.prompt_rect().size.x, 20.0, "a chip is laid out")
	assert_lt(deck.prompt_rect().end.y, deck.row_rects()[0].position.y, "above the deck, near the hack panel's own bar")
	_host.director.clear_hack_prompt()
	assert_false(_model().has_prompt())
	assert_eq(deck.prompt_rect(), Rect2(), "hidden again when the prompt clears")


func test_a_prompt_that_is_already_up_when_the_hud_binds_shows() -> void:
	_setup()
	_host.director.set_hack_prompt({"id": "jack_in", "text_key": "boss_jack_in", "button": "hack"})
	_hud.bind(_host)
	assert_true(_model().has_prompt())
	assert_eq(_model().prompt_text(), "Jack in")


func test_an_unknown_prompt_key_falls_back_to_a_plain_word() -> void:
	_setup()
	_host.director.set_hack_prompt({"id": "x", "text_key": "no_such_key", "button": "hack"})
	assert_eq(_model().prompt_text(), "Use")


func test_the_prompt_names_the_live_button_and_pops_in_like_an_interact_prompt() -> void:
	_setup()
	_host.director.set_hack_prompt({"id": "jack_in", "text_key": "boss_jack_in", "button": "hack"})
	_hud.tick(0.01)
	var deck: CommandDeck = _hud.get_deck()
	assert_false(deck.prompt_button_text.is_empty())
	assert_eq(deck.prompt_button_text, _hud.hack_button_text())
	assert_lt(deck.prompt_pop_scale(), 1.0, "starts small")
	_hud.tick(0.07)
	assert_gt(deck.prompt_pop_scale(), 1.0, "overshoots")
	_hud.tick(0.2)
	assert_eq(deck.prompt_pop_scale(), 1.0, "settles")


func test_the_hack_bar_says_jack_in_while_the_prompt_is_up_and_draws_cleanly() -> void:
	_setup()
	_hud.size = Vector2(SandboxStyle.REFERENCE_SIZE)
	_hud.get_deck().size = _hud.size
	_host.director.set_hack_prompt({"id": "jack_in", "text_key": "boss_jack_in", "button": "hack"})
	for i: int in 8:
		_hud.tick(0.1)
		_hud.get_deck().queue_redraw()
		await tree.process_frame
	assert_true(_hud.get_deck().is_inside_tree())


func test_the_real_hushmaster_offers_jack_in_to_the_hud() -> void:
	_setup()
	_kit = BossKit.new(self)
	await _kit.arena()
	_kit.director.hack_prompt_changed.connect(func(info: Dictionary) -> void: _model().set_prompt(info))
	_kit.boss.hp = 0
	_kit.boss._finish_when_toppled = false
	_kit.boss._begin_topple()
	await _kit.until(func() -> bool: return not _kit.director.hack_prompt.is_empty(), 400)
	assert_true(_model().has_prompt(), "the topple's prompt reached the hack panel's model")
	assert_eq(_model().prompt_text(), "Jack in")
	assert_eq(_model().prompt_id(), "jack_in")


# ---- B12: the leg pips ----

func _show_rig_bar() -> BossBarModel:
	_host.boss.boss_bar_shown.emit({"name": "The Hushmaster", "hp": 500.0, "hp_max": 500.0, "phases": [{"id": "rig", "name": "The rig"}, {"id": "mech", "name": "The Heap"}], "phase": 0})
	_host.boss.boss_pips_changed.emit(4, 4)
	_hud.tick(1.0)
	return _hud.get_boss_bar().model


func test_the_pips_have_a_label_and_a_count_from_data() -> void:
	_setup()
	var model: BossBarModel = _show_rig_bar()
	assert_eq(model.pips_label(), "Legs")
	assert_eq(model.pips_count_text(), "4/4")
	_host.boss.boss_pips_changed.emit(3, 4)
	assert_eq(model.pips_count_text(), "3/4")
	_host.boss.boss_phase_changed.emit(1, "The Heap")
	assert_eq(model.pips_label(), "Plates", "the Heap's armour plates have their own word")


func test_the_pips_are_big() -> void:
	assert_ge(SliceUiData.num("boss_bar.part_pip_h"), 2.0 * SliceUiData.num("boss_bar.pip_h"), "twice the old height or more")
	assert_gt(SliceUiData.num("boss_bar.part_pip_w"), SliceUiData.num("boss_bar.pip_w"))


func test_a_hint_waits_under_the_pips_until_the_first_one_drops() -> void:
	_setup()
	var model: BossBarModel = _show_rig_bar()
	assert_eq(model.pips_hint(), "Zap the leg relays")
	_host.boss.boss_pips_changed.emit(3, 4)
	assert_eq(model.pips_hint(), "", "once a leg is down the player has the idea")


func test_a_pip_dropping_flashes_and_the_flash_ends() -> void:
	_setup()
	var model: BossBarModel = _show_rig_bar()
	assert_eq(model.pips_flash(), 0.0, "the first count never flashes")
	assert_false(model.pip_flashing(3))
	_host.boss.boss_pips_changed.emit(3, 4)
	assert_gt(model.pips_flash(), 0.9)
	assert_true(model.pip_flashing(3), "the pip that went out blinks")
	assert_false(model.pip_flashing(0), "the others stay as they were")
	assert_false(model.pip_flashing(2))
	_hud.tick(0.1)
	assert_false(model.pip_flashing(3), "it blinks off in steps")
	_hud.tick(0.1)
	assert_true(model.pip_flashing(3))
	_hud.tick(1.0)
	assert_eq(model.pips_flash(), 0.0)
	assert_false(model.pip_flashing(3), "and it is over")


func test_two_legs_dropping_at_once_flash_together() -> void:
	_setup()
	var model: BossBarModel = _show_rig_bar()
	_host.boss.boss_pips_changed.emit(2, 4)
	assert_true(model.pip_flashing(2))
	assert_true(model.pip_flashing(3))
	assert_false(model.pip_flashing(1))


func test_a_new_row_of_pips_does_not_flash() -> void:
	_setup()
	var model: BossBarModel = _show_rig_bar()
	_host.boss.boss_pips_changed.emit(3, 4)
	_host.boss.boss_pips_changed.emit(4, 4)
	assert_false(model.pip_flashing(3), "a rise is not a drop")
	_host.boss.boss_pips_changed.emit(0, 0)
	_host.boss.boss_pips_changed.emit(4, 4)
	assert_eq(model.pips_flash(), 0.0, "a new count resets the flash")


func test_the_bar_draws_the_pips_with_a_flash_without_errors() -> void:
	_setup()
	_hud.size = Vector2(SandboxStyle.REFERENCE_SIZE)
	var bar: BossBar = _hud.get_boss_bar()
	bar.size = _hud.size
	var model: BossBarModel = _show_rig_bar()
	_host.boss.boss_pips_changed.emit(2, 4)
	for i: int in 5:
		_hud.tick(0.1)
		bar.queue_redraw()
		await tree.process_frame
	assert_true(model.is_visible())
	assert_gt(bar.bar_rect(_hud.size).size.x, 100.0)
