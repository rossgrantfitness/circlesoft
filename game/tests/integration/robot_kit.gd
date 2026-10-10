class_name RobotKit
extends RefCounted
## Helpers for the robot-zone tests and bot run (CS-21): boot the real combat sandbox with its clocks in the test's hands, step
## everything by hand at 60 Hz (the animation too, so footsteps happen), and steer the player like a bot would: pick a point,
## turn it into a stick push relative to the camera, and keep pushing until she is there.

const SANDBOX: String = "res://scenes/sandbox/combat_sandbox.tscn"
const DT: float = 1.0 / 60.0

var test: TestCase = null
var sandbox: CombatSandbox = null
var player: ActionPlayer = null
var camera: OrbitCamera = null
var lock_on: LockOn = null
var director: CombatDirector = null
var boarding: RobotBoarding = null
var controller: ScaleController = null
var yard: RobotYard = null
## Every tick's mode, for tests that care about the order things happened in.
var mode_trail: Array[RobotBoarding.Mode] = []


func _init(for_test: TestCase) -> void:
	test = for_test


## Builds the sandbox and takes its clocks: nothing ticks unless step() does. Wolves are frozen where they stand.
func boot() -> void:
	sandbox = (load(SANDBOX) as PackedScene).instantiate() as CombatSandbox
	test.add_to_root(sandbox)
	for i: int in 3:
		await test.tree.physics_frame
	player = sandbox.get_player() as ActionPlayer
	camera = sandbox.get_camera()
	lock_on = sandbox.get_lock_on()
	director = sandbox.get_director() as CombatDirector
	boarding = sandbox.get_robot_boarding()
	controller = sandbox.get_scale_controller()
	yard = sandbox.get_robot_yard()
	for node: Node in [sandbox, director, player, camera, lock_on, boarding, controller]:
		if node != null:
			node.set_physics_process(false)
	player.read_engine_input = false
	camera.read_engine_input = false
	lock_on.read_engine_input = false
	boarding.read_engine_input = false
	controller.audio_enabled = false
	director.sync_to_wall_clock = false
	for enemy: Node3D in sandbox.get_enemies():
		enemy.set_physics_process(false)
		enemy.set_process(false)
	for prop: SmashProp in yard.props:
		prop.set_process(false)
	step(4)


## One 60 Hz step of everything that matters, in the order the game runs it.
func step(frames: int = 1) -> void:
	for i: int in frames:
		director.tick(DT)
		player.tick(DT)
		_advance_animation()
		controller.tick(DT)
		boarding.tick(DT)
		camera.tick(DT)
		lock_on.tick(DT)
		for prop: SmashProp in yard.props:
			if prop.is_collapsing():
				prop.tick(DT)
		mode_trail.append(boarding.get_mode())


## The player's animation is stepped by hand (a headless test has no idle frames in between).
func _advance_animation() -> void:
	var anim: AnimationPlayer = player.get_animation_player()
	if anim == null:
		return
	if anim.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.advance(DT)


func step_until(condition: Callable, max_frames: int = 600) -> int:
	var frames: int = 0
	while not bool(condition.call()) and frames < max_frames:
		step(1)
		frames += 1
	return frames


## Puts her down at `at` facing `yaw_deg` with the camera behind her (no sequence, no walking).
func place(at: Vector3, yaw_deg: float) -> void:
	player.global_position = at
	player.rotation.y = deg_to_rad(yaw_deg)
	player.velocity = Vector3.ZERO
	camera.recenter()
	camera.snap()
	step(2)


## The stick push that heads for `target` (flat) given where the camera looks.
func stick_toward(target: Vector3) -> Vector2:
	var offset: Vector3 = Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
	if offset.length() < 0.01:
		return Vector2.ZERO
	var cam_basis: Basis = camera.get_camera().global_basis
	var forward: Vector3 = PlayerMotion.flat_forward(cam_basis)
	var right: Vector3 = PlayerMotion.flat_right(cam_basis)
	var dir: Vector3 = offset.normalized()
	return Vector2(dir.dot(right), -dir.dot(forward)).limit_length(1.0)


## Walks to within `tolerance` of `target`, or until `max_frames` run out, or until `stop` says so. Returns true if she got there.
func walk_to(target: Vector3, tolerance: float = 1.0, max_frames: int = 1500, stop: Callable = Callable()) -> bool:
	for i: int in max_frames:
		var gap: float = Vector2(target.x - player.global_position.x, target.z - player.global_position.z).length()
		if gap <= tolerance or (stop.is_valid() and bool(stop.call())):
			player.set_move_input(Vector2.ZERO)
			return gap <= tolerance
		player.set_move_input(stick_toward(target))
		step(1)
	player.set_move_input(Vector2.ZERO)
	return false


func stop() -> void:
	player.set_move_input(Vector2.ZERO)
	step(1)


func mode() -> RobotBoarding.Mode:
	return boarding.get_mode()
