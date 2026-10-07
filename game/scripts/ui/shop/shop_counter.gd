class_name ShopCounter
extends Interactable
## A shop counter Red can use with the interact button: it opens a shop from data/shops/ (`shop_id`).
## A placeholder counter (a box, a top slab and a sign with the shop's name) is built from code when
## the node has no children, with a collision box so Red walks up to it instead of through it.
## Real shop fronts replace it later; the interaction stays the same.
##
## It acts instead of talking: the Interactable `handler` hook (see PlayerInteractor.try_interact)
## opens the shop screen straight away. The interactor only fires when no bubble or menu is up, so
## there is nothing to wait for.

const GROUP_COUNTER: StringName = &"shop_counter"
const SHADER_LIT: String = "res://shaders/psx_lit.gdshader"
const TEXTURE_PATH: String = "res://art/placeholder/textures/checker_128.png"
const COLOR_BODY: Color = Color(0.55, 0.36, 0.23)
const COLOR_TOP: Color = Color(0.72, 0.55, 0.36)
const COLOR_SIGN_GENERAL: Color = Color(0.95, 0.7, 0.28)
const COLOR_SIGN_GEAR: Color = Color(0.45, 0.62, 0.78)

signal shop_opened(shop_id: String)

## The shop file in data/shops/ (its file name, without .json).
@export var shop_id: String = ""
## Builds the placeholder counter (box, slab, sign, collision) when the node has no children.
@export var build_placeholder: bool = true
## Sign text; empty uses the shop's name.
@export var sign_text: String = ""

## Injected for tests: the shop screen to open. Null means "make one on the UI stage".
var shop_menu: ShopMenu = null

var _own_menu: ShopMenu = null


func _init() -> void:
	kind = Kind.TALK
	handler = _use


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_COUNTER)
	if build_placeholder and get_child_count() == 0:
		_build_placeholder()


func _exit_tree() -> void:
	if _own_menu != null and is_instance_valid(_own_menu):
		_own_menu.remove_from_group(UiStage.MODAL_GROUP)
		_own_menu.queue_free()
	_own_menu = null


## The interact button's action: open the shop. Returns true when it opened.
func _use(user: Node, _interactor: Node) -> bool:
	var menu: ShopMenu = _menu(user)
	if menu == null or not menu.open_shop(shop_id):
		return false
	shop_opened.emit(shop_id)
	return true


func _menu(user: Node) -> ShopMenu:
	if shop_menu != null and is_instance_valid(shop_menu):
		return shop_menu
	if _own_menu == null or not is_instance_valid(_own_menu):
		_own_menu = ShopMenu.install(get_tree(), user as PlayerController)
	_own_menu.player = user as PlayerController
	return _own_menu


# ---- placeholder counter ----

func _build_placeholder() -> void:
	var texture: Texture2D = load(TEXTURE_PATH) as Texture2D
	var shop: Dictionary = ShopData.load_shop(shop_id)
	var gear: bool = str(shop.get("kind", "")) == ShopData.KIND_GEAR
	_add_box("Body", Vector3(1.5, 0.85, 0.6), Vector3(0.0, 0.425, -0.55), texture, COLOR_BODY)
	_add_box("Top", Vector3(1.64, 0.08, 0.74), Vector3(0.0, 0.89, -0.55), texture, COLOR_TOP)
	_add_box("Sign", Vector3(1.4, 0.38, 0.06), Vector3(0.0, 1.55, -0.78), texture, COLOR_SIGN_GEAR if gear else COLOR_SIGN_GENERAL)
	var label: Label3D = Label3D.new()
	label.name = "SignText"
	label.text = sign_text if not sign_text.is_empty() else str(shop.get("name", shop_id))
	label.font_size = 28
	label.pixel_size = 0.0055
	label.outline_size = 6
	label.modulate = Color(0.93, 0.92, 0.85)
	label.outline_modulate = Color(0.08, 0.07, 0.12)
	label.shaded = false
	label.position = Vector3(0.0, 1.55, -0.74)
	add_child(label)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.64, 1.0, 0.74)
	shape.shape = box
	shape.position = Vector3(0.0, 0.5, -0.55)
	body.add_child(shape)
	add_child(body)


func _add_box(node_name: String, box_size: Vector3, at: Vector3, texture: Texture2D, tint: Color) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_LIT) as Shader
	material.set_shader_parameter("albedo_texture", texture)
	material.set_shader_parameter("albedo_tint", tint)
	mesh_instance.material_override = material
	add_child(mesh_instance)
