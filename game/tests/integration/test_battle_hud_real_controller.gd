extends TestCase
## The HUD against the real BattleController (virtual clock, Auto-Timing): the HUD answers every
## command_needed through its own menus, the fight runs to the end, and the end screens appear.
## Skipped quietly if the real controller is not in the project.

const HUD_SCENE: String = "res://scenes/ui/battle/battle_hud.tscn"
const OK: MenuInput.Cmd = MenuInput.Cmd.CONFIRM
const DOWN: MenuInput.Cmd = MenuInput.Cmd.DOWN
const UP: MenuInput.Cmd = MenuInput.Cmd.UP
const BACK: MenuInput.Cmd = MenuInput.Cmd.CANCEL

var _hud: BattleHud = null
var _seen_options: Array[Dictionary] = []
var _rating_popups: int = 0


func _fight(use_skills: bool) -> BattleController:
	var data: BattleData = BattleData.shared()
	var progression: Progression = Progression.new(data)
	var setup: BattleSetup = BattleSetup.new()
	setup.data = data
	setup.encounter_id = "grunt_pair"
	setup.rng_seed = 11
	setup.clock = VirtualClock.new()
	setup.auto_timing = true
	for char_id: String in data.character_order:
		setup.party.append(progression.new_member(char_id, 3))
	setup.bag = {"ration_bar": 2}
	var controller: BattleController = BattleController.create(setup)
	_hud = (load(HUD_SCENE) as PackedScene).instantiate() as BattleHud
	_hud.manual_ticks = true
	_hud.animations_enabled = false
	_hud.audio.target = FakeAudio.new()
	add_to_root(_hud)
	_hud.bind(controller)
	_seen_options.clear()
	# Connected after the HUD, so the HUD has opened its menu when this runs: play the menu like a person.
	controller.command_needed.connect(func(_actor: String, options: Dictionary) -> void: _play_turn(options, use_skills))
	controller.press_judged.connect(func(_info: Dictionary) -> void: _rating_popups = _count_ratings())
	return controller


func _count_ratings() -> int:
	var count: int = 0
	for popup: BattlePopup in _hud.get_popups():
		if popup.kind == BattlePopup.Kind.RATING:
			count += 1
	return maxi(count, _rating_popups)


func _play_turn(options: Dictionary, use_skills: bool) -> void:
	_seen_options.append(options)
	var menu: BattleCommandMenu = _hud.get_menu()
	if use_skills:
		var usable_row: int = -1
		var skills: Array = options.get("skills", [])
		for i: int in skills.size():
			if bool((skills[i] as Dictionary).get("usable", false)):
				usable_row = i
				break
		if usable_row >= 0:
			_main_row(menu, 1)
			_hud.handle_command(OK)
			for i: int in usable_row:
				_hud.handle_command(DOWN)
			_hud.handle_command(OK)
			_confirm_targets(menu)
			if not menu.is_open():
				return
			# The pick went nowhere (say a revive with nobody down): back out and just attack.
			var guard: int = 0
			while menu.get_state() != BattleCommandMenu.State.MAIN and guard < 6:
				_hud.handle_command(BACK)
				guard += 1
	_main_row(menu, 0)
	_hud.handle_command(OK)
	_confirm_targets(menu)


## The cursor remembers where this fighter left it last turn, so walk it to the row we want.
func _main_row(menu: BattleCommandMenu, row: int) -> void:
	var guard: int = 0
	while menu.get_main_list().get_cursor_index() != row and guard < 6:
		_hud.handle_command(DOWN)
		guard += 1


func _confirm_targets(menu: BattleCommandMenu) -> void:
	var guard: int = 0
	while menu.get_state() == BattleCommandMenu.State.TARGET and guard < 8:
		_hud.handle_command(OK)
		guard += 1
	assert_lt(guard, 8, "the target pick always finishes")


func test_a_whole_fight_runs_through_the_hud_with_attacks() -> void:
	var controller: BattleController = _fight(false)
	await controller.start()
	assert_eq(controller.get_result()["result"], "win")
	assert_gt(_seen_options.size(), 0, "the HUD was asked for commands")
	assert_gt(_rating_popups, 0, "Auto-Timing's Rad! pop-ups showed")
	var final_target: String = str(controller.get_result()["report"].get("final_ko_target", ""))
	assert_eq(_hud.has_shown_ko(), not final_target.is_empty(), "the final hit got its K.O.! (unless the last grunt waved a white flag)")
	_hud.tick(5.0)
	assert_true(_hud.get_victory_screen().is_showing() or _hud.get_mode() == BattleHud.Mode.ENDED)
	assert_gt(_hud.get_victory_screen().get_total_time(), 0.0)


func test_a_whole_fight_with_skills_runs_through_the_hud() -> void:
	var controller: BattleController = _fight(true)
	await controller.start()
	assert_eq(controller.get_result()["result"], "win")
	assert_gt(_seen_options.size(), 0)
	assert_true(_hud.get_victory_screen().is_showing() or _hud.get_mode() == BattleHud.Mode.KO or _hud.get_mode() == BattleHud.Mode.VICTORY)


func test_the_roster_and_bars_follow_the_real_signals() -> void:
	var controller: BattleController = _fight(false)
	await controller.start()
	var report: Dictionary = controller.get_result()["report"]
	assert_eq(_hud.roster.ids("party").size(), 3)
	assert_true(_hud.roster.all_out("enemy"))
	for id: String in _hud.roster.ids("party"):
		var final_hp: int = int(_hud.roster.get_member(id).get("hp", -1))
		assert_ge(final_hp, 0)
	_hud.tick(3.0)
	_hud.get_victory_screen().skip()
	assert_has(_hud.get_victory_screen().get_lines(), "XP %d" % int(report["xp"]))


func test_real_command_options_have_the_shape_the_menu_reads() -> void:
	var controller: BattleController = _fight(false)
	await controller.start()
	var options: Dictionary = _seen_options[0]
	assert_true(options.has("attack") and options.has("skills") and options.has("items") and options.has("defend") and options.has("run"))
	for skill: Dictionary in options["skills"]:
		for key: String in ["id", "name", "juice_cost", "usable", "target"]:
			assert_true(skill.has(key), "skill has %s" % key)
