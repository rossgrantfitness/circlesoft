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

var _environment: Environment = null


func _ready() -> void:
	apply()


## Sets the fog, background and ambient light. Called on load, and again when a room that waited
## in memory during a battle comes back.
func apply() -> void:
	PsxLook.set_fog(fog_color, fog_near, fog_far)
	var world_environment: WorldEnvironment = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null:
		return
	_environment = world_environment.environment
	if _environment == null:
		return
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = fog_color
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = ambient_color
	_environment.ambient_light_energy = ambient_energy
