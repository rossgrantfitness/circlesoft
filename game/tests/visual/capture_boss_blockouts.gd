extends SceneTree
## Screenshots of the boss placeholder blockouts (task VS-24), in the real renderer with the grim_ps2 look:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_boss_blockouts.gd -- --shot=sheet|wide|hush|mech|kasp|arena --out=/some/dir
## sheet: boss_blockouts.png, one wide shot (mech, Hushmaster, arena pieces) with close-up insets that include Red for scale.
## No game classes are named here (this file compiles before the autoloads exist); everything goes through load().

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"
const PS2_LOOK: String = "res://scripts/core/ps2_look.gd"
const LOOK_PROFILES: String = "res://scripts/core/look_profiles.gd"
const GEAR: String = "res://scripts/combat/gear_visuals.gd"
const FLOOR_TILE: String = "res://art/final/textures/city/tiles_busted/floor_concrete_panel_bevel.png"
const SWORD_FILE: String = "res://art/final/weapons/sword_katana_cyan.glb"
const RED: String = "res://art/final/characters/red/red_ross_v1_rigged_ual.glb"
const DIR: String = "res://art/placeholder/bosses/"
const ARENA: String = "res://art/placeholder/bosses/arena/"
const GAME_BOX: Rect2i = Rect2i(64, 36, 1152, 648)
const SETTLE_FRAMES: int = 10

var _out: String = "/tmp"
var _shot: String = "sheet"
var _screen: Node = null
var _world: Node3D = null
var _camera: Camera3D = null
var _look: GDScript = null
var _ps2: GDScript = null
var _labels: Array[Label] = []
var _mech_node: Node3D = null


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
		"sheet":
			await _sheet()
		"wide":
			_place_wide()
			_cam(Vector3(10.0, 24.0, 175.0), Vector3(0.0, 17.0, -20.0), 40.0)
			_save(await _grab(), "boss_wide")
		"hush":
			_place_hush()
			_cam(Vector3(2.0, 3.2, 20.0), Vector3(0.0, 3.6, 0.0), 42.0)
			_save(await _grab(), "boss_hush")
		"mech":
			_place_mech()
			_cam(Vector3(30.0, 24.0, 85.0), Vector3(0.0, 19.0, 0.0), 40.0)
			_save(await _grab(), "boss_mech")
		"mech_back":
			_place_mech()
			_mech_node.rotation_degrees.y = 150.0
			_cam(Vector3(30.0, 24.0, 85.0), Vector3(0.0, 19.0, 0.0), 40.0)
			_save(await _grab(), "boss_mech_back")
		"mech_close":
			_place_mech()
			_cam(Vector3(20.0, 28.0, 48.0), Vector3(0.0, 24.0, 0.0), 40.0)
			_save(await _grab(), "boss_mech_close")
		"kasp":
			_place_kasp()
			_cam(Vector3(0.9, 1.2, 4.2), Vector3(0.0, 0.7, 0.0), 40.0)
			_save(await _grab(), "boss_kasp")
		"arena":
			_place_arena()
			_cam(Vector3(8.0, 8.0, 34.0), Vector3(4.0, 3.5, 0.0), 45.0)
			_save(await _grab(), "boss_arena")
	quit(0)


# ---- the sheet ----

const MECH_AT: Vector3 = Vector3(28.0, 0.0, 0.0)
const HUSH_AT: Vector3 = Vector3(-46.0, 0.0, 52.0)
const HUSH_PEOPLE: Vector3 = Vector3(-47.0, 0.0, 71.0)
const MECH_PEOPLE: Vector3 = Vector3(21.0, 0.0, 22.0)
const ARENA_AT: Vector3 = Vector3(-30.0, 0.0, 250.0)


func _sheet() -> void:
	_mech(MECH_AT)
	_hush(HUSH_AT)
	_people(HUSH_PEOPLE, &"a")
	_people(MECH_PEOPLE, &"b")
	_arena_row(ARENA_AT)
	_fog(300.0, 1500.0)
	_label("junk mech  40 m", MECH_AT + Vector3(0.0, 42.5, 0.0), &"main")
	_label("Hushmaster  12 m wide", HUSH_AT + Vector3(0.0, 10.0, 0.0), &"main")
	_show_labels(&"main")
	_cam(Vector3(-8.0, 10.0, 150.0), Vector3(-8.0, 17.0, 0.0), 36.0)
	var main_image: Image = await _grab()
	_show_labels(&"a")
	_cam(Vector3(-41.0, 2.4, 80.0), Vector3(-45.0, 3.4, 58.0), 52.0)
	await _settle(SETTLE_FRAMES)
	var inset_a: Image = await _grab()
	_show_labels(&"b")
	_cam(Vector3(30.0, 2.2, 32.0), Vector3(25.0, 8.0, 3.0), 62.0)
	await _settle(SETTLE_FRAMES)
	var inset_b: Image = await _grab()
	_show_labels(&"none")
	_cam(Vector3(-10.0, 8.0, 296.0), Vector3(-12.0, 5.0, 250.0), 58.0)
	await _settle(SETTLE_FRAMES)
	var inset_c: Image = await _grab()
	var gap: int = 8
	var tile_w: int = (main_image.get_width() - gap * 2) / 3
	var tile_h: int = tile_w * main_image.get_height() / main_image.get_width()
	var sheet: Image = Image.create(main_image.get_width(), main_image.get_height() + gap + tile_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#ffb347"))
	sheet.blit_rect(main_image, Rect2i(Vector2i.ZERO, main_image.get_size()), Vector2i.ZERO)
	var x: int = 0
	for inset: Image in [inset_a, inset_b, inset_c]:
		inset.resize(tile_w, tile_h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(inset, Rect2i(Vector2i.ZERO, inset.get_size()), Vector2i(x, main_image.get_height() + gap))
		x += tile_w + gap
	_save(sheet, "boss_blockouts")


func _place_wide() -> void:
	_mech(Vector3(0.0, 0.0, -60.0))
	_hush(Vector3(-34.0, 0.0, 20.0))
	_arena_row(Vector3(-72.0, 0.0, 108.0))


func _place_hush() -> void:
	_hush(Vector3.ZERO)
	_people(Vector3(0.0, 0.0, 9.0), &"hush")


func _place_mech() -> void:
	_fog(300.0, 1500.0)
	_mech(Vector3.ZERO)
	_people(Vector3(1.5, 0.0, 14.0), &"hush")


func _place_kasp() -> void:
	_model(DIR + "kasp.glb", Vector3(0.45, 0.0, 0.0), "enemy")
	var red: Node3D = _model(RED, Vector3(-0.45, 0.0, 0.0), "party")
	_gear(red)


func _place_arena() -> void:
	_arena_row(Vector3.ZERO)


# ---- building blocks ----

func _mech(at: Vector3) -> void:
	_mech_node = _model(DIR + "junk_mech.glb", at, "enemy")


func _hush(at: Vector3) -> void:
	_model(DIR + "hushmaster.glb", at, "enemy")


func _people(at: Vector3, group: StringName) -> void:
	var red: Node3D = _model(RED, at + Vector3(-0.8, 0.0, 0.0), "party")
	_gear(red)
	var kasp: Node3D = _model(DIR + "kasp.glb", at + Vector3(0.8, 0.0, 0.0), "enemy")
	kasp.rotation_degrees.y = -15.0
	_label("Red 0.95 m", at + Vector3(-2.0, 1.2, 0.0), group)
	_label("Kasp 1.05 m", at + Vector3(2.0, 1.3, 0.0), group)


func _arena_row(at: Vector3) -> void:
	var x: float = 0.0
	for entry: Array in [["arena_wall_segment", 12.2], ["arena_gate_post", 4.4], ["plateau_rail_segment", 4.2], ["arena_turret_pylon", 3.0], ["scrap_pile_s", 5.0], ["scrap_pile_m", 7.5], ["scrap_pile_l", 11.0]]:
		_model(ARENA + str(entry[0]) + ".glb", at + Vector3(x + float(entry[1]) * 0.5, 0.0, 0.0), "enemy")
		x += float(entry[1]) + 1.5
	_model(ARENA + "scrap_heap_giant.glb", at + Vector3(-45.0, 0.0, -12.0), "enemy")


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
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.light_color = Color("#ffd9b0")
	key.light_energy = 1.35
	key.rotation_degrees = Vector3(-38.0, 28.0, 0.0)
	key.directional_shadow_max_distance = 300.0
	_world.add_child(key)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(800.0, 0.2, 800.0)
	var floor_body: MeshInstance3D = MeshInstance3D.new()
	floor_body.mesh = mesh
	var material: ShaderMaterial = _ps2.call("make_material", load(FLOOR_TILE), "city_tiles", _look.call("profile", "grim_ps2"))
	material.set_shader_parameter(&"uv_scale", Vector2(200.0, 200.0))
	material.set_shader_parameter(&"use_orm", 0.0)
	floor_body.material_override = material
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	_world.add_child(floor_body)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.far = 900.0
	_camera.current = true
	_world.add_child(_camera)
	var node: Node = _ps2.new() as Node
	node.name = "Ps2Look"
	_world.add_child(node)
	_look.call("set_forced", "grim_ps2")
	_fog(200.0, 1200.0)


func _cam(at: Vector3, target: Vector3, fov: float) -> void:
	_camera.fov = fov
	_camera.position = at
	_camera.look_at(target, Vector3.UP)


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


func _fog(near: float, far: float) -> void:
	(load("res://scripts/core/psx_look.gd") as GDScript).call("set_fog", Color("#262d33"), near, far)


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
