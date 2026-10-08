extends TestCase
## The grim Red (red_shiba_grim.glb, built by scripts/tools/red_shiba.py --variant grim): the same shiba
## Ross locked, grown up and worn for the grim look test. It must drop in through `model_path`, so it keeps
## the whole model contract (docs/style_guide.md): the six clip names and lengths, the 17 bones, under 900
## triangles, 128 px textures, feet at the origin. And it must actually be the new look: smaller head, taller
## leaner body, matte, scuffed, dull. Needs the project imported once: godot --headless --path game --import

const CLASSIC_PATH: String = "res://art/placeholder/characters/red/red_shiba.glb"
const GRIM_PATH: String = "res://art/placeholder/characters/red/red_shiba_grim.glb"
const LIT_SHADER: String = "res://shaders/psx_lit.gdshader"
const PARTY_TRIANGLE_HARD_CAP: int = 900
const GRIM_TRIANGLES: int = 884             # measured: body 840 + sword 44, the same primitives as the classic Red
const BONES: int = 17
const MAX_TEXTURE_PX: int = 128
const REQUIRED_BONES: Array[String] = ["root", "hips", "spine", "head", "ear_l", "ear_r", "tail",
	"upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r", "shin_l", "shin_r",
	"weapon_socket", "prop_socket"]
const LOOPING: Dictionary[String, float] = {"idle": 22.0 / 15.0, "walk": 12.0 / 15.0, "run": 9.0 / 15.0, "fall": 8.0 / 15.0}
const ONE_SHOT: Dictionary[String, float] = {"jump": 6.0 / 15.0, "land": 4.0 / 15.0}
const CLIP_TOLERANCE: float = 0.05
## Head height as built: the head ellipsoid is 0.41 tall in the classic Red, and the grim warp scales it by 0.8.
const CLASSIC_HEAD_HEIGHT: float = 0.41
const GRIM_HEAD_SCALE: float = 0.8
const BODY_BONES: Array[String] = ["spine", "thigh_l", "shin_l"]


func _load(path: String) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, path + " should import (run godot --headless --path game --import)")
	var model: Node3D = packed.instantiate() as Node3D
	own(model)
	return model


func _meshes(model: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		found.append(node as MeshInstance3D)
	return found


func _triangles(model: Node) -> int:
	var total: int = 0
	for mesh_instance: MeshInstance3D in _meshes(model):
		for surface: int in mesh_instance.mesh.get_surface_count():
			var indices: PackedInt32Array = mesh_instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
			total += indices.size() / 3
	return total


func _skeleton(model: Node) -> Skeleton3D:
	var found: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	assert_eq(found.size(), 1)
	return found[0] as Skeleton3D


func _height(model: Node) -> float:
	var high: float = -INF
	for mesh_instance: MeshInstance3D in _meshes(model):
		high = maxf(high, mesh_instance.get_aabb().end.y)
	return high


func _bone_rest_global(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin


func _body_texture(model: Node) -> Image:
	for mesh_instance: MeshInstance3D in _meshes(model):
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material: ShaderMaterial = mesh_instance.mesh.surface_get_material(surface) as ShaderMaterial
			if material != null and material.resource_name.ends_with("_body"):
				return (material.get_shader_parameter("albedo_texture") as Texture2D).get_image()
	return null


## Mean saturation over the colour cells of the 128 px body sheet (the 16 px cells of fur, cream, jacket, tan).
func _mean_saturation(image: Image) -> float:
	var total: float = 0.0
	var count: int = 0
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]:
		for y: int in 16:
			for x: int in 16:
				total += image.get_pixel(cell.x * 16 + x, cell.y * 16 + y).s
				count += 1
	return total / float(count)


func _brightest(image: Image) -> float:
	var best: float = 0.0
	for y: int in image.get_height():
		for x: int in image.get_width():
			best = maxf(best, image.get_pixel(x, y).get_luminance())
	return best


# ---- the model contract: it must drop in through model_path ----

func test_same_six_clip_names_loops_lengths_and_stepped_tracks() -> void:
	var players: Array[Node] = _load(GRIM_PATH).find_children("*", "AnimationPlayer", true, false)
	assert_eq(players.size(), 1, "one AnimationPlayer")
	var player: AnimationPlayer = players[0] as AnimationPlayer
	assert_eq(PlayerMotion.missing_clips(player).size(), 0, "all six clips are there")
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


func test_clips_match_the_classic_red_clip_for_clip() -> void:
	var classic: AnimationPlayer = _load(CLASSIC_PATH).find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var grim: AnimationPlayer = _load(GRIM_PATH).find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip: StringName in PlayerMotion.CLIP_NAMES:
		assert_almost_eq(grim.get_animation(clip).length, classic.get_animation(clip).length, 0.001, String(clip))
		assert_ge(grim.get_animation(clip).get_track_count(), 10, String(clip) + " animates the rig")


func test_under_900_triangles_and_the_same_count_as_the_classic_red() -> void:
	var grim: int = _triangles(_load(GRIM_PATH))
	assert_le(grim, PARTY_TRIANGLE_HARD_CAP, "under the 900 hard cap (sword included)")
	assert_eq(grim, GRIM_TRIANGLES)
	assert_eq(grim, _triangles(_load(CLASSIC_PATH)), "only the proportions and the surface changed, not the budget")


func test_same_17_bone_skeleton() -> void:
	var skeleton: Skeleton3D = _skeleton(_load(GRIM_PATH))
	assert_eq(skeleton.get_bone_count(), BONES)
	for bone: String in REQUIRED_BONES:
		assert_ge(skeleton.find_bone(bone), 0, "bone " + bone)


func test_feet_at_the_origin_and_one_psx_material_set() -> void:
	var model: Node3D = _load(GRIM_PATH)
	var low: float = INF
	for mesh_instance: MeshInstance3D in _meshes(model):
		low = minf(low, mesh_instance.get_aabb().position.y)
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material: ShaderMaterial = mesh_instance.mesh.surface_get_material(surface) as ShaderMaterial
			assert_not_null(material, "PSX ShaderMaterial")
			if material == null:
				continue
			assert_eq(material.shader.resource_path, LIT_SHADER)
			assert_true(String(material.resource_name).begins_with("mat_red_shiba_grim"), "named for the model: " + material.resource_name)
			var texture: Texture2D = material.get_shader_parameter("albedo_texture") as Texture2D
			assert_not_null(texture)
			if texture != null:
				assert_le(maxi(texture.get_width(), texture.get_height()), MAX_TEXTURE_PX, "128 px or smaller")
	assert_almost_eq(low, 0.0, 0.1, "feet at the origin")


# ---- scale and proportions ----

func test_scale_taller_than_the_classic_red_but_still_a_party_sized_character() -> void:
	var classic: float = _height(_load(CLASSIC_PATH))
	var grim: float = _height(_load(GRIM_PATH))
	assert_gt(grim, classic, "taller")
	assert_ge(grim, 1.05, "head top about 1.1, ears and sword above it")
	assert_le(grim, 1.35, "but not bigger than the party's tallest (Otis is 1.25 to the head)")


func test_about_three_and_a_half_heads_tall_instead_of_two_and_a_half() -> void:
	var skeleton: Skeleton3D = _skeleton(_load(GRIM_PATH))
	var classic_skeleton: Skeleton3D = _skeleton(_load(CLASSIC_PATH))
	# Where the head ellipsoid tops out is the head bone's tail; its height is the head bone's own length scaled
	# by the head ellipsoid (0.41 of a 0.39 bone), so heads = height to the top of the head / head height.
	var neck: float = _bone_rest_global(skeleton, "head").y
	var classic_neck: float = _bone_rest_global(classic_skeleton, "head").y
	assert_gt(neck, classic_neck + 0.1, "the neck is higher: a longer body under a smaller head")
	var grim_head: float = CLASSIC_HEAD_HEIGHT * GRIM_HEAD_SCALE
	var grim_top: float = neck + (0.99 - 0.60) * GRIM_HEAD_SCALE        # the head bone's tail, as built
	var heads: float = grim_top / grim_head
	assert_ge(heads, 3.0, "at least 3 heads (%f)" % heads)
	assert_le(heads, 3.6, "at most about 3.5 heads (%f)" % heads)
	assert_lt((0.99 / CLASSIC_HEAD_HEIGHT), 2.6, "the classic Red is about 2.4 to 2.5 heads")


func test_leaner_the_legs_and_torso_are_longer_and_the_body_is_narrower() -> void:
	var grim: Skeleton3D = _skeleton(_load(GRIM_PATH))
	var classic: Skeleton3D = _skeleton(_load(CLASSIC_PATH))
	var grim_leg: float = _bone_rest_global(grim, "hips").y - _bone_rest_global(grim, "shin_l").y
	var classic_leg: float = _bone_rest_global(classic, "hips").y - _bone_rest_global(classic, "shin_l").y
	assert_gt(grim_leg, classic_leg * 1.2, "longer legs")
	var grim_gap: float = absf(_bone_rest_global(grim, "thigh_l").x - _bone_rest_global(grim, "thigh_r").x)
	var classic_gap: float = absf(_bone_rest_global(classic, "thigh_l").x - _bone_rest_global(classic, "thigh_r").x)
	assert_lt(grim_gap, classic_gap, "narrower stance")
	var grim_shoulders: float = absf(_bone_rest_global(grim, "upper_arm_l").x - _bone_rest_global(grim, "upper_arm_r").x)
	var classic_shoulders: float = absf(_bone_rest_global(classic, "upper_arm_l").x - _bone_rest_global(classic, "upper_arm_r").x)
	assert_lt(grim_shoulders, classic_shoulders * 0.9, "slimmer shoulders")


func test_the_locked_features_are_all_still_there() -> void:
	var skeleton: Skeleton3D = _skeleton(_load(GRIM_PATH))
	var ear_l: Vector3 = _bone_rest_global(skeleton, "ear_l")
	var ear_r: Vector3 = _bone_rest_global(skeleton, "ear_r")
	assert_gt(ear_l.x, 0.08, "wide-set ears (left)")
	assert_lt(ear_r.x, -0.08, "wide-set ears (right)")
	assert_gt(ear_l.y, _bone_rest_global(skeleton, "head").y, "the ears sit up on the head")
	assert_lt(_bone_rest_global(skeleton, "tail").z, 0.0, "the curled tail sits behind her (she faces +Z)")
	assert_gt(skeleton.find_bone("weapon_socket"), -1, "sword socket")
	assert_eq(_meshes(_load(GRIM_PATH)).size(), 2, "body and sword, as the classic Red")


# ---- the surface: matte, scuffed, dull ----

func test_matte_dull_and_dark_compared_with_the_classic_texture() -> void:
	var classic: Image = _body_texture(_load(CLASSIC_PATH))
	var grim: Image = _body_texture(_load(GRIM_PATH))
	assert_not_null(classic)
	assert_not_null(grim)
	if classic == null or grim == null:
		return
	assert_lt(_mean_saturation(grim), _mean_saturation(classic) * 0.8, "colours drained (%f vs %f)" % [_mean_saturation(grim), _mean_saturation(classic)])
	assert_lt(_brightest(grim), 0.8, "no Chalk gloss spots: the brightest pixel is a warm lamp, not a toy highlight")
	assert_gt(_brightest(classic), 0.85, "(the classic Red does have them)")


func test_the_jacket_is_darker_and_scuffed() -> void:
	var classic: Image = _body_texture(_load(CLASSIC_PATH))
	var grim: Image = _body_texture(_load(GRIM_PATH))
	if classic == null or grim == null:
		fail("no body texture")
		return
	# Cell (3,0): the jacket color. Classic is a clean two-tone block; grim is darker and not one flat color.
	var jacket_classic: Color = classic.get_pixel(3 * 16 + 8, 4)
	var jacket_grim: Color = grim.get_pixel(3 * 16 + 8, 4)
	assert_lt(jacket_grim.get_luminance(), jacket_classic.get_luminance() * 0.85, "darker jacket")
	var colors: Dictionary = {}
	for y: int in 16:
		for x: int in 16:
			colors[grim.get_pixel(3 * 16 + x, y).to_html()] = true
	assert_gt(colors.size(), 4, "scuffs and dirt break up the flat color (%d colors in the cell)" % colors.size())


# ---- it drops in ----

func test_player_scene_still_names_the_approved_red_and_the_grim_one_drops_in_by_path() -> void:
	var player: PlayerController = (load("res://scenes/actors/player.tscn") as PackedScene).instantiate() as PlayerController
	assert_eq(player.model_path, CLASSIC_PATH, "nothing approved was changed")
	player.model_path = GRIM_PATH
	add_to_root(player)
	assert_eq(player.get_node("Visual/Model").scene_file_path, GRIM_PATH, "setting model_path is all it takes")
	assert_eq(player.get_current_animation(), &"idle")
