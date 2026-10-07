extends SceneTree
## Screenshots of the shops in the test room: walk up to the gear counter, press interact, look at
## the shelf with the up / down arrows per fighter, the quantity picker, then the general store and
## the sell list. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m3_shop.gd
## Writes docs/screenshots/m3_shop.png (+ m3_shop_quantity.png, m3_shop_general.png, m3_shop_sell.png,
## m3_shop_counter.png). Does not name game classes; menu commands are the raw numbers of
## MenuInput.Cmd: UP 1, DOWN 2, LEFT 3, RIGHT 4, CONFIRM 5, CANCEL 6.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUT_DIR: String = "res://../docs/screenshots/"
const UP: int = 1
const DOWN: int = 2
const CONFIRM: int = 5
const CANCEL: int = 6

var _room: Node = null
var _shop: Node = null


func _initialize() -> void:
	await process_frame
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	await _frames(10)
	_room = main.get_node("PsxScreen/WorldViewport/World/PsxTestRoom")
	var state: Node = root.get_node("GameState")
	state.call("add_credits", 640)
	state.call("add_item", "canned_coffee", 3)
	state.call("add_item", "rebar_blade", 1)
	await _frames(10)

	var gear: Node3D = _room.get_node("GearCounter")
	var player: Node3D = _room.get("player")
	player.global_position = gear.global_position + Vector3(-1.1, 0.02, 1.4)
	player.rotation.y = PI * 0.75
	await _frames(40)
	await _save("m3_shop_counters.png")

	await _use_counter("GearCounter")
	_shop = await _find_shop()
	_shop.set("animations_enabled", false)
	await _seconds(1.0)
	_press(CONFIRM)
	_press(DOWN, 3)
	await _seconds(0.4)
	await _save("m3_shop.png")
	_press(UP, 3)
	_press(CONFIRM)
	_press(UP, 0)
	await _seconds(0.4)
	await _save("m3_shop_quantity.png")
	_press(CANCEL, 3)
	await _seconds(0.8)

	await _use_counter("GeneralCounter")
	_shop = await _find_shop()
	await _seconds(1.0)
	_press(CONFIRM)
	_press(DOWN, 1)
	await _seconds(0.3)
	await _save("m3_shop_general.png")
	_press(CANCEL)
	_press(DOWN)
	_press(CONFIRM)
	await _seconds(0.3)
	await _save("m3_shop_sell.png")
	quit(0)


func _use_counter(counter_name: String) -> void:
	var counter: Node3D = _room.get_node(counter_name)
	var player: Node3D = _room.get("player")
	player.global_position = counter.global_position + Vector3(0.0, 0.02, 0.9)
	player.set("velocity", Vector3.ZERO)
	player.rotation.y = PI
	await _frames(40)
	_room.get("interactor").call("try_interact")
	await _seconds(0.8)


func _find_shop() -> Node:
	var stage: Node = get_first_node_in_group("ui_stage")
	var stage_root: Node = stage.call("get_stage_root")
	for child: Node in stage_root.get_children():
		if child.name.begins_with("ShopMenu") or child.get_script() != null and str(child.get_script().resource_path).ends_with("shop_menu.gd"):
			return child
	return null


func _press(command: int, times: int = 1) -> void:
	for i: int in times:
		_shop.call("handle_command", command)


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
