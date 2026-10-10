class_name TelegraphCue
extends Node3D
## The wind-up flash: when an enemy starts an attack that Red can answer, a pop of light on it and a ring that closes in on it and
## lands exactly on the moment of impact. That is the parry (or dodge) cue, readable from across the arena. The colour says which
## answer works: one colour for "parry it", another for "dodge it" (see fx.json `telegraph.kinds`; new kinds need no code).
##
## It is stepped by CombatFx with the attacker's own combat-clock delta, so in a Lamp Flare (enemies slow) or in hit-stop the ring
## slows and stops with the swing it is counting down.

const FLASH_SHADER: String = "res://shaders/fx_flash.gdshader"

var kind_config: Dictionary = {}
var settings: Dictionary = {}          # fx.json "telegraph" (anchor, flash_life_s, ring_from_m, ring_to_m)
var impact_in_s: float = 0.5
var target: Node3D = null              # the attacker it follows

var _t: float = 0.0
var _flash: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _flash_material: ShaderMaterial = null
var _ring_material: ShaderMaterial = null


func _ready() -> void:
	top_level = true
	var color: Color = Color.html(str(kind_config.get("color", "#ffd34a")))
	_flash = _make_quad("Flash", color, float(kind_config.get("intensity", 3.0)), 0.0)
	_flash_material = _flash.material_override as ShaderMaterial
	_ring = _make_quad("Ring", color, float(kind_config.get("ring_intensity", 2.4)), 1.0)
	_ring_material = _ring.material_override as ShaderMaterial
	_ring_material.set_shader_parameter(&"ring_radius", 0.9)
	_ring_material.set_shader_parameter(&"ring_width", 0.07)
	_follow()
	_update()


func _make_quad(node_name: String, color: Color, intensity: float, ring_amount: float) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(FLASH_SHADER) as Shader
	material.set_shader_parameter(&"tint", color)
	material.set_shader_parameter(&"intensity", intensity)
	material.set_shader_parameter(&"ring", ring_amount)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = quad
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 4.0
	add_child(instance)
	return instance


## Advances the cue by `dt` seconds of the attacker's combat time. Returns false when it is finished (the caller frees it).
func step(dt: float) -> bool:
	_t += maxf(dt, 0.0)
	_follow()
	_update()
	return _t < impact_in_s + 0.06


func elapsed() -> float:
	return _t


## Ring radius (metres) at `t` into a cue that lands at `impact_s` (pure): closes from `from_m` to `to_m`, quickest at the end.
static func ring_radius_at(t: float, impact_s: float, from_m: float, to_m: float) -> float:
	var k: float = clampf(t / maxf(impact_s, 0.01), 0.0, 1.0)
	return lerpf(from_m, to_m, k * k)


## The kind of cue for a telegraph signal (pure): the signal's own `telegraph_kind` if the data knows it, else parryable /
## unparryable by the `parryable` flag.
static func kind_for(info: Dictionary, kinds: Dictionary) -> String:
	var wanted: String = str(info.get("telegraph_kind", ""))
	if not wanted.is_empty() and kinds.has(wanted):
		return wanted
	return "parryable" if bool(info.get("parryable", true)) else "unparryable"


func _follow() -> void:
	if target == null or not is_instance_valid(target):
		return
	var point: Vector3 = target.global_position + Vector3.UP * 1.0
	if target.has_method("anchor"):
		point = target.call("anchor", StringName(str(settings.get("anchor", "head")))) as Vector3
	_flash.global_position = point
	_ring.global_position = point


func _update() -> void:
	var life: float = maxf(float(settings.get("flash_life_s", 0.16)), 0.001)
	var fk: float = clampf(_t / life, 0.0, 1.0)
	_flash.visible = fk < 1.0
	_flash.scale = Vector3.ONE * float(kind_config.get("flash_size_m", 0.8)) * lerpf(0.6, 1.2, fk)
	_flash_material.set_shader_parameter(&"fade", 1.0 - fk)
	var radius: float = ring_radius_at(_t, impact_in_s, float(settings.get("ring_from_m", 1.5)), float(settings.get("ring_to_m", 0.3)))
	_ring.scale = Vector3.ONE * radius * 2.0
	var k: float = clampf(_t / maxf(impact_in_s, 0.01), 0.0, 1.0)
	_ring_material.set_shader_parameter(&"fade", clampf(0.35 + 0.65 * k, 0.0, 1.0) * (1.0 if _t < impact_in_s else 0.0))
