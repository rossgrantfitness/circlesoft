class_name FieldRoom
extends Node3D
## Put on a room's root to make it playable: spawns Red at the spawn marker, points the room's
## diorama camera at her, gives the camera its bounds, and starts the prop fader.
##
## It also sets up the room's talking: one DialogueRunner (every NPC in group "npc" registers as a
## speaker), the field menu (menu action) and Red's interactor with its prompt icon.
##
## Expected children: a Marker3D named PlayerSpawn (or a Spawns node holding one Marker3D per named
## spawn, which the SceneRouter picks with `entry_spawn`), a DioramaCamera named CameraRig and,
## optionally, a CameraBounds. Props that should fade when they block the view join the group
## "fade_occluder".
##
## Exploration (M3-2, M3-5): the crew follows Red (PartyFollow, off with `party_follows`), doors,
## pickups, crates and climb/hop spots in the room work through the interactor, and map enemies
## (MapEnemy) that touch Red start a battle with a first-turn rule (FieldEncounters).

@export var player_scene: PackedScene
@export var spawn_name: String = "PlayerSpawn"
@export var camera_rig_name: String = "CameraRig"
@export var bounds_name: String = "CameraBounds"
## The id in data/world/rooms.json (empty for rooms the router does not know).
@export var room_id: String = ""
## Which spawn marker Red starts on. The SceneRouter sets this before the room enters the tree.
@export var entry_spawn: String = ""
@export var spawns_name: String = "Spawns"
## The crew (the party minus Red) walks behind her. Off in the old test room, which has Otis and Mox standing in it.
@export var party_follows: bool = true
## Members only walk behind her once their join flag is set (data/world/exploration.json "follow.join_flags":
## Otis after the dock fight, Mox later). Off in the graybox test rooms, which show the whole party.
@export var crew_by_flags: bool = false

const RESUME_BLOCK_FRAMES: int = 6

var player: PlayerController = null
var camera_rig: DioramaCamera = null
var prop_fader: PropFader = null
var runner: DialogueRunner = null
var field_menu: FieldMenu = null
var interactor: PlayerInteractor = null
var prompt: InteractPrompt = null
var fights: RoomFights = null
var party: PartyFollow = null
var encounters: FieldEncounters = null
var story: StoryDirector = null

## A fight was chosen (the enemy's Fight! answer finished). Main answers by starting the battle.
signal battle_requested(encounter_id: String, fight_id: String)
## A map enemy caught Red. Main starts that encounter with the first-turn rule (party / enemies / normal).
signal field_battle_requested(encounter_id: String, enemy_id: String, first_turn: String)

var _suspended: bool = false


func _ready() -> void:
	camera_rig = get_node_or_null(camera_rig_name) as DioramaCamera
	var spawn: Marker3D = find_spawn(entry_spawn)
	if camera_rig == null or spawn == null or player_scene == null:
		push_error("FieldRoom %s needs a player scene, a %s marker and a %s" % [name, spawn_name, camera_rig_name])
		return
	player = player_scene.instantiate() as PlayerController
	add_child(player)
	player.global_transform = Transform3D(Basis.from_euler(Vector3(0.0, spawn.global_rotation.y, 0.0)), spawn.global_position)
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

	if party_follows:
		_setup_party()
	_setup_talking()
	_setup_encounters()
	_setup_story()


## The marker named `wanted` under the Spawns node (or directly under the room); with no name, or no
## such marker, the default PlayerSpawn, or the first marker under Spawns.
func find_spawn(wanted: String) -> Marker3D:
	if not wanted.is_empty():
		var named: Marker3D = get_node_or_null(NodePath("%s/%s" % [spawns_name, wanted])) as Marker3D
		if named == null:
			named = get_node_or_null(NodePath(wanted)) as Marker3D
		if named != null:
			return named
		push_warning("FieldRoom %s: no spawn '%s', using the default" % [name, wanted])
	var default_spawn: Marker3D = get_node_or_null(spawn_name) as Marker3D
	if default_spawn != null:
		return default_spawn
	var holder: Node = get_node_or_null(spawns_name)
	if holder != null:
		for child: Node in holder.get_children():
			if child is Marker3D:
				return child as Marker3D
	return null


## Names of the spawn markers this room has (under Spawns, plus PlayerSpawn).
func spawn_names() -> Array[String]:
	var names: Array[String] = []
	var holder: Node = get_node_or_null(spawns_name)
	if holder != null:
		for child: Node in holder.get_children():
			if child is Marker3D:
				names.append(str(child.name))
	if get_node_or_null(spawn_name) is Marker3D:
		names.append(spawn_name)
	return names


func _setup_party() -> void:
	var ids: Array[String] = []
	var state: Node = get_node_or_null("/root/GameState")
	if state != null:
		ids.assign(state.call("get_party_ids"))
	if crew_by_flags:
		var join_flags: Dictionary = DataDB.get_dict(ExplorationTuning.TUNING_ID).get("follow", {}).get("join_flags", {})
		var joined: Array[String] = []
		for id: String in ids:
			if not join_flags.has(id) or WorldProgress.has_flag(str(join_flags[id])):
				joined.append(id)
		ids = joined
	party = PartyFollow.new()
	party.name = "PartyFollow"
	add_child(party)
	party.setup(player, ids, self)
	party.member_added.connect(_on_member_added)


func _setup_story() -> void:
	story = StoryDirector.new()
	story.name = "StoryDirector"
	add_child(story)
	story.setup(self)


func _on_member_added(follower: PartyFollower) -> void:
	if runner != null:
		runner.register_speaker(follower.member_id, follower, follower.get_head_height())


func _setup_encounters() -> void:
	encounters = FieldEncounters.new()
	encounters.name = "FieldEncounters"
	add_child(encounters)
	encounters.setup(self, player)
	encounters.battle_requested.connect(field_battle_requested.emit)


func _setup_talking() -> void:
	runner = DialogueRunner.create(self, player, camera_rig.get_camera())
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		if node is Npc and is_ancestor_of(node):
			var npc: Npc = node as Npc
			runner.register_speaker(npc.speaker_id, npc, npc.get_head_height())
	if party != null:
		for follower: PartyFollower in party.followers:
			runner.register_speaker(follower.member_id, follower, follower.get_head_height())
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
	if story != null:
		story.battle_finished(result)
	if encounters != null:
		encounters.battle_finished(result)
	elif player != null:
		player.start_blink()


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
	var tree: SceneTree = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
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
