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
## The ring is a soft, dim marker, never bright enough to be mistaken for an enemy's wind-up warning.
const RING_GLOW: float = 0.3
const RING_GREY_MIX: float = 0.55
const LABEL_FONT_KEY: String = "tag"
const SHADOW_OFFSET_PX: Vector2 = Vector2(2.0, -2.0)

@export var sword_id: StringName = &""
@export var radius_m: float = 0.9
## The ring around the pedestal is this fraction of its old size (it loomed into the screen corners).
@export var ring_scale: float = 0.6
## The name label shows only when Red is this close (metres) and fades out over label_fade_m beyond it.
@export var label_show_m: float = 3.0
@export var label_fade_m: float = 1.0
## Whose distance decides the label (Red). Null = the label always shows.
var watch: Node3D = null

var _display: Node3D = null
var _time: float = 0.0
var _label: Label3D = null
var _label_shadow: Label3D = null
## Only the nearest stand shows its name (the sandbox sets this each frame).
var label_enabled: bool = true
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
	_update_label()
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		if _ring != null:
			(_ring.material_override as StandardMaterial3D).emission_energy_multiplier = RING_GLOW + _flash_left * 2.0


## 1 when Red is within label_show_m, fading to 0 over label_fade_m beyond it, else 0.
func label_alpha() -> float:
	if not label_enabled:
		return 0.0
	if watch == null or not is_instance_valid(watch):
		return 1.0
	var flat: Vector3 = watch.global_position - global_position
	flat.y = 0.0
	return clampf((label_show_m + label_fade_m - flat.length()) / maxf(label_fade_m, 0.01), 0.0, 1.0)


func _update_label() -> void:
	if _label == null:
		return
	var alpha: float = label_alpha()
	_label.visible = alpha > 0.0
	_label.modulate.a = alpha
	if _label_shadow != null:
		_label_shadow.visible = alpha > 0.0
		_label_shadow.modulate.a = alpha


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
	ring_mesh.inner_radius = radius_m * 0.62 * ring_scale
	ring_mesh.outer_radius = radius_m * 0.72 * ring_scale
	_ring.mesh = ring_mesh
	_ring.position.y = 0.37
	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	var tint: Color = _trail_color().lerp(Color(0.5, 0.52, 0.55), RING_GREY_MIX)
	ring_material.albedo_color = tint
	ring_material.emission_enabled = true
	ring_material.emission = tint
	ring_material.emission_energy_multiplier = RING_GLOW
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = ring_material
	add_child(_ring)

	_display = Node3D.new()
	_display.name = "Display"
	_display.position.y = FLOAT_HEIGHT_M
	add_child(_display)
	_display.add_child(_make_sword_model())

	# The name: the sandbox UI font, white, with the black down-right drop shadow (a second label behind it).
	var font: Font = UiFonts.get_font(LABEL_FONT_KEY)
	_label_shadow = _make_label(font, Color.BLACK, Vector2.ZERO + SHADOW_OFFSET_PX, -1)
	_label = _make_label(font, Color.WHITE, Vector2.ZERO, 0)
	add_child(_label_shadow)
	add_child(_label)


func _make_label(font: Font, color: Color, offset_px: Vector2, priority: int) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = display_name()
	label.font = font
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.004
	label.font_size = 32
	label.outline_size = 0
	label.no_depth_test = true
	label.render_priority = priority
	label.offset = offset_px
	label.position.y = 1.65
	label.modulate = color
	return label


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
