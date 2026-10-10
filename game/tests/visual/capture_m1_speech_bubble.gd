extends SceneTree
## Screenshots of the speech bubbles and the field menu for sharing progress with Ross.
## Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m1_speech_bubble.gd
## Writes docs/screenshots/m1_speech_bubble.png and docs/screenshots/m1_field_menu.png
## (the whole 1280x720 window). Extra shots with `-- --extra` (gestures, flipped bubble, choices, box).

const TEST_SCENE: String = "res://scenes/debug/dialogue_test.tscn"
const OUT_DIR: String = "res://../docs/screenshots/"
const SETTLE_FRAMES: int = 6
const EXTRA_FLAG: String = "--extra"

var _bench: Node = null


func _initialize() -> void:
	var scene: Node = (load(TEST_SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	_bench = scene
	await _frames(10)
	await _bubble_shot()
	await _menu_shot()
	if EXTRA_FLAG in OS.get_cmdline_user_args():
		await _extra_shots()
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
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)
	var release: InputEventAction = InputEventAction.new()
	release.action = action
	release.pressed = false
	root.push_input(release)
	await _frames(2)


func _bubble_shot() -> void:
	_bench.get("runner").start("otis_talk")
	await _wait(0.5)
	await _press(&"confirm")  # skip the first page's typing
	await _wait(0.2)
	await _save("m1_speech_bubble.png")
	_bench.get("runner").stop()
	await _wait(0.5)


func _menu_shot() -> void:
	_bench.get("menu").open()
	await _wait(0.6)
	await _save("m1_field_menu.png")
	_bench.get("menu").close()
	await _wait(0.6)


func _menu_page(rows_down: int, name: String, extra: Callable = Callable()) -> void:
	var menu: Node = _bench.get("menu")
	menu.call("open")
	await _wait(0.5)
	for i: int in rows_down:
		menu.call("handle_command", 2)  # MenuInput.Cmd.DOWN
	menu.call("handle_command", 5)  # CONFIRM
	await _wait(0.4)
	if extra.is_valid():
		extra.call()
		await _wait(0.5)
	await _save(name)
	menu.call("close")
	await _wait(0.5)


func _extra_shots() -> void:
	var runner: Node = _bench.get("runner")
	# Choices: step through Mox's talk until the yes / no question shows.
	runner.call("start", "mox_talk")
	for i: int in 60:
		await _wait(0.15)
		var bubble: Node = runner.call("get_current_bubble")
		if bubble != null and bubble.call("get_state") == 4:  # CHOOSING
			break
		await _press(&"confirm")
	await _wait(0.3)
	await _save("m1_speech_bubble_choice.png")
	runner.call("stop")
	await _wait(0.5)
	# The plain box.
	runner.call("start", "examine_sign")
	await _wait(0.8)
	await _press(&"confirm")
	await _save("m1_text_box.png")
	runner.call("stop")
	await _wait(0.5)
	# Menu pages.
	await _menu_page(0, "m1_field_menu_items.png")
	await _menu_page(1, "m1_field_menu_status.png")
	await _menu_page(2, "m1_field_menu_config.png")
	# All of Red's gestures at once, big enough to judge.
	var stage: Node = get_first_node_in_group("ui_stage")
	var scene: PackedScene = load("res://scenes/ui/speech_bubble.tscn")
	var ids: Array = ["thumbs_up", "head_shake", "exclaim", "question", "dots", "heart", "sweat", "shrug", "ear_perk"]
	var made: Array[Node] = []
	for i: int in ids.size():
		var bubble: Node = scene.instantiate()
		bubble.set("listen_input", false)
		stage.call("get_stage_root").add_child(bubble)
		bubble.call("set_anchor_point", Vector2(30 + i * 40, 120))
		bubble.call("setup_gesture", "red", ids[i])
		made.append(bubble)
	await _wait(0.6)
	await _save("m1_gestures.png")
	for bubble: Node in made:
		bubble.queue_free()
