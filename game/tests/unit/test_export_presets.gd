extends TestCase
## The export presets (docs/bug_log.md B14, B15). The tests and the tool scripts are left out of every build, and a slice build
## is not named after the cut title.


func _presets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load("res://export_presets.cfg") != OK:
		fail("export_presets.cfg did not load")
		return out
	for section: String in cfg.get_sections():
		if section.ends_with(".options"):
			continue
		var info: Dictionary = {}
		for key: String in cfg.get_section_keys(section):
			info[key] = cfg.get_value(section, key)
		info["options"] = {}
		for key: String in cfg.get_section_keys(section + ".options") if cfg.has_section(section + ".options") else PackedStringArray():
			(info["options"] as Dictionary)[key] = cfg.get_value(section + ".options", key)
		out.append(info)
	return out


func test_there_are_six_presets_and_each_leaves_out_tests_and_tools() -> void:
	var presets: Array[Dictionary] = _presets()
	assert_eq(presets.size(), 6, "classic x2, sandbox x2, slice x2")
	for info: Dictionary in presets:
		var filter: String = str(info.get("exclude_filter", ""))
		assert_true(filter.contains("tests/*"), "%s leaves out tests/ (filter: %s)" % [str(info.get("name")), filter])
		assert_true(filter.contains("scripts/tools/*"), "%s leaves out scripts/tools/ (filter: %s)" % [str(info.get("name")), filter])


func test_a_slice_build_is_not_named_after_the_cut_title() -> void:
	var slice_presets: int = 0
	for info: Dictionary in _presets():
		if not str(info.get("custom_features", "")).contains("slice"):
			continue
		slice_presets += 1
		var options: Dictionary = info["options"] as Dictionary
		if options.has("application/product_name"):
			assert_false(str(options["application/product_name"]).containsn("lights"), "%s is not named Lights" % str(info.get("name")))
	assert_eq(slice_presets, 2, "two slice presets (Windows and Mac)")
	# The Mac app takes its name from the project name as the preset's feature tags see it (the `slice` tag).
	assert_true(ProjectSettings.has_setting("application/config/name.slice"), "the project names the slice build")
	assert_false(str(ProjectSettings.get_setting("application/config/name.slice")).containsn("lights"), "and the name is neutral")
