class_name DialogueTest
extends Node
## Standalone bench for speech bubbles, the voiced typing, the dialogue runner and the field menu:
## a tiny PSX room with placeholder capsule speakers (Red, Otis, Mox, an old Zero). Not part of
## the game flow; open scenes/debug/dialogue_test.tscn directly.
##
## Keys: 1 Otis talk · 2 Mox talk · 3 Zero talk · 4 sign · 5 narrator · 6 Red gestures
##       7 Mox faces · 8 Otis faces · 9 crowd NPC box (portrait and {face:...} demos)
##       Tab / C opens the field menu · E / Z / Enter advance bubbles.
## Capture scripts (tests/visual/capture_m1_speech_bubble.gd) use `speakers` and `runner` directly.

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"
const MENU_SCENE: String = "res://scenes/ui/field_menu.tscn"
const FLOOR_TEXTURE: String = "res://art/placeholder/textures/checker_64.png"
const LIT_SHADER: String = "res://shaders/psx_lit.gdshader"
const KEY_CONVERSATIONS: Dictionary[Key, String] = {
	KEY_1: "otis_talk", KEY_2: "mox_talk", KEY_3: "zero_talk", KEY_4: "examine_sign", KEY_5: "examine_pillar",
	KEY_7: "demo_mox_faces", KEY_8: "demo_otis_faces", KEY_9: "demo_crowd_dockhand",
}
const SPEAKER_LAYOUT: Dictionary[String, Dictionary] = {
	"red": {"pos": Vector3(0.0, 0.0, 1.4), "height": 1.0, "color": Color(0.9, 0.3, 0.25)},
	"otis": {"pos": Vector3(-3.2, 0.0, 0.8), "height": 1.25, "color": Color(0.95, 0.55, 0.22)},
	"mox": {"pos": Vector3(3.2, 0.0, 0.6), "height": 1.15, "color": Color(0.9, 0.75, 0.3)},
	"zero_old": {"pos": Vector3(1.0, 0.0, -1.2), "height": 1.0, "color": Color(0.85, 0.72, 0.5)},
}
const HINT_TEXT: String = "1 Otis  2 Mox  3 Zero  4 Sign  5 Pillar  6 Red  7 Mox faces  8 Otis faces  9 Crowd  Tab Menu"

## Start this conversation when the scene opens (empty = wait for a key).
@export var autostart_conversation: String = ""

var screen: PsxScreen = null
var runner: DialogueRunner = null
var menu: FieldMenu = null
var camera: Camera3D = null
var speakers: Dictionary[String, Node3D] = {}
var _hint: Label = null


func _ready() -> void:
	screen = (load(SCREEN_SCENE) as PackedScene).instantiate() as PsxScreen
	add_child(screen)
	_build_world(screen.get_world_root())
	var stage: UiStage = UiStage.get_or_create(get_tree())
	runner = DialogueRunner.new()
	runner.name = "DialogueRunner"
	runner.camera = camera
	add_child(runner)
	for id: String in speakers:
		runner.register_speaker(id, speakers[id])
	menu = (load(MENU_SCENE) as PackedScene).instantiate() as FieldMenu
	stage.get_stage_root().add_child(menu)
	_add_hint(stage.get_stage_root())
	if not autostart_conversation.is_empty():
		runner.start(autostart_conversation)


func _process(_delta: float) -> void:
	if _hint != null:
		_hint.visible = not UiStage.is_busy(get_tree())


func _input(event: InputEvent) -> void:
	if runner == null or runner.is_running() or UiStage.is_busy(get_tree()):
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key: Key = (event as InputEventKey).keycode
		if KEY_CONVERSATIONS.has(key):
			runner.start(KEY_CONVERSATIONS[key])
		elif key == KEY_6:
			runner.add_conversations({"red_demo": [
				{"speaker": "red", "gesture": "thumbs_up"}, {"speaker": "red", "gesture": "head_shake"},
				{"speaker": "red", "gesture": "exclaim"}, {"speaker": "red", "gesture": "question"},
				{"speaker": "red", "gesture": "dots"}, {"speaker": "red", "gesture": "heart"},
				{"speaker": "red", "gesture": "sweat"}]})
			runner.start("red_demo")


func _add_hint(stage_root: Control) -> void:
	var label: Label = Label.new()
	label.text = HINT_TEXT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiText.style_label(label, "dialogue", Color.html("#8D97A5"))
	label.position = Vector2(6, 198)
	stage_root.add_child(label)
	_hint = label


# ---- a tiny room ----

func _build_world(world: Node3D) -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.html("#1F2540")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.97, 1.0)
	environment.ambient_light_energy = 1.6
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(12.0, 0.2, 7.0)
	floor_mesh.mesh = box
	floor_mesh.position = Vector3(0.0, -0.1, -0.5)
	floor_mesh.material_override = _psx_material(Color(1.0, 0.95, 1.0), Vector2(6.0, 3.5))
	world.add_child(floor_mesh)
	for id: String in SPEAKER_LAYOUT:
		var entry: Dictionary = SPEAKER_LAYOUT[id]
		var node: Node3D = _make_capsule(id, float(entry["height"]), entry["color"])
		node.position = entry["pos"]
		world.add_child(node)
		speakers[id] = node
	var rig: DioramaCamera = DioramaCamera.new()
	rig.name = "CameraRig"
	rig.auto_update = false
	world.add_child(rig)
	camera = rig.get_camera()
	rig.set_target(speakers["red"])
	rig.snap_to_target()


## A chibi stand-in: a big head on a small body, tinted per speaker (the final models are Ross's).
func _make_capsule(id: String, height: float, color: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = id.capitalize()
	var body: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = height * 0.5
	body.mesh = capsule
	body.position = Vector3(0.0, height * 0.25, 0.0)
	body.material_override = _psx_material(color.darkened(0.2), Vector2.ONE, true)
	root.add_child(body)
	var head: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = height * 0.3
	sphere.height = height * 0.6
	sphere.radial_segments = 12
	sphere.rings = 6
	head.mesh = sphere
	head.position = Vector3(0.0, height * 0.7, 0.0)
	head.material_override = _psx_material(color, Vector2.ONE, true)
	root.add_child(head)
	return root


func _psx_material(tint: Color, uv_scale: Vector2, flat: bool = false) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(LIT_SHADER) as Shader
	if flat:
		var white: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		material.set_shader_parameter("albedo_texture", ImageTexture.create_from_image(white))
	else:
		material.set_shader_parameter("albedo_texture", load(FLOOR_TEXTURE))
	material.set_shader_parameter("albedo_tint", tint)
	material.set_shader_parameter("uv_scale", uv_scale)
	return material
