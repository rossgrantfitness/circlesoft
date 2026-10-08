extends TestCase
## The sandbox's enemy models: Ross's Cyberwolf Sentinel, rigged (scripts/tools/rig_cyberwolf.py) and animated with the free
## Quaternius clips (scripts/tools/retarget_ual.py), and the Grunt and Brute blockouts (scripts/tools/enemy_combat_blockouts.py;
## the Brute also in a retargeted version). Same facing, scale and origin rules as Red. The pipeline's own checks are in
## test_ual_retarget.gd.

const WOLF_PATH: String = "res://art/final/enemies/cyberwolf_sentinel_rigged_ual.glb"
const RED_PATH: String = "res://art/final/characters/red/red_ross_v1_rigged_ual.glb"
const BRUTE_UAL_PATH: String = "res://art/placeholder/enemies/sandbox_brute/enm_sandbox_brute_ual.glb"
const GRUNT_PATH: String = "res://art/placeholder/enemies/sandbox_grunt/enm_sandbox_grunt.glb"
const BRUTE_PATH: String = "res://art/placeholder/enemies/sandbox_brute/enm_sandbox_brute.glb"
const WOLF_TRIANGLES: int = 1169
const WOLF_BONES: Array[String] = ["root", "hips", "spine", "chest", "neck", "head", "upper_arm_l", "forearm_l", "hand_l", "upper_arm_r",
		"forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r", "tail", "tail_2", "tail_3", "weapon_socket"]
## what the sandbox needs from the wolf, plus the AI's clips (enemies.json behaviour.clips; test_ual_retarget.gd checks that list)
const WOLF_CLIPS: Array[String] = ["idle", "walk", "run", "attack_windup", "attack_swing", "hurt", "launched", "knockdown", "getup", "stagger",
		"notice", "retreat", "stalk", "flee", "dodge_side", "dodge_back", "block_start", "block_hold", "block_break", "strafe_l", "strafe_r"]
const BRUTE_CLIPS: Array[String] = ["idle", "walk", "run", "slam", "enrage", "block_start", "block_hold", "block_break", "hurt", "stagger",
		"knockdown", "getup", "death", "attack_windup", "attack_swing"]
const BLOCKOUT_CLIPS: Array[String] = ["idle", "walk", "attack_windup", "attack_swing"]
const LOOPING: Array[String] = ["idle", "walk", "run", "launched", "stagger", "retreat", "stalk", "flee", "block_hold", "strafe", "strafe_l", "strafe_r"]
const BRUTE_LOOPING: Array[String] = ["idle", "walk", "run", "stagger", "retreat", "block_hold", "strafe", "strafe_l", "strafe_r"]


func _load(path: String) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, path + " should import")
	var model: Node3D = packed.instantiate() as Node3D
	own(model)
	return model


func _height(model: Node) -> Array[float]:
	var low: float = INF
	var high: float = -INF
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (node as MeshInstance3D).get_aabb()
		low = minf(low, box.position.y)
		high = maxf(high, box.end.y)
	return [low, high]


func _tris(model: Node) -> int:
	var total: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			total += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return total


func _skeleton(model: Node) -> Skeleton3D:
	return model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D


func _player(model: Node) -> AnimationPlayer:
	return model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer


func test_the_wolf_has_the_bones_the_socket_and_the_clips() -> void:
	var wolf: Node3D = _load(WOLF_PATH)
	var skeleton: Skeleton3D = _skeleton(wolf)
	for bone: String in WOLF_BONES:
		assert_ge(skeleton.find_bone(bone), 0, "bone " + bone)
	var socket: int = skeleton.find_bone("weapon_socket")
	assert_eq(skeleton.get_bone_name(skeleton.get_bone_parent(socket)), "hand_r")
	var player: AnimationPlayer = _player(wolf)
	for clip: String in WOLF_CLIPS:
		assert_true(player.has_animation(clip), "clip " + clip)
		var animation: Animation = player.get_animation(clip)
		assert_eq(animation.loop_mode == Animation.LOOP_LINEAR, LOOPING.has(clip), clip + " loop flag")
		assert_gt(animation.length, 0.25, clip + " is not a single pose")
		assert_le(animation.length, 3.0, clip + " stays short")
		for track: int in animation.get_track_count():
			assert_eq(animation.track_get_interpolation_type(track), _look_interpolation(), clip + " plays the way import_look.json says")


func _look_interpolation() -> int:
	var look: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animation/import_look.json")) as Dictionary
	return Animation.INTERPOLATION_NEAREST if str(look.get("interpolation", "linear")) == "nearest" else Animation.INTERPOLATION_LINEAR


func test_the_wolf_stands_a_quarter_taller_than_red_with_its_origin_at_the_feet() -> void:
	var wolf: Node3D = _load(WOLF_PATH)
	var red: Node3D = _load(RED_PATH)
	var wolf_box: Array[float] = _height(wolf)
	var red_box: Array[float] = _height(red)
	assert_almost_eq(wolf_box[0], 0.0, 0.01, "feet on the floor")
	var ratio: float = (wolf_box[1] - wolf_box[0]) / (red_box[1] - red_box[0])
	assert_almost_eq(ratio, 1.25, 0.03, "about 1.25 x Red's height")
	var skeleton: Skeleton3D = _skeleton(wolf)
	var tail: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("tail")).origin
	var hips: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("hips")).origin
	assert_lt(tail.z, hips.z - 0.05, "the tail is behind it: it faces +Z")
	assert_eq(_tris(wolf), WOLF_TRIANGLES, "Ross's 1,169 triangles, unchanged")


func test_the_wolf_uses_the_ps2_shader_with_512_textures() -> void:
	var wolf: Node3D = _load(WOLF_PATH)
	for node: Node in wolf.find_children("*", "MeshInstance3D", true, false):
		var material: ShaderMaterial = (node as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
		assert_not_null(material)
		assert_eq(material.shader.resource_path, "res://shaders/ps2_lit.gdshader")
		assert_le((material.get_shader_parameter("albedo_texture") as Texture2D).get_width(), 512)
		assert_not_null(material.get_shader_parameter("orm_texture") as Texture2D, "metallic-roughness kept")


func _hand_height(wolf: Node3D, clip: String, seconds: float) -> float:
	var skeleton: Skeleton3D = _skeleton(wolf)
	var player: AnimationPlayer = _player(wolf)
	player.play(clip)
	player.seek(seconds, true)
	player.pause()
	skeleton.force_update_all_bone_transforms()
	return skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")).origin.y


func test_the_wolf_windup_reads_differently_from_idle() -> void:
	# the telegraph: the right hand ends high behind the head, the idle hand hangs low
	var wolf: Node3D = _load(WOLF_PATH)
	add_to_root(wolf)
	var windup_end: float = _player(wolf).get_animation("attack_windup").length
	var idle: float = _hand_height(wolf, "idle", 0.0)
	var cocked: float = _hand_height(wolf, "attack_windup", windup_end)
	assert_gt(cocked, idle + 0.3, "arm cocked high for the parry window")
	assert_gt(windup_end, 0.4, "a telegraph you can read: at least 0.4 s of wind-up")


func test_the_wolf_swing_has_a_contact_frame_after_which_the_arm_comes_down() -> void:
	var wolf: Node3D = _load(WOLF_PATH)
	add_to_root(wolf)
	var keys: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/wolf_clip_keys.json")) as Dictionary
	var entry: Dictionary = (keys["clips"] as Dictionary)["attack_swing"]
	assert_true(entry.has("contact_s") and entry.has("contact_frame"), "attack_swing has a contact frame")
	var contact: float = float(entry["contact_s"])
	var windup_end: float = _hand_height(wolf, "attack_windup", _player(wolf).get_animation("attack_windup").length)
	var after: float = _hand_height(wolf, "attack_swing", contact + 0.15)
	assert_lt(after, windup_end - 0.2, "the claw comes down through the strike")


func test_the_blockout_grunt_and_brute_exist_and_the_brute_is_bigger() -> void:
	var grunt: Node3D = _load(GRUNT_PATH)
	var brute: Node3D = _load(BRUTE_PATH)
	var grunt_box: Array[float] = _height(grunt)
	var brute_box: Array[float] = _height(brute)
	assert_almost_eq(grunt_box[0], 0.0, 0.12, "grunt stands on the floor")
	assert_ge((brute_box[1] - brute_box[0]) / (grunt_box[1] - grunt_box[0]), 1.4, "the Brute is bigger")
	assert_gt(_tris(brute), _tris(grunt), "and armored (extra plates)")
	assert_le(_tris(brute), 1500)
	for model: Node3D in [grunt, brute]:
		var player: AnimationPlayer = _player(model)
		for clip: String in BLOCKOUT_CLIPS:
			assert_true(player.has_animation(clip), clip)
		assert_ge(_skeleton(model).find_bone("weapon_socket"), 0)


func test_the_wolf_bone_map_is_clean() -> void:
	var map: BoneMap = load("res://art/final/enemies/cyberwolf_sentinel_bone_map.tres") as BoneMap
	assert_not_null(map)
	var skeleton: Skeleton3D = _skeleton(_load(WOLF_PATH))
	for humanoid: String in ["Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "LeftHand",
			"RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "LeftFoot", "RightFoot", "LeftShoulder", "RightShoulder"]:
		var ours: StringName = map.get_skeleton_bone_name(humanoid)
		assert_ne(ours, &"", humanoid + " is mapped")
		assert_ge(skeleton.find_bone(ours), 0, "%s -> %s exists" % [humanoid, ours])


func test_the_retargeted_brute_keeps_the_blockout_and_has_the_ai_clips() -> void:
	var brute: Node3D = _load(BRUTE_UAL_PATH)
	var old_brute: Node3D = _load(BRUTE_PATH)
	var box: Array[float] = _height(brute)
	var old_box: Array[float] = _height(old_brute)
	assert_almost_eq(box[1] - box[0], old_box[1] - old_box[0], 0.01, "same mesh and size as the blockout")
	assert_eq(_tris(brute), _tris(old_brute), "same triangles")
	var skeleton: Skeleton3D = _skeleton(brute)
	var old_skeleton: Skeleton3D = _skeleton(old_brute)
	assert_eq(skeleton.get_bone_count(), old_skeleton.get_bone_count(), "same bones")
	for index: int in old_skeleton.get_bone_count():
		assert_ge(skeleton.find_bone(old_skeleton.get_bone_name(index)), 0, "bone " + old_skeleton.get_bone_name(index))
	var player: AnimationPlayer = _player(brute)
	for clip: String in BRUTE_CLIPS:
		assert_true(player.has_animation(clip), "clip " + clip)
		assert_eq(player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, BRUTE_LOOPING.has(clip), clip + " loop flag")
