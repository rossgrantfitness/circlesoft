class_name PlayerController
extends CharacterBody3D
## Red on the field. Walks briskly, runs while the run button is held, and jumps (light and
## forgiving: coyote time, jump buffering, release-early for a lower hop, a little air control).
## Moves relative to the room's fixed camera, turns to face where she is going, collides with walls.
##
## Speeds, the turn rate and every jump number come from data/world/field_tuning.json via DataDB.
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
const ACTION_JUMP: StringName = &"jump"
const NODE_VISUAL: NodePath = ^"Visual"
const NODE_PLACEHOLDER: NodePath = ^"Visual/PlaceholderCapsule"

signal moved_state_changed(moving: bool, running: bool)
signal jumped
signal landed

## Read the move/run actions every physics frame. Cutscenes turn this off and drive `stick`.
@export var read_engine_input: bool = true
## Frozen (dialogue, cutscenes): no movement, idle pose.
@export var frozen: bool = false

## Stick or d-pad direction: x right, y down (what Input.get_vector gives). Set it directly when
## read_engine_input is off.
var stick: Vector2 = Vector2.ZERO
## Run button held (Shift / west face button): run instead of walk.
var run_held: bool = false
## Jump button held. Letting go while rising cuts the jump short.
var jump_held: bool = false
## The room camera that movement is relative to. Falls back to the viewport's current camera.
var camera: Camera3D = null

var _tuning: FieldTuning = FieldTuning.new()
var _vy: float = 0.0
var _coyote_left: float = 0.0
var _buffer_left: float = 0.0
var _air_time: float = 0.0
var _jumped_this_air: bool = false
var _was_airborne: bool = false
var _ground_y: float = 0.0
var _has_ground_y: bool = false
var _visual: Node3D = null
var _animation_player: AnimationPlayer = null
var _current_animation: StringName = &""
var _moving: bool = false
var _running: bool = false


func _ready() -> void:
	_tuning = FieldTuning.from_db(get_node_or_null("/root/DataDB"))
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
		jump_held = Input.is_action_pressed(ACTION_JUMP)
		if Input.is_action_just_pressed(ACTION_JUMP):
			request_jump()
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


func is_airborne() -> bool:
	return not is_on_floor()


## The height of the ground Red last stood on (or her own height if she has dropped below it). The
## camera follows this instead of her feet so a jump does not bob the view.
func get_ground_height() -> float:
	if not _has_ground_y:
		return global_position.y
	return minf(_ground_y, global_position.y)


## Forget the remembered ground height (after a teleport or a respawn).
func reset_ground_height() -> void:
	_has_ground_y = false


func get_current_animation() -> StringName:
	return _current_animation


## Asks for a jump. If Red cannot jump yet (in the air past coyote time) the request is remembered
## for the buffer time and fires on landing. The engine path calls this on a jump press.
func request_jump() -> void:
	if not frozen:
		_buffer_left = _tuning.jump_buffer_time_s


## One physics step of movement. Public so tests (and cutscenes) can drive it without the engine loop.
func step(delta: float) -> void:
	var cam_basis: Basis = _camera_basis()
	var live_stick: Vector2 = Vector2.ZERO if frozen else stick
	if frozen:
		_buffer_left = 0.0
	var direction: Vector3 = PlayerMotion.camera_relative_direction(live_stick, cam_basis)
	var speed: float = PlayerMotion.target_speed(live_stick, run_held, _tuning.walk_speed, _tuning.run_speed)
	var now_moving: bool = speed > 0.0
	var now_running: bool = now_moving and PlayerMotion.is_running(live_stick, run_held)

	var on_floor: bool = is_on_floor() and _vy <= 0.0
	if on_floor:
		_coyote_left = _tuning.jump_coyote_time_s
		_air_time = 0.0
		_jumped_this_air = false
		_ground_y = global_position.y
		_has_ground_y = true
	else:
		_coyote_left -= delta
		_air_time += delta

	var launch_speed: float = PlayerMotion.jump_speed(_tuning.jump_height, _tuning.jump_rise_time_s)
	var rise_gravity: float = PlayerMotion.jump_gravity(_tuning.jump_height, _tuning.jump_rise_time_s)
	var jumping_now: bool = _buffer_left > 0.0 and _coyote_left > 0.0 and not frozen
	if jumping_now:
		_buffer_left = 0.0
		_coyote_left = 0.0
		_jumped_this_air = true
		on_floor = false
	_buffer_left = maxf(_buffer_left - delta, 0.0)

	var flat_wanted: Vector2 = Vector2(direction.x, direction.z) * speed
	var flat_now: Vector2 = Vector2(velocity.x, velocity.z)
	if on_floor or jumping_now:
		flat_now = flat_wanted
	else:
		flat_now = flat_now.move_toward(flat_wanted, _tuning.jump_air_accel * delta)
	velocity.x = flat_now.x
	velocity.z = flat_now.y

	# Vertical: average of the speed before and after gravity, so the jump reaches the data height
	# at any frame rate.
	var vy_before: float = launch_speed if jumping_now else _vy
	var vy_after: float = 0.0
	if on_floor:
		vy_before = 0.0
	else:
		var gravity: float = rise_gravity if vy_before > 0.0 else rise_gravity * _tuning.jump_fall_gravity_mult
		vy_after = maxf(vy_before - gravity * delta, -_tuning.jump_max_fall_speed)
		var cut_speed: float = launch_speed * _tuning.jump_release_cut_mult
		if not jump_held and vy_after > cut_speed:
			vy_after = cut_speed
	velocity.y = (vy_before + vy_after) * 0.5

	if now_moving:
		var yaw: float = PlayerMotion.turn_toward(rotation.y, PlayerMotion.yaw_for_direction(direction),
				_tuning.turn_rate_deg_per_s, delta)
		rotation.y = yaw
	move_and_slide()

	_vy = vy_after
	if is_on_ceiling() and _vy > 0.0:
		_vy = 0.0
	var airborne: bool = not is_on_floor()
	if jumping_now:
		jumped.emit()
	if _was_airborne and not airborne:
		landed.emit()
	_was_airborne = airborne

	if now_moving != _moving or now_running != _running:
		_moving = now_moving
		_running = now_running
		moved_state_changed.emit(_moving, _running)
	_update_animation(airborne)


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


func _update_animation(airborne: bool) -> void:
	if airborne and (_jumped_this_air or _air_time >= _tuning.jump_air_anim_delay_s):
		for candidate: StringName in PlayerMotion.air_animation_candidates(_vy > 0.0, _moving):
			if _animation_player == null or _animation_player.has_animation(candidate):
				_play_animation(candidate)
				return
	_play_animation(PlayerMotion.animation_for(_moving, _running))


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
