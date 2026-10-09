class_name RobotStageKit
extends RefCounted
## Helpers for the RobotStage tests (VS-21): a floor, the real Red, an orbit camera, lock-on and a director, and a RobotStage built
## from a data dictionary. Nothing ticks unless step() does, at 60 Hz in the order the game runs them (the same order as RobotKit).

const RED_SCENE: String = "res://scenes/actors/action_player.tscn"
const DT: float = 1.0 / 60.0

var test: TestCase = null
var host: Node3D = null
var player: ActionPlayer = null
var camera: OrbitCamera = null
var lock_on: LockOn = null
var director: CombatDirector = null
var stage: RobotStage = null
var forms: Array[StringName] = []


func _init(for_test: TestCase) -> void:
	test = for_test


## Builds the world and the stage from `data` (the shape of a robot_rooms file). Red stands at `at`.
func boot(data: Dictionary, at: Vector3 = Vector3(0, 0.02, 0)) -> void:
	host = test.add_to_root(Node3D.new()) as Node3D
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.bit(CombatLayers.WORLD)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(600, 1, 600)
	shape_node.shape = box
	floor_body.add_child(shape_node)
	host.add_child(floor_body)
	floor_body.position = Vector3(0, -0.5, 0)
	director = CombatDirector.new()
	director.feel = FeelKnobs.load_defaults()
	director.sync_to_wall_clock = false
	host.add_child(director)
	director.set_physics_process(false)
	player = (load(RED_SCENE) as PackedScene).instantiate() as ActionPlayer
	player.read_engine_input = false
	host.add_child(player)
	player.set_physics_process(false)
	player.global_position = at
	camera = OrbitCamera.new()
	camera.read_engine_input = false
	host.add_child(camera)
	camera.follow(player)
	camera.set_physics_process(false)
	lock_on = LockOn.new()
	lock_on.origin_node = player
	lock_on.read_engine_input = false
	host.add_child(lock_on)
	lock_on.set_physics_process(false)
	camera.set_lock_on(lock_on)
	player.camera = camera.get_camera()
	player.lock_on = lock_on
	player.orbit_camera = camera
	stage = RobotStage.new()
	stage.name = "RobotStage"
	stage.effects_enabled = false
	stage.read_engine_input = false
	host.add_child(stage)
	stage.setup(host, player, camera, lock_on, data)
	stage.form_changed.connect(func(form: StringName) -> void: forms.append(form))
	if stage.controller != null:
		stage.controller.set_physics_process(false)
		stage.controller.audio_enabled = false
		stage.boarding.set_physics_process(false)
	for prop: SmashProp in (stage.yard.props if stage.yard != null else []):
		prop.set_process(false)
	await test.tree.physics_frame
	await test.tree.physics_frame
	step(6)


func step(frames: int = 1) -> void:
	for i: int in frames:
		director.tick(DT)
		player.tick(DT)
		var anim: AnimationPlayer = player.get_animation_player()
		if anim != null:
			if anim.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
				anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			anim.advance(DT)
		stage.controller.tick(DT)
		stage.boarding.tick(DT)
		camera.tick(DT)
		lock_on.tick(DT)
		for prop: SmashProp in stage.yard.props:
			if prop.is_collapsing():
				prop.tick(DT)


func step_until(condition: Callable, max_frames: int = 900) -> int:
	var frames: int = 0
	while not bool(condition.call()) and frames < max_frames:
		step(1)
		frames += 1
	return frames


## Puts her down at `at` facing `yaw_deg`, still, and lets the world settle.
func place(at: Vector3, yaw_deg: float = 0.0) -> void:
	player.global_position = at
	player.rotation.y = deg_to_rad(yaw_deg)
	player.velocity = Vector3.ZERO
	camera.recenter()
	camera.snap()
	step(3)


func mode() -> RobotBoarding.Mode:
	return stage.boarding.get_mode()
