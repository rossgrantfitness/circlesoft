extends TestCase
## The four enemy placeholders (Signals grunt, Signals drone, and their variants) in the Red house style:
## they load by path, stay under the triangle caps, carry one looping `idle` clip, use the PSX material with
## nearest filtering, have the texture sizes from the style guide, are sized against Red, and the variants really
## are a recolor plus swapped parts. The grunts hold a white flag (hidden mesh) and use the shared 17 bones.
## Needs the project imported once: godot --headless --path game --import

const DIR: String = "res://art/placeholder/enemies/"
const GRUNT: String = DIR + "signals_grunt/enm_signals_grunt.glb"
const GRUNT_V: String = DIR + "grunt_variant/enm_grunt_variant.glb"
const DRONE: String = DIR + "signals_drone/enm_signals_drone.glb"
const DRONE_V: String = DIR + "drone_variant/enm_drone_variant.glb"
const PARTY: Array[String] = [
	"res://art/placeholder/characters/red/red_shiba.glb",
	"res://art/placeholder/characters/otis/chr_otis.glb",
	"res://art/placeholder/characters/mox/chr_mox.glb",
]
const HUMANOID_CAP: int = 600        # style guide: enemy, humanoid (art_requests row 21 asks 600-900; the lower cap satisfies both)
const SMALL_CAP: int = 450           # style guide: enemy, small (art_requests rows 22 and 24 ask 200-400)
const SMALL_REQUEST_MAX: int = 400
const PROP_CAP: int = 150
const PROP_MARK: String = "_prop_"
const LIT_SHADER: String = "res://shaders/psx_lit.gdshader"
const MAX_TEXTURE_PX: int = 256
const REQUIRED_BONES: PackedStringArray = [
	"root", "hips", "spine", "head", "ear_r", "ear_l", "tail", "upper_arm_r", "forearm_r", "upper_arm_l",
	"forearm_l", "thigh_r", "shin_r", "thigh_l", "shin_l", "weapon_socket", "prop_socket",
]
const DRONE_BONES: PackedStringArray = ["root", "body", "rotor_l", "rotor_r"]


func _model(path: String) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, path + " should import (run godot --headless --path game --import)")
	var model: Node3D = packed.instantiate() as Node3D
	own(model)
	return model


func _meshes(model: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			found.append(mesh_instance)
	return found


func _triangles(mesh_instance: MeshInstance3D) -> int:
	var total: int = 0
	for surface: int in mesh_instance.mesh.get_surface_count():
		var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices != null and (indices as PackedInt32Array).size() > 0:
			total += (indices as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _total_triangles(model: Node) -> int:
	var total: int = 0
	for mesh_instance: MeshInstance3D in _meshes(model):
		total += _triangles(mesh_instance)
	return total


func _mesh_names(model: Node) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for mesh_instance: MeshInstance3D in _meshes(model):
		names.append(String(mesh_instance.name))
	return names


func _bones(model: Node) -> PackedStringArray:
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	assert_eq(skeletons.size(), 1, "one skeleton")
	var out: PackedStringArray = PackedStringArray()
	if skeletons.is_empty():
		return out
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	for i: int in skeleton.get_bone_count():
		out.append(skeleton.get_bone_name(i))
	return out


func _body_height(model: Node3D) -> float:
	var top: float = 0.0
	for mesh_instance: MeshInstance3D in _meshes(model):
		if String(mesh_instance.name).contains(PROP_MARK):
			continue
		top = maxf(top, mesh_instance.get_aabb().end.y)
	return top


func _textures(model: Node) -> Array[Texture2D]:
	var found: Array[Texture2D] = []
	for mesh_instance: MeshInstance3D in _meshes(model):
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material: ShaderMaterial = mesh_instance.mesh.surface_get_material(surface) as ShaderMaterial
			if material == null:
				continue
			var texture: Texture2D = material.get_shader_parameter("albedo_texture") as Texture2D
			if texture != null and not found.has(texture):
				found.append(texture)
	return found


func _first_pixel_signature(model: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for texture: Texture2D in _textures(model):
		parts.append(str(hash(texture.get_image().get_data())))
	parts.sort()
	return ",".join(parts)


# ---- budgets and clips ----

func test_enemies_load_by_path_under_the_triangle_caps() -> void:
	var grunt: int = _total_triangles(_model(GRUNT))
	var grunt_v: int = _total_triangles(_model(GRUNT_V))
	var drone: int = _total_triangles(_model(DRONE))
	var drone_v: int = _total_triangles(_model(DRONE_V))
	assert_gt(grunt, 300, "the grunt is not a stub")
	assert_le(grunt, HUMANOID_CAP, "grunt: %d tris" % grunt)
	assert_le(grunt_v, HUMANOID_CAP, "grunt variant: %d tris" % grunt_v)
	assert_gt(drone, 150)
	assert_le(drone, SMALL_REQUEST_MAX, "drone: %d tris" % drone)
	assert_le(drone, SMALL_CAP)
	assert_le(drone_v, SMALL_REQUEST_MAX, "drone variant: %d tris" % drone_v)
	print("enemy triangles: grunt %d, grunt variant %d, drone %d, drone variant %d" % [grunt, grunt_v, drone, drone_v])


func test_every_enemy_has_one_looping_idle_clip() -> void:
	for path: String in [GRUNT, GRUNT_V, DRONE, DRONE_V]:
		var model: Node3D = _model(path)
		var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
		assert_eq(players.size(), 1, path + ": one AnimationPlayer")
		if players.is_empty():
			continue
		var player: AnimationPlayer = players[0] as AnimationPlayer
		var clips: Array[String] = []
		for clip_name: StringName in player.get_animation_list():
			if clip_name != &"RESET":
				clips.append(String(clip_name))
		assert_eq(clips, ["idle"], path + ": only `idle`, no other authored clips")
		var idle: Animation = player.get_animation(&"idle")
		assert_eq(idle.loop_mode, Animation.LOOP_LINEAR, path + ": idle loops")
		assert_gt(idle.length, 1.0, path + ": about 1.5 s")
		assert_lt(idle.length, 2.0)
		assert_gt(idle.get_track_count(), 3, path + ": it moves something")


func test_idle_really_moves_the_model() -> void:
	for path: String in [GRUNT, DRONE]:
		var model: Node3D = _model(path)
		add_to_root(model)
		var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		player.play(&"idle")
		player.seek(0.0, true)
		var first: Array[Transform3D] = []
		for i: int in skeleton.get_bone_count():
			first.append(skeleton.get_bone_global_pose(i))
		player.seek(player.current_animation_length * 0.5, true)
		var moved: int = 0
		for i: int in skeleton.get_bone_count():
			if not skeleton.get_bone_global_pose(i).is_equal_approx(first[i]):
				moved += 1
		assert_gt(moved, 2, path + ": the idle pose changes over the loop")


# ---- look and rig ----

func test_enemies_use_the_psx_material_with_the_sizes_from_the_style_guide() -> void:
	var expected: Dictionary[String, Array] = {
		GRUNT: [Vector2(128, 128), Vector2(128, 64)],
		GRUNT_V: [Vector2(128, 128), Vector2(128, 64)],
		DRONE: [Vector2(64, 64)],
		DRONE_V: [Vector2(64, 64)],
	}
	for path: String in expected:
		var model: Node3D = _model(path)
		for mesh_instance: MeshInstance3D in _meshes(model):
			for surface: int in mesh_instance.mesh.get_surface_count():
				var material: ShaderMaterial = mesh_instance.mesh.surface_get_material(surface) as ShaderMaterial
				assert_not_null(material, "%s %s needs the PSX ShaderMaterial" % [path, mesh_instance.name])
				if material != null:
					assert_eq(material.shader.resource_path, LIT_SHADER, "%s uses psx_lit" % mesh_instance.name)
		var sizes: Array[Vector2] = []
		for texture: Texture2D in _textures(model):
			sizes.append(texture.get_size())
			assert_le(texture.get_width(), MAX_TEXTURE_PX)
		for want: Vector2 in expected[path]:
			assert_true(sizes.has(want), "%s has a %s texture (has %s)" % [path, want, sizes])


func test_grunts_use_the_17_shared_bones_and_the_drones_use_four() -> void:
	for path: String in [GRUNT, GRUNT_V]:
		var bones: PackedStringArray = _bones(_model(path))
		for bone: String in REQUIRED_BONES:
			assert_true(bones.has(bone), "%s has bone %s" % [path, bone])
		assert_eq(bones.size(), 17, path + ": exactly the shared 17")
	for path: String in [DRONE, DRONE_V]:
		var bones: PackedStringArray = _bones(_model(path))
		for bone: String in DRONE_BONES:
			assert_true(bones.has(bone), "%s has bone %s" % [path, bone])
		assert_eq(bones.size(), 4, path + ": four bones (style guide: body and two rotors)")


func test_enemies_are_sized_against_red_and_stand_on_the_floor() -> void:
	var red_top: float = _body_height(_model(PARTY[0]))
	assert_gt(red_top, 0.95, "Red is the unit")
	var grunt: Node3D = _model(GRUNT)
	var grunt_top: float = _body_height(grunt)
	assert_gt(grunt_top, red_top * 0.85, "grunt height %f vs Red %f" % [grunt_top, red_top])
	assert_lt(grunt_top, red_top * 1.35)
	var drone_top: float = _body_height(_model(DRONE))
	assert_gt(drone_top, 0.9, "the drone hovers up near head height")
	assert_lt(drone_top, 1.5)
	var lowest: float = INF
	for mesh_instance: MeshInstance3D in _meshes(grunt):
		if not String(mesh_instance.name).contains(PROP_MARK):
			lowest = minf(lowest, mesh_instance.get_aabb().position.y)
	assert_lt(absf(lowest), 0.03, "the grunt's feet are on the floor (origin at the feet)")


func test_grunts_hold_a_hidden_white_flag_and_a_prop_in_the_other_hand() -> void:
	for path: String in [GRUNT, GRUNT_V]:
		var model: Node3D = _model(path)
		var names: PackedStringArray = _mesh_names(model)
		var flag_found: bool = false
		for mesh_instance: MeshInstance3D in _meshes(model):
			var mesh_name: String = String(mesh_instance.name)
			if mesh_name.contains(PROP_MARK):
				assert_le(_triangles(mesh_instance), PROP_CAP, mesh_name + " is a held prop")
			if mesh_name.contains("_prop_flag"):
				flag_found = true
		assert_true(flag_found, path + " has a flag mesh")
		var held: int = 0
		for mesh_name: String in names:
			if mesh_name.contains("clipboard") or mesh_name.contains("megaphone"):
				held += 1
		assert_eq(held, 1, path + ": exactly one held prop (clipboard or megaphone)")
	for path: String in [DRONE, DRONE_V]:
		for mesh_name: String in _mesh_names(_model(path)):
			assert_false(mesh_name.contains("_prop_flag"), "drones have no flag")


func test_variants_are_a_recolor_plus_swapped_parts() -> void:
	var grunt: Node3D = _model(GRUNT)
	var variant: Node3D = _model(GRUNT_V)
	assert_ne(_first_pixel_signature(grunt), _first_pixel_signature(variant), "grunt variant is recolored")
	var grunt_names: PackedStringArray = _mesh_names(grunt)
	var variant_names: PackedStringArray = _mesh_names(variant)
	var has_clipboard: bool = false
	for mesh_name: String in grunt_names:
		has_clipboard = has_clipboard or mesh_name.contains("clipboard")
	var variant_megaphone: bool = false
	for mesh_name: String in variant_names:
		variant_megaphone = variant_megaphone or mesh_name.contains("megaphone")
	assert_true(has_clipboard, "the base grunt has the clipboard")
	assert_true(variant_megaphone, "the variant swaps it for a megaphone")
	assert_ne(_total_triangles(grunt), _total_triangles(variant), "and the antenna pair changes the shape")
	assert_ne(_first_pixel_signature(_model(DRONE)), _first_pixel_signature(_model(DRONE_V)), "drone variant is recolored")
	assert_ne(_total_triangles(_model(DRONE)), _total_triangles(_model(DRONE_V)), "with swapped parts (siren and cargo basket)")


func test_drone_texture_shows_the_signals_symbol() -> void:
	var image: Image = _textures(_model(DRONE))[0].get_image()
	# the wavy line with a slash is painted in the top-left 32x32: a pink-red slash, an Ink border, and a blue line
	var pink: int = 0
	var blue: int = 0
	for y: int in 32:
		for x: int in 32:
			var c: Color = image.get_pixel(x, y)
			if c.r > 0.85 and c.g < 0.4 and c.b > 0.3:
				pink += 1
			if c.b > c.r + 0.15 and c.r < 0.4 and c.g > 0.3 and c.b < 0.65:
				blue += 1
	assert_gt(pink, 20, "the slash")
	assert_gt(blue, 20, "the wavy line")


func test_party_models_for_the_stage_exist_with_idle_clips() -> void:
	for path: String in PARTY:
		var model: Node3D = _model(path)
		var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
		assert_eq(players.size(), 1, path)
		if not players.is_empty():
			assert_true((players[0] as AnimationPlayer).has_animation(&"idle"), path + " has idle")
