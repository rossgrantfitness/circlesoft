class_name RobotYard
extends Node3D
## The robot yard (task CS-21): a big walled lot beside the combat arena, reached on foot through a gate in the arena's east wall.
## It holds the Technical Artist's scale props (crates, cars, lamp posts, containers, buildings 10 to 30 m) as smashable SmashProps,
## the loader robot parked with its boarding point, and the colossus standing with its dock_approach in front of it. Everything is
## placed from data/combat/robot_yard.json (by hand, plus a seeded city at the far end), so a layout change is a data edit.
##
## The yard knows nothing about boarding; RobotBoarding and ScaleController use it.

const DATA_ID: String = "combat/robot_yard"
const PROP_DIR: String = "res://art/placeholder/robots/props/"
const SMALL_PATH: String = "res://art/placeholder/robots/robot_small_ual.glb"
const HUGE_PATH: String = "res://art/placeholder/robots/robot_huge_ual.glb"
const LAYER_WORLD: int = 1

var data: Dictionary = {}
var props: Array[SmashProp] = []
var small_display: RobotDisplay = null
var huge_display: RobotDisplay = null
var lamps: Array[OmniLight3D] = []
## Names of things the data asked for that were not there (a missing model file).
var missing: Array[String] = []

var _sandbox: Node3D = null
var _scenes: Dictionary[String, PackedScene] = {}
var _small_home: Transform3D = Transform3D.IDENTITY
var _huge_home: Transform3D = Transform3D.IDENTITY
var _serial: int = 0


## Builds the yard under this node. `for_sandbox` supplies the tile materials (CombatSandbox.tile_material); null gives plain grey.
func build(for_sandbox: Node3D, override_data: Dictionary = {}) -> void:
	_sandbox = for_sandbox
	data = override_data if not override_data.is_empty() else _load_data()
	_build_ground()
	_build_robots()
	_build_props()
	_build_city()


func _load_data() -> Dictionary:
	var tree: SceneTree = get_tree()
	var db: Node = tree.root.get_node_or_null("DataDB") if tree != null else null
	return (db.call("get_dict", DATA_ID) as Dictionary) if db != null else {}


static func vec3(raw: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if raw is Array and (raw as Array).size() >= 3:
		var list: Array = raw as Array
		return Vector3(float(list[0]), float(list[1]), float(list[2]))
	return fallback


# ---- queries ----

## The yard's floor as a rectangle in x (east) and z (south).
func zone_rect() -> Rect2:
	var floor_cfg: Dictionary = data.get("floor", {}) as Dictionary
	var x0: float = float(floor_cfg.get("x_min", 21.0))
	var z0: float = float(floor_cfg.get("z_min", -320.0))
	return Rect2(x0, z0, float(floor_cfg.get("x_max", 721.0)) - x0, float(floor_cfg.get("z_max", 320.0)) - z0)


func contains(point: Vector3) -> bool:
	return zone_rect().has_point(Vector2(point.x, point.z))


## Where the gate in the arena's east wall is (the middle of the gap, on the floor).
func gate_position() -> Vector3:
	var west_x: float = float((data.get("walls", {}) as Dictionary).get("west_x", 24.0))
	return Vector3(west_x, 0.0, float((data.get("gate", {}) as Dictionary).get("center_z", 0.0)))


func gate_width_m() -> float:
	return float((data.get("gate", {}) as Dictionary).get("width_m", 8.0))


func alive_count() -> int:
	var n: int = 0
	for prop: SmashProp in props:
		if is_instance_valid(prop) and not prop.dead:
			n += 1
	return n


func smashed_count() -> int:
	return props.size() - alive_count()


## Props still standing whose footprint is within `radius` (flat distance from the footprint's middle, less the prop's own
## half-width) of `point`.
func props_within(point: Vector3, radius: float) -> Array[SmashProp]:
	var out: Array[SmashProp] = []
	for prop: SmashProp in props:
		if not is_instance_valid(prop) or prop.dead:
			continue
		var centre: Vector3 = prop.centre_world()
		var gap: float = Vector2(centre.x - point.x, centre.z - point.z).length() - prop.stomp_radius_m * 0.6
		if gap <= radius:
			out.append(prop)
	return out


func home_of(kind: StringName) -> Transform3D:
	return _small_home if kind == RobotDisplay.KIND_SMALL else _huge_home


## Stands everything back up and puts both robots back where they started.
func reset() -> void:
	for prop: SmashProp in props:
		if is_instance_valid(prop):
			prop.reset_prop()
	if small_display != null:
		small_display.global_transform = _small_home
		small_display.set_hatch_open(0.0)
		small_display.set_active(true)
		small_display.play(&"idle")
	if huge_display != null:
		huge_display.global_transform = _huge_home
		huge_display.set_doors_open(0.0)
		huge_display.set_active(true)
		huge_display.play(&"idle")


# ---- ground and walls ----

func _build_ground() -> void:
	var ground: Node3D = Node3D.new()
	ground.name = "Ground"
	add_child(ground)
	var floor_cfg: Dictionary = data.get("floor", {}) as Dictionary
	var rect: Rect2 = zone_rect()
	var tile: String = str(floor_cfg.get("tile", ""))
	var floor_tile_m: float = float(floor_cfg.get("tile_m", 6.0))
	_box(ground, "Floor", Vector3(rect.position.x + rect.size.x * 0.5, -0.2, rect.position.y + rect.size.y * 0.5),
			Vector3(rect.size.x, 0.4, rect.size.y), tile, floor_tile_m)
	var walls: Dictionary = data.get("walls", {}) as Dictionary
	var height: float = float(walls.get("height_m", 100.0))
	var thick: float = float(walls.get("thickness_m", 4.0))
	var wall_tile: String = str(walls.get("tile", ""))
	var wall_m: float = float(walls.get("tile_m", 8.0))
	var west_x: float = float(walls.get("west_x", 24.0))
	var east_x: float = rect.end.x + thick * 0.5
	var z_min: float = rect.position.y
	var z_max: float = rect.end.y
	var span_x: float = east_x - west_x + thick
	_box(ground, "WallEast", Vector3(east_x, height * 0.5, (z_min + z_max) * 0.5), Vector3(thick, height, z_max - z_min + thick * 2.0), wall_tile, wall_m)
	_box(ground, "WallNorth", Vector3((west_x + east_x) * 0.5, height * 0.5, z_min - thick * 0.5), Vector3(span_x, height, thick), wall_tile, wall_m)
	_box(ground, "WallSouth", Vector3((west_x + east_x) * 0.5, height * 0.5, z_max + thick * 0.5), Vector3(span_x, height, thick), wall_tile, wall_m)
	# the west wall has the gate: two pieces with the gap between
	var gate: Dictionary = data.get("gate", {}) as Dictionary
	var gate_z: float = float(gate.get("center_z", 0.0))
	var half_gap: float = float(gate.get("width_m", 8.0)) * 0.5
	var north_len: float = (gate_z - half_gap) - (z_min - thick)
	var south_len: float = (z_max + thick) - (gate_z + half_gap)
	_box(ground, "WallWestNorth", Vector3(west_x, height * 0.5, (z_min - thick) + north_len * 0.5), Vector3(thick, height, north_len), wall_tile, wall_m)
	_box(ground, "WallWestSouth", Vector3(west_x, height * 0.5, (gate_z + half_gap) + south_len * 0.5), Vector3(thick, height, south_len), wall_tile, wall_m)


func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, tile: String, tile_m: float) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1 << (LAYER_WORLD - 1)
	body.collision_mask = 0
	parent.add_child(body)
	body.position = pos
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.mesh = CombatSandbox._box_mesh(size, maxf(tile_m, 0.1))
	mesh_node.material_override = _material(tile)
	body.add_child(mesh_node)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	return body


func _material(tile: String) -> Material:
	if _sandbox != null and _sandbox.has_method("tile_material"):
		return _sandbox.call("tile_material", tile, Vector2.ONE) as Material
	var plain: StandardMaterial3D = StandardMaterial3D.new()
	plain.albedo_color = Color(0.34, 0.35, 0.38)
	return plain


# ---- the robots ----

func _build_robots() -> void:
	var small_cfg: Dictionary = data.get("small_robot", {}) as Dictionary
	var huge_cfg: Dictionary = data.get("huge_robot", {}) as Dictionary
	small_display = RobotDisplay.new()
	small_display.name = "ParkedLoader"
	add_child(small_display)
	if not small_display.setup(RobotDisplay.KIND_SMALL, SMALL_PATH):
		missing.append(SMALL_PATH)
	_small_home = _transform_of(small_cfg)
	small_display.global_transform = _small_home
	huge_display = RobotDisplay.new()
	huge_display.name = "StandingColossus"
	add_child(huge_display)
	if not huge_display.setup(RobotDisplay.KIND_HUGE, HUGE_PATH):
		missing.append(HUGE_PATH)
	_huge_home = _transform_of(huge_cfg)
	huge_display.global_transform = _huge_home
	small_display.hatch_open_deg = ScaleProfile.sequence_value("hatch_open_deg", -100.0)
	huge_display.door_open_deg = float(ScaleProfile.sequence(&"dock").get("door_open_deg", 100.0))
	small_display.set_hatch_open(0.0)
	huge_display.set_doors_open(0.0)


func _transform_of(cfg: Dictionary) -> Transform3D:
	var yaw: float = deg_to_rad(float(cfg.get("yaw_deg", 0.0)))
	return Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), vec3(cfg.get("pos", [0.0, 0.0, 0.0])))


# ---- props ----

func _build_props() -> void:
	var kinds: Dictionary = data.get("kinds", {}) as Dictionary
	for raw: Variant in data.get("props", []) as Array:
		var entry: Dictionary = raw as Dictionary
		_add_prop(StringName(str(entry.get("kind", ""))), vec3(entry.get("pos")), float(entry.get("yaw_deg", 0.0)), kinds)
	_build_lamps()


func _add_prop(kind: StringName, pos: Vector3, yaw_deg: float, kinds: Dictionary) -> SmashProp:
	var cfg: Dictionary = kinds.get(String(kind), {}) as Dictionary
	if cfg.is_empty():
		missing.append("prop kind " + String(kind))
		return null
	var path: String = PROP_DIR + str(cfg.get("model", "")) + ".glb"
	var packed: PackedScene = _scene(path)
	if packed == null:
		return null
	var model: Node3D = packed.instantiate() as Node3D
	if model == null:
		return null
	model.name = "Model"
	Ps2Look.upgrade_model(model, path, LookProfiles.active())
	var prop: SmashProp = SmashProp.new()
	_serial += 1
	prop.setup(StringName("%s_%d" % [kind, _serial]), kind, cfg, model)
	prop.name = "%s_%d" % [kind, _serial]
	prop.position = pos
	prop.rotation.y = deg_to_rad(yaw_deg)
	add_child(prop)
	props.append(prop)
	return prop


func _scene(path: String) -> PackedScene:
	if _scenes.has(path):
		return _scenes[path]
	if not ResourceLoader.exists(path):
		missing.append(path)
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed != null:
		_scenes[path] = packed
	return packed


## A sodium lamp on the first few lamp posts (few, so the lights stay cheap).
func _build_lamps() -> void:
	var cfg: Dictionary = data.get("lamps", {}) as Dictionary
	var limit: int = int(cfg.get("max_lit", 6))
	for prop: SmashProp in props:
		if lamps.size() >= limit:
			break
		if prop.kind != &"lamp_post":
			continue
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Lamp_%s" % prop.name
		light.light_color = Color.html(str(cfg.get("color", "#ff9a3c")))
		light.light_energy = float(cfg.get("energy", 2.2))
		light.omni_range = float(cfg.get("range_m", 16.0))
		add_child(light)
		light.global_position = prop.global_transform * Vector3(float(cfg.get("arm_m", 1.5)), float(cfg.get("height_m", 6.2)), 0.0)
		lamps.append(light)


## The far end: a grid of buildings with some jitter, cars and crates in the gaps, the same every run (seeded).
func _build_city() -> void:
	var city: Dictionary = data.get("city", {}) as Dictionary
	if city.is_empty():
		return
	var kinds: Dictionary = data.get("kinds", {}) as Dictionary
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(city.get("seed", 1))
	var xs: Array = city.get("x_range", [0.0, 0.0]) as Array
	var zs: Array = city.get("z_range", [0.0, 0.0]) as Array
	var step: Array = city.get("step", [60.0, 60.0]) as Array
	var jitter: float = float(city.get("jitter", 0.0))
	var skip: float = float(city.get("skip_chance", 0.0))
	var types: Array = city.get("kinds", ["building_10m"]) as Array
	var keep_out: Array = city.get("keep_out", []) as Array
	var index: int = 0
	var x: float = float(xs[0])
	while x <= float(xs[1]):
		var z: float = float(zs[0])
		while z <= float(zs[1]):
			var at: Vector3 = Vector3(x + rng.randf_range(-jitter, jitter), 0.0, z + rng.randf_range(-jitter, jitter))
			var roll: float = rng.randf()
			var kind: String = str(types[index % types.size()])
			index += 1
			if roll >= skip and not _kept_out(at, keep_out):
				var yaw: float = 0.0 if at.z < 0.0 else 180.0       # doors toward the avenue
				_add_prop(StringName(kind), at, yaw + rng.randf_range(-6.0, 6.0), kinds)
			z += float(step[1])
		x += float(step[0])
	for i: int in int(city.get("cars", 0)):
		var car_at: Vector3 = Vector3(rng.randf_range(float(xs[0]), float(xs[1])), 0.0, rng.randf_range(float(zs[0]), float(zs[1])))
		if not _near_prop(car_at, 14.0):
			_add_prop(&"car", car_at, rng.randf_range(0.0, 360.0), kinds)
	for i: int in int(city.get("crates", 0)):
		var crate_at: Vector3 = Vector3(rng.randf_range(float(xs[0]), float(xs[1])), 0.0, rng.randf_range(float(zs[0]), float(zs[1])))
		if not _near_prop(crate_at, 8.0):
			_add_prop(&"crate_large" if rng.randf() < 0.5 else &"crate_small", crate_at, rng.randf_range(0.0, 360.0), kinds)


static func _kept_out(at: Vector3, rects: Array) -> bool:
	for raw: Variant in rects:
		var r: Array = raw as Array
		if at.x >= float(r[0]) and at.x <= float(r[2]) and at.z >= float(r[1]) and at.z <= float(r[3]):
			return true
	return false


func _near_prop(at: Vector3, radius: float) -> bool:
	for prop: SmashProp in props:
		var centre: Vector3 = prop.position
		if Vector2(centre.x - at.x, centre.z - at.z).length() < radius + prop.stomp_radius_m:
			return true
	return false
