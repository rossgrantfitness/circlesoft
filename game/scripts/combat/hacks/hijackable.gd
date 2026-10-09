class_name Hijackable
extends Node
## A component that says "Overclock can take this over" (docs/slice/slice_tech_plan.md 4.4). Put it as a child of a
## turret, drone, cop, crane or dispenser; it joins group `hijackable` and the owner (the parent) does the rest:
##   owner.on_hijack_begin(by: CombatActor, duration_s: float) -> bool   (false = it refuses)
##   owner.on_hijack_end() -> void
## The owner may also say `hijack_allowed()` -> false, and offer `tags` (drone, turret, robot) for the rules.
## The countdown runs on the hijacker's combat clock (hit-stop pauses it); taking damage does not end it, the owner
## dying or running out of time does. Bosses are not taken: `allowed = false` on their body.

signal hijack_started(owner: Node, duration_s: float)
signal hijack_ended(owner: Node)

const GROUP: StringName = &"hijackable"

@export var aim_bone: StringName = &"head"         ## where the link line and the marker go
@export var allowed: bool = true                    ## bosses and some enemies say no
@export var aim_height_m: float = 1.0               ## the link point when the owner has no bone to ask

var _by: CombatActor = null
var _left_s: float = 0.0
var _total_s: float = 0.0
var _hijacked: bool = false


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	tick(delta)


## The node this component belongs to.
func owner_node() -> Node:
	return get_parent()


## Where the link line ends and the HUD marker sits, in world space.
func hijack_point() -> Vector3:
	var host: Node3D = get_parent() as Node3D
	if host == null:
		return Vector3.ZERO
	if host is CombatActor:
		var head: Vector3 = (host as CombatActor).anchor(aim_bone)
		if head != host.global_position:
			return head
	return host.global_position + Vector3.UP * aim_height_m


func can_hijack(by_team: StringName) -> bool:
	if not allowed or _hijacked or get_parent() == null:
		return false
	var host: Node = get_parent()
	if "dead" in host and bool(host.get("dead")):
		return false
	if host.has_method(&"hijack_allowed") and not bool(host.call(&"hijack_allowed")):
		return false
	if "team" in host and StringName(str(host.get("team"))) == by_team:
		return false
	return true


func begin_hijack(by: CombatActor, duration_s: float) -> bool:
	var team: StringName = by.team if by != null else CombatDirector.PLAYER_TEAM
	if not can_hijack(team):
		return false
	var host: Node = get_parent()
	if host.has_method(&"on_hijack_begin"):
		var ok: Variant = host.call(&"on_hijack_begin", by, duration_s)
		if ok is bool and not bool(ok):
			return false
	_by = by
	_total_s = maxf(duration_s, 0.0)
	_left_s = _total_s
	_hijacked = true
	hijack_started.emit(host, duration_s)
	_announce(true)
	return true


## Ends the hijack now (time up, the owner died, or Overclock was cut). Safe to call when nothing is running.
func end_hijack() -> void:
	if not _hijacked:
		return
	_hijacked = false
	_left_s = 0.0
	var host: Node = get_parent()
	if host != null and host.has_method(&"on_hijack_end"):
		host.call(&"on_hijack_end")
	_by = null
	hijack_ended.emit(host)
	_announce(false)


func is_hijacked() -> bool:
	return _hijacked


func time_left_s() -> float:
	return _left_s if _hijacked else 0.0


func duration_s() -> float:
	return _total_s


## The one who took it over (null when nobody has).
func hijacker() -> CombatActor:
	return _by if is_instance_valid(_by) else null


## One step on the hijacker's combat clock. Ends the hijack when the time is up or the owner is dead.
func tick(delta: float) -> void:
	if not _hijacked:
		return
	var host: Node = get_parent()
	if host == null or ("dead" in host and bool(host.get("dead"))):
		end_hijack()
		return
	var local: float = delta
	if is_instance_valid(_by):
		local = _by.local_delta(delta)
	_left_s = maxf(_left_s - local, 0.0)
	if _left_s <= 0.0:
		end_hijack()


func _exit_tree() -> void:
	if _hijacked:
		_hijacked = false           # the owner is leaving the tree with us: nothing to hand back
		_announce(false)


func _announce(active: bool) -> void:
	var director: CombatDirector = null
	if is_inside_tree():
		director = get_tree().get_first_node_in_group(CombatDirector.GROUP) as CombatDirector
	if director != null:
		var host: Node = get_parent()
		var id: StringName = host.get("actor_id") if host != null and "actor_id" in host else StringName(host.name if host != null else "")
		director.hijack_changed.emit({"target": id, "active": active, "duration_s": _total_s})
