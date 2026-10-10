class_name HackCrane
extends HackTarget
## The gantry crane's control cabinet (docs/slice/slice_tech_plan.md 5.2, docs/maps/junkyard.md J3). Overclock takes the crane for
## the hijack time (10 s); while it is held the crane's load travels along a path from data. Let go early and the load stops
## where it is; the next Overclock carries on from there. A job is done when its load reaches the end of its path.
##
## Data (placements.json "hack_targets", kind "crane"): `jobs` is a list done in order, each with
##   id            the job's name
##   flag          GameState flag set when the load arrives (sticky; ActionRoom.sticky_ids reads each job's flag)
##   path          world points [x, y, z] the load's origin travels through (the first is where it waits)
##   speed_mps     how fast it travels (default 4)
##   cargo_path    NodePath (relative to the crane) of an existing Node3D load in the level; or `cargo` {size: [w, h, d]} to
##                 build a solid placeholder box (a girder, a container) that waits at the first path point
##   smash         optional {radius_m, group}: when the load arrives, nodes of that group (default "crane_breakable") within
##                 the radius are smashed (a scrap wall: SmashProp.stomp / smash())
## Job A in J3 carries the bridge girder over the pit and lowers it onto both rims (the girder is solid, so the bridge is real);
## job B swings a container into the vault wall.

signal job_done(job_id: String, point: Vector3)

const DEFAULT_SPEED_MPS: float = 4.0
const DEFAULT_SMASH_GROUP: StringName = &"crane_breakable"
const CARGO_COLOR: Color = Color(0.8, 0.6, 0.15)

var hijackable: Hijackable = null
var jobs: Array[Dictionary] = []

var _cargo: Dictionary = {}                 # job id -> Node3D
var _travel: Dictionary = {}                # job id -> metres travelled along the path
var _done_jobs: Dictionary = {}             # job id -> true (this visit; sticky jobs are also in flags)
var _active: bool = false


func _init() -> void:
	accepts = PackedStringArray(["overclock"])


func _configure(info: Dictionary) -> void:
	jobs.clear()
	for raw: Variant in info.get("jobs", []) as Array:
		if raw is Dictionary:
			jobs.append(raw as Dictionary)


func _ready() -> void:
	super._ready()
	if accepts.has(String(ACCEPT_OVERCLOCK)) and hijackable == null:
		hijackable = Hijackable.new()
		hijackable.name = "Hijackable"
		hijackable.aim_height_m = aim_height_m
		add_child(hijackable)
	for job: Dictionary in jobs:
		_build_cargo(job)
		if _job_done(job):
			_travel[_id(job)] = _length(job)
			_put_cargo(job)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	var local: float = delta
	if hijackable != null and hijackable.hijacker() != null:
		local = hijackable.hijacker().local_delta(delta)
	tick(local)


# ---- the hijack interface (Hijackable calls these on its owner) ----

func hijack_allowed() -> bool:
	return _next_job() >= 0


func on_hijack_begin(_by: CombatActor, _duration_s: float) -> bool:
	if _next_job() < 0:
		return false
	_active = true
	return true


func on_hijack_end() -> void:
	_active = false


# ---- the jobs ----

## True while the crane is moving a load.
func is_moving() -> bool:
	return _active


## The id of the job the next Overclock will carry out ("" when all are done).
func current_job() -> String:
	var index: int = _next_job()
	return _id(jobs[index]) if index >= 0 else ""


## 0 to 1: how far the job's load has travelled.
func job_progress(job_id: String) -> float:
	for job: Dictionary in jobs:
		if _id(job) == job_id:
			var total: float = _length(job)
			return 1.0 if total <= 0.0 else clampf(float(_travel.get(job_id, 0.0)) / total, 0.0, 1.0)
	return 0.0


func job_is_done(job_id: String) -> bool:
	for job: Dictionary in jobs:
		if _id(job) == job_id:
			return _job_done(job)
	return false


func cargo_of(job_id: String) -> Node3D:
	return _cargo.get(job_id, null) as Node3D


func is_done() -> bool:
	if jobs.is_empty():
		return super.is_done()
	return _next_job() < 0


## Moves the current job's load `delta` seconds (the hijacker's own time).
func tick(delta: float) -> void:
	var index: int = _next_job()
	if index < 0 or delta <= 0.0:
		return
	var job: Dictionary = jobs[index]
	var id: String = _id(job)
	var speed: float = float(job.get("speed_mps", DEFAULT_SPEED_MPS))
	_travel[id] = minf(float(_travel.get(id, 0.0)) + speed * delta, _length(job))
	_put_cargo(job)
	if float(_travel[id]) >= _length(job) - 0.0001:
		_arrive(job)


func _arrive(job: Dictionary) -> void:
	var id: String = _id(job)
	_done_jobs[id] = true
	var flag: String = str(job.get("flag", ""))
	if not flag.is_empty() and bool(job.get("sticky", sticky)):
		WorldProgress.set_flag(flag, game_state)
	var end: Vector3 = _point_at(job, _length(job))
	_smash_near(job, end)
	hacked.emit(target_id, ACCEPT_OVERCLOCK)
	job_done.emit(id, end)
	if _next_job() < 0:
		_active = false
		if hijackable != null and hijackable.is_hijacked():
			hijackable.end_hijack()
		complete()
	elif hijackable != null and hijackable.is_hijacked():
		pass            # the same Overclock carries on with the next job


func _smash_near(job: Dictionary, at: Vector3) -> void:
	var cfg: Dictionary = job.get("smash", {}) as Dictionary
	if cfg.is_empty() or not is_inside_tree():
		return
	var radius: float = float(cfg.get("radius_m", 3.0))
	var group: StringName = StringName(str(cfg.get("group", DEFAULT_SMASH_GROUP)))
	for node: Node in get_tree().get_nodes_in_group(group):
		var spot: Node3D = node as Node3D
		if spot == null or spot.global_position.distance_to(at) > radius:
			continue
		if node.has_method(&"smash"):
			node.call(&"smash")
		elif node.has_method(&"stomp"):
			node.call(&"stomp")


func _next_job() -> int:
	for i: int in jobs.size():
		if not _job_done(jobs[i]):
			return i
	return -1


func _job_done(job: Dictionary) -> bool:
	if _done_jobs.has(_id(job)):
		return true
	var flag: String = str(job.get("flag", ""))
	return not flag.is_empty() and bool(job.get("sticky", sticky)) and WorldProgress.has_flag(flag, game_state)


static func _id(job: Dictionary) -> String:
	return str(job.get("id", "job"))


func _points(job: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for raw: Variant in job.get("path", []) as Array:
		out.append(vec3(raw))
	return out


func _length(job: Dictionary) -> float:
	var points: Array[Vector3] = _points(job)
	var total: float = 0.0
	for i: int in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


func _point_at(job: Dictionary, distance: float) -> Vector3:
	var points: Array[Vector3] = _points(job)
	if points.is_empty():
		return global_position
	var left: float = distance
	for i: int in range(1, points.size()):
		var leg: float = points[i - 1].distance_to(points[i])
		if left <= leg and leg > 0.0:
			return points[i - 1].lerp(points[i], left / leg)
		left -= leg
	return points[points.size() - 1]


func _put_cargo(job: Dictionary) -> void:
	var load_node: Node3D = _cargo.get(_id(job), null) as Node3D
	if load_node == null or not is_instance_valid(load_node):
		return
	var at: Vector3 = _point_at(job, float(_travel.get(_id(job), 0.0)))
	if load_node.is_inside_tree():
		load_node.global_position = at
	else:
		load_node.position = at


func _build_cargo(job: Dictionary) -> void:
	var id: String = _id(job)
	var existing: String = str(job.get("cargo_path", ""))
	var load_node: Node3D = null
	if not existing.is_empty():
		load_node = get_node_or_null(NodePath(existing)) as Node3D
	elif job.has("cargo"):
		var size: Vector3 = vec3((job["cargo"] as Dictionary).get("size", [2.0, 2.0, 2.0]), Vector3(2.0, 2.0, 2.0))
		var body: AnimatableBody3D = AnimatableBody3D.new()
		body.name = "Cargo_" + id
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = false
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		body.add_child(PropLook.box(size, PropLook.lit(CARGO_COLOR), "Mesh"))
		var hook: MeshInstance3D = PropLook.box(Vector3(0.3, 1.2, 0.3), PropLook.lit(Color(0.2, 0.2, 0.22)), "Hook")
		hook.position.y = size.y * 0.5 + 0.6
		body.add_child(hook)
		load_node = body
		add_child(body)
		body.top_level = true
	if load_node == null:
		return
	_cargo[id] = load_node
	var points: Array[Vector3] = _points(job)
	if not points.is_empty():
		load_node.global_position = points[0]
