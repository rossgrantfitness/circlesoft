class_name PerfectDodge
extends RefCounted
## Perfect dodge test (contract 4.4): dash just before an enemy hit lands, from inside its threat zone.
## Pure: timestamps on the ATTACKER'S clock and a point-in-shape test.


## 0 <= impact - dash <= window_ms, and Red was inside the threat zone when she dashed.
static func is_perfect(dash_usec: int, impact_usec: int, window_ms: float, in_threat: bool) -> bool:
	if not in_threat:
		return false
	var lead_ms: float = float(impact_usec - dash_usec) / 1000.0
	return lead_ms >= 0.0 and lead_ms <= window_ms


## Is `point` (world) inside any of the hitbox shapes of an attack, each grown by `margin_m`? `boxes` are move
## hitbox dictionaries (offset / rot_deg in the attacker's local space); `attacker_xform` is its global transform.
static func point_in_zone(point: Vector3, attacker_xform: Transform3D, boxes: Array, margin_m: float) -> bool:
	for box: Variant in boxes:
		if point_in_box(point, attacker_xform, box, margin_m):
			return true
	return false


static func box_transform(attacker_xform: Transform3D, box: Dictionary) -> Transform3D:
	var offset: Array = box.get("offset", [0.0, 0.0, 0.0])
	var rot: Array = box.get("rot_deg", [0.0, 0.0, 0.0])
	var basis: Basis = Basis.from_euler(Vector3(deg_to_rad(float(rot[0])), deg_to_rad(float(rot[1])), deg_to_rad(float(rot[2]))))
	return attacker_xform * Transform3D(basis, Vector3(float(offset[0]), float(offset[1]), float(offset[2])))


static func point_in_box(point: Vector3, attacker_xform: Transform3D, box: Dictionary, margin_m: float) -> bool:
	var local: Vector3 = box_transform(attacker_xform, box).affine_inverse() * point
	match str(box.get("shape", "sphere")):
		"box":
			var size: Array = box.get("size", [1.0, 1.0, 1.0])
			return absf(local.x) <= float(size[0]) * 0.5 + margin_m \
					and absf(local.y) <= float(size[1]) * 0.5 + margin_m \
					and absf(local.z) <= float(size[2]) * 0.5 + margin_m
		"capsule":
			var radius: float = float(box.get("radius", 0.5))
			var half: float = maxf(float(box.get("height", 1.0)) * 0.5 - radius, 0.0)
			var nearest: Vector3 = Vector3(0.0, clampf(local.y, -half, half), 0.0)
			return local.distance_to(nearest) <= radius + margin_m
		_:
			return local.length() <= float(box.get("radius", 0.5)) + margin_m
