extends SceneTree
## Contact sheet of the slice rigs (VS-25: Kasp, the junk mech, the townsfolk) playing their retargeted Quaternius clips, in the
## real renderer (PS2 look). A copy of capture_ual_poses.gd with the boss rigs, a floor and a camera that scale with the model:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_boss_clips.gd -- --shot=kasp|mech|townsfolk --out=/some/dir
## Optional: --poses=clip:seconds,clip:contact,...  (debug: replaces the default list)  --yaw=55  --name=file_stem
##   --light=2.0 (brighter stage for the dark mech)  --model=res://....glb --keys=res://....json --height=1.05 (debug: another rig)  --columns=5
## Writes <out>/<shot>_clip_poses.png: one tile per pose (a front-ish three-quarter view), clip name under each.
## A pose given as "contact" is the clip's contact_s from the key data.
## No game classes are named here (this file compiles before the autoloads exist); everything goes through load().

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"
const PS2_LOOK: String = "res://scripts/core/ps2_look.gd"
const LOOK_PROFILES: String = "res://scripts/core/look_profiles.gd"
const GEAR: String = "res://scripts/combat/gear_visuals.gd"
const FLOOR_TILE: String = "res://art/final/textures/city/tiles_busted/floor_concrete_panel_bevel.png"
const SWORD_FILE: String = "res://art/final/weapons/sword_katana_cyan.glb"
const SHOTS: Dictionary = {
	"kasp": {
		"model": "res://art/placeholder/bosses/kasp_ual.glb",
		"keys": "res://data/animation/kasp_clip_keys.json",
		"height": 1.05,
		"poses": [["idle", "0.5"], ["run", "0.1"], ["talk", "0.8"], ["gesture", "0.8"], ["stagger", "0.3"],
				["knockdown", "0.45"], ["knockdown", "0.8"], ["getup", "0.7"], ["defeated", "1.0"], ["defeated", "2.3"]],
	},
	"mech": {
		"model": "res://art/placeholder/bosses/junk_mech_ual.glb",
		"keys": "res://data/animation/junk_mech_clip_keys.json",
		"height": 40.0,
		"poses": [["idle", "1.0"], ["walk", "0.3"], ["swing_r_windup", "1.6"], ["swing_r_strike", "contact"], ["drop_windup", "2.0"],
				["drop_strike", "contact"], ["stomp_windup", "1.5"], ["stomp_strike", "contact"], ["barrage_windup", "1.5"], ["barrage_strike", "contact"]],
	},
	"townsfolk": {
		"model": "res://art/placeholder/characters/townsfolk/townsfolk_blockout_ual.glb",
		"keys": "res://data/animation/townsfolk_clip_keys.json",
		"height": 1.0,
		"poses": [["idle", "0.5"], ["talk", "0.5"], ["talk", "1.5"], ["walk", "0.1"], ["walk", "0.5"]],
	},
}
var COLUMNS: int = 5
const TILE: Vector2i = Vector2i(330, 420)
const SETTLE_FRAMES: int = 8

var _out: String = "/tmp"
var _shot: String = "red"
var _yaw: float = 55.0
var _name: String = ""
var _poses_arg: String = ""
var _model_arg: String = ""
var _keys_arg: String = ""
var _height_arg: float = 0.0
var _height: float = 1.0
var _light: float = 1.0
var _screen: Node = null
var _world: Node3D = null
var _camera: Camera3D = null
var _look: GDScript = null
var _ps2: GDScript = null
var _label: Label = null


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--yaw="):
			_yaw = float(arg.trim_prefix("--yaw="))
		elif arg.begins_with("--name="):
			_name = arg.trim_prefix("--name=")
		elif arg.begins_with("--poses="):
			_poses_arg = arg.trim_prefix("--poses=")
		elif arg.begins_with("--model="):
			_model_arg = arg.trim_prefix("--model=")
		elif arg.begins_with("--keys="):
			_keys_arg = arg.trim_prefix("--keys=")
		elif arg.begins_with("--height="):
			_height_arg = float(arg.trim_prefix("--height="))
		elif arg.begins_with("--light="):
			_light = float(arg.trim_prefix("--light="))
		elif arg.begins_with("--columns="):
			COLUMNS = int(arg.trim_prefix("--columns="))
	await process_frame
	_look = load(LOOK_PROFILES) as GDScript
	_ps2 = load(PS2_LOOK) as GDScript
	_screen = (load(SCREEN_SCENE) as PackedScene).instantiate()
	root.add_child(_screen)
	await _settle(2)
	_world = _screen.call("get_world_root") as Node3D
	var spec: Dictionary = (SHOTS[_shot] as Dictionary).duplicate() if SHOTS.has(_shot) else {"model": "", "keys": "", "height": 1.0, "poses": []}
	if _model_arg != "":
		spec["model"] = _model_arg
	if _keys_arg != "":
		spec["keys"] = _keys_arg
	if _height_arg > 0.0:
		spec["height"] = _height_arg
	_height = float(spec["height"])
	_build_stage()
	var contacts: Dictionary = _contacts(str(spec["keys"]))
	var poses: Array = spec["poses"]
	if _poses_arg != "":
		poses = []
		for item: String in _poses_arg.split(","):
			var pair: PackedStringArray = item.split(":")
			poses.append([pair[0], pair[1]])
	var model: Node3D = (load(str(spec["model"])) as PackedScene).instantiate() as Node3D
	model.rotation_degrees.y = _yaw
	_world.add_child(model)
	_ps2.call("upgrade_model", model, str(spec["model"]), _look.call("profile", "grim_ps2"))
	_look.call("dress_model", model, str(spec["model"]), "enemy")
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rows: int = int(ceil(float(poses.size()) / COLUMNS))
	var sheet: Image = Image.create(TILE.x * mini(COLUMNS, poses.size()), TILE.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#14172a"))
	var height: float = float(spec["height"])
	for index: int in poses.size():
		var clip: String = str(poses[index][0])
		var at: String = str(poses[index][1])
		if not player.has_animation(clip):
			print("MISSING clip ", clip)
			continue
		var seconds: float = float(contacts.get(clip, 0.0)) if at == "contact" else float(at)
		player.play(clip)
		player.seek(seconds, true)
		player.pause()
		_label.text = "%s  %.2fs" % [clip, seconds]
		_camera.position = Vector3(0.0, height * 0.62, height * 3.3)
		_camera.look_at(Vector3(0.0, height * 0.5, 0.0), Vector3.UP)
		await _settle(SETTLE_FRAMES)
		var image: Image = root.get_viewport().get_texture().get_image()
		var size: Vector2i = image.get_size()
		var crop: Rect2i = Rect2i(size.x / 2 - TILE.x / 2, size.y / 2 - TILE.y / 2 - 20, TILE.x, TILE.y)
		sheet.blit_rect(image, crop, Vector2i((index % COLUMNS) * TILE.x, (index / COLUMNS) * TILE.y))
	var stem: String = _name if _name != "" else "%s_clip_poses" % _shot
	var path: String = "%s/%s.png" % [_out, stem]
	print("saved ", path, " ", sheet.get_size(), " error ", sheet.save_png(path))
	quit(0)


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
		else:
			var keys: Array = entry.get("keys", [])
			if keys.size() > 1:
				out[clip] = float((keys[1] as Dictionary).get("clip_s", 0.0))
	return out


func _build_stage() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#14172a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#59607a")
	environment.ambient_light_energy = 0.9 * _light
	var holder: WorldEnvironment = WorldEnvironment.new()
	holder.environment = environment
	_world.add_child(holder)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.light_color = Color("#ffd9b0")
	key.light_energy = 1.35 * _light
	key.rotation_degrees = Vector3(-40.0, 20.0, 0.0)
	_world.add_child(key)
	for lamp: Array in [[Vector3(-2.5, 2.0, -1.5) * _height, Color("#ffb347"), 2.0], [Vector3(2.5, 2.0, 1.5) * _height, Color("#4fd8ff"), 1.6]]:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = lamp[0]
		light.light_color = lamp[1]
		light.light_energy = lamp[2]
		light.omni_range = 9.0 * _height
		_world.add_child(light)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(40.0, 0.1, 40.0) * _height
	var floor_body: MeshInstance3D = MeshInstance3D.new()
	floor_body.mesh = mesh
	var material: ShaderMaterial = _ps2.call("make_material", load(FLOOR_TILE), "city_tiles", _look.call("profile", "grim_ps2"))
	material.set_shader_parameter(&"uv_scale", Vector2(26.0, 26.0))
	material.set_shader_parameter(&"use_orm", 0.0)
	floor_body.material_override = material
	floor_body.position = Vector3(0.0, -0.05 * _height, 0.0)
	_world.add_child(floor_body)
	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.far = 800.0
	_camera.near = 0.05 * _height
	_camera.current = true
	_world.add_child(_camera)
	var node: Node = _ps2.new() as Node
	node.name = "Ps2Look"
	_world.add_child(node)
	_look.call("set_forced", "grim_ps2")
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 18)
	_label.add_theme_color_override(&"font_color", Color("#f3e9d0"))
	_label.add_theme_color_override(&"font_outline_color", Color("#14121f"))
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.position = Vector2(500.0, 512.0)
	(_screen.call("get_ui_layer") as CanvasLayer).add_child(_label)


func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame
