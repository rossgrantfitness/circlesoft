extends SceneTree
## Screenshots of the combat sandbox's look for Ross (real renderer, not headless):
##   red     Red posed in six key attack poses, sword in hand, in the PS2 look (docs/screenshots/sandbox_red_rigged.png)
##   swords  all six swords, split and labelled (docs/screenshots/sandbox_swords.png)
##   wolf    Red and the Cyberwolf Sentinel side by side, the wolf mid wind-up (docs/screenshots/sandbox_cyberwolf_rigged.png)
##   enemies the placeholder Grunt and Brute next to Red (a fallback check)
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_sandbox.gd -- --shot=red --out=/some/dir [--profile=grim_ps2|grim]
##
## It builds its own little stage inside the real PsxScreen (so the 640x360 picture, the grade and the glow are what the
## game shows): a tiled floor and wall from Ross's city tiles, one shadow-casting key light, two lamps, a Ps2Look node.
## No game classes are named here (this file compiles before the autoloads exist); everything goes through load().

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"
const PS2_LOOK: String = "res://scripts/core/ps2_look.gd"
const LOOK_PROFILES: String = "res://scripts/core/look_profiles.gd"
const GEAR: String = "res://scripts/combat/gear_visuals.gd"
const FLOOR_TILE: String = "res://art/final/textures/city/tiles_busted/floor_diamond_plate_rust.png"
const WALL_TILE: String = "res://art/final/textures/city/tiles_busted/rust_panel_strips_riveted.png"
const RED: String = "res://art/final/characters/red/red_ross_v1_rigged.glb"
const WOLF: String = "res://art/final/enemies/cyberwolf_sentinel_rigged.glb"
const GRUNT: String = "res://art/placeholder/enemies/sandbox_grunt/enm_sandbox_grunt.glb"
const BRUTE: String = "res://art/placeholder/enemies/sandbox_brute/enm_sandbox_brute.glb"
const SWORD_DIR: String = "res://art/final/weapons/"
const SWORDS: Array[String] = ["katana_cyan", "heavy_duty", "hook_cyan", "glass_core", "machete", "twin_orange"]
const SWORD_FILES: Dictionary = {"katana_cyan": "sword_katana_cyan", "heavy_duty": "sword_heavy_duty", "hook_cyan": "sword_hook_cyan",
		"glass_core": "sword_glass_core", "machete": "sword_machete", "twin_orange": "sword_twin_orange"}
const SWORD_NAMES: Dictionary = {"katana_cyan": "Cyan katana", "heavy_duty": "Heavy Duty cleaver", "hook_cyan": "Cyan hook-blade",
		"glass_core": "Glass-core sword", "machete": "Dark machete", "twin_orange": "Orange twin-prong blade"}
## clip, key frame, label
const RED_POSES: Array = [["light_1", 2, "light 1"], ["light_2", 2, "light 2"], ["light_3", 2, "light 3 (thrust)"],
		["heavy", 5, "heavy"], ["launcher", 3, "launcher"], ["air_3", 4, "air 3 (air pose)"]]
const SETTLE_FRAMES: int = 12

var _out: String = "/tmp"
var _shot: String = "red"
var _profile_id: String = "grim_ps2"
var _screen: Node = null
var _world: Node3D = null
var _camera: Camera3D = null
var _look: GDScript = null
var _ps2: GDScript = null
var _labels: Array[Label] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--profile="):
			_profile_id = arg.trim_prefix("--profile=")
	await process_frame
	_look = load(LOOK_PROFILES) as GDScript
	_ps2 = load(PS2_LOOK) as GDScript
	_screen = (load(SCREEN_SCENE) as PackedScene).instantiate()
	root.add_child(_screen)
	await _settle(2)
	_world = _screen.call("get_world_root") as Node3D
	_build_stage()
	var shots: Array[String] = ["red", "swords", "wolf", "enemies"] if _shot == "all" else [_shot]
	for shot: String in shots:
		_clear_actors()
		match shot:
			"red":
				_shot_red()
			"swords":
				_shot_swords()
			"wolf":
				_shot_wolf()
			"enemies":
				_shot_enemies()
		await _settle(SETTLE_FRAMES)
		_save(shot)
	quit(0)


# ---- the stage ----

func _build_stage() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#14172a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#59607a")
	environment.ambient_light_energy = 0.9
	var holder: WorldEnvironment = WorldEnvironment.new()
	holder.name = "WorldEnvironment"
	holder.environment = environment
	_world.add_child(holder)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color("#ffd9b0")
	key.light_energy = 1.0
	key.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	_world.add_child(key)
	for lamp: Array in [[Vector3(-3.5, 2.6, -2.5), Color("#ffb347"), 2.2], [Vector3(3.5, 2.6, -1.5), Color("#4fd8ff"), 1.8]]:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = lamp[0]
		light.light_color = lamp[1]
		light.light_energy = lamp[2]
		light.omni_range = 9.0
		_world.add_child(light)
	_build_surface("Floor", Vector3(0.0, 0.0, 0.0), Vector3(40.0, 0.1, 40.0), FLOOR_TILE, Vector2(20.0, 20.0))
	_build_surface("Wall", Vector3(0.0, 3.0, -5.0), Vector3(30.0, 6.0, 0.4), WALL_TILE, Vector2(15.0, 3.0))
	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.current = true
	_world.add_child(_camera)
	_ps2_node()


func _ps2_node() -> void:
	var node: Node = _ps2.new() as Node
	node.name = "Ps2Look"
	_world.add_child(node)
	_look.call("set_forced", _profile_id)


func _build_surface(node_name: String, center: Vector3, size: Vector3, tile: String, tiling: Vector2) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = node_name
	body.mesh = mesh
	var profile: Dictionary = _look.call("profile", "grim_ps2")
	var material: ShaderMaterial = _ps2.call("make_material", load(tile), "city_tiles", profile)
	material.set_shader_parameter(&"uv_scale", tiling)
	material.set_shader_parameter(&"use_orm", 0.0)
	body.material_override = material
	body.position = center - Vector3(0.0, size.y * 0.5 if node_name == "Floor" else 0.0, 0.0)
	_world.add_child(body)


func _clear_actors() -> void:
	for child: Node in _world.get_children():
		if child.has_meta(&"actor"):
			_world.remove_child(child)
			child.queue_free()
	for label: Label in _labels:
		label.queue_free()
	_labels.clear()


# ---- actors ----

func _spawn(path: String, role: String, position: Vector3, yaw_deg: float) -> Node3D:
	var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	model.set_meta(&"actor", true)
	model.position = position
	model.rotation_degrees.y = yaw_deg
	_world.add_child(model)
	var profile: Dictionary = _look.call("profile", _profile_id)
	_ps2.call("upgrade_model", model, path, profile)
	_look.call("dress_model", model, path, role)
	return model


func _pose(model: Node3D, clip: String, frame: int) -> void:
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.play(clip)
	player.seek(float(frame) / 15.0, true)
	player.pause()


func _sword_on(model: Node3D, sword: String) -> void:
	var gear: Node = (load(GEAR) as GDScript).new() as Node
	gear.name = "GearVisuals"
	model.add_child(gear)
	gear.call("equip_sword", StringName(sword))
	var sword_node: Node3D = gear.call("get_sword") as Node3D
	var profile: Dictionary = _look.call("profile", _profile_id)
	_ps2.call("upgrade_model", sword_node, SWORD_DIR + String(SWORD_FILES[sword]) + ".glb", profile)


func _shot_red() -> void:
	var count: int = RED_POSES.size()
	for index: int in count:
		var spec: Array = RED_POSES[index]
		var x: float = (float(index) - float(count - 1) * 0.5) * 1.15
		var model: Node3D = _spawn(RED, "player", Vector3(x, 0.0, 0.0), 0.0)
		_sword_on(model, SWORDS[index % 2] if false else "katana_cyan")
		_pose(model, str(spec[0]), int(spec[1]))
		if str(spec[0]).begins_with("air"):
			model.position.y = 0.45
		_add_label(str(spec[2]), Vector3(x, -0.18, 0.0))
	_aim(Vector3(0.0, 1.9, 7.0), Vector3(0.0, 0.5, 0.0))


func _shot_swords() -> void:
	var profile: Dictionary = _look.call("profile", _profile_id)
	var count: int = SWORDS.size()
	for index: int in count:
		var id: String = SWORDS[index]
		var x: float = (float(index) - float(count - 1) * 0.5) * 0.95
		var path: String = SWORD_DIR + String(SWORD_FILES[id]) + ".glb"
		var sword: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		sword.set_meta(&"actor", true)
		sword.position = Vector3(x, 0.82, 0.0)
		sword.rotation_degrees = Vector3(0.0, -22.0, 0.0)
		_world.add_child(sword)
		_ps2.call("upgrade_model", sword, path, profile)
		_add_label(str(SWORD_NAMES[id]), Vector3(x, 0.0, 0.0))
	_aim(Vector3(0.0, 1.0, 6.4), Vector3(0.0, 0.8, 0.0))


func _shot_wolf() -> void:
	var red: Node3D = _spawn(RED, "player", Vector3(-1.0, 0.0, 0.0), 90.0)
	_sword_on(red, "katana_cyan")
	_pose(red, "idle", 0)
	var wolf: Node3D = _spawn(WOLF, "enemy", Vector3(1.1, 0.0, 0.0), -90.0)
	_pose(wolf, "attack_windup", 4)
	_add_label("Red  (0.95 m)", Vector3(-1.0, -0.18, 0.0))
	_add_label("Cyberwolf Sentinel  (1.19 m), wind-up", Vector3(1.1, -0.18, 0.0))
	_aim(Vector3(0.6, 1.4, 5.6), Vector3(0.05, 0.62, 0.0))


func _shot_enemies() -> void:
	var red: Node3D = _spawn(RED, "player", Vector3(-1.6, 0.0, 0.0), 20.0)
	_sword_on(red, "katana_cyan")
	_pose(red, "idle", 0)
	var grunt: Node3D = _spawn(GRUNT, "enemy", Vector3(0.0, 0.0, 0.0), -10.0)
	_pose(grunt, "attack_windup", 4)
	var brute: Node3D = _spawn(BRUTE, "enemy", Vector3(1.8, 0.0, 0.0), -20.0)
	_pose(brute, "attack_windup", 4)
	_add_label("Red", Vector3(-1.6, -0.18, 0.0))
	_add_label("Grunt blockout (fallback)", Vector3(0.0, -0.18, 0.0))
	_add_label("Brute blockout", Vector3(1.8, -0.18, 0.0))
	_aim(Vector3(0.0, 1.5, 6.0), Vector3(0.0, 0.6, 0.0))


func _aim(from: Vector3, at: Vector3) -> void:
	_camera.position = from
	_camera.look_at(at, Vector3.UP)


func _add_label(text: String, world_position: Vector3) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 15)
	label.add_theme_color_override(&"font_color", Color("#f3e9d0"))
	label.add_theme_color_override(&"font_outline_color", Color("#14121f"))
	label.add_theme_constant_override(&"outline_size", 5)
	label.set_meta(&"world", world_position)
	(_screen.call("get_ui_layer") as CanvasLayer).add_child(label)
	_labels.append(label)


func _place_labels() -> void:
	var scale: float = float(_screen.call("get_display_scale"))
	var origin: Vector2 = (_screen.call("get_display_rect") as Rect2).position
	for label: Label in _labels:
		var world_position: Vector3 = label.get_meta(&"world")
		var pixel: Vector2 = _camera.unproject_position(world_position) * scale + origin
		label.position = pixel - Vector2(label.size.x * 0.5, 0.0)


func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame
		_place_labels()


func _save(shot: String) -> void:
	var names: Dictionary = {"red": "sandbox_red_rigged", "swords": "sandbox_swords", "wolf": "sandbox_cyberwolf_rigged", "enemies": "sandbox_enemies_blockout"}
	var image: Image = root.get_viewport().get_texture().get_image()
	var path: String = "%s/%s%s.png" % [_out, names.get(shot, "sandbox_" + shot), "" if _profile_id == "grim_ps2" else "_" + _profile_id]
	print("saved ", path, " ", image.get_size(), " error ", image.save_png(path))
