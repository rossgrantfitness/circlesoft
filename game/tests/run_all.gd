extends SceneTree
## Headless test runner.
##   godot --headless --path game -s res://tests/run_all.gd
##   godot --headless --path game -s res://tests/run_all.gd -- --only=data_db
## Finds every test_*.gd under tests/unit, tests/integration and tests/sim, runs every test_*
## method, prints PASS/FAIL per test and a summary. Exit code 0 = all passed, 1 = anything failed.
## --only=TEXT runs just the tests whose file path or method name contains TEXT.

const TEST_DIRS: PackedStringArray = ["res://tests/unit", "res://tests/integration", "res://tests/sim"]
const TEST_FILE_PREFIX: String = "test_"
const TEST_FILE_EXT: String = "gd"
const TEST_METHOD_PREFIX: String = "test_"
const ONLY_ARG_PREFIX: String = "--only="
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array[String] = []
var _only: String = ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ONLY_ARG_PREFIX):
			_only = arg.trim_prefix(ONLY_ARG_PREFIX)
	# Autoloads are in the tree but only become ready on the first frame; wait so tests see them set up.
	await process_frame
	await _run_everything()
	quit(EXIT_FAIL if (_failed > 0 or _passed == 0) else EXIT_PASS)


func _run_everything() -> void:
	var files: Array[String] = []
	for dir_path: String in TEST_DIRS:
		_collect_test_files(dir_path, files)
	files.sort()
	for path: String in files:
		await _run_file(path)
	print("")
	print("==== %d passed, %d failed ====" % [_passed, _failed])
	for failed_label: String in _failed_names:
		print("  FAILED: %s" % failed_label)
	if _passed == 0 and _failed == 0:
		print("No tests ran (filter: '%s')." % _only)


func _collect_test_files(dir_path: String, out: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.begins_with(TEST_FILE_PREFIX) and file_name.get_extension() == TEST_FILE_EXT:
			out.append(dir_path.path_join(file_name))
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		_collect_test_files(dir_path.path_join(sub_dir), out)


func _run_file(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script == null or not script.can_instantiate():
		_record(path, false, ["script failed to load or compile"])
		return
	var methods: Array[String] = []
	for info: Dictionary in script.get_script_method_list():
		var method_name: String = info["name"]
		if method_name.begins_with(TEST_METHOD_PREFIX):
			methods.append(method_name)
	methods.sort()
	for method_name: String in methods:
		var label: String = "%s::%s" % [path.trim_prefix("res://tests/"), method_name]
		if not _only.is_empty() and not label.contains(_only):
			continue
		var instance: Object = script.new()
		var test_case: TestCase = instance as TestCase
		if test_case == null:
			_record(label, false, ["file does not extend TestCase"])
			continue
		test_case.tree = self
		test_case.reset_results()
		test_case.before_each()
		await test_case.call(method_name)
		test_case.after_each()
		test_case.free_owned_nodes()
		var problems: Array[String] = test_case.get_failures()
		if problems.is_empty() and test_case.get_assert_count() == 0:
			problems.append("test made no assertions")
		_record(label, problems.is_empty(), problems)


func _record(label: String, ok: bool, problems: Array[String]) -> void:
	if ok:
		_passed += 1
		print("PASS  %s" % label)
		return
	_failed += 1
	_failed_names.append(label)
	print("FAIL  %s" % label)
	for problem: String in problems:
		print("        %s" % problem)
