class_name DashStreak
extends Node3D
## Speed streaks left in the air behind a dash: a few thin additive lines at different heights, along the line of travel,
## fading out fast. Real time (it is a picture of speed, not something that lives in combat time).
## fx.json `dash`: count, length_m, width_m, life_s, color, spread_m, heights, glow.

const STREAK_SHADER: String = "res://shaders/sword_trail.gdshader"

var config: Dictionary = {}
var travel: Vector3 = Vector3.FORWARD     # the way she dashed (unit)
var in_air: bool = false

var _age: float = 0.0
var _life: float = 0.24
var _mesh: ArrayMesh = ArrayMesh.new()
var _material: ShaderMaterial = null


## `start` is where the dash began (her feet). The streaks lie along `direction` from there, trailing behind her.
static func spawn(parent: Node, start: Vector3, direction: Vector3, dash_config: Dictionary, air: bool = false) -> DashStreak:
	var streak: DashStreak = DashStreak.new()
	streak.config = dash_config
	streak.travel = Vector3(direction.x, 0.0, direction.z).normalized() if Vector2(direction.x, direction.z).length() > 0.01 else Vector3.FORWARD
	streak.in_air = air
	streak.top_level = true
	parent.add_child(streak)
	streak.global_position = start
	return streak


func _ready() -> void:
	_life = float(config.get("life_s", 0.24))
	_material = ShaderMaterial.new()
	_material.shader = load(STREAK_SHADER) as Shader
	_material.set_shader_parameter(&"glow", float(config.get("glow", 1.8)))
	_material.set_shader_parameter(&"tip_bias", 0.9)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "Lines"
	instance.mesh = _mesh
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 6.0
	add_child(instance)
	_rebuild(0.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_rebuild(_age / _life)


func _rebuild(k: float) -> void:
	_mesh.clear_surfaces()
	var color: Color = Color.html(str(config.get("air_color" if in_air else "color", "#cfeaff")))
	color.a = (1.0 - k) * (1.0 - k)
	var arrays: Array = line_arrays(travel, config, color, k)
	if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() >= 3:
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## The lines as triangles (pure): `count` ribbons trailing back from the origin along -travel, at the configured heights, fanned
## sideways by `spread_m`. They shrink toward the origin as `k` (0..1 through the effect) rises, so they seem to be left behind.
static func line_arrays(direction: Vector3, dash_config: Dictionary, color: Color, k: float) -> Array:
	var count: int = int(dash_config.get("count", 3))
	var length: float = float(dash_config.get("length_m", 2.4))
	var width: float = float(dash_config.get("width_m", 0.05))
	var spread: float = float(dash_config.get("spread_m", 0.2))
	var heights: Array = dash_config.get("heights", [0.4]) as Array
	var side: Vector3 = direction.cross(Vector3.UP).normalized()
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	for index: int in count:
		var offset: float = (float(index) - float(count - 1) * 0.5) * spread
		var height: float = float(heights[index % heights.size()])
		var near: Vector3 = Vector3(0.0, height, 0.0) + side * offset
		var far: Vector3 = near - direction * length * (1.0 - 0.5 * k)
		var thin: Vector3 = Vector3.UP * width * 0.5
		var quad: Array[Vector3] = [far - thin, far + thin, near + thin, near - thin]
		var quad_uv: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0)]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			vertices.append(quad[corner])
			colors.append(color)
			uvs.append(quad_uv[corner])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return arrays
