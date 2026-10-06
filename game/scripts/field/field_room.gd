class_name FieldRoom
extends Node3D
## Put on a room's root to make it playable: spawns Red at the spawn marker, points the room's
## diorama camera at her, gives the camera its bounds, and starts the prop fader.
##
## It also sets up the room's talking: one DialogueRunner (every NPC in group "npc" registers as a
## speaker), the field menu (menu action) and Red's interactor with its prompt icon.
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
var runner: DialogueRunner = null
var field_menu: FieldMenu = null
var interactor: PlayerInteractor = null
var prompt: InteractPrompt = null


func _ready() -> void:
	camera_rig = get_node_or_null(camera_rig_name) as DioramaCamera
	var spawn: Marker3D = get_node_or_null(spawn_name) as Marker3D
	if camera_rig == null or spawn == null or player_scene == null:
		push_error("FieldRoom %s needs a player scene, a %s marker and a %s" % [name, spawn_name, camera_rig_name])
		return
	player = player_scene.instantiate() as PlayerController
	add_child(player)
	player.global_transform = Transform3D(Basis.IDENTITY, spawn.global_position)
	player.reset_ground_height()
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

	_setup_talking()


func _setup_talking() -> void:
	runner = DialogueRunner.create(self, player, camera_rig.get_camera())
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		if node is Npc and is_ancestor_of(node):
			var npc: Npc = node as Npc
			runner.register_speaker(npc.speaker_id, npc, npc.get_head_height())
	field_menu = FieldMenu.install(get_tree(), player)

	prompt = InteractPrompt.new()
	prompt.follow = player
	prompt.camera = camera_rig.get_camera()
	UiStage.get_or_create(get_tree()).get_stage_root().add_child(prompt)
	interactor = PlayerInteractor.new()
	interactor.name = "PlayerInteractor"
	interactor.player = player
	interactor.runner = runner
	interactor.prompt = prompt
	add_child(interactor)


func _exit_tree() -> void:
	# The UI lives on the shared stage, so it has to be taken down with the room.
	if field_menu != null and is_instance_valid(field_menu):
		field_menu.queue_free()
	if prompt != null and is_instance_valid(prompt):
		prompt.queue_free()
