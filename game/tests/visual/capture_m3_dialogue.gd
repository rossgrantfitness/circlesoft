extends SceneTree
## Screenshots of the M3 dialogue system, for sharing progress with Ross. Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m3_dialogue.gd
## Writes docs/screenshots/m3_dialogue_portrait.png (a speech bubble with the portrait slot, mid-line
## expression change), m3_dialogue_portrait_calm.png (the same bubble before the change),
## m3_dialogue_crowd_box.png (a crowd NPC in the plain bottom box) and m3_dialogue_box_portrait.png
## (a named speaker with no body in the room, in the box with a portrait slot).
## The script names no game classes: it drives the debug bench by node path and method name.

const BENCH_SCENE: String = "res://scenes/debug/dialogue_test.tscn"
const OUT_DIR: String = "res://../docs/screenshots/"
const SETTLE_FRAMES: int = 6

var _bench: Node = null


func _initialize() -> void:
	_bench = (load(BENCH_SCENE) as PackedScene).instantiate()
	root.add_child(_bench)
	await _frames(10)
	await _portrait_shots()
	await _crowd_shot()
	await _box_portrait_shot()
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


func _runner() -> Node:
	return _bench.get("runner")


func _bubble() -> Node:
	return _runner().call("get_current_bubble")


## Types the current page out until the portrait shows the given face (or the page is done).
func _until_face(face: String, limit_s: float) -> void:
	var waited: float = 0.0
	while waited < limit_s and str(_bubble().call("get_face")) != face:
		await _wait(0.05)
		waited += 0.05


func _portrait_shots() -> void:
	_runner().set("chars_per_second_override", 22.0)
	_runner().call("start", "demo_mox_faces")
	await _wait(0.7)
	await _save("m3_dialogue_portrait_calm.png")
	await _until_face("panicking", 6.0)
	await _wait(0.12)
	await _save("m3_dialogue_portrait.png")
	_runner().call("stop")
	await _wait(0.6)


func _crowd_shot() -> void:
	_runner().set("chars_per_second_override", 60.0)
	_runner().call("start", "demo_crowd_dockhand")
	await _wait(1.6)
	await _save("m3_dialogue_crowd_box.png")
	_runner().call("stop")
	await _wait(0.6)


func _box_portrait_shot() -> void:
	# Kasp is not in the bench room, so the runner shows him in the box, with his portrait slot.
	_runner().call("add_conversations", {"demo_kasp_radio": [{"speaker": "kasp", "face": "smug", "text": "Harrow Landing, this is Signals. {face:shouting}Stand down! {face:flustered}...Please? I have a quota."}]})
	_runner().set("chars_per_second_override", 30.0)
	_runner().call("start", "demo_kasp_radio")
	await _wait(0.6)
	await _until_face("shouting", 6.0)
	await _wait(0.3)
	await _save("m3_dialogue_box_portrait.png")
	_runner().call("stop")
