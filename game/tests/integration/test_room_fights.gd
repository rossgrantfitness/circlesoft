extends TestCase
## Fights in the test room: enemies stand in the room, Red talks to one, gets a goofy challenge and a
## Fight? choice. Yes asks for that enemy's encounter (once the last bubble is gone), no does not.
## A win removes the enemy until the room loads again; running away leaves it standing.

const ROOM_PATH: String = "res://scenes/debug/psx_test_room.tscn"
const ENEMIES: Dictionary[String, String] = {
	"GruntEnemy": "grunt_pair", "DroneEnemy": "drone_flock", "SquadEnemy": "squad_four", "ToughEnemy": "ambush_no_exit",
}
const FIGHT_IDS: Dictionary[String, String] = {
	"GruntEnemy": "grunt", "DroneEnemy": "drone", "SquadEnemy": "squad", "ToughEnemy": "tough",
}
## The legs the room-walking test takes (test_field_room.gd) and the jump approaches: keep them clear.
const ROUTE: Array[Vector3] = [
	Vector3(-1.0, 0.0, -1.5), Vector3(9.0, 0.0, -2.4), Vector3(12.5, 0.0, -3.5), Vector3(12.5, 0.0, 3.5),
	Vector3(-4.5, 0.0, 3.5), Vector3(-4.5, 0.0, -3.5),
]
const ROUTE_CLEARANCE: float = 1.0
const NPC_CLEARANCE: float = 1.5
const WAIT_FRAMES: int = 90

var _room: FieldRoom = null
var _state: Node = null
var _requested: Array = []


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")
	_requested = []


func after_each() -> void:
	_state.call("reset")
	for action: StringName in [&"jump", &"menu", &"interact"]:
		Input.action_release(action)


func _load_room() -> FieldRoom:
	_room = (load(ROOM_PATH) as PackedScene).instantiate() as FieldRoom
	add_to_root(_room)
	_room.player.read_engine_input = false
	_room.interactor.read_engine_input = false
	_room.runner.manual_ticks = true
	_room.runner.chars_per_second_override = 100000.0
	_room.battle_requested.connect(func(encounter: String, fight_id: String) -> void: _requested.append([encounter, fight_id]))
	return _room


func _enemy(node_name: String) -> FieldEnemy:
	return _room.get_node(node_name) as FieldEnemy


## Red one step in front of the enemy (on the side it faces), looking at it.
func _stand_before(enemy: FieldEnemy) -> void:
	var facing: Vector3 = enemy.get_facing()
	facing.y = 0.0
	var spot: Vector3 = enemy.global_position + facing.normalized() * 1.2
	var player: PlayerController = _room.player
	player.global_position = Vector3(spot.x, 0.02, spot.z)
	player.velocity = Vector3.ZERO
	player.rotation.y = PlayerMotion.yaw_for_direction(-facing.normalized())
	for i: int in 4:
		await tree.physics_frame
	_room.interactor.refresh()


## Advances the conversation until the choice shows, returns true when it does.
func _to_the_choice() -> bool:
	for i: int in 60:
		var bubble: SpeechBubble = _room.runner.get_current_bubble()
		if bubble != null and bubble.get_state() == SpeechBubble.State.CHOOSING:
			return true
		_room.runner.confirm()
		_room.runner.tick(0.5)
	return false


## Picks a choice, then clicks through the rest of the conversation.
func _answer(index: int) -> void:
	_room.runner.get_current_bubble().choose(index)
	for i: int in 80:
		if not _room.runner.is_running():
			break
		_room.runner.confirm()
		_room.runner.tick(0.5)
	# The runner's own release countdown (frames), so the UI lock lets go.
	for i: int in 6:
		_room.runner.tick(0.1)


func _wait_for_request() -> void:
	for i: int in WAIT_FRAMES:
		if not _requested.is_empty():
			return
		_room.runner.tick(0.1)
		await tree.process_frame


func _distance_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var closest: Vector3 = Geometry3D.get_closest_point_to_segment(point, a, b)
	return Vector2(point.x - closest.x, point.z - closest.z).length()


# ---- the room ----

func test_the_room_has_four_enemies_with_their_encounters_from_data() -> void:
	_load_room()
	var data: Dictionary = RoomFights.data()
	var db: Node = tree.root.get_node("DataDB")
	var encounter_ids: Array = []
	for encounter: Dictionary in db.call("get_dict", "battle/encounters")["encounters"]:
		encounter_ids.append(str(encounter["id"]))
	for node_name: String in ENEMIES:
		var enemy: FieldEnemy = _enemy(node_name)
		assert_not_null(enemy, node_name + " is in the room")
		assert_eq(enemy.fight_id, FIGHT_IDS[node_name])
		assert_eq(enemy.get_encounter_id(), ENEMIES[node_name], node_name + " starts the right encounter")
		assert_has(encounter_ids, enemy.get_encounter_id(), "the encounter exists in battle/encounters.json")
		var fight: Dictionary = data["fights"][enemy.fight_id]
		assert_eq(enemy.get_interactable().conversation, str(fight["challenge"]))
		assert_true(_room.runner.has_conversation(str(fight["challenge"])))
		assert_true(_room.runner.has_conversation(str(fight["yes"])))
		assert_true(_room.runner.has_conversation(str(fight["no"])))
		assert_true(_room.runner.has_speaker(enemy.speaker_id), "registered as a speaker")
		assert_true(ResourceLoader.exists(enemy.model_path), node_name + " model exists")
		assert_not_null(enemy.get_model(), node_name + " model is attached")
		assert_not_null(enemy.get_animation_player(), "has an AnimationPlayer")
		assert_true(enemy.get_animation_player().has_animation(&"idle"), "with an idle clip")
		assert_eq(enemy.get_interactable().current_kind_name(), "talk")


func test_enemies_stay_out_of_the_walking_and_jumping_routes() -> void:
	_load_room()
	var others: Array[Node3D] = [_room.get_node("Otis") as Node3D, _room.get_node("Mox") as Node3D,
			_room.get_node("OldZero") as Node3D, _room.get_node("Pillar") as Node3D]
	var spawn: Vector3 = (_room.get_node("PlayerSpawn") as Marker3D).global_position
	for node_name: String in ENEMIES:
		var spot: Vector3 = _enemy(node_name).global_position
		for i: int in ROUTE.size() - 1:
			assert_ge(_distance_to_segment(spot, ROUTE[i], ROUTE[i + 1]), ROUTE_CLEARANCE, "%s clear of route leg %d" % [node_name, i])
		assert_gt(Vector2(spot.x - spawn.x, spot.z - spawn.z).length(), NPC_CLEARANCE, node_name + " is not on the spawn")
		for other: Node3D in others:
			assert_gt(Vector2(spot.x - other.global_position.x, spot.z - other.global_position.z).length(), 1.0, "%s is not on %s" % [node_name, other.name])
		for jumpable: Node in _room.get_children():
			if jumpable.is_in_group(&"jumpable") and jumpable is MeshInstance3D:
				var mesh_instance: MeshInstance3D = jumpable as MeshInstance3D
				var half: Vector3 = mesh_instance.mesh.get_aabb().size * 0.5
				assert_true(absf(spot.x - mesh_instance.global_position.x) > half.x + 0.5 or absf(spot.z - mesh_instance.global_position.z) > half.z + 0.5,
						"%s is not inside the %s" % [node_name, jumpable.name])


func test_each_enemy_is_solid_and_stands_on_the_floor() -> void:
	_load_room()
	for node_name: String in ENEMIES:
		var enemy: FieldEnemy = _enemy(node_name)
		var body: StaticBody3D = enemy.get_node("Body") as StaticBody3D
		assert_eq(body.collision_layer & 1, 1, node_name + " is solid")
		assert_almost_eq(enemy.global_position.y, 0.0, 0.001)
		assert_gt(enemy.get_head_height(), 1.0, node_name + " has a head point for the bubble")


# ---- fighting ----

func test_challenge_then_yes_asks_for_that_encounter() -> void:
	_load_room()
	var enemy: FieldEnemy = _enemy("GruntEnemy")
	await _stand_before(enemy)
	assert_eq(_room.interactor.get_target(), enemy.get_interactable(), "Red picks the enemy")
	assert_eq(_room.prompt.current_icon, "talk", "the speech-bubble icon")
	assert_true(_room.interactor.try_interact())
	assert_eq(_room.runner.get_current_conversation(), "challenge_grunt")
	assert_true(_to_the_choice(), "the challenge ends in a choice")
	var bubble: SpeechBubble = _room.runner.get_current_bubble()
	assert_eq(bubble.get_choices().size(), 2, "Fight? yes / no")
	assert_true(_requested.is_empty(), "nothing starts before the answer")
	_answer(0)
	await _wait_for_request()
	assert_eq(_requested.size(), 1)
	assert_eq(_requested[0], ["grunt_pair", "grunt"])
	assert_false(UiStage.is_busy(tree), "the request waits for the last bubble to be gone")


func test_every_enemy_starts_its_own_encounter() -> void:
	for node_name: String in ENEMIES:
		_load_room()
		var enemy: FieldEnemy = _enemy(node_name)
		await _stand_before(enemy)
		assert_true(_room.interactor.try_interact(), node_name)
		assert_true(_to_the_choice())
		_answer(0)
		await _wait_for_request()
		assert_eq(_requested.size(), 1, node_name)
		if not _requested.is_empty():
			assert_eq(_requested[0][0], ENEMIES[node_name], node_name + " -> its encounter")
		_room.queue_free()
		await tree.process_frame
		_requested = []
		_room = null


func test_no_does_not_start_a_fight() -> void:
	_load_room()
	var enemy: FieldEnemy = _enemy("DroneEnemy")
	await _stand_before(enemy)
	assert_true(_room.interactor.try_interact())
	assert_true(_to_the_choice())
	_answer(1)
	for i: int in 30:
		_room.runner.tick(0.1)
		await tree.process_frame
	assert_true(_requested.is_empty(), "no fight")
	assert_false(_room.runner.is_running())
	assert_true(is_instance_valid(enemy), "the enemy is still there")
	assert_false(_room.player.frozen, "Red is free again")


func test_the_choice_icons_and_voice_names_exist() -> void:
	var speakers: Dictionary = tree.root.get_node("DataDB").call("get_value", "ui/dialogue_ui", "speakers")
	for fight_id: String in RoomFights.fight_ids():
		var line: Dictionary = (RoomFights.data()["fights"][fight_id] as Dictionary)
		assert_true(line.has("challenge"))
	for speaker: String in ["enemy_grunt", "enemy_drone", "enemy_squad", "enemy_tough"]:
		assert_has(speakers, speaker)
		assert_ne(str(speakers[speaker]["name"]), "", speaker + " has a name tag")


func test_a_win_removes_the_enemy_a_run_does_not() -> void:
	_load_room()
	var grunt: FieldEnemy = _enemy("GruntEnemy")
	var drone: FieldEnemy = _enemy("DroneEnemy")
	_room.fights.pending_fight_id = "drone"
	_room.battle_finished("ran")
	assert_true(is_instance_valid(drone) and not drone.is_queued_for_deletion(), "running away leaves it")
	assert_false(bool(_state.call("get_flag", RoomFights.defeated_flag("drone"))))
	assert_eq(_room.fights.pending_fight_id, "", "the fight is no longer pending")
	_room.fights.pending_fight_id = "grunt"
	_room.battle_finished("win")
	assert_true(bool(_state.call("get_flag", RoomFights.defeated_flag("grunt"))), "the defeated flag is set")
	assert_true(grunt.is_queued_for_deletion(), "the enemy is gone")
	assert_false(grunt.get_interactable().enabled)
	assert_null(_room.fights.enemy_for("grunt"))
	assert_not_null(_room.fights.enemy_for("drone"))
	await tree.process_frame
	assert_false(is_instance_valid(grunt))
	await _stand_before(drone)
	assert_eq(_room.interactor.get_target(), drone.get_interactable(), "the others can still be fought")


func test_defeated_enemies_come_back_when_the_room_loads_again() -> void:
	_state.call("set_flag", RoomFights.defeated_flag("grunt"), true)
	_load_room()
	assert_not_null(_room.fights.enemy_for("grunt"), "a freshly loaded room has everyone")
	assert_false(bool(_state.call("get_flag", RoomFights.defeated_flag("grunt"))), "and the flag was cleared")


func test_full_trip_a_real_fight_from_the_room_and_back() -> void:
	var main: Main = BattleFlowKit.make_main(self)
	await tree.process_frame
	var room: FieldRoom = main.get_room() as FieldRoom
	room.runner.chars_per_second_override = 100000.0
	var enemy: FieldEnemy = room.get_node("GruntEnemy") as FieldEnemy
	var facing: Vector3 = enemy.get_facing()
	facing.y = 0.0
	var spot: Vector3 = enemy.global_position + facing.normalized() * 1.2
	room.player.global_position = Vector3(spot.x, 0.02, spot.z)
	room.player.rotation.y = PlayerMotion.yaw_for_direction(-facing.normalized())
	room.player.read_engine_input = false
	room.interactor.read_engine_input = false
	for i: int in 4:
		await tree.physics_frame
	var red_spot: Vector3 = room.player.global_position
	main.battle_setup_hook = BattleFlowKit.winning_hook(main)
	assert_true(room.interactor.try_interact(), "Red talks to the grunt")
	# Real frames now: click through the bubbles, answer Fight!, and let Main take it from there.
	var frames: int = 0
	while main.get_state() == Main.State.ROOM and frames < 600:
		if room.runner.is_running():
			room.runner.confirm()
		frames += 1
		await tree.process_frame
	assert_eq(main.get_state(), Main.State.BATTLE, "answering Fight! started the battle")
	assert_true(await BattleFlowKit.finish_fight(tree, main, "continue"), "the fight ended")
	await tree.process_frame
	assert_eq(main.get_state(), Main.State.ROOM)
	assert_eq(main.get_room(), room)
	assert_true(room.player.global_position.distance_to(red_spot) < 0.05, "Red is where she stood")
	assert_true(bool(_state.call("get_flag", RoomFights.defeated_flag("grunt"))), "the grunt is defeated")
	assert_true(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(), "and gone from the room")
	assert_not_null(room.fights.enemy_for("drone"), "the others are still there")
	assert_gt(int(_state.call("get_credits")), 0, "the win paid out")
