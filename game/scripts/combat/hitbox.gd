class_name Hitbox
extends Node3D
## The attacker's damage shapes (contract 4.2). The move runner turns slices on and off; each tick the
## active shapes are QUERIED against the other team's hurtboxes (PhysicsDirectSpaceState3D.intersect_shape,
## areas only), so contact is found in the same frame and tests repeat exactly. Each target is reported once
## per swing across all its slices (unless the move has rehit_ms), via director.report_contact().

const MAX_RESULTS: int = 16

var actor: CombatActor = null
var director: CombatDirector = null      ## set by the actor; tests may set it directly
var contact_point: Vector3 = Vector3.ZERO
var contact_box_index: int = -1

var _active: Dictionary = {}             # slice index -> {box, shape, params}
var _attack: Dictionary = {}
var _swing_id: int = -1
var _ledger: Dictionary = {}
var _clock_ms: float = 0.0
var _debug: Dictionary = {}              # slice index -> MeshInstance3D
var _debug_material: StandardMaterial3D = null


func owner_actor() -> CombatActor:
	return actor if actor != null else get_parent() as CombatActor


## Turn one slice on. `hit` is the attack data (MoveRunner.attack_data()); a new swing_id starts a fresh
## "who has been hit" list, the same swing_id keeps it (so overlapping slices never double-hit).
func activate(box: Dictionary, hit: Dictionary, swing_id: int) -> void:
	if swing_id != _swing_id:
		_ledger.clear()
		_swing_id = swing_id
	_attack = hit
	var index: int = int(box.get("index", _active.size()))
	_active[index] = {"box": box, "shape": _make_shape(box)}


func deactivate(index: int) -> void:
	_active.erase(index)
	_hide_debug(index)


## Everything off and forgotten.
func clear() -> void:
	_active.clear()
	_ledger.clear()
	_swing_id = -1
	_attack = {}
	for index: Variant in _debug.keys():
		_hide_debug(int(index))


func is_active() -> bool:
	return not _active.is_empty()


func active_count() -> int:
	return _active.size()


func attack_data() -> Dictionary:
	return _attack


func swing_id() -> int:
	return _swing_id


func world_transform_of(box: Dictionary) -> Transform3D:
	return PerfectDodge.box_transform(owner_actor().global_transform if owner_actor() != null else global_transform, box)


## Query the active shapes. `delta` is the owner's LOCAL time step (it only matters for rehit_ms).
func tick(delta: float) -> void:
	_clock_ms += delta * 1000.0
	_update_debug()
	if _active.is_empty() or not is_inside_tree():
		return
	var self_actor: CombatActor = owner_actor()
	if self_actor == null:
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var rehit_ms: float = float(_attack.get("rehit_ms", 0.0))
	var indices: Array = _active.keys()
	indices.sort()
	for index: Variant in indices:
		if not _active.has(index):
			continue
		var entry: Dictionary = _active[index]
		var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		params.shape = entry["shape"]
		params.transform = world_transform_of(entry["box"])
		params.collision_mask = CombatLayers.hitbox_mask(self_actor.team)
		params.collide_with_areas = true
		params.collide_with_bodies = false
		var found: Array[Dictionary] = space.intersect_shape(params, MAX_RESULTS)
		for hit: Dictionary in found:
			var hurtbox: Hurtbox = hit.get("collider") as Hurtbox
			if hurtbox == null:
				continue
			var victim: CombatActor = hurtbox.owner_actor()
			if victim == null or victim == self_actor or victim.team == self_actor.team:
				continue
			if not HitResolver.may_hit(_ledger, _swing_id, victim.actor_id, _clock_ms, rehit_ms):
				continue
			contact_point = (params.transform.origin + victim.anchor(&"center")) * 0.5
			contact_box_index = int(index)
			if director != null:
				director.report_contact(self, hurtbox)


func _make_shape(box: Dictionary) -> Shape3D:
	match str(box.get("shape", "sphere")):
		"box":
			var size: Array = box.get("size", [1.0, 1.0, 1.0])
			var shape: BoxShape3D = BoxShape3D.new()
			shape.size = Vector3(float(size[0]), float(size[1]), float(size[2]))
			return shape
		"capsule":
			var capsule: CapsuleShape3D = CapsuleShape3D.new()
			capsule.radius = float(box.get("radius", 0.5))
			capsule.height = maxf(float(box.get("height", 1.0)), capsule.radius * 2.0)
			return capsule
		_:
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = float(box.get("radius", 0.5))
			return sphere


# ---- debug drawing (feel knob show_hitboxes) ----

func _show_debug() -> bool:
	return director != null and director.feel != null and director.feel.get_b("show_hitboxes")


func _update_debug() -> void:
	if not _show_debug():
		for index: Variant in _debug.keys():
			_hide_debug(int(index))
		return
	for index: Variant in _active.keys():
		var entry: Dictionary = _active[index]
		var mesh_node: MeshInstance3D = _debug.get(index, null)
		if mesh_node == null:
			mesh_node = MeshInstance3D.new()
			mesh_node.mesh = _debug_mesh_for(entry["shape"])
			mesh_node.material_override = _material()
			mesh_node.top_level = true
			add_child(mesh_node)
			_debug[index] = mesh_node
		mesh_node.visible = true
		mesh_node.global_transform = world_transform_of(entry["box"])


func _hide_debug(index: int) -> void:
	var mesh_node: MeshInstance3D = _debug.get(index, null)
	if mesh_node != null:
		mesh_node.queue_free()
		_debug.erase(index)


func _material() -> StandardMaterial3D:
	if _debug_material == null:
		_debug_material = StandardMaterial3D.new()
		_debug_material.albedo_color = Color(1.0, 0.2, 0.15, 0.35)
		_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _debug_material


static func _debug_mesh_for(shape: Shape3D) -> Mesh:
	if shape is BoxShape3D:
		var box_mesh: BoxMesh = BoxMesh.new()
		box_mesh.size = (shape as BoxShape3D).size
		return box_mesh
	if shape is CapsuleShape3D:
		var capsule_mesh: CapsuleMesh = CapsuleMesh.new()
		capsule_mesh.radius = (shape as CapsuleShape3D).radius
		capsule_mesh.height = (shape as CapsuleShape3D).height
		return capsule_mesh
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = (shape as SphereShape3D).radius
	sphere_mesh.height = sphere_mesh.radius * 2.0
	return sphere_mesh
