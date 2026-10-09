extends TestCase
## CS-21: the same ActionPlayer wearing three body sizes (Red, the 3.5 m loader, the 50 m colossus). A form is only a ScaleProfile
## (data/combat/scale_profiles.json); these tests drive the real controller by hand and check that each form really moves,
## jumps, turns, swings and sounds like its numbers say, and that going back to Red leaves nothing behind.

const SCENE: String = "res://scenes/actors/action_player.tscn"
const DT: float = 1.0 / 60.0

var _player: ActionPlayer = null
var _floor: StaticBody3D = null
var _director: CombatDirector = null


func _arena(with_director: bool = false) -> void:
	_floor = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1200, 2, 1200)
	shape.shape = box
	_floor.add_child(shape)
	_floor.collision_layer = 1
	add_to_root(_floor)
	_floor.global_position = Vector3(0, -1, 0)
	if with_director:
		_director = CombatDirector.new()
		_director.sync_to_wall_clock = false
		add_to_root(_director)
		_director.set_physics_process(false)
	_player = (load(SCENE) as PackedScene).instantiate() as ActionPlayer
	_player.read_engine_input = false
	add_to_root(_player)
	_player.set_physics_process(false)
	_player.global_position = Vector3(0, 0.02, 0)
	await tree.physics_frame
	await tree.physics_frame
	_step(10)


func _step(frames: int) -> void:
	for i: int in frames:
		if _director != null:
			_director.tick(DT)
		_player.tick(DT)


func _speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func _form(id: StringName) -> void:
	var profile: ScaleProfile = ScaleProfile.get_form(id)
	assert_not_null(profile, "form %s is in the data" % id)
	_player.set_scale_profile(profile)
	_step(8)


func _top_speed(frames: int = 240) -> float:
	_player.set_move_input(Vector2(0, -1))
	_step(frames)
	var v: float = _speed()
	_player.set_move_input(Vector2.ZERO)
	_step(240)
	return v


func test_each_form_runs_at_its_own_top_speed() -> void:
	await _arena()
	var red: float = _top_speed(60)
	_form(&"small")
	var small: float = _top_speed()
	_form(&"huge")
	var huge: float = _top_speed(400)
	assert_almost_eq(red, _player.knobs.get_f("run_speed_mps"), 0.1, "Red: the feel panel's number")
	assert_almost_eq(small, ScaleProfile.get_form(&"small").knob("run_speed_mps", 0.0), 0.1)
	assert_almost_eq(huge, ScaleProfile.get_form(&"huge").knob("run_speed_mps", 0.0), 0.1)
	assert_gt(huge, small, "bigger robots cover more ground per second")
	assert_gt(small, red)


func test_a_huge_robot_speeds_up_slowly_and_turns_slowly() -> void:
	await _arena()
	_form(&"huge")
	_player.set_move_input(Vector2(0, -1))
	_step(12)
	assert_lt(_speed(), 4.0, "ten m/s2 of acceleration: 0.2 s in, still crawling")
	var small_profile: ScaleProfile = ScaleProfile.get_form(&"small")
	_form(&"small")
	_player.set_move_input(Vector2.ZERO)
	_step(60)
	assert_eq(small_profile.id, &"small")
	# turn rate: a quarter turn at 480 deg/s (small) takes about 0.19 s, at 70 deg/s (huge) about 1.3 s
	var cam: Camera3D = Camera3D.new()
	add_to_root(cam)
	_player.camera = cam
	cam.global_basis = Basis.IDENTITY
	_player.rotation.y = 0.0
	_player.set_move_input(Vector2(1, 0))       # screen-right
	_step(14)
	assert_lt(absf(wrapf(_player.rotation.y - PlayerMotion.yaw_for_direction(Vector3.RIGHT), -PI, PI)), 0.2, "the loader has turned right after a quarter second")
	_player.set_move_input(Vector2.ZERO)
	_form(&"huge")
	_player.rotation.y = 0.0
	_player.set_move_input(Vector2(1, 0))
	_step(14)
	var left_to_turn: float = absf(wrapf(_player.rotation.y - PlayerMotion.yaw_for_direction(Vector3.RIGHT), -PI, PI))
	assert_gt(left_to_turn, 1.0, "the colossus is still swinging round after the same time")


func test_jump_heights_follow_the_profile() -> void:
	await _arena()
	var heights: Dictionary[StringName, float] = {}
	for id: StringName in [&"small", &"huge"]:
		_form(id)
		var peak: float = 0.0
		_player.press(&"jump")
		for i: int in 400:
			_step(1)
			peak = maxf(peak, _player.global_position.y)
		heights[id] = peak
		_step(200)
	assert_almost_eq(heights[&"small"], 3.0, 0.15, "the loader jumps 3 m")
	assert_almost_eq(heights[&"huge"], 12.0, 0.6, "the colossus jumps 12 m")


func test_a_huge_jump_hangs_longer_than_a_small_one() -> void:
	await _arena()
	var air: Dictionary[StringName, int] = {}
	for id: StringName in [&"small", &"huge"]:
		_form(id)
		_player.press(&"jump")
		_step(1)
		var frames: int = 0
		while not _player.is_on_floor() and frames < 600:
			_step(1)
			frames += 1
		air[id] = frames
		_step(120)
	assert_gt(air[&"huge"], air[&"small"], "heavier: more air time (slower rise)")


func test_the_body_hurtbox_and_health_follow_the_form_and_health_keeps_its_fraction() -> void:
	await _arena(true)
	var red_hp_max: int = _player.hp_max
	_player.hp = red_hp_max / 2
	_form(&"huge")
	assert_eq(_player.hp_max, 6000)
	assert_almost_eq(float(_player.hp) / float(_player.hp_max), 0.5, 0.01, "half health stays half health")
	assert_almost_eq(_player.radius_m, 11.0, 0.001)
	assert_almost_eq(_player.height_m, 46.0, 0.001)
	var capsule: CapsuleShape3D = (_player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	assert_almost_eq(capsule.radius, 11.0, 0.001, "the collision body grew")
	var hurt: CapsuleShape3D = (_player.get_hurtbox().get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	assert_almost_eq(hurt.radius, 11.0, 0.001, "and so did the place she can be hit")
	_form(&"red")
	assert_eq(_player.hp_max, red_hp_max)
	assert_almost_eq(_player.radius_m, 0.3, 0.001)


func test_going_back_to_red_leaves_red_exactly_as_she_was() -> void:
	await _arena()
	var before_speed: float = _top_speed(60)
	_form(&"huge")
	_form(&"small")
	_form(&"red")
	assert_eq(_player.get_form_id(), &"red")
	assert_almost_eq(_top_speed(60), before_speed, 0.01)
	assert_false(_player.is_armored(), "Red flinches again")
	assert_eq(_player.collision_mask, CombatLayers.body_mask(&"player", false))


func test_the_huge_robot_steps_over_bodies_and_the_small_one_does_not() -> void:
	await _arena()
	var enemy_bit: int = CombatLayers.bit(CombatLayers.ENEMY_BODY)
	_form(&"huge")
	assert_eq(_player.collision_mask & enemy_bit, 0, "a 50 m robot ignores enemy bodies")
	assert_ne(_player.collision_mask & 1, 0, "but still stands on the world")
	_form(&"small")
	assert_ne(_player.collision_mask & enemy_bit, 0, "the loader still bumps into things")
	_player.press(&"dash")
	_step(2)
	assert_eq(_player.collision_mask & enemy_bit, 0, "a dash goes through enemies in every form")
	_step(60)
	assert_ne(_player.collision_mask & enemy_bit, 0, "and the mask comes back")


func test_each_form_wears_its_own_model_and_the_others_are_hidden() -> void:
	await _arena()
	var red_model: Node3D = _player.get_model()
	assert_not_null(red_model)
	_form(&"small")
	var small_model: Node3D = _player.get_model()
	assert_ne(small_model, red_model)
	assert_true(small_model.scene_file_path.ends_with("robot_small_ual.glb"))
	assert_false(red_model.visible, "Red's model is hidden inside the robot")
	assert_true(small_model.visible)
	_form(&"huge")
	assert_true(_player.get_model().scene_file_path.ends_with("robot_huge_ual.glb"))
	assert_false(small_model.visible)
	_form(&"red")
	assert_eq(_player.get_model(), red_model, "Red's own model, not a copy")
	assert_true(red_model.visible)
	assert_not_null(_player.get_animation_player())
	assert_true(_player.get_animation_player().has_animation(&"run"))


func test_the_same_sword_goes_with_her_into_a_robot_at_the_robot_s_size() -> void:
	await _arena()
	assert_true(_player.equip_sword(&"machete"))
	_form(&"small")
	assert_eq(_player.current_sword(), &"machete", "the sword she was carrying")
	var sword: Node3D = (_player.get_node("GearVisuals") as GearVisuals).get_sword()
	assert_not_null(sword)
	var base: float = float((_player.get_node("GearVisuals") as GearVisuals).sword_entry(&"machete").get("scale", 1.0))
	assert_almost_eq(sword.scale.x, base * 3.68, 0.001, "3.68 times Red's")
	_form(&"huge")
	var huge_sword: Node3D = (_player.get_node("GearVisuals") as GearVisuals).get_sword()
	assert_almost_eq(huge_sword.scale.x, base * 52.6, 0.01)
	_form(&"red")
	assert_almost_eq(((_player.get_node("GearVisuals") as GearVisuals).get_sword()).scale.x, base, 0.001)
	assert_eq(_player.current_sword(), &"machete")
	_player.equip_sword(&"katana_cyan")
	_form(&"small")
	assert_eq(_player.current_sword(), &"katana_cyan", "a sword picked up as Red comes along")


func test_robot_animation_speed_is_slower_and_heavier() -> void:
	await _arena()
	_form(&"small")
	_player.set_move_input(Vector2(0, -1))
	_step(90)
	var small_speed: float = _player.get_animation_player().speed_scale
	assert_almost_eq(small_speed, 9.0 / 13.9, 0.03, "ground speed over the run clip's stride: no foot slide")
	_form(&"huge")
	_player.set_move_input(Vector2(0, -1))
	_step(400)
	assert_eq(_player.current_clip(), &"walk", "the colossus uses the walk clip for everything")
	var huge_speed: float = _player.get_animation_player().speed_scale
	assert_almost_eq(huge_speed, 22.0 / 31.5, 0.03, "the walk clip at 0.7")
	_player.set_move_input(Vector2.ZERO)
	_step(240)
	assert_almost_eq(_player.get_animation_player().speed_scale, 0.6, 0.01, "even its idle is slow")


func test_a_swing_in_a_robot_uses_scaled_boxes_and_damage() -> void:
	await _arena(true)
	var enemy: CombatActor = CombatActor.new()
	enemy.actor_id = &"dummy"
	enemy.team = &"enemy"
	enemy.move_set_id = &"grunt"
	enemy.hp = 100000
	enemy.hp_max = 100000
	add_to_root(enemy)
	enemy.global_position = Vector3(0, 0, 18)
	await tree.physics_frame
	await tree.physics_frame
	_step(2)
	_form(&"huge")
	_player.rotation.y = 0.0
	var seen: Array[Dictionary] = []
	_director.hit_landed.connect(func(info: Dictionary) -> void: seen.append(info))
	_player.press(&"light")
	var frames: int = 0
	while seen.is_empty() and frames < 200:
		_step(1)
		frames += 1
	assert_false(seen.is_empty(), "a 52 m swing reaches a target 18 m away")
	var small_move: Dictionary = MoveSet.load_default().get_move(&"red", &"light_1")
	var base_damage: int = int((small_move["hit"] as Dictionary)["damage"])
	assert_eq(int(seen[0]["damage"]), base_damage * 40, "damage x40 for the colossus")
	_form(&"red")
	assert_eq(_player.collision_mask & CombatLayers.bit(CombatLayers.ENEMY_BODY), CombatLayers.bit(CombatLayers.ENEMY_BODY))


func test_a_giant_robot_swings_slower_than_red() -> void:
	await _arena(true)
	var durations: Dictionary[StringName, int] = {}
	for id: StringName in [&"red", &"huge"]:
		_form(id)
		_step(5)
		_player.press(&"light")
		_step(1)
		var frames: int = 1
		while _player.get_state() == ActionPlayer.State.ATTACK and frames < 600:
			_step(1)
			frames += 1
		durations[id] = frames
		_step(30)
	assert_gt(durations[&"huge"], int(float(durations[&"red"]) * 1.8), "0.45 x speed: the same move takes over twice as long")


func test_a_robot_is_not_staggered_by_a_hit_and_input_can_be_locked() -> void:
	await _arena(true)
	_form(&"small")
	assert_true(_player.is_armored())
	_player.input_locked = true
	_player.set_move_input(Vector2(0, -1))
	_player.press(&"jump")
	var z0: float = _player.global_position.z
	_step(30)
	assert_almost_eq(_player.global_position.z, z0, 0.001, "locked: no walking")
	assert_true(_player.is_on_floor(), "and no jump")
	_player.input_locked = false
	_player.set_move_input(Vector2(0, -1))
	_step(30)
	assert_ne(_player.global_position.z, z0, "unlocked: walks again")


func test_ghost_and_scripted_modes_take_her_off_the_physics_and_back() -> void:
	await _arena(true)
	_player.set_control_mode(ActionPlayer.ControlMode.GHOST)
	assert_false(_player.get_node("Visual").visible, "hidden")
	assert_eq(_player.collision_layer, 0)
	assert_eq(_player.collision_mask, 0)
	assert_false(_player.get_hurtbox().monitorable, "nothing can hit a ghost")
	_player.set_move_input(Vector2(0, -1))
	_player.global_position = Vector3(5, 3, 5)
	_step(30)
	assert_almost_eq(_player.global_position.y, 3.0, 0.001, "a ghost does not fall; a sequence places it")
	_player.set_control_mode(ActionPlayer.ControlMode.SCRIPTED)
	assert_true(_player.get_node("Visual").visible, "scripted: visible")
	assert_eq(_player.collision_layer, 0)
	_player.set_control_mode(ActionPlayer.ControlMode.NORMAL)
	assert_true(_player.get_node("Visual").visible)
	assert_eq(_player.collision_layer, CombatLayers.bit(CombatLayers.PLAYER_BODY))
	assert_true(_player.get_hurtbox().monitorable)
	_player.set_move_input(Vector2.ZERO)
	_step(120)
	assert_true(_player.is_on_floor(), "gravity is back")
