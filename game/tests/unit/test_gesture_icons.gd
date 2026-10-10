extends TestCase
## Red's gesture icons: every gesture has clean 16x16 frames, names map through aliases, and
## every gesture the Writer used in data/dialogue/ resolves.

const REQUIRED: PackedStringArray = ["thumbs_up", "head_shake", "exclaim", "question", "dots", "heart", "sweat"]


func test_every_required_gesture_exists() -> void:
	for id: String in REQUIRED:
		assert_has(GestureIcons.ids(), id)


func test_every_frame_is_16_by_16_with_known_pixels() -> void:
	var size: int = GestureIcons.get_icon_size()
	var legend: Dictionary = DataDB.get_value("ui/gestures", "legend", {})
	for id: String in GestureIcons.ids():
		var frames: Array = DataDB.get_value("ui/gestures", "gestures.%s.frames" % id, [])
		assert_ge(frames.size(), 1, id)
		for rows: Array in frames:
			assert_eq(rows.size(), size, "%s: row count" % id)
			for row: String in rows:
				assert_eq(row.length(), size, "%s: row width" % id)
				for pixel: String in row:
					assert_true(pixel == "." or legend.has(pixel), "%s: unknown pixel '%s'" % [id, pixel])


func test_textures_are_built_and_not_empty() -> void:
	for id: String in GestureIcons.ids():
		var frames: Array[ImageTexture] = GestureIcons.get_frames(id)
		assert_ge(frames.size(), 1, id)
		var image: Image = frames[0].get_image()
		var has_pixels: bool = false
		for y: int in image.get_height():
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.0:
					has_pixels = true
		assert_true(has_pixels, "%s draws something" % id)


func test_aliases_and_unknown_names() -> void:
	assert_eq(GestureIcons.resolve("Thumbs-Up"), "thumbs_up")
	assert_eq(GestureIcons.resolve("..."), "dots")
	assert_eq(GestureIcons.resolve("sweat_drop"), "sweat")
	assert_eq(GestureIcons.resolve("no_such_gesture"), "")


func test_choice_prefix_split() -> void:
	var thumbs: Dictionary = GestureIcons.split_choice("Thumbs-up: Grand tour")
	assert_eq(thumbs["gesture"], "thumbs_up")
	assert_eq(thumbs["label"], "Grand tour")
	var shake: Dictionary = GestureIcons.split_choice("Head shake: I'll poke")
	assert_eq(shake["gesture"], "head_shake")
	assert_eq(shake["label"], "I'll poke")
	var plain: Dictionary = GestureIcons.split_choice("Yes!")
	assert_eq(plain["gesture"], "")
	assert_eq(plain["label"], "Yes!")
	var other_colon: Dictionary = GestureIcons.split_choice("Note: not a gesture")
	assert_eq(other_colon["gesture"], "")
	assert_eq(other_colon["label"], "Note: not a gesture")


func test_every_gesture_in_dialogue_data_resolves() -> void:
	for doc_id: String in DataDB.json_ids():
		if not doc_id.begins_with("dialogue/"):
			continue
		var conversations: Dictionary = DataDB.get_dict(doc_id).get("conversations", {})
		for conv: String in conversations:
			for line: Dictionary in conversations[conv]:
				if line.has("gesture"):
					assert_ne(GestureIcons.resolve(str(line["gesture"])), "", "%s uses gesture '%s'" % [conv, line["gesture"]])
				for option: Variant in line.get("choice", []):
					var parts: Dictionary = GestureIcons.split_choice(str(option))
					if str(option).contains(":"):
						assert_ne(parts["gesture"], "", "%s: choice '%s' has an unknown gesture prefix" % [conv, option])
