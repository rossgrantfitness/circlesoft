extends Node
## Moves the game between rooms: fade to black, free the old room, load the new one from
## data/world/rooms.json, put Red on a named spawn marker, fade back in.
##
## go_to(room_id, spawn_id) is what doors call. Every room id, scene path and spawn name comes from
## rooms.json (a test checks every door's target exists). `room_entered(room_id)` fires once the new
## room is in place and the fade back in begins; SaveManager's auto-save listens to it, and the
## GameState location is set just before it. start_at() is the same without the fade to black (the
## first room of a run, Continue).
##
## The router talks to Main (group "main_flow"), which owns the PSX screen and the battle flow:
## Main.enter_room(scene, spawn_id) swaps the room, so a battle's detach / attach keeps working
## exactly as before. It refuses to change rooms while a battle is on. A door used while a change
## is already running does nothing (is_busy()).
##
## Autoload (no class_name). Tests can make their own with `load(...).new()` and set `main`.

signal room_entered(room_id: String)
signal transition_started(room_id: String)
signal transition_finished(room_id: String)

const ROOMS_ID: String = "world/rooms"
const MAIN_GROUP: StringName = &"main_flow"
const KEY_ROOMS: String = "rooms"
const KEY_SCENE: String = "scene"
const KEY_SPAWNS: String = "spawns"
const KEY_DEFAULT_SPAWN: String = "default_spawn"
const FADE_Z: int = 100
const DEFAULT_STEPS: int = 8

## Main (or anything with enter_room / get_room / get_state). Null means the node in group "main_flow".
var main: Node = null
## GameState to record the location in. Null means the autoload.
var game_state: Node = null
## Skip the fade timing (tests, a skip option later).
var instant: bool = false
var current_room_id: String = ""
## The DataDB id of the rooms file. Main sets it from the game mode (GameMode.rooms_id): the slice
## reads slice/rooms, the shelved game world/rooms. Tests keep the default.
var rooms_id: String = ROOMS_ID
var current_spawn_id: String = ""
## The room being loaded right now (set just before the host swaps the scene in, so an ActionRoom that has just
## been created can ask which room it is). Equal to current_room_id once the change is done.
var pending_room_id: String = ""

var _busy: bool = false
var _fade: DitherFade = null
## The Main that the running change loads into. If it is freed mid-change (the game went back to the
## title, a test ended) the change is dropped and the router is free again.
var _transition_host_id: int = 0
## Bumped by start_at, which replaces a change that is still running (the title's New Game pressed twice).
var _generation: int = 0


# ---- rooms.json ----

func data() -> Dictionary:
	return DataDB.get_dict(rooms_id)


func room_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign((data().get(KEY_ROOMS, {}) as Dictionary).keys())
	return ids


func has_room(room_id: String) -> bool:
	return (data().get(KEY_ROOMS, {}) as Dictionary).has(room_id)


func get_room_entry(room_id: String) -> Dictionary:
	return (data().get(KEY_ROOMS, {}) as Dictionary).get(room_id, {})


func scene_path(room_id: String) -> String:
	return str(get_room_entry(room_id).get(KEY_SCENE, ""))


func spawn_ids(room_id: String) -> Array[String]:
	var ids: Array[String] = []
	for id: Variant in get_room_entry(room_id).get(KEY_SPAWNS, []):
		ids.append(str(id))
	return ids


func has_spawn(room_id: String, spawn_id: String) -> bool:
	return spawn_ids(room_id).has(spawn_id)


## The spawn used when none is named: the room's default_spawn, else its first one.
func default_spawn(room_id: String) -> String:
	var entry: Dictionary = get_room_entry(room_id)
	var wanted: String = str(entry.get(KEY_DEFAULT_SPAWN, ""))
	if not wanted.is_empty():
		return wanted
	var spawns: Array[String] = spawn_ids(room_id)
	return spawns[0] if not spawns.is_empty() else ""


func fade_steps() -> int:
	return int(data().get("fade", {}).get("steps", DEFAULT_STEPS))


func fade_out_s() -> float:
	return float(data().get("fade", {}).get("out_s", 0.0))


func fade_in_s() -> float:
	return float(data().get("fade", {}).get("in_s", 0.0))


func start_room_id() -> String:
	return str(data().get("start_room", ""))


# ---- changing rooms ----

## True while a room change is running (fading out, loading or fading in).
func is_busy() -> bool:
	return _busy


## Fades out, loads `room_id` at `spawn_id` (the room's default when empty), fades in. Returns false
## (and changes nothing) for an unknown room or spawn, while another change runs, or in a battle.
## It is a coroutine: `await` it to wait for the fade back in to finish.
func go_to(room_id: String, spawn_id: String = "") -> bool:
	return await _change_room(room_id, spawn_id, true)


## The same without the fade to black: the first room of a run, or Continue.
func start_at(room_id: String, spawn_id: String = "") -> bool:
	if _busy:
		_generation += 1
		_busy = false
	return await _change_room(room_id, spawn_id, false)


func _change_room(room_id: String, spawn_id: String, fade_out: bool) -> bool:
	if _busy and _transition_host_id != 0 and not is_instance_id_valid(_transition_host_id):
		_busy = false
	if _busy:
		return false
	var wanted_spawn: String = spawn_id if not spawn_id.is_empty() else default_spawn(room_id)
	if not _can_enter(room_id, wanted_spawn):
		return false
	var host: Node = _host()
	var scene: PackedScene = load(scene_path(room_id)) as PackedScene
	_busy = true
	var generation: int = _generation
	_transition_host_id = host.get_instance_id()
	transition_started.emit(room_id)
	_hold_player(host.call("get_room") as Node)
	if fade_out:
		await _fade_to(fade_steps(), fade_out_s())
	pending_room_id = room_id
	var room: Node = host.call("enter_room", scene, wanted_spawn) as Node
	if room == null:
		_busy = false
		await _fade_to(0, 0.0)
		transition_finished.emit(room_id)
		return false
	_hold_player(room)
	await get_tree().physics_frame
	if generation != _generation:
		return false  # a newer start_at took over
	if not is_instance_valid(host):
		_busy = false
		return false
	current_room_id = room_id
	current_spawn_id = wanted_spawn
	WorldProgress.set_location(room_id, wanted_spawn, game_state)
	room_entered.emit(room_id)
	await _fade_to(0, fade_in_s())
	if generation != _generation:
		return false
	_release_player(room)
	_busy = false
	_transition_host_id = 0
	transition_finished.emit(room_id)
	return true


func _can_enter(room_id: String, spawn_id: String) -> bool:
	if not has_room(room_id):
		push_error("SceneRouter: no room '%s' in %s.json" % [room_id, rooms_id])
		return false
	if not spawn_id.is_empty() and not has_spawn(room_id, spawn_id):
		push_error("SceneRouter: room '%s' has no spawn '%s'" % [room_id, spawn_id])
		return false
	if not ResourceLoader.exists(scene_path(room_id)):
		push_error("SceneRouter: the scene for '%s' is missing: %s" % [room_id, scene_path(room_id)])
		return false
	var host: Node = _host()
	if host == null or not host.has_method("enter_room"):
		push_error("SceneRouter: no Main to load rooms into")
		return false
	if host.has_method("get_state") and int(host.call("get_state")) == Main.State.BATTLE:
		return false
	return true


func _host() -> Node:
	if main != null and is_instance_valid(main):
		return main
	return get_tree().get_first_node_in_group(MAIN_GROUP)


## Red stands still while the screen fades (the old room's, then the new room's).
func _hold_player(room: Node) -> void:
	var red: CharacterBody3D = room.get("player") as CharacterBody3D if room != null else null
	if red != null:
		HeroLink.set_frozen(red, true)
		HeroLink.set_stick(red, Vector2.ZERO)


func _release_player(room: Variant) -> void:
	# The room can be gone by now (the game went back to the title during the fade).
	var red: CharacterBody3D = (room as Node).get("player") as CharacterBody3D if is_instance_valid(room) else null
	if red != null:
		HeroLink.set_frozen(red, false)


# ---- the fade ----

## Dither level now (0 = clear, fade_steps() = black).
func get_fade_step() -> int:
	return _fade.step if _fade != null and is_instance_valid(_fade) else 0


func _get_fade() -> DitherFade:
	if _fade == null or not is_instance_valid(_fade) or _fade.get_parent() == null:
		_fade = DitherFade.new()
		_fade.name = "RoomFade"
		_fade.size = Vector2(UiStage.STAGE_SIZE)
		_fade.z_index = FADE_Z
		_fade.step_count = fade_steps()
		UiStage.get_or_create(get_tree()).get_stage_root().add_child(_fade)
	return _fade


func _fade_to(target_step: int, seconds: float) -> void:
	var fade: DitherFade = _get_fade()
	var distance: int = absi(target_step - fade.step)
	if instant or seconds <= 0.0 or distance == 0:
		fade.step = target_step
		return
	var direction: int = signi(target_step - fade.step)
	var wait: float = seconds / float(distance)
	for i: int in distance:
		if _transition_host_id != 0 and not is_instance_id_valid(_transition_host_id):
			fade.step = 0
			return
		fade.step += direction
		await get_tree().create_timer(wait).timeout
