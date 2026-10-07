extends TestCase
## The battle stage against the real BattleController (virtual clock, a policy answering every command): the
## controller's own snapshot and signals build the views, every enemy model the encounter data names resolves to
## a placeholder, the fight runs to a win, and the stage hands back `finished` with the controller's report.
## Skipped quietly when the real controller is not in the project.

const CONTROLLER_PATH: String = "res://scripts/battle/model/battle_controller.gd"
const SCENE: String = "res://scenes/battle/battle_scene.tscn"
const TUNING_DATA_ID: String = "battle_stage/stage"
const WAIT_LIMIT_S: float = 8.0


func _stage() -> BattleScene:
	var stage: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	stage.transitions_enabled = false
	stage.audio = FakeAudio.new()
	add_to_root(stage)
	stage.set_dynamic_camera(false)
	var db: Node = tree.root.get_node("DataDB")
	var data: Dictionary = (db.call("get_dict", TUNING_DATA_ID) as Dictionary).duplicate(true)
	data["end"]["hold_s"] = 0.02
	data["ko"]["freeze_ms"] = 40
	stage.tuning = BattleStageTuning.from_dict(data)
	return stage


func _setup(encounter_id: String) -> BattleSetup:
	var data: BattleData = BattleData.shared()
	var progression: Progression = Progression.new(data)
	var setup: BattleSetup = BattleSetup.new()
	setup.data = data
	setup.encounter_id = encounter_id
	setup.rng_seed = 5
	setup.clock = VirtualClock.new()
	setup.auto_timing = true
	setup.command_source = BattleSimPolicy.new()
	for char_id: String in data.character_order:
		setup.party.append(progression.new_member(char_id, 5))
	setup.bag = {"ration_bar": 2}
	return setup


func _wait_for_finish(stage: BattleScene, done: Array) -> bool:
	var start: int = Time.get_ticks_msec()
	while done.is_empty():
		if stage.hud != null and not stage.result.is_empty() and stage.hud.has_signal("finished"):
			stage.hud.emit_signal("finished", stage.result, "continue")
		if float(Time.get_ticks_msec() - start) / 1000.0 > WAIT_LIMIT_S:
			return false
		await tree.process_frame
	return true


func test_every_encounter_resolves_a_placeholder_model_for_every_enemy() -> void:
	if not ResourceLoader.exists(CONTROLLER_PATH):
		assert_true(true, "real controller not in the project yet")
		return
	var stage: BattleScene = _stage()
	var data: BattleData = BattleData.shared()
	var seen: int = 0
	for encounter_id: String in ["grunt_solo", "grunt_pair", "drone_flock", "squad_four", "ambush_no_exit"]:
		var controller: BattleController = BattleController.create(_setup(encounter_id))
		var snap: Dictionary = controller.snapshot()
		for entry: Variant in (snap["combatants"] as Array):
			var info: Dictionary = entry
			var path: String = stage._resolve_model(info)
			assert_true(ResourceLoader.exists(path), "%s %s resolves to a model that exists (%s)" % [encounter_id, info["id"], path])
			if str(info["side"]) == "enemy":
				assert_true(path.begins_with("res://art/placeholder/enemies/"), "%s resolves to an enemy placeholder (%s)" % [info["kind"], path])
				seen += 1
	assert_gt(seen, 10)
	assert_eq(stage.tuning.backdrop("harrow_docks")["floor_a"], stage.tuning.backdrop("harrow")["floor_a"], "encounter backdrop ids map to the sets")
	assert_eq(stage.tuning.backdrop("relay_tower_floor")["floor_a"], stage.tuning.backdrop("tower")["floor_a"])
	assert_not_null(data)


func test_a_full_real_fight_plays_through_the_stage() -> void:
	if not ResourceLoader.exists(CONTROLLER_PATH):
		assert_true(true, "real controller not in the project yet")
		return
	var stage: BattleScene = _stage()
	var setup: BattleSetup = _setup("squad_four")
	var done: Array = []
	stage.finished.connect(func(result: String, report: Dictionary) -> void: done.append([result, report]))
	stage.controller_factory = func(made_for: RefCounted) -> Object:
		return BattleController.create(made_for as BattleSetup)
	await stage.start_battle(setup)
	var finished_ok: bool = await _wait_for_finish(stage, done)
	assert_true(finished_ok, "the stage reached `finished`")
	assert_eq(done.size(), 1)
	assert_eq(done[0][0], "win")
	assert_gt(int(done[0][1]["xp"]), 0, "the controller's report comes through")
	assert_eq(stage.views.size(), 3 + 4, "party of three, squad of four")
	# A fight can also end with the last enemy waving a white flag (no final KO target, so no K.O. beat);
	# that depends on exact damage numbers, so retuning enemy HP must not break this test.
	var white_flag_finish: bool = str((done[0][1] as Dictionary).get("final_ko_target", "")) == ""
	assert_true(stage.ko_beat_done or white_flag_finish, "the last enemy got its K.O. beat (or left under a white flag)")
	var fled_or_down: int = 0
	for id: String in stage.views:
		var view: CombatantView = stage.views[id]
		assert_false(view.used_fallback, "%s has a model" % id)
		if view.side == "enemy" and view.down:
			fled_or_down += 1
	assert_eq(fled_or_down, 4, "every enemy ended down or gone")
	assert_true((stage.audio as FakeAudio).sfx_ids.has("battle_ding"), "cues fired")
	assert_true((stage.audio as FakeAudio).sfx_ids.has("battle_hit"), "hits landed")


func test_the_real_snapshot_sets_boss_and_backdrop() -> void:
	if not ResourceLoader.exists(CONTROLLER_PATH):
		assert_true(true, "real controller not in the project yet")
		return
	var stage: BattleScene = _stage()
	var controller: BattleController = BattleController.create(_setup("drone_flock"))
	stage.attach_controller(controller)
	stage._on_battle_started(controller.snapshot())
	assert_eq(stage._backdrop_id, "relay_tower_floor")
	assert_false(stage.is_boss)
	assert_eq(stage.views.size(), 6)
	assert_true(stage.get_view("e3").model_path.contains("grunt_variant"), "the whistle blower is the grunt variant")
