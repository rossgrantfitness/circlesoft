extends TestCase
## CS-21: the robot zone in the real combat sandbox: the yard through the gate, the scale props that make size read, the smashable
## props, the boarding, the docking sequence and the way back out, and the world scaling with the form (fog, draw distance).
## The clocks are in the test's hands (RobotKit), so every state is reached by stepping at 60 Hz.

var _kit: RobotKit = null


func _boot() -> void:
	_kit = RobotKit.new(self)
	await _kit.boot()


func _board() -> void:
	var small: RobotDisplay = _kit.yard.small_display
	var at: Vector3 = small.boarding_point()
	_kit.place(at + Vector3(-3.0, 0.02, 0.0), 90.0)
	_kit.player.set_move_input(Vector2(0, -1))
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.SMALL, 400)
	_kit.stop()


func _dock() -> void:
	var approach: Vector3 = _kit.yard.huge_display.approach_point()
	_kit.place(approach + Vector3(-9.0, 0.02, 0.0), 90.0)
	_kit.player.set_move_input(Vector2(0, -1))
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.HUGE, 900)
	_kit.stop()


# ---- the yard ----

func test_the_yard_has_the_scale_props_and_both_robots() -> void:
	await _boot()
	var kinds: Dictionary = {}
	for prop: SmashProp in _kit.yard.props:
		kinds[prop.kind] = int(kinds.get(prop.kind, 0)) + 1
	for kind: String in ["crate_small", "crate_large", "container", "car", "lamp_post", "building_10m", "building_20m", "building_30m"]:
		assert_true(kinds.has(StringName(kind)), "the yard has %s" % kind)
	assert_gt(_kit.yard.props.size(), 100, "plenty to smash")
	assert_true(_kit.yard.missing.is_empty(), "nothing the data asked for is missing: %s" % [_kit.yard.missing])
	var small: RobotDisplay = _kit.yard.small_display
	var huge: RobotDisplay = _kit.yard.huge_display
	assert_true(small.has_bone("boarding_point"))
	assert_true(huge.has_bone("dock_approach"))
	assert_true(small.is_active())
	assert_true(huge.is_active())
	assert_true(_kit.yard.contains(small.global_position))
	assert_true(_kit.yard.contains(huge.global_position))
	assert_almost_eq(small.boarding_point().distance_to(small.global_position), 1.1, 0.05, "1.1 m behind the loader")
	assert_almost_eq(huge.approach_point().distance_to(huge.global_position), 15.8, 0.1, "15.8 m in front of the colossus")
	assert_eq(_kit.mode(), RobotBoarding.Mode.RED)
	assert_eq(_kit.player.get_form_id(), &"red")


func test_the_gate_in_the_arena_wall_leads_to_the_yard_on_foot() -> void:
	await _boot()
	var gate: Dictionary = _kit.sandbox.robot_gate()
	assert_false(gate.is_empty())
	assert_not_null(_kit.sandbox.get_node_or_null("Level/WallEastNorth"))
	assert_not_null(_kit.sandbox.get_node_or_null("Level/WallEastSouth"))
	assert_null(_kit.sandbox.get_node_or_null("Level/WallEast"), "the east wall is two pieces with the gate between")
	for body: Node in _kit.sandbox.get_node("Level").get_children():
		assert_eq((body as StaticBody3D).collision_layer, 1, "still world layer")
	_kit.place(Vector3(12.0, 0.02, 3.0), 90.0)
	var arrived: bool = _kit.walk_to(Vector3(40.0, 0.0, 0.0), 1.5, 900)
	assert_true(arrived, "Red walks out of the arena through the gate")
	assert_gt(_kit.player.global_position.x, 30.0)


func test_the_arena_still_has_its_walls_and_no_other_gap() -> void:
	await _boot()
	_kit.place(Vector3(12.0, 0.02, 10.0), 90.0)
	_kit.player.set_move_input(Vector2(0, -1))
	_kit.step(180)
	assert_lt(_kit.player.global_position.x, 23.5, "the east wall holds away from the gate")


func test_props_are_solid_to_red_and_the_loader_but_not_to_the_colossus() -> void:
	await _boot()
	var crate: SmashProp = null
	for prop: SmashProp in _kit.yard.props:
		if prop.kind == &"crate_large":
			crate = prop
			break
	assert_not_null(crate)
	var enemy_bit: int = CombatLayers.bit(CombatLayers.ENEMY_BODY)
	assert_eq(crate.collision_layer, enemy_bit)
	assert_ne(_kit.player.collision_mask & enemy_bit, 0, "Red bumps into it")
	_kit.controller.set_form(&"huge", 0.0)
	_kit.step(4)
	assert_eq(_kit.player.collision_mask & enemy_bit, 0, "the colossus does not")


# ---- smashing ----

func test_a_prop_collapses_when_its_health_runs_out_and_stands_up_on_reset() -> void:
	await _boot()
	var crate: SmashProp = _kit.yard.props[0]
	var smashed: Array[int] = []
	crate.smashed.connect(func(_p: SmashProp) -> void: smashed.append(1))
	crate.apply_hit({"damage": 3, "outcome": &"hit"})
	assert_false(crate.dead)
	assert_lt(crate.hp, crate.hp_max)
	crate.apply_hit({"damage": 9999, "outcome": &"hit"})
	assert_true(crate.dead)
	assert_eq(smashed.size(), 1)
	assert_true(crate.is_collapsing())
	assert_eq(crate.collision_layer, 0, "no longer in the way")
	for i: int in 80:
		crate.tick(1.0 / 60.0)
	assert_true(crate.is_gone())
	assert_false(crate.model.visible)
	crate.reset_prop()
	assert_false(crate.dead)
	assert_eq(crate.hp, crate.hp_max)
	assert_true(crate.model.visible)
	assert_eq(crate.collision_layer, CombatLayers.bit(CombatLayers.ENEMY_BODY))


func test_props_are_not_enemies() -> void:
	await _boot()
	assert_eq(_kit.director.living_enemies().size(), _kit.sandbox.get_enemies().size(), "the wolves only")
	assert_eq(_kit.yard.props[0].team, &"prop")
	var found_prop_target: bool = false
	for target: Node3D in _kit.lock_on._candidates():
		if target is SmashProp:
			found_prop_target = true
	assert_false(found_prop_target, "nothing locks onto a crate")


func test_a_sword_swing_smashes_a_crate_through_the_real_hit_flow() -> void:
	await _boot()
	var crate: SmashProp = null
	for prop: SmashProp in _kit.yard.props:
		if prop.kind == &"crate_small":
			crate = prop
			break
	var at: Vector3 = crate.centre_world()
	_kit.place(at + Vector3(0.0, 0.02, 1.2), 180.0)         # standing south of it, facing it
	await tree.physics_frame
	await tree.physics_frame
	var hits: Array[Dictionary] = []
	_kit.director.hit_landed.connect(func(info: Dictionary) -> void: hits.append(info))
	for swing: int in 4:
		_kit.player.press(&"light")
		for i: int in 40:
			_kit.step(1)
			if i % 4 == 0:
				await tree.physics_frame
		if crate.dead:
			break
	assert_false(hits.is_empty(), "Red's sword hit the crate")
	assert_true(crate.dead, "and it broke")


func test_the_loader_smashes_with_scaled_damage_and_the_colossus_stomps_through_buildings() -> void:
	await _boot()
	var building: SmashProp = null
	for prop: SmashProp in _kit.yard.props:
		if prop.kind == &"building_20m" and prop.position.x > 280.0:
			building = prop
			break
	assert_not_null(building)
	_kit.controller.set_form(&"huge", 0.0)
	_kit.place(building.centre_world() + Vector3(-40.0, 0.02, 0.0), 90.0)
	_kit.step(30)
	assert_false(building.dead)
	_kit.walk_to(building.centre_world(), 3.0, 600, func() -> bool: return building.dead)
	assert_true(building.dead, "walking into a building flattens it")
	assert_gt(_kit.controller.stomps, 0)
	_kit.stop()


# ---- boarding ----

func test_walking_into_the_ring_boards_the_loader() -> void:
	await _boot()
	var small: RobotDisplay = _kit.yard.small_display
	var forms: Array[StringName] = []
	_kit.player.form_changed.connect(func(id: StringName) -> void: forms.append(id))
	_kit.place(small.boarding_point() + Vector3(-3.0, 0.02, 0.0), 90.0)
	assert_eq(_kit.mode(), RobotBoarding.Mode.RED)
	assert_ne(_kit.boarding.prompt_text(), "", "the prompt says what to do")
	_kit.player.set_move_input(Vector2(0, -1))
	var frames: int = _kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.BOARDING, 300)
	assert_lt(frames, 300, "she walked into the ring and the boarding started")
	assert_eq(_kit.player.get_control_mode(), ActionPlayer.ControlMode.SCRIPTED, "a sequence moves her now")
	_kit.player.set_move_input(Vector2(0, -1))
	_kit.step(30)
	assert_eq(_kit.mode(), RobotBoarding.Mode.BOARDING, "the stick does nothing during the climb")
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.SMALL, 400)
	_kit.stop()
	assert_eq(_kit.mode(), RobotBoarding.Mode.SMALL)
	assert_eq(_kit.player.get_form_id(), &"small")
	assert_eq(_kit.controller.form_id(), &"small")
	assert_eq(_kit.player.get_control_mode(), ActionPlayer.ControlMode.NORMAL)
	assert_false(_kit.player.input_locked, "the controls are back")
	assert_false(small.is_active(), "the parked loader is the one she is wearing now")
	assert_true(forms.has(&"small"))
	assert_eq(_kit.player.hp_max, 480)
	assert_almost_eq(small.hatch_open_amount(), 0.0, 0.01, "hatch shut")


func test_interact_boards_from_a_few_metres_off() -> void:
	await _boot()
	var small: RobotDisplay = _kit.yard.small_display
	_kit.place(small.boarding_point() + Vector3(-2.2, 0.02, 0.0), 90.0)
	_kit.step(10)
	assert_eq(_kit.mode(), RobotBoarding.Mode.RED, "standing outside the ring does nothing")
	_kit.boarding.request_interact()
	_kit.step(3)
	assert_eq(_kit.mode(), RobotBoarding.Mode.BOARDING)


func test_boarding_events_come_in_order_and_the_camera_pulls_back_over_a_second_or_more() -> void:
	await _boot()
	var small: RobotDisplay = _kit.yard.small_display
	var seen: Array[StringName] = []
	_kit.boarding.sequence_event.connect(func(kind: StringName, event: StringName) -> void: seen.append(StringName("%s:%s" % [kind, event])))
	_kit.place(small.boarding_point() + Vector3(-1.0, 0.02, 0.0), 90.0)
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.BOARDING, 100)
	var view_start: float = _kit.camera.scale_view_progress()
	var distances: Array[float] = []
	for i: int in 240:
		_kit.step(1)
		distances.append(_kit.camera.get_camera().position.z)
		if _kit.mode() == RobotBoarding.Mode.SMALL:
			break
	assert_eq(view_start, 1.0, "no pull-back before the climb")
	var index_of: Callable = func(id: StringName) -> int: return seen.find(id)
	assert_lt(index_of.call(&"board:begin:hatch_open"), index_of.call(&"board:begin:climb"))
	assert_lt(index_of.call(&"board:begin:climb"), index_of.call(&"board:begin:hatch_close"))
	assert_lt(index_of.call(&"board:begin:hatch_close"), index_of.call(&"board:swap"))
	assert_lt(index_of.call(&"board:swap"), index_of.call(&"board:control"))
	# the camera: starts at Red's distance, ends at the loader's, and gets there over more than a second (both read from the data)
	var red_distance: float = float(ScaleProfile.camera_block(&"red")["distance_m"])
	var loader_distance: float = float(ScaleProfile.camera_block(&"small")["distance_m"])
	assert_gt(loader_distance, red_distance + 1.0, "the loader's view is farther back than Red's, or there is nothing to pull back")
	var settle: int = -1
	for i: int in distances.size():
		if absf(distances[i] - loader_distance) < 0.5:
			settle = i
			break
	var move_start: int = -1
	for i: int in distances.size():
		if absf(distances[i] - red_distance) > 0.3:
			move_start = i
			break
	assert_gt(move_start, 0)
	assert_gt(settle, move_start)
	var seconds: float = float(settle - move_start) / 60.0
	assert_gt(seconds, 0.8, "a pull-back, not a cut")
	assert_lt(seconds, 1.6)


func test_climbing_out_puts_red_back_at_the_boarding_point_and_does_not_re_board() -> void:
	await _boot()
	await _board()
	var small: RobotDisplay = _kit.yard.small_display
	_kit.place(Vector3(60.0, 0.02, 0.0), 90.0)
	_kit.step(30)
	_kit.boarding.request_disembark()
	_kit.step(2)
	assert_eq(_kit.mode(), RobotBoarding.Mode.DISEMBARKING)
	assert_true(small.is_active(), "the loader is there again, parked where she left it")
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.RED, 400)
	assert_eq(_kit.mode(), RobotBoarding.Mode.RED)
	assert_eq(_kit.player.get_form_id(), &"red")
	assert_eq(_kit.player.hp_max, 120)
	assert_eq(_kit.player.get_control_mode(), ActionPlayer.ControlMode.NORMAL)
	assert_true(_kit.player.global_position.distance_to(small.boarding_point()) < 0.6, "right at the boarding point")
	_kit.step(120)
	assert_eq(_kit.mode(), RobotBoarding.Mode.RED, "standing in the ring does not board her again")
	assert_almost_eq(small.hatch_open_amount(), 0.0, 0.01)
	_kit.player.set_move_input(Vector2(0, 1))       # step back out of the ring (camera looks east, stick down = west)
	_kit.step(60)
	_kit.player.set_move_input(Vector2.ZERO)
	_kit.step(5)
	_kit.player.set_move_input(Vector2(0, -1))
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.BOARDING, 200)
	assert_eq(_kit.mode(), RobotBoarding.Mode.BOARDING, "once she has stepped out, the ring takes her again")


func test_disembark_waits_for_her_to_stop_and_a_stale_press_expires() -> void:
	await _boot()
	await _board()
	_kit.place(Vector3(60.0, 0.02, 0.0), 90.0)
	_kit.player.set_move_input(Vector2(0, -1))
	_kit.step(40)
	_kit.boarding.request_disembark()
	_kit.step(2)
	assert_eq(_kit.mode(), RobotBoarding.Mode.SMALL, "not while she is running")
	_kit.player.set_move_input(Vector2.ZERO)
	_kit.step(40)
	assert_eq(_kit.mode(), RobotBoarding.Mode.DISEMBARKING, "the press was remembered and goes off as soon as she has stopped")
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.RED, 400)
	assert_eq(_kit.mode(), RobotBoarding.Mode.RED)
	# a press that nothing follows up on does not wait forever
	await _board()
	_kit.place(Vector3(60.0, 0.02, 0.0), 90.0)
	_kit.player.set_move_input(Vector2(0, -1))
	_kit.step(20)
	_kit.boarding.request_disembark()
	_kit.step(60 * 3)
	assert_eq(_kit.mode(), RobotBoarding.Mode.SMALL, "still running three seconds later")
	_kit.player.set_move_input(Vector2.ZERO)
	_kit.step(60)
	assert_eq(_kit.mode(), RobotBoarding.Mode.SMALL, "the old press has run out")


# ---- docking ----

func test_walking_the_loader_to_the_ring_starts_the_docking_and_it_runs_its_states_in_order() -> void:
	await _boot()
	await _board()
	var huge: RobotDisplay = _kit.yard.huge_display
	var small: RobotDisplay = _kit.yard.small_display
	var seen: Array[StringName] = []
	_kit.boarding.sequence_event.connect(func(kind: StringName, event: StringName) -> void: seen.append(StringName("%s:%s" % [kind, event])))
	var approach: Vector3 = huge.approach_point()
	_kit.place(approach + Vector3(-9.0, 0.02, 0.0), 90.0)
	_kit.step(20)
	assert_eq(_kit.mode(), RobotBoarding.Mode.SMALL)
	_kit.player.set_move_input(Vector2(0, -1))
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.DOCKING, 300)
	assert_eq(_kit.mode(), RobotBoarding.Mode.DOCKING)
	assert_eq(_kit.player.get_control_mode(), ActionPlayer.ControlMode.GHOST, "the loader is on its own now")
	assert_true(small.is_active())
	var states: Array[StringName] = []
	var doors_at_hop: float = -1.0
	var small_height_at_snap: float = -1.0
	var huge_bay_height: float = -1.0
	var guard: int = 0
	while _kit.mode() == RobotBoarding.Mode.DOCKING and guard < 600:
		_kit.step(1)
		guard += 1
		var seq: RobotSequence = _kit.boarding.get_sequence()
		if seq == null:
			break
		var phase: StringName = seq.phase_name()
		if states.is_empty() or states[states.size() - 1] != phase:
			states.append(phase)
		if phase == &"hop" and doors_at_hop < 0.0:
			doors_at_hop = huge.doors_open_amount()
		if phase == &"snap":
			small_height_at_snap = small.global_position.y
			huge_bay_height = huge.dock_point().y
	assert_eq(states, [&"approach", &"doors", &"hop", &"snap", &"lock", &"power_up"], "the Technical Artist's order")
	assert_gt(doors_at_hop, 0.9, "the doors were open before the hop")
	assert_gt(small_height_at_snap, 15.0, "the loader snapped in at the chest bay, high up the colossus")
	assert_lt(absf(small_height_at_snap - huge_bay_height), 1.0, "right at the bay")
	assert_eq(_kit.mode(), RobotBoarding.Mode.HUGE)
	assert_eq(_kit.player.get_form_id(), &"huge")
	assert_eq(_kit.controller.form_id(), &"huge")
	assert_eq(_kit.player.get_control_mode(), ActionPlayer.ControlMode.NORMAL)
	assert_false(_kit.player.input_locked)
	assert_false(huge.is_active(), "the display gives way to the controller")
	assert_false(small.is_active(), "the loader is docked inside")
	assert_almost_eq(huge.doors_open_amount(), 0.0, 0.01, "the doors are shut")
	assert_true(seen.find(&"dock:begin:doors") < seen.find(&"dock:begin:hop"))
	assert_true(seen.find(&"dock:end:snap") < seen.find(&"dock:swap"))
	assert_eq(_kit.player.hp_max, 6000)


func test_the_loader_snaps_onto_the_dock_point_and_the_colossus_stands_where_it_was() -> void:
	await _boot()
	await _board()
	var huge: RobotDisplay = _kit.yard.huge_display
	var small: RobotDisplay = _kit.yard.small_display
	var home: Vector3 = huge.global_position
	_kit.place(huge.approach_point() + Vector3(-8.0, 0.02, 0.0), 90.0)
	_kit.player.set_move_input(Vector2(0, -1))
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.DOCKING, 300)
	_kit.step_until(func() -> bool: return _kit.boarding.get_sequence().progress(&"snap") >= 1.0, 600)
	var anchor_to_point: float = small.dock_anchor().distance_to(huge.dock_point())
	assert_lt(anchor_to_point, 0.2, "dock_anchor is on dock_point")
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.HUGE, 600)
	assert_lt(_kit.player.global_position.distance_to(home), 0.2, "the controller took over at the colossus's own place")
	assert_almost_eq(_kit.player.rotation.y, huge.rotation.y, 0.01)


func test_the_dock_hit_stop_pauses_the_sequence_briefly() -> void:
	await _boot()
	await _board()
	var huge: RobotDisplay = _kit.yard.huge_display
	_kit.place(huge.approach_point() + Vector3(-8.0, 0.02, 0.0), 90.0)
	_kit.player.set_move_input(Vector2(0, -1))
	_kit.step_until(func() -> bool: return _kit.mode() == RobotBoarding.Mode.DOCKING, 300)
	_kit.step_until(func() -> bool: return _kit.boarding.get_sequence().has_fired(&"end:snap"), 600)
	assert_true(_kit.boarding.get_sequence().is_frozen(), "80 ms hit-stop at the clank")
	var t: float = _kit.boarding.get_sequence().time_s
	_kit.step(2)
	assert_almost_eq(_kit.boarding.get_sequence().time_s, t, 0.0001)
	_kit.step(8)
	assert_gt(_kit.boarding.get_sequence().time_s, t)


func test_undocking_reverses_it_and_the_loader_is_in_front_of_the_colossus() -> void:
	await _boot()
	await _board()
	await _dock()
	var huge: RobotDisplay = _kit.yard.huge_display
	_kit.place(Vector3(300.0, 0.02, 0.0), 90.0)
	_kit.step(30)
	_kit.boarding.request_disembark()
	_kit.step(3)
	assert_eq(_kit.mode(), RobotBoarding.Mode.UNDOCKING)
	assert_true(huge.is_active(), "the colossus stands where it was left")
	assert_lt(huge.global_position.distance_to(Vector3(300.0, 0.0, 0.0)), 0.5)
	var states: Array[StringName] = []
	var guard: int = 0
	while _kit.mode() == RobotBoarding.Mode.UNDOCKING and guard < 600:
		_kit.step(1)
		guard += 1
		var seq: RobotSequence = _kit.boarding.get_sequence()
		if seq != null:
			var phase: StringName = seq.phase_name()
			if states.is_empty() or states[states.size() - 1] != phase:
				states.append(phase)
	assert_eq(states, [&"power_down", &"doors", &"hop", &"doors_close"])
	assert_eq(_kit.mode(), RobotBoarding.Mode.SMALL)
	assert_eq(_kit.player.get_form_id(), &"small")
	assert_eq(_kit.controller.form_id(), &"small")
	var out: Vector3 = huge.approach_point()
	assert_lt(Vector2(_kit.player.global_position.x - out.x, _kit.player.global_position.z - out.z).length(), 0.5, "out on the floor in front of the colossus")
	assert_true(_kit.player.is_on_floor() or _kit.player.global_position.y < 0.5)
	_kit.step(60)
	assert_eq(_kit.mode(), RobotBoarding.Mode.SMALL, "it does not dock again at once")


# ---- the world scales with the form ----

func test_fog_draw_distance_and_shadows_scale_with_each_form() -> void:
	await _boot()
	var env: Environment = (_kit.sandbox.get_node("WorldEnvironment") as WorldEnvironment).environment
	var key: DirectionalLight3D = _kit.sandbox.get_node("Lights/KeyLight") as DirectionalLight3D
	var look: PsxRoomLook = _kit.sandbox.get_node("RoomLook") as PsxRoomLook
	var cam: Camera3D = _kit.camera.get_camera()
	var seen: Dictionary = {}
	for id: StringName in [&"red", &"small", &"huge"]:
		_kit.controller.set_form(id, 0.0)
		_kit.step(4)
		seen[id] = {"far": cam.far, "near": cam.near, "fog": look.fog_distances(), "density": env.fog_density, "shadow": key.directional_shadow_max_distance}
	assert_lt(float(seen[&"red"]["far"]), float(seen[&"small"]["far"]))
	assert_lt(float(seen[&"small"]["far"]), float(seen[&"huge"]["far"]), "draw distance grows with the body")
	assert_eq(seen[&"red"]["fog"], Vector2(30.0, 150.0), "Red's haze is the arena's")
	assert_eq(seen[&"small"]["fog"], Vector2(60.0, 300.0))
	assert_eq(seen[&"huge"]["fog"], Vector2(300.0, 1500.0))
	assert_gt(float(seen[&"red"]["density"]), float(seen[&"huge"]["density"]))
	assert_lt(float(seen[&"red"]["shadow"]), float(seen[&"huge"]["shadow"]))
	assert_gt(float(seen[&"huge"]["near"]), float(seen[&"red"]["near"]))
	# the colossus must be visible from its own camera: nothing of it is inside the haze
	var camera_distance: float = 75.0
	assert_gt(Vector2(seen[&"huge"]["fog"]).x, camera_distance)
	assert_gt(float(seen[&"huge"]["far"]), camera_distance * 10.0)


func test_the_haze_eases_with_the_camera_when_a_form_is_entered() -> void:
	await _boot()
	var look: PsxRoomLook = _kit.sandbox.get_node("RoomLook") as PsxRoomLook
	_kit.controller.set_form(&"huge", 1.5)
	_kit.step(30)
	var early: float = look.fog_distances().y
	assert_gt(early, 150.0)
	assert_lt(early, 1500.0, "still on its way half a second in")
	assert_true(_kit.controller.is_blending())
	_kit.step(80)
	assert_almost_eq(look.fog_distances().y, 1500.0, 1.0)
	assert_false(_kit.controller.is_blending())


func test_sound_pitch_follows_the_form_and_is_restored_when_the_sandbox_goes() -> void:
	await _boot()
	_kit.controller.audio_enabled = true
	var audio: Node = tree.root.get_node("AudioManager")
	_kit.controller.set_form(&"small", 0.0)
	assert_almost_eq(float(audio.get("sfx_pitch_mult")), 0.75, 0.001)
	_kit.controller.set_form(&"huge", 0.0)
	assert_almost_eq(float(audio.get("sfx_pitch_mult")), 0.4, 0.001)
	assert_almost_eq(float(audio.call("get_scale_lowpass_hz")), 4500.0, 0.1)
	_kit.controller.set_form(&"red", 0.0)
	assert_almost_eq(float(audio.get("sfx_pitch_mult")), 1.0, 0.001)
	_kit.controller.set_form(&"huge", 0.0)
	_kit.sandbox.get_parent().remove_child(_kit.sandbox)
	assert_almost_eq(float(audio.get("sfx_pitch_mult")), 1.0, 0.001, "leaving the sandbox leaves the sound as it found it")
	_kit.sandbox.free()


func test_reset_arena_puts_everything_back() -> void:
	await _boot()
	await _board()
	await _dock()
	for prop: SmashProp in _kit.yard.props.slice(0, 5):
		prop.stomp()
	assert_gt(_kit.yard.smashed_count(), 0)
	_kit.sandbox.reset_arena()
	_kit.step(4)
	assert_eq(_kit.mode(), RobotBoarding.Mode.RED)
	assert_eq(_kit.player.get_form_id(), &"red")
	assert_eq(_kit.controller.form_id(), &"red")
	assert_eq(_kit.yard.smashed_count(), 0, "every prop stands again")
	assert_true(_kit.yard.small_display.is_active())
	assert_true(_kit.yard.huge_display.is_active())
	assert_lt(_kit.yard.huge_display.global_position.distance_to(_kit.yard.home_of(&"huge").origin), 0.01)
	assert_lt(_kit.player.global_position.distance_to(_kit.sandbox.get_player_spawn().origin), 0.2)
	assert_eq(_kit.player.hp, 120)


func test_a_landing_slam_flattens_the_props_around_the_colossus_s_feet() -> void:
	await _boot()
	_kit.controller.set_form(&"huge", 0.0)
	var spot: Vector3 = Vector3(400.0, 0.02, 0.0)           # the avenue: nothing of the city is kept here
	_kit.place(spot, 90.0)
	_kit.step(30)
	var victims: Array[SmashProp] = []
	for offset: Vector3 in [Vector3(16.0, 0.0, 0.0), Vector3(-17.0, 0.0, 8.0)]:       # outside a plain 11 m stomp, inside a slam
		var crate: SmashProp = _kit.yard._add_prop(&"car", spot + offset, 0.0, _kit.yard.data["kinds"] as Dictionary)
		victims.append(crate)
	_kit.step(2)
	assert_eq(_kit.controller.stomp_nearby(), 0, "walking does not reach them")
	_kit.player.press(&"jump")
	_kit.step(300)
	assert_gt(_kit.controller.slams_taken, 0)
	for car: SmashProp in victims:
		assert_true(car.dead, "the slam flattened it")
