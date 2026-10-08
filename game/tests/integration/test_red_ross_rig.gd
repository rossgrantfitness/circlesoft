extends TestCase
## Ross's Red, rigged (scripts/tools/rig_red.py): the model contract in docs/pivot/combat_api.md section 5. Checks the rigged
## file only; Ross's original (red_ross_v1.glb) is never touched. Missing OPTIONAL clips are listed, not failed, because the
## procedural fallbacks cover them.

const RED_PATH: String = "res://art/final/characters/red/red_ross_v1_rigged.glb"
const TRIANGLES: int = 1614                # Ross's mesh, unchanged by rigging
const TRIANGLE_CAP: int = 5000
const MAX_TEXTURE_PX: int = 512
const HEIGHT_M: float = 0.951
const REQUIRED_BONES: Array[String] = ["root", "hips", "spine", "chest", "neck", "head", "upper_arm_l", "forearm_l", "hand_l",
		"upper_arm_r", "forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r", "weapon_socket"]
const OPTIONAL_BONES: Array[String] = ["ear_l", "ear_l_2", "ear_r", "ear_r_2", "tail", "prop_socket", "head_gear", "back", "lamp_socket",
		"shoulder_l", "shoulder_r"]
const REQUIRED_CLIPS: Array[String] = ["idle", "run", "jump_up", "fall", "land", "dash", "light_1", "light_2", "light_3", "heavy",
		"launcher", "air_1", "air_2", "air_3", "parry", "hurt", "knockdown"]
const OPTIONAL_CLIPS: Array[String] = ["walk", "air_dash", "parry_success", "getup"]
const LOOPING: Array[String] = ["idle", "run", "fall", "walk"]
const MAX_CLIP_S: float = 1.7


func _red() -> Node3D:
	var packed: PackedScene = load(RED_PATH) as PackedScene
	assert_not_null(packed, "red_ross_v1_rigged.glb should import (godot --headless --path game --import)")
	var model: Node3D = packed.instantiate() as Node3D
	own(model)
	return model


func _skeleton(model: Node) -> Skeleton3D:
	var found: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	assert_eq(found.size(), 1, "one Skeleton3D")
	return found[0] as Skeleton3D


func _player(model: Node) -> AnimationPlayer:
	var found: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	assert_eq(found.size(), 1, "one AnimationPlayer")
	return found[0] as AnimationPlayer


func _meshes(model: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out


func _most_keys(animation: Animation) -> int:
	var most: int = 0
	for track: int in animation.get_track_count():
		most = maxi(most, animation.track_get_key_count(track))
	return most


func test_has_every_required_bone_and_the_optional_ones() -> void:
	var skeleton: Skeleton3D = _skeleton(_red())
	for bone: String in REQUIRED_BONES:
		assert_ge(skeleton.find_bone(bone), 0, "bone " + bone)
	for bone: String in OPTIONAL_BONES:
		assert_ge(skeleton.find_bone(bone), 0, "this rig carries the optional bone " + bone)
	assert_ge(skeleton.get_bone_count(), 25)


func test_the_weapon_socket_is_under_the_right_hand_with_y_along_the_blade() -> void:
	var skeleton: Skeleton3D = _skeleton(_red())
	var socket: int = skeleton.find_bone("weapon_socket")
	assert_eq(skeleton.get_bone_name(skeleton.get_bone_parent(socket)), "hand_r", "weapon_socket hangs from hand_r")
	var rest: Transform3D = skeleton.get_bone_global_rest(socket)
	assert_gt(rest.basis.y.y, 0.4, "the blade points up")
	assert_gt(rest.basis.y.z, 0.2, "and forward (+Z)")
	assert_lt(rest.origin.x, -0.2, "the right hand is on the -X side")
	assert_gt(rest.origin.y, 0.25, "the fist is at hip height or above")
	assert_lt(rest.origin.y, 0.6)


func test_faces_plus_z_with_the_origin_at_the_feet_and_her_height_kept() -> void:
	var model: Node3D = _red()
	var skeleton: Skeleton3D = _skeleton(model)
	var low: float = INF
	var high: float = -INF
	for mesh_instance: MeshInstance3D in _meshes(model):
		var box: AABB = mesh_instance.get_aabb()
		low = minf(low, box.position.y)
		high = maxf(high, box.end.y)
	assert_almost_eq(low, 0.0, 0.01, "feet on the floor")
	assert_almost_eq(high - low, HEIGHT_M, 0.02, "Ross's height, 0.95 m, kept")
	# the tail sits behind her, the toes in front: both prove +Z is forward
	var tail: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("tail")).origin
	var hips: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("hips")).origin
	assert_lt(tail.z, hips.z - 0.05, "the tail is behind her (-Z)")
	var foot: int = skeleton.find_bone("foot_l")
	var foot_tip: Vector3 = skeleton.get_bone_global_rest(foot).origin + skeleton.get_bone_global_rest(foot).basis.y * skeleton.get_bone_rest(foot).origin.length()
	assert_gt(skeleton.get_bone_global_rest(foot).basis.y.z, 0.5, "the feet point forward (+Z)")
	assert_almost_eq(hips.x, 0.0, 0.01, "centred on x")
	assert_almost_eq(foot_tip.y, 0.0, 0.1)


func test_every_required_clip_exists_and_the_optional_ones_are_listed() -> void:
	var player: AnimationPlayer = _player(_red())
	var missing_optional: Array[String] = []
	for clip: String in REQUIRED_CLIPS:
		assert_true(player.has_animation(clip), "clip " + clip)
	for clip: String in OPTIONAL_CLIPS:
		if not player.has_animation(clip):
			missing_optional.append(clip)
	assert_eq(missing_optional.size(), 0, "optional clips missing: %s" % [missing_optional])


func test_clips_are_stepped_short_loop_right_and_have_key_poses() -> void:
	var player: AnimationPlayer = _player(_red())
	for clip: String in REQUIRED_CLIPS + OPTIONAL_CLIPS:
		var animation: Animation = player.get_animation(clip)
		assert_not_null(animation, clip)
		assert_le(animation.length, MAX_CLIP_S, clip + " stays short")
		assert_gt(animation.length, 0.2, clip + " is not a single pose")
		var looped: bool = LOOPING.has(clip)
		assert_eq(animation.loop_mode == Animation.LOOP_LINEAR, looped, clip + (" loops" if looped else " plays once"))
		for track: int in animation.get_track_count():
			assert_eq(animation.track_get_interpolation_type(track), Animation.INTERPOLATION_NEAREST, "%s track %d is stepped" % [clip, track])
		# two to five key poses (plus the closing key of a loop): never a baked, per-frame clip
		var keys: int = _most_keys(animation)
		assert_ge(keys, 2, clip + " has at least two key poses")
		assert_le(keys, 30, clip + " is not a long mocap clip")


func _rotation_at(animation: Animation, bone: String, time: float) -> Quaternion:
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D and str(animation.track_get_path(track)).ends_with(":" + bone):
			return animation.rotation_track_interpolate(track, time)
	fail("no rotation track for " + bone)
	return Quaternion.IDENTITY


func test_attack_poses_are_held_and_change_at_the_frames_the_move_data_assumes() -> void:
	# docs/pivot/combat_api.md example: anim.keys at clip_s 0, 0.133 (frame 2) and 0.267 (frame 4); the clips are stepped,
	# so each key pose is held until the next one.
	var animation: Animation = _player(_red()).get_animation("light_1")
	var wind_up: Quaternion = _rotation_at(animation, "upper_arm_r", 0.0)
	var held: Quaternion = _rotation_at(animation, "upper_arm_r", 0.07)
	var strike: Quaternion = _rotation_at(animation, "upper_arm_r", 2.0 / 15.0 + 0.005)
	var strike_held: Quaternion = _rotation_at(animation, "upper_arm_r", 3.0 / 15.0)
	var follow: Quaternion = _rotation_at(animation, "upper_arm_r", 4.0 / 15.0 + 0.005)
	assert_true(wind_up.is_equal_approx(held), "the wind-up is held until frame 2")
	assert_false(wind_up.is_equal_approx(strike), "the strike pose arrives at frame 2")
	assert_true(strike.is_equal_approx(strike_held), "and is held")
	assert_false(strike.is_equal_approx(follow), "the follow-through arrives at frame 4")


func test_triangles_textures_and_influences() -> void:
	var model: Node3D = _red()
	var total: int = 0
	for mesh_instance: MeshInstance3D in _meshes(model):
		for surface: int in mesh_instance.mesh.get_surface_count():
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
			total += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			assert_ge(bones.size(), 4, "the mesh is skinned")
			var per_vertex: int = bones.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			assert_le(per_vertex, 4, "at most 4 influences per vertex")
			for vertex: int in range(0, weights.size() / per_vertex, 37):
				var sum: float = 0.0
				for slot: int in per_vertex:
					sum += weights[vertex * per_vertex + slot]
				assert_almost_eq(sum, 1.0, 0.02, "weights add up to one")
			var material: ShaderMaterial = mesh_instance.mesh.surface_get_material(surface) as ShaderMaterial
			assert_not_null(material, "a PS2 ShaderMaterial")
			if material != null:
				assert_eq(material.shader.resource_path, "res://shaders/ps2_lit.gdshader", "Ross's final art gets the PS2 shader")
				var albedo: Texture2D = material.get_shader_parameter("albedo_texture") as Texture2D
				assert_not_null(albedo)
				assert_le(albedo.get_width(), MAX_TEXTURE_PX, "512 px for the early-PS2 target")
				var orm: Texture2D = material.get_shader_parameter("orm_texture") as Texture2D
				assert_not_null(orm, "the metallic-roughness map is kept")
	assert_eq(total, TRIANGLES, "Ross's 1,614 triangles, unchanged")
	assert_le(total, TRIANGLE_CAP)


func test_ears_and_tail_have_their_own_weights_so_they_can_swing() -> void:
	var model: Node3D = _red()
	var skeleton: Skeleton3D = _skeleton(model)
	var wanted: Dictionary = {}
	for bone: String in ["ear_l_2", "ear_r_2", "tail"]:
		wanted[skeleton.find_bone(bone)] = 0
	for mesh_instance: MeshInstance3D in _meshes(model):
		var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for index: int in bones.size():
			if wanted.has(bones[index]) and weights[index] > 0.5:
				wanted[bones[index]] += 1
	for bone: int in wanted:
		assert_gt(float(wanted[bone]), 5.0, "vertices follow " + skeleton.get_bone_name(bone))


func test_the_face_is_its_own_surface_for_swappable_faces_later() -> void:
	# Ross approved swappable faces for later: only the surface exists now, nothing swaps yet.
	var meshes: Array[MeshInstance3D] = _meshes(_red())
	assert_eq(meshes.size(), 1)
	var mesh: Mesh = meshes[0].mesh
	assert_eq(mesh.get_surface_count(), 2, "body and face")
	var face: ShaderMaterial = mesh.surface_get_material(1) as ShaderMaterial
	assert_not_null(face)
	assert_eq(face.resource_name, "red_ross_face", "the face material is named so a later system can find it")
	var face_tris: int = (mesh.surface_get_arrays(1)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	assert_gt(face_tris, 20, "the face has triangles")
	assert_lt(face_tris, 200, "and is only the face")


func test_the_bone_map_maps_every_humanoid_bone_that_exists() -> void:
	# the plan: retarget the free Quaternius Universal Animation Library onto this skeleton (Godot SkeletonProfileHumanoid)
	var map: BoneMap = load("res://art/final/characters/red/red_ross_bone_map.tres") as BoneMap
	assert_not_null(map, "red_ross_bone_map.tres (made by scripts/tools/make_bone_maps.gd)")
	var skeleton: Skeleton3D = _skeleton(_red())
	var profile: SkeletonProfile = map.profile
	assert_not_null(profile)
	var mapped: int = 0
	for index: int in profile.bone_size:
		var humanoid: StringName = profile.get_bone_name(index)
		var ours: StringName = map.get_skeleton_bone_name(humanoid)
		if ours == &"":
			continue
		mapped += 1
		assert_ge(skeleton.find_bone(ours), 0, "%s -> %s exists" % [humanoid, ours])
	assert_ge(mapped, 20, "root, hips, spine, chest, neck, head and both arms and legs")
	for humanoid: String in ["Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperArm", "RightUpperArm", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]:
		assert_ne(map.get_skeleton_bone_name(humanoid), &"", humanoid + " is mapped")
	# the parent chain matches the humanoid profile's (hips -> spine -> chest -> neck -> head; chest -> shoulder -> arm)
	for pair: Array in [["spine", "hips"], ["chest", "spine"], ["neck", "chest"], ["head", "neck"], ["shoulder_l", "chest"],
			["upper_arm_l", "shoulder_l"], ["forearm_l", "upper_arm_l"], ["hand_l", "forearm_l"], ["thigh_r", "hips"], ["shin_r", "thigh_r"], ["foot_r", "shin_r"]]:
		assert_eq(skeleton.get_bone_name(skeleton.get_bone_parent(skeleton.find_bone(pair[0]))), pair[1], "%s hangs from %s" % pair)
