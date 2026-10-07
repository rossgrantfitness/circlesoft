class_name FlagVisible
extends Node3D
## Shows its children only while a Conditions dictionary holds (the dark window that lights up when
## the job is done, the boom barrier that stays up). `show_if` is JSON text, e.g. {"flag": "job_dark_window_done"};
## `hide_if` the same for hiding. It re-checks whenever a flag changes.

@export var show_if: String = ""
@export var hide_if: String = ""

var _show: Dictionary = {}
var _hide: Dictionary = {}


func _ready() -> void:
	_show = _parse(show_if)
	_hide = _parse(hide_if)
	var state: Node = WorldProgress.game_state()
	if state != null and state.has_signal("flag_changed") and not state.is_connected("flag_changed", _on_flag):
		state.connect("flag_changed", _on_flag)
	refresh()


func refresh() -> void:
	var on: bool = Conditions.met(_show) and (_hide.is_empty() or not Conditions.met(_hide))
	visible = on


func _on_flag(_flag_id: String, _value: bool) -> void:
	refresh()


static func _parse(text: String) -> Dictionary:
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
