class_name DroneLine
extends HackTarget
## A drone line (docs/slice/slice_tech_plan.md 5.2, docs/maps/junkyard.md J3): a dispenser that sends a Signals drone out every few
## seconds, never more than `max_alive` at once, until it is shut down.
##   * EMP on the dispenser stops it for `emp_stops_s` seconds (a breather; it starts again by itself).
##   * Zap on its power node (a separate lock-on target, up on the roof) stops it for good: `zaps_needed` zaps, then the line's
##     flag is set (sticky: a retry or a reload finds it dead).
## The drones come from the room: ActionRoom.spawn_enemy(kind, pos). A test sets `spawner` (Callable(kind, pos) -> Node3D).
##
## Data (hack_targets entry, kind "drone_line"): enemy (default "signals_drone"), interval_s (6), first_after_s (5), max_alive (2),
## total_max (0 = no limit), emp_stops_s (8), zaps_needed (2), node_pos [x, y, z] world (else 5 m above the dispenser),
## spawn_offset [x, y, z] from the dispenser, flag.

const DEFAULT_ENEMY: String = "signals_drone"
const GROUP_ROOM: StringName = &"action_room"

var enemy_kind: String = DEFAULT_ENEMY
var interval_s: float = 6.0
var first_after_s: float = 5.0
var max_alive: int = 2
var total_max: int = 0
var emp_stops_s: float = 8.0
var zaps_needed: int = 2
var spawn_offset: Vector3 = Vector3(0.0, 1.5, 1.5)
var node_pos: Vector3 = Vector3.INF
## Callable(kind: String, pos: Vector3) -> Node3D; empty means ask the ActionRoom.
var spawner: Callable = Callable()
var power_node: HackTarget = null
## Tests turn the clock off and call tick().
var run_on_physics: bool = true
var sent: int = 0

var _next_in_s: float = 0.0
var _paused_left_s: float = 0.0
var _alive: Array[Node3D] = []
var _warned: bool = false


func _init() -> void:
	accepts = PackedStringArray(["emp"])


func _configure(info: Dictionary) -> void:
	enemy_kind = str(info.get("enemy", DEFAULT_ENEMY))
	interval_s = float(info.get("interval_s", interval_s))
	first_after_s = float(info.get("first_after_s", first_after_s))
	max_alive = int(info.get("max_alive", max_alive))
	total_max = int(info.get("total_max", 0))
	emp_stops_s = float(info.get("emp_stops_s", emp_stops_s))
	zaps_needed = int(info.get("zaps_needed", zaps_needed))
	spawn_offset = vec3(info.get("spawn_offset", null), spawn_offset)
	node_pos = vec3(info.get("node_pos", null), Vector3.INF)
	_next_in_s = first_after_s


func _ready() -> void:
	super._ready()
	_build_power_node()
	set_physics_process(run_on_physics)


func _physics_process(delta: float) -> void:
	tick(delta)


## One step of the dispenser's clock.
func tick(delta: float) -> void:
	if is_done():
		return
	if _paused_left_s > 0.0:
		_paused_left_s = maxf(_paused_left_s - delta, 0.0)
		if _paused_left_s <= 0.0:
			set_lamp(TEAL)
		return
	_forget_dead()
	_next_in_s -= delta
	if _next_in_s > 0.0:
		return
	if _alive.size() >= max_alive or (total_max > 0 and sent >= total_max):
		_next_in_s = 0.25                 # full: look again soon, send the moment there is room
		return
	if _send():
		_next_in_s = interval_s
	else:
		_next_in_s = 1.0


func is_paused() -> bool:
	return _paused_left_s > 0.0


func paused_left_s() -> float:
	return _paused_left_s


func alive_count() -> int:
	_forget_dead()
	return _alive.size()


func _ready_for(_hack_id: StringName) -> bool:
	return true


## EMP: stop for a while.
func _apply(hack_id: StringName, _info: Dictionary) -> bool:
	if hack_id != ACCEPT_EMP:
		return false
	_paused_left_s = emp_stops_s
	set_lamp(Color(1.0, 0.6, 0.15))
	return true


func _finishes_on(_hack_id: StringName) -> bool:
	return false            # an EMP only pauses it; the power node ends it


func _apply_done(done: bool) -> void:
	super._apply_done(done)
	if done:
		_paused_left_s = 0.0


func _send() -> bool:
	var at: Vector3 = global_position + global_basis * spawn_offset
	var drone: Node3D = null
	if spawner.is_valid():
		drone = spawner.call(enemy_kind, at) as Node3D
	elif is_inside_tree():
		var room: Node = get_tree().get_first_node_in_group(GROUP_ROOM)
		if room != null and room.has_method(&"spawn_enemy"):
			drone = room.call(&"spawn_enemy", enemy_kind, at) as Node3D
	if drone == null:
		if not _warned:
			_warned = true
			push_warning("DroneLine %s: could not spawn '%s'" % [target_id, enemy_kind])
		return false
	_alive.append(drone)
	sent += 1
	return true


func _forget_dead() -> void:
	var keep: Array[Node3D] = []
	for drone: Node3D in _alive:
		if not is_instance_valid(drone):
			continue
		if "dead" in drone and bool(drone.get("dead")):
			continue
		keep.append(drone)
	_alive = keep


func _build_power_node() -> void:
	power_node = PowerNode.new()
	power_node.name = "PowerNode"
	power_node.target_id = StringName(String(target_id) + "_node")
	power_node.game_state = game_state
	(power_node as PowerNode).needed = zaps_needed
	power_node.data = {"accepts": ["zap"], "lockable": true, "sticky": true, "flag": flag_id(), "aim_height_m": 0.4}
	add_child(power_node)
	power_node.position = Vector3(0.0, 5.0, 0.0)
	if node_pos != Vector3.INF:
		power_node.global_position = node_pos
	power_node.completed.connect(func(_id: StringName) -> void: complete())


## The line's power node, up on the roof: it takes zaps, and the last one ends the line for good.
class PowerNode extends HackTarget:
	const REHIT_FRAMES: int = 20          # a Zap Drone flying through touches it on several frames: one pass is one zap
	var needed: int = 2
	var hits: int = 0
	var rehit_frames: int = REHIT_FRAMES
	var _last_frame: int = -1000

	func _apply(_hack_id: StringName, _info: Dictionary) -> bool:
		var frame: int = Engine.get_physics_frames()
		if rehit_frames > 0 and frame - _last_frame < rehit_frames:
			return false
		_last_frame = frame
		hits += 1
		return true

	func _finishes_on(_hack_id: StringName) -> bool:
		return hits >= needed

	func _build_look() -> void:
		add_child(HackTarget.panel_look(Color(0.3, 0.6, 1.0), Vector3(0.5, 0.6, 0.3)))
