extends Node3D
## Graybox slum alley for judging Ross's city texture packs (2026-10-08) at the PS2 step 1 look.
## Scene: scenes/tests/city_texture_test.tscn. It builds itself from data/world/city_texture_atlas.json.
## Set the three options BEFORE adding the scene to the tree (or call build() again after changing them):
##   variant_mode  "clean", "busted" or "mixed" (a fixed set of pieces is busted, see MIXED_BUSTED)
##   filter_mode   "nearest" (crisp pixel art) or "smooth" (linear filtering + mipmaps)
##   seamless_copies  true = use the seam-fixed copies (tiles_seamless/, tiles_busted_seamless/) where the atlas has one
##   camera_preset "alley" (down the alley), "right_wall" or "left_wall" (face-on detail views)
##   texels_per_m  128.0 = one 128 px tile covers 1 m (the starting density); 64.0 = chunkier, 2 m per tile
## Scale: the capsule is 1.0 m tall (a placeholder for Red). Walls are 3 m high, the alley 5 m wide.
## It uses engine nodes only; every texture comes from Ross's tiles, nothing is painted here.

const ATLAS_PATH: String = "res://data/world/city_texture_atlas.json"
const SEAMLESS_DIRS: Dictionary = {"clean": "res://art/final/textures/city/tiles_seamless/",
	"busted": "res://art/final/textures/city/tiles_busted_seamless/"}
const ALLEY_HALF_WIDTH: float = 2.5
const ALLEY_FRONT_Z: float = 1.0
const ALLEY_BACK_Z: float = -9.0
const WALL_HEIGHT: float = 3.0

## Pieces that switch to the busted look when variant_mode is "mixed".
const MIXED_BUSTED: PackedStringArray = ["floor_base", "wall_left_far", "atm", "wall_screen_green", "generator_dynamo",
	"door_chevron", "wall_end", "vent_hatch"]

var variant_mode: String = "clean"
var filter_mode: String = "nearest"
var texels_per_m: float = 128.0
var camera_preset: String = "alley"
var seamless_copies: bool = false

var _variants: Dictionary = {}
var _textures: Dictionary = {}
var _built: bool = false
var _seamless_ids: Dictionary = {}


func _ready() -> void:
	if not _built:
		build()


func build() -> void:
	for child: Node in get_children():
		child.queue_free()
		remove_child(child)
	_textures.clear()
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_PATH)) as Dictionary
	_variants = atlas["variants"]
	_seamless_ids.clear()
	for tile: Dictionary in atlas["tiles"]:
		_seamless_ids["clean/" + String(tile["id"])] = bool(tile.get("seamless_copy", false))
		_seamless_ids["busted/" + String(tile["id"])] = bool(tile.get("seamless_copy_busted", false))
	_built = true
	_build_environment()
	_build_lights()
	_build_camera()
	_build_floor()
	_build_walls()
	_build_props()
	_build_scale_capsule()


# ---- textures and materials ----

func _variant_for(piece: String) -> String:
	match variant_mode:
		"busted":
			return "busted"
		"mixed":
			return "busted" if MIXED_BUSTED.has(piece) else "clean"
	return "clean"


func _texture(tile_id: String, variant: String) -> ImageTexture:
	var key: String = variant + "/" + tile_id
	if _textures.has(key):
		return _textures[key]
	var dir: String = String((_variants[variant] as Dictionary)["tile_dir"])
	if seamless_copies and _seamless_ids.get(key, false):
		dir = String(SEAMLESS_DIRS[variant])
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(dir.path_join(tile_id + ".png")))
	if filter_mode == "smooth":
		image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture


func _material(piece: String, tile_id: String, size_m: Vector2, repeat: bool, emissive: float = 0.0) -> StandardMaterial3D:
	var texture: ImageTexture = _texture(tile_id, _variant_for(piece))
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.85
	material.metallic_specular = 0.25
	material.texture_repeat = true
	if filter_mode == "smooth":
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if repeat:
		material.uv1_scale = Vector3(size_m.x * texels_per_m / float(texture.get_width()),
			size_m.y * texels_per_m / float(texture.get_height()), 1.0)
	if emissive > 0.0:
		material.emission_enabled = true
		material.emission_texture = texture
		material.emission_energy_multiplier = emissive
	return material


## A flat quad. Quads face +Z by default; basis turns them onto a wall or the floor.
func _quad(piece: String, tile_id: String, center: Vector3, basis: Basis, size_m: Vector2, repeat: bool,
		emissive: float = 0.0) -> MeshInstance3D:
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = size_m
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = piece
	instance.mesh = mesh
	instance.material_override = _material(piece, tile_id, size_m, repeat, emissive)
	instance.transform = Transform3D(basis, center)
	add_child(instance)
	return instance


func _tile_size_m(tile_id: String) -> Vector2:
	var texture: ImageTexture = _texture(tile_id, "clean")
	return Vector2(texture.get_width(), texture.get_height()) / texels_per_m


# ---- orientation helpers ----

func _facing_east() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(90.0))


func _facing_west() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(-90.0))


func _facing_south() -> Basis:
	return Basis.IDENTITY


func _facing_up() -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(-90.0))


# ---- the set ----

func _build_floor() -> void:
	var length: float = ALLEY_FRONT_Z - ALLEY_BACK_Z
	var center_z: float = (ALLEY_FRONT_Z + ALLEY_BACK_Z) * 0.5
	_quad("floor_base", "floor_concrete_cracked_dark", Vector3(0.0, 0.0, center_z), _facing_up(),
		Vector2(ALLEY_HALF_WIDTH * 2.0, length), true)
	# a red mesh runway down the middle and a hazard band across the far end
	_quad("floor_runway", "floor_mesh_red_a", Vector3(0.0, 0.01, -2.0), _facing_up(), Vector2(1.0, 6.0), true)
	_quad("floor_hazard", "floor_concrete_hazard_stripe_a", Vector3(0.0, 0.01, -7.0), _facing_up(),
		Vector2(ALLEY_HALF_WIDTH * 2.0, 2.0), true)


func _build_walls() -> void:
	var mid_y: float = WALL_HEIGHT * 0.5
	# left wall, faces east
	_quad("wall_left_near", "rust_panel_strips_riveted", Vector3(-ALLEY_HALF_WIDTH, mid_y, -1.75), _facing_east(),
		Vector2(5.5, WALL_HEIGHT), true)
	_quad("wall_left_far", "steel_plate_riveted_grey", Vector3(-ALLEY_HALF_WIDTH, mid_y, -6.75), _facing_east(),
		Vector2(4.5, WALL_HEIGHT), true)
	# right wall, faces west
	_quad("wall_right_near", "teal_circuit_board_chip", Vector3(ALLEY_HALF_WIDTH, mid_y, -1.0), _facing_west(),
		Vector2(4.0, WALL_HEIGHT), true)
	_quad("wall_right_far", "rust_riveted_plates_tall", Vector3(ALLEY_HALF_WIDTH, mid_y, -6.0), _facing_west(),
		Vector2(6.0, WALL_HEIGHT), true)
	# end wall, faces the camera
	_quad("wall_end", "rust_riveted_plates_tall", Vector3(0.0, mid_y, ALLEY_BACK_Z), _facing_south(),
		Vector2(ALLEY_HALF_WIDTH * 2.0, WALL_HEIGHT), true)


func _build_props() -> void:
	var lx: float = -ALLEY_HALF_WIDTH + 0.02
	var rx: float = ALLEY_HALF_WIDTH - 0.02
	# left wall: a wall screen, a pipe run, then the two generators standing against the far run
	_quad("wall_screen_green", "wall_screen_green_terminal", Vector3(lx, 1.7, -1.5), _facing_east(),
		_tile_size_m("wall_screen_green_terminal"), false, 1.3)
	_quad("pipes_trim", "pipes_on_black_vertical", Vector3(lx, 1.5, -3.2), _facing_east(),
		Vector2(1.0, WALL_HEIGHT), true)
	_box_prop("generator_dynamo", "generator_dynamo_front", Vector3(-ALLEY_HALF_WIDTH, 0.0, -6.2), _facing_east(), 0.35)
	_box_prop("generator_plasma", "generator_plasma_cell_front", Vector3(-ALLEY_HALF_WIDTH, 0.0, -7.4), _facing_east(), 0.35)
	# right wall: terminal, door, signs, second door
	_box_prop("atm", "atm_grey_terminal", Vector3(ALLEY_HALF_WIDTH, 0.0, -2.0), _facing_west(), 0.3)
	_quad("sign_green_katakana", "sign_garbled_green_katakana", Vector3(rx, 1.9, -5.3), _facing_west(),
		_tile_size_m("sign_garbled_green_katakana"), false, 0.6)
	_quad("door_chevron", "door_plated_chevron", Vector3(rx, 0.75, -3.8), _facing_west(),
		_tile_size_m("door_plated_chevron"), false)
	_quad("sign_indoors_only", "sign_indoors_only_katakana", Vector3(rx, 1.95, -3.8), _facing_west(),
		_tile_size_m("sign_indoors_only_katakana"), false, 1.0)
	_quad("sign_chikagate", "sign_chikagate_emblem_plate", Vector3(rx, 1.3, -6.4), _facing_west(),
		_tile_size_m("sign_chikagate_emblem_plate"), false, 0.5)
	_quad("door_skull", "door_skull", Vector3(rx, 0.75, -7.8), _facing_west(), _tile_size_m("door_skull"), false)
	# end wall: a blue screen, a vault hatch, a vent, the teal terminal
	_quad("wall_screen_blue", "wall_screen_blue_wide", Vector3(-0.6, 1.9, ALLEY_BACK_Z + 0.02), _facing_south(),
		_tile_size_m("wall_screen_blue_wide"), false, 1.3)
	_quad("vent_hatch", "vault_hatch_round", Vector3(0.7, 0.5, ALLEY_BACK_Z + 0.02), _facing_south(),
		_tile_size_m("vault_hatch_round"), false)
	_box_prop("terminal_teal", "terminal_teal_keypad", Vector3(1.6, 0.0, ALLEY_BACK_Z), _facing_south(), 0.3)


## A dark box (so it throws a real shadow) with Ross's tile on its front face. base is on the floor.
func _box_prop(piece: String, tile_id: String, base: Vector3, basis: Basis, depth: float) -> void:
	var size: Vector2 = _tile_size_m(tile_id)
	var normal: Vector3 = basis * Vector3.FORWARD * -1.0
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(size.x, size.y, depth)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = piece + "_body"
	body.mesh = box
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.09, 0.1, 0.1)
	dark.roughness = 0.9
	body.material_override = dark
	body.transform = Transform3D(basis, base + Vector3(0.0, size.y * 0.5, 0.0) + normal * (depth * 0.5))
	add_child(body)
	_quad(piece, tile_id, base + Vector3(0.0, size.y * 0.5, 0.0) + normal * (depth + 0.005), basis, size, false,
		0.35 if piece.begins_with("terminal") or piece == "atm" else 0.0)


func _build_scale_capsule() -> void:
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.2
	capsule.height = 1.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.84, 0.8)
	material.roughness = 0.7
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "scale_capsule_1m"
	instance.mesh = capsule
	instance.material_override = material
	instance.position = Vector3(0.5, 0.5, -3.2)
	add_child(instance)


# ---- light, camera, environment ----

func _build_environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.06, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.36, 0.45, 0.46)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 0.85
	environment.fog_enabled = true
	environment.fog_light_color = Color("2a2c24")
	environment.fog_density = 0.035
	var holder: WorldEnvironment = WorldEnvironment.new()
	holder.environment = environment
	add_child(holder)


func _build_lights() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "key_light"
	sun.light_color = Color(1.0, 0.85, 0.62)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 25.0
	sun.rotation_degrees = Vector3(-48.0, 38.0, 0.0)
	add_child(sun)
	var teal: OmniLight3D = OmniLight3D.new()
	teal.name = "lamp_teal"
	teal.light_color = Color(0.37, 0.88, 0.78)
	teal.light_energy = 2.0
	teal.omni_range = 5.0
	teal.position = Vector3(-1.2, 2.0, -1.6)
	add_child(teal)
	var amber: OmniLight3D = OmniLight3D.new()
	amber.name = "lamp_amber"
	amber.light_color = Color(1.0, 0.6, 0.25)
	amber.light_energy = 2.4
	amber.omni_range = 6.0
	amber.position = Vector3(1.6, 2.4, -4.6)
	add_child(amber)


func _build_camera() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.name = "camera"
	camera.fov = 62.0
	camera.current = true
	add_child(camera)
	match camera_preset:
		"right_wall":
			camera.position = Vector3(-1.8, 1.4, -5.0)
			camera.look_at(Vector3(ALLEY_HALF_WIDTH, 1.3, -5.0))
		"left_wall":
			camera.position = Vector3(1.8, 1.4, -4.5)
			camera.look_at(Vector3(-ALLEY_HALF_WIDTH, 1.4, -4.5))
		_:
			camera.position = Vector3(0.7, 1.45, 3.8)
			camera.look_at(Vector3(-0.3, 1.2, -6.0))
