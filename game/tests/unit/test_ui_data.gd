extends TestCase
## The UI data files hang together: every sound the UI asks for exists in the audio index, every
## speaker has a name and a style, and the layout numbers fit the 384x216 stage.

const STAGE: Vector2 = Vector2(384, 216)


func _audio_ids() -> Array[String]:
	var audio: Node = tree.root.get_node_or_null("AudioManager")
	var ids: Array[String] = []
	if audio != null and audio.has_method("sfx_ids"):
		ids.assign(audio.call("sfx_ids"))
	return ids


func test_every_sound_the_ui_plays_is_in_the_audio_index() -> void:
	var known: Array[String] = _audio_ids()
	assert_gt(known.size(), 0, "AudioManager has an sfx index")
	var wanted: Array[String] = []
	for id: Variant in (DataDB.get_value("ui/dialogue_ui", "sfx", {}) as Dictionary).values():
		wanted.append(str(id))
	for id: Variant in (DataDB.get_value("ui/ui_theme", "sfx", {}) as Dictionary).values():
		wanted.append(str(id))
	for id: Variant in (DataDB.get_value("ui/gestures", "sfx", {}) as Dictionary).values():
		wanted.append(str(id))
	for id: String in wanted:
		assert_has(known, id, "sound '%s' is used by the UI but missing from data/audio/sfx.json" % id)


func test_speakers_have_names_accents_and_a_known_style() -> void:
	var speakers: Dictionary = DataDB.get_value("ui/dialogue_ui", "speakers", {})
	for id: String in ["red", "otis", "mox", "zero_old", "sign", "narrator"]:
		assert_has(speakers, id)
	for id: String in speakers:
		var entry: Dictionary = speakers[id]
		assert_has(["bubble", "box"], str(entry["style"]), id)
		assert_true(entry.has("name"), id)
		assert_gt(float(entry["head_height"]), 0.0, id)


func test_typing_speeds_are_ordered_slow_to_fast() -> void:
	var speeds: Dictionary = DataDB.get_value("ui/dialogue_ui", "typing.speeds", {})
	assert_eq(speeds.keys(), ["slow", "normal", "fast"])
	assert_lt(float(speeds["slow"]), float(speeds["normal"]))
	assert_lt(float(speeds["normal"]), float(speeds["fast"]))
	assert_has(speeds, DataDB.get_value("ui/dialogue_ui", "typing.default_speed", ""))


func test_field_menu_windows_fit_the_stage() -> void:
	var layout: Dictionary = DataDB.get_dict("ui/field_menu")
	for key: String in ["main_window", "place_window", "side_window", "info_window", "save_window"]:
		var rect: Dictionary = layout[key]
		assert_ge(float(rect["x"]), 0.0, key)
		assert_ge(float(rect["y"]), 0.0, key)
		assert_le(float(rect["x"]) + float(rect["w"]), STAGE.x, key)
		assert_le(float(rect["y"]) + float(rect["h"]), STAGE.y, key)


func test_the_text_box_fits_the_stage() -> void:
	var box: Dictionary = DataDB.get_value("ui/dialogue_ui", "box", {})
	assert_le(float(box["x"]) + float(box["w"]), STAGE.x)
	assert_le(float(box["y"]) + float(box["h"]), STAGE.y)


func test_the_dialogue_font_is_a_whole_pixel_size_and_exists() -> void:
	var entry: Dictionary = DataDB.get_dict("ui/ui_theme")["fonts"]["dialogue"]
	assert_true(FileAccess.file_exists(str(entry["path"])))
	assert_eq(float(entry["size"]), float(int(entry["size"])))


func test_every_menu_command_has_text() -> void:
	var commands: Dictionary = DataDB.get_dict("text/field_menu")["commands"]
	for entry: Dictionary in DataDB.get_dict("ui/field_menu")["commands"]:
		var id: String = str(entry["id"])
		assert_has(commands, id)
		assert_le(str(commands[id]["label"]).length(), 12, "menu command names are 12 characters at most")
		assert_false(str(commands[id]["hint"]).is_empty(), id)
