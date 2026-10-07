class_name ShopCounter
extends Interactable
## A shop counter Red can use with the interact button: it opens a shop from data/shops/ (`shop_id`).
## A placeholder counter (a box, a top slab and a sign with the shop's name) is built from code when
## the node has no children, with a collision box so Red walks up to it instead of through it.
## Real shop fronts replace it later; the interaction stays the same.
##
## How it plugs into the existing interact button: its `conversation` is the empty hook
## "shop_counter" (the same trick the save lamps use), so the interactor picks it like anything else
## and calls begin_use(). The shop opens once the interactor's own hook has let go of Red and the UI
## (a couple of frames), so Red's frozen state is never fought over.

const HOOK_CONVERSATION: String = "shop_counter"
const GROUP_COUNTER: StringName = &"shop_counter"
const SHADER_LIT: String = "res://shaders/psx_lit.gdshader"
const TEXTURE_PATH: String = "res://art/placeholder/textures/checker_128.png"
const COLOR_BODY: Color = Color(0.55, 0.36, 0.23)
const COLOR_TOP: Color = Color(0.72, 0.55, 0.36)
const COLOR_SIGN_GENERAL: Color = Color(0.95, 0.7, 0.28)
const COLOR_SIGN_GEAR: Color = Color(0.45, 0.62, 0.78)
const WAIT_FRAMES_MAX: int = 120

signal shop_opened(shop_id: String)

## The shop file in data/shops/ (its file name, without .json).
@export var shop_id: String = ""
## Builds the placeholder counter (box, slab, sign, collision) when the node has no children.
@export var build_placeholder: bool = true
## Sign text; empty uses the shop's name.
@export var sign_text: String = ""

## Injected for tests: the shop screen to open and the player to freeze. Null means "make one on the
## UI stage" and "the owning FieldRoom's player".
var shop_menu: ShopMenu = null
var player: Node = null
var runner: DialogueRunner = null

var _opening: bool = false
var _waited: int = 0
var _own_menu: ShopMenu = null


func _init() -> void:
	conversation = HOOK_CONVERSATION
	kind = Kind.TALK


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_COUNTER)
	if build_placeholder and get_child_count() == 0:
		_build_placeholder()
	set_process(false)
	get_tree().node_added.connect(_on_node_added)
	_ensure_hook.call_deferred()


func _exit_tree() -> void:
	if _own_menu != null and is_instance_valid(_own_menu):
		_own_menu.remove_from_group(UiStage.MODAL_GROUP)
		_own_menu.queue_free()
	_own_menu = null


func _process(_delta: float) -> void:
	tick_open()


## The interact button's hook: start waiting for the UI to be free, then open the shop.
func begin_use(from_point: Vector3) -> void:
	super.begin_use(from_point)
	_opening = true
	_waited = 0
	set_process(true)


func is_opening() -> bool:
	return _opening


## Opens the shop when nothing else holds the UI. Returns true once it is open. Called every frame
## after begin_use(); tests call it by hand.
func tick_open() -> bool:
	if not _opening:
		return false
	_waited += 1
	if _waited > WAIT_FRAMES_MAX:
		_opening = false
		set_process(false)
		return false
	if UiStage.is_busy(get_tree()):
		return false
	var menu: ShopMenu = _menu()
	if menu == null or not menu.open_shop(shop_id):
		return false
	_opening = false
	set_process(false)
	shop_opened.emit(shop_id)
	return true


func _menu() -> ShopMenu:
	if shop_menu != null and is_instance_valid(shop_menu):
		return shop_menu
	if _own_menu == null or not is_instance_valid(_own_menu):
		_own_menu = ShopMenu.install(get_tree(), _player() as PlayerController)
	return _own_menu


func _room() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is FieldRoom:
			return node
		node = node.get_parent()
	return null


func _player() -> Node:
	if player != null:
		return player
	var room: Node = _room()
	return room.get("player") as Node if room != null else null


func _runner() -> DialogueRunner:
	if runner != null:
		return runner
	var room: Node = _room()
	return room.get("runner") as DialogueRunner if room != null else null


# ---- the empty hook conversation (same trick as the save lamps) ----

func _ensure_hook() -> void:
	_register_hook(_runner())


func _register_hook(active: DialogueRunner) -> void:
	if active == null or active.has_conversation(HOOK_CONVERSATION):
		return
	active.add_conversations({HOOK_CONVERSATION: []})


func _on_node_added(node: Node) -> void:
	if node is DialogueRunner and is_inside_tree():
		var room: Node = _room()
		if room != null and room.is_ancestor_of(node):
			_register_hook(node as DialogueRunner)


func usable_distance(point: Vector3, facing: Vector3, tuning: InteractionTuning) -> float:
	_ensure_hook()
	return super.usable_distance(point, facing, tuning)


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
