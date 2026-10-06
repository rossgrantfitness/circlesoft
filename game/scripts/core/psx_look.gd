class_name PsxLook
extends RefCounted
## The switches behind the PSX look. Each effect is one global shader uniform (declared in
## project.godot), so flipping it changes every material at once. The debug overlay calls this.
##
##   PsxLook.set_effect(PsxLook.Effect.FOG, false)
##
## "On" restores the value from project.godot (so a tuned strength is not lost); "off" writes 0.

enum Effect { JITTER, WARP, FOG, VERTEX_LIGHTING, DITHER, COLOR_DEPTH }

const SNAP_RES_GLOBAL: StringName = &"psx_snap_res"
const FOG_COLOR_GLOBAL: StringName = &"psx_fog_color"
const FOG_NEAR_GLOBAL: StringName = &"psx_fog_near"
const FOG_FAR_GLOBAL: StringName = &"psx_fog_far"
const SETTING_PREFIX: String = "shader_globals/"
const SETTING_VALUE_KEY: String = "value"
const OFF_VALUE: float = 0.0

const EFFECT_GLOBALS: Dictionary[Effect, StringName] = {
	Effect.JITTER: &"psx_jitter_strength",
	Effect.WARP: &"psx_affine_strength",
	Effect.FOG: &"psx_fog_enabled",
	Effect.VERTEX_LIGHTING: &"psx_vertex_lighting",
	Effect.DITHER: &"psx_dither_enabled",
	Effect.COLOR_DEPTH: &"psx_color_depth_enabled",
}

const EFFECT_NAMES: Dictionary[Effect, String] = {
	Effect.JITTER: "Vertex jitter",
	Effect.WARP: "Affine warp",
	Effect.FOG: "Fog",
	Effect.VERTEX_LIGHTING: "Vertex lighting",
	Effect.DITHER: "Dither",
	Effect.COLOR_DEPTH: "15-bit color",
}

# What the effects are currently set to (the renderer can't always be asked, e.g. headless).
static var _current: Dictionary[StringName, float] = {}


## The value project.godot gives a global (what "on" means for it).
static func default_value(global_name: StringName) -> Variant:
	var setting: Dictionary = ProjectSettings.get_setting(SETTING_PREFIX + String(global_name), {})
	return setting.get(SETTING_VALUE_KEY, null)


static func is_effect_on(effect: Effect) -> bool:
	var global_name: StringName = EFFECT_GLOBALS[effect]
	if _current.has(global_name):
		return _current[global_name] > OFF_VALUE
	return float(default_value(global_name)) > OFF_VALUE


static func set_effect(effect: Effect, enabled: bool) -> void:
	var global_name: StringName = EFFECT_GLOBALS[effect]
	var value: float = float(default_value(global_name)) if enabled else OFF_VALUE
	_current[global_name] = value
	RenderingServer.global_shader_parameter_set(global_name, value)


static func toggle_effect(effect: Effect) -> bool:
	var now_on: bool = not is_effect_on(effect)
	set_effect(effect, now_on)
	return now_on


## Puts every effect back to its project.godot value.
static func reset_effects() -> void:
	for effect: Effect in EFFECT_GLOBALS:
		set_effect(effect, true)


## Tells the shaders the internal render resolution (the vertex snap grid).
static func set_internal_resolution(size: Vector2i) -> void:
	RenderingServer.global_shader_parameter_set(SNAP_RES_GLOBAL, Vector2(size))


## Sets the fog the shaders use. Rooms call this when they load (see PsxRoomLook).
static func set_fog(color: Color, near: float, far: float) -> void:
	RenderingServer.global_shader_parameter_set(FOG_COLOR_GLOBAL, color)
	RenderingServer.global_shader_parameter_set(FOG_NEAR_GLOBAL, near)
	RenderingServer.global_shader_parameter_set(FOG_FAR_GLOBAL, far)
