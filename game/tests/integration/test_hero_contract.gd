extends TestCase
## VS-4, the hero contract (docs/slice/slice_tech_plan.md 2.6): the old field Red (PlayerController) and the new action
## Red (ActionPlayer) both answer every HeroLink call, so the town code (dialogue, shops, interactor, doors, the router's
## fade hold) works with either. Also: ActionPlayer's town mode, and Decision 3 (the attack button talks) end to end.

const OLD_RED: String = "res://scenes/actors/player.tscn"
const NEW_RED: String = "res://scenes/actors/action_player.tscn"
const DT: float = 1.0 / 60.0

var _floor: StaticBody3D = null


func after_each() -> void:
	for action: StringName in [&"light", &"jump", &"interact"]:
		Input.action_release(action)


func _world() -> void:
	_floor = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(80, 2, 80)
	shape.shape = box
	_floor.add_child(shape)
	_floor.collision_layer = 1
	add_to_root(_floor)
	_floor.global_position = Vector3(0, -1, 0)


func _action_red() -> ActionPlayer:
	var red: ActionPlayer = (load(NEW_RED) as PackedScene).instantiate() as ActionPlayer
	red.read_engine_input = false
	add_to_root(red)
	red.set_physics_process(false)
	red.global_position = Vector3(0, 0.02, 0)
	return red


func _settle(red: ActionPlayer, frames: int = 12) -> void:
	await tree.physics_frame
	await tree.physics_frame
	for i: int in frames:
		red.tick(DT)


func _tick(red: ActionPlayer, frames: int) -> void:
	for i: int in frames:
		red.tick(DT)


# ---- both heroes carry the whole contract ----

func test_the_old_red_has_every_member() -> void:
	var red: Node = (load(OLD_RED) as PackedScene).instantiate()
	add_to_root(red)
	assert_eq(HeroLink.missing_members(red).size(), 0, "missing: %s" % [HeroLink.missing_members(red)])
	assert_true(HeroLink.is_hero(red))


func test_the_new_red_has_every_member() -> void:
	var red: ActionPlayer = _action_red()
	assert_eq(HeroLink.missing_members(red).size(), 0, "missing: %s" % [HeroLink.missing_members(red)])
	assert_true(HeroLink.is_hero(red))
	assert_true(red is CharacterBody3D, "town code only needs a CharacterBody3D")


func test_something_that_is_not_a_hero_is_reported() -> void:
	var node: Node3D = Node3D.new()
	add_to_root(node)
	assert_gt(HeroLink.missing_members(node).size(), 5)
	assert_false(HeroLink.is_hero(node))
	assert_false(HeroLink.is_hero(null))


func test_hero_link_is_safe_on_nobody() -> void:
	assert_false(HeroLink.is_frozen(null))
	assert_false(HeroLink.is_scripted(null))
	assert_false(HeroLink.is_catchable(null))
	assert_false(HeroLink.is_on_floor(null))
	assert_eq(HeroLink.get_stick(null), Vector2.ZERO)
	assert_eq(HeroLink.get_move_direction(null), Vector3.ZERO)
	HeroLink.set_frozen(null, true)
	HeroLink.set_scripted(null, true)
	HeroLink.start_blink(null)
	HeroLink.block_jump_for_frames(null, 3)
	var gone: Node3D = Node3D.new()
	gone.free()
	HeroLink.set_frozen(gone, true)
	assert_false(HeroLink.is_frozen(gone), "a freed hero is nobody")


func test_the_old_red_still_works_through_the_link() -> void:
	var red: PlayerController = (load(OLD_RED) as PackedScene).instantiate() as PlayerController
	add_to_root(red)
	assert_false(HeroLink.is_frozen(red))
	HeroLink.set_frozen(red, true)
	assert_true(red.frozen)
	HeroLink.set_scripted(red, true, &"walk")
	assert_true(HeroLink.is_scripted(red))
	HeroLink.set_scripted(red, false)
	assert_false(red.scripted)
	assert_true(HeroLink.is_catchable(red))
	HeroLink.start_blink(red, 1.0)
	assert_false(HeroLink.is_catchable(red))
	assert_eq(HeroLink.has_animation(red, &"no_such_clip"), false)


# ---- ActionPlayer through the link ----

func test_frozen_stops_walking_and_attacking() -> void:
	_world()
	var red: ActionPlayer = _action_red()
	await _settle(red)
	HeroLink.set_frozen(red, true)
	red.set_move_input(Vector2(0, -1))
	red.press(&"light")
	_tick(red, 30)
	assert_almost_eq(red.global_position.x, 0.0, 0.05)
	assert_almost_eq(red.global_position.z, 0.0, 0.05, "frozen: she does not run")
	assert_ne(red.get_state(), ActionPlayer.State.ATTACK, "frozen: no swing")
	HeroLink.set_frozen(red, false)
	red.set_move_input(Vector2(0, -1))
	_tick(red, 30)
	assert_gt(absf(red.global_position.z), 1.0, "unfrozen: she runs again")


func test_stick_property_reads_and_clears_the_stick() -> void:
	var red: ActionPlayer = _action_red()
	red.set_move_input(Vector2(0.5, 0.0))
	assert_almost_eq(HeroLink.get_stick(red).x, 0.5)
	HeroLink.set_stick(red, Vector2.ZERO)
	assert_eq(HeroLink.get_stick(red), Vector2.ZERO)


func test_scripted_hands_her_to_a_sequence_and_back() -> void:
	_world()
	var red: ActionPlayer = _action_red()
	await _settle(red)
	HeroLink.set_scripted(red, true, &"walk")
	assert_true(HeroLink.is_scripted(red))
	assert_false(HeroLink.is_catchable(red), "nothing catches her mid-sequence")
	red.set_move_input(Vector2(1, 0))
	_tick(red, 20)
	assert_almost_eq(red.global_position.x, 0.0, 0.01, "her own physics are off while scripted")
	red.global_position = Vector3(3, 0.02, 0)         # the sequence moves her
	HeroLink.set_scripted(red, false)
	assert_false(HeroLink.is_scripted(red))
	assert_true(HeroLink.is_catchable(red))
	assert_eq(red.get_control_mode(), ActionPlayer.ControlMode.NORMAL)


func test_clip_names_from_the_town_code_map_onto_her_model() -> void:
	var red: ActionPlayer = _action_red()
	if red.get_animation_player() == null:
		return                                            # a build without the model has no clips to ask
	assert_true(HeroLink.has_animation(red, &"walk"), "walk")
	assert_true(HeroLink.has_animation(red, &"jump"), "the town's 'jump' is her jump_up clip")
	assert_false(HeroLink.has_animation(red, &"no_such_clip"))
	HeroLink.set_scripted(red, true, &"walk")
	assert_eq(red.current_clip(), &"walk")
	HeroLink.set_scripted(red, true, &"jump")
	assert_eq(red.current_clip(), &"jump_up")


func test_blink_makes_her_uncatchable_for_a_while() -> void:
	_world()
	var red: ActionPlayer = _action_red()
	await _settle(red)
	assert_true(HeroLink.is_catchable(red))
	HeroLink.start_blink(red, 0.5)
	assert_true(red.is_blinking())
	assert_false(HeroLink.is_catchable(red))
	_tick(red, 40)
	assert_false(red.is_blinking(), "0.5 s is over after 40 frames")
	assert_true(HeroLink.is_catchable(red))


func test_block_jump_ignores_the_press_that_closed_a_menu() -> void:
	_world()
	var red: ActionPlayer = _action_red()
	await _settle(red)
	HeroLink.block_jump_for_frames(red, 6)
	red.press(&"jump")
	_tick(red, 3)
	assert_true(red.is_on_floor(), "blocked: no jump")
	red.release(&"jump")
	_tick(red, 10)
	red.press(&"jump")
	_tick(red, 4)
	assert_false(red.is_on_floor(), "after the block: she jumps")


func test_ground_height_follows_the_floor_and_resets() -> void:
	_world()
	var red: ActionPlayer = _action_red()
	await _settle(red)
	var ground: float = red.get_ground_height()
	red.press(&"jump")
	_tick(red, 14)
	assert_gt(red.global_position.y, ground + 0.2, "in the air")
	assert_almost_eq(red.get_ground_height(), ground, 0.05, "the town camera keeps the ground height, not the jump")
	HeroLink.reset_ground_height(red)
	assert_almost_eq(red.get_ground_height(), red.global_position.y, 0.001)


# ---- town mode ----

func test_town_mode_turns_attacks_and_hacks_off_but_not_movement() -> void:
	_world()
	var red: ActionPlayer = _action_red()
	await _settle(red)
	red.set_town_mode(true)
	var called_out: Array = []
	red.hack_pressed.connect(func(info: Dictionary) -> void: called_out.append(info))
	red.press(&"light")
	red.press(&"heavy")
	red.press(&"parry")
	_tick(red, 20)
	assert_ne(red.get_state(), ActionPlayer.State.ATTACK, "no swing in town")
	assert_ne(red.get_state(), ActionPlayer.State.PARRY, "no parry in town")
	assert_eq(called_out.size(), 0, "no hack in town")
	red.release(&"light")
	red.release(&"heavy")
	red.release(&"parry")
	red.set_move_input(Vector2(1, 0))
	_tick(red, 20)
	assert_gt(red.global_position.x, 1.0, "she still runs")
	red.press(&"jump")
	_tick(red, 5)
	assert_false(red.is_on_floor(), "and jumps")
	red.set_town_mode(false)
	red.release(&"jump")
	_tick(red, 90)
	red.set_move_input(Vector2.ZERO)
	_tick(red, 20)
	red.press(&"light")
	_tick(red, 4)
	assert_eq(red.get_state(), ActionPlayer.State.ATTACK, "out of town mode the same button swings")


# ---- the town code with ActionPlayer ----

func _interactor(red: ActionPlayer, rules: InteractRules, combat_room: bool) -> PlayerInteractor:
	var interactor: PlayerInteractor = PlayerInteractor.new()
	interactor.player = red
	interactor.read_engine_input = false
	interactor.rules = rules
	interactor.combat_room = combat_room
	add_to_root(interactor)
	interactor.install_press_filter()
	return interactor


## A talk spot one metre in front of her (she faces +Z) whose use is a counter.
func _spot(counter: Array) -> Interactable:
	var spot: Interactable = Interactable.new()
	spot.kind = Interactable.Kind.EXAMINE
	spot.conversation = "x"
	spot.position = Vector3(0.0, 0.0, 1.0)
	spot.handler = func(_hero: CharacterBody3D, _interactor: PlayerInteractor) -> bool:
		counter.append(1)
		return true
	add_to_root(spot)
	return spot


func _enemy_at(distance: float) -> CombatActor:
	var enemy: CombatActor = CombatActor.new()
	enemy.actor_id = &"dummy_enemy"
	enemy.team = &"enemy"
	enemy.move_set_id = &"grunt"
	add_to_root(enemy)
	enemy.global_position = Vector3(0.0, 0.0, distance)
	return enemy


func test_the_interactor_finds_things_for_the_action_red() -> void:
	_world()
	var red: ActionPlayer = _action_red()
	await _settle(red)
	var used: Array = []
	var spot: Interactable = _spot(used)
	var interactor: PlayerInteractor = _interactor(red, null, false)
	interactor.refresh()
	assert_eq(interactor.get_target(), spot, "the spot in front of her is the target")
	assert_true(interactor.try_interact())
	assert_eq(used.size(), 1, "its handler ran with ActionPlayer as the hero")


func test_option_a_in_town_the_attack_button_talks_and_does_not_swing() -> void:
	_world()
	var red: ActionPlayer = _action_red()
	await _settle(red)
	red.set_town_mode(true)
	var used: Array = []
	_spot(used)
	_interactor(red, InteractRules.from_data({"mode": "attack_button"}), false)
	red.press(&"light")
	_tick(red, 3)
	assert_eq(used.size(), 1, "one press, one use")
	assert_ne(red.get_state(), ActionPlayer.State.ATTACK)


func test_option_a_in_a_dungeon_talks_only_when_no_enemy_is_close() -> void:
	_world()
	var red: ActionPlayer = _action_red()
	await _settle(red)
	var used: Array = []
	_spot(used)
	_interactor(red, InteractRules.from_data({"mode": "attack_button", "clear_m": 5.0}), true)
	var enemy: CombatActor = _enemy_at(3.0)
	red.press(&"light")
	_tick(red, 3)
	assert_eq(used.size(), 0, "an enemy 3 m away: the button swings")
	assert_eq(red.get_state(), ActionPlayer.State.ATTACK)
	enemy.global_position = Vector3(0.0, 0.0, 30.0)
	_tick(red, 90)
	red.release(&"light")
	_tick(red, 10)
	assert_ne(red.get_state(), ActionPlayer.State.ATTACK, "the swing is over")
	red.press(&"light")
	_tick(red, 3)
	assert_eq(used.size(), 1, "the enemy is far away: the same button now uses the thing")
	assert_ne(red.get_state(), ActionPlayer.State.ATTACK)


func test_a_dead_enemy_does_not_count_as_close() -> void:
	_world()
	var red: ActionPlayer = _action_red()
	await _settle(red)
	var used: Array = []
	_spot(used)
	_interactor(red, InteractRules.from_data({"mode": "attack_button", "clear_m": 5.0}), true)
	var enemy: CombatActor = _enemy_at(2.0)
	enemy.dead = true
	red.press(&"light")
	_tick(red, 3)
	assert_eq(used.size(), 1)


func test_option_b_the_attack_button_always_swings() -> void:
	_world()
	var red: ActionPlayer = _action_red()
	await _settle(red)
	var used: Array = []
	_spot(used)
	_interactor(red, InteractRules.from_data({"mode": "own_button"}), true)
	red.press(&"light")
	_tick(red, 3)
	assert_eq(used.size(), 0, "option B: the attack button never talks")
	assert_eq(red.get_state(), ActionPlayer.State.ATTACK)


func test_no_prompt_means_the_attack_button_attacks() -> void:
	_world()
	var red: ActionPlayer = _action_red()
	await _settle(red)
	_interactor(red, InteractRules.from_data({"mode": "attack_button"}), true)
	red.press(&"light")
	_tick(red, 3)
	assert_eq(red.get_state(), ActionPlayer.State.ATTACK, "nothing to talk to: swing")


func test_the_dialogue_runner_freezes_and_frees_the_action_red() -> void:
	var red: ActionPlayer = _action_red()
	var runner: DialogueRunner = DialogueRunner.new()
	runner.manual_ticks = true
	runner.chars_per_second_override = 100.0
	var stage_root: Control = Control.new()
	stage_root.size = Vector2(384, 216)
	add_to_root(stage_root)
	runner.parent_override = stage_root
	add_to_root(runner)
	runner.player = red
	runner.add_conversations({"hello": [{"speaker": "red", "text": "Hi."}]})
	assert_true(runner.start("hello"))
	assert_true(red.frozen, "talking freezes her")
	for i: int in 200:
		if not runner.is_running():
			break
		runner.confirm()
		runner.tick(0.5)
	assert_false(runner.is_running())
	for i: int in 3:
		runner.tick(0.1)                  # she is let go a couple of frames after the last bubble (so its button press can't jump)
	assert_false(red.frozen, "and frees her afterwards")


func test_the_shop_menu_freezes_and_frees_the_action_red() -> void:
	var red: ActionPlayer = _action_red()
	var state: Node = MenuKit.make_state(self)
	state.call("add_credits", 100)
	var menu: ShopMenu = (load("res://scenes/ui/shop_menu.tscn") as PackedScene).instantiate() as ShopMenu
	menu.manual_ticks = true
	menu.animations_enabled = false
	menu.game_state = state
	add_to_root(menu)
	menu.player = red
	assert_true(menu.open_shop("test_general"))
	assert_true(red.frozen, "shopping freezes her")
	menu.close()
	for i: int in 3:
		menu.tick(0.016)
	assert_false(red.frozen, "and frees her after")


func test_the_router_holds_the_action_red_during_a_fade() -> void:
	var red: ActionPlayer = _action_red()
	var router: Node = own(load("res://scripts/core/scene_router.gd").new()) as Node
	var room: RoomWithPlayer = RoomWithPlayer.new()
	room.player = red
	add_to_root(room)
	red.set_move_input(Vector2(1, 0))
	router.call("_hold_player", room)
	assert_true(red.frozen, "held while the screen fades")
	assert_eq(red.stick, Vector2.ZERO, "and the stick is let go")
	router.call("_release_player", room)
	assert_false(red.frozen)


class RoomWithPlayer extends Node:
	var player: CharacterBody3D = null
