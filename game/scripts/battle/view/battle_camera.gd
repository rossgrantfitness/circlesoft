class_name BattleCamera
extends Node3D
## The battle camera. Fixed: one pitch and yaw for the whole fight, and it NEVER rotates (the basis is set once
## in configure()). Two things move it, both along fixed axes:
##   push_in(name)   slides it toward the look-at point for a big moment, holds, and eases back (a slight push-in).
##   shake(...)      jumps it sideways / up and down by a decaying amount at a stepped rate (PSX chunky).
## Presets and numbers come from data/battle_stage/stage.json ("camera").

signal push_finished

const CAMERA_NODE: NodePath = ^"Camera3D"
const PUSH_PATH: String = "camera.push_in."
const HASH_SEED: float = 12.9898

var look_at_point: Vector3 = Vector3.ZERO
var base_position: Vector3 = Vector3.ZERO
## Current slide toward the look-at point (units) and current shake offset (world units, camera plane).
var push_amount: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO

## True when a director drives the pose (the "Dynamic" battle camera). False = the fixed calm framing.
var dynamic: bool = false
var current_pose: BattleCamPose = BattleCamPose.new()

var _basis: Basis = Basis.IDENTITY
var _camera: Camera3D = null
var _tuning: BattleStageTuning = null
var _toward: Vector3 = Vector3.FORWARD
var _right: Vector3 = Vector3.RIGHT
var _up: Vector3 = Vector3.UP
var _push_tween: Tween = null
var _shake_amplitude: float = 0.0
var _shake_left_s: float = 0.0
var _shake_total_s: float = 0.0
var _shake_step_s: float = 0.0
var _shake_clock_s: float = 0.0
var _shake_step_index: int = 0


func _ready() -> void:
	_ensure_camera()


func _process(delta: float) -> void:
	_update_shake(delta)
	_apply()


## Reads the fixed look from the tuning and points the camera. Safe to call again for another backdrop.
func configure(tuning: BattleStageTuning) -> void:
	_tuning = tuning
	var camera: Camera3D = _ensure_camera()
	camera.fov = tuning.number("camera.fov_deg")
	camera.near = tuning.number("camera.near")
	camera.far = tuning.number("camera.far")
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	look_at_point = tuning.vec3("camera.look_at")
	var pitch: float = deg_to_rad(tuning.number("camera.pitch_deg"))
	var yaw: float = deg_to_rad(tuning.number("camera.yaw_deg"))
	var away: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	_toward = -away
	base_position = look_at_point + away * tuning.number("camera.distance")
	top_level = true
	var basis: Basis = Basis.looking_at(_toward, Vector3.UP)
	_right = basis.x
	_up = basis.y
	_basis = basis
	dynamic = false
	current_pose = BattleCamPose.make(base_position, look_at_point, 0.0, camera.fov)
	transform = Transform3D(basis, base_position)
	camera.transform = Transform3D.IDENTITY
	camera.current = true
	_apply()


## The director's pose for this frame (position, target, roll, FOV). The push-in and shake still ride on top.
func apply_pose(pose: BattleCamPose) -> void:
	var camera: Camera3D = _ensure_camera()
	dynamic = true
	current_pose = pose
	look_at_point = pose.look
	base_position = pose.position
	_basis = pose.basis()
	_toward = -_basis.z
	_right = _basis.x
	_up = _basis.y
	camera.fov = pose.fov
	top_level = true
	_apply()


func get_camera() -> Camera3D:
	return _ensure_camera()


## The one rotation the camera ever has (tests check it does not change).
func fixed_basis() -> Basis:
	return _basis


## Slide toward the look-at point and back. `preset` is a key under camera.push_in (big_hit, boss_tell, ko, victory).
## Returns the total length in seconds. Ignored while a bigger push is running.
func push_in(preset: String) -> float:
	if _tuning == null:
		return 0.0
	var amount: float = _tuning.number(PUSH_PATH + preset + ".amount")
	var in_s: float = _tuning.number(PUSH_PATH + preset + ".in_ms") / 1000.0
	var hold_s: float = _tuning.number(PUSH_PATH + preset + ".hold_ms") / 1000.0
	var out_s: float = _tuning.number(PUSH_PATH + preset + ".out_ms") / 1000.0
	if _push_tween != null and _push_tween.is_valid():
		if push_amount >= amount:
			return in_s + hold_s + out_s
		_push_tween.kill()
	if not is_inside_tree():
		return in_s + hold_s + out_s
	_push_tween = create_tween()
	_push_tween.tween_property(self, "push_amount", amount, in_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_push_tween.tween_interval(hold_s)
	_push_tween.tween_property(self, "push_amount", 0.0, out_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_push_tween.finished.connect(push_finished.emit)
	return in_s + hold_s + out_s


## Jump the camera around by up to `amplitude` world units for `duration_ms`, new offset `step_hz` times a second,
## fading out. A stronger shake replaces a weaker one that is still running.
func shake(amplitude: float, duration_ms: float, step_hz: float) -> void:
	if amplitude <= 0.0 or duration_ms <= 0.0:
		return
	if _shake_left_s > 0.0 and _current_shake_strength() > amplitude:
		return
	_shake_amplitude = amplitude
	_shake_total_s = duration_ms / 1000.0
	_shake_left_s = _shake_total_s
	_shake_step_s = 1.0 / maxf(step_hz, 1.0)
	_shake_clock_s = 0.0
	_shake_step_index = 0
	shake_offset = _pick_offset(_shake_amplitude)


func is_shaking() -> bool:
	return _shake_left_s > 0.0


func is_pushing() -> bool:
	return _push_tween != null and _push_tween.is_valid() and _push_tween.is_running()


## Advance the shake by hand (tests and the capture scripts drive time themselves).
func step_shake(delta: float) -> void:
	_update_shake(delta)
	_apply()


func _ensure_camera() -> Camera3D:
	if _camera == null:
		_camera = get_node_or_null(CAMERA_NODE) as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		add_child(_camera)
	return _camera


func _update_shake(delta: float) -> void:
	if _shake_left_s <= 0.0:
		shake_offset = Vector2.ZERO
		return
	_shake_left_s = maxf(_shake_left_s - delta, 0.0)
	_shake_clock_s += delta
	while _shake_clock_s >= _shake_step_s:
		_shake_clock_s -= _shake_step_s
		_shake_step_index += 1
		shake_offset = _pick_offset(_current_shake_strength())
	if _shake_left_s <= 0.0:
		shake_offset = Vector2.ZERO


func _current_shake_strength() -> float:
	if _shake_total_s <= 0.0:
		return 0.0
	return _shake_amplitude * clampf(_shake_left_s / _shake_total_s, 0.0, 1.0)


## A repeatable pseudo-random direction per step (no global randomness), so shakes look the same every time.
func _pick_offset(strength: float) -> Vector2:
	var angle: float = fposmod(sin(float(_shake_step_index) * HASH_SEED + 4.1) * 43758.5453, 1.0) * TAU
	var flip: float = 1.0 if (_shake_step_index % 2 == 0) else -1.0
	return Vector2(cos(angle), sin(angle)) * strength * flip


func _apply() -> void:
	if _camera == null:
		return
	var position_now: Vector3 = base_position + _toward * push_amount + _right * shake_offset.x + _up * shake_offset.y
	transform = Transform3D(_basis, position_now)
