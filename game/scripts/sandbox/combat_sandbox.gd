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
var _materials: Dictionary[String, Material] = {}
var _relay: InputRelay = null
var _mouse_captured: bool = false
## Tests set this to a Input.MouseMode value to stand in for the real window's mouse mode (-1 = ask Input).
var mouse_mode_override: int = -1
var _world_environment: WorldEnvironment = null
var _enemy_serial: int = 0
# The robot zone (CS-21): a yard through the east gate, the loader and the colossus, and what sizes Red up.
var _robot_yard: RobotYard = null
var _scale_controller: ScaleController = null
var _robot_boarding: RobotBoarding = null


func _ready() -> void:
	_data = _load_data()
	add_to_group(&"combat_sandbox")
	_setup_screen()
	_apply_look()          # first, so everything built below knows which profile (grim_ps2) it is dressing for
	_build_arena()
	_attach_parts(false)
	_setup_feel()
	_spawn_player()
	_attach_parts(true)
	_spawn_enemies()
	_build_racks()
	_build_robot_zone()
	_make_relay()
	_apply_look()
	if bool(_data.get("capture_mouse", true)):
		set_mouse_captured(true)
	print_verbose("CombatSandbox: ready; parts not there yet: %s" % [missing])


func _exit_tree() -> void:
	set_mouse_captured(false)
	if _relay != null and is_instance_valid(_relay):
		_relay.queue_free()
	for node: Node in _attached:
		if is_instance_valid(node) and node.get_parent() != self:
			if node.has_method("unbind"):
				node.call("unbind")        # let go of the director while it is still alive
			node.queue_free()
	_attached.clear()


func _physics_process(_delta: float) -> void:
	tick()


## Per-frame housekeeping: anything that fell out of the world goes back to its spawn.
func tick() -> void:
	_update_rack_labels()
	if _player != null and _player.global_position.y < FALL_LIMIT_Y:
		_place_player()
	for enemy: Node3D in _enemies:
		if is_instance_valid(enemy) and enemy.global_position.y < FALL_LIMIT_Y:
			enemy.global_position = Vector3(0.0, 0.5, 0.0)
			if enemy is CharacterBody3D:
				(enemy as CharacterBody3D).velocity = Vector3.ZERO


# ---- binding ----

## Only the stand nearest to Red shows its name (and only when she is close, which the stand checks).
func _update_rack_labels() -> void:
	if _player == null:
		return
	var nearest: SwordRack = null
	var best: float = INF
	for rack: SwordRack in _racks:
		var d: float = rack.global_position.distance_squared_to(_player.global_position)
		if d < best:
			best = d
			nearest = rack
	for rack: SwordRack in _racks:
		rack.label_enabled = rack == nearest


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


func get_robot_yard() -> RobotYard:
	return _robot_yard


func get_scale_controller() -> ScaleController:
	return _scale_controller


func get_robot_boarding() -> RobotBoarding:
	return _robot_boarding


## The sharp UI layer (menus and prompts stay crisp over the low-res picture).
func get_ui_parent() -> Node:
	return _ui_parent()


## A material for one of Ross's city tiles in the current look (the robot yard dresses its floor and walls with it).
func tile_material(tile_id: String, uv_scale: Vector2 = Vector2.ONE) -> Material:
	return _material_for(tile_id, uv_scale)


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
	_reset_director()
	if _robot_boarding != null:
		_robot_boarding.reset()          # Red's body, the loader and the colossus back where they started
	if _player != null and _player.has_method("reset_to"):
		_player.call("reset_to", get_player_spawn())
	elif _player != null:
		_player.global_transform = get_player_spawn()
	_spawn_enemies()
	if _camera != null:
		_camera.recenter()
		_camera.snap()
	arena_reset.emit()


## Noise back to empty, any Lamp Flare over, so a reset really is a fresh start.
func _reset_director() -> void:
	if _director == null:
		return
	if _director.has_method("reset"):
		_director.call("reset")
		return
	if _director is CombatDirector:
		var director: CombatDirector = _director as CombatDirector
		if director.style != null:
			director.style.reset()
		if director.time != null:
			director.time.end_flare()


func get_player_spawn() -> Transform3D:
	var spawn: Dictionary = _data.get("player_spawn", {}) as Dictionary
	var pos: Vector3 = _vec3(spawn.get("pos", [0.0, 0.1, 12.0]))
	var yaw: float = deg_to_rad(float(spawn.get("yaw_deg", 180.0)))
	return Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), pos)


## Captures or frees the mouse (the pause menu and the feel panel free it). Headless runs never capture.
func set_mouse_captured(captured: bool) -> void:
	_mouse_captured = captured
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _current_mouse_mode() -> int:
	return mouse_mode_override if mouse_mode_override >= 0 else int(Input.mouse_mode)


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
	# The look profile's own screen block (native by default) wins over this fallback size.
	if Ps2Look.is_ps2_profile(LookProfiles.profile(str(_data.get("look_profile", "grim_ps2")))):
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
	_build_east_wall(level, size, wall_h, wall_t, str(arena.get("wall_tile", "")))
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
		_add_ramp(level, "Ramp%d" % index, raw as Dictionary, str(arena.get("ledge_tile", "")))
		index += 1
	_build_lighting()


## The east wall: whole, or with the gate to the robot yard (a gap, data/combat/robot_yard.json "gate") when the robot zone is on.
func _build_east_wall(level: Node3D, size: Vector2, wall_h: float, wall_t: float, tile: String) -> void:
	var x: float = size.x * 0.5 + wall_t * 0.5
	var gate: Dictionary = robot_gate()
	if gate.is_empty():
		_add_box(level, "WallEast", Vector3(x, wall_h * 0.5, 0.0), Vector3(wall_t, wall_h, size.y), Vector3.ZERO, tile)
		return
	var centre: float = float(gate.get("center_z", 0.0))
	var half: float = float(gate.get("width_m", 8.0)) * 0.5
	var top: float = -size.y * 0.5 - wall_t          # wall's far ends, matching the other walls' overhang
	var bottom: float = size.y * 0.5 + wall_t
	var north_len: float = (centre - half) - top
	var south_len: float = bottom - (centre + half)
	_add_box(level, "WallEastNorth", Vector3(x, wall_h * 0.5, top + north_len * 0.5), Vector3(wall_t, wall_h, north_len), Vector3.ZERO, tile)
	_add_box(level, "WallEastSouth", Vector3(x, wall_h * 0.5, centre + half + south_len * 0.5), Vector3(wall_t, wall_h, south_len), Vector3.ZERO, tile)


## The gate in the east wall ({center_z, width_m}), or empty when the robot zone is off.
func robot_gate() -> Dictionary:
	if not bool(_block("robot_zone").get("enabled", false)):
		return {}
	var db: Node = get_node_or_null("/root/DataDB")
	if db == null:
		return {}
	return db.call("get_value", RobotYard.DATA_ID, "gate", {}) as Dictionary


## A solid wedge ramp: it starts flat on the floor at `pos`, runs `length_m` along `dir` (flat) and ends
## `rise_m` high, `width_m` across. Solid down to the floor, so there is no lip at the foot and the top
## meets the ledge it leads to. Collision is the same wedge as a convex shape.
func _add_ramp(parent: Node3D, node_name: String, cfg: Dictionary, tile: String) -> void:
	var dir: Vector3 = _vec3(cfg.get("dir", [0.0, 0.0, -1.0]))
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	var half_w: float = float(cfg.get("width_m", 4.0)) * 0.5
	var length: float = float(cfg.get("length_m", 6.0))
	var rise: float = float(cfg.get("rise_m", 1.2))
	var toe: Vector3 = Vector3(_vec3(cfg.get("pos")).x, 0.0, _vec3(cfg.get("pos")).z)
	var points: Array[Vector3] = [
		-side * half_w, side * half_w,                                           # toe, on the floor
		dir * length - side * half_w, dir * length + side * half_w,              # the far foot
		dir * length - side * half_w + Vector3.UP * rise, dir * length + side * half_w + Vector3.UP * rise,   # the top edge
	]
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1 << (LAYER_WORLD - 1)
	body.collision_mask = 0
	parent.add_child(body)
	body.position = toe
	var tile_m: float = maxf(float(_block("arena").get("tile_m", 2.0)), 0.1)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre: Vector3 = Vector3.ZERO
	for point: Vector3 in points:
		centre += point / float(points.size())
	# faces as point-index loops: slope, back, floor, two sides
	for loop: Array in [[0, 1, 5, 4], [2, 3, 5, 4], [0, 1, 3, 2], [0, 2, 4], [1, 3, 5]]:
		var ring: Array[Vector3] = []
		for index: int in loop:
			ring.append(points[index])
		var normal: Vector3 = (ring[1] - ring[0]).cross(ring[2] - ring[0]).normalized()
		var face_centre: Vector3 = Vector3.ZERO
		for point: Vector3 in ring:
			face_centre += point / float(ring.size())
		if normal.dot(face_centre - centre) < 0.0:
			ring.reverse()
			normal = -normal
		# ring is now counter-clockwise from outside; Godot's front faces are clockwise, so emit reversed
		for tri: int in range(1, ring.size() - 1):
			for corner: Vector3 in [ring[0], ring[tri + 1], ring[tri]]:
				tool.set_normal(normal)
				tool.set_uv(Vector2(corner.dot(side) + half_w, -(corner.dot(dir) + corner.y * 2.0)) / tile_m)
				tool.add_vertex(corner)
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.mesh = tool.commit()
	mesh_node.material_override = _material_for(tile)
	body.add_child(mesh_node)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array(points)
	shape_node.shape = shape
	body.add_child(shape_node)


func _add_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, rot_deg: Vector3, tile: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1 << (LAYER_WORLD - 1)
	body.collision_mask = 0
	parent.add_child(body)
	body.position = pos
	body.rotation_degrees = rot_deg
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var tile_m: float = maxf(float(_block("arena").get("tile_m", 2.0)), 0.1)
	mesh_node.mesh = _box_mesh(size, tile_m)
	mesh_node.material_override = _material_for(tile)
	body.add_child(mesh_node)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	return body


## A box whose UVs are in tile repeats (metres / tile_m) on every face, so a big floor and a thin wall
## get the same texel density. Front faces are clockwise, as Godot wants.
static func _box_mesh(size: Vector3, tile_m: float) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: Vector3 = size * 0.5
	# [normal, u axis, v axis] with u x v = normal
	var faces: Array[Array] = [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for face: Array in faces:
		var n: Vector3 = face[0]
		var t: Vector3 = face[1]
		var b: Vector3 = face[2]
		var hn: float = absf(n.dot(half))
		var ht: float = absf(t.dot(half))
		var hb: float = absf(b.dot(half))
		var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1)]
		var points: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for c: Vector2 in corners:
			points.append(n * hn + t * ht * c.x + b * hb * c.y)
			uvs.append(Vector2((c.x + 1.0) * ht, (1.0 - c.y) * hb) / tile_m)
		for index: int in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(n)
			tool.set_uv(uvs[index])
			tool.add_vertex(points[index])
	return tool.commit()


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
	var tile_m: float = maxf(float(_block("arena").get("tile_m", 2.0)), 0.1)
	mesh_node.material_override = _material_for(tile, Vector2(TAU * radius / tile_m, height / tile_m))
	body.add_child(mesh_node)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	shape_node.shape = shape
	body.add_child(shape_node)


## The look profile everything in the arena is dressed for.
func _profile() -> Dictionary:
	return LookProfiles.active()


## A material for a city tile. With a texture it is the PS2 material from Ps2Look (so the texture filter and
## the light grade come from the look profile's data); without one, plain grey. `uv_scale` is how many
## tile repeats the surface covers (set per surface, because the PS2 shader maps by UV).
func _material_for(tile_id: String, uv_scale: Vector2 = Vector2.ONE) -> Material:
	var key: String = "%s|%.3f|%.3f" % [tile_id, uv_scale.x, uv_scale.y]
	if _materials.has(key):
		return _materials[key]
	var arena: Dictionary = _block("arena")
	var texture: Texture2D = _tile_texture(tile_id)
	var material: Material = null
	if texture != null:
		var shader_material: ShaderMaterial = Ps2Look.make_material(texture, "city_tiles", _profile())
		shader_material.set_shader_parameter(&"uv_scale", uv_scale)
		material = shader_material
	else:
		var grey: Array = arena.get("grey", [0.34, 0.35, 0.38]) as Array
		var plain: StandardMaterial3D = StandardMaterial3D.new()
		plain.albedo_color = Color(float(grey[0]), float(grey[1]), float(grey[2]))
		plain.roughness = 0.9
		plain.metallic_specular = 0.2
		material = plain
		if not tile_id.is_empty() and not missing.has("tile " + tile_id):
			missing.append("tile " + tile_id)
	_materials[key] = material
	return material


## The tile's picture: the seam-fixed copy when the atlas says there is one (`seamless_copy`, or
## `seamless_copy_busted`), else the original slice.
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
	var candidates: Array[String] = []
	var entry: Dictionary = _atlas_entry(db, tile_id)
	var flag: String = "seamless_copy" if variant == "clean" else "seamless_copy_" + variant
	if bool(entry.get(flag, false)):
		var seamless_dir: String = str(db.call("get_value", ATLAS_ID, "variants.%s.seamless_dir" % variant, ""))
		if seamless_dir.is_empty():
			seamless_dir = dir.trim_suffix("/") + "_seamless/"
		candidates.append(seamless_dir.path_join(tile_id + ".png"))
	candidates.append(dir.path_join(tile_id + ".png"))
	for path: String in candidates:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


func _atlas_entry(db: Node, tile_id: String) -> Dictionary:
	for raw: Variant in db.call("get_value", ATLAS_ID, "tiles", []) as Array:
		if (raw as Dictionary).get("id", "") == tile_id:
			return raw as Dictionary
	return {}


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
	# The PS2 look: smooth 640x360 picture, retro effects off, glow and the key light's shadow, all from the profile.
	var ps2: Ps2Look = Ps2Look.new()
	ps2.name = "Ps2Look"
	add_child(ps2)
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
	if "knobs" in _player:
		_player.set("knobs", _feel)
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
	var spawns: Array = (_data.get("enemy_spawns", []) as Array).duplicate()
	if bool(_block("robot_zone").get("enabled", false)):
		spawns.append_array(_block("robot_zone").get("enemy_spawns", []) as Array)
	for raw: Variant in spawns:
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
		rack.ring_scale = float(racks.get("ring_scale", 0.6))
		rack.label_show_m = float(racks.get("label_show_m", 3.0))
		rack.label_fade_m = float(racks.get("label_fade_m", 1.0))
		rack.watch = _player
		rack.position = _vec3(stand.get("pos"))
		holder.add_child(rack)
		_racks.append(rack)


## The robot zone (CS-21): the yard, the controller that sizes Red up, and the boarding that decides who is in control.
func _build_robot_zone() -> void:
	if not bool(_block("robot_zone").get("enabled", false)) or _player == null:
		return
	_robot_yard = RobotYard.new()
	_robot_yard.name = "RobotYard"
	add_child(_robot_yard)
	_robot_yard.build(self)
	for entry: String in _robot_yard.missing:
		missing.append("robot yard: " + entry)
	_scale_controller = ScaleController.new()
	_scale_controller.name = "ScaleController"
	add_child(_scale_controller)
	_scale_controller.bind(self, _player as ActionPlayer, _camera, _lock, _robot_yard)
	_robot_boarding = RobotBoarding.new()
	_robot_boarding.name = "RobotBoarding"
	add_child(_robot_boarding)
	_robot_boarding.bind(self, _player as ActionPlayer, _camera, _scale_controller, _robot_yard)


func _find_actor(actor_id: StringName) -> Node3D:
	if _director is CombatDirector:
		var found: CombatActor = (_director as CombatDirector).get_actor(actor_id)
		if found != null:
			return found
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
		if layer == "stage":
			UiStage.get_or_create(get_tree()).get_stage_root().add_child(node)
		elif layer == "ui":
			_ui_parent().add_child(node)
		else:
			add_child(node)
		if bool(entry.get("bind", false)) and node.has_method("bind"):
			node.call("bind", self)
		_give_feel_to(node)


## A HUD whose feel panel found no director knobs gets the sandbox's own, so F12 always has sliders.
func _give_feel_to(node: Node) -> void:
	if _feel == null or not node.has_method("get_feel_panel"):
		return
	var panel: Object = node.call("get_feel_panel") as Object
	if panel != null and panel.get("knobs") == null and panel.has_method("bind"):
		panel.call("bind", _feel)


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
		# Only while the mouse really is captured: the pause menu and feel panel free it (SandboxPauseGate
		# remembers CAPTURED and gives it back), and then the camera must not turn.
		if _mouse_captured and _current_mouse_mode() == Input.MOUSE_MODE_CAPTURED and _camera != null:
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
