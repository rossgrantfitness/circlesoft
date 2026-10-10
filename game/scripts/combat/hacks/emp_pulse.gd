class_name EmpPulse
extends Node3D
## The EMP's look: a ring of static that spreads out from Red and fades (hacks.json `emp`). The effect itself
## (the push, the guard break, the stun) is done by HackCaster the moment the pulse is born; this node is only the picture,
## a plain glowing ring until the Technical Artist's hack FX (VS-41) replaces `_build_visual`.

signal finished

var radius_m: float = 4.5
var duration_s: float = 0.35

var _age_s: float = 0.0
var _ring: MeshInstance3D = null
var _material: StandardMaterial3D = null


func _ready() -> void:
	_build_visual()
	_apply(0.0)


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	_age_s += delta
	_apply(clampf(_age_s / maxf(duration_s, 0.01), 0.0, 1.0))
	if _age_s >= duration_s:
		finished.emit()
		queue_free()


func _apply(progress: float) -> void:
	if _ring == null:
		return
	var size: float = lerpf(0.2, 1.0, 1.0 - pow(1.0 - progress, 3.0)) * radius_m
	_ring.scale = Vector3(size, 1.0, size)
	_material.albedo_color.a = 1.0 - progress
	_material.emission_energy_multiplier = lerpf(4.0, 0.5, progress)


func _build_visual() -> void:
	_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	_ring.mesh = torus
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.3, 0.95, 1.0, 1.0)
	_material.emission_enabled = true
	_material.emission = Color(0.3, 0.95, 1.0)
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = _material
	_ring.position = Vector3(0.0, 0.08, 0.0)
	add_child(_ring)
