extends SceneTree
## Screenshots of the sandbox UI (the HUD in a fight, the pause menu, the controls card, the feel panel)
## on top of the real arena. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_sandbox_ui.gd -- --sandbox
## Writes docs/screenshots/: sandbox_hud.png, sandbox_feel_panel.png, sandbox_pause.png, sandbox_controls.png.
## Names no game classes (it compiles before the autoloads exist): everything is load(), get() and call().

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUT_DIR: String = "res://../docs/screenshots/"
const STAGE: Vector2i = Vector2i(384, 216)

var _main: Node = null
var _sandbox: Node = null
var _director: Object = null
var _hud: Node = null


func _initialize() -> void:
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	_main.set("debug_overlay_enabled", false)
	root.add_child(_main)
	for i: int in 40:
		await process_frame
	_sandbox = _main.call("get_sandbox") as Node
	if _sandbox == null:
		push_error("capture: the sandbox did not start")
		quit(1)
		return
	_director = _sandbox.call("get_director") as Object
	var huds: Array[Node] = root.find_children("SandboxHud", "Control", true, false)
	_hud = huds[0] if not huds.is_empty() else null
	if _hud == null:
		push_error("capture: no SandboxHud in the tree (is the HUD attached?)")
		quit(1)
		return
	_hud.set("listen_input", false)
	_hud.set_process(false)
	await _fight_shot()
	await _panel_shot()
	await _pause_shots()
	quit(0)


func _frames(count: int = 4) -> void:
	for i: int in count:
		await process_frame


func _grab(file: String) -> void:
	await _frames(6)
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + file))
	print("saved ", file, " ", image.get_size())


func _fight_shot() -> void:
	var enemies: Array = _sandbox.call("get_enemies")
	_director.emit_signal("hp_changed", &"red", 78, 120)
	if not enemies.is_empty():
		var first: Object = enemies[0] as Object
		var id: StringName = first.get("actor_id")
		_director.emit_signal("hp_changed", id, 22, 40)
		var lock: Object = _sandbox.call("get_lock_on") as Object
		lock.emit_signal("target_changed", first)
		_director.emit_signal("hit_landed", {"attacker": &"red", "target": id, "outcome": "hit", "damage": 14})
		_director.emit_signal("hit_landed", {"attacker": &"red", "target": id, "outcome": "hit", "damage": 9})
	_director.emit_signal("noise_changed", 640.0, 0.62, &"rad", "Rad!")
	_director.emit_signal("noise_rank_changed", &"rad", "Rad!", true)
	_director.emit_signal("lights_on_changed", true, 8.0)
	_director.emit_signal("flare_started", {"source": "dodge", "duration_s": 2.5, "enemy_scale": 0.25})
	_director.emit_signal("perfect_dodge", {"attacker": &"grunt_1", "move_id": &"swipe"})
	_director.emit_signal("parry_judged", {"attacker": &"grunt_1", "rating": "totally_rad", "outcome": "perfect_parry"})
	for i: int in 4:
		_hud.call("tick", 0.0833)
		await process_frame
	_hud.call("tick", 0.0001)
	await _grab("sandbox_hud.png")


func _panel_shot() -> void:
	var panel: Node = _hud.call("get_feel_panel") as Node
	panel.set("animations_enabled", false)
	panel.call("open_panel")
	panel.call("focus_knob", "dash_distance_m")
	panel.call("set_knob_value", "dash_distance_m", 5.5)
	panel.call("set_knob_value", "cam_distance_m", 6.0)
	await _grab("sandbox_feel_panel.png")
	panel.call("close_panel")


func _pause_shots() -> void:
	var pause: Node = _hud.call("get_pause_menu") as Node
	pause.set("animations_enabled", false)
	pause.call("open_menu")
	await _grab("sandbox_pause.png")
	var card: Node = pause.call("get_card") as Node
	card.set("animations_enabled", false)
	card.call("open_card")
	await _grab("sandbox_controls.png")
