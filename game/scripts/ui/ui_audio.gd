class_name UiAudio
extends RefCounted
## The one place UI code talks to AudioManager. Every call is optional: if the autoload (or the
## method) is missing, nothing happens, so the UI never depends on audio being there.
## Tests set `target` to a fake that records the calls.

const AUDIO_PATH: NodePath = ^"AudioManager"
const METHOD_SFX: StringName = &"play_sfx"
const METHOD_VOICE: StringName = &"play_voice"
const METHOD_RESET_VOICE: StringName = &"reset_voice"
const THEME_ID: String = "ui/ui_theme"

## Replace to intercept calls (tests). Null means "use the AudioManager autoload".
var target: Object = null


func _resolve() -> Object:
	if target != null and is_instance_valid(target):
		return target
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(AUDIO_PATH)


## A sound by id (for example &"bubble_open").
func sfx_id(id: String) -> void:
	if id.is_empty():
		return
	var audio: Object = _resolve()
	if audio != null and audio.has_method(METHOD_SFX):
		audio.call(METHOD_SFX, StringName(id))


## One of the menu sounds named in ui_theme.json: "tick", "confirm" or "back".
func sfx(key: String) -> void:
	sfx_id(str(DataDB.get_value(THEME_ID, "sfx.%s" % key, "")))


func voice(speaker_id: String, character: String) -> void:
	var audio: Object = _resolve()
	if audio != null and audio.has_method(METHOD_VOICE):
		audio.call(METHOD_VOICE, StringName(speaker_id), character)


func reset_voice() -> void:
	var audio: Object = _resolve()
	if audio != null and audio.has_method(METHOD_RESET_VOICE):
		audio.call(METHOD_RESET_VOICE)
