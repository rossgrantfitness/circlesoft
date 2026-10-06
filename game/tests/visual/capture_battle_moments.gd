extends SceneTree
## A contact sheet of big moments from the stub-driven demo fight: the lunge, the TOTALLY RAD hit with the shake,
## the perfect block, the K.O. freeze, a white-flag leave and the static transition. Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_battle_moments.gd
## Writes docs/screenshots/m2_battle_moments.png (2 x 3 frames, each one the 384x216 picture, shown at 2x)
## and docs/screenshots/m2_static_transition.png. Names no game classes.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const STAGE_SCENE: String = "res://scenes/battle/battle_scene.tscn"
const STUB: String = "res://tests/fixtures/battle_stage/stub_battle_controller.gd"
const OUT_DIR: String = "res://../docs/screenshots/"
const FRAME: Vector2i = Vector2i(384, 216)

var _frames: Array[Image] = []
var _stage: Node = null
var _stub: RefCounted = null


func _initialize() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	for i: int in 6:
		await process_frame
	var screen: Node = main.get_node("PsxScreen")
	_stage = screen.call("load_world", load(STAGE_SCENE) as PackedScene)
	_stage.set("transitions_enabled", false)
	_stub = (load(STUB) as GDScript).new() as RefCounted
	_stub.set("tree", self)
	_stage.call("attach_controller", _stub)
	_stub.call("start")
	await _wait(0.6)
	# 1. Red lunges at the first grunt (the wind-up lean, then the dash)
	var attack: Dictionary = _stub.call("make_action", "red", "attack", ["e1"], 720, "red", "attack", 500, 900, 1300)
	_stub.emit_signal("action_started", attack)
	await _wait(0.78)
	_grab()
	# 2. TOTALLY RAD: the hit, recoil, flash and screen shake
	_stub.emit_signal("press_judged", {"actor": "red", "index": 0, "side": "attack", "rating": "totally_rad", "delta_ms": 4})
	_stub.emit_signal("hit", {"source": "red", "target": "e1", "amount": 22, "kind": "damage", "blocked": "none", "payback": false})
	await _wait(0.07)
	_grab()
	_stub.emit_signal("action_finished", attack)
	await _wait(1.2)
	# 3. the cue: the grunt swings, the "!" and flash on Red (she is about to block)
	var swing: Dictionary = _stub.call("make_action", "e1", "attack", ["red"], 200, "red", "block", 120, 400, 800)
	_stub.emit_signal("action_started", swing)
	await _wait(0.26)
	_grab()
	_stub.emit_signal("hit", {"source": "e1", "target": "red", "amount": 0, "kind": "damage", "blocked": "perfect", "payback": true})
	_stub.emit_signal("action_finished", swing)
	await _wait(1.0)
	# 4. the white flag: the second grunt gives up (it is nearly beaten)
	_stub.emit_signal("combatant_fled", "e1")
	await _wait(0.75)
	_grab()
	# 5. the K.O. beat on the last enemy: everything freezes for a moment
	_stub.emit_signal("combatant_down", "e3")
	_stub.emit_signal("combatant_down", "e2")
	var finisher: Dictionary = _stub.call("make_action", "otis", "attack", ["e4"], 100, "otis")
	_stub.emit_signal("action_started", finisher)
	await _wait(0.25)
	_stub.emit_signal("hit", {"source": "otis", "target": "e4", "amount": 50, "kind": "damage", "blocked": "none", "payback": false})
	_stub.emit_signal("combatant_down", "e4")
	await _wait(0.12)
	_grab()
	await _wait(1.4)
	# 6. victory: the hop
	_stub.emit_signal("battle_ended", "win", {"xp": 40, "credits": 90, "drops": [], "level_ups": [], "final_ko_target": "e4"})
	await _wait(0.45)
	_grab()
	_save_sheet()
	# the static transition, half way in
	var layer: Node = _stage.get("static_layer")
	layer.call("set_progress", 0.625)
	for i: int in 8:
		await process_frame
	var shot: Image = root.get_texture().get_image()
	shot.save_png(OUT_DIR + "m2_static_transition.png")
	print("saved m2_static_transition.png")
	quit(0)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _grab() -> void:
	var image: Image = root.get_texture().get_image()
	# the picture sits in the middle of the window at a whole-number scale; cut it out and shrink it to 2x
	var scale: int = int(floor(minf(float(image.get_width()) / FRAME.x, float(image.get_height()) / FRAME.y)))
	var size: Vector2i = FRAME * scale
	var origin: Vector2i = (image.get_size() - size) / 2
	var crop: Image = image.get_region(Rect2i(origin, size))
	crop.resize(FRAME.x * 2, FRAME.y * 2, Image.INTERPOLATE_NEAREST)
	_frames.append(crop)


func _save_sheet() -> void:
	var cols: int = 2
	var rows: int = int(ceil(float(_frames.size()) / float(cols)))
	var sheet: Image = Image.create(FRAME.x * 2 * cols, FRAME.y * 2 * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.07, 0.12))
	for i: int in _frames.size():
		sheet.blit_rect(_frames[i], Rect2i(Vector2i.ZERO, _frames[i].get_size()), Vector2i((i % cols) * FRAME.x * 2, (i / cols) * FRAME.y * 2))
	sheet.save_png(OUT_DIR + "m2_battle_moments.png")
	print("saved m2_battle_moments.png (%d frames)" % _frames.size())
