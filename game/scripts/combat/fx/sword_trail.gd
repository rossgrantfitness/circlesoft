class_name SwordTrail
extends Node3D
## The glowing ribbon a sword leaves behind a swing (combat_api.md 4.7 and 4.6: `move_started` with `trail: true`
## switches it on for the swing's active phase; FX flips `set_active`). Built from the blade's two ends
## (GearVisuals.blade_points(): `base` near the guard, `tip` at the point): every frame the world positions of both are
## remembered, and a triangle strip is drawn between consecutive samples, fading with age.
##
## It lives in world space (top level), so it hangs in the air where the sword was while Red moves on. Its clock is the
## owner's combat clock, not real time: call `set_time_scale()` with the fighter's scale (0 in hit-stop, below 1 in a
## Lamp Flare), so trails freeze and slow with their fighter (combat_api.md 4.1). It never casts a shadow.
##
## Pure parts (testable without a scene): `ribbon_arrays()`, `prune()`.

const SHADER_PATH: String = "res://shaders/sword_trail.gdshader"
const DEFAULT_COLOR: Color = Color(0.31, 0.85, 1.0, 1.0)

@export var color: Color = DEFAULT_COLOR
## Seconds of combat time a sample lives. Short trails read as speed; long ones as smear.
@export var max_age_s: float = 0.22
@export var max_samples: int = 24
## Brightness above 1 so the trail blooms (the profile's glow threshold sits just under it).
@export var glow: float = 1.8
## Samples are only added when the blade moved at least this far (metres), so a still sword leaves nothing.
@export var min_step_m: float = 0.015

var _base: Node3D = null
var _tip: Node3D = null
var _active: bool = false
var _time_scale: float = 1.0
var _samples: Array[Dictionary] = []     # {base: Vector3, tip: Vector3, age: float}, newest last
var _mesh: ArrayMesh = ArrayMesh.new()
var _instance: MeshInstance3D = null
var _material: ShaderMaterial = null


func _ready() -> void:
	top_level = true
	_instance = MeshInstance3D.new()
	_instance.name = "Ribbon"
	_instance.mesh = _mesh
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.extra_cull_margin = 4.0
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH) as Shader
	_material.set_shader_parameter(&"glow", glow)
	_instance.material_override = _material
	add_child(_instance)
	global_transform = Transform3D.IDENTITY


## `points` is GearVisuals.blade_points(): {base: Node3D, tip: Node3D}.
func bind_blade(points: Dictionary) -> void:
	_base = points.get("base") as Node3D
	_tip = points.get("tip") as Node3D
	_samples.clear()


func set_color(new_color: Color) -> void:
	color = new_color


## On while a swing's active phase runs; off lets what is left fade out.
func set_active(on: bool) -> void:
	_active = on


func is_active() -> bool:
	return _active


## The fighter's time scale: 0 freezes the trail (hit-stop), 0.3 slows it (a Lamp Flare), 1 is normal.
func set_time_scale(scale: float) -> void:
	_time_scale = maxf(scale, 0.0)


func sample_count() -> int:
	return _samples.size()


func clear() -> void:
	_samples.clear()
	_mesh.clear_surfaces()


func _process(delta: float) -> void:
	step(delta * _time_scale)


## Advances the trail by `dt` seconds of combat time: ages the samples, adds the blade's current position when active.
func step(dt: float) -> void:
	if dt > 0.0:
		for sample: Dictionary in _samples:
			sample["age"] = float(sample["age"]) + dt
	prune(_samples, max_age_s, max_samples)
	if _active and dt > 0.0 and _base != null and _tip != null and is_instance_valid(_base) and is_instance_valid(_tip):
		var base_pos: Vector3 = _base.global_position
		var tip_pos: Vector3 = _tip.global_position
		if _samples.is_empty() or (_samples[-1]["tip"] as Vector3).distance_to(tip_pos) >= min_step_m:
			_samples.append({"base": base_pos, "tip": tip_pos, "age": 0.0})
	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _samples.size() < 2:
		return
	var arrays: Array = ribbon_arrays(_samples, max_age_s, color)
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	_material.set_shader_parameter(&"glow", glow)


## Drops samples that are too old, and the oldest ones beyond `limit`. Pure.
static func prune(samples: Array[Dictionary], max_age: float, limit: int) -> void:
	while not samples.is_empty() and float(samples[0]["age"]) > max_age:
		samples.remove_at(0)
	while samples.size() > limit:
		samples.remove_at(0)


## The mesh arrays for a triangle strip through the samples (oldest first): two vertices per sample (base, tip), the
## colour's alpha fading from 1 (new) to 0 (at max_age), UV.x 0 at the base and 1 at the tip. Pure.
static func ribbon_arrays(samples: Array[Dictionary], max_age: float, tint: Color) -> Array:
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var count: int = samples.size()
	for index: int in count:
		var sample: Dictionary = samples[index]
		var life: float = clampf(1.0 - float(sample["age"]) / maxf(max_age, 0.0001), 0.0, 1.0)
		var faded: Color = Color(tint.r, tint.g, tint.b, tint.a * life * life)
		vertices.append(sample["base"])
		vertices.append(sample["tip"])
		colors.append(faded)
		colors.append(faded)
		uvs.append(Vector2(0.0, float(index) / float(maxi(count - 1, 1))))
		uvs.append(Vector2(1.0, float(index) / float(maxi(count - 1, 1))))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return arrays
