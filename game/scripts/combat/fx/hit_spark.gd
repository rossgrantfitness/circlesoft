class_name HitSpark
extends Node3D
## A burst of sparks at a hit (and the same thing for parries, dodges and deaths): a bright flash, a handful of glowing
## streaks that fly out and fall, and optionally an expanding ring. All of it additive and unlit so the glow in the PS2 look
## blooms it; none of it casts a shadow. Profiles are data/combat/fx.json `sparks.<id>`.
##
## It frees itself when it is done. Real time on purpose: a spark should play out through the hit-stop it causes.
## Pure parts for tests: `make_particles()`, `step_particles()`, `streak_arrays()`.

const STREAK_SHADER: String = "res://shaders/sword_trail.gdshader"
const FLASH_SHADER: String = "res://shaders/fx_flash.gdshader"

var profile: Dictionary = {}
var normal: Vector3 = Vector3.UP
var seed_value: int = 0

var _particles: Array[Dictionary] = []
var _age: float = 0.0
var _life: float = 0.3
var _streaks: MeshInstance3D = null
var _streak_mesh: ArrayMesh = ArrayMesh.new()
var _streak_material: ShaderMaterial = null
var _flash: MeshInstance3D = null
var _flash_material: ShaderMaterial = null
var _ring: MeshInstance3D = null
var _ring_material: ShaderMaterial = null
var _color: Color = Color.WHITE
var _core: Color = Color.WHITE


## Makes a spark burst and adds it to `parent` at `world_position`. `direction` is the way the hit "points" (from the target
## toward the attacker, roughly); sparks fly in a cone around it.
static func spawn(parent: Node, world_position: Vector3, direction: Vector3, spark_profile: Dictionary, seed_in: int = 0) -> HitSpark:
	var spark: HitSpark = HitSpark.new()
	spark.profile = spark_profile
	spark.normal = direction.normalized() if direction.length() > 0.001 else Vector3.UP
	spark.seed_value = seed_in
	spark.top_level = true
	parent.add_child(spark)
	spark.global_position = world_position
	return spark


func _ready() -> void:
	_color = Color.html(str(profile.get("color", "#ffe2a8")))
	_core = Color.html(str(profile.get("core", "#ffffff")))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else randi()
	_particles = make_particles(profile, normal, rng)
	var flash_cfg: Dictionary = profile.get("flash", {}) as Dictionary
	var ring_cfg: Dictionary = profile.get("ring", {}) as Dictionary
	_life = maxf(float(profile.get("life_s", 0.25)), float(flash_cfg.get("life_s", 0.1)))
	_life = maxf(_life, float(ring_cfg.get("life_s", 0.0)))
	_streak_material = ShaderMaterial.new()
	_streak_material.shader = load(STREAK_SHADER) as Shader
	_streak_material.set_shader_parameter(&"glow", float(profile.get("glow", 2.0)))
	_streaks = _make_instance("Streaks", _streak_mesh, _streak_material)
	if not flash_cfg.is_empty():
		_flash_material = _flash_material_for(_core.lerp(_color, 0.35), float(flash_cfg.get("intensity", 2.5)), 0.0)
		_flash = _make_instance("Flash", _quad(float(flash_cfg.get("size_m", 0.5))), _flash_material)
	if not ring_cfg.is_empty():
		_ring_material = _flash_material_for(_color, float(flash_cfg.get("intensity", 2.5)) * 0.8, 1.0)
		_ring = _make_instance("Ring", _quad(1.0), _ring_material)
		_ring.scale = Vector3.ONE * 0.05
	_update()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	step_particles(_particles, delta, float(profile.get("gravity", 5.0)))
	_update()


func _update() -> void:
	var eye: Vector3 = Vector3.ZERO
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() and get_viewport() != null else null
	if camera != null:
		eye = camera.global_position
	_streak_mesh.clear_surfaces()
	var arrays: Array = streak_arrays(_particles, eye, float(profile.get("length_m", 0.3)), float(profile.get("width_m", 0.035)),
			float(profile.get("life_s", 0.25)), _color, _core, global_position)
	if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() >= 3:
		_streak_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var flash_cfg: Dictionary = profile.get("flash", {}) as Dictionary
	if _flash != null:
		var flash_life: float = maxf(float(flash_cfg.get("life_s", 0.1)), 0.001)
		var k: float = clampf(_age / flash_life, 0.0, 1.0)
		_flash.visible = k < 1.0
		_flash.scale = Vector3.ONE * lerpf(0.55, 1.15, k)
		_flash_material.set_shader_parameter(&"fade", 1.0 - k)
	var ring_cfg: Dictionary = profile.get("ring", {}) as Dictionary
	if _ring != null:
		var ring_life: float = maxf(float(ring_cfg.get("life_s", 0.2)), 0.001)
		var r: float = clampf(_age / ring_life, 0.0, 1.0)
		_ring.visible = r < 1.0
		_ring.scale = Vector3.ONE * lerpf(0.05, float(ring_cfg.get("max_m", 1.0)), 1.0 - (1.0 - r) * (1.0 - r))
		_ring_material.set_shader_parameter(&"fade", 1.0 - r)


func _make_instance(node_name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 4.0
	add_child(instance)
	return instance


static func _quad(size_m: float) -> QuadMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size_m, size_m)
	return quad


static func _flash_material_for(color: Color, intensity: float, ring_amount: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(FLASH_SHADER) as Shader
	material.set_shader_parameter(&"tint", color)
	material.set_shader_parameter(&"intensity", intensity)
	material.set_shader_parameter(&"ring", ring_amount)
	material.set_shader_parameter(&"ring_radius", 0.8)
	return material


# ---- pure parts ----

## The streaks of a burst: {pos (relative to the burst), vel, age, life}. Directions fill a cone (cone_deg is the full angle)
## around `direction`; speeds are drawn between the profile's two numbers. Deterministic for a seeded `rng`.
static func make_particles(spark_profile: Dictionary, direction: Vector3, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var count: int = int(spark_profile.get("count", 8))
	var speeds: Array = spark_profile.get("speed", [3.0, 6.0]) as Array
	var low: float = float(speeds[0])
	var high: float = float(speeds[1]) if speeds.size() > 1 else low
	var half_cone: float = deg_to_rad(float(spark_profile.get("cone_deg", 70.0))) * 0.5
	var life: float = float(spark_profile.get("life_s", 0.25))
	var axis: Vector3 = direction.normalized() if direction.length() > 0.001 else Vector3.UP
	var side: Vector3 = axis.cross(Vector3.UP)
	if side.length() < 0.01:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var up: Vector3 = axis.cross(side).normalized()
	for index: int in count:
		var spin: float = rng.randf() * TAU
		var tilt: float = half_cone * sqrt(rng.randf())
		var dir: Vector3 = axis * cos(tilt) + (side * cos(spin) + up * sin(spin)) * sin(tilt)
		out.append({"pos": Vector3.ZERO, "vel": dir.normalized() * rng.randf_range(low, high), "age": 0.0, "life": life * rng.randf_range(0.7, 1.0)})
	return out


## Moves the streaks on by `dt` (gravity pulls them down, a little drag slows them).
static func step_particles(particles: Array[Dictionary], dt: float, gravity: float) -> void:
	for particle: Dictionary in particles:
		var velocity: Vector3 = particle["vel"]
		velocity.y -= gravity * dt
		velocity *= maxf(1.0 - 2.2 * dt, 0.0)
		particle["vel"] = velocity
		particle["pos"] = (particle["pos"] as Vector3) + velocity * dt
		particle["age"] = float(particle["age"]) + dt


## Triangles for the streaks, facing the eye: each is a thin quad from its head back along its velocity. Fades with age;
## UV.x runs 0 (tail) to 1 (head). `origin` is the burst's world position (the particles are relative to it).
static func streak_arrays(particles: Array[Dictionary], eye: Vector3, length_m: float, width_m: float, default_life: float,
		color: Color, core: Color, origin: Vector3) -> Array:
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	for particle: Dictionary in particles:
		var life: float = maxf(float(particle.get("life", default_life)), 0.0001)
		var k: float = float(particle["age"]) / life
		if k >= 1.0:
			continue
		var velocity: Vector3 = particle["vel"]
		var speed: float = velocity.length()
		if speed < 0.01:
			continue
		var head: Vector3 = particle["pos"]
		var direction: Vector3 = velocity / speed
		var tail: Vector3 = head - direction * length_m * clampf(speed / 6.0, 0.35, 1.2)
		var to_eye: Vector3 = (eye - (origin + head)).normalized() if eye != Vector3.ZERO else Vector3.BACK
		var across: Vector3 = direction.cross(to_eye)
		across = across.normalized() * width_m * 0.5 if across.length() > 0.001 else Vector3.RIGHT * width_m * 0.5
		var tint: Color = core.lerp(color, clampf(k * 1.6, 0.0, 1.0))
		tint.a = (1.0 - k) * (1.0 - k)
		var quad: Array[Vector3] = [tail - across, tail + across, head + across, head - across]
		var quad_uv: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0)]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			vertices.append(quad[corner])
			colors.append(tint)
			uvs.append(quad_uv[corner])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return arrays
