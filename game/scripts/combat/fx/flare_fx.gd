class_name FlareFx
extends Node3D
## The two big looks of Red's lamp (combat_api.md 4.4, 4.5, 6):
##   * the LAMP FLARE: a perfect dodge or parry flares her lamp. A hot burst of light on her, a shock ring, a flash, and a cooler,
##     calmer world (less colour, a touch darker, more glow) for as long as the enemies run slow.
##   * LIGHTS ON: while the power mode runs her lamp stays lit, her edge light brightens and the neon strips on her jacket glow.
## Real time, not combat time: it is a picture of the slow-mo, so it must not slow down with it. Numbers: fx.json `flare`, `lights_on`.
## Pure parts for tests: `lamp_energy()`, `boost_materials()` / `restore_materials()`.

const FLASH_SHADER: String = "res://shaders/fx_flash.gdshader"
const RING_LIFE_FALLBACK: float = 0.5

var config: Dictionary = {}          # fx.json "flare"
var lights_config: Dictionary = {}   # fx.json "lights_on"
## Who the lamp rides on (anything with anchor(&"lamp")), and whose model gets the Lights On glow (anything with get_model()).
var follow: Node3D = null
var world_environment: WorldEnvironment = null

var _flaring: bool = false
var _t: float = 0.0
var _duration: float = 1.0
var _lamp: OmniLight3D = null
var _flash: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _flash_material: ShaderMaterial = null
var _ring_material: ShaderMaterial = null
var _saved_environment: Dictionary = {}
var _lights_on: bool = false
var _lights_on_light: OmniLight3D = null
var _lights_on_burst_t: float = -1.0
var _saved_materials: Array[Dictionary] = []


func _ready() -> void:
	top_level = true
	_lamp = _make_light("FlareLamp", Color.html(str((config.get("lamp", {}) as Dictionary).get("color", "#ffb347"))), float((config.get("lamp", {}) as Dictionary).get("range_m", 10.0)))
	_lamp.visible = false
	_flash = _make_quad("FlareFlash")
	_flash_material = _flash.material_override as ShaderMaterial
	_ring = _make_quad("FlareRing")
	_ring_material = _ring.material_override as ShaderMaterial
	_ring_material.set_shader_parameter(&"ring", 1.0)
	_ring_material.set_shader_parameter(&"ring_radius", 0.85)
	_flash.visible = false
	_ring.visible = false
	var lamp_cfg: Dictionary = lights_config.get("lamp", {}) as Dictionary
	_lights_on_light = _make_light("LightsOnLamp", Color.html(str(lamp_cfg.get("color", "#ffd27a"))), float(lamp_cfg.get("range_m", 6.5)))
	_lights_on_light.visible = false


func _make_light(node_name: String, color: Color, range_m: float) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = node_name
	light.light_color = color
	light.omni_range = range_m
	light.shadow_enabled = false
	light.light_energy = 0.0
	add_child(light)
	return light


func _make_quad(node_name: String) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(FLASH_SHADER) as Shader
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = quad
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 8.0
	add_child(instance)
	return instance


# ---- the Lamp Flare ----

## Starts a flare of `duration_s` real seconds.
func start_flare(duration_s: float) -> void:
	_flaring = true
	_t = 0.0
	_duration = maxf(duration_s, 0.1)
	var env: Environment = world_environment.environment if world_environment != null else null
	if env != null and _saved_environment.is_empty():
		_saved_environment = {"adjustment_enabled": env.adjustment_enabled, "adjustment_saturation": env.adjustment_saturation,
				"adjustment_brightness": env.adjustment_brightness, "glow_intensity": env.glow_intensity}
	_lamp.visible = true
	var flash_cfg: Dictionary = config.get("flash", {}) as Dictionary
	_flash_material.set_shader_parameter(&"tint", Color.html(str(flash_cfg.get("color", "#fff0c8"))))
	_flash_material.set_shader_parameter(&"intensity", float(flash_cfg.get("intensity", 3.0)))
	var ring_cfg: Dictionary = config.get("ring", {}) as Dictionary
	_ring_material.set_shader_parameter(&"tint", Color.html(str(ring_cfg.get("color", "#ffd38a"))))
	_ring_material.set_shader_parameter(&"intensity", float(ring_cfg.get("intensity", 2.4)))
	_follow_anchor()


func stop_flare() -> void:
	if not _flaring:
		return
	_flaring = false
	_lamp.visible = false
	_flash.visible = false
	_ring.visible = false
	_restore_environment()


func is_flaring() -> bool:
	return _flaring


func flare_time() -> float:
	return _t


## The lamp's energy at `t` seconds into a flare of `duration` seconds (pure): ramps up over burst_s to the peak, settles to the hold
## level, and fades to 0 over the last fade_s.
static func lamp_energy(t: float, duration: float, flare_config: Dictionary) -> float:
	var lamp: Dictionary = flare_config.get("lamp", {}) as Dictionary
	var peak: float = float(lamp.get("energy_peak", 9.0))
	var hold: float = float(lamp.get("energy_hold", 2.6))
	var burst: float = maxf(float(flare_config.get("burst_s", 0.22)), 0.001)
	var fade: float = maxf(float(flare_config.get("fade_s", 0.4)), 0.001)
	if t < 0.0 or t >= duration:
		return 0.0
	var level: float
	if t < burst:
		level = peak * (t / burst)
	else:
		level = lerpf(peak, hold, clampf((t - burst) / 0.3, 0.0, 1.0))
	var tail: float = clampf((duration - t) / fade, 0.0, 1.0)
	return level * tail


## 0..1 through a flare, for the cool world: in over the burst, out over the fade (pure).
static func world_amount(t: float, duration: float, flare_config: Dictionary) -> float:
	var burst: float = maxf(float(flare_config.get("burst_s", 0.22)), 0.001)
	var fade: float = maxf(float(flare_config.get("fade_s", 0.4)), 0.001)
	if t < 0.0 or t >= duration:
		return 0.0
	return clampf(t / burst, 0.0, 1.0) * clampf((duration - t) / fade, 0.0, 1.0)


# ---- Lights On ----

func set_lights_on(active: bool) -> void:
	if active == _lights_on:
		return
	_lights_on = active
	if active:
		_lights_on_burst_t = 0.0
		_lights_on_light.visible = true
		var model: Node3D = _model_of_follow()
		if model != null:
			_saved_materials = boost_materials(model, float(lights_config.get("rim_mult", 1.9)), float(lights_config.get("emissive_pick", 1.6)))
	else:
		_lights_on_light.visible = false
		var model: Node3D = _model_of_follow()
		if model != null:
			restore_materials(model, _saved_materials)
		_saved_materials = []


func is_lights_on() -> bool:
	return _lights_on


## Brightens a model's edge light and turns on its neon pick (pure-ish: edits copies on the model's own surface overrides).
## Returns what to put back. A surface whose material has no rim/emissive parameters is left alone.
static func boost_materials(model: Node, rim_mult: float, emissive: float) -> Array[Dictionary]:
	var saved: Array[Dictionary] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: ShaderMaterial = mesh_instance.get_active_material(surface) as ShaderMaterial
			if source == null or source.get_shader_parameter("rim_strength") == null:
				continue
			var had_override: bool = mesh_instance.get_surface_override_material(surface) != null
			var material: ShaderMaterial = source if had_override else (source.duplicate() as ShaderMaterial)
			saved.append({"mesh": mesh_instance, "surface": surface, "had_override": had_override, "rim": float(material.get_shader_parameter("rim_strength")),
					"emissive": float(material.get_shader_parameter("emissive_pick") if material.get_shader_parameter("emissive_pick") != null else 0.0)})
			material.set_shader_parameter(&"rim_strength", float(material.get_shader_parameter("rim_strength")) * rim_mult)
			material.set_shader_parameter(&"emissive_pick", maxf(emissive, float(saved[-1]["emissive"])))
			if not had_override:
				mesh_instance.set_surface_override_material(surface, material)
	return saved


static func restore_materials(model: Node, saved: Array[Dictionary]) -> void:
	for entry: Dictionary in saved:
		var mesh_instance: MeshInstance3D = entry["mesh"] as MeshInstance3D
		if not is_instance_valid(mesh_instance):
			continue
		var surface: int = int(entry["surface"])
		if not bool(entry["had_override"]):
			mesh_instance.set_surface_override_material(surface, null)
			continue
		var material: ShaderMaterial = mesh_instance.get_surface_override_material(surface) as ShaderMaterial
		if material != null:
			material.set_shader_parameter(&"rim_strength", float(entry["rim"]))
			material.set_shader_parameter(&"emissive_pick", float(entry["emissive"]))


# ---- per frame ----

func _process(delta: float) -> void:
	_follow_anchor()
	if _flaring:
		_t += delta
		_step_flare()
	if _lights_on:
		_step_lights_on(delta)


func _follow_anchor() -> void:
	if follow == null or not is_instance_valid(follow):
		return
	var point: Vector3 = follow.call("anchor", &"lamp") as Vector3 if follow.has_method("anchor") else follow.global_position + Vector3.UP * 0.6
	_lamp.global_position = point
	_flash.global_position = point
	_ring.global_position = point
	_lights_on_light.global_position = point


func _step_flare() -> void:
	if _t >= _duration:
		stop_flare()
		return
	_lamp.light_energy = lamp_energy(_t, _duration, config)
	var flash_cfg: Dictionary = config.get("flash", {}) as Dictionary
	var flash_life: float = maxf(float(flash_cfg.get("life_s", 0.16)), 0.001)
	var fk: float = _t / flash_life
	_flash.visible = fk < 1.0
	_flash.scale = Vector3.ONE * float(flash_cfg.get("size_m", 2.4)) * lerpf(0.5, 1.0, clampf(fk, 0.0, 1.0))
	_flash_material.set_shader_parameter(&"fade", 1.0 - clampf(fk, 0.0, 1.0))
	var ring_cfg: Dictionary = config.get("ring", {}) as Dictionary
	var ring_life: float = maxf(float(ring_cfg.get("life_s", RING_LIFE_FALLBACK)), 0.001)
	var rk: float = _t / ring_life
	_ring.visible = rk < 1.0
	_ring.scale = Vector3.ONE * float(ring_cfg.get("max_m", 7.0)) * (1.0 - (1.0 - clampf(rk, 0.0, 1.0)) * (1.0 - clampf(rk, 0.0, 1.0)))
	_ring_material.set_shader_parameter(&"fade", 1.0 - clampf(rk, 0.0, 1.0))
	var env: Environment = world_environment.environment if world_environment != null else null
	if env != null and not _saved_environment.is_empty():
		var amount: float = world_amount(_t, _duration, config)
		var env_cfg: Dictionary = config.get("environment", {}) as Dictionary
		env.adjustment_enabled = true
		env.adjustment_saturation = lerpf(float(_saved_environment["adjustment_saturation"]), float(env_cfg.get("saturation", 0.72)), amount)
		env.adjustment_brightness = lerpf(float(_saved_environment["adjustment_brightness"]), float(env_cfg.get("brightness", 0.94)), amount)
		env.glow_intensity = float(_saved_environment["glow_intensity"]) + float(env_cfg.get("glow_boost", 0.35)) * amount


func _restore_environment() -> void:
	var env: Environment = world_environment.environment if world_environment != null else null
	if env == null or _saved_environment.is_empty():
		return
	for property: String in _saved_environment:
		env.set(property, _saved_environment[property])
	_saved_environment = {}


func _step_lights_on(delta: float) -> void:
	var lamp_cfg: Dictionary = lights_config.get("lamp", {}) as Dictionary
	var energy: float = float(lamp_cfg.get("energy", 2.4))
	var burst: Dictionary = lights_config.get("burst", {}) as Dictionary
	if _lights_on_burst_t >= 0.0:
		_lights_on_burst_t += delta
		var life: float = maxf(float(burst.get("life_s", 0.4)), 0.001)
		var k: float = _lights_on_burst_t / life
		if k >= 1.0:
			_lights_on_burst_t = -1.0
			_ring.visible = _flaring and _ring.visible
		else:
			energy += energy * 3.0 * (1.0 - k)
			if not _flaring:
				_ring_material.set_shader_parameter(&"tint", Color.html(str(burst.get("color", "#ffd27a"))))
				_ring_material.set_shader_parameter(&"intensity", float(burst.get("intensity", 2.4)))
				_ring.visible = true
				_ring.scale = Vector3.ONE * float(burst.get("ring_m", 3.0)) * (1.0 - (1.0 - k) * (1.0 - k))
				_ring_material.set_shader_parameter(&"fade", 1.0 - k)
	_lights_on_light.light_energy = energy


func _model_of_follow() -> Node3D:
	if follow != null and is_instance_valid(follow) and follow.has_method("get_model"):
		return follow.call("get_model") as Node3D
	return null
