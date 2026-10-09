extends TestCase
## VS-19: the world hack targets (docs/slice/slice_tech_plan.md 4.5 and 5.2): the HackTarget base, the fuse-box door, the terminal,
## the crane, the drone line and its power node. The real Zap Drone, EMP and Overclock are cast at them through HackKit; the
## timing-heavy parts (the crane's job order, the drone line's clock) are stepped by hand. Sticky flags are checked through a
## save and a reload.

var _state: Node = null
var _kit: HackKit = null


class Breakable extends Node3D:
	var smashed: int = 0

	func smash() -> void:
		smashed += 1


class FakeDrone extends Node3D:
	var dead: bool = false


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")
	Placements.extra_ids = ["slice/placements"] as Array[String]


func after_each() -> void:
	_state.call("reset")
	Placements.extra_ids = [] as Array[String]


func _flag(id: String) -> bool:
	return bool(_state.call("get_flag", id))


func _add(node: HackTarget, id: String, info: Dictionary, at: Vector3 = Vector3.ZERO) -> HackTarget:
	node.target_id = StringName(id)
	node.data = info
	node.position = at                      # before it enters the tree, as a scene node would be
	add_to_root(node)
	return node


func _save_and_reload() -> void:
	var saved: Dictionary = _state.call("to_dict") as Dictionary
	_state.call("reset")
	_state.call("from_dict", saved)


# ---- the base ----

func test_a_target_joins_the_hack_and_lock_on_groups_and_answers_the_hack_interface() -> void:
	var target: HackTarget = _add(HackTarget.new(), "t1", {"accepts": ["zap", "emp"], "aim_height_m": 2.0}, Vector3(1, 0, 3))
	assert_true(target.is_in_group(&"hack_targets"), "ZapDrone and EmpPulse look here")
	assert_true(target.is_in_group(&"lock_targets"), "lock-on reaches it")
	assert_true(target.can_take(&"zap"))
	assert_true(target.can_take(&"emp"))
	assert_false(target.can_take(&"overclock"))
	assert_false(target.can_take(&"interact"))
	assert_eq(target.aim_point(), Vector3(1, 2, 3))
	assert_eq(target.flag_id(), "hack_t1_done", "the default flag name")


func test_a_hack_it_accepts_finishes_it_sets_the_flag_and_takes_it_off_the_lock_list() -> void:
	var target: HackTarget = _add(HackTarget.new(), "t2", {"accepts": ["zap"], "flag": "t2_open"})
	var seen: Array[StringName] = []
	target.hacked.connect(func(_id: StringName, hack: StringName) -> void: seen.append(hack))
	var finished: Array[StringName] = []
	target.completed.connect(func(id: StringName) -> void: finished.append(id))
	assert_false(target.take_hack(&"emp", {}), "a hack it does not accept does nothing")
	assert_false(_flag("t2_open"))
	assert_true(target.take_hack(&"zap", {}))
	assert_eq(seen, [&"zap"] as Array[StringName])
	assert_eq(finished, [&"t2"] as Array[StringName])
	assert_true(_flag("t2_open"), "the sticky flag is in GameState")
	assert_true(target.is_done())
	assert_false(target.can_take(&"zap"), "spent")
	assert_false(target.take_hack(&"zap", {}), "and a second zap does nothing")
	assert_false(target.is_in_group(&"lock_targets"), "lock-on moves on")
	assert_true(target.is_in_group(&"hack_targets"))


func test_a_sticky_target_is_still_done_after_a_save_and_a_reload() -> void:
	var first: HackTarget = _add(HackTarget.new(), "t3", {"accepts": ["zap"], "flag": "t3_open", "sticky": true})
	first.take_hack(&"zap", {})
	first.free()
	_save_and_reload()
	assert_true(_flag("t3_open"), "the flag came back from the save")
	var again: HackTarget = _add(HackTarget.new(), "t3", {"accepts": ["zap"], "flag": "t3_open", "sticky": true})
	assert_true(again.is_done())
	assert_false(again.can_take(&"zap"))
	assert_false(again.is_in_group(&"lock_targets"), "a hacked target is not offered to the lock-on again")


func test_a_target_that_is_not_sticky_is_done_for_this_visit_only() -> void:
	var first: HackTarget = _add(HackTarget.new(), "t4", {"accepts": ["zap"], "flag": "t4_open", "sticky": false})
	first.take_hack(&"zap", {})
	assert_true(first.is_done())
	assert_false(_flag("t4_open"), "no flag written")
	first.free()
	var again: HackTarget = _add(HackTarget.new(), "t4", {"accepts": ["zap"], "flag": "t4_open", "sticky": false})
	assert_false(again.is_done(), "a new visit finds it fresh")
	assert_true(again.can_take(&"zap"))


func test_the_junkyard_placements_build_every_kind_and_the_flags_agree_with_the_robot_room() -> void:
	var section: Dictionary = Placements.section(HackTarget.SECTION)
	var classes: Dictionary = {"fuse_door": HackDoor, "terminal": HackTerminal, "crane": HackCrane, "drone_line": DroneLine, "loader": HackLoader}
	var count: int = 0
	for id: String in section:
		if id.begins_with("_"):
			continue
		var info: Dictionary = section[id]
		assert_true(classes.has(str(info.get("kind", ""))), "%s has a known kind" % id)
		var node: HackTarget = (classes[str(info["kind"])] as GDScript).new() as HackTarget
		node.target_id = StringName(id)
		add_to_root(node)
		assert_eq(node.accepts, PackedStringArray(info["accepts"]), "%s accepts what the data says" % id)
		if info.has("flag"):
			assert_eq(node.flag_id(), str(info["flag"]))
			assert_true(bool(info.get("sticky", true)), "%s is sticky" % id)
		count += 1
	assert_ge(count, 6, "J1 fuse door, J2 terminal, J3 crane, drone line, vault door and the J4 loader")
	var j4: Dictionary = DataDB.get_dict("slice/robot_rooms/junk_j4")
	assert_eq(str((j4["small_robot"] as Dictionary)["wake_flag"]), str((section["loader_j4"] as Dictionary)["flag"]),
			"the loader's wake button and the sleeping loader name the same flag")


func test_a_knock_out_restart_keeps_every_hack_target_flag() -> void:
	var room: ActionRoom = own(ActionRoom.new()) as ActionRoom
	var ids: Array = room.sticky_ids()
	for flag: String in ["hack_j1_door_open", "term_j2_gate_open", "crane_j3_done", "hack_j3_bridge_placed", "hack_j3_vault_wall_hit",
			"dline_j3_dead", "hack_j3_vault_open", "loader_awake"]:
		assert_has(ids, flag, "%s survives a retry" % flag)


# ---- the fuse-box door ----

func _door(info: Dictionary = {}) -> HackDoor:
	var cfg: Dictionary = {"accepts": ["zap"], "flag": "door_open", "slab": {"size": [3.0, 3.0, 0.4], "offset": [0.0, 0.0, 2.0]}, "open_s": 1.0}
	cfg.merge(info, true)
	return _add(HackDoor.new(), "fuse1", cfg, Vector3(0, 0, 6)) as HackDoor


func test_zapping_the_fuse_box_slides_the_door_up_and_switches_off_its_collision() -> void:
	var door: HackDoor = _door()
	assert_true(door.has_blocker())
	var body: StaticBody3D = door.slab as StaticBody3D
	var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
	assert_false(shape.disabled, "solid while the fuse box is untouched")
	var rest: float = body.position.y
	assert_true(door.take_hack(&"zap", {}))
	assert_true(_flag("door_open"))
	for i: int in 30:
		door.tick(1.0 / 60.0)
	assert_gt(body.position.y, rest, "on its way up")
	assert_lt(door.open_amount(), 1.0)
	for i: int in 40:
		door.tick(1.0 / 60.0)
	assert_eq(door.open_amount(), 1.0)
	assert_almost_eq(body.position.y, rest + 3.0, 0.01, "up by its own height")
	await tree.physics_frame
	assert_true(shape.disabled, "and you can walk through")


func test_a_fuse_door_zapped_in_an_earlier_visit_starts_open() -> void:
	_state.call("set_flag", "door_open", true)
	var door: HackDoor = _door()
	var body: StaticBody3D = door.slab as StaticBody3D
	assert_true(door.is_open())
	assert_eq(door.open_amount(), 1.0, "no show on the way in")
	assert_gt(body.position.y, 2.9)
	await tree.physics_frame
	assert_true((body.get_child(0) as CollisionShape3D).disabled)
	assert_false(door.is_in_group(&"lock_targets"))


func test_a_fuse_box_with_no_slab_just_sets_its_flag_for_a_door_placement_to_read() -> void:
	var box: HackDoor = _add(HackDoor.new(), "fuse2", {"accepts": ["zap"], "flag": "gate_open", "also_flags": ["bark_done"]}) as HackDoor
	assert_false(box.has_blocker())
	box.take_hack(&"zap", {})
	assert_true(_flag("gate_open"), "a Door with requires.flag gate_open opens by this")
	assert_true(_flag("bark_done"), "also_flags are set too")


func test_a_real_zap_drone_opens_a_fuse_box_in_its_path() -> void:
	_kit = HackKit.new(self)
	await _kit.arena()
	var box: HackDoor = _add(HackDoor.new(), "fuse3", {"accepts": ["zap"], "flag": "zapped_open", "aim_height_m": 0.9}, Vector3(0, 0, 6)) as HackDoor
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return box.is_done(), 120)
	assert_true(box.is_done(), "the Zap Drone flew into it")
	assert_true(_flag("zapped_open"))
	assert_eq(_kit.casts.size(), 1, "one cast")


# ---- the terminal ----

func test_a_terminal_uses_the_button_sets_the_gate_flag_and_is_spent() -> void:
	var terminal: HackTerminal = _add(HackTerminal.new(), "term1", {"flag": "gate_open", "message": ["The gate unlatches."], "also_flags": ["j2_seen"]}) as HackTerminal
	assert_eq(terminal.accepts, PackedStringArray(["interact"]))
	assert_not_null(terminal.interactable, "the button finds an Interactable")
	assert_true(terminal.interactable.is_in_group(Interactable.GROUP))
	assert_false(terminal.is_in_group(&"lock_targets"), "you walk up to it; it is not aimed at")
	var used: Array[StringName] = []
	terminal.used.connect(func(id: StringName) -> void: used.append(id))
	assert_false(terminal.take_hack(&"zap", {}), "a zap does nothing to a terminal")
	assert_true(terminal.interactable.handler.call(null, null), "the Interactable's handler is the button")
	assert_true(_flag("gate_open"))
	assert_true(_flag("j2_seen"))
	assert_eq(terminal.last_messages, ["The gate unlatches."] as Array[String])
	assert_eq(used, [&"term1"] as Array[StringName])
	assert_true(terminal.is_done())
	assert_false(terminal.interactable.is_in_group(Interactable.GROUP), "spent: no prompt any more")
	assert_false(terminal.take_hack(&"interact", {}))


func test_a_terminal_that_is_not_once_can_be_used_again_and_can_start_a_scene() -> void:
	var terminal: HackTerminal = _add(HackTerminal.new(), "term2", {"flag": "lamp_on", "once": false, "scene": "intro_scene"}) as HackTerminal
	var scenes: Array[String] = []
	terminal.scene_requested.connect(func(id: String) -> void: scenes.append(id))
	assert_true(terminal.take_hack(&"interact", {}))
	assert_true(terminal.take_hack(&"interact", {}), "again")
	assert_eq(scenes, ["intro_scene", "intro_scene"] as Array[String])
	assert_false(terminal.is_done())
	assert_true(terminal.interactable.is_in_group(Interactable.GROUP))


# ---- the crane ----

func _crane(jobs: Array, info: Dictionary = {}) -> HackCrane:
	var cfg: Dictionary = {"accepts": ["overclock"], "jobs": jobs, "flag": "crane_done"}
	cfg.merge(info, true)
	return _add(HackCrane.new(), "crane1", cfg, Vector3(0, 0, 5)) as HackCrane


func _job(id: String, flag: String, path: Array, speed: float = 4.0, extra: Dictionary = {}) -> Dictionary:
	var job: Dictionary = {"id": id, "flag": flag, "speed_mps": speed, "cargo": {"size": [2.0, 0.5, 2.0]}, "path": path}
	job.merge(extra, true)
	return job


func test_a_crane_is_a_hijackable_lock_target_and_its_load_waits_at_the_start_of_the_path() -> void:
	var crane: HackCrane = _crane([_job("a", "a_done", [[0, 1, 9], [0, 1, 19]])])
	assert_not_null(crane.hijackable, "Overclock needs a Hijackable")
	assert_true(crane.hijackable.is_in_group(Hijackable.GROUP))
	assert_true(crane.is_in_group(&"lock_targets"))
	assert_eq(crane.current_job(), "a")
	assert_eq(crane.cargo_of("a").global_position, Vector3(0, 1, 9))
	assert_true(crane.hijackable.can_hijack(&"player"))


func test_a_real_overclock_carries_the_load_along_its_path_and_the_job_stays_done() -> void:
	_kit = HackKit.new(self)
	await _kit.arena()
	_kit.battery().reset_full()
	_kit.caster().select_slot(2)
	var crane: HackCrane = _crane([_job("a", "a_done", [[0, 1, 9], [0, 1, 13]], 4.0)])
	var done_jobs: Array[String] = []
	crane.job_done.connect(func(id: String, _at: Vector3) -> void: done_jobs.append(id))
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.until(func() -> bool: return crane.hijackable.is_hijacked(), 60)
	assert_true(crane.hijackable.is_hijacked(), "Overclock took the crane")
	assert_true(crane.is_moving())
	await _kit.until(func() -> bool: return crane.job_is_done("a"), 240)
	assert_true(crane.job_is_done("a"), "the load arrived")
	assert_eq(done_jobs, ["a"] as Array[String])
	assert_almost_eq(crane.cargo_of("a").global_position.z, 13.0, 0.01, "at the end of the path")
	assert_true(_flag("a_done"), "the job's flag is set")
	assert_true(_flag("crane_done"), "and the crane's, with no jobs left")
	assert_true(crane.is_done())
	assert_false(crane.hijackable.is_hijacked(), "the link lets go when the work is finished")
	assert_false(crane.is_in_group(&"lock_targets"))


func test_letting_go_early_stops_the_load_and_the_next_overclock_carries_on_from_there() -> void:
	var crane: HackCrane = _crane([_job("a", "a_done", [[0, 1, 9], [0, 1, 49]], 4.0)])
	assert_true(crane.on_hijack_begin(null, 10.0))
	for i: int in 300:                       # 5 s at 4 m/s = 20 m of 40
		crane._physics_process(1.0 / 60.0)
	assert_almost_eq(crane.job_progress("a"), 0.5, 0.01)
	crane.on_hijack_end()
	assert_false(crane.is_moving())
	crane.tick(1.0)                          # time passing alone does nothing... but tick moves it, so the hijack must gate the clock
	var held: float = crane.job_progress("a")
	crane._physics_process(1.0)
	assert_eq(crane.job_progress("a"), held, "not hijacked: the physics clock does not move it")
	assert_false(crane.job_is_done("a"))
	assert_false(_flag("a_done"))
	assert_true(crane.on_hijack_begin(null, 10.0), "a second Overclock")
	for i: int in 600:
		crane._physics_process(1.0 / 60.0)
	assert_true(crane.job_is_done("a"), "finished from where it stopped")
	assert_almost_eq(crane.cargo_of("a").global_position.z, 49.0, 0.01)


func test_the_jobs_go_in_order_and_the_second_smashes_what_is_near_where_the_load_lands() -> void:
	var wall: Breakable = Breakable.new()
	wall.add_to_group(&"crane_breakable")
	add_to_root(wall)
	wall.global_position = Vector3(20, 0, 0)
	var far_wall: Breakable = Breakable.new()
	far_wall.add_to_group(&"crane_breakable")
	add_to_root(far_wall)
	far_wall.global_position = Vector3(60, 0, 0)
	var crane: HackCrane = _crane([
		_job("bridge", "bridge_done", [[0, 1, 9], [0, 1, 11]]),
		_job("vault", "vault_hit", [[0, 1, 15], [20, 1, 2]], 6.0, {"smash": {"radius_m": 4.0}})])
	assert_eq(crane.current_job(), "bridge")
	crane.on_hijack_begin(null, 10.0)
	for i: int in 200:
		crane.tick(1.0 / 60.0)
		if crane.job_is_done("bridge"):
			break
	assert_true(crane.job_is_done("bridge"))
	assert_eq(crane.current_job(), "vault", "the second job is next")
	assert_false(crane.is_done())
	assert_true(crane.is_in_group(&"lock_targets"), "still something to do")
	assert_eq(wall.smashed, 0)
	for i: int in 400:
		crane.tick(1.0 / 60.0)
	assert_true(crane.job_is_done("vault"))
	assert_eq(wall.smashed, 1, "the wall at the landing point is smashed")
	assert_eq(far_wall.smashed, 0, "the one across the yard is not")
	assert_true(crane.is_done())


func test_a_crane_finished_in_an_earlier_visit_has_its_load_where_it_ended() -> void:
	_state.call("set_flag", "a_done", true)
	var crane: HackCrane = _crane([_job("a", "a_done", [[0, 1, 9], [0, 1, 19]])], {"flag": "crane_done"})
	assert_true(crane.job_is_done("a"))
	assert_true(crane.is_done())
	assert_eq(crane.current_job(), "")
	assert_eq(crane.cargo_of("a").global_position, Vector3(0, 1, 19), "the bridge is still across the pit")
	assert_false(crane.hijackable.can_hijack(&"player") and crane.hijack_allowed(), "nothing left to carry")
	assert_false(crane.on_hijack_begin(null, 10.0))


# ---- the drone line ----

class Spawns extends RefCounted:
	var made: Array[FakeDrone] = []
	var host: Node = null

	func make(_kind: String, at: Vector3) -> Node3D:
		var drone: FakeDrone = FakeDrone.new()
		host.add_child(drone)
		drone.global_position = at
		made.append(drone)
		return drone


func _line(info: Dictionary = {}) -> Array:
	var spawns: Spawns = Spawns.new()
	spawns.host = add_to_root(Node3D.new())
	var cfg: Dictionary = {"accepts": ["emp"], "flag": "line_dead", "interval_s": 6.0, "first_after_s": 5.0, "max_alive": 2,
			"emp_stops_s": 8.0, "zaps_needed": 2, "node_pos": [10.0, 5.0, 6.0]}
	cfg.merge(info, true)
	var line: DroneLine = DroneLine.new()
	line.run_on_physics = false
	line.spawner = spawns.make
	_add(line, "dline", cfg, Vector3(8, 0, 8))
	(line.power_node as DroneLine.PowerNode).rehit_frames = 0
	return [line, spawns]


func _run(line: DroneLine, seconds: float) -> void:
	for i: int in int(seconds * 60.0):
		line.tick(1.0 / 60.0)


func test_a_drone_line_sends_a_drone_every_few_seconds_and_never_more_than_two_at_once() -> void:
	var made: Array = _line()
	var line: DroneLine = made[0]
	var spawns: Spawns = made[1]
	_run(line, 4.9)
	assert_eq(spawns.made.size(), 0, "nothing before the first delay")
	_run(line, 0.3)
	assert_eq(spawns.made.size(), 1, "the first at 5 s")
	_run(line, 5.5)
	assert_eq(spawns.made.size(), 1, "the next waits for the interval")
	_run(line, 0.7)
	assert_eq(spawns.made.size(), 2, "the second at 11 s")
	_run(line, 30.0)
	assert_eq(spawns.made.size(), 2, "two alive is the limit")
	assert_eq(line.alive_count(), 2)
	spawns.made[0].dead = true
	_run(line, 7.0)
	assert_eq(spawns.made.size(), 3, "a dead drone makes room for the next")
	assert_eq(spawns.made[2].global_position, Vector3(8, 1.5, 9.5), "sent from the dispenser, a little in front and up")


func test_emp_on_the_dispenser_stops_the_line_for_eight_seconds_then_it_starts_again() -> void:
	var made: Array = _line({"first_after_s": 1.0})
	var line: DroneLine = made[0]
	var spawns: Spawns = made[1]
	_run(line, 1.1)
	assert_eq(spawns.made.size(), 1)
	assert_true(line.take_hack(&"emp", {}))
	assert_true(line.is_paused())
	assert_false(line.is_done(), "an EMP is a breather, not the end")
	assert_false(_flag("line_dead"))
	_run(line, 7.5)
	assert_eq(spawns.made.size(), 1, "silent while it is down")
	_run(line, 6.5)
	assert_false(line.is_paused())
	assert_eq(spawns.made.size(), 2, "and it starts sending again by itself")
	assert_true(line.is_in_group(&"lock_targets") or not line.lockable, "still a live line")


func test_a_real_emp_pulse_stops_a_drone_line_in_its_ring() -> void:
	_kit = HackKit.new(self)
	await _kit.arena()
	_kit.battery().set_charge(100.0)
	_kit.caster().select_slot(1)
	var made: Array = _line()
	var line: DroneLine = made[0]
	line.global_position = Vector3(0, 0, 2.5)
	await _kit.settle()
	await _kit.tap_hack()
	await _kit.frames(60)
	assert_eq(_kit.moves, [&"hack_emp"] as Array[StringName])
	assert_true(line.is_paused(), "the EMP's ring reached the dispenser")


func test_zapping_the_power_node_twice_ends_the_line_for_good_and_it_stays_dead() -> void:
	var made: Array = _line({"first_after_s": 1.0})
	var line: DroneLine = made[0]
	var spawns: Spawns = made[1]
	var node: HackTarget = line.power_node
	assert_eq(node.global_position, Vector3(10, 5, 6), "up on the roof")
	assert_true(node.is_in_group(&"lock_targets"), "a lock-on target")
	assert_true(node.can_take(&"zap"))
	assert_false(line.can_take(&"zap"), "the dispenser itself ignores a zap")
	assert_true(node.take_hack(&"zap", {}))
	assert_false(node.is_done(), "one zap is not enough")
	assert_false(line.is_done())
	assert_true(node.take_hack(&"zap", {}))
	assert_true(node.is_done())
	assert_true(line.is_done(), "the whole line is dead")
	assert_true(_flag("line_dead"))
	_run(line, 20.0)
	assert_eq(spawns.made.size(), 0, "no more drones")
	assert_false(line.take_hack(&"emp", {}), "nothing left to EMP")
	_save_and_reload()
	var again: Array = _line({"first_after_s": 1.0})
	var line2: DroneLine = again[0]
	_run(line2, 20.0)
	assert_eq((again[1] as Spawns).made.size(), 0, "still dead after a save and a reload")
	assert_true(line2.power_node.is_done())
	assert_false(line2.power_node.is_in_group(&"lock_targets"))


func test_one_pass_of_a_zap_drone_through_the_power_node_counts_once() -> void:
	var line: DroneLine = DroneLine.new()
	line.run_on_physics = false
	line.spawner = Spawns.new().make
	_add(line, "dline2", {"accepts": ["emp"], "flag": "line2_dead", "zaps_needed": 2}, Vector3(8, 0, 8))
	var node: DroneLine.PowerNode = line.power_node as DroneLine.PowerNode
	assert_true(node.take_hack(&"zap", {}))
	assert_false(node.take_hack(&"zap", {}), "the same pass, a frame later: ignored")
	assert_eq(node.hits, 1)
	assert_false(line.is_done())
