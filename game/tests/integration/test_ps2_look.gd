extends TestCase
## The early-PS2 look (scripts/core/ps2_look.gd, data/world/look_profiles.json "grim_ps2", shaders/ps2_lit*.gdshader,
## docs/pivot/combat_api.md section 6). The old game's profiles must stay exactly as they were.

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"
const GRUNT: String = "res://art/placeholder/enemies/sandbox_grunt/enm_sandbox_grunt.glb"
const WOLF: String = "res://art/final/enemies/cyberwolf_sentinel_rigged.glb"
const SWORD: String = "res://art/final/weapons/sword_katana_cyan.glb"
const PS2: String = "grim_ps2"


func after_each() -> void:
	LookProfiles.reset()
	PsxLook.reset_effects()
	super.after_each()


func _profile() -> Dictionary:
	return LookProfiles.profile(PS2)


# ---- the data ----

func test_the_profile_exists_and_the_old_profiles_have_no_ps2_blocks() -> void:
	assert_true(LookProfiles.has_profile(PS2))
	assert_eq(LookProfiles.default_id(), "grim", "nothing makes grim_ps2 the default")
	for old: String in ["classic", "grim"]:
		for key: String in ["screen", "shadows", "glow", "texture_filter", "retro_wobble"]:
			assert_false(LookProfiles.profile(old).has(key), "%s has no %s block" % [old, key])
	assert_almost_eq(LookProfiles.number("grim", "grade.desat", 0.0), 0.75, 0.0001, "grim's own grade is unchanged")
	assert_almost_eq(LookProfiles.number("grim", "grade.gamma", 0.0), 1.1, 0.0001)
	assert_almost_eq(LookProfiles.number("grim", "grade.tint_amount", 0.0), 0.6, 0.0001)


func test_the_grade_is_ross_s_lighter_b_filter() -> void:
	assert_almost_eq(LookProfiles.number(PS2, "grade.desat", 0.0), 0.35, 0.0001)
	assert_almost_eq(LookProfiles.number(PS2, "grade.tint_amount", 0.0), 0.3, 0.0001)
	assert_almost_eq(LookProfiles.number(PS2, "grade.gamma", 0.0), 1.0, 0.0001)
	for key: String in ["accent_keep", "crush", "grain", "vignette", "gain"]:
		assert_almost_eq(LookProfiles.number(PS2, "grade." + key, -1.0), LookProfiles.number("grim", "grade." + key, -2.0), 0.0001, key + " as in grim")


func test_the_ps2_blocks() -> void:
	var profile: Dictionary = _profile()
	assert_true(Ps2Look.is_ps2_profile(profile))
	assert_eq(Ps2Look.resolution_of(str(profile["screen"]["resolution"])), Vector2i(640, 360))
	assert_eq(float(profile["retro_wobble"]["jitter"]), 0.0)
	assert_eq(float(profile["retro_wobble"]["affine"]), 0.0)
	assert_false(bool(profile["dither"]["enabled"]))
	assert_false(bool(profile["color_depth"]["enabled"]))
	assert_true(bool(profile["shadows"]["enabled"]))
	assert_almost_eq(float(profile["shadows"]["max_distance_m"]), 20.0, 0.001)
	assert_true(bool(profile["glow"]["enabled"]))
	assert_false(bool(profile["characters"]["dull"]), "Ross's art is never repainted")
	assert_gt(float(profile["characters"]["rim_strength"]), 0.0, "the edge light is kept")
	assert_lt(float(profile["characters"]["rim_strength"]), 1.0, "and stays 'not too bright'")


func test_texture_filtering_is_data_per_group() -> void:
	var profile: Dictionary = _profile()
	assert_eq(Ps2Look.filter_for(profile, "city_tiles"), "nearest", "Ross, 2026-10-08: nearest for now")
	for group: String in ["characters", "weapons", "enemies"]:
		assert_eq(Ps2Look.filter_for(profile, group), "smooth", group)
	assert_eq(Ps2Look.filter_for(profile, "no_such_group"), "smooth", "unknown groups use the default")
	var flipped: Dictionary = profile.duplicate(true)
	flipped["texture_filter"]["city_tiles"] = "smooth"
	assert_eq(Ps2Look.filter_for(flipped, "city_tiles"), "smooth", "one data edit flips it")
	assert_eq(Ps2Look.shader_path_for(profile, "city_tiles"), "res://shaders/ps2_lit_crisp.gdshader")
	assert_eq(Ps2Look.shader_path_for(profile, "weapons"), "res://shaders/ps2_lit.gdshader")
	assert_eq(Ps2Look.group_for_path("res://art/final/weapons/sword_machete.glb"), "weapons")
	assert_eq(Ps2Look.group_for_path("res://art/final/enemies/x.glb"), "enemies")
	assert_eq(Ps2Look.group_for_path("res://art/final/characters/red/x.glb"), "characters")
	assert_eq(Ps2Look.group_for_path("res://art/placeholder/enemies/x.glb"), "placeholders")


func test_the_640x360_resolution_is_listed_and_the_default_stays_384x216() -> void:
	assert_eq(Ps2Look.resolution_of("640x360"), Vector2i(640, 360))
	assert_eq(Ps2Look.resolution_of("nonsense"), Vector2i.ZERO)
	assert_eq(str(DataDB.get_value("world/psx_look", "default_resolution", "")), "384x216")


# ---- environment and light ----

func test_glow_and_shadow_settings_land_on_the_nodes() -> void:
	var environment: Environment = Environment.new()
	Ps2Look.apply_environment(environment, _profile())
	assert_true(environment.glow_enabled)
	assert_almost_eq(environment.glow_hdr_threshold, float(_profile()["glow"]["hdr_threshold"]), 0.0001)
	assert_eq(environment.glow_blend_mode, Environment.GLOW_BLEND_MODE_SCREEN)
	var off: Environment = Environment.new()
	off.glow_enabled = true
	Ps2Look.apply_environment(off, {"glow": {"enabled": false}})
	assert_false(off.glow_enabled)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	own(light)
	Ps2Look.apply_shadows(light, _profile())
	assert_true(light.shadow_enabled)
	assert_almost_eq(light.directional_shadow_max_distance, 20.0, 0.001)
	assert_eq(light.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)


# ---- the screen and the switch back ----

func test_the_node_switches_the_screen_and_the_effects_and_puts_them_back() -> void:
	var screen: PsxScreen = (load(SCREEN_SCENE) as PackedScene).instantiate() as PsxScreen
	add_to_root(screen)
	var holder: Node3D = Node3D.new()
	screen.get_world_root().add_child(holder)
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = Environment.new()
	holder.add_child(world_environment)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	holder.add_child(key)
	var look: Ps2Look = Ps2Look.new()
	holder.add_child(look)
	assert_eq(screen.get_resolution(), Vector2i(384, 216), "an old profile: nothing changes")
	assert_false(look.is_applied())
	LookProfiles.set_forced(PS2)
	assert_true(look.is_applied())
	assert_eq(screen.get_resolution(), Vector2i(640, 360))
	assert_eq(screen.get_display().texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "smooth scale-up")
	assert_false(PsxLook.is_effect_on(PsxLook.Effect.JITTER), "vertex jitter off")
	assert_false(PsxLook.is_effect_on(PsxLook.Effect.WARP), "affine warp off")
	assert_false(PsxLook.is_effect_on(PsxLook.Effect.DITHER))
	assert_false(PsxLook.is_effect_on(PsxLook.Effect.COLOR_DEPTH))
	assert_true(world_environment.environment.glow_enabled)
	assert_true(key.shadow_enabled)
	LookProfiles.set_forced("grim")
	assert_false(look.is_applied())
	assert_eq(screen.get_resolution(), Vector2i(384, 216), "back to the old game's picture")
	assert_eq(screen.get_display().texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_true(PsxLook.is_effect_on(PsxLook.Effect.JITTER))
	assert_true(PsxLook.is_effect_on(PsxLook.Effect.WARP))
	assert_true(PsxLook.is_effect_on(PsxLook.Effect.COLOR_DEPTH))
	assert_false(world_environment.environment.glow_enabled, "glow back to what the scene had")
	assert_false(key.shadow_enabled)


# ---- shaders and materials ----

func test_the_shaders_compile_and_make_material_picks_by_group() -> void:
	for path: String in ["res://shaders/ps2_lit.gdshader", "res://shaders/ps2_lit_crisp.gdshader", "res://shaders/sword_trail.gdshader"]:
		var shader: Shader = load(path) as Shader
		assert_not_null(shader, path)
		assert_gt(shader.code.length(), 100)
	var image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	assert_eq(Ps2Look.make_material(texture, "characters", _profile()).shader.resource_path, "res://shaders/ps2_lit.gdshader")
	assert_eq(Ps2Look.make_material(texture, "city_tiles", _profile()).shader.resource_path, "res://shaders/ps2_lit_crisp.gdshader")
	var material: ShaderMaterial = Ps2Look.make_material(texture, "characters", _profile(), Color(0.5, 0.5, 0.5))
	assert_eq(material.get_shader_parameter("albedo_texture"), texture)
	assert_eq(material.get_shader_parameter("albedo_tint"), Color(0.5, 0.5, 0.5))


func test_the_importer_gives_final_art_the_ps2_material_with_mipmaps() -> void:
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var standard: StandardMaterial3D = StandardMaterial3D.new()
	standard.albedo_texture = ImageTexture.create_from_image(image)
	standard.roughness_texture = ImageTexture.create_from_image(image)
	standard.albedo_color = Color(0.9, 0.8, 0.7)
	var material: ShaderMaterial = load("res://scripts/tools/psx_post_import.gd").call("make_ps2_material", standard)
	assert_eq(material.shader.resource_path, "res://shaders/ps2_lit.gdshader")
	assert_true((material.get_shader_parameter("albedo_texture") as Texture2D).get_image().has_mipmaps(), "mipmaps for the smooth sampler")
	assert_not_null(material.get_shader_parameter("orm_texture"))
	assert_eq(material.get_shader_parameter("albedo_tint"), Color(0.9, 0.8, 0.7))
	# and the old importer path is untouched
	var old: ShaderMaterial = load("res://scripts/tools/psx_post_import.gd").call("make_psx_material", standard)
	assert_eq(old.shader.resource_path, "res://shaders/psx_lit.gdshader")


func test_upgrading_a_placeholder_keeps_its_texture_and_goes_crisp() -> void:
	var model: Node3D = (load(GRUNT) as PackedScene).instantiate() as Node3D
	own(model)
	var before: Texture2D = null
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		before = ((node as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial).get_shader_parameter("albedo_texture")
		break
	Ps2Look.upgrade_model(model, GRUNT, _profile())
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		var upgraded: ShaderMaterial = mi.get_surface_override_material(0) as ShaderMaterial
		assert_eq(upgraded.shader.resource_path, "res://shaders/ps2_lit_crisp.gdshader", "placeholders stay crisp pixels")
		assert_eq(upgraded.get_shader_parameter("albedo_texture"), before, "same texture")
		assert_eq((mi.mesh.surface_get_material(0) as ShaderMaterial).shader.resource_path, "res://shaders/psx_lit.gdshader", "the shared mesh material is not edited")
		break


func test_swords_get_a_neon_pick_and_characters_get_the_edge_light() -> void:
	var sword: Node3D = (load(SWORD) as PackedScene).instantiate() as Node3D
	own(sword)
	Ps2Look.upgrade_model(sword, SWORD, _profile())
	var found: bool = false
	for node: Node in sword.find_children("*", "MeshInstance3D", true, false):
		var material: ShaderMaterial = (node as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
		assert_gt(float(material.get_shader_parameter("emissive_pick")), 0.3, "the blade's glow lines can bloom")
		found = true
	assert_true(found)
	LookProfiles.apply(PS2)
	var wolf: Node3D = (load(WOLF) as PackedScene).instantiate() as Node3D
	own(wolf)
	LookProfiles.dress_model(wolf, WOLF, "enemy")
	for node: Node in wolf.find_children("*", "MeshInstance3D", true, false):
		var material: ShaderMaterial = (node as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
		assert_not_null(material, "dressed")
		assert_almost_eq(float(material.get_shader_parameter("rim_strength")), 0.5, 0.001, "the cool enemy edge light from the profile")
		assert_eq(material.shader.resource_path, "res://shaders/ps2_lit.gdshader", "dressing keeps the PS2 shader")
