extends TestCase
## DialogueSpeakers: who gets a bubble, who gets the plain box (narrator, signs, crowd NPCs by
## data, anyone with no body in the room), and who gets a portrait.


func _ui() -> Dictionary:
	return DataDB.get_dict("ui/dialogue_ui")


func test_crowd_ids_are_found_by_prefix_from_data() -> void:
	assert_true(DialogueSpeakers.is_crowd(_ui(), "crowd_dockhand"))
	assert_true(DialogueSpeakers.is_crowd(_ui(), "crowd_"))
	assert_false(DialogueSpeakers.is_crowd(_ui(), "otis"))
	assert_false(DialogueSpeakers.is_crowd(_ui(), "dockhand"))


func test_crowd_prefixes_come_from_the_data_not_the_code() -> void:
	var ui: Dictionary = _ui().duplicate(true)
	ui["crowd"]["prefixes"] = ["npc_"]
	assert_true(DialogueSpeakers.is_crowd(ui, "npc_baker"))
	assert_false(DialogueSpeakers.is_crowd(ui, "crowd_baker"))


func test_a_listed_speaker_can_be_marked_crowd() -> void:
	var ui: Dictionary = _ui().duplicate(true)
	ui["speakers"]["old_man"] = {"name": "Old Man", "crowd": true}
	assert_true(DialogueSpeakers.is_crowd(ui, "old_man"))
	assert_eq(DialogueSpeakers.style_for(ui, "old_man", true), "box")


func test_crowd_npcs_get_the_box_even_with_a_body_in_the_room() -> void:
	assert_eq(DialogueSpeakers.style_for(_ui(), "crowd_dockhand", true), "box")
	assert_eq(DialogueSpeakers.style_for(_ui(), "crowd_dockhand", false), "box")


func test_named_cast_get_a_bubble_when_they_are_in_the_room_and_the_box_when_not() -> void:
	assert_eq(DialogueSpeakers.style_for(_ui(), "otis", true), "bubble")
	assert_eq(DialogueSpeakers.style_for(_ui(), "otis", false), "box")


func test_narrator_and_signs_are_always_boxes() -> void:
	assert_eq(DialogueSpeakers.style_for(_ui(), "narrator", true), "box")
	assert_eq(DialogueSpeakers.style_for(_ui(), "sign", true), "box")


func test_a_lines_own_style_wins() -> void:
	assert_eq(DialogueSpeakers.style_for(_ui(), "crowd_dockhand", true, "bubble"), "bubble")
	assert_eq(DialogueSpeakers.style_for(_ui(), "otis", true, "box"), "box")
	assert_eq(DialogueSpeakers.style_for(_ui(), "otis", true, "nonsense"), "bubble", "an unknown style is ignored")


func test_crowd_name_is_the_rest_of_the_id() -> void:
	assert_eq(DialogueSpeakers.crowd_name(_ui(), "crowd_dockhand"), "Dockhand")
	assert_eq(DialogueSpeakers.crowd_name(_ui(), "crowd_dock_hand"), "Dock Hand")
	assert_eq(DialogueSpeakers.entry(_ui(), "crowd_dockhand")["name"], "Dockhand")
	assert_eq(DialogueSpeakers.entry(_ui(), "crowd_dockhand")["style"], "box")


func test_only_named_cast_have_portraits() -> void:
	assert_eq(DialogueSpeakers.portrait_key(_ui(), "otis"), "otis")
	assert_eq(DialogueSpeakers.portrait_key(_ui(), "zero_old"), "zero_old")
	assert_eq(DialogueSpeakers.portrait_key(_ui(), "crowd_dockhand"), "")
	assert_eq(DialogueSpeakers.portrait_key(_ui(), "narrator"), "")
	assert_eq(DialogueSpeakers.portrait_key(_ui(), "enemy_grunt"), "")


func test_every_portrait_a_speaker_names_exists_in_portrait_data() -> void:
	var speakers: Dictionary = _ui()["speakers"]
	for id: String in speakers:
		var key: String = str((speakers[id] as Dictionary).get("portrait", ""))
		if not key.is_empty():
			assert_true(PortraitLibrary.has_character(key), "%s -> portrait '%s'" % [id, key])
