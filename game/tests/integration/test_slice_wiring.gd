extends TestCase
## The gaps between the Level Designer's junkyard and the engine, on the real slice data (data/slice/rooms.json and the
## scenes under scenes/slice/junkyard): save terminals in rooms that have robots, a one-way door, breakable walls, the encounter
## runner (encounters.json + the scene's Encounters/ markers), the radio barks (Barks/ markers + slice_barks.json) and the
## room's music, ambience and hack sounds.

var _main: Main = null
var _router: Node = null
var _state: Node = null
var _manager: Node = null
var _audio: Node = null
var _old_dir: String = ""
var _dir: String = ""


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_router = tree.root.get_node("SceneRouter")
	_manager = tree.root.get_node("SaveManager")
	_audio = tree.root.get_node("AudioManager")
	_old_dir = str(_manager.get("save_dir"))
	_dir = "user://test_wiring_%d" % Time.get_ticks_usec()
	ExplorationKit.drop_stale_modals(self)


func after_each() -> void:
	if _main != null and is_instance_valid(_main):
		_main.apply_mode(GameMode.Mode.CLASSIC)
	_router.set("main", null)
	_router.set("instant", false)
	_router.set("current_room_id", "")
	_router.set("pending_room_id", "")
	_router.set("rooms_id", "world/rooms")
	_manager.set("save_dir", _old_dir)
	_manager.set("rooms_data_id", "world/rooms")
	_manager.set("saving_allowed", true)
	_state.set("rooms_data_id", "world/rooms")
	_state.call("reset")
	Placements.extra_ids = []
	Placements.extra_job_ids = []
	Placements.extra_scene_ids = []
	InputSorting.revert()
	SandboxPauseGate.clear(tree)
	_audio.call("stop_music")
	_audio.call("stop_all_loops")
	for node: Node in tree.get_nodes_in_group(ActionRoom.GROUP_HUD):
		node.remove_from_group(ActionRoom.GROUP_HUD)
		node.queue_free()
	if DirAccess.dir_exists_absolute(_dir):
		for file_name: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(file_name))
		DirAccess.remove_absolute(_dir)


## A slice-mode Main on the real rooms, started in `room_id` at `spawn`.
func _boot(room_id: String, spawn: String = "") -> ActionRoom:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate() as Main
	_main.show_title = false
	_main.debug_overlay_enabled = false
	_main.sandbox_boot_enabled = false
	add_to_root(_main)
	_main.apply_mode(GameMode.Mode.SLICE)
	_manager.set("save_dir", _dir)
	_router.set("main", _main)
	_router.set("instant", true)
	_state.call("reset")
	_router.call("start_at", room_id, spawn)
	return await _until_room(room_id)


func _until_room(room_id: String, limit: int = 240) -> ActionRoom:
	for i: int in limit:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return room
	fail("never reached %s" % room_id)
	return null


func _kill(enemy: Node3D) -> void:
	(enemy as CombatActor).apply_hit({"outcome": "hit", "damage": 99999, "hitstun_ms": 100.0, "knockback": Vector3.ZERO, "launch_mps": 0.0, "poise_after": 0.0})


func _put_hero(room: ActionRoom, at: Vector3) -> void:
	room.hero.global_position = at
	room.hero.velocity = Vector3.ZERO


# ---- 1. save terminals in rooms that name robots ----

func test_a_robot_room_saves_while_red_is_on_foot() -> void:
	var room: ActionRoom = await _boot("kasp_arena", "from_j5")
	assert_ne(str(room.entry.get("robots", "")), "", "the arena names the loader")
	assert_false(room.saving_blocked())
	assert_true(_manager.call("can_save"))
	var terminals: Array[SaveLamp] = []
	for node: Node in room.find_children("*", "Node", true, false):
		if node is SaveLamp:
			terminals.append(node as SaveLamp)
	assert_gt(terminals.size(), 0, "the arena gate has a save terminal")
	for terminal: SaveLamp in terminals:
		assert_true(terminal.enabled, "and it works while she is on foot")
	room._on_stage_form(&"small")
	assert_true(room.saving_blocked(), "in the loader it does not")
	for terminal: SaveLamp in terminals:
		assert_false(terminal.enabled)
	room._on_stage_form(&"red")
	for terminal: SaveLamp in terminals:
		assert_true(terminal.enabled, "and it works again once she climbs out")


# ---- 2. the one-way door ----

func test_j4_s_door_back_to_j3_shuts_when_the_loader_wakes() -> void:
	var room: ActionRoom = await _boot("junk_j4", "from_j3")
	var door: Door = null
	for node: Node in room.find_children("*", "Node3D", true, false):
		if node is Door and (node as Door).placement_id == "jk_j4_to_j3":
			door = node as Door
	assert_not_null(door)
	assert_true(door.is_unlocked(), "open while the loader sleeps")
	assert_false(door.is_shut())
	_state.call("set_flag", "loader_awake", true)
	assert_true(door.is_shut())
	assert_false(door.is_unlocked(), "shut once it wakes")
	assert_true(door.is_locked_by_data())
	assert_eq(door.locked_message(), str(Placements.door("jk_j4_to_j3")["locked_message"]))
	door.use(room.hero, room.interactor)
	for i: int in 5:
		await tree.physics_frame
	assert_eq(_main.get_room(), room, "she stays in J4")
	assert_eq(str(_router.get("current_room_id")), "junk_j4")
	_state.call("set_flag", "loader_awake", false)
	assert_true(door.is_unlocked(), "the flag decides, nothing else")


func test_not_flag_wins_over_a_door_that_was_opened_before() -> void:
	var room: ActionRoom = await _boot("junk_j4", "from_j3")
	var door: Door = null
	for node: Node in room.find_children("*", "Node3D", true, false):
		if node is Door and (node as Door).placement_id == "jk_j4_to_j3":
			door = node as Door
	_state.call("mark_opened", door.unlock_id())
	_state.call("set_flag", "loader_awake", true)
	assert_false(door.is_unlocked())


# ---- 3. breakable walls ----

func test_the_crane_s_vault_wall_can_be_smashed() -> void:
	var room: ActionRoom = await _boot("junk_j3", "from_j2")
	var wall: Node = room.find_child("VaultWall", true, false)
	assert_not_null(wall)
	assert_true(wall.has_method("smash"), "ActionRoom gave the plain StaticBody3D its smash()")
	assert_true(wall is BreakableWall)
	var wall_node: BreakableWall = wall as BreakableWall
	assert_false(wall_node.is_smashed())
	var heard: Array = []
	wall_node.smashed.connect(func(_w: BreakableWall) -> void: heard.append(1))
	wall_node.smash()
	assert_eq(heard.size(), 1)
	assert_true(bool(_state.call("get_flag", wall_node.flag_id())), "a sticky flag remembers it")
	for i: int in 70:
		await tree.physics_frame
	assert_true(wall_node.is_smashed())
	assert_false(wall_node.visible)
	for shape: Node in wall_node.find_children("*", "CollisionShape3D", true, false):
		assert_true((shape as CollisionShape3D).disabled, "the way is open")
	wall_node.smash()
	assert_eq(heard.size(), 1, "smashing twice does nothing more")


func test_a_loader_only_wall_falls_to_the_loader_and_not_to_red_on_foot() -> void:
	var room: ActionRoom = await _boot("junk_j4", "from_j3")
	var wall: StaticBody3D = StaticBody3D.new()
	wall.name = "TestSmashWall"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.0, 3.0, 4.0)
	shape.shape = box
	shape.position = Vector3(0.0, 1.5, 0.0)
	wall.add_child(shape)
	wall.add_to_group(BreakableWall.GROUP_LOADER)
	room.level.add_child(wall)
	wall.global_position = Vector3(8.0, 0.0, 8.0)
	room._prepare_breakables()
	assert_true(wall is BreakableWall)
	var smash_wall: BreakableWall = wall as BreakableWall
	_put_hero(room, Vector3(8.0, 0.1, 9.9))          # touching the box, on foot
	for i: int in 6:
		await tree.physics_frame
	assert_false(smash_wall.is_smashed(), "on foot it is just a wall")
	room._form = &"small"
	_put_hero(room, Vector3(8.0, 0.1, 9.9))
	for i: int in 70:
		_put_hero(room, Vector3(8.0, 0.1, 9.9))
		await tree.physics_frame
	assert_true(smash_wall.is_smashed(), "the loader walked into it")


# ---- 4. the encounter runner ----

func test_the_runner_reads_the_rooms_encounters_and_markers() -> void:
	var room: ActionRoom = await _boot("junk_j1", "from_market")
	assert_not_null(room.encounter_runner)
	assert_eq(room.encounter_runner.encounter_ids(), ["enc_j1_pair"] as Array[String])
	assert_eq(room.encounter_runner.state_of("enc_j1_pair"), "waiting")
	assert_eq(room.encounter_runner.enemies_of("enc_j1_pair").size(), 0, "nobody until Red comes near")


func test_walking_up_to_the_pound_starts_the_pair_with_the_data_s_numbers() -> void:
	var room: ActionRoom = await _boot("junk_j1", "from_market")
	var runner: EncounterRunner = room.encounter_runner
	runner.set_physics_process(false)
	runner.manual_ticks = true
	_put_hero(room, Vector3(2.0, 0.1, 22.0))
	runner.tick(0.1)
	assert_eq(runner.state_of("enc_j1_pair"), "waiting", "far away: quiet")
	_put_hero(room, Vector3(30.0, 0.1, 22.0))
	runner.tick(0.1)
	assert_eq(runner.state_of("enc_j1_pair"), "running", "inside 8 m of the barrels")
	var cops: Array[Node3D] = runner.enemies_of("enc_j1_pair")
	assert_eq(cops.size(), 2, "two cops")
	var base_hp: int = int(DataDB.get_value("combat/enemies", "enemies.grunt.hp_max", 0))
	if base_hp > 0:
		assert_eq((cops[0] as CombatActor).hp_max, int(round(float(base_hp) * 0.8)), "20 percent less health (hp_mult 0.8)")
	assert_eq(room.director.tokens.max_attackers, 1, "ONE attacks at a time while this fight is on")
	assert_lt(cops[0].global_position.distance_to(Vector3(34.0, 0.1, 20.0)), 3.5, "at the barrel, from the marker")
	for cop: Node3D in cops:
		_kill(cop)
	runner.tick(0.1)
	assert_eq(runner.state_of("enc_j1_pair"), "cleared")
	assert_eq(room.director.tokens.max_attackers, 2, "the usual cap is back")


func test_a_later_wave_comes_when_the_first_thins_out_and_its_warning_goes_to_the_radio() -> void:
	var room: ActionRoom = await _boot("junk_j2", "from_j1")
	var runner: EncounterRunner = room.encounter_runner
	runner.set_physics_process(false)
	runner.manual_ticks = true
	var warnings: Array[String] = []
	runner.wave_warning.connect(func(_id: String, bark: String) -> void: warnings.append(bark))
	var spoken: Array[String] = []
	room.radio_barks.radio_said.connect(func(_speaker: String, text: String) -> void: spoken.append(text))
	runner.tick(0.1)                                    # the chute is a room_enter fight with a turret only
	_put_hero(room, Vector3(66.0, 0.1, 22.0))
	runner.tick(0.1)
	assert_eq(runner.state_of("enc_j2_pitstop"), "running")
	assert_eq(runner.enemies_of("enc_j2_pitstop").size(), 3, "three cops first")
	assert_eq(runner.fixtures_of("enc_j2_pitstop").size(), 1, "and the turret on its ledge")
	for cop: Node3D in runner.enemies_of("enc_j2_pitstop"):
		_kill(cop)
	runner.tick(3.0)                                    # past the 2.5 s wave gap
	assert_eq(warnings, ["bark_j2_overclock"] as Array[String], "the warning goes out first")
	assert_eq(spoken.size(), 1, "and Vela says it on the radio")
	runner.tick(1.0)                                    # past the 0.9 s notice
	assert_eq(runner.enemies_of("enc_j2_pitstop").size(), 1, "then the heavy")


func test_a_sticky_fight_drops_the_shutters_and_stays_cleared() -> void:
	var room: ActionRoom = await _boot("junk_j4", "from_j3")
	var runner: EncounterRunner = room.encounter_runner
	runner.set_physics_process(false)
	runner.manual_ticks = true
	assert_false(runner.shutters_down(), "raised: open")
	_put_hero(room, Vector3(28.0, 0.1, 30.0))
	runner.tick(0.1)
	assert_eq(runner.state_of("enc_j4_stand"), "running")
	assert_true(runner.shutters_down(), "the Stand shuts behind her")
	assert_true(bool(_state.call("get_flag", "j4_stand_started")))
	var guard: int = 0
	while runner.state_of("enc_j4_stand") == "running" and guard < 40:
		for enemy: Node3D in runner.enemies_of("enc_j4_stand"):
			_kill(enemy)
		runner.tick(20.0)
		guard += 1
	assert_eq(runner.state_of("enc_j4_stand"), "cleared", "three waves, all dead")
	assert_true(bool(_state.call("get_flag", "j4_stand_cleared")), "sticky: the clear flag is set for good")
	assert_false(runner.shutters_down(), "the shutters go back up")
	# Back in the room later: nothing runs.
	_router.call("start_at", "junk_j4", "from_j3")
	var again: ActionRoom = await _until_room("junk_j4")
	assert_ne(again, room)
	assert_eq(again.encounter_runner.state_of("enc_j4_stand"), "cleared")
	assert_false(again.encounter_runner.shutters_down())


func test_wave_gated_turrets_power_up_when_their_wave_spawns() -> void:
	var room: ActionRoom = await _boot("junk_j4", "from_j3")
	var runner: EncounterRunner = room.encounter_runner
	runner.set_physics_process(false)
	runner.manual_ticks = true
	assert_eq(runner.fixtures_of("enc_j4_stand").size(), 0, "no turrets until the Stand begins")
	_put_hero(room, Vector3(28.0, 0.1, 30.0))
	runner.tick(0.1)
	var turrets: Array[Node3D] = runner.fixtures_of("enc_j4_stand")
	assert_eq(turrets.size(), 2, "the two turrets from the Fixtures markers")
	assert_true(turrets[0].get_meta("fixture_online") is Dictionary, "their rule is 'after wave w1'")
	assert_true(bool(turrets[0].get("attacks_allowed")), "w1 has spawned, so they may shoot")
	assert_eq(str(turrets[0].get_meta("fixture_id")), "turret_j4_a")


# ---- 5. radio barks ----

func test_a_bark_marker_plays_the_writers_line_once_through_the_radio() -> void:
	var room: ActionRoom = await _boot("junk_j1", "from_market")
	var barks: RadioBarks = room.radio_barks
	barks.set_physics_process(false)
	barks.manual_ticks = true
	assert_eq(barks.marker_ids(), ["bark_j1_arrive", "bark_j1_lockon", "bark_j1_zap"] as Array[String])
	var spoken: Array[String] = []
	barks.radio_said.connect(func(speaker: String, text: String) -> void: spoken.append("%s: %s" % [speaker, text]))
	_put_hero(room, Vector3(30.0, 0.1, 22.0))
	assert_eq(barks.tick(), ["bark_j1_lockon"] as Array[String], "inside the 9 m of the lock-on marker")
	var line: String = str(DataDB.get_value("dialogue/slice_barks", "conversations.bark_j1_lockon", [])[0]["text"])
	assert_eq(spoken, ["vela: %s" % line] as Array[String])
	assert_eq(barks.tick(), [] as Array[String], "once per run")
	assert_true(bool(_state.call("get_flag", "bark_heard_bark_j1_lockon")))
	var radio: RadioBark = room.get_hud().call("get_radio") as RadioBark
	var arrive: String = str(DataDB.get_value("dialogue/slice_barks", "conversations.bark_j1_arrive", [])[0]["text"])
	assert_eq(str(radio.current_line().get("text", "")), arrive, "the radio box is showing Vela (the arrival bark played first, the lock-on one is queued)")


func test_variants_cycle_and_two_line_barks_queue_back_to_back() -> void:
	var room: ActionRoom = await _boot("junk_j1", "from_market")
	var barks: RadioBarks = room.radio_barks
	var spoken: Array[String] = []
	barks.radio_said.connect(func(_speaker: String, text: String) -> void: spoken.append(text))
	var conversations: Dictionary = DataDB.get_value("dialogue/slice_barks", "conversations", {})
	assert_true(barks.say("kasp_rig_quiet_hours"))
	assert_eq(spoken[0], str(conversations["kasp_rig_quiet_hours"][0]["text"]), "the first time the first")
	spoken.clear()
	assert_true(barks.say("kasp_rig_quiet_hours"))
	assert_eq(spoken[0], str(conversations["kasp_rig_quiet_hours_v2"][0]["text"]), "then the next")
	assert_false(barks.say("no_such_bark"))
	var two: String = ""
	for id: String in conversations:
		if (conversations[id] as Array).size() >= 2:
			two = id
			break
	if not two.is_empty():
		spoken.clear()
		assert_true(barks.say(two))
		assert_eq(spoken.size(), (conversations[two] as Array).size())


func test_every_bark_marker_in_every_room_has_a_line() -> void:
	var conversations: Dictionary = DataDB.get_value("dialogue/slice_barks", "conversations", {})
	for room_id: String in ["junk_j1", "junk_j2", "junk_j3", "junk_j4"]:
		var scene: PackedScene = load(str(DataDB.get_value("slice/rooms", "rooms.%s.scene" % room_id, ""))) as PackedScene
		var level: Node = scene.instantiate()
		var holder: Node = level.get_node_or_null("Barks")
		if holder != null:
			for marker: Node in holder.get_children():
				assert_true(conversations.has(str(marker.name)), "%s: %s has a line in slice_barks.json" % [room_id, marker.name])
		level.free()


# ---- 6. sound ----

func test_a_room_plays_its_music_and_ambience_and_swaps_them_at_the_door() -> void:
	await _boot("market_hideout")
	assert_eq(_audio.get("current_music_id"), &"music_market", "rooms.json music: market")
	assert_true(bool(_audio.call("is_loop_playing", &"amb_market_night")))
	_router.call("go_to", "junk_j1", "from_market")
	await _until_room("junk_j1")
	assert_false(bool(_audio.call("is_loop_playing", &"amb_market_night")), "the market bed stopped")
	assert_true(bool(_audio.call("is_loop_playing", &"amb_junkyard")), "the yard's started")
	_router.call("go_to", "junk_j2", "from_j1")
	await _until_room("junk_j2")
	for i: int in 3:
		await tree.physics_frame
	assert_true(bool(_audio.call("is_loop_playing", &"amb_junkyard")), "the same bed in the next room is not cut off")


func test_the_arena_music_uses_the_boss_track() -> void:
	var cfg: Dictionary = DataDB.get_dict("slice/audio")
	assert_eq(str((cfg["music_aliases"] as Dictionary)["kasp_phase1"]), "hushmaster")
	assert_ne(str(_audio.call("resolve_music_id", &"hushmaster")), "", "music_hushmaster exists")
	assert_ne(str(_audio.call("resolve_music_id", &"junk_mech")), "")


func test_hack_signals_fire_their_sounds() -> void:
	var room: ActionRoom = await _boot("market_hideout")
	var played: Array[StringName] = []
	room.slice_audio.sound_played.connect(func(id: StringName) -> void: played.append(id))
	var director: CombatDirector = room.director
	director.hack_cast.emit({"hack": &"emp"})
	director.hack_cast.emit({"hack": &"zap_drone"})
	director.hack_refused.emit({"hack": &"overclock", "reason": "no_signal"})
	director.hack_locked.emit(true, 5000.0)
	director.hack_locked.emit(false, 0.0)
	assert_eq(played, [&"hack_emp", &"hack_zap_cast", &"hack_denied", &"hack_locked", &"hack_unlocked"] as Array[StringName])
	played.clear()
	director.battery_changed.emit(60.0, 100.0)
	director.battery_changed.emit(100.0, 100.0)
	director.battery_changed.emit(100.0, 100.0)
	assert_eq(played, [&"hack_battery_full"] as Array[StringName], "the chime plays once, when it tops up")
	played.clear()
	director.hijack_changed.emit({"active": true, "duration_s": 10.0})
	assert_true(bool(_audio.call("is_loop_playing", &"hack_overclock_loop")), "the hum while something is hijacked")
	director.hijack_changed.emit({"active": true, "duration_s": 10.0})
	director.hijack_changed.emit({"active": false})
	assert_true(bool(_audio.call("is_loop_playing", &"hack_overclock_loop")), "one is still hijacked")
	director.hijack_changed.emit({"active": false})
	assert_false(bool(_audio.call("is_loop_playing", &"hack_overclock_loop")))
	assert_has(played, &"hack_overclock_end")


func test_every_sound_the_audio_file_names_exists() -> void:
	var cfg: Dictionary = DataDB.get_dict("slice/audio")
	var ids: Array = []
	var hack: Dictionary = cfg["hack_sounds"] as Dictionary
	for key: String in hack:
		if hack[key] is Dictionary:
			ids.append_array((hack[key] as Dictionary).values())
		else:
			ids.append(hack[key])
	for beds: Variant in (cfg["ambience_by_music"] as Dictionary).values():
		ids.append_array(beds as Array)
	for id: Variant in ids:
		assert_true(bool(_audio.call("has_sfx", StringName(str(id)))), "sfx.json has '%s'" % id)
