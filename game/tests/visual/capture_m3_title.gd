extends SceneTree
## Screenshots of the M3 title screen (New Game / Continue / Config / Battle Test / Quit), the name
## entry window and the Config screen, for sharing progress with Ross. Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m3_title.gd
## Writes docs/screenshots/m3_title.png (Continue greyed, no save), m3_title_continue.png (a save
## exists, Continue is lit), m3_name_entry.png, m3_config.png, m3_config_controls.png and
## m3_config_tap.png. The script names no game classes: it finds everything by node name and path.

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const OUT_DIR: String = "res://../docs/screenshots/"
const STUB_SOURCE: String = "extends Node\nvar saves: bool = false\nfunc has_any_save() -> bool:\n\treturn saves\nfunc newest_slot() -> int:\n\treturn 1 if saves else -1\n"
const SETTLE_FRAMES: int = 6

var _title: Node = null
var _saves: Node = null


func _initialize() -> void:
	var stub: GDScript = GDScript.new()
	stub.source_code = STUB_SOURCE
	stub.reload()
	_saves = Node.new()
	_saves.set_script(stub)
	root.add_child(_saves)
	await _start_title()
	await _shot_menu("m3_title.png")
	await _shot_menu_with_save()
	await _shot_name_entry()
	await _shot_config()
	quit(0)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
	await _frames(2)


func _save(file_name: String) -> void:
	await _frames(SETTLE_FRAMES)
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUT_DIR + file_name)
	print("saved %s (%s) error %d" % [file_name, image.get_size(), err])


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event)
	await _frames(2)


func _start_title() -> void:
	if _title != null:
		_title.queue_free()
		await _frames(2)
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	_title.set("save_manager", _saves)
	root.add_child(_title)
	await _wait(1.2)
	await _press(&"confirm")
	await _wait(0.8)


func _shot_menu(file_name: String) -> void:
	await _press(&"move_down")
	await _press(&"move_down")
	await _wait(0.2)
	await _save(file_name)


func _shot_menu_with_save() -> void:
	_saves.set("saves", true)
	await _start_title()
	await _wait(0.3)
	await _save("m3_title_continue.png")


func _shot_name_entry() -> void:
	# The cursor starts on Continue when a save exists; New Game is the row above.
	await _press(&"move_up")
	await _press(&"confirm")
	await _wait(0.5)
	var entry: Node = _title.call("get_name_entry")
	entry.call("set_cursor", 2, 1)
	await _save("m3_name_entry.png")
	await _press(&"cancel")  # delete letters ...
	await _press(&"cancel")
	await _press(&"cancel")
	await _press(&"cancel")  # ... then back out to the menu
	await _wait(0.4)


func _shot_config() -> void:
	# Menu: New Game, Continue, Config ...
	await _press(&"move_down")
	await _press(&"move_down")
	await _press(&"confirm")
	await _wait(0.8)
	var screen: Node = _title.call("get_config_screen")
	var list: Node = screen.call("get_list")
	list.call("set_index", 4, false)  # Text Speed: the preview line types out
	await _wait(1.4)
	await _save("m3_config.png")
	list.call("set_index", 8, false)
	await _wait(0.3)
	await _save("m3_config_volume.png")
	list.call("set_index", 11, false)
	await _press(&"confirm")
	await _wait(0.3)
	await _save("m3_config_controls.png")
	await _press(&"cancel")
	list.call("set_index", 3, false)
	await _press(&"confirm")
	await _press(&"confirm")
	await _wait(1.5 + 0.75 * 3.0)
	await _save("m3_config_tap.png")
