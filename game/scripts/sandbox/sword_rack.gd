class_name SwordRack
extends Area3D
## One sword stand in the arena (docs/pivot/combat_api.md 4.7). Walking onto it equips its sword on
## Red, through the player's equip_sword() (which uses the Technical Artist's GearVisuals). Swords
## change the look only; the moves are the same for all of them.
##
## The stand shows the sword floating over a pedestal with its name. The model path and name come
## from data/combat/swords.json; if that file or the model is missing the stand shows a plain bar
## and the id, so the arena works before the art is in. Layer 16 (interact), mask 10 (player_body).

signal sword_picked(sword_id: StringName)

const LAYER_INTERACT: int = 16
const LAYER_PLAYER_BODY: int = 10
const SWORDS_DATA_ID: String = "combat/swords"
const SPIN_DEG_PER_S: float = 40.0
const BOB_M: float = 0.06
const FLOAT_HEIGHT_M: float = 1.15

@export var sword_id: StringName = &""
@export var radius_m: float = 0.9

var _display: Node3D = null
var _time: float = 0.0
var _label: Label3D = null
var _ring: MeshInstance3D = null
var _flash_left: float = 0.0


func _ready() -> void:
	collision_layer = 1 << (LAYER_INTERACT - 1)
	collision_mask = 1 << (LAYER_PLAYER_BODY - 1)
	monitoring = true
	monitorable = false
	_build()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	_time += delta
	if _display != null:
		_display.rotation.y += deg_to_rad(SPIN_DEG_PER_S) * delta
		_display.position.y = FLOAT_HEIGHT_M + sin(_time * 2.0) * BOB_M
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		if _ring != null:
			(_ring.material_override as StandardMaterial3D).emission_energy_multiplier = 1.0 + _flash_left * 6.0


## The data entry for this stand's sword (empty when there is no swords.json yet).
func sword_entry() -> Dictionary:
	var db: Node = get_node_or_null("/root/DataDB")
	if db == null:
		return {}
	return db.call("get_value", SWORDS_DATA_ID, "swords.%s" % sword_id, {}) as Dictionary


func display_name() -> String:
	return str(sword_entry().get("name", String(sword_id).capitalize().replace("_", " ")))


## Equip this stand's sword on `player` (anything with equip_sword(id) -> bool). Returns whether it took.
func give_to(player: Node) -> bool:
	if player == null or not player.has_method("equip_sword"):
		return false
	var current: StringName = player.call("current_sword") if player.has_method("current_sword") else &""
	if current == sword_id:
		return false
	var done: bool = bool(player.call("equip_sword", sword_id))
	if done:
		_flash_left = 0.5
		sword_picked.emit(sword_id)
	return done


func _on_body_entered(body: Node3D) -> void:
	give_to(body)


# ---- looks ----

func _build() -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = radius_m
	cylinder.height = 1.6
	shape.shape = cylinder
	shape.position.y = 0.8
	add_child(shape)

	var base: MeshInstance3D = MeshInstance3D.new()
	var base_mesh: CylinderMesh = CylinderMesh.new()
	base_mesh.top_radius = radius_m * 0.55
	base_mesh.bottom_radius = radius_m * 0.7
	base_mesh.height = 0.35
	base.mesh = base_mesh
	base.position.y = 0.175
	var base_material: StandardMaterial3D = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.16, 0.17, 0.2)
	base_material.roughness = 0.8
	base.material_override = base_material
	add_child(base)

	_ring = MeshInstance3D.new()
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = radius_m * 0.62
	ring_mesh.outer_radius = radius_m * 0.72
	_ring.mesh = ring_mesh
	_ring.position.y = 0.37
	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	var tint: Color = _trail_color()
	ring_material.albedo_color = tint
	ring_material.emission_enabled = true
	ring_material.emission = tint
	ring_material.emission_energy_multiplier = 1.0
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = ring_material
	add_child(_ring)

	_display = Node3D.new()
	_display.name = "Display"
	_display.position.y = FLOAT_HEIGHT_M
	add_child(_display)
	_display.add_child(_make_sword_model())

	_label = Label3D.new()
	_label.text = display_name()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.006
	_label.font_size = 36
	_label.outline_size = 10
	_label.no_depth_test = true
	_label.position.y = 1.85
	_label.modulate = Color(1.0, 0.95, 0.8)
	add_child(_label)


func _make_sword_model() -> Node3D:
	var entry: Dictionary = sword_entry()
	var path: String = str(entry.get("model", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		if scene != null:
			var model: Node3D = scene.instantiate() as Node3D
			if model != null:
				Ps2Look.upgrade_model(model, path, LookProfiles.active())
				return model
	var bar: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.08, 0.9, 0.04)
	bar.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = _trail_color()
	material.emission_enabled = true
	material.emission = _trail_color()
	bar.material_override = material
	return bar


func _trail_color() -> Color:
	var trail: Variant = sword_entry().get("trail", {})
	if trail is Dictionary and (trail as Dictionary).has("color"):
		return Color.html(str((trail as Dictionary)["color"]))
	return Color(0.4, 0.9, 1.0)
