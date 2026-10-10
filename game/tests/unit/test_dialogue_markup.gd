extends TestCase
## DialogueMarkup: {face:grin} tags are stripped from the text, remembered by position, handed to
## the right page, and checked against known names and faces.


func test_a_tag_is_removed_from_the_text_and_remembered() -> void:
	var parsed: Dictionary = DialogueMarkup.parse("Hello {face:grin}there")
	assert_eq(parsed["text"], "Hello there")
	var tags: Array = parsed["tags"]
	assert_eq(tags.size(), 1)
	assert_eq(tags[0]["name"], "face")
	assert_eq(tags[0]["value"], "grin")
	assert_eq(tags[0]["pos"], 5, "five letters came before it (the space does not count)")


func test_text_without_tags_is_unchanged() -> void:
	var parsed: Dictionary = DialogueMarkup.parse("Just words, no tags.")
	assert_eq(parsed["text"], "Just words, no tags.")
	assert_eq((parsed["tags"] as Array).size(), 0)


func test_several_tags_keep_their_order_and_positions() -> void:
	var parsed: Dictionary = DialogueMarkup.parse("{face:calm}Hi {face:stern}you {face:laughing}there")
	assert_eq(parsed["text"], "Hi you there")
	var positions: Array[int] = []
	var values: Array[String] = []
	for tag: Dictionary in parsed["tags"]:
		positions.append(int(tag["pos"]))
		values.append(str(tag["value"]))
	assert_eq(positions, [0, 2, 5])
	assert_eq(values, ["calm", "stern", "laughing"])


func test_a_tag_at_the_end_is_kept() -> void:
	var parsed: Dictionary = DialogueMarkup.parse("Bye!{face:worried}")
	assert_eq(parsed["text"], "Bye!")
	assert_eq(parsed["tags"][0]["pos"], 4)


func test_button_tokens_without_a_colon_are_left_alone() -> void:
	var parsed: Dictionary = DialogueMarkup.parse("Press {A} to jump {face:proud}now")
	assert_eq(parsed["text"], "Press {A} to jump now")
	assert_eq((parsed["tags"] as Array).size(), 1)


func test_spaces_around_the_value_are_trimmed() -> void:
	var parsed: Dictionary = DialogueMarkup.parse("a{face: grin }b")
	assert_eq(parsed["tags"][0]["value"], "grin")


func test_tags_follow_their_letters_onto_the_right_page() -> void:
	var text: String = "Line one\nLine two\nLine three {face:proud}\nLine four {face:happy}"
	var parsed: Dictionary = DialogueMarkup.parse(text)
	var lines: PackedStringArray = (parsed["text"] as String).split("\n")
	var pages: PackedStringArray = TextWrap.paginate(lines, 3)
	assert_eq(pages.size(), 2)
	var per_page: Array[Array] = DialogueMarkup.split_by_pages(pages, parsed["tags"])
	assert_eq(per_page.size(), 2)
	assert_eq(per_page[0].size(), 0)
	assert_eq(per_page[1].size(), 2)
	assert_eq(per_page[1][0]["at"], 0, "the first tag sits right at the start of page two")
	assert_eq(per_page[1][1]["at"], DialogueMarkup.visible_count("Line four"))


func test_a_tag_at_the_end_of_a_full_page_goes_to_the_next_page_start() -> void:
	var parsed: Dictionary = DialogueMarkup.parse("One\nTwo\nThree{face:proud}\nFour")
	var pages: PackedStringArray = TextWrap.paginate((parsed["text"] as String).split("\n"), 3)
	var per_page: Array[Array] = DialogueMarkup.split_by_pages(pages, parsed["tags"])
	assert_eq(per_page[0].size(), 0)
	assert_eq(per_page[1].size(), 1)
	assert_eq(per_page[1][0]["at"], 0)


func test_visible_count_ignores_spaces_and_line_breaks() -> void:
	assert_eq(DialogueMarkup.visible_count("a b\nc"), 3)
	assert_eq(DialogueMarkup.visible_count("   "), 0)


func test_problems_names_unknown_tags_and_faces() -> void:
	var clean: Array[String] = DialogueMarkup.problems("Hi {face:grin}", ["face"], ["grin", "smug"])
	assert_eq(clean, [] as Array[String])
	var unknown_tag: Array[String] = DialogueMarkup.problems("Hi {shake:hard}", ["face"])
	assert_eq(unknown_tag.size(), 1)
	var unknown_face: Array[String] = DialogueMarkup.problems("Hi {face:sparkly}", ["face"], ["grin", "smug"])
	assert_eq(unknown_face.size(), 1)
	assert_true(unknown_face[0].contains("sparkly"))
	var no_list: Array[String] = DialogueMarkup.problems("Hi {face:anything}", ["face"])
	assert_eq(no_list, [] as Array[String], "with no face list, any face passes")


func test_every_face_tag_in_the_real_dialogue_data_is_valid() -> void:
	var names: Array = DataDB.get_value("ui/dialogue_ui", "markup.tags", [])
	var ui: Dictionary = DataDB.get_dict("ui/dialogue_ui")
	var checked: int = 0
	for doc_id: String in DataDB.json_ids():
		if not doc_id.begins_with("dialogue/"):
			continue
		var conversations: Dictionary = DataDB.get_dict(doc_id).get("conversations", {})
		for conv: String in conversations:
			for line: Dictionary in conversations[conv]:
				if not line.has("text"):
					continue
				var key: String = DialogueSpeakers.portrait_key(ui, str(line["speaker"]))
				var faces: Array[String] = PortraitLibrary.faces_of(key) if not key.is_empty() else ([] as Array[String])
				var found: Array[String] = DialogueMarkup.problems(str(line["text"]), names, faces)
				assert_eq(found, [] as Array[String], "%s/%s" % [doc_id, conv])
				if str(line["text"]).contains("{face:"):
					checked += 1
	assert_gt(checked, 0, "the demo conversations use face tags")
