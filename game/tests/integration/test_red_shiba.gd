extends TestCase
## The playable placeholder Red (the locked shiba, red_proto_f + the bare movement clips; built by
## scripts/tools/red_shiba.py). Covers the model contract (docs/style_guide.md "Model contract"):
## the six clip names, the tri and bone budgets, scale and origin, the 128 px textures, and that the
## player controller maps its movement states to those clips by name. Needs the project imported
## once: godot --headless --path game --import

const SHIBA_PATH: String = "res://art/placeholder/characters/red/red_shiba.glb"
## The default Red since Ross approved the grim look (2026-10-08): player.tscn names her; F11 swaps in the classic shiba.
const GRIM_SHIBA_PATH: String = "res://art/placeholder/characters/red/red_shiba_grim.glb"
const PLAYER_SCENE: String = "res://scenes/actors/player.tscn"
const LIT_SHADER: String = "res://shaders/psx_lit.gdshader"
const PARTY_TRIANGLE_HARD_CAP: int = 900
const SHIBA_TRIANGLES: int = 884             # measured: body 840 + sword 44
const BONES: int = 17
const MAX_TEXTURE_PX: int = 128
const HEAD_TOP: float = 1.0                  # Red is the unit; the ears add a little on top
const EARS_MAX: float = 1.2
const REQUIRED_BONES: Array[String] = ["root", "hips", "spine", "head", "ear_l", "ear_r", "tail",
	"upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r", "shin_l", "shin_r",
	"weapon_socket", "prop_socket"]
## clip: length in seconds (15 fps stepped; frames / 15)
const LOOPING: Dictionary[String, float] = {"idle": 22.0 / 15.0, "walk": 12.0 / 15.0, "run": 9.0 / 15.0, "fall": 8.0 / 15.0}
const ONE_SHOT: Dictionary[String, float] = {"jump": 6.0 / 15.0, "land": 4.0 / 15.0}
const CLIP_TOLERANCE: float = 0.05
const TICK: float = 1.0 / 60.0
const SETTLE_STEPS: int = 20

var _player: PlayerController = null


func _model() -> Node3D:
	var packed: PackedScene = load(SHIBA_PATH) as PackedScene
	assert_not_null(packed, "red_shiba.glb should import (run godot --headless --path game --import)")
	var model: Node3D = packed.instantiate() as Node3D
	own(model)
	return model


func _meshes(model: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		found.append(node as MeshInstance3D)
	return found


func _animation_player(model: Node) -> AnimationPlayer:
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	assert_eq(players.size(), 1, "one AnimationPlayer")
	return players[0] as AnimationPlayer


# ---- the model contract ----

func test_all_six_clips_exist_with_the_contract_names() -> void:
	var player: AnimationPlayer = _animation_player(_model())
	for clip: StringName in PlayerMotion.CLIP_NAMES:
		assert_true(player.has_animation(clip), "has clip " + String(clip))
	assert_eq(PlayerMotion.missing_clips(player).size(), 0, "nothing missing")
	assert_eq(PlayerMotion.CLIP_NAMES.size(), 6)


func test_loops_loop_one_shots_play_once_and_every_track_is_stepped() -> void:
	var player: AnimationPlayer = _animation_player(_model())
	for clip: String in LOOPING:
		var animation: Animation = player.get_animation(clip)
		assert_eq(animation.loop_mode, Animation.LOOP_LINEAR, clip + " loops")
		assert_almost_eq(animation.length, LOOPING[clip], CLIP_TOLERANCE, clip + " length")
	for clip: String in ONE_SHOT:
		var animation: Animation = player.get_animation(clip)
		assert_eq(animation.loop_mode, Animation.LOOP_NONE, clip + " plays once")
		assert_almost_eq(animation.length, ONE_SHOT[clip], CLIP_TOLERANCE, clip + " length")
	for clip: StringName in PlayerMotion.CLIP_NAMES:
		var animation: Animation = player.get_animation(clip)
		for track: int in animation.get_track_count():
			assert_eq(animation.track_get_interpolation_type(track), Animation.INTERPOLATION_NEAREST, "%s track %d is stepped" % [clip, track])


func test_run_is_quicker_than_walk_and_squash_is_in_the_clips() -> void:
	var player: AnimationPlayer = _animation_player(_model())
	assert_lt(player.get_animation("run").length, player.get_animation("walk").length)
	var has_scale: bool = false
	var animation: Animation = player.get_animation("land")
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) == Animation.TYPE_SCALE_3D:
			has_scale = true
	assert_true(has_scale, "the rubber squash is a scale track on the root bone")


func test_triangle_count_is_under_the_party_hard_cap() -> void:
	var total: int = 0
	for mesh_instance: MeshInstance3D in _meshes(_model()):
		for surface: int in mesh_instance.mesh.get_surface_count():
			var indices: PackedInt32Array = mesh_instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
			total += indices.size() / 3
	assert_le(total, PARTY_TRIANGLE_HARD_CAP, "under the 900 hard cap (sword included)")
	assert_eq(total, SHIBA_TRIANGLES, "884 with the sword, as locked")


func test_skeleton_has_the_shared_17_bones() -> void:
	var skeletons: Array[Node] = _model().find_children("*", "Skeleton3D", true, false)
	assert_eq(skeletons.size(), 1)
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	assert_eq(skeleton.get_bone_count(), BONES)
	for bone: String in REQUIRED_BONES:
		assert_ge(skeleton.find_bone(bone), 0, "bone " + bone)


func test_scale_origin_and_materials() -> void:
	var low: float = INF
	var high: float = -INF
	for mesh_instance: MeshInstance3D in _meshes(_model()):
		var box: AABB = mesh_instance.get_aabb()
		low = minf(low, box.position.y)
		high = maxf(high, box.end.y)
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material: ShaderMaterial = mesh_instance.mesh.surface_get_material(surface) as ShaderMaterial
			assert_not_null(material, "PSX ShaderMaterial")
			if material == null:
				continue
			assert_eq(material.shader.resource_path, LIT_SHADER)
			var texture: Texture2D = material.get_shader_parameter("albedo_texture") as Texture2D
			assert_not_null(texture)
			if texture != null:
				assert_le(maxi(texture.get_width(), texture.get_height()), MAX_TEXTURE_PX, "texture is 128 px or smaller")
	assert_almost_eq(low, 0.0, 0.1, "feet at the origin")
	assert_ge(high, HEAD_TOP - 0.05, "Red is about 1.0 unit tall (head top)")
	assert_le(high, EARS_MAX, "ears and sword do not make her much taller")


# ---- the game uses it ----

func test_player_scene_points_at_the_shiba_and_attaches_it() -> void:
	var player: PlayerController = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	add_to_root(player)
	assert_eq(player.model_path, GRIM_SHIBA_PATH, "player.tscn names the grim shiba (the approved default look)")
	assert_not_null(player.get_node_or_null("Visual/Model"), "model attached")
	assert_null(player.get_node_or_null("Visual/PlaceholderCapsule"), "capsule stand-in removed")
	assert_eq(player.get_current_animation(), &"idle")


func _make_world() -> void:   # a coroutine: await it
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_to_root(floor_body)
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	_player.read_engine_input = false
	_player.position = Vector3(0.0, 0.02, 0.0)
	add_to_root(_player)
	_player.set_tuning(FieldTuning.from_db(tree.root.get_node("DataDB")))
	# B2: Red's own physics is switched off once the floor is registered, and step() is called by hand,
	# so the test counts exact steps instead of real frames (frame-time independent, like B1).
	await tree.physics_frame
	await tree.physics_frame
	_player.set_physics_process(false)
	_player.position = Vector3(0.0, 0.02, 0.0)
	_player.velocity = Vector3.ZERO


func _steps(count: int) -> void:
	for i: int in count:
		_player.step(TICK)


func test_movement_states_map_to_clips_with_the_real_model() -> void:
	await _make_world()
	_steps(SETTLE_STEPS)
	assert_eq(_player.get_current_animation(), &"idle")
	_player.stick = Vector2(0.0, -0.5)
	_steps(3)
	assert_eq(_player.get_current_animation(), &"walk")
	_player.stick = Vector2(0.0, -1.0)
	_player.run_held = true
	_steps(3)
	assert_eq(_player.get_current_animation(), &"run")
	_player.stick = Vector2.ZERO
	_player.run_held = false
	_steps(3)
	assert_eq(_player.get_current_animation(), &"idle")


func test_jump_fall_and_land_play_their_clips_and_land_returns_to_idle() -> void:
	await _make_world()
	_steps(SETTLE_STEPS)
	_player.jump_held = true
	_player.request_jump()
	_steps(6)
	assert_eq(_player.get_current_animation(), &"jump", "rising plays jump")
	var saw_fall: bool = false
	var saw_land: bool = false
	for i: int in 240:
		_steps(1)
		if _player.get_current_animation() == &"fall":
			saw_fall = true
		if _player.get_current_animation() == &"land":
			saw_land = true
		if saw_land:
			break
	assert_true(saw_fall, "falling plays fall")
	assert_true(saw_land, "touching down while standing still plays land")
	_steps(40)    # the land clip is 0.27 s
	assert_eq(_player.get_current_animation(), &"idle", "back to idle after the squash")


func test_landing_while_moving_skips_the_land_squash() -> void:
	await _make_world()
	_steps(SETTLE_STEPS)
	_player.stick = Vector2(0.0, -1.0)
	_player.run_held = true
	_player.jump_held = true
	_player.request_jump()
	var saw_land: bool = false
	for i: int in 90:
		_steps(1)
		if _player.get_current_animation() == &"land":
			saw_land = true
	assert_false(saw_land, "no squash when she runs on")
	assert_eq(_player.get_current_animation(), &"run")


func test_is_landing_rule() -> void:
	assert_true(PlayerMotion.is_landing(0.1, false, false))
	assert_false(PlayerMotion.is_landing(0.0, false, false), "clip over")
	assert_false(PlayerMotion.is_landing(0.1, true, false), "still in the air")
	assert_false(PlayerMotion.is_landing(0.1, false, true), "moving on")


func test_missing_clips_reports_what_a_model_lacks() -> void:
	var anims: AnimationPlayer = AnimationPlayer.new()
	own(anims)
	var library: AnimationLibrary = AnimationLibrary.new()
	for clip: String in ["idle", "walk", "run"]:
		library.add_animation(clip, Animation.new())
	anims.add_animation_library("", library)
	assert_eq(PlayerMotion.missing_clips(anims), [&"jump", &"fall", &"land"] as Array[StringName])
	assert_eq(PlayerMotion.missing_clips(null).size(), 6)
