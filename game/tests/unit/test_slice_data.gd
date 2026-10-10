extends TestCase
## VS-33, the slice's cross-file data checks (QA; docs/slice/slice_tech_plan.md section 8). An id that one slice data file names must
## resolve in the file it points at: encounters -> rooms, enemies, barks; story scenes -> something that starts them; boss endings and
## barks -> scenes and conversations; hacks -> a name and an icon. Known bugs (docs/bug_log.md) are checked with known_bug(): the
## test passes while the bug stands and prints XFAIL with the bug id, and prints XPASS once the bug is fixed, so the marker can go.
## Run it alone: godot --headless --path game -s res://tests/run_all.gd -- --only=test_slice_data

const ROOMS_ID: String = "slice/rooms"
const ENCOUNTERS_ID: String = "slice/encounters"
const SCENES_ID: String = "slice/story_scenes"
const BARKS_ID: String = "dialogue/slice_barks"
const HACKS_ID: String = "combat/hacks"
const BOSS_IDS: Array[String] = ["combat/bosses/hushmaster", "combat/bosses/junk_mech"]
const DATA_ROOT: String = "res://data"
const SCENES_FILE: String = "res://data/slice/story_scenes.json"


## A known bug: the check passes while it stands (XFAIL, names the bug) and passes with XPASS once fixed.
func known_bug(bug_id: String, fixed: bool, message: String) -> void:
	assert_true(true, "known bug check %s" % bug_id)
	if fixed:
		print("XPASS %s: fixed. Take the known-bug marker out of this test." % bug_id)
	else:
		print("XFAIL %s (known bug, docs/bug_log.md): %s" % [bug_id, message])


func test_the_slice_data_files_load_and_their_ids_resolve() -> void:
	for id: String in [ROOMS_ID, ENCOUNTERS_ID, SCENES_ID, BARKS_ID, HACKS_ID]:
		assert_true(DataDB.has_json(id), "%s is loaded from data/" % id)
	for boss_id: String in BOSS_IDS:
		assert_true(DataDB.has_json(boss_id), "%s is loaded from data/" % boss_id)


func test_every_encounter_names_a_room_enemies_waves_and_barks_that_exist() -> void:
	var rooms: Dictionary = DataDB.get_dict(ROOMS_ID).get("rooms", {}) as Dictionary
	var enemy_scenes: Dictionary = CombatData.combat_file(CombatData.FILE_SANDBOX).get("enemy_scenes", {}) as Dictionary
	var conversations: Dictionary = DataDB.get_value(BARKS_ID, "conversations", {}) as Dictionary
	var encounters: Dictionary = DataDB.get_dict(ENCOUNTERS_ID).get("encounters", {}) as Dictionary
	assert_gt(encounters.size(), 0, "the encounters file has encounters")
	for id: Variant in encounters.keys():
		var def: Dictionary = encounters[id] as Dictionary
		var label: String = str(id)
		assert_true(rooms.has(str(def.get("room", ""))), "%s: its room exists in rooms.json" % label)
		var wave_ids: Array[String] = []
		for raw_wave: Variant in def.get("waves", []) as Array:
			var wave: Dictionary = raw_wave as Dictionary
			var wave_id: String = str(wave.get("id", ""))
			assert_false(wave_ids.has(wave_id), "%s: wave %s is named once" % [label, wave_id])
			for raw_spawn: Variant in wave.get("spawn", []) as Array:
				var kind: String = str((raw_spawn as Dictionary).get("enemy", ""))
				assert_true(enemy_scenes.has(kind), "%s/%s: enemy %s has a scene in sandbox.json" % [label, wave_id, kind])
			if wave.has("warning"):
				assert_true(conversations.has(str(wave["warning"])), "%s/%s: warning bark %s is in slice_barks.json" % [label, wave_id, str(wave["warning"])])
			var start: Variant = wave.get("start", "on_trigger")
			if start is Dictionary and (start as Dictionary).has("after_wave"):
				var after: String = str((start as Dictionary)["after_wave"])
				assert_true(wave_ids.has(after), "%s/%s: starts after %s, which comes earlier in the same encounter" % [label, wave_id, after])
			wave_ids.append(wave_id)
		for raw_fixture: Variant in def.get("fixtures", []) as Array:
			var fixture: Dictionary = raw_fixture as Dictionary
			var fixture_kind: String = str(fixture.get("enemy", ""))
			if str(fixture.get("kind", "")) == "":
				assert_true(enemy_scenes.has(fixture_kind), "%s: fixture %s has a scene" % [label, fixture_kind])
			var online: Variant = fixture.get("online", "on_trigger")
			if online is Dictionary:
				assert_true(wave_ids.has(str((online as Dictionary).get("after_wave", ""))), "%s: a turret comes online after a wave that exists" % label)


func test_every_staged_scene_without_a_trigger_is_started_by_something() -> void:
	var scenes: Dictionary = DataDB.get_dict(SCENES_ID).get("scenes", {}) as Dictionary
	var corpus: String = _all_data_text(SCENES_FILE)
	var orphans: Array[String] = []
	for id: Variant in scenes.keys():
		var scene: Dictionary = scenes[id] as Dictionary
		if scene.has("trigger"):
			continue
		if not corpus.contains("\"%s\"" % str(id)):
			orphans.append(str(id))
	assert_true(orphans.is_empty(), "B6: scenes with no trigger that nothing names (never play): %s" % ", ".join(orphans))
	for id: String in ["charge_delivery", "appeal_market", "mox_deck", "gate_pass"]:
		assert_false(orphans.has(id), "%s is started by a placement or a job" % id)


func test_every_scene_a_placement_names_exists() -> void:
	var scenes: Dictionary = DataDB.get_dict(SCENES_ID).get("scenes", {}) as Dictionary
	var placements: Dictionary = DataDB.get_dict("slice/placements")
	var names: Array[String] = []
	_collect_key_strings(placements, "scene", names)
	assert_gt(names.size(), 0, "the placements name at least one scene")
	for scene_id: String in names:
		assert_true(scenes.has(scene_id), "placement scene %s exists in story_scenes.json" % scene_id)


func test_every_boss_ending_scene_and_bark_resolves() -> void:
	var scenes: Dictionary = DataDB.get_dict(SCENES_ID).get("scenes", {}) as Dictionary
	var conversations: Dictionary = DataDB.get_value(BARKS_ID, "conversations", {}) as Dictionary
	for boss_id: String in BOSS_IDS:
		var boss: Dictionary = DataDB.get_dict(boss_id)
		assert_false(boss.is_empty(), "%s loads" % boss_id)
		var ending: Dictionary = boss.get("ending", {}) as Dictionary
		assert_true(scenes.has(str(ending.get("scene", ""))), "%s: its ending scene exists in story_scenes.json" % boss_id)
		var barks: Array[String] = []
		_collect_barks(boss, barks)
		assert_gt(barks.size(), 0, "%s names barks" % boss_id)
		for bark: String in barks:
			assert_true(conversations.has(bark), "%s: bark %s is a conversation in slice_barks.json" % [boss_id, bark])


func test_every_hack_has_a_name_a_role_and_an_icon() -> void:
	var hacks: Dictionary = DataDB.get_dict(HACKS_ID).get("hacks", {}) as Dictionary
	assert_eq(hacks.size(), 4, "Red's four starter hacks")
	for id: Variant in hacks.keys():
		var hack: Dictionary = hacks[id] as Dictionary
		assert_false(str(hack.get("name", "")).is_empty(), "%s has a name" % str(id))
		assert_false(str(hack.get("role", "")).is_empty(), "%s has a role" % str(id))
		assert_true(HackIcons.has_icon(str(hack.get("icon", ""))), "%s has an icon (placeholder or final)" % str(id))


# ---- helpers ----

## Every JSON and CSV text under data/, except `skip_path`, joined. Used to ask "does anything name this id?".
func _all_data_text(skip_path: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	_collect_text(DATA_ROOT, skip_path, parts)
	return "\n".join(parts)


func _collect_text(dir_path: String, skip_path: String, parts: PackedStringArray) -> void:
	for file_name: String in DirAccess.get_files_at(dir_path):
		var path: String = dir_path.path_join(file_name)
		if path == skip_path or not (file_name.ends_with(".json") or file_name.ends_with(".csv")):
			continue
		parts.append(FileAccess.get_file_as_string(path))
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		_collect_text(dir_path.path_join(sub_dir), skip_path, parts)


## Every string value under any key named `key`, at any depth.
func _collect_key_strings(node: Variant, key: String, out: Array[String]) -> void:
	if node is Dictionary:
		for k: Variant in (node as Dictionary).keys():
			var value: Variant = (node as Dictionary)[k]
			if str(k) == key and value is String and not out.has(str(value)):
				out.append(str(value))
			_collect_key_strings(value, key, out)
	elif node is Array:
		for item: Variant in node as Array:
			_collect_key_strings(item, key, out)


## Every string under a key that starts with "on_" (the boss files name their radio barks that way).
func _collect_barks(node: Variant, out: Array[String]) -> void:
	if node is Dictionary:
		for k: Variant in (node as Dictionary).keys():
			var value: Variant = (node as Dictionary)[k]
			if str(k).begins_with("on_") and value is String and not out.has(str(value)):
				out.append(str(value))
			_collect_barks(value, out)
	elif node is Array:
		for item: Variant in node as Array:
			_collect_barks(item, out)
