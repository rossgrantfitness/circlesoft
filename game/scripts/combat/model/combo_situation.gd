class_name ComboSituation
extends RefCounted
## Reads the world for ComboSelector (docs/pivot/kh_combo_design.md): which target the next swing is for, how far,
## whether it is in the air, launchable or guarding, and how many enemies crowd Red. Static helpers that take
## plain nodes; the selector itself never touches a node.
##
## "Guarding" is the design's "armored or its guard is up": the fighter's is_armored() or is_guarding().
## "Launchable" is the fighter's `launchable` flag (enemies.json).

## The target a press is about: the hard lock-on, else the enemy nearest the aim direction inside the cone.
## `enemies` is every living enemy (Node3D). `lock_on` may be null. Range and cone come from the lunge's magnet block.
static func pick_target(red: Node3D, enemies: Array, lock_on: LockOn, aim_dir: Vector3, facing: Vector3,
		range_m: float, cone_deg: float) -> Node3D:
	if lock_on != null:
		return lock_on.magnet_target(aim_dir, facing, range_m, cone_deg)
	var list: Array[Dictionary] = []
	var nodes: Array[Node3D] = []
	for item: Variant in enemies:
		var node: Node3D = item as Node3D
		if node != null and is_instance_valid(node):
			list.append({"pos": node.global_position})
			nodes.append(node)
	var dir: Vector3 = aim_dir if aim_dir.length() > 0.001 else facing
	var index: int = LockOnMath.magnet_pick(list, red.global_position, dir, range_m, cone_deg)
	return nodes[index] if index >= 0 else null


## The target-and-crowd part of the situation. `target` may be null. `params` is combo.json "params".
static func describe(red_pos: Vector3, target: Node3D, enemies: Array, params: Dictionary) -> Dictionary:
	var out: Dictionary = {"target_exists": false, "target_dist_m": INF, "target_airborne": false, "target_launchable": true,
			"target_guarding": false, "enemies_near": 0}
	var reach: float = float(params.get("lunge_max_dist_m", 12.0))
	if target != null and is_instance_valid(target):
		var dist: float = LockOnMath.flat_offset(red_pos, target.global_position).length()
		if dist <= reach:
			out["target_exists"] = true
			out["target_dist_m"] = dist
			out["target_airborne"] = target.has_method(&"is_airborne") and bool(target.call(&"is_airborne"))
			out["target_launchable"] = bool(target.get(&"launchable")) if target.get(&"launchable") != null else true
			out["target_guarding"] = (target.has_method(&"is_armored") and bool(target.call(&"is_armored"))) \
					or (target.has_method(&"is_guarding") and bool(target.call(&"is_guarding")))
	var near: float = float(params.get("near_radius_m", 3.0))
	var count: int = 0
	for item: Variant in enemies:
		var node: Node3D = item as Node3D
		if node != null and is_instance_valid(node) and LockOnMath.flat_offset(red_pos, node.global_position).length() <= near:
			count += 1
	out["enemies_near"] = count
	return out
