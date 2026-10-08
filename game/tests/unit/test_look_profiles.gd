extends TestCase
## The switchable look profiles (data/world/look_profiles.json, scripts/core/look_profiles.gd): "classic" is
## the toy-box look Ross approved first and must stay an exact no-op; "grim" is the 2026-10-08 look test.

const POST_SHADER: String = "res://shaders/psx_post.gdshader"
const RED_CLASSIC: String = "res://art/placeholder/characters/red/red_shiba.glb"
const RED_GRIM: String = "res://art/placeholder/characters/red/red_shiba_grim.glb"
const LOOK_TEST_SCENES: Array[String] = ["harrow_square", "harrow_checkpoint", "battle"]


func after_each() -> void:
	LookProfiles.reset()


func _material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(POST_SHADER) as Shader
	return material


# ---- the data ----

func test_the_file_has_classic_and_grim_and_defaults_to_classic() -> void:
	assert_true(LookProfiles.has_profile("classic"))
	assert_true(LookProfiles.has_profile("grim"))
	assert_eq(LookProfiles.default_id(), "classic", "classic stays the default everywhere")
	assert_eq(LookProfiles.active_id(), "classic", "nothing asked yet: the default")


func test_only_the_look_test_scenes_are_grim_by_default() -> void:
	for key: String in LOOK_TEST_SCENES:
		assert_eq(LookProfiles.scene_default(key), "grim", key + " is a look-test scene")
	for key: String in ["harrow_bar", "harrow_home", "harrow_docks", "title", "road_mast_road", "nonsense"]:
		assert_eq(LookProfiles.scene_default(key), "classic", key + " stays classic until Ross signs off")
	var listed: Dictionary = DataDB.get_dict("world/look_profiles")["scene_defaults"]
	for key: Variant in listed:
		if not str(key).begins_with("_"):
			assert_has(LOOK_TEST_SCENES, str(key), "only look-test scenes are listed")


func test_classic_is_an_exact_no_op() -> void:
	var params: Dictionary = LookProfiles.grade_parameters("classic")
	assert_eq(params["grade_amount"], 0.0, "the post shader passes the picture through")
	assert_eq(params["color_levels"], 32.0, "15-bit color as before")
	assert_eq(params["dither_amount"], 1.0)
	assert_false(LookProfiles.flag("classic", "dressing", true), "no props, no grime")
	assert_false(LookProfiles.dulls_characters_for("classic"), "characters untouched")
	assert_eq((LookProfiles.profile("classic")["models"] as Dictionary).size(), 0, "no model variants")
	assert_eq(LookProfiles.number("classic", "lighting.ambient_energy_mul", 0.0), 1.0)
	assert_eq(LookProfiles.number("classic", "lighting.point_energy_mul", 0.0), 1.0)
	assert_eq(LookProfiles.number("classic", "lighting.key_energy_mul", 0.0), 1.0)
	assert_eq(LookProfiles.number("classic", "fog.mix", -1.0), 0.0, "fog keeps the room's own color")
	assert_eq(LookProfiles.number("classic", "fog.near_mul", 0.0), 1.0)
	assert_eq(LookProfiles.number("classic", "materials.saturation", 0.0), 1.0)
	assert_eq(LookProfiles.number("classic", "materials.value", 0.0), 1.0)
	var untouched: Color = Color(0.85, 0.62, 0.3, 1.0)
	assert_eq(LookProfiles.grade_color(untouched, "classic"), untouched)


func test_grim_is_clearly_not_subtle() -> void:
	# Ross (2026-10-08): "desaturate, darken, grime things up a bit": every control points the right way, firmly.
	assert_eq(LookProfiles.number("grim", "grade.amount", 0.0), 1.0)
	assert_ge(LookProfiles.number("grim", "grade.desat", 0.0), 0.6, "colour mostly drained")
	assert_gt(LookProfiles.number("grim", "grade.gamma", 1.0), 1.05, "darker mids")
	assert_gt(LookProfiles.number("grim", "grade.crush", 0.0), 0.0, "crushed blacks")
	assert_gt(LookProfiles.number("grim", "grade.grain", 0.0), 0.04, "film grain")
	assert_gt(LookProfiles.number("grim", "grade.tint_amount", 0.0), 0.3, "sodium / teal split tone")
	assert_gt(LookProfiles.number("grim", "grade.accent_keep", 0.0), 0.5, "lamps, warning stripes and the call keep their colour")
	assert_lt(LookProfiles.number("grim", "post.color_levels", 32.0), 32.0, "chunkier banding")
	assert_gt(LookProfiles.number("grim", "post.dither_amount", 1.0), 1.0, "more dither grain")
	assert_lt(LookProfiles.number("grim", "materials.saturation", 1.0), 0.7)
	assert_lt(LookProfiles.number("grim", "fog.near_mul", 1.0), 1.0, "dirtier fog starts earlier")
	assert_true(LookProfiles.flag("grim", "dressing", false))
	assert_true(LookProfiles.dulls_characters_for("grim"))


func test_unknown_profile_reads_as_classic() -> void:
	assert_eq(LookProfiles.number("no_such", "no.such.key", 5.0), 5.0, "a missing key gives the fallback")
	assert_eq(LookProfiles.number("no_such", "grade.amount", 5.0), 0.0, "an unknown profile reads the classic values")
	assert_eq(LookProfiles.profile("no_such"), LookProfiles.profile("classic"))
	LookProfiles.apply("no_such")
	assert_eq(LookProfiles.active_id(), "classic")


# ---- which profile a scene gets ----

func test_a_scene_asks_for_its_own_profile() -> void:
	assert_eq(LookProfiles.enter_scene("harrow_square"), "grim")
	assert_eq(LookProfiles.active_id(), "grim")
	assert_true(LookProfiles.is_grim())
	assert_eq(LookProfiles.enter_scene("harrow_bar"), "classic")
	assert_eq(LookProfiles.active_id(), "classic")
	assert_eq(LookProfiles.scene_key(), "harrow_bar")


func test_forcing_a_profile_beats_the_scene_default_and_cycles_through_auto() -> void:
	assert_eq(LookProfiles.forced_id(), "", "auto at start")
	assert_eq(LookProfiles.cycle_forced(), "classic", "auto -> classic")
	assert_eq(LookProfiles.enter_scene("harrow_square"), "classic", "forced classic beats the square's grim")
	assert_eq(LookProfiles.cycle_forced(), "grim", "classic -> grim")
	assert_eq(LookProfiles.enter_scene("harrow_bar"), "grim", "forced grim beats the bar's classic")
	assert_eq(LookProfiles.cycle_forced(), "", "grim -> auto")
	assert_eq(LookProfiles.active_id(), "classic", "auto again: the scene (the bar) decides")
	LookProfiles.set_forced("grim")
	assert_eq(LookProfiles.active_id(), "grim")
	LookProfiles.set_forced("nonsense")
	assert_eq(LookProfiles.forced_id(), "", "an unknown id means auto")


func test_look_aware_nodes_are_told_when_the_profile_changes() -> void:
	var listener: _Listener = _Listener.new()
	add_to_root(listener)
	LookProfiles.apply("grim")
	assert_eq(listener.seen, ["grim"])
	LookProfiles.apply("classic")
	assert_eq(listener.seen, ["grim", "classic"])


class _Listener extends Node:
	var seen: Array[String] = []

	func _ready() -> void:
		add_to_group(LookProfiles.GROUP_AWARE)

	func apply_look(id: String, _profile: Dictionary) -> void:
		seen.append(id)


# ---- the screen grade ----

func test_the_post_shader_has_every_grade_control_and_is_off_by_default() -> void:
	var material: ShaderMaterial = _material()
	var amount: Variant = material.get_shader_parameter("grade_amount")
	assert_true(amount == null or amount == 0.0, "off until a profile turns it on (the shader's own default is 0)")
	assert_has((material.shader.code as String), "uniform float grade_amount : hint_range(0.0, 1.0) = 0.0;")
	var names: Array[String] = []
	for entry: Dictionary in material.shader.get_shader_uniform_list():
		names.append(str(entry["name"]))
	for key: String in LookProfiles.SCREEN_PARAMS.values():
		assert_has(names, key, key + " is a post-shader uniform")
	for key: String in LookProfiles.SCREEN_COLOR_PARAMS.values():
		assert_has(names, key)
	assert_has(names, "grade_amount")


func test_apply_grade_writes_the_profile_into_the_post_material() -> void:
	var material: ShaderMaterial = _material()
	LookProfiles.apply_grade(material, "grim")
	assert_eq(material.get_shader_parameter("grade_amount"), 1.0)
	assert_eq(material.get_shader_parameter("grade_desat"), LookProfiles.number("grim", "grade.desat", -1.0))
	assert_eq(material.get_shader_parameter("color_levels"), LookProfiles.number("grim", "post.color_levels", -1.0))
	assert_true(material.get_shader_parameter("grade_shadow_tint") is Vector3)
	LookProfiles.apply_grade(material, "classic")
	assert_eq(material.get_shader_parameter("grade_amount"), 0.0, "switching back switches the grade off")
	assert_eq(material.get_shader_parameter("color_levels"), 32.0)
	assert_eq(material.get_shader_parameter("dither_amount"), 1.0)


func test_apply_reaches_every_psx_screen_in_the_tree() -> void:
	var screen: PsxScreen = (load("res://scenes/core/psx_screen.tscn") as PackedScene).instantiate() as PsxScreen
	add_to_root(screen)
	var material: ShaderMaterial = screen.get_display().material as ShaderMaterial
	assert_eq(material.get_shader_parameter("grade_amount"), 0.0, "a fresh screen is classic")
	LookProfiles.apply("grim")
	assert_eq(material.get_shader_parameter("grade_amount"), 1.0)
	LookProfiles.apply("classic")
	assert_eq(material.get_shader_parameter("grade_amount"), 0.0)
	LookProfiles.apply("grim")
	var second: PsxScreen = (load("res://scenes/core/psx_screen.tscn") as PackedScene).instantiate() as PsxScreen
	add_to_root(second)
	assert_eq((second.get_display().material as ShaderMaterial).get_shader_parameter("grade_amount"), 1.0, "a screen made later starts in the active look")


# ---- colors ----

func test_drain_takes_colour_and_brightness_away() -> void:
	var orange: Color = Color(0.9, 0.5, 0.1, 1.0)
	var grey: Color = LookProfiles.drain(orange, 0.0, 1.0)
	assert_almost_eq(grey.r, grey.g, 0.0001)
	assert_almost_eq(grey.g, grey.b, 0.0001)
	var half: Color = LookProfiles.drain(orange, 0.5, 1.0)
	assert_lt(half.r - half.b, orange.r - orange.b, "less spread between channels")
	var dark: Color = LookProfiles.drain(orange, 1.0, 0.5)
	assert_almost_eq(dark.r, 0.45, 0.0001)
	var same: Color = LookProfiles.drain(orange, 1.0, 1.0)
	assert_almost_eq(same.r, orange.r, 0.0001, "saturation 1, value 1 changes nothing")
	assert_almost_eq(same.g, orange.g, 0.0001)
	assert_almost_eq(same.b, orange.b, 0.0001)
	var graded: Color = LookProfiles.grade_color(orange, "grim")
	assert_lt(graded.r - graded.b, orange.r - orange.b, "grim drains the spread")


# ---- models ----

func test_red_swaps_to_her_grim_shiba_only_in_grim() -> void:
	assert_eq(LookProfiles.resolve_model_for(RED_CLASSIC, "classic"), RED_CLASSIC)
	assert_eq(LookProfiles.resolve_model_for(RED_CLASSIC, "grim"), RED_GRIM)
	assert_eq(LookProfiles.resolve_model_for("res://art/placeholder/characters/otis/chr_otis.glb", "grim"), "res://art/placeholder/characters/otis/chr_otis.glb", "Otis keeps his model (his texture is dulled instead)")
	assert_true(LookProfiles.is_variant_path(RED_GRIM))
	assert_false(LookProfiles.is_variant_path(RED_CLASSIC))
	LookProfiles.apply("grim")
	assert_eq(LookProfiles.resolve_model(RED_CLASSIC), RED_GRIM)
	LookProfiles.apply("classic")
	assert_eq(LookProfiles.resolve_model(RED_CLASSIC), RED_CLASSIC)


func test_a_variant_that_is_not_there_falls_back_to_the_classic_model() -> void:
	LookProfiles.use_data_for_tests({"default": "classic", "profiles": {
		"classic": {"models": {}},
		"grim": {"models": {RED_CLASSIC: "res://art/placeholder/characters/red/not_built_yet.glb"}},
	}})
	assert_eq(LookProfiles.resolve_model_for(RED_CLASSIC, "grim"), RED_CLASSIC)


func test_the_look_key_changes_with_the_profile() -> void:
	var classic_key: String = LookProfiles.model_look_key(RED_CLASSIC)
	LookProfiles.apply("grim")
	assert_ne(LookProfiles.model_look_key(RED_CLASSIC), classic_key, "Red needs reloading when the look changes")
	var otis: String = "res://art/placeholder/characters/otis/chr_otis.glb"
	var grim_otis: String = LookProfiles.model_look_key(otis)
	LookProfiles.apply("classic")
	assert_ne(LookProfiles.model_look_key(otis), grim_otis, "so does anyone whose texture is dulled")


# ---- the battle set ----

func test_backdrop_look_is_unchanged_in_classic_and_overridden_in_grim() -> void:
	var base: Dictionary = BattleStageTuning.from_db(DataDB).backdrop("harrow")
	assert_eq(LookProfiles.backdrop_look(base, "classic"), base, "classic gives the backdrop back untouched")
	var grim: Dictionary = LookProfiles.backdrop_look(base, "grim")
	assert_ne(grim["floor_a"], base["floor_a"])
	assert_eq(grim["void"], LookProfiles.value("grim", "backdrop.void", ""))
	var base_lamp: float = float((base["lamps"] as Array)[0]["energy"])
	var grim_lamp: float = float((grim["lamps"] as Array)[0]["energy"])
	assert_almost_eq(grim_lamp, base_lamp * LookProfiles.number("grim", "backdrop.lamp_energy_mul", 1.0), 0.0001)
	assert_eq(str((grim["lamps"] as Array)[0]["color"]), str(LookProfiles.value("grim", "backdrop.lamp_color", "")))
	assert_eq(base["floor_a"], "#4A3F46", "the source dictionary was not edited")
