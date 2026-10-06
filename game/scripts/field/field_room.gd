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

const RESUME_BLOCK_FRAMES: int = 6

var player: PlayerController = null
var camera_rig: DioramaCamera = null
var prop_fader: PropFader = null
var runner: DialogueRunner = null
var field_menu: FieldMenu = null
var interactor: PlayerInteractor = null
var prompt: InteractPrompt = null
var fights: RoomFights = null

## A fight was chosen (the enemy's Fight! answer finished). Main answers by starting the battle.
signal battle_requested(encounter_id: String, fight_id: String)

var _suspended: bool = false


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

	fights = RoomFights.new()
	fights.name = "RoomFights"
	add_child(fights)
	fights.setup(self, runner, interactor)
	fights.battle_requested.connect(battle_requested.emit)


## True while a battle has the world and this room waits in memory.
func is_suspended() -> bool:
	return _suspended


## The room is about to be detached while a battle uses the world: hide its on-screen bits and
## switch the menu off. Everything else (Red, NPCs, the camera) simply waits in memory.
func suspend() -> void:
	_suspended = true
	if prompt != null:
		prompt.hide_icon()
	if field_menu != null and is_instance_valid(field_menu):
		field_menu.enabled = false


## The room is back in the world after a battle: the camera and the room's look come back, and the
## buttons that dismissed the victory screen are ignored for a moment so they cannot also jump or talk.
func resume() -> void:
	_suspended = false
	camera_rig.get_camera().make_current()
	var look: PsxRoomLook = get_node_or_null("RoomLook") as PsxRoomLook
	if look != null:
		look.apply()
	if field_menu != null and is_instance_valid(field_menu):
		field_menu.enabled = true
	if player != null:
		player.block_jump_for_frames(RESUME_BLOCK_FRAMES)
	if interactor != null:
		interactor.block_for_frames(RESUME_BLOCK_FRAMES)


## Main tells the room how its battle ended. A win removes the enemy that was fought.
func battle_finished(result: String, _report: Dictionary = {}) -> void:
	if fights != null:
		fights.battle_finished(result)


func _exit_tree() -> void:
	if not _suspended:
		teardown()


## Takes the room's UI off the shared stage and stops its talking. Runs when the room leaves the
## world for good (not when it only waits in memory during a battle).
func teardown() -> void:
	# The UI lives on the shared stage, so it has to be taken down with the room: a bubble or the
	# menu left behind would keep the "busy" lock on for good.
	if fights != null and is_instance_valid(fights):
		fights.shut_down()
	if runner != null and is_instance_valid(runner):
		runner.stop()
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var stage: UiStage = tree.get_first_node_in_group(UiStage.GROUP) as UiStage
	if stage != null:
		for child: Node in stage.get_stage_root().get_children():
			if child is SpeechBubble:
				_drop_from_stage(child)
	if field_menu != null and is_instance_valid(field_menu):
		_drop_from_stage(field_menu)
	if prompt != null and is_instance_valid(prompt):
		prompt.queue_free()


static func _drop_from_stage(node: Node) -> void:
	node.remove_from_group(UiStage.MODAL_GROUP)
	node.queue_free()
