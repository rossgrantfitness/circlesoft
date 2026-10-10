class_name Scanner
extends Node3D
## A Signals inspector's hand scanner: a flat, dithered cone on the floor that sweeps left and right.
## It is the inspector's only way of noticing Red (data/world/scanner.json, docs/maps/ore_train.md):
##   - the cone is length_m long and half_angle_deg wide on each side of where it points; it points where
##     the inspector faces, swung sweep_deg left and right once every sweep_period_s;
##   - Red must stand inside it, unblocked, for spot_time_s (the timer drains again when she slips out);
##   - cover blocks it: a ray from the scanner (scan_height up) to Red's chest (target_height up) that
##     meets a body in group "cover" taller than cover_min_height stops it. Low things (the lashed
##     crates) are not cover.
## When it spots her the cone turns red and a "?" pops over the inspector's head. The MapEnemy then chases
## like any other. Add one as a child of a MapEnemy (placement "scanner": true) and call advance(delta)
## every step; MapEnemy asks sees(...) when it is looking for her.

const DATA_ID: String = "world/scanner"
const GROUP_COVER: StringName = &"cover"
const SHADER_UNLIT: String = "res://shaders/psx_unlit.gdshader"
const COVER_HEIGHT_META: StringName = &"height"
const MAX_RAY_HOPS: int = 6
const HEAD_HEIGHT: float = 1.75
const MASK_WORLD: int = 1

signal spotted_red

var length_m: float = 5.0
var half_angle_deg: float = 25.0
var sweep_deg: float = 20.0
var sweep_period_s: float = 2.0
var spot_time_s: float = 0.4
var scan_height: float = 1.0
var target_height: float = 0.6
var cover_min_height: float = 1.2
var question_s: float = 1.1

var is_spotted: bool = false
var cone: MeshInstance3D = null
var question: Label3D = null

var _cfg: Dictionary = {}
var _clock: float = 0.0
var _spot_timer: float = 0.0
var _question_left: float = 0.0
var _material: ShaderMaterial = null


func _ready() -> void:
	_cfg = DataDB.get_dict(DATA_ID)
	length_m = float(_cfg.get("length_m", length_m))
	half_angle_deg = float(_cfg.get("half_angle_deg", half_angle_deg))
	sweep_deg = float(_cfg.get("sweep_deg", sweep_deg))
	sweep_period_s = float(_cfg.get("sweep_period_s", sweep_period_s))
	spot_time_s = float(_cfg.get("spot_time_s", spot_time_s))
	scan_height = float(_cfg.get("scan_height", scan_height))
	target_height = float(_cfg.get("target_height", target_height))
	cover_min_height = float(_cfg.get("cover_min_height", cover_min_height))
	question_s = float(_cfg.get("question_s", question_s))
	name = "Scanner"
	_build_cone()
	_build_question()
	set_spotted(false)


## Moves the sweep along (call once per step while the inspector is running; a cutscene stops calling it).
func advance(delta: float) -> void:
	_clock += delta
	if cone != null:
		cone.rotation.y = sweep_offset()
	if _question_left > 0.0:
		_question_left = maxf(_question_left - delta, 0.0)
		if question != null:
			question.visible = _question_left > 0.0


## How far the cone is swung from straight ahead right now (radians, positive = toward the inspector's left).
func sweep_offset() -> float:
	if sweep_period_s <= 0.0:
		return 0.0
	return deg_to_rad(sweep_deg) * sin(_clock * TAU / sweep_period_s)


## The unit direction (flat) the scanner points right now, given where the inspector faces.
func cone_direction(facing: Vector3) -> Vector3:
	var flat: Vector3 = Vector3(facing.x, 0.0, facing.z)
	if flat.length() < 0.001:
		return Vector3.BACK
	return flat.normalized().rotated(Vector3.UP, sweep_offset())


## True when `point` (flat) is inside the cone from `from` (no cover check).
func in_cone(from: Vector3, facing: Vector3, point: Vector3) -> bool:
	var offset: Vector3 = Vector3(point.x - from.x, 0.0, point.z - from.z)
	var distance: float = offset.length()
	if distance > length_m:
		return false
	if distance < 0.05:
		return true
	return cone_direction(facing).dot(offset / distance) >= cos(deg_to_rad(half_angle_deg))


## True when cover (a body in group "cover" taller than cover_min_height) is between the scanner and Red's chest.
func blocked(from: Vector3, point: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var start: Vector3 = Vector3(from.x, from.y + scan_height, from.z)
	var end: Vector3 = Vector3(point.x, point.y + target_height, point.z)
	var excluded: Array[RID] = []
	for hop: int in MAX_RAY_HOPS:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end, MASK_WORLD)
		query.exclude = excluded
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return false
		var body: Object = hit["collider"]
		if is_cover(body):
			return true
		excluded.append(hit["rid"])
	return false


## True for a body that counts as cover: in group "cover" and taller than cover_min_height.
func is_cover(body: Object) -> bool:
	if not body is Node or not (body as Node).is_in_group(GROUP_COVER):
		return false
	var height: float = float((body as Node).get_meta(COVER_HEIGHT_META, 2.0))
	return height > cover_min_height


## One look for Red. Returns true once she has been inside the cone, unblocked, for spot_time_s.
func sees(from: Vector3, facing: Vector3, point: Vector3, delta: float) -> bool:
	var inside: bool = in_cone(from, facing, point) and not blocked(from, point)
	if inside:
		_spot_timer += delta
	else:
		_spot_timer = maxf(_spot_timer - delta * 2.0, 0.0)
	return _spot_timer >= spot_time_s


func spot_progress() -> float:
	return clampf(_spot_timer / maxf(spot_time_s, 0.001), 0.0, 1.0)


func reset_spot() -> void:
	_spot_timer = 0.0


## Red cone and a question mark when it has her; the calm cold white otherwise.
func set_spotted(on: bool) -> void:
	var was: bool = is_spotted
	is_spotted = on
	var colors: Dictionary = _cfg.get("colors", {})
	var tint: Color = Color.html(str(colors.get("spotted" if on else "calm", "#ff4a3a" if on else "#d6ecff")))
	if _material != null:
		_material.set_shader_parameter("albedo_tint", tint)
		_material.set_shader_parameter("emission_energy", float(_cfg.get("spotted_energy" if on else "calm_energy", 1.2)))
	if on and not was:
		_question_left = question_s
		if question != null:
			question.visible = true
		spotted_red.emit()
	elif not on:
		reset_spot()
		_question_left = 0.0
		if question != null:
			question.visible = false


func _build_cone() -> void:
	var steps: int = maxi(int(_cfg.get("cone_steps", 10)), 2)
	var y: float = float(_cfg.get("cone_y", 0.045))
	var cell: float = maxf(float(_cfg.get("dither_cell_m", 0.2)), 0.02)
	var half: float = deg_to_rad(half_angle_deg)
	var points: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	points.append(Vector3(0.0, y, 0.0))
	uvs.append(Vector2.ZERO)
	for i: int in steps + 1:
		var angle: float = lerpf(-half, half, float(i) / float(steps))
		var p: Vector3 = Vector3(sin(angle) * length_m, y, cos(angle) * length_m)
		points.append(p)
		uvs.append(Vector2(p.x, p.z) / (cell * 4.0))
	for i: int in steps:
		indices.append_array([0, i + 1, i + 2])
		indices.append_array([0, i + 2, i + 1])  # both sides, so it shows whichever way the winding falls
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	cone = MeshInstance3D.new()
	cone.name = "Cone"
	cone.mesh = mesh
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_UNLIT) as Shader
	_material.set_shader_parameter("albedo_texture", _dither_texture())
	_material.set_shader_parameter("uv_scale", Vector2.ONE)
	cone.material_override = _material
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cone)


## A 4x4 ordered-dither tile: about 40 percent of the texels are solid, the rest are cut out.
static func _dither_texture() -> ImageTexture:
	var bayer: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for i: int in 16:
		image.set_pixel(i % 4, i / 4, Color(1, 1, 1, 1.0 if bayer[i] < 6 else 0.0))
	return ImageTexture.create_from_image(image)


func _build_question() -> void:
	question = Label3D.new()
	question.name = "Question"
	question.text = str(_cfg.get("question_text", "?"))
	question.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	question.pixel_size = 0.014
	question.font_size = 44
	question.outline_size = 12
	question.modulate = Color(1.0, 0.9, 0.5)
	question.no_depth_test = true
	question.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	question.position = Vector3(0.0, HEAD_HEIGHT, 0.0)
	question.visible = false
	add_child(question)
