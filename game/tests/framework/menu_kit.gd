class_name MenuKit
extends RefCounted
## Builders shared by the field menu and shop tests: a fresh GameState copy loaded with the real
## party data, a field menu on the root window with fake audio, and small helpers to press buttons.

const STATE_SCRIPT: String = "res://tests/fixtures/ui/state_with_order.gd"
const PLAIN_STATE_SCRIPT: String = "res://scripts/core/game_state.gd"
const MENU_SCENE: String = "res://scenes/ui/field_menu.tscn"
const CONFIG_SCRIPT: String = "res://scripts/core/config.gd"
const TEST_CREW: Dictionary = {
	"red": {"hp": 42, "hp_max": 42, "juice": 8, "juice_max": 12},
	"otis": {"hp": 61, "hp_max": 66, "juice": 5, "juice_max": 10},
	"mox": {"hp": 30, "hp_max": 34, "juice": 14, "juice_max": 16},
}


## A GameState copy (with set_party_order) holding the real party and starting bag. Freed by the test.
static func make_state(test: TestCase, plain: bool = false) -> Node:
	var state: Node = test.own((load(PLAIN_STATE_SCRIPT if plain else STATE_SCRIPT) as GDScript).new() as Node) as Node
	state.call("load_party", DataDB.get_dict("party/party"))
	state.call("reset")
	# The menu tests were written against a hurt crew with these numbers (they used to be the starting
	# numbers in party.json); the real start is now full HP from StatCalc, so set them here.
	for id: String in TEST_CREW:
		state.call("update_member", id, TEST_CREW[id])
	return state


static func make_config(test: TestCase, scratch_path: String) -> Node:
	var cfg: Node = test.own((load(CONFIG_SCRIPT) as GDScript).new() as Node) as Node
	cfg.set("save_path", scratch_path)
	return cfg


## A field menu on the root window that ticks by hand, with no animation and a fake audio target.
static func make_menu(test: TestCase, state: Node, audio: FakeAudio, config: Node = null) -> FieldMenu:
	var menu: FieldMenu = (load(MENU_SCENE) as PackedScene).instantiate() as FieldMenu
	menu.manual_ticks = true
	menu.animations_enabled = false
	menu.game_state = state
	menu.config = config
	menu.audio.target = audio
	test.add_to_root(menu)
	return menu


static func press(menu: FieldMenu, commands: Array) -> void:
	for command: MenuInput.Cmd in commands:
		menu.handle_command(command)


## Opens the menu and walks to the page at `index` in the main list, then presses confirm.
static func open_page(menu: FieldMenu, index: int) -> void:
	menu.open()
	for i: int in index:
		menu.handle_command(MenuInput.Cmd.DOWN)
	menu.handle_command(MenuInput.Cmd.CONFIRM)


## Puts `count` of an item in the bag.
static func give(state: Node, item_id: String, count: int = 1) -> void:
	state.call("add_item", item_id, count)
