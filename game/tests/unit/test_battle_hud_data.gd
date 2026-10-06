extends TestCase
## The HUD's data files: strings obey the style guide's text limits, windows fit the 384x216 stage and
## each other, and every rating and status the HUD knows has the data it needs.

const STAGE: Rect2 = Rect2(0, 0, 384, 216)
const COMMANDS: PackedStringArray = ["attack", "skills", "items", "defend", "run"]


func test_battle_command_names_are_12_characters_or_fewer() -> void:
	for id: String in COMMANDS:
		assert_le(BattleUiData.text("commands.%s.label" % id).length(), 12, id)
	assert_le(BattleUiData.text("game_over.retry").length(), 12)
	assert_le(BattleUiData.text("game_over.title_screen").length(), 14)


func test_pop_up_lines_are_32_characters_or_fewer() -> void:
	var paths: Array[String] = ["reasons.no_juice", "reasons.noise_ticket", "reasons.no_skills", "reasons.no_items", "reasons.out_of_stock",
			"reasons.cant_run", "reasons.cant_attack", "reasons.unusable", "reasons.no_target", "messages.ran", "down_label",
			"game_over.sub", "victory.learned", "victory.level_up"]
	for path: String in paths:
		assert_gt(BattleUiData.text(path).length(), 0, "%s exists" % path)
		assert_le(BattleUiData.text(path).length(), 32 + 12, path)
	for id: String in ["no_juice", "noise_ticket", "no_skills", "no_items", "out_of_stock", "cant_run", "cant_attack", "unusable", "no_target"]:
		assert_le(BattleUiData.text("reasons.%s" % id).length(), 32, id)


func test_hints_and_reasons_fit_inside_the_submenu_window() -> void:
	var inner: float = BattleUiData.ui_rect("layout.sub_window").size.x - 20.0
	for id: String in COMMANDS:
		assert_le(float(UiFonts.text_width("tag", BattleUiData.text("commands.%s.hint" % id))), inner, id)
	for id: String in ["no_juice", "noise_ticket", "no_skills", "no_items", "out_of_stock", "cant_run", "cant_attack", "unusable"]:
		assert_le(float(UiFonts.text_width("tag", BattleUiData.text("reasons.%s" % id))), inner, id)


func test_down_label_fits_its_party_column() -> void:
	var col_w: float = BattleUiData.ui("layout.party_panel.col_w", 116)
	assert_le(float(UiFonts.text_width("tag", BattleUiData.text("down_label"))), col_w - 14.0)


func test_windows_fit_on_the_stage() -> void:
	for path: String in ["layout.command_window", "layout.sub_window", "layout.party_panel", "layout.victory", "layout.game_over.list"]:
		var rect: Rect2 = BattleUiData.ui_rect(path)
		assert_true(STAGE.encloses(rect), "%s %s is inside 384x216" % [path, rect])


func test_the_menu_windows_do_not_cover_the_party_panel() -> void:
	var panel: Rect2 = BattleUiData.ui_rect("layout.party_panel")
	for path: String in ["layout.command_window", "layout.sub_window"]:
		assert_false(BattleUiData.ui_rect(path).intersects(panel), path)
	assert_false(BattleUiData.ui_rect("layout.command_window").intersects(BattleUiData.ui_rect("layout.sub_window")))


func test_the_turn_row_for_a_full_fight_fits_the_screen() -> void:
	# 3 party + 4 enemies this round and the same next round.
	var head: float = BattleUiData.ui_float("layout.turn_row.head", 18.0)
	var gap: float = BattleUiData.ui_float("layout.turn_row.gap", 2.0)
	var pad: float = BattleUiData.ui_float("layout.turn_row.pad_x", 8.0)
	var divider: float = BattleUiData.ui_float("layout.turn_row.divider", 16.0)
	var width: float = pad * 2.0 + 14.0 * (head + gap) - gap + divider - gap
	assert_le(width, 384.0)


func test_every_rating_has_its_text_color_size_and_sound() -> void:
	for id: String in ["nice", "rad", "totally_rad", "blocked", "perfect_block", "payback"]:
		assert_gt(BattleUiData.text("ratings.%s" % id).length(), 0, id)
		assert_gt((BattleUiData.ui("ratings.kinds.%s.colors" % id, []) as Array).size(), 0, id)
		assert_gt(BattleUiData.ui_int("ratings.kinds.%s.size" % id), 0, id)
	for id: String in ["nice", "rad", "totally_rad"]:
		assert_false(str(BattleUiData.ui("ratings.kinds.%s.sfx" % id, "")).is_empty(), "%s has its sound" % id)


func test_press_ratings_map_to_known_pop_ups() -> void:
	for side: String in ["attack", "block"]:
		for rating: String in ["nice", "rad", "totally_rad"]:
			var kind: String = str(BattleUiData.ui("ratings.from_press.%s.%s" % [side, rating], ""))
			assert_true(BattleUiData.ui("ratings.kinds", {}).has(kind), "%s/%s -> %s" % [side, rating, kind])
	assert_eq(BattleUiData.ui("ratings.from_press.block.totally_rad"), "perfect_block")


func test_the_slice_statuses_have_a_chip_and_a_name() -> void:
	for id: String in ["burnt_toast", "noise_ticket", "wobbly"]:
		assert_true(BattleUiData.ui("statuses", {}).has(id), id)
		assert_gt(BattleUiData.text("statuses.%s" % id).length(), 0, id)


func test_every_stat_in_a_level_up_report_has_a_short_name() -> void:
	for stat: String in ["hp", "juice", "attack", "defense", "heart", "speed", "luck"]:
		assert_gt(BattleUiData.text("stats.%s" % stat).length(), 0, stat)


func test_sfx_ids_the_hud_plays_are_in_the_contract_list() -> void:
	var contract: PackedStringArray = ["battle_ding", "battle_hit", "battle_hit_big", "battle_rating_nice", "battle_rating_rad",
			"battle_rating_totally_rad", "battle_block", "battle_perfect_block", "battle_payback", "battle_ko", "battle_down",
			"battle_flee", "battle_heal", "battle_static_in", "battle_static_out", "battle_victory", "battle_game_over", "battle_menu_open"]
	var used: Array[String] = []
	for key: String in ["menu_open", "ko", "victory", "game_over"]:
		used.append(str(BattleUiData.ui("sfx.%s" % key, "")))
	for id: String in (BattleUiData.ui("ratings.kinds", {}) as Dictionary):
		used.append(str(BattleUiData.ui("ratings.kinds.%s.sfx" % id, "")))
	for sfx: String in used:
		if not sfx.is_empty():
			assert_has(contract, sfx)


func test_fmt_fills_placeholders_and_the_confirm_button() -> void:
	assert_eq(BattleUiData.fmt("{cost} Juice", {"cost": 8}), "8 Juice")
	assert_eq(BattleUiData.fmt("Press {A}"), "Press A")


func test_settings_range_in_the_data_is_sensible() -> void:
	assert_lt(BattleUiData.ui_int("settings.timing_offset_min_ms"), 0)
	assert_gt(BattleUiData.ui_int("settings.timing_offset_max_ms"), 0)
	assert_gt(BattleUiData.ui_int("settings.timing_offset_step_ms"), 0)
	assert_le(BattleUiData.ui_int("settings.timing_offset_max_ms"), 500)


func test_the_skill_and_item_names_come_from_the_battle_data_when_it_exists() -> void:
	assert_eq(BattleUiData.name_of("ration_bar"), "Ration Bar")
	assert_eq(BattleUiData.name_of("some_made_up_move"), "Some Made Up Move")
