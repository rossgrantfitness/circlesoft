class_name PsxRoomLook
extends Node
## Put one on a room's root. When the room loads it sets the fog the shaders use and the
## room's background and ambient light, so every room carries its own look in its scene file.
## Fog distances are measured from the camera, so each room's camera setup decides them.

## Fog and background color: the room's "void" color (Night or Ink).
@export var fog_color: Color = Color(0.12, 0.145, 0.25)
## Distance from the camera where fog starts.
@export var fog_near: float = 12.0
## Distance from the camera where fog is complete.
@export var fog_far: float = 24.0
@export var ambient_color: Color = Color(0.4, 0.4, 0.6)
@export var ambient_energy: float = 1.0

const BASE_ENERGY_META: StringName = &"look_base_energy"

## A scene that scales its haze with the player's size (the combat sandbox's giant robots, CS-21) sets the fog distances
## here, (near, far) in metres; ZERO = use the profile's own. It survives a look-profile switch.
var fog_override: Vector2 = Vector2.ZERO

var _environment: Environment = null
var _fog_tint: Color = Color(0.12, 0.145, 0.25)


func _ready() -> void:
	add_to_group(LookProfiles.GROUP_AWARE)
	apply()


## Sets the fog, background and ambient light. Called on load, and again when a room that waited
## in memory during a battle comes back.
func apply() -> void:
	# This room asks for its look profile (its own default, or the one forced from the F1 overlay). The
	# profile's apply_look() below is also what the overlay's switch calls, so both paths agree.
	LookProfiles.enter_scene(scene_key())
	apply_look(LookProfiles.active_id(), LookProfiles.active())


## Sets the fog distances now (and keeps them through look changes). Same colour as the profile's.
func set_fog_distances(near_m: float, far_m: float) -> void:
	fog_override = Vector2(near_m, far_m)
	PsxLook.set_fog(_fog_tint, near_m, far_m)


## The distances in force right now: the override if there is one, else the profile's numbers.
func fog_distances() -> Vector2:
	if fog_override != Vector2.ZERO:
		return fog_override
	var fog: Dictionary = LookProfiles.active().get("fog", {}) as Dictionary
	return Vector2(fog_near * float(fog.get("near_mul", 1.0)), fog_far * float(fog.get("far_mul", 1.0)))


## The key this room uses in data/world/look_profiles.json "scene_defaults": its room id.
func scene_key() -> String:
	var host: Node = get_parent()
	if host == null:
		return ""
	var id: Variant = host.get("room_id")
	if id is String and not (id as String).is_empty():
		return id
	return str(host.name).to_lower()


## Fog, background, ambient light and the room's lights for a look profile. "classic" leaves every
## value exactly as the room's scene file wrote it.
func apply_look(_id: String, profile: Dictionary) -> void:
	var fog: Dictionary = profile.get("fog", {})
	var lighting: Dictionary = profile.get("lighting", {})
	var fog_tint: Color = fog_color
	var wanted: String = str(fog.get("color", ""))
	if not wanted.is_empty():
		fog_tint = fog_color.lerp(Color.html(wanted), float(fog.get("mix", 1.0)))
	_fog_tint = fog_tint
	if fog_override != Vector2.ZERO:
		PsxLook.set_fog(fog_tint, fog_override.x, fog_override.y)
	else:
		PsxLook.set_fog(fog_tint, fog_near * float(fog.get("near_mul", 1.0)), fog_far * float(fog.get("far_mul", 1.0)))
	var host: Node = get_parent()
	if host == null:
		return
	_apply_lights(host, lighting)
	var world_environment: WorldEnvironment = host.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null:
		return
	_environment = world_environment.environment
	if _environment == null:
		return
	var ambient_mul: Variant = lighting.get("ambient_color_mul", [1.0, 1.0, 1.0])
	var tint: Color = Color(ambient_color.r, ambient_color.g, ambient_color.b, 1.0)
	if ambient_mul is Array and (ambient_mul as Array).size() >= 3:
		var channels: Array = ambient_mul
		tint = Color(ambient_color.r * float(channels[0]), ambient_color.g * float(channels[1]), ambient_color.b * float(channels[2]), 1.0)
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = fog_tint
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = tint
	_environment.ambient_light_energy = ambient_energy * float(lighting.get("ambient_energy_mul", 1.0))


## The room's own lamps and key lights, scaled by the profile (each light remembers its first energy).
func _apply_lights(host: Node, lighting: Dictionary) -> void:
	var point_mul: float = float(lighting.get("point_energy_mul", 1.0))
	var key_mul: float = float(lighting.get("key_energy_mul", 1.0))
	for node: Node in host.find_children("*", "Light3D", true, false):
		if _is_dressing_light(node, host):
			continue
		var light: Light3D = node as Light3D
		if not light.has_meta(BASE_ENERGY_META):
			light.set_meta(BASE_ENERGY_META, light.light_energy)
		light.light_energy = float(light.get_meta(BASE_ENERGY_META)) * (key_mul if light is DirectionalLight3D else point_mul)


static func _is_dressing_light(node: Node, host: Node) -> bool:
	var current: Node = node.get_parent()
	while current != null and current != host:
		if current.is_in_group(GrimDressing.GROUP):
			return true
		current = current.get_parent()
	return false
