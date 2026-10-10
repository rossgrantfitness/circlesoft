extends TestCase
## The command flow, from the stub's command_needed down to the dictionary the HUD submits:
## Attack / Skills / Items / Defend / Run, greyed skills with a reason, item counts, targeting
## (single and whole side), cancel, per-character cursor memory, and the mouse.

const HUD_SCENE: String = "res://scenes/ui/battle/battle_hud.tscn"
const UP: MenuInput.Cmd = MenuInput.Cmd.UP
const DOWN: MenuInput.Cmd = MenuInput.Cmd.DOWN
const LEFT: MenuInput.Cmd = MenuInput.Cmd.LEFT
const RIGHT: MenuInput.Cmd = MenuInput.Cmd.RIGHT
const OK: MenuInput.Cmd = MenuInput.Cmd.CONFIRM
const BACK: MenuInput.Cmd = MenuInput.Cmd.CANCEL

var _audio: FakeAudio = null
var _hud: BattleHud = null
var _stub: BattleHudStub = null


func _setup(options: Dictionary = {}, actor: String = "red") -> void:
	_audio = FakeAudio.new()
	_hud = (load(HUD_SCENE) as PackedScene).instantiate() as BattleHud
	_hud.manual_ticks = true
	_hud.animations_enabled = false
	_hud.audio.target = _audio
	add_to_root(_hud)
	_stub = BattleHudStub.new()
	_hud.bind(_stub)
	_stub.start()
	_ask(options if not options.is_empty() else BattleHudStub.default_options(), actor)


func _ask(options: Dictionary, actor: String) -> void:
	_stub.turn_started.emit(actor)
	_stub.command_needed.emit(actor, options)


func _go(commands: Array) -> void:
	for command: MenuInput.Cmd in commands:
		_hud.handle_command(command)


func _menu() -> BattleCommandMenu:
	return _hud.get_menu()


func _last() -> Dictionary:
	return _stub.commands.back() if not _stub.commands.is_empty() else {}


func _rows(list: MenuList) -> Array[String]:
	var labels: Array[String] = []
	for row: Dictionary in list.get_items():
		labels.append(str(row["label"]))
	return labels


# ---- the main list ----

func test_command_needed_opens_the_menu_with_the_five_commands() -> void:
	_setup()
	assert_true(_menu().is_open())
	assert_eq(_menu().get_state(), BattleCommandMenu.State.MAIN)
	assert_eq(_rows(_menu().get_main_list()), ["Attack", "Skills", "Items", "Defend", "Run"])
	assert_eq(_hud.get_mode(), BattleHud.Mode.COMMAND)
	assert_eq(_menu().get_actor(), "red")


func test_attack_goes_through_target_selection_to_a_command_dictionary() -> void:
	_setup()
	_go([OK])
	assert_eq(_menu().get_state(), BattleCommandMenu.State.TARGET)
	assert_eq(_menu().get_targeting().get_selected(), "e1")
	_go([OK])
	assert_eq(_last(), {"kind": "attack", "targets": ["e1"]})
	assert_false(_menu().is_open())
	assert_eq(_hud.get_mode(), BattleHud.Mode.PLAYING)


func test_defend_and_run_submit_at_once() -> void:
	_setup()
	_go([DOWN, DOWN, DOWN, OK])
	assert_eq(_last(), {"kind": "defend"})
	_ask(BattleHudStub.default_options(), "otis")
	_go([DOWN, DOWN, DOWN, DOWN, OK])
	assert_eq(_last(), {"kind": "run"})


func test_the_cursor_wraps_around_the_main_list() -> void:
	_setup()
	_go([UP])
	assert_eq(_menu().get_main_list().get_cursor_index(), 4)
	_go([DOWN])
	assert_eq(_menu().get_main_list().get_cursor_index(), 0)


func test_run_is_greyed_with_a_reason_when_the_fight_cannot_be_escaped() -> void:
	_setup(BattleHudStub.default_options(false))
	_go([UP])
	assert_eq(_menu().get_hint_text(), "Can't run from this one!")
	_go([OK])
	assert_true(_stub.commands.is_empty(), "a greyed Run submits nothing")
	assert_true(_menu().is_open())
	assert_eq(_hud.get_banner().get_current_text(), "Can't run from this one!")
	assert_has(_audio.sfx_ids, "menu_back", "the buzz")


func test_commands_the_model_disables_are_greyed() -> void:
	var options: Dictionary = BattleHudStub.default_options()
	options["attack"] = false
	options["items"] = []
	_setup(options)
	var rows: Array[Dictionary] = _menu().get_main_list().get_items()
	assert_false(rows[0]["enabled"])
	assert_true(rows[1]["enabled"])
	assert_false(rows[2]["enabled"])
	assert_true(rows[3]["enabled"])
	_go([OK])
	assert_true(_stub.commands.is_empty())
	assert_eq(_menu().get_state(), BattleCommandMenu.State.MAIN)


func test_the_hint_line_follows_the_highlighted_command() -> void:
	_setup()
	assert_eq(_menu().get_hint_text(), BattleUiData.text("commands.attack.hint"))
	_go([DOWN])
	assert_eq(_menu().get_hint_text(), BattleUiData.text("commands.skills.hint"))


# ---- skills ----

func test_skills_submenu_shows_juice_costs() -> void:
	_setup()
	_go([DOWN, OK])
	assert_eq(_menu().get_state(), BattleCommandMenu.State.SKILLS)
	var rows: Array[Dictionary] = _menu().get_sub_list().get_items()
	assert_eq(_rows(_menu().get_sub_list()), ["Porch Light", "Sweep the Yard", "Big Swing"])
	assert_eq(rows[0]["value"], "4 Juice")
	assert_eq(rows[1]["value"], "6 Juice")
	assert_eq(rows[2]["value"], "10 Juice")


func test_skill_that_costs_too_much_is_greyed_with_the_juice_reason() -> void:
	_setup()  # Red has 8 Juice; Big Swing costs 10 and the stub marks it unusable
	_go([DOWN, OK, DOWN, DOWN])
	assert_false(_menu().get_sub_list().get_items()[2]["enabled"])
	assert_eq(_menu().get_hint_text(), "Not enough Juice.")
	_go([OK])
	assert_true(_stub.commands.is_empty(), "a greyed skill cannot be picked")
	assert_eq(_menu().get_state(), BattleCommandMenu.State.SKILLS)
	assert_eq(_hud.get_banner().get_current_text(), "Not enough Juice.")


func test_noise_ticket_greys_every_skill_with_its_own_reason() -> void:
	var options: Dictionary = BattleHudStub.default_options()
	for skill: Dictionary in options["skills"]:
		skill["usable"] = false
	_setup(options)
	_stub.status_changed.emit("red", "noise_ticket", true)
	_ask(options, "red")
	_go([DOWN, OK])
	assert_eq(_menu().get_state(), BattleCommandMenu.State.SKILLS)
	for row: Dictionary in _menu().get_sub_list().get_items():
		assert_false(row["enabled"])
		assert_eq(row["reason"], "noise_ticket")
	assert_eq(_menu().get_hint_text(), "Noise Ticket! No skills.")


func test_with_no_skills_at_all_the_skills_row_is_greyed() -> void:
	var options: Dictionary = BattleHudStub.default_options()
	options["skills"] = []
	_setup(options)
	_go([DOWN])
	assert_false(_menu().get_main_list().get_items()[1]["enabled"])
	assert_eq(_menu().get_hint_text(), "No skills yet.")
	_stub.status_changed.emit("red", "noise_ticket", true)
	_ask(options, "red")  # Red's cursor is remembered on Skills
	assert_eq(_menu().get_hint_text(), "Noise Ticket! No skills.", "Noise Ticket gets named")


func test_a_skill_goes_through_targeting_into_a_skill_command() -> void:
	_setup()
	_go([DOWN, OK, OK])  # Porch Light -> targeting
	assert_eq(_menu().get_state(), BattleCommandMenu.State.TARGET)
	_go([OK])
	assert_eq(_last(), {"kind": "skill", "skill_id": "porch_light", "targets": ["e1"]})


func test_all_enemy_skill_lights_the_whole_side_and_sends_every_live_enemy() -> void:
	_setup()
	_stub.combatant_down.emit("e2")
	_go([DOWN, OK, DOWN, OK])  # Sweep the Yard
	var targeting: BattleTargeting = _menu().get_targeting()
	assert_true(targeting.is_all)
	assert_eq(_hud.get_target_cursor().get_marked_ids(), ["e1", "e3"], "the whole side is marked, the fallen skipped")
	assert_eq(_hud.get_target_cursor().get_tag_text(), "All enemies")
	_go([RIGHT, OK])
	assert_eq(_last(), {"kind": "skill", "skill_id": "sweep_the_yard", "targets": ["e1", "e3"]})


func test_a_skill_that_targets_the_user_skips_the_pick() -> void:
	var options: Dictionary = BattleHudStub.default_options()
	options["skills"] = [{"id": "pep_talk", "name": "Pep Talk", "juice_cost": 2, "usable": true, "target": "self"}]
	_setup(options)
	_go([DOWN, OK, OK])
	assert_eq(_last(), {"kind": "skill", "skill_id": "pep_talk", "targets": ["red"]})


# ---- items ----

func test_items_submenu_shows_counts_and_greys_empty_stacks() -> void:
	_setup()
	_go([DOWN, DOWN, OK])
	assert_eq(_menu().get_state(), BattleCommandMenu.State.ITEMS)
	var rows: Array[Dictionary] = _menu().get_sub_list().get_items()
	assert_eq(rows[0]["value"], "x2")
	assert_eq(rows[1]["value"], "x1")
	assert_eq(rows[2]["value"], "x0")
	assert_true(rows[0]["enabled"])
	assert_false(rows[2]["enabled"])
	_go([DOWN, DOWN])
	assert_eq(_menu().get_hint_text(), "None left.")


func test_using_an_item_on_an_ally_sends_an_item_command() -> void:
	_setup()
	_go([DOWN, DOWN, OK, OK])  # Ration Bar -> one_ally
	assert_eq(_menu().get_state(), BattleCommandMenu.State.TARGET)
	assert_eq(_menu().get_targeting().candidates, ["red", "otis", "mox"])
	_go([DOWN, OK])
	assert_eq(_last().get("kind"), "item")
	assert_eq(_last().get("item_id"), "ration_bar")
	assert_eq(_last().get("targets").size(), 1)
	assert_has(["otis", "mox"], _last()["targets"][0])


func test_a_revive_item_only_offers_downed_allies() -> void:
	_setup()
	_stub.combatant_down.emit("otis")
	_go([DOWN, DOWN, OK, DOWN, OK])  # Smelling Salts
	assert_eq(_menu().get_state(), BattleCommandMenu.State.TARGET)
	assert_eq(_menu().get_targeting().candidates, ["otis"])
	_go([OK])
	assert_eq(_last(), {"kind": "item", "item_id": "smelling_salts", "targets": ["otis"]})


func test_a_revive_with_nobody_down_says_so_and_stays_put() -> void:
	_setup()
	_go([DOWN, DOWN, OK, DOWN, OK])
	assert_eq(_menu().get_state(), BattleCommandMenu.State.ITEMS)
	assert_eq(_hud.get_banner().get_current_text(), "No one to use that on.")
	assert_true(_stub.commands.is_empty())


# ---- targeting ----

func test_target_pointer_hops_between_enemies_by_screen_position() -> void:
	_setup()
	_go([OK])
	var t: BattleTargeting = _menu().get_targeting()
	# Fallback layout: e1 top-middle (160,76), e2 left (124,96), e3 right (196,96).
	assert_eq(t.get_selected(), "e1")
	_go([RIGHT])
	assert_eq(t.get_selected(), "e3")
	_go([LEFT])
	assert_eq(t.get_selected(), "e2", "straight left of e3 is e2")
	_go([RIGHT])
	assert_eq(t.get_selected(), "e3")
	_go([LEFT, UP])
	assert_eq(t.get_selected(), "e1", "up from e2 is e1")
	_go([DOWN])
	assert_eq(t.get_selected(), "e2", "down from e1: e2 and e3 tie, the first wins")


func test_pointer_wraps_around_at_the_edge() -> void:
	_setup()
	_go([OK, RIGHT, RIGHT])
	assert_eq(_menu().get_targeting().get_selected(), "e1", "past the last enemy wraps to the first in the list")


func test_the_pointer_skips_fallen_enemies() -> void:
	_setup()
	_stub.combatant_down.emit("e1")
	_go([OK])
	assert_eq(_menu().get_targeting().candidates, ["e2", "e3"])
	assert_eq(_menu().get_targeting().get_selected(), "e2")


func test_the_target_tag_names_the_pointed_enemy() -> void:
	_setup()
	_go([OK])
	assert_eq(_hud.get_target_cursor().get_tag_text(), "Signals Grunt")
	_go([RIGHT])
	assert_eq(_hud.get_target_cursor().get_tag_text(), "Signals Drone")
	assert_true(_hud.get_target_cursor().visible)


func test_targets_use_the_stage_positions_when_a_stage_is_set() -> void:
	_setup()
	var stage: Node = own(Node.new()) as Node
	stage.set_script(_stage_script())
	stage.set("points", {"e1": Vector2(300, 50), "e2": Vector2(50, 50), "e3": Vector2(180, 50)})
	_hud.stage = stage
	_go([OK])
	var t: BattleTargeting = _menu().get_targeting()
	assert_eq(t.get_selected(), "e1")
	_go([LEFT])
	assert_eq(t.get_selected(), "e3", "left of e1 on the stage's layout is e3")
	_go([LEFT])
	assert_eq(t.get_selected(), "e2")


func _stage_script() -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node\nvar points: Dictionary = {}\nfunc screen_pos_of(id: String) -> Vector2:\n\treturn points.get(id, Vector2.ZERO)\n"
	script.reload()
	return script


# ---- cancel ----

func test_cancel_backs_out_one_step_at_a_time() -> void:
	_setup()
	_go([DOWN, OK, OK])  # skills -> Porch Light -> target
	assert_eq(_menu().get_state(), BattleCommandMenu.State.TARGET)
	_go([BACK])
	assert_eq(_menu().get_state(), BattleCommandMenu.State.SKILLS)
	_go([BACK])
	assert_eq(_menu().get_state(), BattleCommandMenu.State.MAIN)
	_go([BACK])
	assert_eq(_menu().get_state(), BattleCommandMenu.State.MAIN, "nothing to back out of at the top")
	assert_true(_stub.commands.is_empty())
	assert_has(_audio.sfx_ids, "menu_back")


func test_cancel_from_an_attack_target_returns_to_the_main_list() -> void:
	_setup()
	_go([OK, BACK])
	assert_eq(_menu().get_state(), BattleCommandMenu.State.MAIN)
	assert_false(_hud.get_target_cursor().visible)


# ---- memory ----

func test_cursor_memory_is_kept_per_character() -> void:
	_setup()
	_go([DOWN, OK, DOWN, OK, OK])  # Red: Skills -> Sweep the Yard -> all enemies
	assert_eq(_last()["skill_id"], "sweep_the_yard")
	# Otis has his own list and starts from the top.
	_ask(BattleHudStub.default_options(), "otis")
	assert_eq(_menu().get_main_list().get_cursor_index(), 0)
	_go([DOWN, DOWN, OK])
	assert_eq(_menu().get_state(), BattleCommandMenu.State.ITEMS)
	_go([DOWN])  # Otis's item cursor on row 1
	_go([BACK, BACK]) 
	# Back to Red: her main row is Skills, her skill row is Sweep the Yard, her last single target e3.
	_stub.commands.clear()
	_ask(BattleHudStub.default_options(), "red")
	assert_eq(_menu().get_main_list().get_cursor_index(), 1, "Red's main row")
	_go([OK])
	assert_eq(_menu().get_sub_list().get_cursor_index(), 1, "Red's skill row")


func test_the_last_target_is_remembered_for_the_same_character() -> void:
	_setup()
	_go([OK, RIGHT, OK])  # attack e3
	assert_eq(_last()["targets"], ["e3"])
	_ask(BattleHudStub.default_options(), "red")
	_go([OK])
	assert_eq(_menu().get_targeting().get_selected(), "e3")
	_ask(BattleHudStub.default_options(), "otis")
	_go([OK])
	assert_eq(_menu().get_targeting().get_selected(), "e1", "another fighter starts fresh")


func test_a_remembered_target_that_has_fallen_is_not_used() -> void:
	_setup()
	_go([OK, RIGHT, OK])
	_stub.combatant_down.emit("e3")
	_ask(BattleHudStub.default_options(), "red")
	_go([OK])
	assert_eq(_menu().get_targeting().get_selected(), "e1")


# ---- mouse ----

func _motion(point: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	return event


func _click(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = true
	return event


func test_mouse_hover_moves_the_cursor_and_click_picks_a_command() -> void:
	_setup()
	var list: MenuList = _menu().get_main_list()
	var row_rect: Rect2 = list.get_row_rect(3)
	var at: Vector2 = list.get_global_transform() * row_rect.get_center()
	assert_true(_hud.handle_mouse(_motion(at)))
	assert_eq(list.get_cursor_index(), 3)
	assert_true(_hud.handle_mouse(_click(at)))
	assert_eq(_last(), {"kind": "defend"})


func test_mouse_picks_a_target_by_clicking_the_enemy_and_right_click_backs_out() -> void:
	_setup()
	_go([OK])
	var spot: Vector2 = _hud.position_of("e3") + Vector2(0, 14)
	_hud.handle_mouse(_motion(spot))
	assert_eq(_menu().get_targeting().get_selected(), "e3")
	assert_true(_hud.handle_mouse(_click(Vector2(5, 5), MOUSE_BUTTON_RIGHT)))
	assert_eq(_menu().get_state(), BattleCommandMenu.State.MAIN)
	_go([OK])
	assert_true(_hud.handle_mouse(_click(spot)))
	assert_eq(_last(), {"kind": "attack", "targets": ["e3"]})


func test_a_mouse_click_on_a_greyed_skill_says_why() -> void:
	_setup()
	_go([DOWN, OK])
	var list: MenuList = _menu().get_sub_list()
	var at: Vector2 = list.get_global_transform() * list.get_row_rect(2).get_center()
	_hud.handle_mouse(_click(at))
	assert_true(_stub.commands.is_empty())
	assert_eq(_hud.get_banner().get_current_text(), "Not enough Juice.")


# ---- sounds, slide ----

func test_the_cursor_ticks_and_confirm_sounds_play() -> void:
	_setup()
	_go([DOWN, OK])
	assert_has(_audio.sfx_ids, "menu_tick")
	assert_has(_audio.sfx_ids, "menu_confirm")
	assert_has(_audio.sfx_ids, "battle_menu_open")


func test_the_menu_slides_away_when_a_move_starts_and_back_for_the_next_turn() -> void:
	_setup()
	assert_eq(_hud.get_menu_slide(), 1.0)
	_go([DOWN, DOWN, DOWN, OK])
	assert_eq(_hud.get_menu_slide(), 0.0)
	assert_false(_menu().visible)
	_ask(BattleHudStub.default_options(), "otis")
	assert_eq(_hud.get_menu_slide(), 1.0)
	assert_true(_menu().visible)
	_stub.action_started.emit({"actor": "otis", "kind": "attack", "targets": ["e1"], "presses": [], "show_name": false})
	assert_eq(_hud.get_menu_slide(), 0.0, "a move starting hides the menu")
	assert_false(_menu().is_open())


func test_the_menu_slides_off_while_a_target_is_picked_and_back_on_cancel() -> void:
	_setup()
	_go([OK])
	assert_eq(_menu().get_state(), BattleCommandMenu.State.TARGET)
	assert_eq(_hud.get_menu_slide(), 0.0, "fighters are in plain view while one is picked")
	assert_true(_menu().is_open(), "still waiting for the pick")
	_go([BACK])
	assert_eq(_hud.get_menu_slide(), 1.0)
	_go([OK, OK])
	assert_eq(_last().get("kind"), "attack")


func test_the_slide_is_stepped_when_animations_are_on() -> void:
	_setup()
	_hud.animations_enabled = true
	_go([DOWN, DOWN, DOWN, OK])
	assert_eq(_hud.get_menu_slide(), 1.0, "still on its way out")
	_hud.tick(0.0834)
	assert_almost_eq(_hud.get_menu_slide(), 2.0 / 3.0, 0.001)
	_hud.tick(0.0834)
	_hud.tick(0.0834)
	assert_eq(_hud.get_menu_slide(), 0.0)
	assert_false(_menu().visible)
	_hud.tick(0.0834)
	assert_eq(_hud.get_menu_slide(), 0.0)
