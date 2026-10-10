class_name BattleBackdrop
extends Node3D
## The battle set: a toy-box diorama of a floor and two back walls (back and left), warm lamps in the dark, a
## few crates. Placeholder art in the house look: every surface uses the PSX shaders (vertex lighting, snap,
## affine, nearest, stepped fog), textures are painted in code (BattleTextures), floors are cut into 1x1 pieces so
## lamp pools and the affine warp stay gentle. Ross's real sets replace it; the backdrop id from the battle
## snapshot picks a palette (data/battle_stage/stage.json, "backdrops"; unknown ids use "default").

const LIT_SHADER: String = "res://shaders/psx_lit.gdshader"
const UNLIT_SHADER: String = "res://shaders/psx_unlit.gdshader"
const FLOOR_TILE_UNITS: float = 2.0       # a 64 px floor tile covers 2x2 units (32 texels per unit)
const WALL_TILE_UNITS: Vector2 = Vector2(4.0, 2.0)
const WALL_LENGTH_MARGIN: float = 6.0
const POST_WIDTH: float = 0.12
const BULB_RADIUS: float = 0.17
const HALO_SIZE: float = 1.7
const HALO_PX: int = 32
const AFFINE_FLOOR: float = 0.3
const AFFINE_PROP: float = 0.6
const LAMP_BODY_TINT: Color = Color(0.38, 0.4, 0.46, 1.0)
const GROUP_LAMP: StringName = &"battle_lamp"

var backdrop_id: String = ""
var lamps: Array[Node3D] = []
var lights: Array[OmniLight3D] = []
var look: Dictionary = {}

var _lit_shader: Shader = null
var _unlit_shader: Shader = null
var _tuning: BattleStageTuning = null
var _building: bool = false
## The look profile the set was built for ("classic", "grim"); a different one rebuilds it.
var built_profile: String = ""
var dressing: GrimDressing = null
var _grime: Dictionary = {}
var _surface_tints: Dictionary = {}


func _ready() -> void:
	add_to_group(LookProfiles.GROUP_AWARE)


## The look profile changed (F11): rebuild the set in the new look. A build asks for the profile itself,
## so while building this ignores the notice.
func apply_look(profile_id: String, _profile: Dictionary) -> void:
	if _building or _tuning == null or profile_id == built_profile:
		return
	build(_tuning, backdrop_id)


## Builds (or rebuilds) the set for a backdrop id.
func build(tuning: BattleStageTuning, id: String) -> void:
	_building = true
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	lamps.clear()
	lights.clear()
	dressing = null
	_tuning = tuning
	backdrop_id = id
	built_profile = LookProfiles.enter_scene("battle")
	look = LookProfiles.backdrop_look(tuning.backdrop(id), built_profile)
	var profile: Dictionary = LookProfiles.profile(built_profile)
	_grime = profile.get("grime", {}) if profile.get("grime", {}) is Dictionary else {}
	_surface_tints = look.get("surface_tint", {}) if look.get("surface_tint", {}) is Dictionary else {}
	_lit_shader = load(LIT_SHADER) as Shader
	_unlit_shader = load(UNLIT_SHADER) as Shader
	_build_environment()
	_build_surfaces()
	_build_crates()
	_build_lamps()
	_build_key_light()
	if bool(profile.get("dressing", false)):
		dressing = GrimDressing.new()
		dressing.name = "GrimDressing"
		dressing.dressing_id = "battle"
		dressing.restyle_materials = false
		add_child(dressing)
	var void_color: Color = Color.html(str(look["void"]))
	PsxLook.set_fog(void_color, float(look["fog_near"]), float(look["fog_far"]))
	_building = false


## Triangles in the set (for the room budget test).
func triangle_count() -> int:
	var total: int = 0
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			if indices != null and (indices as PackedInt32Array).size() > 0:
				total += (indices as PackedInt32Array).size() / 3
			else:
				total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _build_environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.html(str(look["void"]))
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.html(str(look["ambient"]))
	environment.ambient_light_energy = float(look["ambient_energy"])
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)


func _build_surfaces() -> void:
	var size: Dictionary = look["size"]
	var floor_size: Vector2 = Vector2(float((size["floor"] as Array)[0]), float((size["floor"] as Array)[1]))
	var back_z: float = float(size["back_wall_z"])
	var left_x: float = float(size["left_wall_x"])
	var wall_h: float = float(size["wall_height"])
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = floor_size
	floor_mesh.subdivide_width = int(floor_size.x) - 1
	floor_mesh.subdivide_depth = int(floor_size.y) - 1
	var floor_instance: MeshInstance3D = MeshInstance3D.new()
	floor_instance.name = "Floor"
	floor_instance.mesh = floor_mesh
	floor_instance.position = Vector3(left_x + floor_size.x / 2.0, 0.0, back_z + floor_size.y / 2.0)
	floor_instance.set_surface_override_material(0, _lit(_floor_texture(), floor_size / FLOOR_TILE_UNITS, _tint_for("floor"), AFFINE_FLOOR))
	add_child(floor_instance)
	var wall_texture: ImageTexture = _wall_texture()
	var back_len: float = floor_size.x + WALL_LENGTH_MARGIN
	var back_mesh: PlaneMesh = PlaneMesh.new()
	back_mesh.size = Vector2(back_len, wall_h)
	back_mesh.orientation = PlaneMesh.FACE_Z
	back_mesh.subdivide_width = int(back_len / 2.0) - 1
	back_mesh.subdivide_depth = 1
	var back: MeshInstance3D = MeshInstance3D.new()
	back.name = "WallBack"
	back.mesh = back_mesh
	back.position = Vector3(left_x + back_len / 2.0, wall_h / 2.0, back_z)
	back.set_surface_override_material(0, _lit(wall_texture, Vector2(back_len, wall_h) / WALL_TILE_UNITS, _tint_for("wall"), AFFINE_FLOOR))
	add_child(back)
	var left_len: float = floor_size.y + 2.0
	var left_mesh: PlaneMesh = PlaneMesh.new()
	left_mesh.size = Vector2(left_len, wall_h)
	left_mesh.orientation = PlaneMesh.FACE_X
	left_mesh.subdivide_width = int(left_len / 2.0) - 1
	left_mesh.subdivide_depth = 1
	var left: MeshInstance3D = MeshInstance3D.new()
	left.name = "WallLeft"
	left.mesh = left_mesh
	left.position = Vector3(left_x, wall_h / 2.0, back_z + left_len / 2.0)
	left.set_surface_override_material(0, _lit(wall_texture, Vector2(left_len, wall_h) / WALL_TILE_UNITS, _tint_for("wall"), AFFINE_FLOOR))
	add_child(left)


## The grim look paints its own grimy floor and walls (GrimePaint) in place of the toy-box ones.
func _floor_texture() -> ImageTexture:
	if _surface_tints.has("floor"):
		return GrimePaint.surface_texture("floor", _grime)
	return BattleTextures.floor_texture(look)


func _wall_texture() -> ImageTexture:
	if _surface_tints.has("wall"):
		return GrimePaint.surface_texture("wall", _grime)
	return BattleTextures.wall_texture(look)


func _tint_for(part: String) -> Color:
	return Color.html(str(_surface_tints[part])) if _surface_tints.has(part) else Color.WHITE


func _build_crates() -> void:
	var crate_material: ShaderMaterial = _lit(BattleTextures.crate_texture(look), Vector2.ONE, _tint_for("crate"), AFFINE_PROP)
	var index: int = 0
	for entry: Variant in (look["crates"] as Array):
		var crate: Dictionary = entry
		var size: Vector3 = BattleStageTuning.vec3_of(crate["size"])
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "Crate%d" % index
		instance.mesh = mesh
		var base: Vector3 = BattleStageTuning.vec3_of(crate["pos"])
		instance.position = base + Vector3(0.0, size.y / 2.0, 0.0)
		instance.rotation_degrees.y = float(crate["yaw_deg"])
		instance.set_surface_override_material(0, crate_material)
		add_child(instance)
		index += 1


func _build_lamps() -> void:
	var halo_color: Color = Color.html("#FFB347")
	var halo_texture: ImageTexture = BattleTextures.halo_texture(HALO_PX, halo_color)
	var post_texture: ImageTexture = BattleTextures.crate_texture(look)
	var index: int = 0
	for entry: Variant in (look["lamps"] as Array):
		var lamp: Dictionary = entry
		var base: Vector3 = BattleStageTuning.vec3_of(lamp["pos"])
		var height: float = float(lamp["height"])
		var color: Color = Color.html(str(lamp["color"]))
		var root: Node3D = Node3D.new()
		root.name = "Lamp%d" % index
		root.position = base
		root.add_to_group(GROUP_LAMP)
		var post: MeshInstance3D = MeshInstance3D.new()
		post.name = "Post"
		var post_mesh: BoxMesh = BoxMesh.new()
		post_mesh.size = Vector3(POST_WIDTH, height, POST_WIDTH)
		post.mesh = post_mesh
		post.position = Vector3(0.0, height / 2.0, 0.0)
		post.set_surface_override_material(0, _lit(post_texture, Vector2(1.0, height), LAMP_BODY_TINT, AFFINE_PROP))
		root.add_child(post)
		var bulb: MeshInstance3D = MeshInstance3D.new()
		bulb.name = "Bulb"
		var bulb_mesh: SphereMesh = SphereMesh.new()
		bulb_mesh.radius = BULB_RADIUS
		bulb_mesh.height = BULB_RADIUS * 2.0
		bulb_mesh.radial_segments = 8
		bulb_mesh.rings = 4
		bulb.mesh = bulb_mesh
		bulb.position = Vector3(0.0, height + BULB_RADIUS * 0.6, 0.0)
		var bulb_material: ShaderMaterial = _unlit(halo_texture, Color.html("#FFE08A"), 1.4)
		bulb.set_surface_override_material(0, bulb_material)
		root.add_child(bulb)
		var halo: MeshInstance3D = MeshInstance3D.new()
		halo.name = "Halo"
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(HALO_SIZE, HALO_SIZE)
		halo.mesh = quad
		halo.position = bulb.position + Vector3(0.0, 0.0, 0.1)
		var halo_material: StandardMaterial3D = StandardMaterial3D.new()
		halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		halo_material.albedo_texture = halo_texture
		halo_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		halo_material.no_depth_test = false
		halo_material.disable_fog = true
		halo.material_override = halo_material
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(halo)
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Light"
		light.light_color = color
		light.light_energy = float(lamp["energy"])
		light.omni_range = float(lamp["range"])
		light.position = Vector3(0.0, height - 0.2, 0.5)
		root.add_child(light)
		add_child(root)
		lamps.append(root)
		lights.append(light)
		index += 1


func _build_key_light() -> void:
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color.html(str(look["key_color"]))
	key.light_energy = float(look["key_energy"])
	var angles: Array = look["key_dir_deg"]
	key.rotation_degrees = Vector3(float(angles[0]), float(angles[1]), 0.0)
	add_child(key)


func _lit(texture: Texture2D, uv_scale: Vector2, tint: Color, affine: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _lit_shader
	material.set_shader_parameter(&"albedo_texture", texture)
	material.set_shader_parameter(&"uv_scale", uv_scale)
	material.set_shader_parameter(&"albedo_tint", tint)
	material.set_shader_parameter(&"affine_amount", affine)
	return material


func _unlit(texture: Texture2D, tint: Color, energy: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _unlit_shader
	material.set_shader_parameter(&"albedo_texture", texture)
	material.set_shader_parameter(&"uv_scale", Vector2(0.03, 0.03))
	material.set_shader_parameter(&"uv_offset", Vector2(0.5, 0.5))
	material.set_shader_parameter(&"albedo_tint", tint)
	material.set_shader_parameter(&"emission_energy", energy)
	return material
