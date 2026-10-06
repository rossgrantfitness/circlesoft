extends TestCase
## Milestone 1 step 3: DataDB loads real data cleanly, reports bad files by name, and takes a
## directory so fixtures never mix with real data.

const DataDBScript: GDScript = preload("res://scripts/core/data_db.gd")
const GOOD_DIR: String = "res://tests/fixtures/db_good"
const BAD_DIR: String = "res://tests/fixtures/db_bad"
const TUNING_ID: String = "world/field_tuning"


func _make_db() -> Node:
	return own(DataDBScript.new()) as Node


func test_autoload_loaded_real_data_without_errors() -> void:
	var db: Node = tree.root.get_node("DataDB")
	assert_false(db.has_errors(), "real data errors: %s" % db.get_errors())
	assert_true(db.has_json(TUNING_ID))


func test_real_data_directory_parses() -> void:
	var db: Node = _make_db()
	assert_true(db.load_all(), "errors: %s" % db.get_errors())
	assert_eq(db.get_errors().size(), 0)


func test_field_tuning_values_are_sane() -> void:
	var db: Node = tree.root.get_node("DataDB")
	var walk: float = db.get_value(TUNING_ID, "walk_speed")
	var run: float = db.get_value(TUNING_ID, "run_speed")
	assert_gt(walk, 0.0)
	assert_gt(run, walk, "run must be faster than walk")
	assert_gt(float(db.get_value(TUNING_ID, "jump.height")), 0.8, "enough to hop onto a 0.8 crate")
	assert_gt(float(db.get_value(TUNING_ID, "jump.rise_time_s")), 0.0)
	assert_gt(float(db.get_value(TUNING_ID, "jump.fall_gravity_mult")), 0.99)
	assert_gt(float(db.get_value(TUNING_ID, "jump.coyote_time_s")), 0.0)
	assert_gt(float(db.get_value(TUNING_ID, "jump.buffer_time_s")), 0.0)
	var cut: float = db.get_value(TUNING_ID, "jump.release_cut_mult")
	assert_gt(cut, 0.0)
	assert_lt(cut, 1.0)
	assert_gt(float(db.get_value(TUNING_ID, "blink_time_s")), 0.0)
	assert_gt(float(db.get_value(TUNING_ID, "follow.spacing")), 0.0)
	assert_gt(float(db.get_value(TUNING_ID, "camera.smoothing")), 0.0)
	var margin: float = db.get_value(TUNING_ID, "camera.safe_frame_margin")
	assert_gt(margin, 0.0)
	assert_lt(margin, 0.5, "margins on both sides must leave a middle")


func test_good_fixture_loads_json_and_csv() -> void:
	var db: Node = _make_db()
	assert_true(db.load_all(GOOD_DIR))
	assert_has(db.json_ids(), "sample")
	assert_has(db.json_ids(), "nested/thing")
	assert_has(db.table_ids(), "table")
	assert_eq(db.get_json("nested/thing"), [1.0, 2.0, 3.0], "JSON numbers always parse as floats")
	var rows: Array = db.get_table("table")
	assert_eq(rows.size(), 3, "blank line skipped")
	assert_eq(rows[0], {"name": "alpha", "level": 1, "hp": 10.5})
	assert_eq(rows[2]["name"], "gamma, the third", "quoted comma kept")


func test_get_value_walks_paths() -> void:
	var db: Node = _make_db()
	db.load_all(GOOD_DIR)
	assert_eq(db.get_value("sample", "answer"), 42)
	assert_eq(db.get_value("sample", "nested.name"), "fixture")
	assert_eq(db.get_value("sample", "nested.list.1"), 20)
	assert_true(db.has_value("sample", "nested.list.2"))
	assert_false(db.has_value("sample", "nested.list.3"))
	assert_false(db.has_value("sample", "nope"))
	assert_false(db.has_value("missing_file", "answer"))
	assert_eq(db.get_value("sample", "nope", "fallback"), "fallback")


func test_getters_are_safe_for_unknown_ids() -> void:
	var db: Node = _make_db()
	db.load_all(GOOD_DIR)
	assert_null(db.get_json("nope"))
	assert_eq(db.get_dict("nope"), {})
	assert_eq(db.get_dict("nested/thing"), {}, "array file is not a dict")
	assert_eq(db.get_table("nope").size(), 0)
	assert_eq(db.get_dict("sample")["answer"], 42)


func test_bad_files_are_reported_by_name() -> void:
	var db: Node = _make_db()
	assert_false(db.load_all(BAD_DIR))
	var errors: Dictionary[String, String] = db.get_errors()
	assert_has(errors, BAD_DIR + "/broken.json")
	assert_has(errors, BAD_DIR + "/ragged.csv")
	assert_eq(errors.size(), 2, "only the two bad files: %s" % errors)
	assert_true(errors[BAD_DIR + "/broken.json"].contains("line"), "JSON error names the line")
	assert_true(errors[BAD_DIR + "/ragged.csv"].contains("line 3"), "CSV error names the line")


func test_good_files_still_load_next_to_bad_ones() -> void:
	var db: Node = _make_db()
	db.load_all(BAD_DIR)
	assert_true(db.has_json("ok"))
	assert_false(db.has_json("broken"))
	assert_false(db.has_table("ragged"))


func test_missing_directory_is_reported() -> void:
	var db: Node = _make_db()
	var missing: String = "res://tests/fixtures/does_not_exist"
	assert_false(db.load_all(missing))
	assert_has(db.get_errors(), missing)


func test_reload_replaces_old_contents() -> void:
	var db: Node = _make_db()
	db.load_all(GOOD_DIR)
	db.load_all(BAD_DIR)
	assert_false(db.has_json("sample"), "old data cleared")
	assert_true(db.has_json("ok"))


## Godot would turn a .csv into a translation (and a broken export) unless a sibling .import
## file says importer="keep". Every CSV under data/ and tests/fixtures/ needs one.
func test_every_csv_is_marked_keep_so_it_is_not_imported_as_a_translation() -> void:
	var csv_files: Array[String] = []
	_collect_csv("res://data", csv_files)
	_collect_csv("res://tests/fixtures", csv_files)
	assert_gt(csv_files.size(), 0, "fixtures contain CSV files")
	for csv_path: String in csv_files:
		var import_path: String = csv_path + ".import"
		assert_true(FileAccess.file_exists(import_path), "missing " + import_path)
		if FileAccess.file_exists(import_path):
			assert_true(FileAccess.get_file_as_string(import_path).contains('importer="keep"'), import_path)


func _collect_csv(dir_path: String, out: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() == "csv":
			out.append(dir_path.path_join(file_name))
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		_collect_csv(dir_path.path_join(sub_dir), out)
