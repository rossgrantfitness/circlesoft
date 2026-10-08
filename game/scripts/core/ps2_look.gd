class_name Ps2Look
extends Node
## The early-PS2 look (docs/pivot/combat_api.md section 6), switched by the look profile "grim_ps2".
##
## Put one of these in a scene that wants the PS2 look (the combat sandbox does). It is "look-aware": whenever
## LookProfiles applies a profile it calls apply_look(), and
##   * for a profile with a `screen` block (grim_ps2) it sets the internal picture (640x360) and the smooth scale-up,
##     turns the PSX retro effects off (vertex jitter, affine warp, dither, 15-bit colour), sets the smooth fog,
##     and dresses the scene's WorldEnvironment (glow) and key DirectionalLight3D (real-time shadow);
##   * for any other profile it puts everything back (so F11 can flip between grim and grim_ps2 and the old game's
##     look is exactly as it was).
## A scene that has no Ps2Look is untouched by all of this: the old game never loads one.
##
## The static helpers do the actual work and are what the tests call; they take the profile dictionary, so nothing
## here is hard-coded: every number lives in data/world/look_profiles.json.

## Where to find the sandbox's own nodes. Empty = look for a WorldEnvironment and the first DirectionalLight3D
## among this node's siblings (anywhere under the parent).
@export var world_environment_path: NodePath = NodePath()
@export var key_light_path: NodePath = NodePath()

const SCREEN_GROUP: StringName = &"psx_screen"
const LOOK_DATA_ID: String = "world/psx_look"
const GROUPS: PackedStringArray = ["characters", "enemies", "weapons", "placeholders", "city_tiles", "default"]
const SMOOTH: String = "smooth"
const NEAREST: String = "nearest"
const PS2_SHADER_PATH: String = "res://shaders/ps2_lit.gdshader"
const CRISP_SHADER_PATH: String = "res://shaders/ps2_lit_crisp.gdshader"
const PSX_LIT_SHADER_PATH: String = "res://shaders/psx_lit.gdshader"
## Parameters copied from an old PSX material when it is upgraded to the PS2 shader.
const COPIED_PARAMS: PackedStringArray = ["albedo_texture", "albedo_tint", "uv_scale", "uv_offset", "alpha_cutoff", "rim_color",
		"rim_strength", "rim_power", "rim_top_bias", "rim_bands"]
const BLEND_MODES: Dictionary[String, int] = {
	"additive": Environment.GLOW_BLEND_MODE_ADDITIVE, "screen": Environment.GLOW_BLEND_MODE_SCREEN,
	"softlight": Environment.GLOW_BLEND_MODE_SOFTLIGHT, "replace": Environment.GLOW_BLEND_MODE_REPLACE,
	"mix": Environment.GLOW_BLEND_MODE_MIX}
const SHADOW_MODES: Dictionary[String, int] = {
	"orthogonal": DirectionalLight3D.SHADOW_ORTHOGONAL, "parallel_2_splits": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
	"parallel_4_splits": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS}
const SHADOW_QUALITIES: Dictionary[String, int] = {
	"hard": RenderingServer.SHADOW_QUALITY_HARD, "soft_very_low": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	"soft_low": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "soft_medium": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM}

var _applied: bool = false
var _saved_environment: Dictionary = {}
var _saved_light: Dictionary = {}
var _saved_camera: Dictionary = {}


func _ready() -> void:
	add_to_group(LookProfiles.GROUP_AWARE)
	apply_look(LookProfiles.active_id(), LookProfiles.active())


func _exit_tree() -> void:
	if _applied:
		_leave()


## LookProfiles calls this whenever a profile is switched on.
func apply_look(_id: String, profile: Dictionary) -> void:
	if is_ps2_profile(profile):
		_enter(profile)
	elif _applied:
		_leave()


func is_applied() -> bool:
	return _applied


# ---- entering and leaving ----

func _enter(profile: Dictionary) -> void:
	var screen: PsxScreen = _screen()
	if screen != null:
		apply_screen(screen, profile)
	apply_effects(profile)
	apply_fog(profile)
	var environment: Environment = _environment()
	if environment != null:
		if not _applied:
			_saved_environment = save_environment(environment)
		apply_environment(environment, profile)
	var light: DirectionalLight3D = _key_light()
	if light != null:
		if not _applied:
			_saved_light = {"shadow_enabled": light.shadow_enabled, "directional_shadow_mode": light.directional_shadow_mode,
					"directional_shadow_max_distance": light.directional_shadow_max_distance, "shadow_bias": light.shadow_bias,
					"shadow_normal_bias": light.shadow_normal_bias, "shadow_blur": light.shadow_blur,
					"directional_shadow_blend_splits": light.directional_shadow_blend_splits}
		apply_shadows(light, profile)
	var camera: Camera3D = _camera()
	if camera != null:
		if not _applied:
			_saved_camera = {"far": camera.far, "near": camera.near}
		apply_camera(camera, profile)
	_applied = true


func _leave() -> void:
	_applied = false
	var screen: PsxScreen = _screen()
	if screen != null:
		restore_screen(screen)
	PsxLook.reset_effects()
	var environment: Environment = _environment()
	if environment != null and not _saved_environment.is_empty():
		for property: String in _saved_environment:
			environment.set(property, _saved_environment[property])
	var light: DirectionalLight3D = _key_light()
	if light != null and not _saved_light.is_empty():
		for property: String in _saved_light:
			light.set(property, _saved_light[property])
	var camera: Camera3D = _camera()
	if camera != null and not _saved_camera.is_empty():
		for property: String in _saved_camera:
			camera.set(property, _saved_camera[property])


func _screen() -> PsxScreen:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(SCREEN_GROUP) as PsxScreen


func _environment() -> Environment:
	var node: WorldEnvironment = null
	if not world_environment_path.is_empty():
		node = get_node_or_null(world_environment_path) as WorldEnvironment
	elif get_parent() != null:
		node = get_parent().find_child("WorldEnvironment", true, false) as WorldEnvironment
	return node.environment if node != null else null


func _camera() -> Camera3D:
	if get_parent() == null:
		return null
	for found: Node in get_parent().find_children("*", "Camera3D", true, false):
		return found as Camera3D
	return null


func _key_light() -> DirectionalLight3D:
	if not key_light_path.is_empty():
		return get_node_or_null(key_light_path) as DirectionalLight3D
	if get_parent() == null:
		return null
	for found: Node in get_parent().find_children("*", "DirectionalLight3D", true, false):
		return found as DirectionalLight3D
	return null


# ---- the profile ----

## True for a profile written for this look (it has a `screen` block).
static func is_ps2_profile(profile: Dictionary) -> bool:
	return profile.has("screen")


static func block(profile: Dictionary, key: String) -> Dictionary:
	var found: Variant = profile.get(key, {})
	return found as Dictionary if found is Dictionary else {}


## "smooth" or "nearest" for a texture group (unknown groups use the profile's "default").
static func filter_for(profile: Dictionary, group: String) -> String:
	var filters: Dictionary = block(profile, "texture_filter")
	var wanted: String = str(filters.get(group, filters.get("default", SMOOTH)))
	return wanted if wanted == NEAREST else SMOOTH


## Which texture group a model path belongs to.
static func group_for_path(path: String) -> String:
	if path.contains("/placeholder/"):
		return "placeholders"
	if path.contains("/weapons/"):
		return "weapons"
	if path.contains("/enemies/"):
		return "enemies"
	if path.contains("/characters/"):
		return "characters"
	if path.contains("city") or path.contains("/environments/"):
		return "city_tiles"
	return "default"


static func shader_path_for(profile: Dictionary, group: String) -> String:
	var shaders: Dictionary = block(profile, "shader")
	if filter_for(profile, group) == NEAREST:
		return str(shaders.get(NEAREST, CRISP_SHADER_PATH))
	return str(shaders.get(SMOOTH, PS2_SHADER_PATH))


# ---- the screen and the retro effects ----

static func apply_screen(screen: PsxScreen, profile: Dictionary) -> void:
	var screen_block: Dictionary = block(profile, "screen")
	var wanted: Vector2i = resolution_of(str(screen_block.get("resolution", "")))
	if wanted != Vector2i.ZERO and screen.get_resolution() != wanted:
		screen.set_resolution(wanted)
	var display: TextureRect = screen.get_display()
	if display != null:
		display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if bool(screen_block.get("smooth_scale", true)) else CanvasItem.TEXTURE_FILTER_NEAREST


## Back to the old game's picture: its default resolution and the sharp (nearest) scale-up.
static func restore_screen(screen: PsxScreen) -> void:
	var default_id: String = str(DataDB.get_value(LOOK_DATA_ID, "default_resolution", ""))
	var wanted: Vector2i = resolution_of(default_id)
	if wanted != Vector2i.ZERO and screen.get_resolution() != wanted:
		screen.set_resolution(wanted)
	var display: TextureRect = screen.get_display()
	if display != null:
		display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## "640x360" -> Vector2i(640, 360) from data/world/psx_look.json (ZERO if the id is not listed).
static func resolution_of(id: String) -> Vector2i:
	var entries: Variant = DataDB.get_value(LOOK_DATA_ID, "resolutions", [])
	if entries is Array:
		for entry: Variant in entries:
			var dict: Dictionary = entry
			if str(dict.get("id", "")) == id:
				return Vector2i(int(dict["width"]), int(dict["height"]))
	return Vector2i.ZERO


## Vertex jitter, affine warp, dither and 15-bit colour, each on or off from the profile.
static func apply_effects(profile: Dictionary) -> void:
	var wobble: Dictionary = block(profile, "retro_wobble")
	PsxLook.set_effect(PsxLook.Effect.JITTER, float(wobble.get("jitter", 0.0)) > 0.0)
	PsxLook.set_effect(PsxLook.Effect.WARP, float(wobble.get("affine", 0.0)) > 0.0)
	PsxLook.set_effect(PsxLook.Effect.DITHER, bool(block(profile, "dither").get("enabled", false)))
	PsxLook.set_effect(PsxLook.Effect.COLOR_DEPTH, bool(block(profile, "color_depth").get("enabled", false)))


## The smooth fog the PS2 shaders read (the globals PsxLook sets).
static func apply_fog(profile: Dictionary) -> void:
	var fog: Dictionary = block(profile, "fog")
	var color: Color = Color.html(str(fog.get("color", "#2a2c24")))
	PsxLook.set_fog(color, float(fog.get("near_m", 18.0)), float(fog.get("far_m", 75.0)))


# ---- environment (glow) and the key light (shadow) ----

## The Environment properties a profile's glow block sets (property -> value). Empty glow block = glow off.
static func environment_values(profile: Dictionary) -> Dictionary:
	var glow: Dictionary = block(profile, "glow")
	var out: Dictionary = {"glow_enabled": bool(glow.get("enabled", false))}
	if not bool(glow.get("enabled", false)):
		return out
	out["glow_intensity"] = float(glow.get("intensity", 0.8))
	out["glow_strength"] = float(glow.get("strength", 1.0))
	out["glow_bloom"] = float(glow.get("bloom", 0.0))
	out["glow_hdr_threshold"] = float(glow.get("hdr_threshold", 1.0))
	out["glow_hdr_scale"] = float(glow.get("hdr_scale", 2.0))
	out["glow_blend_mode"] = int(BLEND_MODES.get(str(glow.get("blend", "screen")), Environment.GLOW_BLEND_MODE_SCREEN))
	var levels: Variant = glow.get("levels", [])
	if levels is Array:
		for index: int in mini((levels as Array).size(), 7):
			out["glow_levels/%d" % (index + 1)] = float((levels as Array)[index])
	return out


static func apply_environment(environment: Environment, profile: Dictionary) -> void:
	var values: Dictionary = environment_values(profile)
	for property: String in values:
		environment.set(property, values[property])


static func save_environment(environment: Environment) -> Dictionary:
	var saved: Dictionary = {}
	for property: String in environment_values({"glow": {"enabled": true, "levels": [0, 0, 0, 0, 0, 0, 0]}}):
		saved[property] = environment.get(property)
	return saved


## One shadow-casting key light: soft-low filter, about 20 m of shadow, two splits.
static func apply_shadows(light: DirectionalLight3D, profile: Dictionary) -> void:
	var shadows: Dictionary = block(profile, "shadows")
	light.shadow_enabled = bool(shadows.get("enabled", false))
	if not light.shadow_enabled:
		return
	light.directional_shadow_mode = int(SHADOW_MODES.get(str(shadows.get("mode", "parallel_2_splits")), DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)) as DirectionalLight3D.ShadowMode
	light.directional_shadow_max_distance = float(shadows.get("max_distance_m", 20.0))
	light.shadow_bias = float(shadows.get("bias", 0.05))
	light.shadow_normal_bias = float(shadows.get("normal_bias", 1.0))
	light.shadow_blur = float(shadows.get("blur", 1.0))
	light.directional_shadow_blend_splits = bool(shadows.get("blend_splits", true))
	if shadows.has("atlas_px"):
		RenderingServer.directional_shadow_atlas_set_size(int(shadows["atlas_px"]), true)
	var quality: int = int(SHADOW_QUALITIES.get(str(shadows.get("filter", "soft_low")), RenderingServer.SHADOW_QUALITY_SOFT_LOW))
	RenderingServer.directional_soft_shadow_filter_set_quality(quality as RenderingServer.ShadowQuality)
	RenderingServer.positional_soft_shadow_filter_set_quality(quality as RenderingServer.ShadowQuality)


## A long far plane (no draw-distance limit for authenticity's sake). Profile `camera`: far_m, near_m.
static func apply_camera(camera: Camera3D, profile: Dictionary) -> void:
	var block_data: Dictionary = block(profile, "camera")
	if block_data.has("far_m"):
		camera.far = float(block_data["far_m"])
	if block_data.has("near_m"):
		camera.near = float(block_data["near_m"])


# ---- materials ----

## A fresh PS2 material for a texture in a texture group (smooth or crisp by the profile).
static func make_material(texture: Texture2D, group: String, profile: Dictionary, tint: Color = Color.WHITE) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(shader_path_for(profile, group)) as Shader
	if texture != null:
		material.set_shader_parameter(&"albedo_texture", texture)
	material.set_shader_parameter(&"albedo_tint", tint)
	material.set_shader_parameter(&"use_orm", 0.0)
	return material


## Makes every surface of a model use the PS2 shader for its texture group (surface overrides on this model's own
## meshes; nothing shared is edited). Models that already use the right shader keep their material. Old PSX
## materials (the placeholders) keep their texture, tint and edge-light settings. Weapons get a neon pick so
## their glow lines bloom.
static func upgrade_model(model: Node, source_path: String, profile: Dictionary) -> void:
	if model == null or not is_ps2_profile(profile):
		return
	var group: String = group_for_path(source_path)
	var shader: Shader = load(shader_path_for(profile, group)) as Shader
	var neon: float = float(block(block(profile, "glow"), "neon_pick").get(group, 0.0))
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: ShaderMaterial = mesh_instance.get_active_material(surface) as ShaderMaterial
			if source == null:
				continue
			var copy: ShaderMaterial = source.duplicate() as ShaderMaterial
			if copy.shader != shader:
				var old_shader: Shader = copy.shader
				copy.shader = shader
				if old_shader != null and old_shader.resource_path == PSX_LIT_SHADER_PATH:
					copy.set_shader_parameter(&"use_orm", 0.0)
			if neon > 0.0:
				copy.set_shader_parameter(&"emissive_pick", neon)
			mesh_instance.set_surface_override_material(surface, copy)
