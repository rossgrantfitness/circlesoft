class_name DioramaMath
extends RefCounted
## Pure camera math for the fixed diorama camera. No nodes, so tests can call it directly.
## Screen coordinates here are NDC: x -1..1 left to right, y -1..1 bottom to top.

const HALF: float = 0.5
const MIN_DEPTH: float = 0.001
const MIN_PITCH_DOT: float = 0.1
const SAFE_FRAME_ITERATIONS: int = 8
const SAFE_FRAME_EPSILON: float = 0.0005


## The one fixed rotation of a room's camera. pitch_deg is how far it looks down; yaw_deg turns it
## around the vertical axis (0 = the camera sits on +Z of the room looking toward -Z).
static func orientation(pitch_deg: float, yaw_deg: float) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(-pitch_deg), deg_to_rad(yaw_deg), 0.0))


## Where the camera sits for a given look-at point.
static func camera_origin(focus: Vector3, cam_basis: Basis, distance: float) -> Vector3:
	return focus + cam_basis.z * distance


## Orthographic size (full height in world units) that frames the same area as a perspective
## camera at `distance`, so flipping modes does not change the shot.
static func matching_ortho_size(fov_deg: float, distance: float) -> float:
	return 2.0 * distance * tan(deg_to_rad(fov_deg) * HALF)


## Half height of the visible area at a given depth (distance in front of the camera).
static func half_height(depth: float, perspective: bool, fov_deg: float, ortho_size: float) -> float:
	if perspective:
		return maxf(depth, MIN_DEPTH) * tan(deg_to_rad(fov_deg) * HALF)
	return ortho_size * HALF


## NDC position of a world point seen by a camera (x right, y up). Matches Godot's keep-height FOV.
static func project(world: Vector3, cam_origin: Vector3, cam_basis: Basis, perspective: bool,
		fov_deg: float, ortho_size: float, aspect: float) -> Vector2:
	var view: Vector3 = cam_basis.inverse() * (world - cam_origin)
	var half_h: float = half_height(-view.z, perspective, fov_deg, ortho_size)
	return Vector2(view.x / (half_h * aspect), view.y / half_h)


## How much of a frame-rate-independent smoothing step to take. smoothing <= 0 means snap.
static func smooth_alpha(smoothing: float, delta: float) -> float:
	if smoothing <= 0.0:
		return 1.0
	return 1.0 - exp(-smoothing * delta)


## Clamps a look-at point to the room's camera bounds on X and Z. Height is left alone.
## A bounds box with no width on an axis pins the camera on that axis (tiny rooms).
static func clamp_to_bounds(focus: Vector3, bounds: AABB) -> Vector3:
	var lo: Vector3 = bounds.position
	var hi: Vector3 = bounds.end
	return Vector3(clampf(focus.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)), focus.y,
			clampf(focus.z, minf(lo.z, hi.z), maxf(lo.z, hi.z)))


## Slides `focus` along the ground, the least amount needed, so that `anchor` lands inside the
## safe frame. `margin` is the fraction of the screen kept clear on every side (0.2 = the middle 60%).
## Returns the new focus. The camera's rotation is never touched.
static func slide_into_safe_frame(focus: Vector3, anchor: Vector3, cam_basis: Basis, distance: float,
		perspective: bool, fov_deg: float, ortho_size: float, aspect: float, margin: float) -> Vector3:
	var limit: float = maxf(1.0 - 2.0 * margin, 0.0)
	var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var forward: Vector3 = Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var forward_up: float = maxf(forward.dot(cam_basis.y), MIN_PITCH_DOT)
	var result: Vector3 = focus
	for i: int in SAFE_FRAME_ITERATIONS:
		var origin: Vector3 = camera_origin(result, cam_basis, distance)
		var ndc: Vector2 = project(anchor, origin, cam_basis, perspective, fov_deg, ortho_size, aspect)
		var over_x: float = ndc.x - clampf(ndc.x, -limit, limit)
		var over_y: float = ndc.y - clampf(ndc.y, -limit, limit)
		if absf(over_x) < SAFE_FRAME_EPSILON and absf(over_y) < SAFE_FRAME_EPSILON:
			break
		var depth: float = -(cam_basis.inverse() * (anchor - origin)).z
		var half_h: float = half_height(depth, perspective, fov_deg, ortho_size)
		result += right * (over_x * half_h * aspect)
		result += forward * (over_y * half_h / forward_up)
	return result
