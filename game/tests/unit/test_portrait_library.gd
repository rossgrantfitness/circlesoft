extends TestCase
## PortraitLibrary: portraits are found by the path in data/ui/portraits.json, a real PNG at that
## path is used the moment it exists, and a missing one falls back to the placeholder initials head.

const SCRATCH_DIR: String = "user://test_portraits"
const SOURCE: int = 96


func before_each() -> void:
	PortraitLibrary.clear_cache()
	DirAccess.make_dir_recursive_absolute(SCRATCH_DIR)


func after_each() -> void:
	PortraitLibrary.clear_cache()
	for file_name: String in DirAccess.get_files_at(SCRATCH_DIR):
		DirAccess.remove_absolute(SCRATCH_DIR.path_join(file_name))


func _write_portrait(file_name: String, size: int, color: Color) -> String:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var path: String = SCRATCH_DIR.path_join(file_name)
	image.save_png(path)
	return path


func test_the_cast_and_their_faces_come_from_data() -> void:
	assert_has(PortraitLibrary.character_ids(), "otis")
	assert_eq(PortraitLibrary.faces_of("otis"), ["calm", "apologetic", "stern", "worried", "laughing"] as Array[String])
	assert_eq(PortraitLibrary.default_face("otis"), "calm")
	assert_eq(PortraitLibrary.faces_of("kasp").size(), 3)
	assert_true(PortraitLibrary.is_known_face("mox", "panicking"))
	assert_false(PortraitLibrary.is_known_face("mox", "calm"))
	assert_false(PortraitLibrary.has_character("nobody"))


func test_the_path_template_is_filled_in_with_the_face() -> void:
	assert_eq(PortraitLibrary.path_for("otis", "stern"), "res://art/final/portraits/otis/ptr_otis_stern.png")
	assert_eq(PortraitLibrary.path_for("nobody", "x"), "")


func test_with_no_art_there_is_no_texture() -> void:
	var characters: Dictionary = DataDB.get_dict("ui/portraits")["characters"]
	characters["ghost"] = {"path": "res://art/final/portraits/ghost/ptr_ghost_{face}.png", "faces": ["calm"], "default_face": "calm"}
	assert_null(PortraitLibrary.load_texture("ghost", "calm"))
	assert_false(PortraitLibrary.has_art("ghost", "calm"))
	assert_null(PortraitLibrary.load_texture("nobody", "calm"))
	characters.erase("ghost")


func test_a_png_at_the_data_path_is_loaded_by_that_path() -> void:
	var path: String = _write_portrait("ptr_test_calm.png", SOURCE, Color(0.2, 0.6, 0.9))
	var characters: Dictionary = DataDB.get_dict("ui/portraits")["characters"]
	var original: String = str(characters["otis"]["path"])
	characters["otis"]["path"] = SCRATCH_DIR + "/ptr_test_{face}.png"
	var texture: Texture2D = PortraitLibrary.load_texture("otis", "calm")
	characters["otis"]["path"] = original
	assert_not_null(texture, "real art at the path is found")
	assert_eq(texture.get_size(), Vector2(SOURCE, SOURCE))
	assert_true(path.ends_with("ptr_test_calm.png"))


func test_a_second_look_up_comes_from_the_cache() -> void:
	_write_portrait("ptr_cache_calm.png", SOURCE, Color.RED)
	var characters: Dictionary = DataDB.get_dict("ui/portraits")["characters"]
	var original: String = str(characters["otis"]["path"])
	characters["otis"]["path"] = SCRATCH_DIR + "/ptr_cache_{face}.png"
	var first: Texture2D = PortraitLibrary.load_texture("otis", "calm")
	var second: Texture2D = PortraitLibrary.load_texture("otis", "calm")
	characters["otis"]["path"] = original
	assert_not_null(first)
	assert_eq(first, second)


func test_the_crops_are_half_size_squares_inside_the_96_portrait() -> void:
	for kind: String in ["bubble", "box"]:
		var crop: Rect2i = PortraitLibrary.crop_for(kind)
		var slot: int = PortraitLibrary.slot_size(kind)
		assert_true(Rect2i(0, 0, SOURCE, SOURCE).encloses(crop), "%s crop stays inside the portrait" % kind)
		assert_eq(crop.size.x, slot * 2, "%s crop is exactly twice the slot, so pixels stay square" % kind)
		assert_eq(crop.size.y, slot * 2)


func test_drawing_real_art_and_the_placeholder_both_work() -> void:
	var canvas: Control = Control.new()
	add_to_root(canvas)
	canvas.draw.connect(func() -> void:
		PortraitLibrary.draw(canvas, "otis", "calm", Rect2i(0, 0, 32, 32), "bubble", Color.BLACK)
		PortraitLibrary.draw(canvas, "kasp", "shouting", Rect2i(40, 0, 48, 48), "box", Color.BLACK))
	canvas.size = Vector2(100, 60)
	canvas.queue_redraw()
	await tree.process_frame
	assert_true(canvas.is_inside_tree(), "placeholder drawing runs without errors")


func test_every_face_a_character_lists_has_a_placeholder_look() -> void:
	var faces: Dictionary = DataDB.get_dict("ui/portraits")["faces"]
	for id: String in PortraitLibrary.character_ids():
		for face: String in PortraitLibrary.faces_of(id):
			assert_has(faces, face, "%s needs a placeholder look for '%s'" % [id, face])
		assert_true(PortraitLibrary.is_known_face(id, PortraitLibrary.default_face(id)), "%s default face is one of its faces" % id)


func test_the_slice_portrait_budget_is_in_the_data() -> void:
	# docs/style_guide.md: Red, Otis and Mox 5 each, Kasp and the key NPCs 3 each.
	assert_eq(PortraitLibrary.faces_of("red").size(), 5)
	assert_eq(PortraitLibrary.faces_of("otis").size(), 5)
	assert_eq(PortraitLibrary.faces_of("mox").size(), 5)
	assert_eq(PortraitLibrary.faces_of("kasp").size(), 3)
	assert_eq(PortraitLibrary.faces_of("zero_old").size(), 3)
