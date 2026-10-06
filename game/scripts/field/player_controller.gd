class_name PlayerController
extends CharacterBody3D
## Red on the field. Walks and runs relative to the room's fixed camera, turns to face where she
## is going, collides with walls, and sticks to the ground (no jump).
##
## Speeds and the turn rate come from data/world/field_tuning.json via DataDB.
## Facing: the model looks along local +Z (the art convention), so get_facing() is that axis.
## The Visual node is a slot for the placeholder Red model; the capsule stand-in is removed
## automatically when the .glb exists.
##
## Collision: layer 1 is the world (walls, floor). Red sits on layer 2 and collides with layer 1.

const MODEL_PATH: String = "res://art/placeholder/characters/red/red_blockout.glb"
const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_UP: StringName = &"move_up"
const ACTION_DOWN: StringName = &"move_down"
const ACTION_RUN: StringName = &"run"
const ACTION_WALK: StringName = &"walk"
const GRAVITY_SETTING: String = "physics/3d/default_gravity"
const NODE_VISUAL: NodePath = ^"Visual"
const NODE_PLACEHOLDER: NodePath = ^"Visual/PlaceholderCapsule"

signal moved_state_changed(moving: bool, running: bool)

## Read the move/run actions every physics frame. Cutscenes turn this off and drive `stick`.
@export var read_engine_input: bool = true
## Frozen (dialogue, cutscenes): no movement, idle pose.
@export var frozen: bool = false

## Stick or d-pad direction: x right, y down (what Input.get_vector gives). Set it directly when
## read_engine_input is off.
var stick: Vector2 = Vector2.ZERO
var run_held: bool = false
## Walk button (Shift on a keyboard): walk even at full tilt. Wins over run.
var walk_held: bool = false
## The room camera that movement is relative to. Falls back to the viewport's current camera.
var camera: Camera3D = null

var _tuning: FieldTuning = FieldTuning.new()
var _gravity: float = 0.0
var _visual: Node3D = null
var _animation_player: AnimationPlayer = null
var _current_animation: StringName = &""
var _moving: bool = false
var _running: bool = false


func _ready() -> void:
	_tuning = FieldTuning.from_db(get_node_or_null("/root/DataDB"))
	_gravity = float(ProjectSettings.get_setting(GRAVITY_SETTING))
	_visual = get_node_or_null(NODE_VISUAL) as Node3D
	if ResourceLoader.exists(MODEL_PATH):
		var model_scene: PackedScene = load(MODEL_PATH) as PackedScene
		if model_scene != null:
			attach_model(model_scene)
	_play_animation(PlayerMotion.ANIM_IDLE)


func _physics_process(delta: float) -> void:
	if read_engine_input:
		stick = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)
		run_held = Input.is_action_pressed(ACTION_RUN)
		walk_held = Input.is_action_pressed(ACTION_WALK)
	step(delta)


func set_tuning(tuning: FieldTuning) -> void:
	_tuning = tuning


func set_camera(cam: Camera3D) -> void:
	camera = cam


## The unit direction Red's model faces (flat).
func get_facing() -> Vector3:
	return global_basis.z


func is_moving() -> bool:
	return _moving


func is_running() -> bool:
	return _running


func get_current_animation() -> StringName:
	return _current_animation


## One physics step of movement. Public so tests (and cutscenes) can drive it without the engine loop.
func step(delta: float) -> void:
	var cam_basis: Basis = _camera_basis()
	var live_stick: Vector2 = Vector2.ZERO if frozen else stick
	var direction: Vector3 = PlayerMotion.camera_relative_direction(live_stick, cam_basis)
	var speed: float = PlayerMotion.target_speed(live_stick, run_held, _tuning.walk_speed, _tuning.run_speed,
			_tuning.stick_run_threshold, walk_held)
	var now_moving: bool = speed > 0.0
	var now_running: bool = now_moving and PlayerMotion.is_running(live_stick, run_held, _tuning.stick_run_threshold, walk_held)

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	if now_moving:
		var yaw: float = PlayerMotion.turn_toward(rotation.y, PlayerMotion.yaw_for_direction(direction),
				_tuning.turn_rate_deg_per_s, delta)
		rotation.y = yaw
	move_and_slide()

	if now_moving != _moving or now_running != _running:
		_moving = now_moving
		_running = now_running
		moved_state_changed.emit(_moving, _running)
	_play_animation(PlayerMotion.animation_for(_moving, _running))


## Puts a model scene in the Visual slot and drops the capsule stand-in. Called automatically when
## the placeholder Red .glb exists.
func attach_model(model_scene: PackedScene) -> Node3D:
	if _visual == null:
		_visual = get_node_or_null(NODE_VISUAL) as Node3D
	if _visual == null:
		push_error("PlayerController: no Visual node to put the model in")
		return null
	var placeholder: Node = get_node_or_null(NODE_PLACEHOLDER)
	if placeholder != null:
		placeholder.queue_free()
		_visual.remove_child(placeholder)
	var model: Node3D = model_scene.instantiate() as Node3D
	if model == null:
		push_error("PlayerController: model scene root is not a Node3D")
		return null
	model.name = "Model"
	_visual.add_child(model)
	_animation_player = _find_animation_player(model)
	_current_animation = &""
	_play_animation(PlayerMotion.ANIM_IDLE)
	return model


func _camera_basis() -> Basis:
	var cam: Camera3D = camera
	if cam == null and is_inside_tree():
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return Basis.IDENTITY
	return cam.global_basis


func _play_animation(wanted: StringName) -> void:
	if _animation_player == null or wanted == _current_animation:
		return
	if _animation_player.has_animation(wanted):
		_animation_player.play(wanted)
		_current_animation = wanted


func _find_animation_player(root: Node) -> AnimationPlayer:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is AnimationPlayer:
			return node as AnimationPlayer
		stack.append_array(node.get_children())
	return null
