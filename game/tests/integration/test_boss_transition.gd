extends TestCase
## VS-30: the boss phase change (docs/slice/boss_design.md "Transition"): Kasp escapes up a crane cage, the cranes pour the Heap,
## Red (in control) runs to the loader and boards, the loader drives the ring road, the colossus wakes and steps to its dock spot,
## the CS-21 docking switches the scale mid-scene, and Red cannot be hurt the whole time. Per-phase retry: a knock-out in phase 2
## restarts already docked at full health. BossFight (VS-26/27) is not in yet, so a small stub plays its part: it calls begin() and
## starts "phase 2" on `finished`. The arena's markers are built in code with the names the Level Designer's scene must have.

const ROOMS_ID: String = "slice/graybox_rooms"
const PLACEMENTS_ID: String = "slice/graybox_placements"
const DT: float = 1.0 / 60.0

var _kit: RobotStageKit = null
var _trans: BossTransition = null
var _fight: StubFight = null
var _state: Node = null
var _main: Main = null
var _router: Node = null


## What BossFight does at the phase change, as little as it needs to: call begin() and take over on `finished`.
class StubFight extends RefCounted:
	var phase: int = 1
	var steps: Array[StringName] = []
	var radio: Array[String] = []
	var pours: Array[StringName] = []

	func hook(transition: BossTransition) -> void:
		transition.step_started.connect(func(step: StringName) -> void: steps.append(step))
		transition.radio_said.connect(func(_who: String, text: String) -> void: radio.append(text))
		transition.crane_poured.connect(func(id: StringName) -> void: pours.append(id))
		transition.finished.connect(func() -> void: phase = 2)


class FakeMech extends Node3D:
	var progress: Array[float] = []

	func set_assemble_progress(t: float) -> void:
		progress.append(t)


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_router = tree.root.get_node("SceneRouter")
	_state.call("reset")


func after_each() -> void:
	if _main != null and is_instance_valid(_main):
		_main.apply_mode(GameMode.Mode.CLASSIC)
	_main = null
	_router.set("main", null)
	_router.set("instant", false)
	_router.set("current_room_id", "")
	_router.set("pending_room_id", "")
	_router.set("rooms_id", "world/rooms")
	_state.set("rooms_data_id", "world/rooms")
	_state.call("reset")
	Placements.extra_ids = [] as Array[String]
	Placements.extra_job_ids = [] as Array[String]
	InputSorting.revert()
	for node: Node in tree.get_nodes_in_group(ActionRoom.GROUP_HUD):
		node.remove_from_group(ActionRoom.GROUP_HUD)
		node.queue_free()


func _arena_data() -> Dictionary:
	return {"ground": false, "small_robot": {"pos": [8.0, 0.0, 56.0], "yaw_deg": 180.0},
			"huge_robot": {"pos": [105.0, 0.0, 0.0], "yaw_deg": -90.0}, "props": []}


func _marker(name: String, at: Vector3, parent: Node3D = null) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = name
	(parent if parent != null else _kit.host).add_child(node)
	node.global_position = at
	return node


## The arena's named nodes, as docs/maps/kasp_arena.md lists them.
func _markers(with_road: bool = true) -> void:
	_marker("hushmaster_start", Vector3(0, 0, 0))
	_marker("kasp_escape_target", Vector3(0, 0, -19))
	_marker("mech_start", Vector3(0, 0, -110))
	_marker("crane_a", Vector3(-60, 0, -95))
	_marker("crane_b", Vector3(0, 0, -95))
	_marker("crane_c", Vector3(60, 0, -95))
	var gate: Node3D = _marker("stockade_e_gate", Vector3(62, 0, 0))
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	gate.add_child(body)
	var parked: Node3D = _marker("loader_parked", Vector3(8, 0, 56))
	parked.rotation.y = PI
	_marker("colossus_cradle", Vector3(105, 0, 0))
	_marker("colossus_dock_pos", Vector3(84, 0, 0))
	_marker("dock_approach", Vector3(68.2, 0, 0))
	if with_road:
		var road: Node3D = _marker("ring_road", Vector3.ZERO)
		_marker("ring_a", Vector3(40, 0, 56), road)
		_marker("ring_b", Vector3(70, 0, 40), road)
		_marker("ring_c", Vector3(70, 0, 12), road)


func _boot(with_road: bool = true, red_at: Vector3 = Vector3(0, 0.02, 0)) -> void:
	_kit = RobotStageKit.new(self)
	await _kit.boot(_arena_data(), red_at)
	_markers(with_road)
	_trans = BossTransition.new()
	_trans.run_on_physics = false
	_kit.host.add_child(_trans)
	assert_true(_trans.setup(_kit.host, _kit.stage, _kit.player, DataDB.get_dict(BossTransition.DATA_ID)))
	_fight = StubFight.new()
	_fight.hook(_trans)


func _run(frames: int) -> void:
	for i: int in frames:
		_trans.tick(DT)
		_kit.step(1)


func _run_until(condition: Callable, limit: int = 1800) -> int:
	var count: int = 0
	while not bool(condition.call()) and count < limit:
		_run(1)
		count += 1
	return count


## Red runs to the loader (the player's part of the board_loader step) by being put at its boarding ring.
func _walk_to_loader() -> void:
	var ring: Vector3 = _kit.stage.yard.small_display.boarding_point()
	_kit.player.global_position = Vector3(ring.x, 0.02, ring.z)
	_kit.player.velocity = Vector3.ZERO


# ---- the data ----

func test_the_transition_data_names_every_marker_the_arena_must_have() -> void:
	var cfg: Dictionary = DataDB.get_dict(BossTransition.DATA_ID)
	var markers: Dictionary = cfg["markers"]
	for role: String in ["rig_start", "kasp_target", "mech_start", "cranes", "cage_crane", "gate", "loader", "ring_road", "cradle", "dock_pos", "dock_approach"]:
		assert_true(markers.has(role), role)
	assert_eq((markers["cranes"] as Array).size(), 3, "three yard cranes")
	assert_eq((cfg["mech_assemble"]["pours_at_s"] as Array).size(), 3, "one pour each")
	var total: float = 0.0
	for key: String in ["throw_s", "run_s", "lift_s"]:
		total += float(cfg["kasp_escape"][key])
	assert_almost_eq(total, 4.0, 0.01, "kasp_escape is about 4 s")
	assert_almost_eq(float(cfg["mech_assemble"]["duration_s"]), 8.0, 0.01, "mech_assemble is about 8 s")
	assert_true(bool(cfg["invulnerable"]), "Red cannot be hurt")
	var arena: Dictionary = DataDB.get_dict("slice/robot_rooms/kasp_arena")
	assert_true(arena.has("small_robot") and arena.has("huge_robot"), "the arena has the loader and the colossus")
	assert_eq((arena["huge_robot"] as Dictionary)["yaw_deg"], -90.0, "the colossus faces west")


# ---- starting ----

func test_it_refuses_to_start_unless_red_is_on_foot_and_only_once() -> void:
	await _boot()
	_kit.stage.place_in(&"small")
	assert_false(_trans.begin(), "not from inside the loader")
	_kit.stage.place_in(&"red")
	assert_true(_trans.begin())
	assert_false(_trans.begin(), "not twice")
	assert_true(_trans.is_running())
	assert_eq(_trans.step_name(), &"kasp_escape")


# ---- kasp_escape ----

func test_kasp_is_thrown_from_the_seat_and_rides_a_crane_cage_up_while_red_keeps_control() -> void:
	await _boot()
	_trans.begin()
	var kasp: Node3D = _trans.kasp
	assert_not_null(kasp, "a stand-in Kasp when BossFight gives none")
	assert_almost_eq(kasp.global_position.y, 2.5, 0.01, "in the seat")
	_kit.player.set_move_input(Vector2(0, -1))
	var start: Vector3 = _kit.player.global_position
	_run(60)
	assert_gt(start.distance_to(_kit.player.global_position), 1.0, "Red runs while he escapes: she has control")
	_kit.player.set_move_input(Vector2.ZERO)
	assert_eq(_kit.player.get_control_mode(), ActionPlayer.ControlMode.NORMAL)
	_run(85)
	assert_lt(kasp.global_position.distance_to(Vector3(0, 0, -19)), 2.0, "on the ground at the escape point after the throw and run")
	_run_until(func() -> bool: return _trans.step == BossTransition.Step.MECH_ASSEMBLE, 400)
	assert_eq(_trans.step_name(), &"mech_assemble")
	assert_gt(kasp.global_position.y, 40.0, "up the cage")
	assert_false(kasp.visible, "and out of sight, in the Heap's cab")
	assert_between_s(_trans.kasp_duration_s(), 3.5, 4.5)


func assert_between_s(value: float, low: float, high: float) -> void:
	assert_ge(value, low)
	assert_le(value, high)


# ---- mech_assemble ----

func test_the_three_cranes_pour_in_turn_the_heap_rises_the_gate_opens_and_vela_barks() -> void:
	await _boot()
	var mech: FakeMech = FakeMech.new()
	_kit.host.add_child(mech)
	_trans.mech = mech
	_trans.begin()
	_run_until(func() -> bool: return _trans.step == BossTransition.Step.MECH_ASSEMBLE, 600)
	_run(30)
	assert_eq(_fight.radio.back(), "Get to the loader.", "the bark when the pour starts")
	assert_eq(_fight.pours, [&"crane_a"] as Array[StringName], "crane A first")
	_run(120)
	assert_eq(_fight.pours, [&"crane_a", &"crane_b", &"crane_c"] as Array[StringName], "then B then C")
	var gate: Node3D = _kit.host.find_child("stockade_e_gate", true, false) as Node3D
	assert_true(gate.visible, "the gate is still shut while the cranes pour")
	_run_until(func() -> bool: return _trans.step == BossTransition.Step.BOARD_LOADER, 900)
	assert_eq(_trans.step_name(), &"board_loader")
	assert_false(gate.visible, "crane B lifts the east barricade away")
	assert_gt(mech.progress.size(), 100, "the Heap was told every frame")
	assert_eq(mech.progress[0], 0.0)
	assert_eq(mech.progress.back(), 1.0, "and ends fully assembled")
	for i: int in range(1, mech.progress.size()):
		assert_ge(mech.progress[i], mech.progress[i - 1], "never goes backwards")


func test_without_a_mech_a_stand_in_heap_grows() -> void:
	await _boot()
	_trans.begin()
	_run_until(func() -> bool: return _trans.step == BossTransition.Step.MECH_ASSEMBLE, 600)
	_run(240)
	var heap: Node3D = _kit.host.get_node_or_null("HeapStandIn") as Node3D
	assert_not_null(heap)
	assert_gt(heap.scale.y, 10.0, "rising")
	assert_lt(heap.scale.y, 40.0)
	assert_almost_eq(heap.global_position.z, -110.0, 0.01, "at mech_start")


# ---- board_loader ----

func test_the_boarding_step_waits_for_red_as_long_as_it_takes_and_re_parks_the_loader() -> void:
	await _boot()
	_kit.stage.yard.small_display.global_position = Vector3(30, 0, 30)        # she climbed out of the J5 loader somewhere else
	_trans.begin()
	_run_until(func() -> bool: return _trans.step == BossTransition.Step.BOARD_LOADER, 1200)
	assert_lt(_kit.stage.yard.small_display.global_position.distance_to(Vector3(8, 0, 56)), 0.1, "the loader is at loader_parked")
	_run(600)
	assert_eq(_trans.step_name(), &"board_loader", "no timer: ten seconds later she is still on foot")
	assert_eq(_kit.stage.form(), &"red")
	_walk_to_loader()
	_run_until(func() -> bool: return _kit.stage.form() == &"small", 900)
	assert_eq(_kit.stage.form(), &"small", "she climbed in by the normal boarding")
	_run_until(func() -> bool: return _trans.step == BossTransition.Step.DRIVE, 300)
	assert_eq(_trans.step_name(), &"drive")


# ---- the whole thing ----

func test_the_whole_transition_ends_with_red_in_the_colossus_and_she_is_never_hurt() -> void:
	await _boot()
	var full: int = _kit.player.hp
	var vulnerable_frames: int = 0
	_trans.begin()
	var forms_seen: Array[StringName] = []
	var step_log: Array[StringName] = []
	for i: int in 6000:
		_run(1)
		if _trans.is_running() and not _kit.player.is_invulnerable():
			vulnerable_frames += 1
		if forms_seen.is_empty() or forms_seen.back() != _kit.stage.form():
			forms_seen.append(_kit.stage.form())
		if step_log.is_empty() or step_log.back() != _trans.step_name():
			step_log.append(_trans.step_name())
		if _trans.step == BossTransition.Step.BOARD_LOADER and _kit.stage.form() == &"red" and _trans._t > 0.5:
			_walk_to_loader()
		if _trans.is_done():
			break
	assert_true(_trans.is_done(), "finished")
	assert_eq(_fight.phase, 2, "the stub BossFight started phase 2 on `finished`")
	assert_eq(vulnerable_frames, 0, "Red cannot be hurt the whole time")
	assert_eq(_kit.player.hp, _kit.player.hp_max, "and she is at full colossus health")
	assert_eq(_fight.steps, [&"kasp_escape", &"mech_assemble", &"board_loader", &"drive", &"dock_colossus"] as Array[StringName])
	assert_eq(forms_seen, [&"red", &"small", &"huge"] as Array[StringName], "the scale switches red, then small, then huge")
	assert_eq(_kit.stage.mode(), RobotBoarding.Mode.HUGE)
	assert_eq(_kit.player.get_form_id(), &"huge")
	assert_eq(_kit.player.get_control_mode(), ActionPlayer.ControlMode.NORMAL, "control returns in the colossus")
	assert_false(_kit.player.input_locked)
	var huge: RobotDisplay = _kit.stage.yard.huge_display
	assert_lt(huge.global_position.distance_to(Vector3(84, 0, 0)), 0.1, "the colossus stands at colossus_dock_pos")
	assert_false(huge.is_active(), "and Red is wearing it")
	assert_lt(full - _kit.player.hp, 1, "unhurt")
	_kit.player.hp = 1
	_run(30)
	assert_false(_trans.is_running(), "the invulnerability is only for the sequence")


func test_the_docking_takes_the_cs21_four_and_a_half_seconds_and_the_scale_switches_inside_it() -> void:
	await _boot()
	_trans.begin()
	_run_until(func() -> bool: return _trans.step == BossTransition.Step.BOARD_LOADER, 1200)
	_walk_to_loader()
	_run_until(func() -> bool: return _trans.step == BossTransition.Step.DRIVE, 900)
	assert_eq(_kit.stage.form(), &"small")
	var drive_frames: int = _run_until(func() -> bool: return _trans.step == BossTransition.Step.DOCK_COLOSSUS, 2400)
	assert_between_s(float(drive_frames) * DT, 6.0, 13.0)
	assert_eq(_kit.stage.form(), &"small", "still the loader at the end of the drive")
	var dock_frames: int = 0
	var swapped_at: int = -1
	while not _trans.is_done() and dock_frames < 900:
		_run(1)
		dock_frames += 1
		if swapped_at < 0 and _kit.stage.form() == &"huge":
			swapped_at = dock_frames
	assert_between_s(float(dock_frames) * DT, 4.0, 5.2)
	assert_gt(swapped_at, 0)
	assert_lt(swapped_at, dock_frames, "the switch happens inside the sequence, before control returns")
	assert_between_s(float(swapped_at) * DT, 3.0, 4.2)


func test_the_ring_road_can_be_skipped_and_a_scene_without_road_markers_still_works() -> void:
	await _boot(false)
	_trans.begin()
	_run_until(func() -> bool: return _trans.step == BossTransition.Step.BOARD_LOADER, 1200)
	_walk_to_loader()
	_run_until(func() -> bool: return _trans.step == BossTransition.Step.DRIVE, 900)
	_run(30)
	_trans.skip_drive()
	_run(2)
	assert_eq(_trans.step_name(), &"dock_colossus", "skipped to the dock")
	_run_until(func() -> bool: return _trans.is_done(), 900)
	assert_true(_trans.is_done())
	assert_eq(_kit.stage.form(), &"huge")


# ---- retry per phase ----

func test_a_phase_two_restart_starts_already_docked_with_no_sequence() -> void:
	await _boot()
	var finished: Array[bool] = []
	_trans.finished.connect(func() -> void: finished.append(true))
	assert_true(_trans.start_docked(), "the retry path")
	assert_eq(_kit.stage.form(), &"huge")
	assert_eq(_kit.stage.mode(), RobotBoarding.Mode.HUGE)
	assert_true(_trans.is_done())
	assert_eq(finished.size(), 0, "no `finished`: BossFight starts phase 2 itself")
	assert_lt(_kit.stage.yard.huge_display.global_position.distance_to(Vector3(84, 0, 0)), 0.1)
	var gate: Node3D = _kit.host.find_child("stockade_e_gate", true, false) as Node3D
	assert_false(gate.visible, "the gate is already open")
	assert_false(_trans.is_running())
	assert_false(_kit.stage.yard.small_display.is_active() and _kit.stage.yard.huge_display.is_active(), "nothing parked: she is the colossus")


# ---- inside a real room ----

func _start_room(room_id: String) -> void:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate() as Main
	_main.show_title = false
	_main.debug_overlay_enabled = false
	_main.sandbox_boot_enabled = false
	add_to_root(_main)
	_main.apply_mode(GameMode.Mode.SLICE)
	_router.set("rooms_id", ROOMS_ID)
	_router.set("main", _main)
	_router.set("instant", true)
	_state.set("rooms_data_id", ROOMS_ID)
	Placements.extra_ids = [PLACEMENTS_ID] as Array[String]
	Placements.extra_job_ids = ["slice/graybox_jobs"] as Array[String]
	_main.start_new_game()
	await _until_room("gb_hub")
	_router.call("go_to", room_id, "from_hub")
	await _until_room(room_id)


func _until_room(room_id: String, limit: int = 160) -> void:
	for i: int in limit:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room.room_id == room_id and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			return
	fail("never reached %s" % room_id)


func _until_replaced(old: ActionRoom, limit: int = 200) -> void:
	for i: int in limit:
		await tree.physics_frame
		var room: ActionRoom = _main.get_room() as ActionRoom
		if room != null and room != old and not bool(_router.call("is_busy")) and room.hero != null:
			await tree.physics_frame
			await tree.physics_frame
			return
	fail("the room was never replaced")


func _kill(hero: ActionPlayer) -> void:
	hero.apply_hit({"outcome": "hit", "damage": 99999, "hitstun_ms": 100.0, "knockback": Vector3.ZERO, "launch_mps": 0.0, "poise_after": 0.0})


func test_a_knock_out_in_phase_two_restarts_in_the_colossus_at_full_health() -> void:
	await _start_room("gb_arena")
	var room: ActionRoom = _main.get_room() as ActionRoom
	assert_eq(room.get_form(), &"red")
	# phase 1 has started: the retry point is the room's entrance (health and battery as she walked in)
	room.set_phase_checkpoint("from_hub", &"red", false)
	room.hero.hp = 40
	_kill(room.hero)
	assert_true(room.continue_after_knockout())
	await _until_replaced(room)
	var again: ActionRoom = _main.get_room() as ActionRoom
	assert_eq(again.get_form(), &"red", "a phase 1 death restarts on foot")
	assert_gt(again.hero.hp, 40, "with the health she walked in with, not the 40 she died with")
	# phase 2 has begun: the retry point is the colossus, docked, at full health
	again.set_phase_checkpoint("from_vault", &"huge")
	again.get_robot_stage().place_in(&"huge")
	again.hero.hp = 100
	_kill(again.hero)
	assert_true(again.continue_after_knockout())
	await _until_replaced(again)
	var third: ActionRoom = _main.get_room() as ActionRoom
	assert_eq(third.room_id, "gb_arena")
	assert_eq(third.get_form(), &"huge", "restarts already docked")
	assert_eq(third.hero.get_form_id(), &"huge")
	assert_eq(third.get_robot_stage().mode(), RobotBoarding.Mode.HUGE, "no boarding to replay")
	assert_eq(third.hero.hp, third.hero.hp_max, "full colossus health")
	assert_false(third.hero.dead)
	assert_eq(str(_router.get("current_spawn_id")), "from_vault", "through the retry spawn")
	# the new room is itself a checkpoint, so a second defeat lands in the same place
	_kill(third.hero)
	assert_true(third.continue_after_knockout())
	await _until_replaced(third)
	assert_eq((_main.get_room() as ActionRoom).get_form(), &"huge")


func test_clearing_the_phase_checkpoint_goes_back_to_the_room_entrance() -> void:
	await _start_room("gb_arena")
	var room: ActionRoom = _main.get_room() as ActionRoom
	room.set_phase_checkpoint("from_vault", &"huge")
	assert_eq(room.continue_target()["spawn"], "from_vault")
	room.clear_phase_checkpoint()
	assert_eq(room.continue_target()["spawn"], "from_hub", "the entrance she walked in by")
