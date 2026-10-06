extends SceneTree
## Quick look at Red prototypes D and E in the PSX screen (own check, not the shared contact-sheet
## capture). Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/check_red_proto_de.gd [-- d e]
## Writes builds/screenshots/proto_check_<letter>.png (3/4 view), proto_check_<letter>_front.png,
## _back.png and _side.png. builds/ is git-ignored.

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"
const MODEL_PATH: String = "res://art/placeholder/characters/red_prototypes/red_proto_%s.glb"
const OUTPUT_PATH: String = "res://../builds/screenshots/proto_check_%s%s.png"
const LETTERS: PackedStringArray = ["d", "e"]
## View name, suffix, camera yaw around Red in degrees (0 = looking at her face), pitch down.
const VIEWS: Array = [["34", "", 35.0], ["front", "_front", 0.0], ["side", "_side", 90.0], ["back", "_back", 180.0]]
## Close-up of the face, neutral then grin (the face material's uv_offset swaps the cell).
const FACE_VIEWS: Array = [["face", "_face", 0.0], ["grin", "_grin", 0.0]]
const FACE_LOOK_AT: Vector3 = Vector3(0.0, 0.78, 0.0)
const FACE_DISTANCE: float = 1.1
const GRIN_OFFSETS: Dictionary = {"d": Vector2(32.0 / 128.0, 0.0), "e": Vector2(0.5, 0.0)}
const INGAME_FOV: float = 20.0
const INGAME_DISTANCE: float = 16.1
const INGAME_PITCH: float = 42.0
const CHALK: Color = Color(0.929, 0.918, 0.847)
const SILHOUETTE_FLOOR: Color = Color(0.72, 0.70, 0.64)
const INK: Color = Color(0.078, 0.071, 0.122)
const CAMERA_DISTANCE: float = 3.1
const CAMERA_FOV: float = 30.0
const LOOK_AT: Vector3 = Vector3(0.0, 0.58, 0.0)
const PITCH_DEGREES: float = 12.0
const SETTLE_FRAMES: int = 6
const NIGHT: Color = Color(0.122, 0.145, 0.251)
const DUSK: Color = Color(0.227, 0.208, 0.4)
const LAMP_AMBER: Color = Color(1.0, 0.82, 0.55)
const COOL_FILL: Color = Color(0.55, 0.65, 0.95)


func _initialize() -> void:
	var screen: Node = (load(SCREEN_SCENE) as PackedScene).instantiate()
	root.add_child(screen)
	for i: int in SETTLE_FRAMES:
		await process_frame
	var world: Node3D = screen.get_world_root()
	_build_stage(world)
	var letters: PackedStringArray = LETTERS
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not user_args.is_empty():
		letters = user_args
	var camera: Camera3D = world.get_node("Camera") as Camera3D
	for letter: String in letters:
		var model: Node3D = (load(MODEL_PATH % letter) as PackedScene).instantiate() as Node3D
		world.add_child(model)
		for view: Array in VIEWS:
			_aim(camera, float(view[2]))
			for i: int in SETTLE_FRAMES:
				await process_frame
			var image: Image = root.get_texture().get_image()
			var rect: Rect2 = screen.get_display_rect()
			image = image.get_region(Rect2i(rect))
			var path: String = OUTPUT_PATH % [letter, str(view[1])]
			print("saved %s %s err %d" % [path, image.get_size(), image.save_png(path)])
		for view: Array in FACE_VIEWS:
			_set_grin(model, letter, view[0] == "grin")
			_aim(camera, float(view[2]), FACE_LOOK_AT, FACE_DISTANCE)
			for i: int in SETTLE_FRAMES:
				await process_frame
			var image: Image = root.get_texture().get_image()
			image = image.get_region(Rect2i(screen.get_display_rect()))
			var path: String = OUTPUT_PATH % [letter, str(view[1])]
			print("saved %s %s err %d" % [path, image.get_size(), image.save_png(path)])
		await _ingame_shots(screen, camera, model, letter)
		model.queue_free()
		await process_frame
	quit(0)


## The true in-game size: diorama camera (42 degrees down, about 38 px per unit at 384x216), in
## color, in grayscale, and as a solid-Ink silhouette on a light backdrop.
func _ingame_shots(screen: Node, camera: Camera3D, model: Node3D, letter: String) -> void:
	camera.fov = INGAME_FOV
	_aim(camera, 20.0, LOOK_AT, INGAME_DISTANCE, INGAME_PITCH)
	var shots: Array = [["_ingame", false, false], ["_ingame_gray", true, false], ["_ingame_silhouette", false, true]]
	for shot: Array in shots:
		_silhouette(model, bool(shot[2]))
		for i: int in SETTLE_FRAMES:
			await process_frame
		var image: Image = root.get_texture().get_image()
		image = image.get_region(Rect2i(screen.get_display_rect()))
		if bool(shot[1]):
			image.convert(Image.FORMAT_L8)
			image.convert(Image.FORMAT_RGB8)
		var path: String = OUTPUT_PATH % [letter, str(shot[0])]
		print("saved %s err %d" % [path, image.save_png(path)])
	_silhouette(model, false)
	camera.fov = CAMERA_FOV


func _silhouette(model: Node, on: bool) -> void:
	var world_env: WorldEnvironment = root.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment
	world_env.environment.background_color = CHALK if on else NIGHT
	var floor_node: MeshInstance3D = root.find_children("Floor", "MeshInstance3D", true, false)[0] as MeshInstance3D
	(floor_node.mesh.material as StandardMaterial3D).albedo_color = SILHOUETTE_FLOOR if on else DUSK
	var ink_material: StandardMaterial3D = StandardMaterial3D.new()
	ink_material.albedo_color = INK
	ink_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh_instance: Node in model.find_children("*", "MeshInstance3D", true, false):
		(mesh_instance as MeshInstance3D).material_override = ink_material if on else null


## Moves the face material's uv_offset to the grin cell (or back to neutral).
func _set_grin(model: Node, letter: String, grin: bool) -> void:
	for mesh_instance: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mesh_instance as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var material: ShaderMaterial = mesh.surface_get_material(surface) as ShaderMaterial
			if material != null and material.resource_name.contains("_face"):
				material.set_shader_parameter("uv_offset", GRIN_OFFSETS[letter] if grin else Vector2.ZERO)


func _aim(camera: Camera3D, yaw_degrees: float, look_at: Vector3 = LOOK_AT, distance: float = CAMERA_DISTANCE, pitch_degrees: float = PITCH_DEGREES) -> void:
	var yaw: float = deg_to_rad(yaw_degrees)
	var pitch: float = deg_to_rad(pitch_degrees)
	var offset: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.position = look_at + offset
	camera.look_at(look_at)


func _build_stage(world: Node3D) -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = NIGHT
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.43, 0.6)
	environment.ambient_light_energy = 1.0
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = environment
	world.add_child(world_env)
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera"
	camera.fov = CAMERA_FOV
	camera.current = true
	world.add_child(camera)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.light_color = LAMP_AMBER
	key.light_energy = 1.0
	key.rotation_degrees = Vector3(-45.0, -35.0, 0.0)   # from front-left above
	world.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.light_color = COOL_FILL
	fill.light_energy = 0.3
	fill.rotation_degrees = Vector3(-20.0, 145.0, 0.0)  # from back-right
	world.add_child(fill)
	var floor_mesh: CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = 1.4
	floor_mesh.bottom_radius = 1.4
	floor_mesh.height = 0.04
	floor_mesh.radial_segments = 24
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = DUSK
	floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material = floor_material
	var floor_node: MeshInstance3D = MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.name = "Floor"
	floor_node.position = Vector3(0.0, -0.02, 0.0)
	world.add_child(floor_node)
