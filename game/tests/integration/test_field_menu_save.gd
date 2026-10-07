extends TestCase
## The field menu's Save row with the real SaveManager: greyed away from a lamp; at one it closes the
## menu and opens the lamp's save screen after the menu has let go of Red, so Red ends up free once
## the save screen is gone, and the slot really holds the game.

const SAVE_MANAGER_SCRIPT: String = "res://scripts/core/save_manager.gd"
const PLAYER_SCENE: String = "res://scenes/actors/player.tscn"

var _dir: String = ""


func after_each() -> void:
	if DirAccess.dir_exists_absolute(_dir):
		for file_name: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(file_name))
		DirAccess.remove_absolute(_dir)


func test_saving_from_the_menu_at_a_lamp_writes_a_slot_and_frees_red() -> void:
	_dir = "user://test_menu_save_%d" % Time.get_ticks_usec()
	var state: Node = MenuKit.make_state(self)
	state.call("add_credits", 321)
	var manager: Node = (load(SAVE_MANAGER_SCRIPT) as GDScript).new() as Node
	manager.set("save_dir", _dir)
	manager.set("game_state", state)
	manager.set("auto_save_enabled", false)
	add_to_root(manager)
	var player: PlayerController = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	add_to_root(player)
	var menu: FieldMenu = MenuKit.make_menu(self, state, FakeAudio.new())
	menu.player = player
	menu.save_manager = manager
	menu.save_spot_override = true
	menu.open()
	assert_true(player.frozen)
	menu.get_main_list().set_index(6)
	menu.handle_command(MenuInput.Cmd.CONFIRM)
	assert_false(menu.is_open())
	for i: int in 4:
		menu.tick(0.016)
	var prompt: SavePrompt = menu.get_save_prompt() as SavePrompt
	assert_not_null(prompt, "the lamp's save screen opened")
	assert_true(player.frozen, "Red stays put while saving")
	prompt.finish_animations()
	for i: int in 3:
		prompt.tick(0.016)
	prompt.handle_command(MenuInput.Cmd.CONFIRM)  # the cursor starts on the first manual slot
	assert_eq(prompt.get_saved_slot(), 1)
	assert_eq(int((manager.call("slot_summary", 1) as Dictionary)["credits"]), 321, "the slot holds the game as it was")
	prompt.close()
	prompt.finish_animations()
	for i: int in 4:
		prompt.tick(0.016)
	assert_false(player.frozen, "Red is free again once the save screen is gone")
	assert_false(UiStage.is_busy(tree))
