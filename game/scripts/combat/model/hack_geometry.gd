class_name HackGeometry
extends RefCounted
## The little bits of geometry the hacks need, pure so tests can throw cases at them: does a Zap Drone's flight path
## touch a standing fighter, is something inside the EMP ring, how far round from where she is aiming is a thing.

## Distance from `point` to the vertical segment standing on `base` and `height` tall.
static func distance_to_upright(point: Vector3, base: Vector3, height: float) -> float:
	var y: float = clampf(point.y, base.y, base.y + maxf(height, 0.0))
	return point.distance_to(Vector3(base.x, y, base.z))


## Does the straight flight from `from` to `to` pass within `radius` of an upright capsule axis (feet at `base`, `height` tall)?
## Walks the segment in `step` metre bites, so a fast drone cannot jump over a fighter between two frames.
static func segment_hits_upright(from: Vector3, to: Vector3, base: Vector3, height: float, radius: float, step: float = 0.15) -> bool:
	var length: float = from.distance_to(to)
	var count: int = maxi(int(ceilf(length / maxf(step, 0.01))), 1)
	for i: int in range(count + 1):
		var point: Vector3 = from.lerp(to, float(i) / float(count))
		if distance_to_upright(point, base, height) <= radius:
			return true
	return false


## Flat (ground plane) distance between two points.
static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Is a fighter at `base` (with body `radius`) inside an EMP ring of `ring_radius` around `centre`? The body's edge counts.
static func in_ring(centre: Vector3, base: Vector3, body_radius: float, ring_radius: float) -> bool:
	return flat_distance(centre, base) - maxf(body_radius, 0.0) <= ring_radius


## Unsigned flat angle in degrees between the way she is aiming and the way to a thing. 0 when either has no length.
static func aim_angle_deg(from: Vector3, to: Vector3, aim: Vector3) -> float:
	return LockOnMath.flat_angle_deg(aim, LockOnMath.flat_offset(from, to))
