class_name HackTerminal
extends HackTarget
## A terminal Red walks up to and uses with the one button (docs/slice/slice_tech_plan.md 5.2). Using it opens a gate, starts a scene,
## or sets any flags the placement lists; with `once` (the default) it is spent afterwards and stays spent (sticky).
## Data (hack_targets entry, kind "terminal"): flag (the gate's flag, set when used), also_flags, message (lines shown
## when used), scene (a story scene id: the `scene_requested` signal tells whoever runs scenes), once (true), reach_m.
## A Door placement with `requires: {flag: <this flag>}` is the gate; nothing else is needed.

signal used(target_id: StringName)
signal scene_requested(scene_id: String)

var also_flags: Array[String] = []
var message: Array[String] = []
var scene_id: String = ""
var once: bool = true


func _init() -> void:
	accepts = PackedStringArray(["interact"])
	lockable = false


func _configure(info: Dictionary) -> void:
	also_flags = _strings(info.get("also_flags", []))
	message = _strings(info.get("message", []))
	scene_id = str(info.get("scene", ""))
	once = bool(info.get("once", true))


func _apply(_hack_id: StringName, info: Dictionary) -> bool:
	WorldProgress.set_flag(flag_id(), game_state)          # the gate's flag, even for a terminal that can be used again
	for extra: String in also_flags:
		WorldProgress.set_flag(extra, game_state)
	var talker: PlayerInteractor = info.get("interactor", null) as PlayerInteractor
	say(message, talker)
	used.emit(target_id)
	if not scene_id.is_empty():
		scene_requested.emit(scene_id)
	return true


func _finishes_on(_hack_id: StringName) -> bool:
	return once


func is_done() -> bool:
	if once:
		return super.is_done()
	return false
