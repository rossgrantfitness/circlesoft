extends TestCase
## The giant-robot scale test blockouts (task CS-21): the small robot (about 3.5 m) and the huge robot (about 50 m), the scale props,
## and the per-scale effect numbers. Both robots copy Red's skeleton (bone names and hierarchy, scaled) so the same controller and
## the same retargeted clips drive them (scripts/tools/make_robots.py, retarget_ual.py robot_small / robot_huge).
## Placeholders only: Ross makes the final art. The handoff is docs/pivot/robot_scale_test.md.

const RED_PATH: String = "res://art/final/characters/red/red_ross_v1_rigged_ual.glb"
const RED_SETTINGS: String = "res://data/animation/retarget_red.json"
const ROBOTS: Dictionary = {
	"small": {
		"path": "res://art/placeholder/robots/robot_small_ual.glb", "settings": "res://data/animation/retarget_robot_small.json",
		"height_m": 3.5, "tri_min": 1500, "tri_max": 3000,
		"extra_bones": ["cockpit_hatch", "cockpit_seat", "boarding_point", "dock_anchor"],
	},
	"huge": {
		"path": "res://art/placeholder/robots/robot_huge_ual.glb", "settings": "res://data/animation/retarget_robot_huge.json",
		"height_m": 50.0, "tri_min": 3000, "tri_max": 6000,
		"extra_bones": ["dock_point", "dock_door_l", "dock_door_r", "dock_lift", "dock_approach"],
	},
}
const PROPS: Dictionary = {
	"prop_crate_small": [0.7, 1.0], "prop_crate_large": [1.8, 2.3], "prop_cargo_container": [2.3, 3.0], "prop_car_block": [1.2, 1.8],
	"prop_lamp_post": [6.0, 7.5], "prop_building_10m": [10.0, 15.0], "prop_building_20m": [20.0, 26.0], "prop_building_30m": [30.0, 36.0],
}
const PROP_DIR: String = "res://art/placeholder/robots/props/"
const LOOPING: Array[String] = ["idle", "walk", "run", "fall"]
const FX_DATA: String = "combat/fx"
const SHAKE_KEYS: Array[String] = ["amplitude_m", "duration_s", "frequency_hz"]


func _json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, path + " should exist")
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert_true(parsed is Dictionary, path + " should be a JSON object")
	return parsed as Dictionary if parsed is Dictionary else {}


func _model(path: String) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, path + " should import (godot --headless --path game --import)")
	if packed == null:
		return Node3D.new()
	var model: Node3D = packed.instantiate() as Node3D
	add_to_root(model)
	return model


func _skeleton(model: Node) -> Skeleton3D:
	var found: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	assert_eq(found.size(), 1, "one Skeleton3D")
	return found[0] as Skeleton3D


func _player(model: Node) -> AnimationPlayer:
	var found: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	assert_eq(found.size(), 1, "one AnimationPlayer")
	return found[0] as AnimationPlayer


## The model's box at rest (every mesh in the file, in the model's own space).
func _bounds(model: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		var part: AABB = instance.global_transform * instance.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


func _triangles(model: Node) -> int:
	var count: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			count += index.size() / 3
	return count


func _bone_names(skeleton: Skeleton3D) -> Array[String]:
	var out: Array[String] = []
	for i: int in skeleton.get_bone_count():
		out.append(skeleton.get_bone_name(i))
	return out


func _bone_origin(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin


# ---- the rigs ----

func test_the_robots_have_every_bone_of_red_with_the_same_parents() -> void:
	var red: Skeleton3D = _skeleton(_model(RED_PATH))
	for id: String in ROBOTS:
		var skeleton: Skeleton3D = _skeleton(_model(str(ROBOTS[id]["path"])))
		for bone: String in _bone_names(red):
			var index: int = skeleton.find_bone(bone)
			assert_ge(index, 0, "%s robot has Red's bone %s" % [id, bone])
			if index < 0:
				continue
			var red_parent: int = red.get_bone_parent(red.find_bone(bone))
			var parent: int = skeleton.get_bone_parent(index)
			var red_parent_name: String = red.get_bone_name(red_parent) if red_parent >= 0 else ""
			var parent_name: String = skeleton.get_bone_name(parent) if parent >= 0 else ""
			assert_eq(parent_name, red_parent_name, "%s: %s hangs from the same bone as on Red" % [id, bone])


func test_the_weapon_socket_sits_on_the_right_hand_and_the_extra_bones_are_there() -> void:
	for id: String in ROBOTS:
		var skeleton: Skeleton3D = _skeleton(_model(str(ROBOTS[id]["path"])))
		var socket: int = skeleton.find_bone("weapon_socket")
		assert_eq(skeleton.get_bone_name(skeleton.get_bone_parent(socket)), "hand_r", id + ": weapon_socket hangs from hand_r")
		assert_lt(skeleton.get_bone_global_rest(socket).origin.x, 0.0, id + ": the right hand is on the -X side")
		for bone: String in ROBOTS[id]["extra_bones"]:
			assert_ge(skeleton.find_bone(bone), 0, "%s robot has the %s node" % [id, bone])


func test_the_robots_stand_on_the_floor_at_the_expected_height() -> void:
	var red_box: AABB = _bounds(_model(RED_PATH))
	assert_almost_eq(red_box.end.y, 0.951, 0.01, "Red's own height, the yardstick")
	for id: String in ROBOTS:
		var box: AABB = _bounds(_model(str(ROBOTS[id]["path"])))
		var height: float = float(ROBOTS[id]["height_m"])
		assert_almost_eq(box.position.y, 0.0, 0.02, id + ": the soles are on the floor")
		assert_almost_eq(box.end.y, height, height * 0.02, id + ": height")
		assert_almost_eq(box.get_center().x, 0.0, height * 0.02, id + ": centred left to right")


func test_the_small_robot_is_about_three_and_a_half_times_red_and_the_huge_one_about_fourteen_times_that() -> void:
	var red_top: float = _bounds(_model(RED_PATH)).end.y
	var small_top: float = _bounds(_model(str(ROBOTS["small"]["path"]))).end.y
	var huge_top: float = _bounds(_model(str(ROBOTS["huge"]["path"]))).end.y
	assert_gt(small_top / red_top, 3.3)
	assert_lt(small_top / red_top, 4.0)
	assert_gt(huge_top / small_top, 12.0)
	assert_lt(huge_top / small_top, 16.0)


func test_triangle_counts_are_inside_the_style_budget() -> void:
	for id: String in ROBOTS:
		var triangles: int = _triangles(_model(str(ROBOTS[id]["path"])))
		assert_ge(triangles, int(ROBOTS[id]["tri_min"]), "%s robot has some detail (%d tris)" % [id, triangles])
		assert_le(triangles, int(ROBOTS[id]["tri_max"]), "%s robot is within the guide (%d tris)" % [id, triangles])


# ---- the docking bay and the boarding points ----

func test_the_small_robot_fits_the_huge_robots_chest_bay() -> void:
	var small: Node3D = _model(str(ROBOTS["small"]["path"]))
	var huge: Node3D = _model(str(ROBOTS["huge"]["path"]))
	var small_box: AABB = _bounds(small)
	var huge_skeleton: Skeleton3D = _skeleton(huge)
	var small_skeleton: Skeleton3D = _skeleton(small)
	var point: Vector3 = _bone_origin(huge_skeleton, "dock_point")
	var door_l: Vector3 = _bone_origin(huge_skeleton, "dock_door_l")
	var door_r: Vector3 = _bone_origin(huge_skeleton, "dock_door_r")
	assert_almost_eq(point.x, 0.0, 0.01, "the bay is on the middle line")
	assert_gt(point.y, 20.0, "the bay is up in the chest")
	assert_lt(point.y, 34.0)
	assert_gt(door_l.x - door_r.x, small_box.size.x + 1.0, "the doors are further apart than the small robot is wide")
	assert_gt((door_l.y - point.y) * 2.0, small_box.size.y * 1.1, "the bay is taller than the small robot")
	assert_gt(door_l.z, point.z, "the doors are at the front of the bay")
	assert_almost_eq(_bone_origin(small_skeleton, "dock_anchor").length(), 0.0, 0.01, "the small robot's anchor is the floor between its feet")
	assert_gt(_bone_origin(huge_skeleton, "dock_approach").z, 5.0, "the approach point is out in front of the huge robot")


func test_the_small_robots_hatch_and_boarding_point() -> void:
	var skeleton: Skeleton3D = _skeleton(_model(str(ROBOTS["small"]["path"])))
	var hatch: Vector3 = _bone_origin(skeleton, "cockpit_hatch")
	var seat: Vector3 = _bone_origin(skeleton, "cockpit_seat")
	var boarding: Vector3 = _bone_origin(skeleton, "boarding_point")
	assert_gt(hatch.y, 1.2, "the hatch is up on the torso")
	assert_lt(hatch.z, -0.3, "the hatch is in the back")
	assert_lt(boarding.z, hatch.z - 0.4, "Red boards from the ground behind it")
	assert_almost_eq(boarding.y, 0.0, 0.01, "on the floor")
	assert_gt(seat.y, 1.2, "the seat is in the chest")
	assert_gt(seat.z, hatch.z, "inside the hatch")


# ---- the clips ----

func test_both_robots_carry_every_clip_red_has_and_loop_the_loops() -> void:
	var red_clips: Array = _json(RED_SETTINGS)["clips"] as Array
	for id: String in ROBOTS:
		var player: AnimationPlayer = _player(_model(str(ROBOTS[id]["path"])))
		var settings: Dictionary = _json(str(ROBOTS[id]["settings"]))
		var names: Array[String] = []
		for clip: Variant in settings["clips"]:
			names.append(str((clip as Dictionary)["name"]))
		for clip: Variant in red_clips:
			var clip_name: String = str((clip as Dictionary)["name"])
			assert_has(names, clip_name, "%s settings bake %s" % [id, clip_name])
			assert_true(player.has_animation(clip_name), "%s robot has clip %s" % [id, clip_name])
		for clip_name: String in LOOPING:
			if player.has_animation(clip_name):
				assert_eq(player.get_animation(clip_name).loop_mode, Animation.LOOP_LINEAR, "%s: %s loops" % [id, clip_name])
		assert_false(player.get_animation("light_1").loop_mode == Animation.LOOP_LINEAR, id + ": an attack plays once")
		assert_ge(player.get_animation("run").get_length(), 0.5)
		assert_gt(player.get_animation("light_1").get_track_count(), 15, id + ": the clip drives the body")


func test_a_baked_clip_keeps_the_feet_near_the_floor() -> void:
	for id: String in ROBOTS:
		var model: Node3D = _model(str(ROBOTS[id]["path"]))
		var player: AnimationPlayer = _player(model)
		var skeleton: Skeleton3D = _skeleton(model)
		var height: float = float(ROBOTS[id]["height_m"])
		player.play("idle")
		player.seek(0.5, true)
		player.advance(0.0)
		var low: float = 1.0e9
		for bone: String in ["foot_l", "foot_r"]:
			low = minf(low, skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin.y)
		assert_lt(low, height * 0.06, id + ": a foot is on the ground in idle")


# ---- the props ----

func test_the_scale_props_have_believable_sizes() -> void:
	for prop_name: String in PROPS:
		var box: AABB = _bounds(_model(PROP_DIR + prop_name + ".glb"))
		var limits: Array = PROPS[prop_name]
		assert_ge(box.end.y, float(limits[0]), prop_name + " is tall enough")
		assert_le(box.end.y, float(limits[1]), prop_name + " is not too tall")
		assert_almost_eq(box.position.y, 0.0, 0.05, prop_name + " sits on the floor")


# ---- the effects, per scale ----

func test_footstep_and_landing_shakes_grow_slow_and_long_with_scale() -> void:
	var shakes: Dictionary = DataDB.get_dict(FX_DATA)["shake"]
	for id: String in ["step_small", "step_huge", "land_small", "land_huge"]:
		assert_true(shakes.has(id), "shake." + id)
		for key: String in SHAKE_KEYS:
			assert_true((shakes[id] as Dictionary).has(key), "%s.%s" % [id, key])
	assert_gt(float(shakes["step_huge"]["amplitude_m"]), float(shakes["step_small"]["amplitude_m"]) * 2.0)
	assert_gt(float(shakes["step_huge"]["duration_s"]), float(shakes["step_small"]["duration_s"]) * 1.5)
	assert_lt(float(shakes["step_huge"]["frequency_hz"]), float(shakes["step_small"]["frequency_hz"]) * 0.5, "a slow rumble, not a buzz")
	assert_gt(float(shakes["land_huge"]["amplitude_m"]), float(shakes["step_huge"]["amplitude_m"]) - 0.001, "the slam is at least a footstep")
	assert_gt(float(shakes["land_small"]["amplitude_m"]), float(shakes["step_small"]["amplitude_m"]), "a landing is heavier than a step")
	assert_gt(float(shakes["step_huge"]["suggested_mult"]), float(shakes["step_small"]["suggested_mult"]))


func test_dust_is_bigger_and_slower_at_large_scale() -> void:
	var fx: Dictionary = DataDB.get_dict(FX_DATA)
	var dust: Dictionary = fx["dust"]
	for id: String in ["step_small", "step_huge", "land_small", "land_huge"]:
		assert_true(dust.has(id), "dust." + id)
		for key: String in ["color", "count", "ring_radius_m", "speed_mps", "size_m", "grow", "rise_mps", "life_s", "alpha", "gravity"]:
			assert_true((dust[id] as Dictionary).has(key), "dust.%s.%s" % [id, key])
	var small: Dictionary = dust["step_small"]
	var huge: Dictionary = dust["step_huge"]
	assert_gt(float(huge["life_s"]), float(small["life_s"]) * 2.0, "the huge cloud hangs around longer")
	assert_gt(float((huge["size_m"] as Array)[0]), float((small["size_m"] as Array)[1]), "even its smallest puff is bigger than the small robot's biggest")
	assert_gt(float(huge["ring_radius_m"]), float(small["ring_radius_m"]) * 5.0)
	assert_true((dust["land_huge"] as Dictionary).has("shock_ring"), "the heavy slam throws a shock ring")
	for scale_id: String in ["small", "huge"]:
		var set: Dictionary = fx["scale_sets"][scale_id]
		assert_true(fx["shake"].has(set["step_shake"]) and fx["shake"].has(set["land_shake"]), scale_id + " shakes exist")
		assert_true(dust.has(set["step_dust"]) and dust.has(set["land_dust"]), scale_id + " dust exists")


func test_scale_dust_bursts_are_deterministic_and_fade_out() -> void:
	var dust: Dictionary = DataDB.get_dict(FX_DATA)["dust"]
	for id: String in ["step_small", "step_huge", "land_huge"]:
		var cfg: Dictionary = dust[id]
		var puffs: Array[Dictionary] = ScaleDust.puffs(cfg, 5)
		assert_eq(puffs.size(), int(cfg["count"]), id + ": one puff per count")
		assert_eq(ScaleDust.puffs(cfg, 5)[0]["velocity"], puffs[0]["velocity"], id + ": same seed, same burst")
		var life: float = float(cfg["life_s"])
		var start: Dictionary = ScaleDust.state(puffs[0], cfg, 0.0)
		var middle: Dictionary = ScaleDust.state(puffs[0], cfg, life * 0.5)
		var end: Dictionary = ScaleDust.state(puffs[0], cfg, life)
		assert_almost_eq(float(start["alpha"]), 0.0, 0.001, id + ": fades in from nothing")
		assert_gt(float(middle["alpha"]), 0.0)
		assert_almost_eq(float(end["alpha"]), 0.0, 0.001, id + ": gone at the end of its life")
		assert_gt(float(end["size"]), float(start["size"]), id + ": the puff grows")
		assert_ge((middle["position"] as Vector3).y, 0.0, id + ": never below the floor")
		assert_gt(Vector2((middle["position"] as Vector3).x, (middle["position"] as Vector3).z).length(), 0.0, id + ": it spreads out")
	assert_gt(float(ScaleDust.state(ScaleDust.puffs(dust["step_huge"], 5)[0], dust["step_huge"], 1.0)["size"]),
			float(ScaleDust.state(ScaleDust.puffs(dust["step_small"], 5)[0], dust["step_small"], 1.0)["size"]) * 5.0, "much bigger at large scale")
