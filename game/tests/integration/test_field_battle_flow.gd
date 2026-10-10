extends TestCase
## A map enemy touching Red goes all the way through Main: the battle starts with the first-turn rule
## from facing (BattleSetup.first_turn), a win removes the enemy and Red blinks, running leaves it
## standing and Red blinks, and a story fight that was won stays gone when the room is entered again.

const TICK: float = 1.0 / 60.0

var _main: Main = null
var _router: Node = null
var _state: Node = null
var _first_turns: Array[String] = []


func before_each() -> void:
	_state = tree.root.get_node("GameState")
	_state.call("reset")
	_first_turns = []


func after_each() -> void:
	_state.call("reset")


func _start(path: String) -> FieldRoom:
	var made: Dictionary = ExplorationKit.make_main_and_router(self, path)
	_main = made["main"]
	_router = made["router"]
	return _main.get_room() as FieldRoom


func _hook(win: bool) -> Callable:
	var inner: Callable = BattleFlowKit.winning_hook(_main) if win else BattleFlowKit.running_hook(_main)
	return func(setup: BattleSetup) -> void:
		_first_turns.append(setup.first_turn)
		inner.call(setup)


## Puts the grunt and Red in a meeting and steps the grunt until it touches her.
func _meet(room: FieldRoom, enemy: MapEnemy, enemy_yaw_deg: float, red_yaw_deg: float) -> void:
	ExplorationKit.prepare(room)
	enemy.auto_step = false
	enemy.global_position = Vector3(2.0, 0.0, 1.0)
	enemy.rotation.y = deg_to_rad(enemy_yaw_deg)
	room.player.global_position = Vector3(1.4, 0.02, 1.0)
	room.player.rotation.y = deg_to_rad(red_yaw_deg)
	await ExplorationKit.ticks(self, 2)
	enemy.step(TICK)


func test_a_touch_from_behind_starts_the_fight_with_a_free_first_turn_and_a_win_removes_the_enemy() -> void:
	var room: FieldRoom = _start(ExplorationKit.TEST_A)
	await tree.process_frame
	var grunt: MapEnemy = room.get_node("Grunt") as MapEnemy
	_main.battle_setup_hook = _hook(true)
	await _meet(room, grunt, 90.0, 90.0)  # both look east: Red is behind it
	assert_true(await BattleFlowKit.wait_for_state(tree, _main, Main.State.BATTLE), "the battle started")
	assert_eq(_first_turns, ["party"] as Array[String], "first_turn reached BattleSetup")
	assert_false(room.is_inside_tree(), "the room waits in memory")
	assert_true(await BattleFlowKit.finish_fight(tree, _main, "continue"))
	await tree.process_frame
	assert_eq(_main.get_room(), room)
	assert_true(not is_instance_valid(grunt) or grunt.is_defeated(), "a win removes the grunt")
	assert_true(room.player.is_blinking(), "Red blinks")
	assert_true(_main.get_state() == Main.State.ROOM)


func test_getting_caught_from_behind_gives_the_enemies_the_first_turn() -> void:
	var room: FieldRoom = _start(ExplorationKit.TEST_A)
	await tree.process_frame
	var grunt: MapEnemy = room.get_node("Grunt") as MapEnemy
	_main.battle_setup_hook = _hook(true)
	await _meet(room, grunt, -90.0, -90.0)  # it looks west at her, she looks west (away)
	assert_true(await BattleFlowKit.wait_for_state(tree, _main, Main.State.BATTLE))
	assert_eq(_first_turns, ["enemies"] as Array[String])
	assert_true(await BattleFlowKit.finish_fight(tree, _main, "continue"))


func test_running_away_leaves_the_enemy_standing_and_red_blinks() -> void:
	var room: FieldRoom = _start(ExplorationKit.TEST_A)
	await tree.process_frame
	var grunt: MapEnemy = room.get_node("Grunt") as MapEnemy
	_main.battle_setup_hook = _hook(false)
	await _meet(room, grunt, -90.0, 90.0)  # face to face
	assert_true(await BattleFlowKit.wait_for_state(tree, _main, Main.State.BATTLE))
	assert_eq(_first_turns, ["normal"] as Array[String])
	assert_true(await BattleFlowKit.finish_fight(tree, _main, ""))
	await tree.process_frame
	assert_false(grunt.is_defeated(), "it is still there")
	assert_eq(grunt.get_state(), MapEnemy.State.GIVE_UP, "catching its breath")
	assert_true(room.player.is_blinking())
	assert_false(room.encounters.is_fighting())
	# While Red blinks, standing in it does not start another fight.
	grunt.step(TICK)
	grunt.step(TICK)
	assert_eq(_main.get_state(), Main.State.ROOM)
	assert_eq(_first_turns.size(), 1)


func test_a_won_story_fight_is_gone_when_the_room_is_entered_again() -> void:
	_start(ExplorationKit.TEST_A)
	await tree.process_frame
	assert_true(await _router.call("go_to", "test_b", "from_a"))
	var room: FieldRoom = _main.get_room() as FieldRoom
	var guard: MapEnemy = room.get_node("Guard") as MapEnemy
	_main.battle_setup_hook = _hook(true)
	await _meet(room, guard, 90.0, 90.0)
	assert_true(await BattleFlowKit.wait_for_state(tree, _main, Main.State.BATTLE))
	assert_true(await BattleFlowKit.finish_fight(tree, _main, "continue"))
	await tree.process_frame
	assert_true(bool(_state.call("get_flag", "defeated_test_b_guard")))
	# Leave and come back.
	assert_true(await _router.call("go_to", "test_a", "from_b"))
	assert_true(await _router.call("go_to", "test_b", "from_a"))
	var again: FieldRoom = _main.get_room() as FieldRoom
	assert_eq(again.encounters.enemies().size(), 0, "the guard stays beaten")
	# But the regular grunt in room A is back.
	assert_true(await _router.call("go_to", "test_a", "from_b"))
	assert_eq((_main.get_room() as FieldRoom).encounters.enemies().size(), 1, "regular enemies respawn")
