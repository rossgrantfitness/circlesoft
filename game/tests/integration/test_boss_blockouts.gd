extends TestCase
## The boss placeholder blockouts (task VS-24): the Hushmaster, Kasp, the giant junk mech and the arena pieces, in
## art/placeholder/bosses/. Checks node names, sizes and bones, so the Combat Programmer (VS-27, VS-28), the Animator (VS-25)
## and the Level Designer (VS-29) can rely on them. Built by scripts/tools/make_bosses.py. Ross makes the final art; his files
## (VS-A1, VS-A2) replace these on the same node and bone names.

const DIR: String = "res://art/placeholder/bosses/"
const ARENA_DIR: String = "res://art/placeholder/bosses/arena/"
const RED_PATH: String = "res://art/final/characters/red/red_ross_v1_rigged_ual.glb"
const PAIRS: Array[String] = ["fl", "fr", "bl", "br"]
const PLATE_NAMES: Array[String] = ["plate_chest_front", "plate_flank_l", "plate_flank_r", "plate_shoulder_l", "plate_shoulder_r", "plate_belly"]
const BANNED_WORDS: Array[String] = ["face", "eye", "mouth", "drill", "spiral", "sunglass"]


func _model(path: String) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, path + " should import (godot --headless --path game --import)")
	if packed == null:
		return Node3D.new()
	var model: Node3D = packed.instantiate() as Node3D
	add_to_root(model)
	return model


func _node(model: Node, node_name: String) -> Node3D:
	var found: Node = model.find_child(node_name, true, false)
	assert_not_null(found, "node %s exists" % node_name)
	return found as Node3D


func _mesh_box(node: Node3D) -> AABB:
	var mesh: MeshInstance3D = node as MeshInstance3D
	assert_not_null(mesh, "%s carries a mesh" % node.name)
	if mesh == null:
		return AABB()
	return mesh.global_transform * mesh.get_aabb()


## The box of every mesh under (and including) the node, in world space.
func _box(node: Node) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for item: Node in meshes:
		var instance: MeshInstance3D = item as MeshInstance3D
		var part: AABB = instance.global_transform * instance.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


func _sorted_size(box: AABB) -> Array[float]:
	var sizes: Array[float] = [box.size.x, box.size.y, box.size.z]
	sizes.sort()
	return sizes


func _triangles(model: Node) -> int:
	var count: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var index: PackedInt32Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array
			count += index.size() / 3
	return count


func _skeleton(model: Node) -> Skeleton3D:
	var found: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	assert_eq(found.size(), 1, "one Skeleton3D")
	return found[0] as Skeleton3D


func _bone_origin(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin


func _assert_red_bones(skeleton: Skeleton3D, label: String) -> void:
	var red: Skeleton3D = _skeleton(_model(RED_PATH))
	for i: int in red.get_bone_count():
		var bone: String = red.get_bone_name(i)
		var index: int = skeleton.find_bone(bone)
		assert_ge(index, 0, "%s has Red's bone %s" % [label, bone])
		if index < 0:
			continue
		var red_parent: int = red.get_bone_parent(i)
		var parent: int = skeleton.get_bone_parent(index)
		assert_eq(skeleton.get_bone_name(parent) if parent >= 0 else "", red.get_bone_name(red_parent) if red_parent >= 0 else "",
				"%s: %s hangs from the same bone as on Red" % [label, bone])


# ---- the Hushmaster ----

func test_hushmaster_has_its_named_parts() -> void:
	var model: Node3D = _model(DIR + "hushmaster.glb")
	for part: String in ["hull", "seat", "kasp_mount", "dish_base", "dish", "dish_port"]:
		_node(model, part)
	for pair: String in PAIRS:
		_node(model, "legs_" + pair)
		_node(model, "relay_" + pair)
		_node(model, "lamp_" + pair)


func test_hushmaster_has_eight_legs_in_four_pairs_each_its_own_node() -> void:
	var model: Node3D = _model(DIR + "hushmaster.glb")
	var pivots: Array[Vector3] = []
	for pair: String in PAIRS:
		var group: Node3D = _node(model, "legs_" + pair)
		assert_eq(group.get_child_count(), 2, "legs_%s holds exactly two legs" % pair)
		for number: int in [1, 2]:
			var leg: Node3D = _node(model, "leg_%s_%d" % [pair, number])
			assert_eq(leg.get_parent(), group, "leg_%s_%d hangs under legs_%s" % [pair, number, pair])
			assert_not_null(leg.find_child(leg.name + "_lower", false, false), "%s has a lower segment from the knee" % leg.name)
			assert_false(pivots.has(leg.global_position), "%s has its own pivot" % leg.name)
			pivots.append(leg.global_position)
			assert_almost_eq(leg.global_position.y, 3.7, 0.2, "%s pivots at the hip socket" % leg.name)
			assert_gt(absf(leg.global_position.x), 1.8, "%s hangs from the hull's side" % leg.name)
	assert_eq(pivots.size(), 8)


func test_each_leg_is_a_skinny_stilt_reaching_the_floor() -> void:
	var model: Node3D = _model(DIR + "hushmaster.glb")
	for pair: String in PAIRS:
		for number: int in [1, 2]:
			var leg: Node3D = _node(model, "leg_%s_%d" % [pair, number])
			var box: AABB = _box(leg)
			assert_almost_eq(box.position.y, 0.0, 0.1, "%s's foot is on the floor" % leg.name)
			var foot: Vector3 = box.get_center()
			var reach: float = Vector2(foot.x - leg.global_position.x, foot.z - leg.global_position.z).length()
			assert_gt(reach, 1.4, "%s spreads out from the hull" % leg.name)
			var thin: float = minf(box.size.x, box.size.z)
			assert_gt(box.size.y, 3.0, "%s is tall" % leg.name)
			assert_lt(thin, 5.0)
			var upper: AABB = _mesh_box(leg)
			assert_lt(minf(upper.size.y, minf(upper.size.x, upper.size.z)), 1.2, "%s is skinny, not a slab" % leg.name)


func test_hushmaster_body_is_about_four_by_three_metres_riding_high() -> void:
	var model: Node3D = _model(DIR + "hushmaster.glb")
	var hull: AABB = _mesh_box(_node(model, "hull"))
	assert_almost_eq(hull.size.x, 4.0, 0.3, "hull width (X)")
	assert_almost_eq(hull.size.z, 3.0, 0.3, "hull depth (Z)")
	assert_almost_eq(hull.position.y, 3.3, 0.3, "the hull's underside rides about 3.5 m up")
	assert_lt(hull.size.y, 1.8)
	var whole: AABB = _box(model)
	assert_almost_eq(whole.size.x, 12.0, 1.2, "legs about 12 m across")
	assert_almost_eq(whole.position.y, 0.0, 0.05, "stands on the floor")
	assert_almost_eq(whole.end.y, 8.0, 0.8, "the dish tops out near 8 m")
	assert_almost_eq(whole.get_center().x, 0.0, 0.2, "centred left to right")
	assert_lt(whole.size.z, 12.0, "fits the 40 m plateau with room for the stomp rings")


func test_four_relay_boxes_with_red_lamps() -> void:
	var model: Node3D = _model(DIR + "hushmaster.glb")
	var seen: Array[Vector3] = []
	for pair: String in PAIRS:
		var relay: Node3D = _node(model, "relay_" + pair)
		var lamp: Node3D = _node(model, "lamp_" + pair)
		var sizes: Array[float] = _sorted_size(_mesh_box(relay))
		assert_almost_eq(sizes[0], 0.5, 0.12, "relay_%s depth" % pair)
		assert_almost_eq(sizes[1], 0.6, 0.12, "relay_%s height" % pair)
		assert_almost_eq(sizes[2], 0.8, 0.12, "relay_%s width" % pair)
		assert_eq(lamp.get_parent(), relay, "the lamp is a child of its relay")
		assert_ge(_mesh_box(lamp).position.y, _mesh_box(relay).end.y - 0.05, "the lamp sits on top of the relay")
		var instance: MeshInstance3D = lamp as MeshInstance3D
		var material: BaseMaterial3D = instance.mesh.surface_get_material(0) as BaseMaterial3D
		if material != null:
			assert_gt(material.albedo_color.r, material.albedo_color.b * 0.8, "the lamp is pink-red, not cyan")
		assert_false(seen.has(relay.global_position), "each relay has its own place")
		seen.append(relay.global_position)
		var leg: Node3D = _node(model, "leg_%s_1" % pair)
		assert_lt(absf(relay.global_position.x - leg.global_position.x), 0.8, "relay_%s sits at its leg pair's hull socket" % pair)
		assert_gt(signf(relay.global_position.z), 0.0 if pair.begins_with("f") else -2.0, "front relays are at the front")
		assert_lt(signf(relay.global_position.z), 2.0 if pair.begins_with("f") else 0.0, "back relays are at the back")


func test_the_dish_the_seat_and_kasps_mount() -> void:
	var model: Node3D = _model(DIR + "hushmaster.glb")
	var dish: AABB = _mesh_box(_node(model, "dish"))
	assert_almost_eq(dish.size.x, 3.0, 0.4, "the dish is about 3 m across")
	assert_gt(dish.position.y, 4.8, "the dish stands above the hull")
	var port: Node3D = _node(model, "dish_port")
	assert_lt(port.global_position.y, dish.position.y + 1.0, "the service port is at the dish's base")
	assert_gt(port.global_position.z, _node(model, "dish_base").global_position.z, "the port faces front")
	var mount: Node3D = _node(model, "kasp_mount")
	var seat: AABB = _mesh_box(_node(model, "seat"))
	assert_gt(mount.global_position.y, 4.62, "Kasp sits above the hull's deck")
	assert_lt(mount.global_position.y, seat.end.y - 0.3, "on the cushion, not the headrest")
	assert_lt(absf(mount.global_position.x), 0.1, "on the middle line")


func test_hushmaster_stays_in_the_triangle_budget() -> void:
	var triangles: int = _triangles(_model(DIR + "hushmaster.glb"))
	assert_ge(triangles, 800, "some detail")
	assert_le(triangles, 6000, "inside the style guide (2,000 to 6,000)")


# ---- Kasp ----

func test_kasp_is_1_05_m_on_red_bones() -> void:
	var model: Node3D = _model(DIR + "kasp.glb")
	var skeleton: Skeleton3D = _skeleton(model)
	_assert_red_bones(skeleton, "Kasp")
	var box: AABB = _box(model)
	assert_almost_eq(box.end.y, 1.05, 0.06, "Kasp's height with the antenna pin")
	assert_almost_eq(box.position.y, 0.0, 0.02, "soles on the floor")
	assert_almost_eq(box.get_center().x, 0.0, 0.1, "centred")
	var red_head: float = _bone_origin(_skeleton(_model(RED_PATH)), "head").y
	assert_almost_eq(_bone_origin(skeleton, "head").y / red_head, 1.05 / 0.951, 0.03, "the skeleton is Red's, scaled by his height")
	assert_gt(_bone_origin(skeleton, "hand_l").x, 0.2, "left is +X, as on Red")
	assert_gt(_triangles(model), 300)
	assert_lt(_triangles(model), 6000)


# ---- the junk mech ----

func test_junk_mech_carries_red_bones_scaled_plus_its_mounts() -> void:
	var model: Node3D = _model(DIR + "junk_mech.glb")
	var skeleton: Skeleton3D = _skeleton(model)
	_assert_red_bones(skeleton, "junk mech")
	for bone: String in PLATE_NAMES + ["cockpit_core", "kasp_seat"]:
		assert_ge(skeleton.find_bone(bone), 0, "bone " + bone)
	assert_eq(skeleton.get_bone_name(skeleton.get_bone_parent(skeleton.find_bone("kasp_seat"))), "cockpit_core", "Kasp's seat is in the core")
	var red: Skeleton3D = _skeleton(_model(RED_PATH))
	var ratio: float = 40.0 / 0.951
	for bone: String in ["hips", "chest", "head", "hand_l", "foot_r", "weapon_socket"]:
		var expected: Vector3 = _bone_origin(red, bone) * ratio
		assert_lt(_bone_origin(skeleton, bone).distance_to(expected), 0.5, "%s sits at Red's place x %.1f" % [bone, ratio])
	assert_almost_eq(_bone_origin(skeleton, "weapon_socket").x < 0.0, true, "the right hand is on the -X side")


func test_junk_mech_is_forty_metres_standing_on_the_floor() -> void:
	var model: Node3D = _model(DIR + "junk_mech.glb")
	var box: AABB = _box(model)
	assert_almost_eq(box.end.y, 40.0, 1.0, "about 40 m")
	assert_almost_eq(box.position.y, 0.0, 0.1, "soles on the floor")
	assert_gt(box.size.x, 25.0, "wide, with the arms out")
	assert_lt(box.size.x, 40.0)
	assert_lt(box.size.z, 30.0)
	var triangles: int = _triangles(model)
	assert_ge(triangles, 3000, "busy scrap earns detail")
	assert_le(triangles, 14000, "inside the style guide (6,000 to 12,000, roughly)")


func test_junk_mech_plates_are_detachable_mesh_nodes_on_mount_bones() -> void:
	var model: Node3D = _model(DIR + "junk_mech.glb")
	var skeleton: Skeleton3D = _skeleton(model)
	for plate: String in PLATE_NAMES:
		var node: Node3D = _node(model, plate)
		var box: AABB = _mesh_box(node)
		var largest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
		assert_ge(largest, 6.0, plate + " is 6 m or more")
		assert_le(largest, 10.0, plate + " is 10 m or less")
		var mount: Vector3 = _bone_origin(skeleton, plate)
		assert_lt(box.get_center().distance_to(mount), 1.5, plate + " is drawn around its own mount bone")
		assert_ge(box.position.y, 14.0, plate + " is on the body, not the legs")
	assert_eq(PLATE_NAMES.size(), 6)


func test_junk_mech_core_pod_sits_in_the_chest_behind_the_front_plate() -> void:
	var model: Node3D = _model(DIR + "junk_mech.glb")
	var core: AABB = _mesh_box(_node(model, "cockpit_core"))
	assert_almost_eq(core.size.x, 4.0, 0.5, "a pod about 4 m across")
	assert_lt(core.size.y, 5.0)
	assert_lt(core.size.z, 5.0)
	var chest: Vector3 = _bone_origin(_skeleton(model), "chest")
	assert_lt(absf(core.get_center().x), 0.5, "on the middle line")
	assert_almost_eq(core.get_center().y, chest.y, 4.0, "in the chest")
	var front: AABB = _mesh_box(_node(model, "plate_chest_front"))
	assert_gt(front.position.z, core.end.z, "the front plate hangs in front of the core, so it must come off first")
	assert_lt(front.position.x, core.position.x, "and it is wider than the pod")
	assert_gt(front.end.x, core.end.x)
	var seat: Vector3 = _bone_origin(_skeleton(model), "kasp_seat")
	assert_true(core.has_point(seat), "Kasp's seat is inside the pod")


func test_junk_mech_has_floodlights_for_a_head_and_no_face() -> void:
	var model: Node3D = _model(DIR + "junk_mech.glb")
	var lights: AABB = _mesh_box(_node(model, "floodlights"))
	assert_gt(lights.position.y, 29.0, "the floodlight bank is up where the head is")
	assert_gt(lights.size.x, 4.0, "a wide bank of lamps, not two round eyes")
	assert_ge(_mesh_box(_node(model, "junk_mech_body")).end.y, 39.0, "the small jammer dish tops the head")
	var names: Array[String] = []
	for node: Node in model.find_children("*", "", true, false):
		names.append(String(node.name).to_lower())
	var skeleton: Skeleton3D = _skeleton(model)
	for i: int in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(i).to_lower())
	for word: String in BANNED_WORDS:
		for node_name: String in names:
			assert_false(node_name.contains(word), "no '%s' anywhere in the mech (original design, no face): %s" % [word, node_name])


func test_junk_mech_is_lopsided_not_symmetrical() -> void:
	var model: Node3D = _model(DIR + "junk_mech.glb")
	var body: AABB = _mesh_box(_node(model, "junk_mech_body"))
	var skeleton: Skeleton3D = _skeleton(model)
	assert_gt(absf(body.get_center().x), 0.05, "not centred exactly")
	assert_gt(body.end.x - 0.0, 8.0, "something sticks out to the left")
	assert_gt(0.0 - body.position.x, 8.0, "and to the right")
	var crane_x: float = _bone_origin(skeleton, "back").x
	assert_gt(absf(_box(model).get_center().x), -1.0)
	assert_almost_eq(crane_x, 0.0, 0.01, "(the back bone is on the middle line; the crane mast is offset from it in the mesh)")


# ---- the arena pieces ----

func test_arena_wall_and_gate_and_rail_sizes() -> void:
	var wall: AABB = _box(_model(ARENA_DIR + "arena_wall_segment.glb"))
	assert_almost_eq(wall.size.y, 8.0, 0.8, "the stockade is 8 m high")
	assert_almost_eq(wall.size.x, 12.2, 0.6, "a segment is one container long")
	assert_almost_eq(wall.position.y, 0.0, 0.05)
	var gate: AABB = _box(_model(ARENA_DIR + "arena_gate_post.glb"))
	assert_almost_eq(gate.size.y, 11.0, 1.0, "gate post")
	assert_almost_eq(gate.position.y, 0.0, 0.05)
	var rail: AABB = _box(_model(ARENA_DIR + "plateau_rail_segment.glb"))
	assert_almost_eq(rail.size.y, 1.1, 0.1, "the plateau rail is 1.1 m")
	assert_almost_eq(rail.size.x, 4.1, 0.3)
	assert_almost_eq(rail.position.y, 0.0, 0.05)


func test_arena_turret_pylon_has_a_base_head_and_barrel() -> void:
	var model: Node3D = _model(ARENA_DIR + "arena_turret_pylon.glb")
	var pylon: AABB = _mesh_box(_node(model, "pylon"))
	assert_almost_eq(pylon.end.y, 2.5, 0.15, "the pylon is 2.5 m")
	var base: Node3D = _node(model, "turret_base")
	var head: Node3D = _node(model, "turret_head")
	var barrel: Node3D = _node(model, "turret_barrel")
	assert_eq(head.get_parent(), base, "the head swivels on the base")
	assert_eq(barrel.get_parent(), head, "the barrel rides the head")
	var turret: AABB = _box(base)
	assert_almost_eq(turret.size.y, 1.2, 0.4, "the turret is about 1.2 m")
	assert_gt(_mesh_box(barrel).size.z, 0.8, "the barrel points forward (+Z)")
	assert_gt(_mesh_box(barrel).get_center().z, head.global_position.z, "forward of the swivel")


func test_scrap_piles_and_the_giant_heap_grow_with_their_names() -> void:
	var heights: Dictionary = {}
	for pile_name: String in ["scrap_pile_s", "scrap_pile_m", "scrap_pile_l", "scrap_heap_giant"]:
		var box: AABB = _box(_model(ARENA_DIR + pile_name + ".glb"))
		heights[pile_name] = box.end.y
		assert_almost_eq(box.position.y, 0.0, 0.7, pile_name + " sits on the floor")
	assert_almost_eq(float(heights["scrap_pile_s"]), 2.5, 0.9, "small pile about 2.5 m")
	assert_almost_eq(float(heights["scrap_pile_m"]), 4.5, 1.3, "medium pile about 4.5 m")
	assert_almost_eq(float(heights["scrap_pile_l"]), 6.0, 1.5, "large pile about 6 m")
	assert_almost_eq(float(heights["scrap_heap_giant"]), 35.0, 8.0, "the giant heap, 30 to 45 m")
	assert_lt(float(heights["scrap_pile_s"]), float(heights["scrap_pile_m"]))
	assert_lt(float(heights["scrap_pile_m"]), float(heights["scrap_pile_l"]))
