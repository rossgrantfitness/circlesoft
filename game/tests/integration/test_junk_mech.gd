extends TestCase
## The Heap, phase 2 of Kasp's fight (VS-28; docs/slice/boss_design.md, data/combat/bosses/junk_mech.json): a 40 m junk mech built
## in final world units. Four attacks with floor decals and a lamp that goes orange then red, four armour plates that take 35 percent
## until the attack that names them is recovering, the core behind them, the reveal, the last stand and the collapse; repair cells in
## smashable containers; the boss bar's pips. Red stands in for the colossus (a bigger health bar is all the fight needs).

const DT: float = 1.0 / 60.0

var _kit: BossKit = null
var _mech: JunkMech = null


func _setup(red_at: Vector3 = Vector3(0, 0.02, 30)) -> void:
	_kit = BossKit.new(self)
	await _kit.arena(false)
	_kit.red.hp_max = 6000
	_kit.red.hp = 6000
	_kit.red.global_position = red_at
	_mech = JunkMech.create(CombatData.read_json(CombatData.DIR + "bosses/junk_mech.json"), 5)
	_kit.room.add_child(_mech)
	_mech.set_physics_process(false)
	_mech.global_position = Vector3.ZERO
	await _kit.frames(5)


func _frames(count: int) -> void:
	for i: int in range(count):
		await tree.physics_frame
		_kit.director.tick(DT)
		_kit.red.tick(DT)
		_mech.tick(DT)


func _until(done: Callable, limit: int = 900) -> int:
	var count: int = 0
	while not bool(done.call()) and count < limit:
		await _frames(1)
		count += 1
	return count


func _open_all_and_break_plates() -> void:
	for id: StringName in JunkMech.PLATE_IDS:
		var plate: BossPart = _mech.part(id)
		_mech._open_left_ms[id] = 99999.0
		plate.apply_hit({"damage": 99999, "source": "sword", "outcome": &"hit", "move_id": &"light_1"})


# ---- built ----

func test_the_heap_has_four_plates_and_a_core_at_colossus_scale() -> void:
	await _setup()
	assert_eq(_mech.scale_form, &"huge")
	assert_eq(_mech.plates_standing(), 4)
	assert_eq(_mech.parts().size(), 5)
	assert_eq(_mech.part(&"plate_chest").hp_max, 3200)
	assert_eq(_mech.part(&"core").hp_max, 8400)
	assert_eq(_mech.height_m, 40.0)
	assert_has(_mech.tags(), "boss")
	assert_has(_mech.tags(), "robot")


func test_the_plates_follow_the_models_bones() -> void:
	await _setup()
	var chest: BossPart = _mech.part(&"plate_chest")
	assert_almost_eq(chest.global_position.y + chest.height_m * 0.5, 23.3, 1.0, "the chest plate is on the chest, 23 m up")
	var left: BossPart = _mech.part(&"plate_shoulder_l")
	var right: BossPart = _mech.part(&"plate_shoulder_r")
	assert_gt(left.global_position.x, right.global_position.x, "left is +X, as on Red")


func test_the_bar_shows_the_plates_total_then_the_core() -> void:
	await _setup()
	var bars: Array[Vector2] = []
	_mech.bar_changed.connect(func(hp: float, hp_max: float) -> void: bars.append(Vector2(hp, hp_max)))
	_mech._hp_cache = -1.0
	await _frames(2)
	assert_eq(bars[0], Vector2(10000.0, 10000.0), "four plates, 10,000 in all")
	_open_all_and_break_plates()
	await _frames(2)
	assert_eq(bars[bars.size() - 1], Vector2(8400.0, 8400.0), "then the core")


func test_the_plate_health_knob_scales_the_plates() -> void:
	_kit = BossKit.new(self)
	await _kit.arena(false)
	_kit.director.feel.set_value("heap_plate_hp_scale", 0.5)
	var doc: Dictionary = CombatData.read_json(CombatData.DIR + "bosses/junk_mech.json")
	var mech: JunkMech = JunkMech.create(doc, 1)
	_kit.room.add_child(mech)
	mech.set_physics_process(false)
	assert_eq(mech.part(&"plate_chest").hp_max, 1600)
	assert_eq(mech.part(&"core").hp_max, 8400, "the core is not scaled")


# ---- plates and the core ----

func test_a_closed_plate_takes_35_percent_and_an_open_one_full_damage() -> void:
	await _setup()
	await _frames(2)
	var plate: BossPart = _mech.part(&"plate_chest")
	var closed: Dictionary = {"damage": 100, "source": "sword", "outcome": &"hit", "move_id": &"light_1"}
	plate.apply_hit(closed)
	assert_eq(closed["damage"], 35)
	_mech._open_left_ms[&"plate_chest"] = 1000.0
	await _frames(1)
	var open: Dictionary = {"damage": 100, "source": "sword", "outcome": &"hit", "move_id": &"light_1"}
	plate.apply_hit(open)
	assert_eq(open["damage"], 100)


func test_the_core_is_sealed_while_any_plate_stands() -> void:
	await _setup()
	await _frames(2)
	var hit: Dictionary = {"damage": 500, "source": "sword", "outcome": &"hit", "move_id": &"light_1"}
	_mech.part(&"core").apply_hit(hit)
	assert_eq(hit["damage"], 0)
	assert_eq(_mech.part(&"core").hp, 8400)


func test_a_plate_opens_in_the_recovery_of_the_attack_that_names_it_and_closes_again() -> void:
	await _setup()
	var opened: Array[StringName] = []
	_mech.plate_opened.connect(func(id: StringName) -> void: opened.append(id))
	_kit.red.hp = 6000
	_mech.brain.begin(&"scrap_swing", 0.0)
	_mech.brain.finish(0.0, 0, 0.0)
	_mech._start_pattern(_mech.brain.make_pick(&"scrap_swing", _mech._view(30.0)))
	var side: StringName = _mech.current_move()
	var plate: StringName = &"plate_shoulder_l" if side == &"scrap_swing_l" else &"plate_shoulder_r"
	assert_false(_mech.is_plate_open(plate), "not while it winds up")
	await _until(func() -> bool: return _mech.is_plate_open(plate), 400)
	assert_true(_mech.is_plate_open(plate), "open in the recovery")
	assert_eq(opened, [plate] as Array[StringName])
	assert_true(_mech.runner.phase() == MoveRunner.PHASE_RECOVERY)
	await _until(func() -> bool: return not _mech.is_plate_open(plate), 400)
	assert_false(_mech.is_plate_open(plate), "and shut again 400 ms after the recovery")


func test_breaking_a_plate_drops_a_pip_hides_the_plate_and_barks() -> void:
	await _setup()
	var pips: Array[Vector2i] = []
	var barks: Array[StringName] = []
	_mech.pips_changed.connect(func(standing: int, total: int) -> void: pips.append(Vector2i(standing, total)))
	_mech.bark.connect(func(id: StringName) -> void: barks.append(id))
	_mech._open_left_ms[&"plate_back"] = 9999.0
	await _frames(1)
	_mech.part(&"plate_back").apply_hit({"damage": 99999, "source": "sword", "outcome": &"hit", "move_id": &"light_1"})
	assert_eq(pips, [Vector2i(3, 4)])
	assert_has(barks, &"kasp_mech_plate")
	assert_eq(_mech.plates_standing(), 3)


func test_the_last_plate_opens_the_cab_for_2_6_seconds_nothing_can_hurt_it() -> void:
	await _setup()
	var shots: Array[StringName] = []
	_mech.shot.connect(func(id: StringName) -> void: shots.append(id))
	_open_all_and_break_plates()
	await _frames(2)
	assert_eq(_mech.stage, &"core")
	assert_has(shots, &"shot_core_reveal")
	assert_true(_mech.is_invulnerable())
	var hit: Dictionary = {"damage": 500, "source": "sword", "outcome": &"hit", "move_id": &"light_1"}
	_mech.part(&"core").apply_hit(hit)
	assert_eq(hit["damage"], 0, "untouchable during the reveal")
	await _frames(60 * 3)
	assert_false(_mech.is_invulnerable())
	var after: Dictionary = {"damage": 100, "source": "sword", "outcome": &"hit", "move_id": &"light_1"}
	_mech.part(&"core").apply_hit(after)
	assert_eq(after["damage"], 50, "half damage while it is not recovering")


func test_the_core_takes_150_percent_in_every_recovery() -> void:
	await _setup()
	_open_all_and_break_plates()
	await _frames(60 * 3)
	_mech.brain.begin(&"scrap_barrage", 0.0)
	_mech.brain.finish(0.0, 0, 0.0)
	_mech._start_pattern(_mech.brain.make_pick(&"scrap_barrage", _mech._view(35.0)))
	await _until(func() -> bool: return _mech.runner.is_busy() and _mech.runner.phase() == MoveRunner.PHASE_RECOVERY, 600)
	await _frames(2)
	assert_true(_mech.is_core_open())
	var hit: Dictionary = {"damage": 100, "source": "sword", "outcome": &"hit", "move_id": &"light_1"}
	_mech.part(&"core").apply_hit(hit)
	assert_eq(hit["damage"], 150)


func test_at_35_percent_the_core_roars_and_the_last_stand_begins() -> void:
	await _setup()
	var stages: Array[StringName] = []
	_mech.stage_changed.connect(func(id: StringName) -> void: stages.append(id))
	_open_all_and_break_plates()
	await _frames(60 * 3)
	var core: BossPart = _mech.part(&"core")
	core.hp = 3000
	core.apply_hit({"damage": 10, "source": "sword", "outcome": &"hit", "move_id": &"light_1"})
	assert_eq(_mech.stage, &"last_stand")
	assert_true(_mech.is_invulnerable(), "the roar: 2.2 s untouchable")
	assert_has(stages, &"last_stand")
	await _frames(60 * 3)
	assert_false(_mech.is_invulnerable())


func test_a_chain_plays_two_attacks_with_the_gap_between() -> void:
	await _setup()
	_open_all_and_break_plates()
	await _frames(60 * 3)
	_mech.part(&"core").hp = 3000
	_mech.part(&"core").apply_hit({"damage": 10, "source": "sword", "outcome": &"hit", "move_id": &"light_1"})
	await _frames(60 * 3)
	var played: Array[StringName] = []
	_mech._start_pattern(_mech.brain.make_pick(&"chain_a", _mech._view(30.0)))
	played.append(_mech.current_move())
	await _until(func() -> bool: return _mech.state == JunkMech.State.CHAIN_WAIT, 600)
	await _until(func() -> bool: return _mech.state == JunkMech.State.PATTERN, 120)
	played.append(_mech.current_move())
	assert_eq(played, [&"scrap_swing_l", &"wrecking_drop"] as Array[StringName])


func test_breaking_the_core_collapses_the_heap_and_ends_the_phase() -> void:
	await _setup()
	var done: Array[bool] = []
	_mech.defeated.connect(func() -> void: done.append(true))
	_open_all_and_break_plates()
	await _frames(60 * 3)
	var core: BossPart = _mech.part(&"core")
	core.hp = 1
	_mech._core_open_ms = 5000.0
	await _frames(1)
	core.apply_hit({"damage": 100, "source": "sword", "outcome": &"hit", "move_id": &"light_1"})
	assert_eq(_mech.state, JunkMech.State.DEFEAT)
	assert_true(done.is_empty(), "five seconds of collapse first")
	await _until(func() -> bool: return not done.is_empty(), 400)
	assert_eq(done.size(), 1)


# ---- the attacks ----

func _hits_from_heap() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for info: Dictionary in _kit.hits_on_red():
		if str(info["attacker"]) == "junk_mech":
			out.append(info)
	return out


func test_the_swing_hits_for_720_in_front_of_the_arm() -> void:
	await _setup(Vector3(0, 0.02, 20))
	_mech._start_pattern(_mech.brain.make_pick(&"scrap_swing", _mech._view(20.0)))
	await _until(func() -> bool: return not _hits_from_heap().is_empty(), 400)
	assert_eq(_hits_from_heap().size(), 1, "one hit per swing")
	assert_eq(int(_hits_from_heap()[0]["damage"]), 720)


func test_stepping_out_of_the_swing_arc_beats_it() -> void:
	await _setup(Vector3(0, 0.02, 20))
	_mech._start_pattern(_mech.brain.make_pick(&"scrap_swing", _mech._view(20.0)))
	await _frames(60)
	_kit.red.global_position = Vector3(45, 0.02, 20)
	await _frames(300)
	assert_eq(_hits_from_heap().size(), 0)


func test_the_drop_circle_follows_red_then_locks_and_the_ring_comes_for_572() -> void:
	await _setup(Vector3(0, 0.02, 25))
	_mech._start_pattern(_mech.brain.make_pick(&"wrecking_drop", _mech._view(25.0)))
	await _frames(30)
	var early: Vector3 = _mech.lock_position(&"locked_target")
	_kit.red.global_position = Vector3(10, 0.02, 25)
	await _frames(20)
	assert_almost_eq(_mech.lock_position(&"locked_target").x, 10.0, 0.5, "it follows her")
	assert_ne(_mech.lock_position(&"locked_target"), early)
	await _until(func() -> bool: return _mech.is_locked(&"locked_target"), 200)
	var locked: Vector3 = _mech.lock_position(&"locked_target")
	_kit.red.global_position = locked + Vector3(30, 0, 0)         # 30 m from the circle: the ring (16 to 52 m) will cross her
	await _frames(15)
	assert_eq(_mech.lock_position(&"locked_target"), locked, "and stays")
	await _until(func() -> bool: return not _hits_from_heap().is_empty(), 300)
	assert_eq(int(_hits_from_heap()[0]["damage"]), 572, "the ring: 1040 x 0.55")


func test_standing_in_the_drop_circle_takes_the_full_1040() -> void:
	await _setup(Vector3(0, 0.02, 25))
	_mech._start_pattern(_mech.brain.make_pick(&"wrecking_drop", _mech._view(25.0)))
	await _until(func() -> bool: return not _hits_from_heap().is_empty(), 400)
	assert_eq(int(_hits_from_heap()[0]["damage"]), 1040)


func test_the_march_has_two_rings_a_second_apart() -> void:
	await _setup(Vector3(0, 0.02, 20))
	_mech._start_pattern(_mech.brain.make_pick(&"stomp_march", _mech._view(20.0)))
	_kit.red.global_position = Vector3(0, 0.02, 33)
	var times: Array[float] = []
	for i: int in range(300):
		await _frames(1)
		if _hits_from_heap().size() > times.size():
			times.append(_mech.runner.elapsed_ms())
		if times.size() >= 2:
			break
	assert_eq(times.size(), 2, "both stomps hit someone standing in the ring's path")


func test_the_barrage_circles_land_where_red_stood_and_miss_if_she_moves() -> void:
	await _setup(Vector3(0, 0.02, 30))
	_mech._start_pattern(_mech.brain.make_pick(&"scrap_barrage", _mech._view(30.0)))
	await _frames(60 * 2)
	var spots: Array[Vector3] = [_mech.lock_position(&"target_1"), _mech.lock_position(&"target_2"), _mech.lock_position(&"target_3")]
	assert_true(_mech.is_locked(&"target_1"))
	_kit.red.global_position = spots[0] + Vector3(25, 0, 0)            # always 25 m from the last circle: out of their 9 m
	for i: int in range(240):
		await _frames(1)
		_kit.red.global_position = _mech.lock_position(&"target_3") + Vector3(25, 0, 0) if _mech.is_locked(&"target_3") else spots[0] + Vector3(25, 0, 0)
	assert_eq(_hits_from_heap().size(), 0, "she kept moving")


func test_standing_still_through_the_barrage_is_hit() -> void:
	await _setup(Vector3(0, 0.02, 30))
	_mech._start_pattern(_mech.brain.make_pick(&"scrap_barrage", _mech._view(30.0)))
	await _frames(60 * 4)
	assert_gt(float(_hits_from_heap().size()), 0.0)
	assert_eq(int(_hits_from_heap()[0]["damage"]), 360)


func test_the_damage_knob_scales_what_the_heap_does() -> void:
	await _setup(Vector3(0, 0.02, 25))
	_kit.director.feel.set_value("heap_damage_scale", 0.5)
	_mech._start_pattern(_mech.brain.make_pick(&"wrecking_drop", _mech._view(25.0)))
	await _until(func() -> bool: return not _hits_from_heap().is_empty(), 400)
	assert_eq(int(_hits_from_heap()[0]["damage"]), 520)


func test_the_gap_knob_stretches_the_pause_between_attacks() -> void:
	await _setup(Vector3(0, 0.02, 25))
	_kit.director.feel.set_value("heap_gap_scale", 2.0)
	_mech._start_pattern(_mech.brain.make_pick(&"stomp_march", _mech._view(25.0)))
	await _until(func() -> bool: return _mech.state == JunkMech.State.WALK and not _mech.brain.is_busy(), 900)
	var wait_ms: float = _mech.brain.next_ok_ms() - _mech.clock.now_ms()
	assert_almost_eq(wait_ms, 5200.0, 200.0, "2600 ms x 2")


# ---- readable ----

func test_the_lamps_go_orange_then_red_before_the_hit() -> void:
	await _setup(Vector3(0, 0.02, 25))
	_mech._start_pattern(_mech.brain.make_pick(&"wrecking_drop", _mech._view(25.0)))
	await _frames(30)
	assert_not_null(_mech._lamp_material)
	assert_eq(_mech._lamp_material.emission, JunkMech.LAMP_WINDUP)
	await _until(func() -> bool: return _mech.runner.elapsed_ms() >= 2020.0, 300)
	assert_eq(_mech._lamp_material.emission, JunkMech.LAMP_RED, "red for the last 400 ms before the impact")


func test_every_attack_paints_a_decal_while_it_winds_up() -> void:
	await _setup(Vector3(0, 0.02, 25))
	for pattern: StringName in [&"scrap_swing", &"wrecking_drop", &"stomp_march"]:
		_mech._start_pattern(_mech.brain.make_pick(pattern, _mech._view(25.0)))
		await _frames(40)
		var shown: bool = false
		for key: Variant in _mech._decals.keys():
			if (_mech._decals[key] as MeshInstance3D).visible:
				shown = true
		assert_true(shown, "%s paints something on the floor" % pattern)
		_mech._abort_pattern()
		await _frames(2)


func test_the_heap_walks_toward_red_when_she_is_far() -> void:
	await _setup(Vector3(0, 0.02, 100))
	var before: float = _mech.global_position.z
	await _frames(120)
	assert_gt(_mech.global_position.z, before + 10.0, "16 m/s toward her")


# ---- the sounds ----

func test_the_boss_sounds_play_through_the_audio_manager_and_unknown_ones_stay_quiet() -> void:
	var audio: Node = tree.root.get_node_or_null("AudioManager")
	if audio == null:
		return
	BossSfx.play(&"mech_roar")
	assert_eq(audio.get("last_sfx_id"), &"mech_roar")
	BossSfx.play(&"not_a_sound_id")
	assert_eq(audio.get("last_sfx_id"), &"mech_roar", "an unknown id is skipped")
	for id: StringName in [&"boss_stomp_windup", &"boss_stomp_ring", &"boss_sweep_line", &"boss_sweep_beam", &"boss_drone_drop", &"boss_quiet_hours",
			&"boss_quiet_hours_cut", &"boss_relay_break", &"boss_topple", &"boss_jack_in", &"mech_sting_windup", &"mech_sting_lock", &"mech_swing",
			&"mech_slam", &"mech_barrage", &"mech_plate_break", &"mech_core_hit", &"mech_core_alarm", &"mech_defeat"]:
		assert_true(bool(audio.call("has_sfx", id)), "%s is registered" % id)


# ---- the fight around it: phases, bar, repair cells ----

func test_phase_2_builds_the_heap_shows_the_bar_with_pips_and_sets_the_retry_point() -> void:
	_kit = BossKit.new(self)
	await _kit.arena(true)
	var pips: Array[Vector2i] = []
	_kit.director.boss_pips_changed.connect(func(standing: int, total: int) -> void: pips.append(Vector2i(standing, total)))
	var shown: Array[Dictionary] = []
	_kit.director.boss_bar_shown.connect(func(info: Dictionary) -> void: shown.append(info))
	_kit.fight.skip_phase()
	await _kit.frames(3)
	assert_eq(_kit.fight.phase_id(), &"mech")
	assert_not_null(_kit.fight.heap)
	_kit.fight.heap.set_physics_process(false)
	assert_eq(shown.size(), 1)
	assert_eq(shown[0]["hp_max"], 10000.0)
	assert_eq(shown[0]["phase"], 1)
	assert_has(pips, Vector2i(4, 4))
	assert_eq(_kit.room.checkpoints.back(), {"spawn": "retry_phase2", "form": &"huge", "full_health": true})


func test_a_retry_at_phase_2_starts_the_heap_straight_away() -> void:
	_kit = BossKit.new(self)
	await _kit.arena(false)
	await _kit.begin(3, "retry_phase2")
	assert_eq(_kit.fight.phase_id(), &"mech")
	assert_not_null(_kit.fight.heap)
	_kit.fight.heap.set_physics_process(false)
	assert_null(_kit.fight.hushmaster, "no Hushmaster in a phase 2 retry")


func test_defeating_the_heap_ends_the_fight_and_sets_slice_done() -> void:
	_kit = BossKit.new(self)
	await _kit.arena(false)
	await _kit.begin(3, "retry_phase2")
	var heap: JunkMech = _kit.fight.heap
	heap.set_physics_process(false)
	var finished: Array[bool] = []
	_kit.fight.fight_finished.connect(func() -> void: finished.append(true))
	var state: Node = tree.root.get_node_or_null("GameState")
	heap._on_part_broken(&"core")
	for i: int in range(400):
		await tree.physics_frame
		_kit.director.tick(DT)
		heap.tick(DT)
	assert_eq(finished.size(), 1)
	if state != null:
		assert_true(bool(state.call("has_flag", "slice_done")))
		state.call("set_flag", "slice_done", false)


func _fake_yard(count: int) -> Array[SmashProp]:
	var props: Array[SmashProp] = []
	for i: int in range(count):
		var prop: SmashProp = SmashProp.new()
		prop.setup(StringName("box_%d" % i), &"container", {"aabb_size": [6.0, 3.0, 12.0], "aabb_pos": [-3.0, 0.0, -6.0], "hp": 20}, null)
		_kit.room.add_child(prop)
		var angle: float = TAU * float(i) / float(count)
		prop.global_position = Vector3(sin(angle), 0.0, cos(angle)) * 60.0
		props.append(prop)
	return props


class FakeYard extends RefCounted:
	var props: Array[SmashProp] = []


class FakeStage extends RefCounted:
	var yard: FakeYard = FakeYard.new()


func test_repair_cells_sit_in_marked_containers_and_a_smashed_one_heals_the_colossus_12_percent() -> void:
	_kit = BossKit.new(self)
	await _kit.arena(false)
	var stage: FakeStage = FakeStage.new()
	stage.yard.props = _fake_yard(20)
	_kit.room.set_meta("robot_stage", stage)
	await _kit.begin(3, "retry_phase2")
	_kit.fight.heap.set_physics_process(false)
	assert_eq(_kit.fight.repair_cells.size(), 0, "no stage on the stub room, so nothing is placed yet")
	_kit.fight.room = _kit.room
	var holder: Node3D = _kit.room
	# place by hand against the fake yard
	var fight: BossFight = _kit.fight
	var yard_props: Array[SmashProp] = stage.yard.props
	fight.repair_cells.clear()
	var entry: Dictionary = {"prop": yard_props[0], "position": yard_props[0].global_position, "taken": false, "released": false}
	fight.repair_cells.append(entry)
	yard_props[0].smashed.connect(func(_p: SmashProp) -> void: fight._release_cell(entry))
	fight._mark_container(yard_props[0], fight.heap_doc["pickups"]["repair_cell"])
	assert_not_null(yard_props[0].find_child("*", true, false), "the container carries a marker")
	_kit.red.hp_max = 6000
	_kit.red.hp = 3000
	_kit.red.global_position = yard_props[0].global_position + Vector3(0, 0.02, 0)
	fight._tick_repair_cells()
	assert_eq(_kit.red.hp, 3000, "still sealed in the container")
	yard_props[0].apply_hit({"damage": 999, "outcome": &"hit"})
	assert_true(bool(entry["released"]), "smashed: the cell is out")
	fight._tick_repair_cells()
	assert_eq(_kit.red.hp, 3720, "12 percent of 6000")
	assert_true(bool(entry["taken"]))
	fight._tick_repair_cells()
	assert_eq(_kit.red.hp, 3720, "one cell, one heal")
	assert_not_null(holder)
