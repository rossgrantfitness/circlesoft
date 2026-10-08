class_name CombatSandbox
extends Node3D
## The LIGHTS ON combat sandbox arena (docs/pivot/combat_api.md 1, 4.6 and 6): the floor, walls,
## pillars, ledge and ramp; Red, the camera and lock-on; the enemies; the sword rack; and the optional
## parts other roles ship (director, fx, HUD, feel panel, pause), attached when their files exist.
## Main loads this scene into the PSX world on the `sandbox` feature tag or `-- --sandbox`.
##
## Everything about the arena is in data/combat/sandbox.json (sizes, tiles, spawns, racks, lights),
## so Ross's notes become number edits. Missing pieces never stop it from running: no art means plain
## grey, no enemy scene means that spawn is skipped (listed in `missing`), no HUD file means no HUD.
##
## Binding, for the HUD and FX: get_director(), get_player(), get_lock_on(), get_camera(),
## screen_pos_of(actor_id, point) in 640x360 stage pixels, and reset_arena() for the pause menu.
## Nodes in the PSX world get no input events, so a small relay in the sharp UI layer forwards button
## presses (with their real timestamps) to Red and mouse movement to the camera.

signal arena_reset

const DATA_ID: String = "combat/sandbox"
const ATLAS_ID: String = "world/city_texture_atlas"
const GROUP_PSX_SCREEN: StringName = &"psx_screen"
const GROUP_DIRECTOR: StringName = &"combat_director"
const ROOM_KEY: String = "combat_sandbox"
const LAYER_WORLD: int = 1
const FALL_LIMIT_Y: float = -8.0
const COMBAT_ACTIONS: Array[StringName] = [&"jump", &"light", &"heavy", &"dash", &"parry"]
const DEFAULT_STAGE: Vector2 = Vector2(640.0, 360.0)

## Used by PsxRoomLook to pick this scene's look profile.
var room_id: String = ROOM_KEY
## Names of things the data asked for that were not there yet (enemy scenes, attachments, tiles).
var missing: Array[String] = []

var _data: Dictionary = {}
var _director: Node = null
var _feel: FeelKnobs = null
var _player: Node3D = null
var _camera: OrbitCamera = null
var _lock: LockOn = null
var _enemies: Array[Node3D] = []
var _racks: Array[SwordRack] = []
var _attached: Array[Node] = []
var _materials: Dictionary[String, StandardMaterial3D] = {}
var _relay: InputRelay = null
var _mouse_captured: bool = false
var _world_environment: WorldEnvironment = null
var _enemy_serial: int = 0


func _ready() -> void:
	_data = _load_data()
	add_to_group(&"combat_sandbox")
	_setup_screen()
	_build_arena()
	_attach_parts(false)
	_setup_feel()
	_spawn_player()
	_attach_parts(true)
	_spawn_enemies()
	_build_racks()
	_make_relay()
	_apply_look()
	if bool(_data.get("capture_mouse", true)):
		set_mouse_captured(true)


func _exit_tree() -> void:
	set_mouse_captured(false)
	if _relay != null and is_instance_valid(_relay):
		_relay.queue_free()
	for node: Node in _attached:
		if is_instance_valid(node) and node.get_parent() != self:
			node.queue_free()
	_attached.clear()


func _physics_process(_delta: float) -> void:
	tick()


## Per-frame housekeeping: anything that fell out of the world goes back to its spawn.
func tick() -> void:
	if _player != null and _player.global_position.y < FALL_LIMIT_Y:
		_place_player()
	for enemy: Node3D in _enemies:
		if is_instance_valid(enemy) and enemy.global_position.y < FALL_LIMIT_Y:
			enemy.global_position = Vector3(0.0, 0.5, 0.0)
			if enemy is CharacterBody3D:
				(enemy as CharacterBody3D).velocity = Vector3.ZERO


# ---- binding ----

func get_director() -> Node:
	return _director


## The one set of feel knobs everything reads: the director's when it has them, else the sandbox's own
## (the defaults in data/combat/feel.json, then Ross's saved feel_current.json on top).
func get_feel() -> FeelKnobs:
	return _feel


func get_player() -> Node3D:
	return _player


func get_lock_on() -> LockOn:
	return _lock


func get_camera() -> OrbitCamera:
	return _camera


func get_enemies() -> Array[Node3D]:
	var live: Array[Node3D] = []
	for enemy: Node3D in _enemies:
		if is_instance_valid(enemy):
			live.append(enemy)
	return live


func get_racks() -> Array[SwordRack]:
	return _racks


func get_data() -> Dictionary:
	return _data


## Where an actor's `point` (&"head", &"center", &"feet", &"lamp") is on the 640x360 stage, in
## stage pixels. Vector2.ZERO when the actor is unknown or the point is behind the camera.
func screen_pos_of(actor_id: StringName, point: StringName = &"head") -> Vector2:
	var actor: Node3D = _find_actor(actor_id)
	if actor == null or _camera == null or _camera.get_camera() == null:
		return Vector2.ZERO
	var world: Vector3 = _anchor_of(actor, point)
	var cam: Camera3D = _camera.get_camera()
	if cam.is_position_behind(world):
		return Vector2.ZERO
	var pixel: Vector2 = cam.unproject_position(world)
	var size: Vector2 = cam.get_viewport().get_visible_rect().size
	var stage: Vector2 = _stage_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return pixel
	return Vector2(pixel.x * stage.x / size.x, pixel.y * stage.y / size.y)


## Puts everything back to the start: Red full health at the spawn, every enemy fresh at its spawn,
## Noise empty, lock released. The pause menu's "Reset arena" calls this.
func reset_arena() -> void:
	if _lock != null:
		_lock.release()
	for enemy: Node3D in _enemies:
		if is_instance_valid(enemy):
			if enemy.get_parent() != null:
				enemy.get_parent().remove_child(enemy)
			enemy.queue_free()
	_enemies.clear()
	_enemy_serial = 0
	if _director != null and _director.has_method("reset"):
		_director.call("reset")
	if _player != null and _player.has_method("reset_to"):
		_player.call("reset_to", get_player_spawn())
	elif _player != null:
		_player.global_transform = get_player_spawn()
	_spawn_enemies()
	if _camera != null:
		_camera.recenter()
		_camera.snap()
	arena_reset.emit()


func get_player_spawn() -> Transform3D:
	var spawn: Dictionary = _data.get("player_spawn", {}) as Dictionary
	var pos: Vector3 = _vec3(spawn.get("pos", [0.0, 0.1, 12.0]))
	var yaw: float = deg_to_rad(float(spawn.get("yaw_deg", 180.0)))
	return Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), pos)


## Captures or frees the mouse (the pause menu and the feel panel free it). Headless runs never capture.
func set_mouse_captured(captured: bool) -> void:
	if DisplayServer.get_name() == "headless":
		_mouse_captured = false
		return
	_mouse_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return _mouse_captured


## The look-aware hook (LookProfiles calls it when the profile changes): nothing arena-specific yet;
## the profile's grade and PsxRoomLook's fog and lights do the work.
func apply_look(_id: String, _profile: Dictionary) -> void:
	pass


# ---- data ----

func _load_data() -> Dictionary:
	var db: Node = get_node_or_null("/root/DataDB")
	if db == null:
		return {}
	return db.call("get_dict", DATA_ID) as Dictionary


func _stage_size() -> Vector2:
	var raw: Variant = _data.get("stage_size", null)
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	return DEFAULT_STAGE


static func _vec3(raw: Variant) -> Vector3:
	if raw is Array and (raw as Array).size() >= 3:
		var list: Array = raw
		return Vector3(float(list[0]), float(list[1]), float(list[2]))
	return Vector3.ZERO


func _block(key: String) -> Dictionary:
	return _data.get(key, {}) as Dictionary


# ---- the screen and the look ----

func _setup_screen() -> void:
	var screen: Node = get_tree().get_first_node_in_group(GROUP_PSX_SCREEN)
	if screen == null or not screen.has_method("set_resolution"):
		return
	var wanted: String = str(_data.get("internal_resolution", "640x360"))
	var parts: PackedStringArray = wanted.split("x")
	if parts.size() == 2:
		var size: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
		var allowed: Array = screen.call("get_resolutions") as Array
		if allowed.has(size):
			screen.call("set_resolution", size)
		else:
			push_warning("CombatSandbox: %s is not in data/world/psx_look.json yet; staying at the default size" % wanted)
			missing.append("resolution " + wanted)


func _apply_look() -> void:
	var wanted: String = str(_data.get("look_profile", "grim_ps2"))
	if not LookProfiles.has_profile(wanted):
		missing.append("look profile " + wanted)
		wanted = str(_data.get("fallback_look_profile", "grim"))
	LookProfiles.enter_scene(ROOM_KEY)
	if LookProfiles.has_profile(wanted) and LookProfiles.active_id() != wanted:
		LookProfiles.apply(wanted)


# ---- the arena ----

func _build_arena() -> void:
	var arena: Dictionary = _block("arena")
	var size: Vector2 = Vector2(44.0, 44.0)
	if arena.get("size_m") is Array:
		size = Vector2(float((arena["size_m"] as Array)[0]), float((arena["size_m"] as Array)[1]))
	var wall_h: float = float(arena.get("wall_height_m", 7.0))
	var wall_t: float = float(arena.get("wall_thickness_m", 1.0))
	var level: Node3D = Node3D.new()
	level.name = "Level"
	add_child(level)
	_add_box(level, "Floor", Vector3(0.0, -0.2, 0.0), Vector3(size.x, 0.4, size.y), Vector3.ZERO, str(arena.get("floor_tile", "")))
	_add_box(level, "WallNorth", Vector3(0.0, wall_h * 0.5, -size.y * 0.5 - wall_t * 0.5), Vector3(size.x + wall_t * 2.0, wall_h, wall_t), Vector3.ZERO, str(arena.get("wall_tile", "")))
	_add_box(level, "WallSouth", Vector3(0.0, wall_h * 0.5, size.y * 0.5 + wall_t * 0.5), Vector3(size.x + wall_t * 2.0, wall_h, wall_t), Vector3.ZERO, str(arena.get("wall_tile", "")))
	_add_box(level, "WallWest", Vector3(-size.x * 0.5 - wall_t * 0.5, wall_h * 0.5, 0.0), Vector3(wall_t, wall_h, size.y), Vector3.ZERO, str(arena.get("wall_tile", "")))
	_add_box(level, "WallEast", Vector3(size.x * 0.5 + wall_t * 0.5, wall_h * 0.5, 0.0), Vector3(wall_t, wall_h, size.y), Vector3.ZERO, str(arena.get("wall_tile", "")))
	var index: int = 0
	for raw: Variant in arena.get("pillars", []) as Array:
		var pillar: Dictionary = raw as Dictionary
		_add_pillar(level, "Pillar%d" % index, _vec3(pillar.get("pos")), float(pillar.get("radius", 1.0)),
				float(pillar.get("height", 4.0)), str(arena.get("pillar_tile", "")))
		index += 1
	index = 0
	for raw: Variant in arena.get("ledges", []) as Array:
		var ledge: Dictionary = raw as Dictionary
		var ledge_size: Vector3 = _vec3(ledge.get("size"))
		var base: Vector3 = _vec3(ledge.get("pos"))
		_add_box(level, "Ledge%d" % index, base + Vector3(0.0, ledge_size.y * 0.5, 0.0), ledge_size, Vector3.ZERO, str(arena.get("ledge_tile", "")))
		index += 1
	index = 0
	for raw: Variant in arena.get("ramps", []) as Array:
		var ramp: Dictionary = raw as Dictionary
		var base_pos: Vector3 = _vec3(ramp.get("pos"))
		base_pos.y = float(ramp.get("y", 0.5))
		_add_box(level, "Ramp%d" % index, base_pos, _vec3(ramp.get("size")), _vec3(ramp.get("rot_deg")), str(arena.get("ledge_tile", "")))
		index += 1
	_build_lighting()


func _add_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, rot_deg: Vector3, tile: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1 << (LAYER_WORLD - 1)
	body.collision_mask = 0
	parent.add_child(body)
	body.position = pos
	body.rotation_degrees = rot_deg
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = _material_for(tile)
	body.add_child(mesh_node)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	return body


func _add_pillar(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, tile: String) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1 << (LAYER_WORLD - 1)
	body.collision_mask = 0
	parent.add_child(body)
	body.position = pos + Vector3(0.0, height * 0.5, 0.0)
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh_node.mesh = mesh
	mesh_node.material_override = _material_for(tile)
	body.add_child(mesh_node)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	shape_node.shape = shape
	body.add_child(shape_node)


## The arena's plain-grey fallback colour, or the tile's texture (world-triplanar so every box and
## cylinder gets the same texel density). The filter comes from data, never from code: first the
## look profile's texture_filter block, then sandbox.json arena.texture_filter.
func _material_for(tile_id: String) -> StandardMaterial3D:
	if _materials.has(tile_id):
		return _materials[tile_id]
	var arena: Dictionary = _block("arena")
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var grey: Variant = arena.get("grey", [0.34, 0.35, 0.38])
	var grey_list: Array = grey as Array
	material.albedo_color = Color(float(grey_list[0]), float(grey_list[1]), float(grey_list[2]))
	material.roughness = 0.9
	material.metallic_specular = 0.2
	var texture: Texture2D = _tile_texture(tile_id)
	if texture != null:
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		var tile_m: float = maxf(float(arena.get("tile_m", 2.0)), 0.1)
		material.uv1_scale = Vector3.ONE / tile_m
		material.texture_filter = _filter_mode()
		material.texture_repeat = true
	elif not tile_id.is_empty():
		missing.append("tile " + tile_id)
	_materials[tile_id] = material
	return material


func _tile_texture(tile_id: String) -> Texture2D:
	if tile_id.is_empty():
		return null
	var db: Node = get_node_or_null("/root/DataDB")
	if db == null:
		return null
	var variant: String = str(_block("arena").get("tile_variant", "clean"))
	var dir: String = str(db.call("get_value", ATLAS_ID, "variants.%s.tile_dir" % variant, ""))
	if dir.is_empty():
		return null
	var path: String = dir.path_join(tile_id + ".png")
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## BaseMaterial3D texture filter from data. Ross's pixel-art filtering call is pending (R40), so the
## profile can decide ("nearest" / "linear") and sandbox.json is the fallback.
func _filter_mode() -> BaseMaterial3D.TextureFilter:
	var mode: String = str(_block("arena").get("texture_filter", "linear"))
	var from_profile: Variant = LookProfiles.value(LookProfiles.active_id(), "texture_filter.mode", null)
	if from_profile is String and not (from_profile as String).is_empty():
		mode = from_profile
	match mode:
		"nearest":
			return BaseMaterial3D.TEXTURE_FILTER_NEAREST
		"nearest_mipmap":
			return BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_:
			return BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _build_lighting() -> void:
	var lighting: Dictionary = _block("lighting")
	var lights: Node3D = Node3D.new()
	lights.name = "Lights"
	add_child(lights)
	var key_cfg: Dictionary = lighting.get("key", {}) as Dictionary
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color.html(str(key_cfg.get("color", "#ffd9b0")))
	key.light_energy = float(key_cfg.get("energy", 1.0))
	key.rotation_degrees = _vec3(key_cfg.get("rot_deg", [-58.0, 35.0, 0.0]))
	key.shadow_enabled = bool(key_cfg.get("shadow", true))
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_max_distance = float(key_cfg.get("shadow_max_distance_m", 20.0))
	lights.add_child(key)
	var index: int = 0
	for raw: Variant in lighting.get("lamps", []) as Array:
		var lamp_cfg: Dictionary = raw as Dictionary
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.name = "Lamp%d" % index
		lamp.position = _vec3(lamp_cfg.get("pos"))
		lamp.light_color = Color.html(str(lamp_cfg.get("color", "#ffffff")))
		lamp.light_energy = float(lamp_cfg.get("energy", 1.5))
		lamp.omni_range = float(lamp_cfg.get("range", 12.0))
		lights.add_child(lamp)
		index += 1
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.html(str(lighting.get("background", "#14172a")))
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var ambient: Dictionary = lighting.get("ambient", {}) as Dictionary
	environment.ambient_light_color = Color.html(str(ambient.get("color", "#59607a")))
	environment.ambient_light_energy = float(ambient.get("energy", 0.9))
	var fog: Dictionary = lighting.get("fog", {}) as Dictionary
	if not fog.is_empty():
		environment.fog_enabled = true
		environment.fog_light_color = Color.html(str(fog.get("color", "#1f2540")))
		environment.fog_density = float(fog.get("density", 0.012))
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "WorldEnvironment"
	_world_environment.environment = environment
	add_child(_world_environment)
	var look: PsxRoomLook = PsxRoomLook.new()
	look.name = "RoomLook"
	look.fog_color = environment.fog_light_color if environment.fog_enabled else environment.background_color
	look.ambient_color = environment.ambient_light_color
	look.ambient_energy = environment.ambient_light_energy
	add_child(look)


# ---- the fighters ----

func _spawn_player() -> void:
	var scenes: Dictionary = _block("scenes")
	var path: String = str(scenes.get("player", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		missing.append("player scene " + path)
		push_error("CombatSandbox: no player scene at %s" % path)
		return
	var scene: PackedScene = load(path) as PackedScene
	_player = scene.instantiate() as Node3D
	if _player == null:
		push_error("CombatSandbox: the player scene's root is not a Node3D")
		return
	add_child(_player)
	_place_player()
	_lock = LockOn.new()
	_lock.name = "LockOn"
	_lock.origin_node = _player
	add_child(_lock)
	_camera = OrbitCamera.new()
	_camera.name = "OrbitCamera"
	add_child(_camera)
	_camera.follow(_player)
	_camera.set_lock_on(_lock)
	_camera.snap()
	if "knobs" in _player:
		_player.set("knobs", _feel)
	_camera.knobs = _feel
	if "camera" in _player:
		_player.set("camera", _camera.get_camera())
	if "lock_on" in _player:
		_player.set("lock_on", _lock)
	if "orbit_camera" in _player:
		_player.set("orbit_camera", _camera)


func _setup_feel() -> void:
	if _director != null and "feel" in _director and _director.get("feel") is FeelKnobs:
		_feel = _director.get("feel") as FeelKnobs
	else:
		_feel = FeelKnobs.load_defaults()
	_feel.load_user()


func _place_player() -> void:
	if _player == null:
		return
	if _player.has_method("reset_to"):
		_player.call("reset_to", get_player_spawn())
	else:
		_player.global_transform = get_player_spawn()


func _spawn_enemies() -> void:
	var scenes: Dictionary = _block("enemy_scenes")
	for raw: Variant in _data.get("enemy_spawns", []) as Array:
		var entry: Dictionary = raw as Dictionary
		var kind: String = str(entry.get("enemy", ""))
		var path: String = str(scenes.get(kind, ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			if not missing.has("enemy scene " + kind):
				missing.append("enemy scene " + kind)
			continue
		var scene: PackedScene = load(path) as PackedScene
		var enemy: Node3D = scene.instantiate() as Node3D
		if enemy == null:
			continue
		_enemy_serial += 1
		if "actor_id" in enemy:
			enemy.set("actor_id", StringName("%s_%d" % [kind, _enemy_serial]))
		if "spawn_position" in enemy:
			enemy.set("spawn_position", _vec3(entry.get("pos")))
		enemy.position = _vec3(entry.get("pos"))
		add_child(enemy)
		_enemies.append(enemy)


func _build_racks() -> void:
	var racks: Dictionary = _block("racks")
	var holder: Node3D = Node3D.new()
	holder.name = "SwordRacks"
	add_child(holder)
	for raw: Variant in racks.get("stands", []) as Array:
		var stand: Dictionary = raw as Dictionary
		var rack: SwordRack = SwordRack.new()
		rack.name = "Rack_%s" % str(stand.get("sword", ""))
		rack.sword_id = StringName(str(stand.get("sword", "")))
		rack.radius_m = float(racks.get("interact_radius_m", 0.9))
		rack.position = _vec3(stand.get("pos"))
		holder.add_child(rack)
		_racks.append(rack)


func _find_actor(actor_id: StringName) -> Node3D:
	if _player != null and "actor_id" in _player and StringName(_player.get("actor_id")) == actor_id:
		return _player
	if actor_id == &"red" and _player != null:
		return _player
	for enemy: Node3D in get_enemies():
		if "actor_id" in enemy and StringName(enemy.get("actor_id")) == actor_id:
			return enemy
	return null


func _anchor_of(actor: Node3D, point: StringName) -> Vector3:
	if actor.has_method("anchor"):
		return actor.call("anchor", point) as Vector3
	var lift: float = {&"feet": 0.0, &"center": 0.45, &"head": 1.0, &"lamp": 0.6}.get(point, 0.5)
	return actor.global_position + Vector3.UP * lift


# ---- attachments from other roles ----

## Attaches the parts listed in sandbox.json that exist. `after_player` false = the director (needs to
## exist before the fighters register); true = everything else (needs the player to bind to).
func _attach_parts(after_player: bool) -> void:
	for raw: Variant in _data.get("attachments", []) as Array:
		var entry: Dictionary = raw as Dictionary
		var is_director: bool = str(entry.get("id", "")) == "director"
		if is_director == after_player:
			continue
		var node: Node = _make_attachment(entry)
		if node == null:
			missing.append("attachment " + str(entry.get("id", "")))
			continue
		_attached.append(node)
		if is_director:
			_director = node
		var layer: String = str(entry.get("layer", "world"))
		if layer == "ui":
			_ui_parent().add_child(node)
		else:
			add_child(node)
		if bool(entry.get("bind", false)) and node.has_method("bind"):
			node.call("bind", self)


func _make_attachment(entry: Dictionary) -> Node:
	var scene_path: String = str(entry.get("scene", ""))
	if not scene_path.is_empty():
		if not ResourceLoader.exists(scene_path):
			return null
		var scene: PackedScene = load(scene_path) as PackedScene
		return scene.instantiate() if scene != null else null
	var script_path: String = str(entry.get("script", ""))
	if script_path.is_empty() or not ResourceLoader.exists(script_path):
		return null
	var script: GDScript = load(script_path) as GDScript
	if script == null or not script.can_instantiate():
		return null
	return script.new() as Node


## The sharp UI layer of the PSX screen (menus stay crisp over the 640x360 picture). With no screen
## (tests) a layer of our own.
func _ui_parent() -> Node:
	var screen: Node = get_tree().get_first_node_in_group(GROUP_PSX_SCREEN)
	if screen != null and screen.has_method("get_ui_layer"):
		return screen.call("get_ui_layer") as Node
	var own: CanvasLayer = get_node_or_null("UiLayer") as CanvasLayer
	if own == null:
		own = CanvasLayer.new()
		own.name = "UiLayer"
		add_child(own)
	return own


# ---- input ----

func _make_relay() -> void:
	if get_tree().get_first_node_in_group(GROUP_PSX_SCREEN) == null:
		return        # no PSX screen: the player and camera poll Input themselves
	_relay = InputRelay.new()
	_relay.name = "SandboxInputRelay"
	_relay.sandbox = self
	_ui_parent().add_child(_relay)


## Forwards one input event: combat buttons (with their real press time) to Red, mouse motion to the
## camera while the mouse is captured.
func handle_input_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _mouse_captured and _camera != null:
			_camera.add_mouse_motion((event as InputEventMouseMotion).relative)
		return
	if _player == null or not _player.has_method("handle_input_event"):
		return
	_player.call("handle_input_event", event)


## Lives in the sharp UI layer, which does get input events.
class InputRelay extends Node:
	var sandbox: CombatSandbox = null

	func _input(event: InputEvent) -> void:
		if sandbox != null and is_instance_valid(sandbox):
			sandbox.handle_input_event(event)
