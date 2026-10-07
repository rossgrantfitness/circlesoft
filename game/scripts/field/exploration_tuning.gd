class_name ExplorationTuning
extends RefCounted
## Typed view of data/world/exploration.json (doors, pickups, crates, climb and hop spots, the crew
## following Red). A missing key logs an error and reads as 0.

const TUNING_ID: String = "world/exploration"

var door_trigger_depth: float = 0.0
var door_trigger_half_width: float = 0.0
var door_min_push_speed: float = 0.0
var door_reach: float = 0.0
var door_panel: Vector3 = Vector3.ONE
var pickup_reach: float = 0.0
var pickup_size: float = 0.0
var pickup_lift: float = 0.0
var pickup_bob_height: float = 0.0
var pickup_bob_period_s: float = 0.0
var pickup_spin_deg_per_s: float = 0.0
var pickup_sparkle_period_s: float = 0.0
var crate_reach: float = 0.0
var crate_size: Vector3 = Vector3.ONE
var crate_lid_open_deg: float = 0.0
var traversal_reach: float = 0.0
var climb_s: float = 0.0
var hop_s: float = 0.0
var hop_height: float = 0.0
var climb_forward_hold: float = 0.0
var traversal_pad: Vector2 = Vector2.ONE
var follow_teleport_distance: float = 0.0
var follow_arrive_distance: float = 0.0
var follow_bob_height: float = 0.0
var follow_bob_hz: float = 0.0
var follow_turn_rate_deg_per_s: float = 0.0
var follow_moving_speed: float = 0.0


static func from_db(db: Node = null) -> ExplorationTuning:
	if db == null:
		var loop: SceneTree = Engine.get_main_loop() as SceneTree
		db = loop.root.get_node_or_null("DataDB") if loop != null else null
	if db == null:
		push_error("ExplorationTuning: no DataDB available")
		return ExplorationTuning.new()
	return from_dict(db.call("get_dict", TUNING_ID))


static func from_dict(data: Dictionary) -> ExplorationTuning:
	var t: ExplorationTuning = ExplorationTuning.new()
	t.door_trigger_depth = _n(data, "door.trigger_depth")
	t.door_trigger_half_width = _n(data, "door.trigger_half_width")
	t.door_min_push_speed = _n(data, "door.min_push_speed")
	t.door_reach = _n(data, "door.reach")
	t.door_panel = _v3(data, "door.panel")
	t.pickup_reach = _n(data, "pickup.reach")
	t.pickup_size = _n(data, "pickup.size")
	t.pickup_lift = _n(data, "pickup.lift")
	t.pickup_bob_height = _n(data, "pickup.bob_height")
	t.pickup_bob_period_s = _n(data, "pickup.bob_period_s")
	t.pickup_spin_deg_per_s = _n(data, "pickup.spin_deg_per_s")
	t.pickup_sparkle_period_s = _n(data, "pickup.sparkle_period_s")
	t.crate_reach = _n(data, "crate.reach")
	t.crate_size = _v3(data, "crate.size")
	t.crate_lid_open_deg = _n(data, "crate.lid_open_deg")
	t.traversal_reach = _n(data, "traversal.reach")
	t.climb_s = _n(data, "traversal.climb_s")
	t.hop_s = _n(data, "traversal.hop_s")
	t.hop_height = _n(data, "traversal.hop_height")
	t.climb_forward_hold = _n(data, "traversal.forward_hold")
	var pad: Vector3 = _v3(data, "traversal.pad", 2)
	t.traversal_pad = Vector2(pad.x, pad.y)
	t.follow_teleport_distance = _n(data, "follow.teleport_distance")
	t.follow_arrive_distance = _n(data, "follow.arrive_distance")
	t.follow_bob_height = _n(data, "follow.bob_height")
	t.follow_bob_hz = _n(data, "follow.bob_hz")
	t.follow_turn_rate_deg_per_s = _n(data, "follow.turn_rate_deg_per_s")
	t.follow_moving_speed = _n(data, "follow.moving_speed")
	return t


static func _n(data: Dictionary, path: String) -> float:
	var node: Variant = _dig(data, path)
	if node is float or node is int:
		return float(node)
	push_error("%s: '%s' is missing or not a number" % [TUNING_ID, path])
	return 0.0


static func _v3(data: Dictionary, path: String, count: int = 3) -> Vector3:
	var node: Variant = _dig(data, path)
	if node is Array and (node as Array).size() >= count:
		var list: Array = node
		return Vector3(float(list[0]), float(list[1]), float(list[2]) if count > 2 else 0.0)
	push_error("%s: '%s' is missing or not a list of %d numbers" % [TUNING_ID, path, count])
	return Vector3.ONE


static func _dig(data: Dictionary, path: String) -> Variant:
	var node: Variant = data
	for part: String in path.split("."):
		if node is Dictionary and (node as Dictionary).has(part):
			node = (node as Dictionary)[part]
		else:
			return null
	return node
