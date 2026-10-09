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
##     join {member, at}                   the member joins the party (GameState.join_party) and the walking
##                                         line, standing at an actor's spot
##     wait_action {action, prompt}        shows a prompt (a line from data/text/train.json) and waits for that
##                                         button (the train's one prompted Jump; it can't be missed, it waits)
##     run {scene}                         plays another scene's steps right here, then carries on
##     goto {room, spawn}                  changes room through the SceneRouter (the scene ends with it)
##     heal_party                          full HP and Juice for everyone (the old Zero's thermos)
## Red is frozen while a scene plays (unless "freeze": false) and the crew stands still.
## Dialogue lines can carry their own set_flag / give_item actions too.

signal scene_started(scene_id: String)
signal scene_finished(scene_id: String)
signal battle_done(result: String)
## One per physics frame, from this node's own _physics_process. A wait that must not outlive the director awaits this instead of
## the tree's physics_frame: when the director is freed the signal never fires, so the wait ends silently instead of resuming a
## function whose instance is gone (bug B19).
signal _frame_passed

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
## Set by press_action(); the awaited button counts as pressed.
var pressed_action: bool = false
## True while a wait_action step is showing its prompt.
var waiting_for_action: bool = false

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
	_frame_passed.emit()
	if _triggers.is_empty() or not triggers_enabled or _running or room == null or room.is_suspended():
		return
	var player: CharacterBody3D = room.player
	if player == null or HeroLink.is_frozen(player) or HeroLink.is_scripted(player) or not HeroLink.is_on_floor(player):
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
		HeroLink.set_frozen(room.player, true)
		_held_player = true
	if room.party != null:
		room.party.active = false
	scene_started.emit(scene_id)
	await _steps(data.get("steps", []))
	if _gone:
		return
	while _background > 0:
		await get_tree().physics_frame
	if room.party != null:
		room.party.active = true
	if _held_player and room.player != null and is_instance_valid(room.player):
		HeroLink.set_frozen(room.player, false)
	_held_player = false
	_running = false
	current_scene = ""
	_refresh_spots()
	scene_finished.emit(scene_id)


## A scene may have changed a flag a spot's show_if reads (the crate she just shouldered): ask them again.
func _refresh_spots() -> void:
	if room == null or not is_instance_valid(room):
		return
	for node: Node in room.find_children("*", "Node3D", true, false):
		if node is SceneSpot:
			(node as SceneSpot).refresh()


func _steps(steps: Array) -> void:
	for step: Variant in steps:
		var entry: Dictionary = step
		if Conditions.met(entry.get("if", {}), game_state):
			await _do(entry)
		if _gone:
			return


## Runs another scene's steps inline (no freeze, flags or finish signal of its own): one scene ending in
## the next, like the ditch scene handing over to the jump.
func _run(step: Dictionary) -> void:
	var other: Dictionary = Placements.scene(str(step.get("scene", "")))
	if other.is_empty():
		push_warning("StoryDirector: no scene '%s' to run" % step.get("scene", ""))
		return
	await _steps(other.get("steps", []))


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
		"wait_action":
			await _wait_action(step)
		"goto":
			_goto(step)
		"run":
			await _run(step)
		"form":
			await _form(step)
		"heal_party":
			var healer: Node = WorldProgress.game_state(game_state)
			if healer != null:
				healer.call("rest_party")
		_:
			push_warning("StoryDirector: unknown step '%s' in scene %s" % [step.get("do", ""), current_scene])


## `form` (slice): a robot form change on the room's RobotStage. action "disembark" climbs out and waits until she is on foot (the arena gate:
## the loader stays parked), "board" and "dock" start those sequences and wait for the form to change. Needs a room with a RobotStage
## (ActionRoom.get_robot_stage()); without one it only warns.
func _form(step: Dictionary) -> void:
	var stage: Node = room.call("get_robot_stage") as Node if room.has_method("get_robot_stage") else null
	if stage == null:
		push_warning("StoryDirector: the form step needs a room with a robot stage (scene %s)" % current_scene)
		return
	var before: StringName = stage.call("form") as StringName
	var wanted: StringName = &"red"
	match str(step.get("action", "")):
		"disembark":
			if before == &"red":
				return
			stage.call("disembark")
		"board":
			stage.call("board")
			wanted = &"small"
		"dock":
			stage.call("dock")
			wanted = &"huge"
		_:
			push_warning("StoryDirector: unknown form action '%s' in scene %s" % [step.get("action", ""), current_scene])
			return
	var waited: int = 0
	while is_instance_valid(stage) and stage.call("form") != wanted and waited < MAX_WAIT_FRAMES * 4 and is_inside_tree() and not _gone:
		await _frame_passed                  # not the tree's physics_frame: B19, the room can be freed while this waits
		waited += 1


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
	var gs: Node = WorldProgress.game_state(game_state)
	if gs != null and gs.has_method("join_party"):
		gs.call("join_party", str(step.get("member", "")))
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
		if node is MapEnemy and (node as MapEnemy).placement_id == actor_name:
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
		HeroLink.set_scripted(room.player, true, &"walk")
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
		HeroLink.set_scripted(room.player, false)
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


## Shows a prompt and waits until `action` is pressed. Nothing to miss: the prompt waits as long as it takes.
func _wait_action(step: Dictionary) -> void:
	var action: StringName = StringName(str(step.get("action", "jump")))
	var key: String = str(step.get("prompt", ""))
	var text: Variant = DataDB.get_value("text/train", key, key)
	var prompt: Control = ActionPrompt.show_on_stage(get_tree(), str(text))
	pressed_action = false
	waiting_for_action = true
	while not _gone and is_inside_tree():
		if pressed_action or Input.is_action_just_pressed(action):
			break
		await get_tree().physics_frame
	waiting_for_action = false
	pressed_action = false
	if prompt != null and is_instance_valid(prompt):
		prompt.queue_free()


## Tests (and a touch screen later) press the awaited button this way.
func press_action() -> void:
	pressed_action = true


func _goto(step: Dictionary) -> void:
	var route: Node = router if router != null else get_node_or_null("/root/SceneRouter")
	if route != null:
		route.call("go_to", str(step.get("room", "")), str(step.get("spawn", "")))
