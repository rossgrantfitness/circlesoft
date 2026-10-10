class_name Hurtbox
extends Area3D
## Where a fighter can be hit (contract 4.2). It stays on during i-frames so a dodge can be detected;
## the resolver ignores the hit instead. It scans nothing: hitboxes query it.

const DEBUG_COLOR: Color = Color(0.2, 1.0, 0.35, 0.28)

var actor: CombatActor = null
var _shape_node: CollisionShape3D = null
var _debug_mesh: MeshInstance3D = null


func owner_actor() -> CombatActor:
	return actor if actor != null else get_parent() as CombatActor


## A capsule around the fighter: `radius` and `height` in metres, feet at the actor's origin.
func setup(for_actor: CombatActor, radius: float, height: float) -> void:
	actor = for_actor
	collision_layer = CombatLayers.bit(CombatLayers.hurtbox_layer(for_actor.team))
	collision_mask = CombatLayers.hurtbox_mask()
	monitoring = false
	monitorable = true
	if _shape_node == null:
		_shape_node = CollisionShape3D.new()
		add_child(_shape_node)
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	_shape_node.shape = capsule
	_shape_node.position = Vector3(0.0, capsule.height * 0.5, 0.0)


## Show or hide the outline (feel knob show_hitboxes).
func set_debug_visible(visible_now: bool) -> void:
	if not visible_now:
		if _debug_mesh != null:
			_debug_mesh.visible = false
		return
	if _debug_mesh == null and _shape_node != null and _shape_node.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = _shape_node.shape
		var mesh: CapsuleMesh = CapsuleMesh.new()
		mesh.radius = capsule.radius
		mesh.height = capsule.height
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = DEBUG_COLOR
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.mesh = mesh
		_debug_mesh.material_override = material
		_debug_mesh.position = _shape_node.position
		add_child(_debug_mesh)
	if _debug_mesh != null:
		_debug_mesh.visible = true
