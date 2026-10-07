class_name StoryDirector
extends Node
## Plays the little scripted scenes of a room (the dock fight, Otis lifting the checkpoint barrier,
## Mox's dash across the square, the opening) from data/world/story_scenes.json. This is the
## placeholder cutscene player for M3-4; the real cutscene system (M6-3) replaces it later.
##
## A scene is {room, trigger, if, once, freeze, steps}:
##   trigger {on: "enter", spawn?, area? {min [x, z], max [x, z]}}   when it starts by itself
##   if      a Conditions dictionary that must hold        once   a flag set when the scene starts
##   steps   one after another; each may carry its own "if". "do" is one of
##     say {conversation}                  plays a dialogue conversation and waits for it
##     move {actor, to [x, z], speed, wait}  walks an actor (a node name in the room, "red", or
##                                         "follower:otis") there; "wait": false keeps going meanwhile
##     face {actor, toward [x, z]}   wait {s}   show {actor}   hide {actor}
##     set_flag {flag}   clear_flag {flag}   give_item {item, count}   take_item {item, count}
##     credits {amount}   beat {beat}
##     battle {encounter, first_turn}      asks Main for that fight and waits for how it ended
##     join {member, at}                   adds a member to the walking line at an actor's spot
## Red is frozen while a scene plays (unless "freeze": false) and the crew stands still.
## Dialogue lines can carry their own set_flag / give_item actions too.

signal scene_started(scene_id: String)
signal scene_finished(scene_id: String)
signal battle_done(result: String)

const FLAT_REACH: float = 0.05
const DEFAULT_SPEED: float = 3.0
const MAX_WAIT_FRAMES: int = 900

var room: FieldRoom = null
## GameState to use. Null means the autoload.
var game_state: Node = null
## SceneRouter to ask whether a room change is running. Null means the autoload.
var router: Node = null
## Tests: no waiting, walks end at once. The steps still run in order.
var instant: bool = false
## Off: the triggers are not checked (tests that start scenes by hand).
var triggers_enabled: bool = true
var current_scene: String = ""

var _triggers: Array[String] = []
var _running: bool = false
var _waiting_battle: bool = false
var _background: int = 0
var _held_player: bool = false
var _gone: bool = false


func setup(p_room: FieldRoom) -> void:
	room = p_room
	if room.room_id.is_empty():
		return
	for scene_id: String in Placements.scene_ids():
		var data: Dictionary = Placements.scene(scene_id)
		if str(data.get("room", "")) == room.room_id and data.has("trigger"):
			_triggers.append(scene_id)


func _physics_process(_delta: float) -> void:
	if _triggers.is_empty() or not triggers_enabled or _running or room == null or room.is_suspended():
		return
	var player: PlayerController = room.player
	if player == null or player.frozen or player.scripted or not player.is_on_floor():
		return
	var route: Node = router if router != null else get_node_or_null("/root/SceneRouter")
	if route != null and bool(route.call("is_busy")):
		return
	if UiStage.is_busy(get_tree()) or (room.runner != null and room.runner.is_running()):
		return
	for scene_id: String in _triggers:
		if should_start(scene_id):
			run_scene(scene_id)
			return


func _exit_tree() -> void:
	_gone = true


func is_running() -> bool:
	return _running


## True when the scene's trigger, condition and once-flag all say go.
func should_start(scene_id: String) -> bool:
	var data: Dictionary = Placements.scene(scene_id)
	if data.is_empty() or not Conditions.met(data.get("if", {}), game_state):
		return false
	var once: String = str(data.get("once", ""))
	if not once.is_empty() and WorldProgress.has_flag(once, game_state):
		return false
	var trigger: Dictionary = data.get("trigger", {})
	if trigger.has("spawn") and not _list(trigger["spawn"]).has(room.entry_spawn):
		return false
	if trigger.has("area"):
		var area: Dictionary = trigger["area"]
		var low: Array = area["min"]
		var high: Array = area["max"]
		var at: Vector3 = room.player.global_position
		if at.x < float(low[0]) or at.x > float(high[0]) or at.z < float(low[1]) or at.z > float(high[1]):
			return false
	return true


## Starts a scene by id (the trigger, an NPC's variant or a spot). Returns false when one is already
## running or the id is unknown. The scene runs by itself; connect scene_finished to wait for it.
func run_scene(scene_id: String) -> bool:
	if _running or Placements.scene(scene_id).is_empty():
		return false
	_running = true
	current_scene = scene_id
	_play(scene_id)
	return true


## Main says how a fight the scene asked for ended.
func battle_finished(result: String) -> void:
	if _waiting_battle:
		_waiting_battle = false
		battle_done.emit(result)


func _play(scene_id: String) -> void:
	var data: Dictionary = Placements.scene(scene_id)
	var once: String = str(data.get("once", ""))
	if not once.is_empty():
		WorldProgress.set_flag(once, game_state)
	var freeze: bool = bool(data.get("freeze", true))
	if freeze and room.player != null:
		room.player.frozen = true
		_held_player = true
	if room.party != null:
		room.party.active = false
	scene_started.emit(scene_id)
	for step: Variant in data.get("steps", []):
		var entry: Dictionary = step
		if Conditions.met(entry.get("if", {}), game_state):
			await _do(entry)
		if _gone:
			return
	while _background > 0:
		await get_tree().physics_frame
	if room.party != null:
		room.party.active = true
	if _held_player and room.player != null and is_instance_valid(room.player):
		room.player.frozen = false
	_held_player = false
	_running = false
	current_scene = ""
	scene_finished.emit(scene_id)


func _do(step: Dictionary) -> void:
	match str(step.get("do", "")):
		"say":
			await _say(str(step.get("conversation", "")))
		"move":
			if bool(step.get("wait", true)):
				await _walk(step)
			else:
				_walk(step)
		"face":
			_face(step)
		"wait":
			if not instant:
				await get_tree().create_timer(float(step.get("s", 0.5))).timeout
		"show":
			_show(str(step.get("actor", "")), true)
		"hide":
			_show(str(step.get("actor", "")), false)
		"set_flag":
			WorldProgress.set_flag(str(step.get("flag", "")), game_state)
		"clear_flag":
			var gs: Node = WorldProgress.game_state(game_state)
			if gs != null:
				gs.call("set_flag", str(step.get("flag", "")), false)
		"give_item":
			var holder: Node = WorldProgress.game_state(game_state)
			if holder != null:
				holder.call("add_item", str(step.get("item", "")), int(step.get("count", 1)))
		"take_item":
			var owner_state: Node = WorldProgress.game_state(game_state)
			if owner_state != null:
				owner_state.call("remove_item", str(step.get("item", "")), int(step.get("count", 1)))
		"credits":
			var bank: Node = WorldProgress.game_state(game_state)
			if bank != null:
				bank.call("add_credits", int(step.get("amount", 0)))
		"beat":
			var story: Node = WorldProgress.game_state(game_state)
			if story != null:
				story.call("set_story_beat", str(step.get("beat", "")))
		"battle":
			await _battle(step)
		"join":
			_join(step)
		_:
			push_warning("StoryDirector: unknown step '%s' in scene %s" % [step.get("do", ""), current_scene])


func _say(conversation_id: String) -> void:
	var runner: DialogueRunner = room.runner
	if runner == null or not runner.has_conversation(conversation_id):
		push_warning("StoryDirector: no conversation '%s'" % conversation_id)
		return
	var waited: int = 0
	while runner.is_running() and waited < MAX_WAIT_FRAMES and is_inside_tree():
		await get_tree().physics_frame
		waited += 1
	if not is_inside_tree():
		return
	if room.interactor.start_conversation(conversation_id):
		await runner.conversation_finished
		if _gone or not is_inside_tree():
			return
		# The runner hands Red back a couple of frames after the last line: wait for that, or it would
		# hand back the frozen state we set (and she would stay frozen after the scene).
		waited = 0
		while runner.is_in_group(UiStage.MODAL_GROUP) and waited < MAX_WAIT_FRAMES:
			await get_tree().physics_frame
			waited += 1


func _battle(step: Dictionary) -> void:
	_waiting_battle = true
	room.field_battle_requested.emit(str(step.get("encounter", "")), current_scene, str(step.get("first_turn", "normal")))
	await battle_done


func _join(step: Dictionary) -> void:
	if room.party == null:
		return
	var at_actor: Node3D = actor(str(step.get("at", "red")))
	var spot: Vector3 = at_actor.global_position if at_actor != null else room.player.global_position
	room.party.add_member(str(step.get("member", "")), spot)


func _show(actor_name: String, on: bool) -> void:
	var node: Node3D = actor(actor_name)
	if node == null:
		return
	if node.has_method("set_present"):
		node.call("set_present", on)
	else:
		node.visible = on


func _face(step: Dictionary) -> void:
	var node: Node3D = actor(str(step.get("actor", "")))
	if node == null:
		return
	var toward: Array = step.get("toward", [])
	var point: Vector3 = Vector3(float(toward[0]), node.global_position.y, float(toward[1])) if toward.size() == 2 \
			else (actor(str(step.get("toward_actor", "red"))).global_position)
	if node.has_method("face_point"):
		node.call("face_point", point)
		node.call("settle_facing")
	elif node.has_method("face_direction"):
		node.call("face_direction", point - node.global_position)


## Looks an actor up by name: a placed townsperson (by placement id), any node in the room (by node
## name), "red", or "follower:<member id>".
func actor(actor_name: String) -> Node3D:
	if actor_name == "red":
		return room.player
	if actor_name.begins_with("follower:"):
		return room.party.follower_for(actor_name.substr("follower:".length())) if room.party != null else null
	for node: Node in room.find_children("*", "Node3D", true, false):
		if node is PlacedNpc and (node as PlacedNpc).placement_id == actor_name:
			return node as Node3D
	return room.find_child(actor_name, true, false) as Node3D


func _walk(step: Dictionary) -> void:
	var node: Node3D = actor(str(step.get("actor", "")))
	var to: Array = step.get("to", [])
	if node == null or to.size() != 2:
		return
	var speed: float = float(step.get("speed", DEFAULT_SPEED))
	var goal: Vector3 = Vector3(float(to[0]), node.global_position.y, float(to[1]))
	var is_red: bool = node == room.player
	_background += 1
	if is_red:
		room.player.set_scripted(true, &"walk")
	while true:
		var flat: Vector3 = Vector3(goal.x - node.global_position.x, 0.0, goal.z - node.global_position.z)
		if flat.length() <= FLAT_REACH or instant:
			node.global_position = goal
			break
		var heading: Vector3 = flat.normalized()
		node.global_position += heading * minf(speed * get_physics_process_delta_time(), flat.length())
		if is_red:
			room.player.rotation.y = PlayerMotion.yaw_for_direction(heading)
		elif node.has_method("face_point"):
			node.call("face_point", node.global_position + heading)
		elif node.has_method("face_direction"):
			node.call("face_direction", heading)
		await get_tree().physics_frame
	if is_red:
		room.player.set_scripted(false)
	elif node.has_method("settle_facing"):
		node.call("settle_facing")
	_background -= 1


static func _list(value: Variant) -> Array[String]:
	var items: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			items.append(str(entry))
	else:
		items.append(str(value))
	return items
