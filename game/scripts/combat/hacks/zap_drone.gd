class_name ZapDrone
extends Node3D
## The Zap Drone (hacks.json `zap_drone`): a small drone Red throws that flies in a straight line, zips through up to
## `hits` enemies and then burns out. Each enemy it touches takes the hack's hit through `CombatDirector.report_hack_hit`
## (so hit-stop, sparks, numbers and reactions are the sword's); a `drone` takes double, a boss relay triple (tag_mult).
## Anything in group `hack_targets` that accepts `zap` (a fuse box, a relay) in its path is zapped too.
## The look is a glowing bead until the Technical Artist's hack FX (VS-41) replaces `_build_visual`.
##
## Time runs on Red's combat clock (hit-stop freezes the drone, as it freezes everything of hers).

signal finished

const RADIUS_M: float = 0.3
const HACK_TARGET_RADIUS_M: float = 0.7
const GROUP_HACK_TARGETS: StringName = &"hack_targets"

var source: CombatActor = null
var director: CombatDirector = null
var rules: HackRules = null
var hack_id: StringName = &"zap_drone"
var direction: Vector3 = Vector3.FORWARD
var speed_mps: float = 20.0
var max_m: float = 18.0
var pierce: int = 3
var rehit_ms: float = 250.0
var hit: Dictionary = {}
var damage_scale: float = 1.0

var _travelled: float = 0.0
var _clock_ms: float = 0.0
var _last_hit: Dictionary = {}              # target instance id -> ms of the last hit
var _hits_done: int = 0
var _done: bool = false
var _mesh: MeshInstance3D = null


func _ready() -> void:
	_build_visual()


func _physics_process(delta: float) -> void:
	tick(delta)


## How many things it has hit so far.
func hits_done() -> int:
	return _hits_done


func is_done() -> bool:
	return _done


func distance_flown() -> float:
	return _travelled


## One step. `delta` is real time; Red's own time scale is applied here.
func tick(delta: float) -> void:
	if _done:
		return
	var local: float = source.local_delta(delta) if source != null and is_instance_valid(source) else delta
	if local <= 0.0:
		return
	_clock_ms += local * 1000.0
	var step_m: float = minf(speed_mps * local, maxf(max_m - _travelled, 0.0))
	var from: Vector3 = global_position
	var to: Vector3 = from + direction.normalized() * step_m
	var wall: Vector3 = _wall_between(from, to)
	if wall != Vector3.INF:
		to = wall
	_touch(from, to)
	global_position = to
	_travelled += from.distance_to(to)
	if wall != Vector3.INF or _travelled >= max_m - 0.001 or _hits_done >= pierce:
		_finish()


func _touch(from: Vector3, to: Vector3) -> void:
	if director == null:
		return
	for enemy: CombatActor in director.living_enemies():
		if _hits_done >= pierce:
			return
		if not _may_hit(enemy):
			continue
		if not HackGeometry.segment_hits_upright(from, to, enemy.global_position, enemy.height_m, enemy.radius_m + RADIUS_M):
			continue
		_hit_enemy(enemy, to)
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(GROUP_HACK_TARGETS):
			var spot: Node3D = node as Node3D
			if spot == null or not node.has_method(&"can_take") or not bool(node.call(&"can_take", &"zap")):
				continue
			var aim: Vector3 = node.call(&"aim_point") if node.has_method(&"aim_point") else spot.global_position
			if HackGeometry.segment_hits_upright(from, to, aim - Vector3.UP * 0.5, 1.0, HACK_TARGET_RADIUS_M):
				node.call(&"take_hack", &"zap", {"source": source, "position": to})


func _may_hit(target: Node) -> bool:
	var key: int = target.get_instance_id()
	if _last_hit.has(key):
		if rehit_ms <= 0.0 or _clock_ms - float(_last_hit[key]) < rehit_ms:
			return false
	return true


func _hit_enemy(enemy: CombatActor, at: Vector3) -> void:
	var attack: Dictionary = hit.duplicate(true)
	var mult: float = rules.tag_mult(hack_id, HackCaster.tags_of(enemy)) if rules != null else 1.0
	attack["damage"] = int(roundf(float(attack.get("damage", 0)) * mult * damage_scale))
	var result: Dictionary = director.report_hack_hit(source, enemy, attack, {"move_id": &"hack_zap", "origin": global_position,
			"direction": direction.normalized(), "position": enemy.anchor(&"center")})
	if result.get("outcome", HitResolver.OUTCOME_IGNORED) == HitResolver.OUTCOME_IGNORED:
		return
	_last_hit[enemy.get_instance_id()] = _clock_ms
	_hits_done += 1


func _wall_between(from: Vector3, to: Vector3) -> Vector3:
	if not is_inside_tree() or from.is_equal_approx(to):
		return Vector3.INF
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return Vector3.INF
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, CombatLayers.bit(CombatLayers.WORLD))
	query.collide_with_areas = false
	var found: Dictionary = space.intersect_ray(query)
	return found["position"] if not found.is_empty() else Vector3.INF


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	var bead: SphereMesh = SphereMesh.new()
	bead.radius = 0.12
	bead.height = 0.24
	_mesh.mesh = bead
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color(0.3, 0.95, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.95, 1.0)
	glow.emission_energy_multiplier = 3.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = glow
	add_child(_mesh)
