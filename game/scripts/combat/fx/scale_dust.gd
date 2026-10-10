class_name ScaleDust
extends Node3D
## Footstep dust and landing slam clouds for the robot scale test (task CS-21). One burst of soft puffs that fly out from a ring on
## the floor, grow, rise a little and fade, plus (for slams) an expanding shock ring on the ground. Bigger and slower at large
## scale: every number is in data/combat/fx.json `dust.<id>` (step_small, land_small, step_huge, land_huge).
## Real time, like the other hit effects. The puffs are plain billboards, so it works in the PS2 and the old look alike.
##
##   ScaleDust.spawn(world_node, foot_position, &"step_huge")
##
## The pure parts (puffs, state) are static so the tests can check the shape of a burst without a renderer.

const DATA_ID: String = "combat/fx"
const DRAG_PER_S: float = 1.8
const RING_FLOOR_LIFT_M: float = 0.05

var config: Dictionary = {}
var _puffs: Array[Dictionary] = []
var _nodes: Array[MeshInstance3D] = []
var _age: float = 0.0
var _life: float = 1.0
var _ring: MeshInstance3D = null
var _ring_material: StandardMaterial3D = null


## The dust profile for an id from fx.json (empty if the data or the id is not there).
static func profile(id: StringName) -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var db: Node = tree.root.get_node_or_null("DataDB") if tree != null else null
	if db == null:
		return {}
	var found: Variant = db.call("get_value", DATA_ID, "dust.%s" % id, null)
	return found as Dictionary if found is Dictionary else {}


## Starts a burst at `at` (a point on the floor). `id` is a key of fx.json `dust`; `override` replaces the data (tests, tuning).
static func spawn(parent: Node, at: Vector3, id: StringName, override: Dictionary = {}) -> ScaleDust:
	var cfg: Dictionary = override if not override.is_empty() else profile(id)
	if cfg.is_empty():
		return null
	var dust: ScaleDust = ScaleDust.new()
	dust.config = cfg
	dust.top_level = true
	parent.add_child(dust)
	dust.global_position = at
	return dust


## The puffs of a burst: start offset, velocity and start size of each, evenly around the ring with a little spread (seeded, so a
## burst is the same every time for the same seed).
static func puffs(cfg: Dictionary, seed_value: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = int(cfg.get("count", 0))
	var radius: float = float(cfg.get("ring_radius_m", 0.0))
	var speed: Array = cfg.get("speed_mps", [1.0, 2.0]) as Array
	var size: Array = cfg.get("size_m", [0.5, 1.0]) as Array
	var rise: float = float(cfg.get("rise_mps", 0.0))
	for i: int in count:
		var angle: float = TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / float(maxi(count, 1))
		var outward: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var v: float = rng.randf_range(float(speed[0]), float(speed[1]))
		out.append({
			"start": outward * radius * 0.6,
			"velocity": outward * v + Vector3.UP * rise * rng.randf_range(0.6, 1.2),
			"size": rng.randf_range(float(size[0]), float(size[1])),
		})
	return out


## Where one puff is, how wide and how see-through, `age_s` seconds into the burst.
static func state(puff: Dictionary, cfg: Dictionary, age_s: float) -> Dictionary:
	var life: float = maxf(float(cfg.get("life_s", 1.0)), 0.001)
	var k: float = clampf(age_s / life, 0.0, 1.0)
	var drag: float = (1.0 - exp(-DRAG_PER_S * age_s)) / DRAG_PER_S          # distance factor of a drag-slowed velocity
	var velocity: Vector3 = puff["velocity"] as Vector3
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * drag
	var up: float = velocity.y * drag + 0.5 * float(cfg.get("gravity", 0.0)) * age_s * age_s
	var position: Vector3 = (puff["start"] as Vector3) + horizontal + Vector3.UP * maxf(up, 0.0)
	var width: float = float(puff["size"]) * lerpf(1.0, float(cfg.get("grow", 2.0)), sqrt(k))
	var fade: float = pow(1.0 - k, 1.5) * minf(age_s / 0.08, 1.0)               # a quick fade-in so it does not pop
	return {"position": position, "size": width, "alpha": float(cfg.get("alpha", 0.5)) * fade}


func _ready() -> void:
	_life = maxf(float(config.get("life_s", 1.0)), 0.05)
	_puffs = puffs(config, int(global_position.x * 7.0 + global_position.z * 13.0) + 1)
	var color: Color = Color.html(str(config.get("color", "#8b857a")))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	for puff: Dictionary in _puffs:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2.ONE
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true
		material.albedo_texture = texture
		material.albedo_color = Color(color.r, color.g, color.b, 0.0)
		material.no_depth_test = false
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = quad
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_nodes.append(instance)
	var ring: Dictionary = config.get("shock_ring", {}) as Dictionary
	if not ring.is_empty():
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.96
		torus.outer_radius = 1.0
		torus.rings = 24
		torus.ring_segments = 4
		_ring_material = StandardMaterial3D.new()
		_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_material.albedo_color = Color(1.0, 0.92, 0.8, 0.0)
		_ring = MeshInstance3D.new()
		_ring.mesh = torus
		_ring.material_override = _ring_material
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.position = Vector3(0.0, RING_FLOOR_LIFT_M, 0.0)
		add_child(_ring)
	_update(0.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_update(_age)


func _update(age_s: float) -> void:
	for i: int in _puffs.size():
		var s: Dictionary = state(_puffs[i], config, age_s)
		var instance: MeshInstance3D = _nodes[i]
		instance.position = s["position"] as Vector3 + Vector3.UP * float(s["size"]) * 0.35
		instance.scale = Vector3.ONE * float(s["size"])
		var material: StandardMaterial3D = instance.material_override as StandardMaterial3D
		var color: Color = material.albedo_color
		color.a = float(s["alpha"])
		material.albedo_color = color
	if _ring != null:
		var ring: Dictionary = config.get("shock_ring", {}) as Dictionary
		var ring_life: float = maxf(float(ring.get("life_s", 0.5)), 0.01)
		var k: float = clampf(age_s / ring_life, 0.0, 1.0)
		var radius: float = maxf(float(ring.get("max_m", 1.0)) * (1.0 - pow(1.0 - k, 3.0)), 0.01)
		_ring.scale = Vector3(radius, 0.05 + radius * 0.01, radius)
		_ring.visible = k < 1.0
		var color: Color = _ring_material.albedo_color
		color.a = (1.0 - k) * minf(float(ring.get("intensity", 1.0)) * 0.35, 0.9)
		_ring_material.albedo_color = color
