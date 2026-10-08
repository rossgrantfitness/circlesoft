@tool
extends "res://scripts/tools/psx_post_import.gd"
## Scene import script of the retargeted rigs (the *_ual.glb files made by scripts/tools/retarget_ual.py). It is the
## project's model import script (PS2/PSX materials, see psx_post_import.gd) with a different way of treating clips:
##  - loops come from the clip tables in data/animation/retarget_*.json ("loop": true), plus the names the base script loops;
##  - in-betweens come from data/animation/import_look.json ("linear" or "nearest"). The base script makes every track
##    stepped; that is fine for 15 fps hand-posed clips but wrong for 30 fps baked ones, because Godot's importer drops
##    keys that sit on a straight line and a stepped track then holds the wrong pose for a frame;
##  - the TA's hand-posed stand-ins kept in a file (retarget_*.json "keep_standins") stay stepped, as they were made.
## Registered per file in the .import of each *_ual.glb (retarget_ual.py writes that line).

const LOOK_PATH: String = "res://data/animation/import_look.json"
const SETTINGS_DIR: String = "res://data/animation"
const SETTINGS_PREFIX: String = "retarget_"


func _convert_animations(player: AnimationPlayer) -> void:
	var settings: Dictionary = _settings_for(get_source_file())
	var loops: Dictionary = {}
	for clip: Variant in settings.get("clips", []):
		var entry: Dictionary = clip as Dictionary
		loops[str(entry.get("name", ""))] = bool(entry.get("loop", false))
	var standins: Array = settings.get("keep_standins", []) as Array
	var look: Dictionary = _read_json(LOOK_PATH)
	var smooth: bool = str(look.get("interpolation", "linear")) != "nearest"
	for clip_name: StringName in player.get_animation_list():
		var animation: Animation = player.get_animation(clip_name)
		var clip_text: String = String(clip_name)
		var loops_here: bool = bool(loops.get(clip_text, false)) or LOOPING_CLIPS.has(clip_text)
		animation.loop_mode = Animation.LOOP_LINEAR if loops_here else Animation.LOOP_NONE
		var stepped: bool = standins.has(clip_text) or not smooth
		for track: int in animation.get_track_count():
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST if stepped else Animation.INTERPOLATION_LINEAR)


## The retarget settings whose "output" is the file being imported ({} if none: then every clip is stepped like before).
func _settings_for(source_file: String) -> Dictionary:
	for file_name: String in DirAccess.get_files_at(SETTINGS_DIR):
		if file_name.begins_with(SETTINGS_PREFIX) and file_name.ends_with(".json"):
			var data: Dictionary = _read_json(SETTINGS_DIR.path_join(file_name))
			if "res://" + str(data.get("output", "")) == source_file:
				return data
	return {}


func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
