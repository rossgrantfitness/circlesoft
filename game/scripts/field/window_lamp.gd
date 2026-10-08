class_name WindowLamp
extends Node3D
## One of Lamp Square's twelve window lamps (docs/maps/harrow_landing.md). Each is its own light switch:
## lit (an amber glowing quad and a small warm light) or dark (a gray unlit frame, no light), decided by the
## 'lit_if' Conditions dictionary of its id in data/world/windows.json. It re-checks whenever a flag changes,
## so the walk-home scenes (and the side job) just set a flag and the window lights up.
## Placeholder art: two flat boxes and one omni light, built here so the room scene only holds the position.

const DATA_ID: String = "world/windows"
const LIT_TINT: Color = Color(1.0, 0.82, 0.45)
const DARK_TINT: Color = Color(0.12, 0.13, 0.18)
const SHADER_PATH: String = "res://shaders/psx_unlit.gdshader"
const TEXTURE_PATH: String = "res://art/placeholder/textures/checker_64.png"

signal changed(window_id: String, lit: bool)

@export var window_id: String = ""
@export var size: Vector2 = Vector2(0.5, 0.6)
@export var light_range: float = 3.2
@export var light_energy: float = 1.6

var lit: bool = false
var _glass: MeshInstance3D = null
var _frame: MeshInstance3D = null
var _light: OmniLight3D = null


func _ready() -> void:
	_build()
	var state: Node = WorldProgress.game_state()
	if state != null and state.has_signal("flag_changed") and not state.is_connected("flag_changed", _on_flag):
		state.connect("flag_changed", _on_flag)
	refresh()


## Every window id the data file lists, in order.
static func ids() -> Array[String]:
	var found: Array[String] = []
	found.assign((DataDB.get_dict(DATA_ID).get("windows", {}) as Dictionary).keys())
	return found


## True when the window with this id is lit right now.
static func is_lit(id: String, game_state: Node = null) -> bool:
	var windows: Dictionary = DataDB.get_dict(DATA_ID).get("windows", {})
	if not windows.has(id):
		return false
	return Conditions.met((windows[id] as Dictionary).get("lit_if", {}), game_state)


func refresh() -> void:
	var now_lit: bool = is_lit(window_id)
	var was: bool = lit
	lit = now_lit
	if _glass != null:
		_glass.visible = lit
		_frame.visible = not lit
		_light.visible = lit
	if was != lit:
		changed.emit(window_id, lit)


func _on_flag(_flag_id: String, _value: bool) -> void:
	refresh()


func _build() -> void:
	var shader: Shader = load(SHADER_PATH) as Shader
	var texture: Texture2D = load(TEXTURE_PATH) as Texture2D
	_glass = _quad("Glass", LIT_TINT, 1.5, shader, texture, 0.05)
	_frame = _quad("Frame", DARK_TINT, 1.0, shader, texture, 0.04)
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.position = Vector3(0.0, 0.0, 0.5)
	_light.light_color = Color(1.0, 0.7, 0.28)
	_light.light_energy = light_energy
	_light.omni_range = light_range
	add_child(_light)


func _quad(node_name: String, tint: Color, energy: float, shader: Shader, texture: Texture2D, depth: float) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, depth)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("albedo_texture", texture)
	material.set_shader_parameter("uv_scale", Vector2(0.07, 0.07))
	material.set_shader_parameter("albedo_tint", tint)
	material.set_shader_parameter("emission_energy", energy)
	var quad: MeshInstance3D = MeshInstance3D.new()
	quad.name = node_name
	quad.mesh = mesh
	quad.material_override = material
	add_child(quad)
	return quad
