class_name CarriedCrate
extends Node3D
## The delivery crate on Red's back: a plain tan box (placeholder, no animation) that rides on her while the
## Delivery Crate key item is in the bag, and goes away when the ditch scene takes the crate out of it
## (docs/maps/ore_train.md). Put one in a room scene; it hangs itself on the player once the room is ready.

const ITEM_ID: String = "delivery_crate"
const SHADER_PATH: String = "res://shaders/psx_lit.gdshader"
const TEXTURE_PATH: String = "res://art/placeholder/textures/checker_64.png"
const SIZE: Vector3 = Vector3(0.5, 0.5, 0.5)
## On her back: behind her (she faces +Z), at shoulder height.
const OFFSET: Vector3 = Vector3(0.0, 0.85, -0.34)

var _box: MeshInstance3D = null
var _state: Node = null


func _ready() -> void:
	visible = false
	var host: Node = get_parent()
	if host != null and not host.is_node_ready():
		await host.ready
	_attach(host)


func _attach(host: Node) -> void:
	if not host is FieldRoom or (host as FieldRoom).player == null:
		return
	var player: Node3D = (host as FieldRoom).player
	if get_parent() != player:
		reparent(player, false)
	position = OFFSET
	rotation = Vector3.ZERO
	_build()
	_state = WorldProgress.game_state()
	if _state != null and _state.has_signal("item_changed") and not _state.is_connected("item_changed", _on_item):
		_state.connect("item_changed", _on_item)
	refresh()


func refresh() -> void:
	var count: int = 0
	if _state != null and _state.has_method("item_count"):
		count = int(_state.call("item_count", ITEM_ID))
	visible = count > 0


func _on_item(item_id: String, _count: int) -> void:
	if item_id == ITEM_ID:
		refresh()


func _build() -> void:
	if _box != null:
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = SIZE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_PATH) as Shader
	material.set_shader_parameter("albedo_texture", load(TEXTURE_PATH))
	material.set_shader_parameter("albedo_tint", Color(0.72, 0.55, 0.36))
	_box = MeshInstance3D.new()
	_box.name = "Box"
	_box.mesh = mesh
	_box.material_override = material
	add_child(_box)
