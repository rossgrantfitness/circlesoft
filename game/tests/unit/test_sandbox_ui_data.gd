extends TestCase
## The sandbox UI's data: the one Theme resource holds every color, constant and font the scripts ask
## for (so swapping the look is one file), the fonts are open-license with their license file beside
## them, the Config screen has a row for every new button, and the words every screen uses exist.

const SCRIPT_DIR: String = "res://scripts/ui/sandbox/"
const FONT_DIR: String = "res://art/final/ui/fonts/"
const NEW_BUTTONS: Array[String] = ["light", "heavy", "dash", "parry", "lock_on", "camera_toggle", "feel_panel"]


func _source_files() -> Array[String]:
	var out: Array[String] = []
	for file_name: String in DirAccess.get_files_at(SCRIPT_DIR):
		if file_name.ends_with(".gd"):
			out.append(SCRIPT_DIR + file_name)
	return out


func _names_used(pattern: String) -> Array[String]:
	var regex: RegEx = RegEx.new()
	regex.compile(pattern)
	var out: Array[String] = []
	for path: String in _source_files():
		for found: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			var name: String = found.get_string(1)
			if not out.has(name):
				out.append(name)
	return out


func test_the_theme_loads_and_has_every_font_role() -> void:
	SandboxStyle.reload()
	var theme: Theme = SandboxStyle.theme()
	assert_not_null(theme)
	for role: String in ["body", "title", "digits", "label"]:
		assert_not_null(SandboxStyle.font(role), "font role %s" % role)
		assert_gt(SandboxStyle.font_size(role), 0, "size for %s" % role)


func test_every_color_the_scripts_ask_the_theme_for_is_in_the_theme() -> void:
	var theme: Theme = SandboxStyle.theme()
	var names: Array[String] = _names_used('SandboxStyle\\.color\\("([a-z_]+)"\\)')
	assert_gt(names.size(), 10, "the scan found the colors")
	for name: String in names:
		assert_true(theme.has_color(StringName(name), SandboxStyle.TYPE), "theme color %s" % name)


func test_every_color_named_in_a_conditional_is_in_the_theme() -> void:
	var theme: Theme = SandboxStyle.theme()
	for name: String in _names_used('"([a-z_]+_(?:top|bottom))"'):
		assert_true(theme.has_color(StringName(name), SandboxStyle.TYPE), "theme color %s" % name)


func test_every_constant_the_scripts_ask_for_is_in_the_theme() -> void:
	var theme: Theme = SandboxStyle.theme()
	for name: String in _names_used('const_int\\("([a-z_]+)"\\)'):
		assert_true(theme.has_constant(StringName(name), SandboxStyle.TYPE), "theme constant %s" % name)


func test_the_theme_fonts_are_open_license_with_a_license_file_beside_them() -> void:
	var text: String = FileAccess.get_file_as_string("res://art/placeholder/ui/sandbox_theme.tres")
	var regex: RegEx = RegEx.new()
	regex.compile('path="res://art/final/ui/fonts/([A-Za-z0-9\\-]+)\\.ttf"')
	var found: Array[RegExMatch] = regex.search_all(text)
	assert_gt(found.size(), 0, "the theme names its font files")
	for match: RegExMatch in found:
		var stem: String = match.get_string(1)
		var family: String = stem.split("-")[0]
		assert_true(FileAccess.file_exists(FONT_DIR + "%s-OFL.txt" % family), "%s has a license file beside it" % stem)
		assert_true(FileAccess.get_file_as_string(FONT_DIR + "%s-OFL.txt" % family).contains("SIL OPEN FONT LICENSE"), "%s is SIL OFL" % family)


func test_only_the_theme_picks_fonts_no_script_loads_a_font_file() -> void:
	for path: String in _source_files():
		var source: String = FileAccess.get_file_as_string(path)
		assert_false(source.contains(".ttf"), "%s does not name a font file" % path)
		assert_false(source.contains("UiText."), "%s draws text through SandboxStyle" % path)


func test_the_config_screen_has_a_row_for_every_new_button() -> void:
	var groups: Array[String] = InputRemap.group_ids()
	for button: String in NEW_BUTTONS:
		assert_has(groups, button)
		assert_true(InputMap.has_action(StringName(button)), "%s is a real input action" % button)
		var words: Dictionary = DataDB.get_value("text/config", "controls.rows.%s" % button, {})
		assert_ne(str(words.get("label", "")), "", "%s has a label" % button)
		assert_ne(str(words.get("hint", "")), "", "%s has a hint" % button)


func test_the_new_buttons_swap_with_each_other_and_with_jump() -> void:
	var partners: Array[String] = InputRemap.swap_partners("light")
	for other: String in ["jump", "heavy", "dash", "parry", "lock_on", "camera_toggle"]:
		assert_has(partners, other)
	assert_does_not_have(partners, "feel_panel", "the feel panel button is not swapped with combat buttons")
	assert_has(InputRemap.swap_partners("jump"), "interact", "the old swap set still holds")


func test_the_pause_menu_and_card_words_exist() -> void:
	for id: String in ["resume", "reset", "controls", "quit"]:
		assert_ne(SandboxUiData.text("pause.%s" % id), "")
		assert_ne(SandboxUiData.text("pause.hints.%s" % id), "")
	assert_ne(SandboxUiData.text("controls_card.title"), "")
	assert_ne(SandboxUiData.text("hud.hint_keys"), "")
	assert_ne(SandboxUiData.text("hud.hint_pad"), "")
	assert_ne(SandboxUiData.text("feel.info_label"), "")


func test_the_call_out_words_exist() -> void:
	for rating: String in ["nice", "rad", "totally_rad", "miss"]:
		assert_ne(SandboxPopups.parry_text(rating), "", rating)
	assert_ne(SandboxPopups.lamp_flare_text(), "")
	for by: String in ["parry", "poise"]:
		assert_ne(SandboxPopups.stagger_text(by), "", by)


func test_the_text_is_white_with_a_solid_black_shadow_one_pixel_down_right() -> void:
	assert_eq(SandboxStyle.color("text"), Color.html("#FFFFFF"))
	assert_eq(SandboxStyle.color("shadow"), Color.html("#000000"))
	assert_eq(SandboxStyle.const_int("shadow_x"), 1)
	assert_eq(SandboxStyle.const_int("shadow_y"), 1)


func test_the_lean_is_on_by_default() -> void:
	assert_gt(SandboxStyle.slant("body"), 0.0, "Ross picked the leaning sample")


func test_the_sounds_the_hud_plays_exist() -> void:
	for key: String in ["lock_on", "rank_up"]:
		var id: String = str(SandboxUiData.ui("sfx.%s" % key, ""))
		assert_true(DataDB.has_value("audio/sfx", "sounds.%s" % id) or DataDB.has_value("audio/sfx", id) or JSON.stringify(DataDB.get_dict("audio/sfx")).contains('"%s"' % id), "sound %s is in sfx.json" % id)
