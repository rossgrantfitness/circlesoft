extends SceneTree
## Red, old vs the grim variant, on the neutral style stage in the real PSX look: front and three-quarter.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_grim_red.gd -- --out=/some/dir
## Writes <out>/red_<grade>_<old|grim>_<front|34>.png for grade = classic (no screen grade: just the models)
## and grim (under the grim world grade). scripts/tools/compose_grim_shots.py puts them on one sheet.
## No game classes are named here (compiled before the autoloads exist).

const STAGE_SCENE: String = "res://scenes/debug/style_stage.tscn"
const LOOK_SCRIPT: String = "res://scripts/core/look_profiles.gd"
const MODELS: Dictionary = {
	"old": "res://art/placeholder/characters/red/red_shiba.glb",
	"grim": "res://art/placeholder/characters/red/red_shiba_grim.glb",
}
const VIEWS: Array[String] = ["front", "34"]
const SETTLE_FRAMES: int = 8

var _stage: Node = null


func _initialize() -> void:
	var out_dir: String = "/tmp"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	await process_frame
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	root.add_child(_stage)
	await _settle()
	var look: GDScript = load(LOOK_SCRIPT) as GDScript
	_stage.call("frame_for_models", [MODELS["old"], MODELS["grim"]] as Array[String])
	for grade: String in ["classic", "grim"]:
		look.call("set_forced", grade)
		for model: String in MODELS:
			_stage.call("load_model_file", MODELS[model], model)
			_stage.call("pose_clip", "idle", 0.0)
			for view: String in VIEWS:
				_stage.call("show_close", view)
				await _settle()
				var image: Image = _stage.call("grab_picture")
				var path: String = "%s/red_%s_%s_%s.png" % [out_dir, grade, model, view]
				print("saved ", path, " ", image.get_size(), " error ", image.save_png(path))
	quit(0)


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame
