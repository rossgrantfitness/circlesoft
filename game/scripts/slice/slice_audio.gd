class_name SliceAudio
extends Node
## Sound wiring for an ActionRoom (data/slice/audio.json):
##   * the room's `music` (rooms.json) through AudioManager.play_music, and its ambience loops through play_loop; the loops stop
##     when the room is left (the same music in the next room just keeps playing);
##   * the hack sounds, fired from the director's hack signals: a cast (per hack), a refused press, Quiet Hours jamming and ending,
##     the battery reaching full, and the Overclock hum for as long as something is hijacked.
## Boss sounds belong to the boss fight (Combat Programmer). AudioManager is the autoload; a missing one makes this do nothing.

const DATA_ID: String = "slice/audio"

## Which SliceAudio started each ambience loop last. A room that is left stops only the loops it still owns, so the next
## room's identical bed (the junkyard hum) is not cut off when the old room is freed after the new one has started.
static var _loop_owner: Dictionary[StringName, int] = {}

signal sound_played(id: StringName)

var _cfg: Dictionary = {}
var _audio: Node = null
var _loops: Array[StringName] = []
var _director: Object = null
var _hijacks: int = 0
var _was_full: bool = false
var _hijack_loop: StringName = &""


## Starts the room's music and ambience and listens to the director. `entry` is the room's rooms.json row.
func setup(entry: Dictionary, director: Object, audio: Node = null) -> void:
	_cfg = DataDB.get_dict(DATA_ID)
	_audio = audio if audio != null else get_node_or_null("/root/AudioManager")
	_start_room_sound(entry)
	_listen(director)


func _start_room_sound(entry: Dictionary) -> void:
	if _audio == null:
		return
	var music: String = str(entry.get("music", ""))
	var aliases: Dictionary = _cfg.get("music_aliases", {}) as Dictionary
	_audio.call("play_music", StringName(str(aliases.get(music, music))))
	var beds: Array = []
	if entry.has("ambience"):
		var own: Variant = entry["ambience"]
		beds = own as Array if own is Array else [own]
	else:
		beds = (_cfg.get("ambience_by_music", {}) as Dictionary).get(music, []) as Array
	for id: Variant in beds:
		if bool(_audio.call("play_loop", StringName(str(id)))):
			_loops.append(StringName(str(id)))
			_loop_owner[StringName(str(id))] = get_instance_id()


func current_loops() -> Array[StringName]:
	return _loops.duplicate()


func _listen(director: Object) -> void:
	_director = director
	if director == null:
		return
	for pair: Array in [["hack_cast", _on_cast], ["hack_refused", _on_refused], ["hack_locked", _on_locked],
			["battery_changed", _on_battery], ["hijack_changed", _on_hijack]]:
		if director.has_signal(pair[0]) and not director.is_connected(pair[0], pair[1]):
			director.connect(pair[0], pair[1])


func _sounds() -> Dictionary:
	return _cfg.get("hack_sounds", {}) as Dictionary


func _play(id: Variant) -> void:
	var sound: StringName = StringName(str(id))
	if sound == &"" or _audio == null:
		return
	_audio.call("play_sfx", sound)
	sound_played.emit(sound)


func _on_cast(info: Dictionary) -> void:
	_play((_sounds().get("cast", {}) as Dictionary).get(str(info.get("hack", "")), ""))


func _on_refused(_info: Dictionary) -> void:
	_play(_sounds().get("refused", ""))


func _on_locked(active: bool, _ms: float) -> void:
	_play(_sounds().get("locked" if active else "unlocked", ""))


## The "battery full" chime plays when the charge reaches the top from below, not on every refill tick at the top.
func _on_battery(charge: float, capacity: float) -> void:
	var full: bool = capacity > 0.0 and charge >= capacity - 0.001
	if full and not _was_full:
		_play(_sounds().get("battery_full", ""))
	_was_full = full


## Overclock: a hum for as long as anything is hijacked, a closing sound when the last one lets go.
func _on_hijack(info: Dictionary) -> void:
	if bool(info.get("active", false)):
		_hijacks += 1
		if _hijacks == 1 and _audio != null:
			_hijack_loop = StringName(str(_sounds().get("hijack_loop", "")))
			if _hijack_loop != &"":
				_audio.call("play_loop", _hijack_loop)
				sound_played.emit(_hijack_loop)
	else:
		_hijacks = maxi(_hijacks - 1, 0)
		if _hijacks == 0:
			_stop_hijack_hum()
			_play(_sounds().get("hijack_end", ""))


func _stop_hijack_hum() -> void:
	if _hijack_loop != &"" and _audio != null:
		_audio.call("stop_loop", _hijack_loop)
	_hijack_loop = &""


func _exit_tree() -> void:
	_stop_hijack_hum()
	if _audio != null and is_instance_valid(_audio):
		for id: StringName in _loops:
			if int(_loop_owner.get(id, 0)) == get_instance_id():
				_audio.call("stop_loop", id)
				_loop_owner.erase(id)
	_loops.clear()
	if _director != null and is_instance_valid(_director):
		for pair: Array in [["hack_cast", _on_cast], ["hack_refused", _on_refused], ["hack_locked", _on_locked],
				["battery_changed", _on_battery], ["hijack_changed", _on_hijack]]:
			if _director.has_signal(pair[0]) and _director.is_connected(pair[0], pair[1]):
				_director.disconnect(pair[0], pair[1])
