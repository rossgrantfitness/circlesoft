class_name PartyFollow
extends Node
## The crew follows Red in a line (Otis, then Mox), always on screen, never blocking her.
##
## Red drops breadcrumbs as she moves (every breadcrumb_step units). Follower number n stands on
## the trail n * spacing behind her (measured along the path she walked, so they take the same turns
## and hop the same hops). A follower that is far from its spot (after a teleport) runs to it at
## catch_up_speed_mult times her running speed. At room load the trail is seeded straight behind
## her spawn (shortened if a wall is there), so the line starts in order and walks out behind her.
## Numbers: data/world/field_tuning.json "follow", and data/world/exploration.json "follow".
##
## Followers are PartyFollower nodes (collision layer 4, mask none) added to the room.

signal teleport_detected

const HERO_ID: String = "red"
const CHARACTERS_ID: String = "party/characters"
const WALL_MASK: int = 1
const WALL_MARGIN: float = 0.25
const RAY_HEIGHT: float = 0.5
const TRAIL_MARGIN: float = 1.0

var leader: Node3D = null
var followers: Array[PartyFollower] = []
## Off: the line stands still (a room waiting while something else has the screen).
var active: bool = true
## The trail, oldest crumb first; the leader's own position is the newest end and is not stored.
var trail: Array[Vector3] = []
var spacing: float = 0.0
var breadcrumb_step: float = 0.0
var catch_up_speed: float = 0.0

var _tuning: ExplorationTuning = null
var _last_leader: Vector3 = Vector3.ZERO


## Builds the line for `member_ids` (not Red) behind `p_leader`. `parent` gets the follower nodes.
func setup(p_leader: Node3D, member_ids: Array[String], parent: Node3D, field_tuning: FieldTuning = null) -> void:
	leader = p_leader
	_tuning = ExplorationTuning.from_db()
	var field: FieldTuning = field_tuning if field_tuning != null else FieldTuning.from_db(get_node_or_null("/root/DataDB"))
	spacing = field.follow_spacing
	breadcrumb_step = maxf(field.follow_breadcrumb_step, 0.01)
	catch_up_speed = field.run_speed * field.follow_catch_up_speed_mult
	for id: String in member_ids:
		if id == HERO_ID:
			continue
		var follower: PartyFollower = PartyFollower.new()
		parent.add_child(follower)
		follower.setup(id, model_path_for(id), _tuning)
		followers.append(follower)
	seed_trail()
	for i: int in followers.size():
		followers[i].global_position = point_behind(leader.global_position, spacing * float(i + 1))
		followers[i].face_direction(leader_facing())


static func model_path_for(member_id: String) -> String:
	for entry: Variant in DataDB.get_dict(CHARACTERS_ID).get("characters", []):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == member_id:
			return str((entry as Dictionary).get("model", ""))
	return ""


func _physics_process(delta: float) -> void:
	if active:
		step(delta)


func leader_facing() -> Vector3:
	var facing: Vector3 = leader.global_basis.z if leader != null else Vector3.BACK
	facing.y = 0.0
	return facing.normalized() if facing.length() > PlayerMotion.MIN_FLAT_LENGTH else Vector3.BACK


## One step: drop a breadcrumb if Red has moved enough, then bring each follower toward its place.
func step(delta: float) -> void:
	if leader == null or not is_instance_valid(leader):
		return
	var here: Vector3 = leader.global_position
	if here.distance_to(_last_leader) > _tuning.follow_teleport_distance:
		teleport_detected.emit()
		seed_trail()
	_last_leader = here
	if trail.is_empty() or here.distance_to(trail.back()) >= breadcrumb_step:
		trail.append(here)
		_trim_trail()
	for i: int in followers.size():
		followers[i].move_to(point_behind(here, spacing * float(i + 1)), delta, catch_up_speed)


## Starts the trail fresh straight behind the leader. Followers keep where they stand and run up to it.
func seed_trail() -> void:
	trail.clear()
	if leader == null:
		return
	var here: Vector3 = leader.global_position
	_last_leader = here
	var back: Vector3 = -leader_facing()
	var length: float = _clear_distance(here, back, spacing * float(maxi(followers.size(), 1)))
	var distance: float = length
	while distance > 0.0:
		trail.append(here + back * distance)
		distance -= breadcrumb_step
	trail.append(here)


## The spot `distance` back along the path from `from_point`, following the breadcrumbs. If the trail
## is shorter than that, the oldest crumb (where the line started).
func point_behind(from_point: Vector3, distance: float) -> Vector3:
	var current: Vector3 = from_point
	var left: float = distance
	for i: int in range(trail.size() - 1, -1, -1):
		var segment: float = current.distance_to(trail[i])
		if segment >= left:
			return current.move_toward(trail[i], left)
		left -= segment
		current = trail[i]
	return current


## Teleports the leader to `point` (a cutscene, a warp): the trail restarts there and the crew runs after her.
func note_teleport() -> void:
	seed_trail()


## How far along `direction` from `origin` is free of walls, up to `wanted`.
func _clear_distance(origin: Vector3, direction: Vector3, wanted: float) -> float:
	if wanted <= 0.0 or leader == null or not leader.is_inside_tree():
		return maxf(wanted, 0.0)
	var lift: Vector3 = Vector3.UP * RAY_HEIGHT
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin + lift, origin + direction * wanted + lift, WALL_MASK)
	var hit: Dictionary = leader.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return wanted
	return maxf(origin.distance_to(hit["position"] as Vector3) - WALL_MARGIN, 0.0)


func _trim_trail() -> void:
	var needed: float = spacing * float(followers.size()) + TRAIL_MARGIN
	var length: float = 0.0
	var current: Vector3 = leader.global_position
	for i: int in range(trail.size() - 1, -1, -1):
		length += current.distance_to(trail[i])
		current = trail[i]
		if length > needed:
			var kept: Array[Vector3] = []
			kept.assign(trail.slice(i))
			trail = kept
			return
