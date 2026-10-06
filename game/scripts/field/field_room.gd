class_name FieldRoom
extends Node3D
## Put on a room's root to make it playable: spawns Red at the spawn marker, points the room's
## diorama camera at her, gives the camera its bounds, and starts the prop fader.
##
## Expected children: a Marker3D named PlayerSpawn, a DioramaCamera named CameraRig and, optionally,
## a CameraBounds. Props that should fade when they block the view join the group "fade_occluder".

@export var player_scene: PackedScene
@export var spawn_name: String = "PlayerSpawn"
@export var camera_rig_name: String = "CameraRig"
@export var bounds_name: String = "CameraBounds"

var player: PlayerController = null
var camera_rig: DioramaCamera = null
var prop_fader: PropFader = null


func _ready() -> void:
	camera_rig = get_node_or_null(camera_rig_name) as DioramaCamera
	var spawn: Marker3D = get_node_or_null(spawn_name) as Marker3D
	if camera_rig == null or spawn == null or player_scene == null:
		push_error("FieldRoom %s needs a player scene, a %s marker and a %s" % [name, spawn_name, camera_rig_name])
		return
	player = player_scene.instantiate() as PlayerController
	add_child(player)
	player.global_transform = Transform3D(Basis.IDENTITY, spawn.global_position)
	player.set_camera(camera_rig.get_camera())

	var bounds: CameraBounds = get_node_or_null(bounds_name) as CameraBounds
	if bounds != null:
		camera_rig.set_bounds(bounds.get_world_aabb())
	camera_rig.set_target(player)
	camera_rig.snap_to_target()

	prop_fader = PropFader.new()
	prop_fader.name = "PropFader"
	add_child(prop_fader)
	prop_fader.set_target(player)
	prop_fader.set_camera(camera_rig.get_camera())
	prop_fader.target_anchor_height = camera_rig.target_anchor_height
