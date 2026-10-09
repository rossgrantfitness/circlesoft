class_name BossPart
extends CombatActor
## A separately hittable, lockable piece of a boss (slice tech plan 6.3): a relay box on a leg pair, the jammer dish, later the
## junk mech's armour plates. A CombatActor on the enemy team that the director knows, so lock-on, Zap Drone, a hijacked
## turret's bolts, damage numbers and the FX all work on it with no special cases.
##
## `damaged_by` says which hits hurt it: "sword", "hack" (a Zap Drone, an EMP) and "hijacked" (an Overclocked turret's fire).
## A hit from any other source still lands (spark, number, sound) but takes nothing off: the sword "clinks" off a relay.
## `hijacked_mult` scales what a hijacked turret does to it. At 0 health it breaks: `broken(part_id)`, hidden, no longer a target.
## It never reacts to a hit with a flinch or a launch: it is bolted on.
## The boss reads `hit_taken` for the dish's "hit it three times" rule (a Zap counts as three: `move_id` says which).

signal broken(part_id: StringName)
signal hit_taken(part_id: StringName, source: String, move_id: StringName, damage: int)
signal clinked(part_id: StringName, source: String)

var part_id: StringName = &""
var kind: StringName = &""
var tags: PackedStringArray = PackedStringArray()
var damaged_by: Array[String] = ["sword", "hack", "hijacked"]
var hijacked_mult: float = 1.0
var lock_target: bool = true
var on_break: Dictionary = {}
var owner_boss: Node = null
## The boss turns damage off for a while (for example while the rig is still standing, a sword does 30 percent: that is
## the boss's own rule on its body; a part has no such thing).
var invulnerable_now: bool = false

var _visual: Node3D = null


## `spec` is one entry of `parts` in the boss file. `boss` is the body the part belongs to.
func setup(id: StringName, spec: Dictionary, boss: Node) -> void:
	part_id = id
	actor_id = id
	kind = StringName(str(spec.get("kind", "")))
	owner_boss = boss
	hp_max = int(spec.get("hp", 50))
	hp = hp_max
	height_m = float(spec.get("height_m", 1.0))
	radius_m = float(spec.get("radius_m", 0.5))
	for tag: Variant in spec.get("tags", []) as Array:
		tags.append(str(tag))
	damaged_by.clear()
	for source: Variant in spec.get("damaged_by", ["sword", "hack", "hijacked"]) as Array:
		damaged_by.append(str(source))
	hijacked_mult = float(spec.get("hijacked_mult", 1.0))
	lock_target = bool(spec.get("lock_target", true))
	on_break = (spec.get("on_break", {}) as Dictionary).duplicate(true)
	team = &"enemy"
	move_set_id = &"hushmaster"
	launchable = false
	poise_max = 0.0
	weight = 50.0


func _ready() -> void:
	super._ready()
	# A bolted-on box: not a body anyone bumps into or pushes, only a target.
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	_make_visual()


## A box to show where the part is (the blockout's own relay mesh is hidden by the boss when it breaks).
func _make_visual() -> void:
	if get_node_or_null("Marker") != null:
		return
	_visual = MeshInstance3D.new()
	_visual.name = "Marker"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(radius_m * 1.4, height_m * 0.5, radius_m * 1.4)
	(_visual as MeshInstance3D).mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.25, 0.3, 0.0)           # invisible until a hit flashes it
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	(_visual as MeshInstance3D).material_override = material
	_visual.position = Vector3(0.0, height_m * 0.5, 0.0)
	add_child(_visual)


func is_invulnerable() -> bool:
	return invulnerable_now or dead


func tick(delta: float) -> void:
	if _visual != null:
		var material: StandardMaterial3D = (_visual as MeshInstance3D).material_override as StandardMaterial3D
		material.albedo_color.a = maxf(material.albedo_color.a - delta * 4.0, 0.0)


func apply_hit(result: Dictionary) -> void:
	var source: String = str(result.get("source", "sword"))
	var move_id: StringName = StringName(str(result.get("move_id", "")))
	# bolted on: no shove, no launch, no flinch
	result["knockback"] = Vector3.ZERO
	result["launch_mps"] = 0.0
	result["launched"] = false
	result["knockdown"] = false
	result["hitstun_ms"] = 0.0
	if not damaged_by.has(source):
		result["damage"] = 0
		clinked.emit(part_id, source)
	elif source == "hijacked":
		result["damage"] = int(roundf(float(result.get("damage", 0)) * hijacked_mult))
	super.apply_hit(result)
	if _visual != null:
		((_visual as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 0.55
	hit_taken.emit(part_id, source, move_id, int(result.get("damage", 0)))


func _on_death(_result: Dictionary) -> void:
	get_hurtbox().collision_layer = 0
	if _visual != null:
		_visual.visible = false
	broken.emit(part_id)


func has_tag(tag: String) -> bool:
	return tags.has(tag)


## Back to whole (a retry rebuilds the fight; a test may reuse a part).
func mend() -> void:
	revive(true)
	get_hurtbox().collision_layer = CombatLayers.bit(CombatLayers.hurtbox_layer(team))
	if _visual != null:
		_visual.visible = true
