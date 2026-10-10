class_name BattleCamMath
extends RefCounted
## Small pure helpers for the battle camera director: easing, the look-at basis with roll, and a projection that
## answers "where on the screen (0..1) does this world point land" for a pose, without needing a Camera3D.
## The director's framing solver and the tests both use it.

const BEHIND: Vector2 = Vector2(-10.0, -10.0)
const MIN_DEPTH: float = 0.05


## 0..1 -> 0..1. Kinds: linear, in, out, inout (smoothstep), cut (jumps at the end).
static func ease_value(kind: String, t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	match kind:
		"in":
			return x * x
		"out":
			return 1.0 - (1.0 - x) * (1.0 - x)
		"inout":
			return x * x * (3.0 - 2.0 * x)
		"cut":
			return 1.0 if x >= 1.0 else 0.0
	return x


## Camera basis looking from `from` at `to`, rolled `roll_deg` about the view axis (positive = clockwise on screen).
static func basis_for(from: Vector3, to: Vector3, roll_deg: float) -> Basis:
	var forward: Vector3 = (to - from)
	if forward.length() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var up: Vector3 = Vector3.UP
	if absf(forward.dot(Vector3.UP)) > 0.999:
		up = Vector3.BACK
	var base: Basis = Basis.looking_at(forward, up)
	return Basis(forward, deg_to_rad(-roll_deg)) * base


## Where `point` lands on screen for a camera at `from` looking at `to` (0..1 both ways, y down), or BEHIND.
static func project(from: Vector3, to: Vector3, roll_deg: float, fov_deg: float, aspect: float, point: Vector3) -> Vector2:
	var local: Vector3 = basis_for(from, to, roll_deg).inverse() * (point - from)
	if -local.z < MIN_DEPTH:
		return BEHIND
	var tan_half: float = tan(deg_to_rad(fov_deg) * 0.5)
	var ndc_x: float = local.x / (-local.z) / (tan_half * aspect)
	var ndc_y: float = local.y / (-local.z) / tan_half
	return Vector2(0.5 + ndc_x * 0.5, 0.5 - ndc_y * 0.5)


static func project_pose(pose: BattleCamPose, aspect: float, point: Vector3) -> Vector2:
	return project(pose.position, pose.look, pose.roll, pose.fov, aspect, point)


## Angle in degrees between two camera orientations.
static func angle_deg_between(a: Basis, b: Basis) -> float:
	return rad_to_deg(a.get_rotation_quaternion().angle_to(b.get_rotation_quaternion()))
