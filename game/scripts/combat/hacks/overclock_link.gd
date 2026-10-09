class_name OverclockLink
extends Node3D
## The line from Red to a hijacked enemy for as long as Overclock holds it (hacks.json `overclock`): a thin glowing
## beam that follows both ends and thins out toward the end of the hijack. It frees itself when the hijack ends.
## A plain beam until the Technical Artist's hack FX (VS-41) replaces `_build_visual`.

var from_node: Node3D = null
var hijackable: Hijackable = null
var from_height_m: float = 0.7

var _beam: MeshInstance3D = null
var _material: StandardMaterial3D = null


func _ready() -> void:
	_build_visual()
	tick(0.0)


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(_delta: float) -> void:
	if hijackable == null or not is_instance_valid(hijackable) or not hijackable.is_hijacked():
		queue_free()
		return
	if from_node == null or not is_instance_valid(from_node):
		queue_free()
		return
	var a: Vector3 = from_node.global_position + Vector3.UP * from_height_m
	var b: Vector3 = hijackable.hijack_point()
	var length: float = a.distance_to(b)
	if length < 0.05:
		_beam.visible = false
		return
	_beam.visible = true
	_beam.global_position = (a + b) * 0.5
	var up: Vector3 = (b - a).normalized()
	var side: Vector3 = up.cross(Vector3.UP if absf(up.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT).normalized()
	var forward: Vector3 = side.cross(up).normalized()
	_beam.global_basis = Basis(side, up, forward)
	_beam.scale = Vector3(1.0, length, 1.0)
	var left: float = hijackable.time_left_s() / maxf(hijackable.duration_s(), 0.01)
	_material.albedo_color.a = lerpf(0.25, 0.9, clampf(left * 3.0, 0.0, 1.0))


func _build_visual() -> void:
	_beam = MeshInstance3D.new()
	var tube: CylinderMesh = CylinderMesh.new()
	tube.top_radius = 0.02
	tube.bottom_radius = 0.02
	tube.height = 1.0
	tube.radial_segments = 6
	_beam.mesh = tube
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.3, 0.95, 1.0, 0.9)
	_material.emission_enabled = true
	_material.emission = Color(0.3, 0.95, 1.0)
	_material.emission_energy_multiplier = 3.0
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam.material_override = _material
	_beam.top_level = true
	add_child(_beam)
