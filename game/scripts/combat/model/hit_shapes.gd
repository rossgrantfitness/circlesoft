class_name HitShapes
extends RefCounted
## The maths of the two boss hitbox shapes (docs/slice/slice_tech_plan.md 6.4), pure so tests can throw cases at it.
##
## RING   an expanding band on the floor around a point (the Leg Stomp's shock ring). Box keys: inner_start_m (radius at the start),
##        width_m (how thick the band is), expand_mps, max_radius_m (it ends there), clear_height_m (a target whose feet are higher
##        than this above the ring's floor is not hit: jump it).
## BEAM   a long box laid along the floor from a point, swung round like a lighthouse (the Dish Sweep). Box keys: length_m,
##        width_m, height_m (how high above the floor it reaches), sweep_deg (the whole fan), sweep_deg_per_s.
##        The beam starts at `start_yaw` and swings toward `direction` (+1 or -1).
## Yaw is the game's: 0 faces +Z, positive turns toward +X.
## `radius` is the target's body radius (the edge of the body counts); `feet_y` and `height` its vertical extent.


# ---- ring ----

static func ring_radius(box: Dictionary, age_s: float) -> float:
	return float(box.get("inner_start_m", 0.5)) + float(box.get("expand_mps", 8.0)) * maxf(age_s, 0.0)


## Has the ring spread past its maximum (the box is done)?
static func ring_finished(box: Dictionary, age_s: float) -> bool:
	return ring_radius(box, age_s) - float(box.get("width_m", 1.0)) > float(box.get("max_radius_m", 7.0))


static func ring_hits(centre: Vector3, box: Dictionary, age_s: float, target: Vector3, radius: float) -> bool:
	var clear: float = float(box.get("clear_height_m", 0.6))
	if clear > 0.0 and target.y - centre.y >= clear:
		return false                 # jumped it
	var outer: float = minf(ring_radius(box, age_s), float(box.get("max_radius_m", 7.0)))
	var inner: float = maxf(outer - float(box.get("width_m", 1.0)), 0.0)
	var distance: float = Vector2(target.x - centre.x, target.z - centre.z).length()
	return distance + radius >= inner and distance - radius <= outer


# ---- beam ----

## Where the beam points `age_s` after it started: the start yaw plus the sweep so far (never past `sweep_deg`).
static func beam_yaw(box: Dictionary, age_s: float, start_yaw: float, direction: float = 1.0) -> float:
	var swept_deg: float = minf(float(box.get("sweep_deg_per_s", 55.0)) * maxf(age_s, 0.0), float(box.get("sweep_deg", 80.0)))
	return start_yaw + signf(direction) * deg_to_rad(swept_deg)


static func beam_finished(box: Dictionary, age_s: float) -> bool:
	return float(box.get("sweep_deg_per_s", 55.0)) * maxf(age_s, 0.0) >= float(box.get("sweep_deg", 80.0)) + 0.001 \
			and age_s * 1000.0 > float(box.get("hold_ms", 0.0))


static func beam_hits(origin: Vector3, yaw: float, box: Dictionary, target: Vector3, radius: float, height: float) -> bool:
	var forward: Vector2 = Vector2(sin(yaw), cos(yaw))
	var right: Vector2 = Vector2(cos(yaw), -sin(yaw))
	var offset: Vector2 = Vector2(target.x - origin.x, target.z - origin.z)
	var along: float = offset.dot(forward)
	var across: float = offset.dot(right)
	if along < -radius or along > float(box.get("length_m", 30.0)) + radius:
		return false
	if absf(across) > float(box.get("width_m", 1.0)) * 0.5 + radius:
		return false
	var top: float = origin.y + float(box.get("height_m", 1.4))
	return target.y + height >= origin.y and target.y <= top


## The fan the beam will cover, as the two edge yaws (for the floor line that draws it before anything hurts).
static func fan_edges(box: Dictionary, start_yaw: float, direction: float) -> Vector2:
	return Vector2(start_yaw, start_yaw + signf(direction) * deg_to_rad(float(box.get("sweep_deg", 80.0))))
