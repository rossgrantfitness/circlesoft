class_name SmashProp
extends CombatActor
## A crate, car, lamp post or building in the robot yard (task CS-21) that can be smashed. It is a CombatActor on its own team
## (&"prop") so Red's and the robots' swings hit it through the same Hitbox and HitResolver as any enemy, but it never counts as
## an enemy: nothing locks onto it, the wolves ignore it, and "enemies left" does not see it.
##
## It has a box to bump into (the enemy-body layer: Red and the loader are stopped by it, the colossus ignores that layer and
## stomps it instead, see ScaleController) and a hurtbox. At 0 health it collapses: it sinks into the floor in a cloud of dust and
## turns off. reset_prop() stands it up again (the pause menu's "Reset arena").

signal smashed(prop: SmashProp)

const TEAM: StringName = &"prop"
const COLLAPSE_S: float = 0.9
const WOBBLE_S: float = 0.22

var kind: StringName = &""
## The box it fills (x width, y height, z depth), metres, and where the middle of its footprint is from the model's origin.
var box_size: Vector3 = Vector3.ONE
var box_centre: Vector3 = Vector3.ZERO
var dust_id: StringName = &"step_small"
var model: Node3D = null
## How far from its middle a stomping robot has to be to flatten it (the half-width of its footprint).
var stomp_radius_m: float = 0.5
## A hit that does less than this only clinks off (VS-22: a loader-only scrap wall; 0 = anything breaks it). A stomp always breaks it.
var min_hit_damage: int = 0
## A GameState flag set when it is smashed (the Foreman's gate: j5_gate_smashed), from the kind's or the placement's `on_smash_flag`.
var on_smash_flag: String = ""

var _home_y: float = 0.0
var _home_basis: Basis = Basis.IDENTITY
var _collapse_t: float = -1.0
var _wobble_left: float = 0.0
var _shape_node: CollisionShape3D = null
var _tilt_axis: Vector3 = Vector3.RIGHT


func _init() -> void:
	team = TEAM
	launchable = false
	weight = 100.0


## Builds it from a yard "kinds" entry. Call before adding it to the tree.
func setup(prop_id: StringName, prop_kind: StringName, cfg: Dictionary, model_node: Node3D) -> void:
	actor_id = prop_id
	kind = prop_kind
	var size: Array = cfg.get("aabb_size", [1.0, 1.0, 1.0]) as Array
	var at: Array = cfg.get("aabb_pos", [-0.5, 0.0, -0.5]) as Array
	box_size = Vector3(float(size[0]), float(size[1]), float(size[2]))
	box_centre = Vector3(float(at[0]) + box_size.x * 0.5, box_size.y * 0.5, float(at[2]) + box_size.z * 0.5)
	hp_max = int(cfg.get("hp", 20))
	hp = hp_max
	dust_id = StringName(str(cfg.get("dust", "step_small")))
	min_hit_damage = int(cfg.get("min_hit_damage", 0))
	on_smash_flag = str(cfg.get("on_smash_flag", ""))
	radius_m = maxf(maxf(box_size.x, box_size.z) * 0.5, 0.3)
	height_m = maxf(box_size.y, radius_m * 2.0)
	stomp_radius_m = minf(box_size.x, box_size.z) * 0.5
	model = model_node


func _ready() -> void:
	super._ready()
	# a still, solid box for bodies to bump into (CombatActor made the layers; the shape is ours)
	_shape_node = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	_shape_node.shape = shape
	_shape_node.position = box_centre
	add_child(_shape_node)
	if model != null:
		add_child(model)
	_home_y = model.position.y if model != null else 0.0
	_home_basis = model.basis if model != null else Basis.IDENTITY
	# the hurtbox follows the footprint, not the capsule's middle
	if get_hurtbox() != null:
		get_hurtbox().position = Vector3(box_centre.x, 0.0, box_centre.z)
	set_process(false)


## World position of the middle of its footprint.
func centre_world() -> Vector3:
	return global_transform * Vector3(box_centre.x, 0.0, box_centre.z)


func is_collapsing() -> bool:
	return _collapse_t >= 0.0 and _collapse_t < 1.0


func is_gone() -> bool:
	return _collapse_t >= 1.0


## A robot walked into it: flatten it (no swing needed).
func stomp() -> void:
	if dead:
		return
	apply_hit({"damage": hp, "outcome": &"hit", "stomp": true})


## Too light a hit (Red on foot against a loader-only wall) does nothing but wobble it.
func apply_hit(result: Dictionary) -> void:
	if min_hit_damage > 0 and not dead and not bool(result.get("stomp", false)) and int(result.get("damage", 0)) < min_hit_damage:
		_wobble_left = WOBBLE_S * 0.5
		set_process(true)
		return
	super.apply_hit(result)


func _on_hit_reaction(result: Dictionary) -> void:
	if dead or int(result.get("damage", 0)) <= 0:
		return
	_wobble_left = WOBBLE_S
	set_process(true)


func _on_death(_result: Dictionary) -> void:
	_collapse_t = 0.0
	set_process(true)
	collision_layer = 0
	if get_hurtbox() != null:
		get_hurtbox().set_deferred("monitorable", false)
	if _shape_node != null:
		_shape_node.set_deferred("disabled", true)
	_spawn_dust()
	if not on_smash_flag.is_empty():
		WorldProgress.set_flag(on_smash_flag)
	smashed.emit(self)


func _spawn_dust() -> void:
	if not is_inside_tree():
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	ScaleDust.spawn(parent, centre_world(), dust_id)


func _process(delta: float) -> void:
	tick(delta)


## Advances the wobble and the collapse (real time).
func tick(delta: float) -> void:
	if model == null:
		set_process(false)
		return
	if _collapse_t >= 0.0:
		_collapse_t = minf(_collapse_t + delta / COLLAPSE_S, 1.0)
		var sink: float = _collapse_t * _collapse_t
		model.position.y = _home_y - (box_size.y + 0.3) * sink
		model.basis = _home_basis * Basis(_tilt_axis, deg_to_rad(9.0) * sink)
		if _collapse_t >= 1.0:
			model.visible = false
			set_process(false)
		return
	if _wobble_left > 0.0:
		_wobble_left = maxf(_wobble_left - delta, 0.0)
		var k: float = _wobble_left / WOBBLE_S
		var size: float = 0.025 if box_size.y > 4.0 else 0.07        # a building shudders, a crate rattles
		model.basis = _home_basis * Basis(Vector3.FORWARD, sin(k * 26.0) * size * k)
		if _wobble_left <= 0.0:
			model.basis = _home_basis
			set_process(false)


## Stands it back up whole.
func reset_prop() -> void:
	revive(true)
	_collapse_t = -1.0
	_wobble_left = 0.0
	collision_layer = CombatLayers.bit(CombatLayers.body_layer(team))
	if get_hurtbox() != null:
		get_hurtbox().monitorable = true
	if _shape_node != null:
		_shape_node.disabled = false
	if model != null:
		model.visible = true
		model.position.y = _home_y
		model.basis = _home_basis
	set_process(false)
