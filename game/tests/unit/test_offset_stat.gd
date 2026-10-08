extends TestCase
## OffsetStat (the staggered "Hp 78 /120" readout) and the theme's lean switch.


func after_each() -> void:
	SandboxStyle.reload()


func test_the_readout_is_staggered_by_theme_numbers_not_code() -> void:
	assert_gt(SandboxStyle.const_int("stat_label_raise"), 0, "the label sits higher")
	assert_gt(SandboxStyle.const_int("stat_slash_drop"), 0, "the max sits lower")
	assert_gt(SandboxStyle.font_size("stat_big"), SandboxStyle.font_size("stat_small"), "the max is smaller than the current value")
	assert_gt(SandboxStyle.font_size("stat_big"), SandboxStyle.font_size("stat_label"), "and the label is smaller too")


func test_width_grows_with_each_part() -> void:
	var plain: float = OffsetStat.measure("", "78")
	var with_max: float = OffsetStat.measure("", "78", "120")
	var with_label: float = OffsetStat.measure("Hp", "78", "120")
	assert_gt(plain, 0.0)
	assert_gt(with_max, plain, "the slash and max add width")
	assert_gt(with_label, with_max, "the label adds width")
	assert_gt(OffsetStat.measure("", "1234", ""), OffsetStat.measure("", "12", ""), "more digits are wider")


func test_drawing_returns_its_measured_width() -> void:
	var canvas: Control = Control.new()
	add_to_root(canvas)
	var seen: Array[float] = []
	canvas.draw.connect(func() -> void:
		seen.append(OffsetStat.draw(canvas, Vector2(100, 50), "Hp", "78", "120", Color.WHITE))
		seen.append(OffsetStat.draw(canvas, Vector2(200, 50), "", "640", "", Color.WHITE, true)))
	canvas.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	assert_eq(seen.size(), 2)
	assert_almost_eq(seen[0], OffsetStat.measure("Hp", "78", "120"), 0.001)
	assert_almost_eq(seen[1], OffsetStat.measure("", "640", ""), 0.001)


func test_the_lean_is_one_theme_switch_and_defaults_to_upright() -> void:
	assert_almost_eq(SandboxStyle.slant("body"), 0.0, 0.0001, "upright until Ross says otherwise")
	var theme: Theme = SandboxStyle.theme()
	theme.set_constant(&"slant_pct", SandboxStyle.TYPE, 22)
	assert_almost_eq(SandboxStyle.slant("body"), 0.22, 0.0001)
	assert_almost_eq(SandboxStyle.slant("digits"), 0.22, 0.0001, "numerals lean the same way")
	assert_almost_eq(SandboxStyle.slant("stat_big"), 0.22, 0.0001)
	assert_almost_eq(SandboxStyle.slant("label"), 0.0, 0.0001, "the small caps labels stay upright")
	theme.set_constant(&"slant_pct", SandboxStyle.TYPE, 0)


func test_the_fallback_switch_swaps_every_font_role_to_jersey_and_goes_upright() -> void:
	var theme: Theme = SandboxStyle.theme()
	var body_before: Font = SandboxStyle.font("body")
	theme.set_constant(&"slant_pct", SandboxStyle.TYPE, 22)
	theme.set_constant(&"use_fallback_font", SandboxStyle.TYPE, 1)
	assert_true(SandboxStyle.uses_fallback_font())
	assert_ne(SandboxStyle.font("body"), body_before, "a different font")
	assert_almost_eq(SandboxStyle.slant("body"), 0.0, 0.0001, "the fallback is upright")
	for role: String in ["body", "title", "digits", "stat_label", "stat_big", "stat_small"]:
		assert_not_null(SandboxStyle.font(role), role)
		assert_gt(SandboxStyle.font_size(role), 0, role)
	assert_eq(SandboxStyle.font("label"), theme.get_font(&"label", SandboxStyle.TYPE), "the label font never changes")
	theme.set_constant(&"use_fallback_font", SandboxStyle.TYPE, 0)
	theme.set_constant(&"slant_pct", SandboxStyle.TYPE, 0)


func test_numerals_never_use_a_face_whose_counters_fill_with_the_shadow() -> void:
	# Jersey 15 at HUD sizes turns 6, 8 and 9 into blobs that read like "+" (docs/screenshots/ui_digits_strip.png).
	for role: String in ["digits", "stat_big", "stat_small"]:
		var font: FontVariation = SandboxStyle.theme().get_font(StringName(role), SandboxStyle.TYPE) as FontVariation
		assert_not_null(font, role)
		assert_false(font.base_font.resource_path.contains("Jersey"), "%s is not Jersey" % role)
	for role: String in ["digits_fallback", "stat_big_fallback", "stat_small_fallback"]:
		var fallback: FontVariation = SandboxStyle.theme().get_font(StringName(role), SandboxStyle.TYPE) as FontVariation
		assert_false(fallback.base_font.resource_path.contains("Jersey"), "%s is not Jersey either" % role)
