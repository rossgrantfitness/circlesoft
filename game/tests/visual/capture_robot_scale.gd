extends SceneTree
## Screenshots of the giant-robot scale test blockouts (task CS-21), in the real renderer with the grim_ps2 look:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_robot_scale.gd -- --shot=lineup|dock|poses_small|poses_huge --out=/some/dir
## lineup: Red, the small robot, the huge robot and the scale props, one wide shot with a close-up inset (robots_scale_lineup.png).
## dock: the huge robot with its chest bay open and the small robot standing in it (robots_dock_bay.png).
## poses_small / poses_huge: a contact sheet of the retargeted clips (robots_<size>_poses.png).
## No game classes are named here (this file compiles before the autoloads exist); everything goes through load().

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"
const PS2_LOOK: String = "res://scripts/core/ps2_look.gd"
const LOOK_PROFILES: String = "res://scripts/core/look_profiles.gd"
const GEAR: String = "res://scripts/combat/gear_visuals.gd"
const DUST: String = "res://scripts/combat/fx/scale_dust.gd"
const FLOOR_TILE: String = "res://art/final/textures/city/tiles_busted/floor_concrete_panel_bevel.png"
const SWORD_FILE: String = "res://art/final/weapons/sword_katana_cyan.glb"
const RED: String = "res://art/final/characters/red/red_ross_v1_rigged_ual.glb"
const SMALL: String = "res://art/placeholder/robots/robot_small_ual.glb"
const HUGE: String = "res://art/placeholder/robots/robot_huge_ual.glb"
const PROP_DIR: String = "res://art/placeholder/robots/props/"
const GAME_BOX: Rect2i = Rect2i(64, 36, 1152, 648)
const SETTLE_FRAMES: int = 10

var _out: String = "/tmp"
var _shot: String = "lineup"
var _screen: Node = null
var _world: Node3D = null
var _camera: Camera3D = null
var _look: GDScript = null
var _ps2: GDScript = null
var _labels: Array[Label] = []
var _key: DirectionalLight3D = null


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
	await process_frame
	_look = load(LOOK_PROFILES) as GDScript
	_ps2 = load(PS2_LOOK) as GDScript
	_screen = (load(SCREEN_SCENE) as PackedScene).instantiate()
	root.add_child(_screen)
	await _settle(2)
	_world = _screen.call("get_world_root") as Node3D
	_build_stage()
	match _shot:
		"lineup":
			await _lineup()
		"dock":
			await _dock()
		"dust":
			await _dust()
		"poses_small":
			await _poses(SMALL, "robots_small_poses", 3.5, [["idle", 0.5], ["run", 0.1], ["light_1", "c"], ["light_2", "c"], ["light_3", "c"], ["parry", "c"], ["hurt", "c"], ["dash", 0.2], ["heavy", "c"], ["knockdown", 0.4]], "res://data/animation/robot_small_clip_keys.json")
		"poses_huge":
			await _poses(HUGE, "robots_huge_poses", 50.0, [["idle", 0.5], ["run", 0.1], ["light_1", "c"], ["light_2", "c"], ["light_3", "c"], ["parry", "c"], ["hurt", "c"], ["dash", 0.2], ["heavy", "c"], ["knockdown", 0.4]], "res://data/animation/robot_huge_clip_keys.json")
	quit(0)


# ---- shots ----

func _lineup() -> void:
	var huge: Node3D = _model(HUGE, Vector3(0.0, 0.0, 0.0), "enemy")
	var small: Node3D = _model(SMALL, Vector3(-2.2, 0.0, 15.0), "party")
	var red: Node3D = _model(RED, Vector3(-7.0, 0.0, 15.0), "party")
	_gear(red)
	_fog(200.0, 1200.0)
	_prop("prop_crate_small", Vector3(-5.2, 0.0, 15.2), 20.0)
	_prop("prop_crate_large", Vector3(-10.8, 0.0, 16.0), -15.0)
	_prop("prop_lamp_post", Vector3(5.0, 0.0, 13.0), 0.0)
	_prop("prop_car_block", Vector3(11.0, 0.0, 16.0), 90.0)
	_prop("prop_cargo_container", Vector3(-19.0, 0.0, 14.0), 80.0)
	_prop("prop_building_10m", Vector3(-34.0, 0.0, -30.0), 0.0)
	_prop("prop_building_20m", Vector3(-58.0, 0.0, -14.0), 0.0)
	_prop("prop_building_30m", Vector3(40.0, 0.0, -12.0), 0.0)
	_prop("prop_building_10m", Vector3(62.0, 0.0, -4.0), 0.0)
	_prop("prop_lamp_post", Vector3(24.0, 0.0, 12.0), 0.0)
	_prop("prop_lamp_post", Vector3(-26.0, 0.0, 10.0), 0.0)
	# a sodium lamp on each lamp post, and a footstep puff at the huge robot's feet to show the dust scale
	for x: float in [5.0, 24.0, -26.0]:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(x + 1.5, 6.2, 12.0)
		light.light_color = Color("#ff9a3c")
		light.light_energy = 2.2
		light.omni_range = 16.0
		_world.add_child(light)
	var dust: GDScript = load(DUST) as GDScript
	if dust != null:
		dust.call("spawn", _world, Vector3(5.8, 0.0, 8.5), &"step_huge")
		dust.call("spawn", _world, Vector3(-5.8, 0.0, 8.5), &"step_huge")
		dust.call("spawn", _world, Vector3(-4.0, 0.0, 15.0), &"step_small")
	_camera.fov = 40.0
	_camera.position = Vector3(8.0, 21.0, 110.0)
	_camera.look_at(Vector3(0.0, 22.0, 0.0), Vector3.UP)
	_label("HUGE  50 m", Vector3(0.0, 53.0, 0.0), &"main")
	_label("30 m", Vector3(40.0, 34.0, -12.0), &"main")
	_label("20 m", Vector3(-58.0, 24.0, -14.0), &"main")
	_label("10 m", Vector3(-34.0, 14.0, -30.0), &"main")
	_label("Red  0.95 m", Vector3(-7.0, 1.3, 15.0), &"inset")
	_label("small robot  3.5 m", Vector3(-2.2, 3.9, 15.0), &"inset")
	_label("crate  0.8 m", Vector3(-5.2, 1.0, 15.2), &"inset")
	_show_labels(&"main")
	await create_timer(0.5).timeout       # let the dust spread (real time)
	var main_image: Image = await _grab()
	# the close-up inset: Red, the small robot, crates, the car
	_show_labels(&"inset")
	_camera.fov = 40.0
	_camera.position = Vector3(-4.8, 2.0, 25.0)
	_camera.look_at(Vector3(-4.8, 1.7, 15.0), Vector3.UP)
	await _settle(SETTLE_FRAMES)
	var inset: Image = await _grab()
	inset.resize(main_image.get_width() * 4 / 10, main_image.get_height() * 4 / 10, Image.INTERPOLATE_LANCZOS)
	var frame: int = 4
	var pad: int = 14
	var origin: Vector2i = Vector2i(pad + frame, pad + frame)      # top left: the sky is empty there
	main_image.fill_rect(Rect2i(origin.x - frame, origin.y - frame, inset.get_width() + frame * 2, inset.get_height() + frame * 2), Color("#ffb347"))
	main_image.blit_rect(inset, Rect2i(Vector2i.ZERO, inset.get_size()), origin)
	_save(main_image, "robots_scale_lineup")


func _dust() -> void:
	_fog(200.0, 1200.0)
	var dust: GDScript = load(DUST) as GDScript
	for x: float in [-12.0, 0.0, 12.0]:
		dust.call("spawn", _world, Vector3(x, 0.0, 0.0), &"step_huge")
	_camera.position = Vector3(0.0, 8.0, 60.0)
	_camera.look_at(Vector3(0.0, 4.0, 0.0), Vector3.UP)
	await create_timer(0.6).timeout
	_save(await _grab(), "robots_dust_debug")


func _dock() -> void:
	var huge: Node3D = _model(HUGE, Vector3.ZERO, "enemy")
	_fog(200.0, 1200.0)
	var skeleton: Skeleton3D = huge.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	skeleton.set_bone_pose_rotation(skeleton.find_bone("dock_door_l"), Quaternion(Vector3.UP, deg_to_rad(105.0)))
	skeleton.set_bone_pose_rotation(skeleton.find_bone("dock_door_r"), Quaternion(Vector3.UP, deg_to_rad(-105.0)))
	var point: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("dock_point"))
	var small: Node3D = _model(SMALL, point.origin, "party")
	var small_skeleton: Skeleton3D = small.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var anchor: Vector3 = small_skeleton.global_transform * small_skeleton.get_bone_global_pose(small_skeleton.find_bone("dock_anchor")).origin
	small.global_position += point.origin - anchor
	_camera.fov = 40.0
	_camera.position = Vector3(11.0, 28.0, 34.0)
	_camera.look_at(Vector3(0.0, 27.0, 0.0), Vector3.UP)
	var bay_light: OmniLight3D = OmniLight3D.new()
	bay_light.position = point.origin + Vector3(0.0, 2.5, 3.0)
	bay_light.light_color = Color("#ffb347")
	bay_light.light_energy = 2.5
	bay_light.omni_range = 9.0
	_world.add_child(bay_light)
	_label("chest dock bay, doors open  (dock_point / dock_anchor)", Vector3(0.0, 40.0, 0.0), &"dock")
	_show_labels(&"dock")
	await _settle(SETTLE_FRAMES)
	_save(await _grab(), "robots_dock_bay")


func _poses(model_path: String, stem: String, height: float, poses: Array, keys_path: String) -> void:
	var model: Node3D = _model(model_path, Vector3.ZERO, "party")
	model.rotation_degrees.y = 55.0
	var contacts: Dictionary = _contacts(keys_path)
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var columns: int = 5
	var tile: Vector2i = Vector2i(330, 420)
	var rows: int = int(ceil(float(poses.size()) / columns))
	var sheet: Image = Image.create(tile.x * columns, tile.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#14172a"))
	_camera.fov = 38.0
	_fog(maxf(30.0, height * 4.0), maxf(150.0, height * 24.0))
	for index: int in poses.size():
		var clip: String = str(poses[index][0])
		var at: Variant = poses[index][1]
		var seconds: float = float(contacts.get(clip, 0.0)) if str(at) == "c" else float(at)
		player.play(clip)
		player.seek(seconds, true)
		player.pause()
		_camera.position = Vector3(0.0, height * 0.62, height * 3.3)
		_camera.look_at(Vector3(0.0, height * 0.5, 0.0), Vector3.UP)
		await _settle(SETTLE_FRAMES)
		var image: Image = await _grab()
		var crop: Rect2i = Rect2i(image.get_width() / 2 - tile.x / 2, image.get_height() / 2 - tile.y / 2 - 20, tile.x, tile.y)
		sheet.blit_rect(image, crop, Vector2i((index % columns) * tile.x, (index / columns) * tile.y))
		print("pose ", clip, " ", seconds)
	_save(sheet, stem)


# ---- building blocks ----

func _build_stage() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#1a1d2e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#59607a")
	environment.ambient_light_energy = 0.9
	var holder: WorldEnvironment = WorldEnvironment.new()
	holder.environment = environment
	_world.add_child(holder)
	_key = DirectionalLight3D.new()
	_key.light_color = Color("#ffd9b0")
	_key.light_energy = 1.35
	_key.rotation_degrees = Vector3(-38.0, 28.0, 0.0)
	_key.directional_shadow_max_distance = 260.0
	_world.add_child(_key)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(600.0, 0.2, 600.0)
	var floor_body: MeshInstance3D = MeshInstance3D.new()
	floor_body.mesh = mesh
	var material: ShaderMaterial = _ps2.call("make_material", load(FLOOR_TILE), "city_tiles", _look.call("profile", "grim_ps2"))
	material.set_shader_parameter(&"uv_scale", Vector2(150.0, 150.0))
	material.set_shader_parameter(&"use_orm", 0.0)
	floor_body.material_override = material
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	_world.add_child(floor_body)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.far = 800.0
	_camera.current = true
	_world.add_child(_camera)
	var node: Node = _ps2.new() as Node
	node.name = "Ps2Look"
	_world.add_child(node)
	_look.call("set_forced", "grim_ps2")


func _model(path: String, at: Vector3, role: String) -> Node3D:
	var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	model.position = at
	_world.add_child(model)
	_ps2.call("upgrade_model", model, path, _look.call("profile", "grim_ps2"))
	_look.call("dress_model", model, path, role)
	return model


func _gear(model: Node3D) -> void:
	var gear: Node = (load(GEAR) as GDScript).new() as Node
	gear.name = "GearVisuals"
	model.add_child(gear)
	gear.call("equip_sword", &"katana_cyan")
	_ps2.call("upgrade_model", gear.call("get_sword") as Node3D, SWORD_FILE, _look.call("profile", "grim_ps2"))


func _prop(prop_name: String, at: Vector3, yaw_deg: float) -> void:
	var path: String = PROP_DIR + prop_name + ".glb"
	var prop: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	prop.position = at
	prop.rotation_degrees.y = yaw_deg
	_world.add_child(prop)
	_ps2.call("upgrade_model", prop, path, _look.call("profile", "grim_ps2"))


func _pose(model: Node3D, clip: String, seconds: float) -> void:
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.play(clip)
	player.seek(seconds, true)
	player.pause()


func _label(text: String, world_point: Vector3, group: StringName) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 22)
	label.add_theme_color_override(&"font_color", Color("#f3e9d0"))
	label.add_theme_color_override(&"font_outline_color", Color("#14121f"))
	label.add_theme_constant_override(&"outline_size", 8)
	label.set_meta(&"world_point", world_point)
	label.set_meta(&"group", group)
	label.visible = false
	(_screen.call("get_ui_layer") as CanvasLayer).add_child(label)
	_labels.append(label)


func _show_labels(group: StringName) -> void:
	for label: Label in _labels:
		label.visible = label.get_meta(&"group") == group


func _place_labels() -> void:
	var size: Vector2 = _camera.get_viewport().get_visible_rect().size
	for label: Label in _labels:
		var point: Vector3 = label.get_meta(&"world_point") as Vector3
		var p: Vector2 = _camera.unproject_position(point)
		var ui: Vector2 = Vector2(GAME_BOX.position) + Vector2(p.x / size.x * GAME_BOX.size.x, p.y / size.y * GAME_BOX.size.y)
		label.position = ui - Vector2(label.size.x / 2.0, label.size.y)


## The fog the PS2 shaders read, pushed out so the huge robot is not hidden by haze made for a 44 m arena.
func _fog(near: float, far: float) -> void:
	(load("res://scripts/core/psx_look.gd") as GDScript).call("set_fog", Color("#262d33"), near, far)


func _contacts(path: String) -> Dictionary:
	var out: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	var data: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
	for clip: String in (data.get("clips", {}) as Dictionary):
		var entry: Dictionary = data["clips"][clip]
		if entry.has("contact_s"):
			out[clip] = float(entry["contact_s"])
	return out


func _grab() -> Image:
	_place_labels()
	await process_frame
	await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	return image.get_region(GAME_BOX)


func _save(image: Image, stem: String) -> void:
	var path: String = "%s/%s.png" % [_out, stem]
	print("saved ", path, " ", image.get_size(), " error ", image.save_png(path))


func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame
