class_name LockOnMath
extends RefCounted
## Pure maths for lock-on and attack magnetism. No nodes, so tests can throw thousands of cases at it.
##
## A candidate is a Dictionary: {"pos": Vector3} (the point to aim at, in world space) plus anything
## the caller wants to carry along (the actor, its id). Every function that picks one returns an
## INDEX into the candidate list, or -1 for "nobody", so the caller maps it back to its own objects.
##
## Scoring (higher is better, -1.0 = not eligible): a target scores for being near the middle of the
## screen (angle from the camera's flat forward) and for being close. Numbers come from camera.json
## "lock" through `params`; the defaults below are only for tests that pass nothing.

const NOT_ELIGIBLE: float = -1.0
const MIN_LENGTH: float = 0.0001
const DEFAULT_MAX_RANGE_M: float = 16.0
const DEFAULT_MAX_ANGLE_DEG: float = 110.0
const DEFAULT_ANGLE_WEIGHT: float = 1.0
const DEFAULT_DISTANCE_WEIGHT: float = 0.6


## The flat (ground-plane) vector from `from` to `to`.
static func flat_offset(from: Vector3, to: Vector3) -> Vector3:
	return Vector3(to.x - from.x, 0.0, to.z - from.z)


## Unsigned angle (degrees) between two flat directions; 0 when either has no length.
static func flat_angle_deg(a: Vector3, b: Vector3) -> float:
	var fa: Vector3 = Vector3(a.x, 0.0, a.z)
	var fb: Vector3 = Vector3(b.x, 0.0, b.z)
	if fa.length() < MIN_LENGTH or fb.length() < MIN_LENGTH:
		return 0.0
	return rad_to_deg(fa.normalized().angle_to(fb.normalized()))


## How good a target is for a hard lock. -1.0 when out of range or too far round the back.
static func score(candidate: Dictionary, cam_forward: Vector3, player_pos: Vector3, params: Dictionary = {}) -> float:
	var max_range: float = float(params.get("max_range_m", DEFAULT_MAX_RANGE_M))
	var max_angle: float = float(params.get("max_angle_deg", DEFAULT_MAX_ANGLE_DEG))
	var angle_weight: float = float(params.get("angle_weight", DEFAULT_ANGLE_WEIGHT))
	var distance_weight: float = float(params.get("distance_weight", DEFAULT_DISTANCE_WEIGHT))
	var offset: Vector3 = flat_offset(player_pos, candidate["pos"] as Vector3)
	var distance: float = offset.length()
	if distance > max_range:
		return NOT_ELIGIBLE
	var angle: float = flat_angle_deg(cam_forward, offset)
	if angle > max_angle:
		return NOT_ELIGIBLE
	var angle_part: float = 1.0 - angle / maxf(max_angle, MIN_LENGTH)
	var distance_part: float = 1.0 - distance / maxf(max_range, MIN_LENGTH)
	return angle_weight * angle_part + distance_weight * distance_part


## Index of the best-scoring eligible candidate, or -1. Ties go to the earlier one.
static func best(candidates: Array[Dictionary], cam_forward: Vector3, player_pos: Vector3, params: Dictionary = {}) -> int:
	var best_index: int = -1
	var best_score: float = NOT_ELIGIBLE
	for i: int in candidates.size():
		var s: float = score(candidates[i], cam_forward, player_pos, params)
		if s > best_score:
			best_score = s
			best_index = i
	return best_index


## Where `pos` sits across the screen, in metres to the camera's right of the player (negative =
## left). Used to order targets left to right for flick switching.
static func lateral(pos: Vector3, player_pos: Vector3, cam_right: Vector3) -> float:
	var flat_right: Vector3 = Vector3(cam_right.x, 0.0, cam_right.z)
	if flat_right.length() < MIN_LENGTH:
		return 0.0
	return flat_offset(player_pos, pos).dot(flat_right.normalized())


## Switch target with a stick flick or mouse flick. `flick` is screen-style (x right, y down).
## Picks the nearest candidate on the flicked side of the current one (left to right across the
## screen, as seen from `cam_right`). A mostly vertical flick steps right (down) or left (up).
## Returns `current` when nothing lies that way, and -1 only when there are no candidates.
static func switch_index(candidates: Array[Dictionary], current: int, flick: Vector2,
		cam_right: Vector3 = Vector3.RIGHT, player_pos: Vector3 = Vector3.ZERO) -> int:
	if candidates.is_empty():
		return -1
	if current < 0 or current >= candidates.size():
		return 0
	if flick.length() < MIN_LENGTH:
		return current
	var direction: float = signf(flick.x) if absf(flick.x) >= absf(flick.y) else signf(flick.y)
	if direction == 0.0:
		return current
	var here: float = lateral(candidates[current]["pos"] as Vector3, player_pos, cam_right)
	var pick: int = current
	var pick_gap: float = INF
	for i: int in candidates.size():
		if i == current:
			continue
		var gap: float = (lateral(candidates[i]["pos"] as Vector3, player_pos, cam_right) - here) * direction
		if gap > 0.0 and gap < pick_gap:
			pick_gap = gap
			pick = i
	return pick


## Attack magnetism: the candidate inside `range_m` and `cone_deg` (half-angle each side) of
## `direction` that sits most nearly in that direction; closer wins a tie. -1 if none.
static func magnet_pick(candidates: Array[Dictionary], origin: Vector3, direction: Vector3,
		range_m: float, cone_deg: float) -> int:
	var best_index: int = -1
	var best_angle: float = INF
	var best_distance: float = INF
	for i: int in candidates.size():
		var offset: Vector3 = flat_offset(origin, candidates[i]["pos"] as Vector3)
		var distance: float = offset.length()
		if distance > range_m:
			continue
		var angle: float = flat_angle_deg(direction, offset)
		if angle > cone_deg:
			continue
		if angle < best_angle - 0.001 or (absf(angle - best_angle) <= 0.001 and distance < best_distance):
			best_angle = angle
			best_distance = distance
			best_index = i
	return best_index


## Yaw (radians, a model facing +Z) that turns `origin` toward `target`.
static func yaw_to(origin: Vector3, target: Vector3) -> float:
	var offset: Vector3 = flat_offset(origin, target)
	if offset.length() < MIN_LENGTH:
		return 0.0
	return atan2(offset.x, offset.z)


## Camera yaw (radians, 0 = looking toward -Z) that puts the camera behind `player` looking at `target`.
static func camera_yaw_for(player: Vector3, target: Vector3) -> float:
	var offset: Vector3 = flat_offset(player, target)
	if offset.length() < MIN_LENGTH:
		return 0.0
	# A camera with yaw y looks along (-sin y, 0, -cos y).
	return atan2(-offset.x, -offset.z)


## How far the camera turns this frame while the player runs with the look input idle. It follows
## her direction of travel only when she runs ACROSS the view (more than `dead_deg` away from straight
## ahead of the camera), and then only until she is back inside that dead zone, so a held diagonal
## never makes the camera chase her in a circle. Running back toward the camera (beyond `limit_deg`)
## never spins the view. Returns the signed yaw step in radians, at most `rate_deg * delta`.
static func recenter_step(cam_yaw: float, travel: Vector3, rate_deg: float, delta: float,
		dead_deg: float = 35.0, limit_deg: float = 135.0) -> float:
	var flat: Vector3 = Vector3(travel.x, 0.0, travel.z)
	if flat.length() < MIN_LENGTH:
		return 0.0
	var wanted: float = atan2(-flat.x, -flat.z)
	var diff: float = wrapf(wanted - cam_yaw, -PI, PI)
	var magnitude: float = absf(rad_to_deg(diff))
	if magnitude <= dead_deg or magnitude > limit_deg:
		return 0.0
	var weight: float = clampf((magnitude - dead_deg) / maxf(90.0 - dead_deg, 1.0), 0.15, 1.0)
	var step: float = deg_to_rad(rate_deg) * weight * delta
	var to_edge: float = diff - signf(diff) * deg_to_rad(dead_deg)
	return clampf(to_edge, -step, step)
