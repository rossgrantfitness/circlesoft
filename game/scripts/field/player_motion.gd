class_name PlayerMotion
extends RefCounted
## Pure movement math for Red. No nodes, so tests can check it directly.

const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"
const ANIM_RUN: StringName = &"run"
const MIN_FLAT_LENGTH: float = 0.001


## Flat (ground-plane) forward and right of a camera. Looking straight down falls back to the
## camera's up axis so "up on the stick" still means "toward the top of the screen".
static func flat_forward(cam_basis: Basis) -> Vector3:
	var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z)
	if forward.length() < MIN_FLAT_LENGTH:
		forward = Vector3(cam_basis.y.x, 0.0, cam_basis.y.z)
	return forward.normalized()


static func flat_right(cam_basis: Basis) -> Vector3:
	var forward: Vector3 = flat_forward(cam_basis)
	return Vector3(-forward.z, 0.0, forward.x)


## World direction (unit length, or zero for no input) for a stick vector as read by
## Input.get_vector(left, right, up, down): x right, y down.
static func camera_relative_direction(stick: Vector2, cam_basis: Basis) -> Vector3:
	if stick.length() < MIN_FLAT_LENGTH:
		return Vector3.ZERO
	var world: Vector3 = flat_right(cam_basis) * stick.x + flat_forward(cam_basis) * -stick.y
	return world.normalized()


## Run when the run button is held or the stick is tilted all the way; otherwise walk.
static func is_running(stick: Vector2, run_held: bool, run_threshold: float) -> bool:
	return run_held or stick.length() >= run_threshold


static func target_speed(stick: Vector2, run_held: bool, walk_speed: float, run_speed: float,
		run_threshold: float) -> float:
	if stick.length() < MIN_FLAT_LENGTH:
		return 0.0
	return run_speed if is_running(stick, run_held, run_threshold) else walk_speed


## Yaw (radians, around Y) that turns a model facing +Z toward `direction`.
static func yaw_for_direction(direction: Vector3) -> float:
	return atan2(direction.x, direction.z)


## Turns `current_yaw` toward `wanted_yaw` by at most rate_deg * delta, taking the short way round.
static func turn_toward(current_yaw: float, wanted_yaw: float, rate_deg: float, delta: float) -> float:
	var difference: float = wrapf(wanted_yaw - current_yaw, -PI, PI)
	var step: float = deg_to_rad(rate_deg) * delta
	return current_yaw + clampf(difference, -step, step)


static func animation_for(moving: bool, running: bool) -> StringName:
	if not moving:
		return ANIM_IDLE
	return ANIM_RUN if running else ANIM_WALK
