extends SceneTree
## Screenshots of the M3 field menu: main page, Items, Skills, Equip (with the stat arrows), Status,
## Party, Config and the greyed Save row. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m3_menu.gd
## Writes docs/screenshots/m3_menu_*.png (the whole 1280x720 window). Does not name game classes
## (this script compiles before the autoloads exist), so menu commands are the raw numbers of
## MenuInput.Cmd: UP 1, DOWN 2, LEFT 3, RIGHT 4, CONFIRM 5, CANCEL 6.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUT_DIR: String = "res://../docs/screenshots/"
const UP: int = 1
const DOWN: int = 2
const LEFT: int = 3
const RIGHT: int = 4
const CONFIRM: int = 5
const CANCEL: int = 6

var _room: Node = null
var _menu: Node = null
var _state: Node = null


func _initialize() -> void:
	await process_frame
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	await _frames(10)
	_room = main.get_node("PsxScreen/WorldViewport/World/PsxTestRoom")
	_menu = _room.get("field_menu")
	_state = root.get_node("GameState")
	_state.call("add_credits", 1240)
	_state.call("tick_play_time", 4980.0)
	for id: String in ["rebar_blade", "bread_knife", "rivet_hammer", "padded_work_vest", "hi_vis_vest", "lucky_bolt", "can_of_chili", "canned_coffee", "burn_gel", "firecracker_string"]:
		_state.call("add_item", id, 1)
	_state.call("update_member", "otis", {"hp": 40})
	_state.call("update_member", "mox", {"juice": 6})
	await _frames(20)

	_menu.set("animations_enabled", false)
	await _open_page(-1)
	await _save("m3_menu_main.png")

	await _open_page(0)
	await _save("m3_menu_items.png")
	_press(DOWN, 3)
	_press(CONFIRM)
	_press(DOWN)
	await _seconds(0.3)
	await _save("m3_menu_items_target.png")

	await _open_page(1)
	_press(DOWN)
	_press(CONFIRM)
	_press(DOWN)
	await _seconds(0.3)
	await _save("m3_menu_skills.png")

	await _open_page(2)
	_press(CONFIRM)
	_press(CONFIRM)
	await _seconds(0.3)
	await _save("m3_menu_equip.png")
	_press(CONFIRM)
	await _seconds(0.3)
	await _save("m3_menu_equip_done.png")

	await _open_page(3)
	_press(DOWN)
	await _seconds(0.3)
	await _save("m3_menu_status.png")

	await _open_page(4)
	await _seconds(0.3)
	await _save("m3_menu_party.png")

	await _open_page(5)
	await _seconds(1.2)
	await _save("m3_menu_config.png")

	await _open_page(-1)
	_press(DOWN, 6)
	await _seconds(0.3)
	await _save("m3_menu_save_locked.png")
	quit(0)


## Opens the menu fresh and walks to the page at `index` (-1 stays on the main list).
func _open_page(index: int) -> void:
	if _menu.call("is_open"):
		_menu.call("close")
		await _frames(6)
	for i: int in 4:
		await process_frame
	_menu.call("open")
	await _frames(3)
	if index >= 0:
		_press(DOWN, index)
		_press(CONFIRM)
	await _seconds(0.3)


func _press(command: int, times: int = 1) -> void:
	for i: int in times:
		_menu.call("handle_command", command)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _save(file_name: String) -> void:
	await _frames(4)
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUT_DIR + file_name)
	if err != OK:
		push_error("could not save %s" % file_name)
