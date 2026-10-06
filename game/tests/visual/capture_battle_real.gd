extends SceneTree
## The battle stage with the REAL controller (real clock, Auto-Timing, a policy answering commands) and the real
## HUD on top, photographed at three moments: the first cue ("!" and flash), a rating pop-up, and the K.O. beat.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_battle_real.gd -- --enc=grunt_solo     (default encounter: squad_four)
## Writes docs/screenshots/m2_stage_hud_cue.png, m2_stage_hud_rating.png, m2_stage_hud_flag.png and m2_stage_hud_ko.png. Names no game
## classes (this script compiles before the autoloads exist): everything is load() and call().

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const STAGE_SCENE: String = "res://scenes/battle/battle_scene.tscn"
const SETUP_SCRIPT: String = "res://scripts/battle/model/battle_setup.gd"
const DATA_SCRIPT: String = "res://scripts/battle/model/battle_data.gd"
const PROGRESSION_SCRIPT: String = "res://scripts/progression/progression.gd"
const CONTROLLER_SCRIPT: String = "res://scripts/battle/model/battle_controller.gd"
const CLOCK_SCRIPT: String = "res://scripts/battle/model/real_clock.gd"
const POLICY_SCRIPT: String = "res://tests/sim/sim_policy.gd"
const OUT_DIR: String = "res://../docs/screenshots/"
const DEFAULT_ENCOUNTER: String = "squad_four"
const TIME_LIMIT_S: float = 110.0

var _wanted: Dictionary = {"cue": false, "rating": false, "ko": false}
var _taken: Dictionary = {}
var _stage: Node = null


func _initialize() -> void:
	var encounter: String = DEFAULT_ENCOUNTER
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--enc="):
			encounter = arg.trim_prefix("--enc=")
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)
	main.set("debug_overlay_enabled", false)
	root.add_child(main)
	for i: int in 6:
		await process_frame
	var screen: Node = main.get_node("PsxScreen")
	_stage = screen.call("load_world", load(STAGE_SCENE) as PackedScene)
	var data: Object = (load(DATA_SCRIPT) as GDScript).call("shared") as Object
	var progression: Object = (load(PROGRESSION_SCRIPT) as GDScript).new(data) as Object
	var setup: RefCounted = (load(SETUP_SCRIPT) as GDScript).new() as RefCounted
	setup.set("data", data)
	setup.set("encounter_id", encounter)
	setup.set("rng_seed", 9)
	setup.set("clock", (load(CLOCK_SCRIPT) as GDScript).new())
	setup.set("auto_timing", true)
	setup.set("command_source", (load(POLICY_SCRIPT) as GDScript).new())
	for char_id: Variant in data.get("character_order"):
		(setup.get("party") as Array).append(progression.call("new_member", char_id, 5))
	setup.set("bag", {"ration_bar": 2})
	_stage.set("controller_factory", func(made_for: RefCounted) -> Object:
		return (load(CONTROLLER_SCRIPT) as GDScript).call("create", made_for) as Object)
	_stage.connect("cue_fired", _on_cue)
	_stage.connect("ko_beat_started", _on_ko)
	_stage.call("start_battle", setup)
	var start: int = Time.get_ticks_msec()
	var controller: Object = null
	while controller == null:
		await process_frame
		controller = _stage.get("controller")
	controller.connect("combatant_fled", _on_fled)
	while _taken.size() < 4 and float(Time.get_ticks_msec() - start) / 1000.0 < TIME_LIMIT_S:
		await process_frame
		if _wanted["rating"] and not _taken.has("rating"):
			_shoot("rating")
	print("taken: ", _taken.keys())
	quit(0)


func _on_cue(_owner: String, _index: int, _pos: Vector2) -> void:
	if not _taken.has("cue") and not _wanted["cue"]:
		_wanted["cue"] = true
		_later("cue", 3)
		_wanted["rating"] = true
	elif _wanted["rating"] and _taken.has("cue"):
		pass


func _on_ko(_target: String, _pos: Vector2) -> void:
	_later("ko", 6)


func _on_fled(_id: String) -> void:
	_later("flag", 28)


func _later(name: String, frames: int) -> void:
	for i: int in frames:
		await process_frame
	_shoot(name)


func _shoot(name: String) -> void:
	if _taken.has(name):
		return
	_taken[name] = true
	var image: Image = root.get_texture().get_image()
	var file: String = "m2_stage_hud_%s.png" % name
	image.save_png(OUT_DIR + file)
	print("saved ", file)
