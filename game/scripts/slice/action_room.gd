class_name ActionRoom
extends FieldRoom
## The one room script for every slice room (docs/slice/slice_tech_plan.md 2.2, 2.3, 2.4). It is a FieldRoom, so the
## old town pieces that look for "the room" (doors, props, NPCs, the story director) work unchanged, but it builds the
## room around the new action Red instead of the old field Red:
##
##   * reads its entry in the rooms file (data/slice/rooms.json through the SceneRouter): kind, camera, combat, look
##     profile, form, checkpoint, spawns. The Level (the generated scene: floor, walls, props, a Spawns node) is either
##     this node's own scene or a child called "Level"; Main wraps a plain level scene when it is loaded in slice mode.
##   * a CombatDirector and the fx in EVERY room, even town, so the HUD, FX and bots bind the same way everywhere;
##   * Red (ActionPlayer): town rooms (`combat: false`) use the room's fixed diorama camera, no lock-on, attacks off;
##     dungeon and arena rooms use the orbit camera and lock-on, and spawn the room's enemies;
##   * what Red carries (health, battery, sword, form) goes through GameState.slice_run as a HeroSession;
##   * a knock-out restarts from the room's entrance (or the last checkpoint room) with the health and battery she walked
##     in with (Decision 2, recommended A). data/slice/slice.json "retry" switches the rule; `auto_continue_s` is the
##     stand-in for the Continue screen until the UI exists;
##   * the persistent HUD (a node in group "slice_hud" on the UI stage) is re-bound to this room on entry.
##
## Combat host methods, the same as the sandbox's, so the HUD, FX and bots bind to a room unchanged: get_director(),
## get_player(), get_lock_on(), get_camera(), get_feel(), screen_pos_of(actor_id, point), get_ui_parent(); plus
## get_room_id(), get_form(), get_robot_stage() (null until VS-21) and reset_arena() (the pause menu's reset: back to the
## room's entrance).
##
## Tests and tools can hand it its data without a router: set `entry` (the rooms.json entry) and `room_id` before
## adding it to the tree.

## Red was knocked out (rule: the retry rule's name from slice.json, e.g. "room_entrance").
signal knocked_out_rule(rule: String)
## A restart from a knock-out began (the Continue screen closes on this).
signal continue_started(room: String, spawn: String)
## The form she starts the room in (red / small / huge). RobotStage (VS-21) acts on it.
signal form_entered(form_id: StringName)
## The HUD's Quit (pause menu or Continue screen) was chosen: Main goes back to the title.
signal quit_to_title_requested

const SLICE_DATA_ID: String = "slice/slice"
const SANDBOX_DATA_ID: String = "combat/sandbox"
const GROUP_ROOM: StringName = &"action_room"
const GROUP_HUD: StringName = &"slice_hud"
const GROUP_PSX_SCREEN: StringName = &"psx_screen"
const META_HOST: StringName = &"slice_host"
const LEVEL_NODE: String = "Level"
const DEFAULT_HERO_SCENE: String = "res://scenes/actors/action_player.tscn"
const DEFAULT_STAGE: Vector2 = Vector2(640.0, 360.0)
const FALL_LIMIT_Y: float = -8.0
const KIND_TOWN: String = "town"
const CAMERA_DIORAMA: String = "diorama"
const CAMERA_ORBIT: String = "orbit"
const RULE_ROOM: String = "room_entrance"
const RULE_NONE: String = "none"
const RULE_SAVE: String = "last_save"
const KEY_SESSION: String = "session"
const KEY_CHECKPOINT: String = "checkpoint"

## This room's entry in the rooms file. Empty: asked of the SceneRouter by `room_id`.
var entry: Dictionary = {}
## GameState to carry things through. Null means the autoload.
var game_state: Node = null
## SceneRouter to use. Null means the autoload.
var router: Node = null
## A battery to carry instead of the director's (tests; any object with charge(), capacity() and set_charge()).
var battery_override: Object = null
## Off in tests that step the world by hand.
var hud_enabled: bool = true
## Off in tests that do not want the real window's mouse touched (headless never captures anyway).
var mouse_capture_enabled: bool = true

var level: Node3D = null
var director: CombatDirector = null
var hero: ActionPlayer = null
var orbit: OrbitCamera = null
var lock: LockOn = null
## The robots of a room whose entry names `robots` (VS-21); null in every other room.
var robot_stage: RobotStage = null
## A boss fight's own restart point (VS-30): while set, a knock-out restarts here instead of at the room's entrance. See
## set_phase_checkpoint().
var phase_checkpoint: Dictionary = {}

## Ambient one-liners from townspeople as she walks past.
var barks: AmbientBarks = null

var _slice: Dictionary = {}
var _entry_snapshot: RoomSnapshot = null
var _menu_holds_game: bool = false
var _saving_blocked_by_us: bool = false
var _sandbox_data: Dictionary = {}
var _feel: FeelKnobs = null
var _fx: Node = null
var _hero_camera: Camera3D = null
var _spawn_xform: Transform3D = Transform3D.IDENTITY
var _entry_session: HeroSession = null
var _form: StringName = HeroSession.FORM_RED
var _enemies: Array[Node3D] = []
var _enemy_serial: int = 0
var _session_written: bool = false
var _session_locked: bool = false
var _restarting: bool = false
var _hud: Node = null
var _relay: Node = null
var _mouse_captured: bool = false
var _ko_timer: float = -1.0


## Wraps a plain level scene (no ActionRoom script on its root) in an ActionRoom. Main does this in slice mode.
static func wrap(level_root: Node, spawn: String = "") -> ActionRoom:
	var room: ActionRoom = ActionRoom.new()
	room.name = "ActionRoom"
	level_root.name = LEVEL_NODE
	room.add_child(level_root)
	room.entry_spawn = spawn
	return room


func _ready() -> void:
	add_to_group(GROUP_ROOM)
	_slice = DataDB.get_dict(SLICE_DATA_ID).duplicate(true)       # a copy: tests and tools may change a room's
	_sandbox_data = DataDB.get_dict(SANDBOX_DATA_ID).duplicate(true)
	_read_entry()
	level = _level_root()
	var spawn: Marker3D = find_spawn(entry_spawn)
	if spawn == null:
		push_error("ActionRoom %s: no spawn marker (asked for '%s')" % [room_id, entry_spawn])
		return
	_spawn_xform = Transform3D(Basis.from_euler(Vector3(0.0, spawn.global_rotation.y, 0.0)), spawn.global_position)
	_load_session()
	_build_look()
	_build_director()
	_build_hero()
	_build_camera()
	_build_parts()
	_build_robot_stage()
	_setup_talking_action()
	_setup_story()
	_setup_barks()
	_setup_field_menu()
	_spawn_enemies()
	_apply_session()
	_setup_saving()
	_connect_router()
	_attach_hud()
	_make_relay()
	if is_combat() and camera_kind() == CAMERA_ORBIT:
		set_mouse_captured(bool(_cfg("camera").get("capture_mouse", true)))
	_record_checkpoint()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	tick(delta)


## Per-frame housekeeping: Red or an enemy that fell out of the world goes back to a spawn; the knock-out timer.
func tick(delta: float) -> void:
	if hero != null and hero.global_position.y < FALL_LIMIT_Y:
		hero.global_transform = _spawn_xform
		hero.velocity = Vector3.ZERO
	for enemy: Node3D in _enemies:
		if is_instance_valid(enemy) and enemy.global_position.y < FALL_LIMIT_Y:
			enemy.global_position = Vector3(0.0, 0.5, 0.0)
	if _ko_timer >= 0.0:
		_ko_timer -= delta
		if _ko_timer < 0.0:
			continue_after_knockout()


func _exit_tree() -> void:
	set_mouse_captured(false)
	if not _session_written:
		save_session()
	_release_menu_hold()
	_teardown_saving()
	if _hud != null and is_instance_valid(_hud) and _hud.has_signal("quit_requested") and _hud.is_connected("quit_requested", _on_hud_quit):
		_hud.disconnect("quit_requested", _on_hud_quit)
	if _hud != null and is_instance_valid(_hud) and _hud.has_signal("field_menu_requested") \
			and _hud.is_connected("field_menu_requested", open_field_menu):
		_hud.disconnect("field_menu_requested", open_field_menu)
	if _relay != null and is_instance_valid(_relay):
		_relay.queue_free()
	if _hud != null and is_instance_valid(_hud) and _hud.get_meta(META_HOST, null) == self:
		if _hud.has_method("unbind"):
			_hud.call("unbind")
		_hud.set_meta(META_HOST, null)
	for node: Node in [_fx, director]:
		if node != null and is_instance_valid(node) and node.has_method("unbind"):
			node.call("unbind")
	super._exit_tree()


# ---- the entry in the rooms file ----

func _read_entry() -> void:
	var route: Node = _router()
	if room_id.is_empty() and route != null:
		room_id = str(route.get("pending_room_id"))
		if room_id.is_empty():
			room_id = str(route.get("current_room_id"))
	if entry.is_empty() and route != null and route.has_method("get_room_entry") and not room_id.is_empty():
		entry = route.call("get_room_entry", room_id) as Dictionary
	if entry_spawn.is_empty():
		entry_spawn = str(entry.get("default_spawn", ""))


func get_room_id() -> String:
	return room_id


func get_entry() -> Dictionary:
	return entry


func room_kind() -> String:
	return str(entry.get("kind", "dungeon"))


## True when attacks, hacks and enemies are live (the entry's `combat`; town rooms say false).
func is_combat() -> bool:
	return bool(entry.get("combat", room_kind() != KIND_TOWN))


func camera_kind() -> String:
	return str(entry.get("camera", CAMERA_DIORAMA if room_kind() == KIND_TOWN else CAMERA_ORBIT))


func is_checkpoint() -> bool:
	return bool(entry.get("checkpoint", false))


func _router() -> Node:
	if router != null and is_instance_valid(router):
		return router
	return get_node_or_null("/root/SceneRouter")


func _state() -> Node:
	if game_state != null and is_instance_valid(game_state):
		return game_state
	return get_node_or_null("/root/GameState")


func _cfg(key: String) -> Dictionary:
	return _slice.get(key, {}) as Dictionary


func _level_root() -> Node3D:
	var child: Node3D = get_node_or_null(LEVEL_NODE) as Node3D
	return child if child != null else self


# ---- spawns (looked up under the Level) ----

func find_spawn(wanted: String) -> Marker3D:
	var base: Node = _level_root()
	if not wanted.is_empty():
		var named: Marker3D = base.get_node_or_null(NodePath("%s/%s" % [spawns_name, wanted])) as Marker3D
		if named == null:
			named = base.get_node_or_null(NodePath(wanted)) as Marker3D
		if named != null:
			return named
		push_warning("ActionRoom %s: no spawn '%s', using the default" % [room_id, wanted])
	var default_spawn: Marker3D = base.get_node_or_null(NodePath(spawn_name)) as Marker3D
	if default_spawn != null:
		return default_spawn
	var holder: Node = base.get_node_or_null(NodePath(spawns_name))
	if holder != null:
		for child: Node in holder.get_children():
			if child is Marker3D:
				return child as Marker3D
	return null


func spawn_names() -> Array[String]:
	var names: Array[String] = []
	var base: Node = _level_root()
	var holder: Node = base.get_node_or_null(NodePath(spawns_name))
	if holder != null:
		for child: Node in holder.get_children():
			if child is Marker3D:
				names.append(str(child.name))
	if base.get_node_or_null(NodePath(spawn_name)) is Marker3D:
		names.append(spawn_name)
	return names


# ---- look ----

func _build_look() -> void:
	# The room's lights and environment live in the Level; PsxRoomLook (a child of this node, so its host is the room) sets
	# the fog and the profile's grade. A level without a WorldEnvironment gets a plain one.
	var env_node: WorldEnvironment = level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		env_node.environment = Environment.new()
		level.add_child(env_node)
	if level != self:
		env_node.reparent(self, false)          # PsxRoomLook finds it directly under its host
	var look: PsxRoomLook = get_node_or_null("RoomLook") as PsxRoomLook
	if look == null:
		look = PsxRoomLook.new()
		look.name = "RoomLook"
		add_child(look)
	var wanted: String = str(entry.get("look_profile", ""))
	if wanted.is_empty():
		wanted = str(_cfg("look").get("default_profile", "grim_ps2"))
	if LookProfiles.forced_id().is_empty() and LookProfiles.has_profile(wanted):
		LookProfiles.apply(wanted)


# ---- the combat parts ----

func _build_director() -> void:
	director = CombatDirector.new()
	director.name = "CombatDirector"
	add_child(director)
	_feel = director.feel if director.feel != null else FeelKnobs.load_defaults()
	_feel.load_user()


func _build_hero() -> void:
	var path: String = str(_cfg("hero").get("scene", DEFAULT_HERO_SCENE))
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("ActionRoom: no hero scene at %s" % path)
		return
	hero = scene.instantiate() as ActionPlayer
	if hero == null:
		push_error("ActionRoom: %s is not an ActionPlayer" % path)
		return
	hero.knobs = _feel
	add_child(hero)
	hero.set_death_mode(_death_mode())        # after _ready, which reads the sandbox default from player_action.json
	hero.global_transform = _spawn_xform
	hero.set_town_mode(not is_combat())
	player = hero


func _death_mode() -> StringName:
	return &"retry" if str(_cfg("retry").get("rule", RULE_ROOM)) != RULE_NONE else &"sandbox"


func _build_camera() -> void:
	if hero == null:
		return
	if camera_kind() == CAMERA_ORBIT:
		lock = LockOn.new()
		lock.name = "LockOn"
		lock.origin_node = hero
		add_child(lock)
		orbit = OrbitCamera.new()
		orbit.name = "OrbitCamera"
		add_child(orbit)
		orbit.follow(hero)
		orbit.set_lock_on(lock)
		orbit.knobs = _feel
		orbit.snap()
		_hero_camera = orbit.get_camera()
		hero.camera = _hero_camera
		hero.lock_on = lock
		hero.orbit_camera = orbit
		return
	camera_rig = level.find_child("CameraRig", true, false) as DioramaCamera
	if camera_rig == null:
		camera_rig = DioramaCamera.new()
		camera_rig.name = "CameraRig"
		add_child(camera_rig)
		var look: Dictionary = entry.get("diorama", {}) as Dictionary
		if not look.is_empty():
			camera_rig.set_room_look(float(look.get("pitch_deg", camera_rig.pitch_deg)), float(look.get("yaw_deg", camera_rig.yaw_deg)),
					float(look.get("fov_deg", camera_rig.fov_deg)), float(look.get("distance", camera_rig.distance)))
	var bounds: CameraBounds = level.find_child(bounds_name, true, false) as CameraBounds
	if bounds != null:
		camera_rig.set_bounds(bounds.get_world_aabb())
	camera_rig.set_target(hero)
	camera_rig.snap_to_target()
	_hero_camera = camera_rig.get_camera()
	hero.camera = _hero_camera
	HeroLink.set_camera(hero, _hero_camera)
	prop_fader = PropFader.new()
	prop_fader.name = "PropFader"
	add_child(prop_fader)
	prop_fader.set_target(hero)
	prop_fader.set_camera(_hero_camera)
	prop_fader.target_anchor_height = camera_rig.target_anchor_height


func _build_parts() -> void:
	# More parts (the hack caster, the robot stage) join the list in slice.json "room_parts".
	for raw: Variant in _slice.get("room_parts", []) as Array:
		var part: Dictionary = raw as Dictionary
		var script_path: String = str(part.get("script", ""))
		if script_path.is_empty() or not ResourceLoader.exists(script_path):
			continue
		var script: GDScript = load(script_path) as GDScript
		var node: Node = script.new() as Node if script != null and script.can_instantiate() else null
		if node == null:
			continue
		node.name = str(part.get("id", node.name)).capitalize().replace(" ", "")
		add_child(node)
		if bool(part.get("bind", false)) and node.has_method("bind"):
			node.call("bind", self)
		if str(part.get("id", "")) == "fx":
			_fx = node


## The robots of this room (VS-21): RobotStage reads data/slice/robot_rooms/<entry robots>.json. Only rooms that name robots get one.
func _build_robot_stage() -> void:
	var robots_id: String = str(entry.get("robots", ""))
	if robots_id.is_empty() or hero == null:
		return
	robot_stage = RobotStage.new()
	robot_stage.name = "RobotStage"
	add_child(robot_stage)
	if not robot_stage.bind(self):
		push_warning("ActionRoom %s: no robot room data '%s'" % [room_id, robots_id])


## The stage changed her body (she boarded, docked or climbed out): what the next room and the HUD hear as her form.
func _on_stage_form(form_id: StringName) -> void:
	_form = form_id
	form_entered.emit(form_id)


func _spawn_enemies() -> void:
	if not is_combat():
		return
	for raw: Variant in entry.get("enemies", []) as Array:
		var spawn: Dictionary = raw as Dictionary
		spawn_enemy(str(spawn.get("enemy", "")), _vec3(spawn.get("pos")))


## Puts one enemy of `kind` (a key of combat/sandbox "enemy_scenes") into the room at `pos`. Null if there is no such scene.
## A drone line (VS-19) calls this for each drone it sends.
func spawn_enemy(kind: String, pos: Vector3) -> Node3D:
	var scenes: Dictionary = _sandbox_data.get("enemy_scenes", {}) as Dictionary
	var path: String = str(scenes.get(kind, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("ActionRoom %s: no enemy scene for '%s'" % [room_id, kind])
		return null
	var enemy: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	if enemy == null:
		return null
	_enemy_serial += 1
	if "actor_id" in enemy:
		enemy.set("actor_id", StringName("%s_%d" % [kind, _enemy_serial]))
	if "spawn_position" in enemy:
		enemy.set("spawn_position", pos)
	enemy.position = pos
	add_child(enemy)
	_enemies.append(enemy)
	return enemy


static func _vec3(raw: Variant) -> Vector3:
	if raw is Array and (raw as Array).size() >= 3:
		var list: Array = raw
		return Vector3(float(list[0]), float(list[1]), float(list[2]))
	return Vector3.ZERO


# ---- talking ----

func _setup_talking_action() -> void:
	runner = DialogueRunner.create(self, hero, _hero_camera)
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		if node is Npc and is_ancestor_of(node):
			var npc: Npc = node as Npc
			runner.register_speaker(npc.speaker_id, npc, npc.get_head_height())
	prompt = InteractPrompt.new()
	prompt.follow = hero
	prompt.camera = _hero_camera
	UiStage.get_or_create(get_tree()).get_stage_root().add_child(prompt)
	interactor = PlayerInteractor.new()
	interactor.name = "PlayerInteractor"
	interactor.player = hero
	interactor.runner = runner
	interactor.prompt = prompt
	interactor.rules = InteractRules.load_default()           # Decision 3, a data switch (slice.json "interact")
	interactor.combat_room = is_combat()
	add_child(interactor)
	interactor.install_press_filter()
	# The old field menu, party and room fights belong to the shelved game; the slice pause menu replaces the menu.


# ---- what Red carries ----

func _slice_run() -> Dictionary:
	var state: Node = _state()
	if state == null:
		return {}
	return state.get("slice_run") as Dictionary


func _put_slice_run(run: Dictionary) -> void:
	var state: Node = _state()
	if state != null:
		state.set("slice_run", run)


func _load_session() -> void:
	var run: Dictionary = _slice_run()
	var carried: HeroSession = HeroSession.from_dict(run.get(KEY_SESSION, {}) as Dictionary)
	_entry_session = carried.duplicate_session()
	_form = carried.form_for_room(str(entry.get("form", "red")))
	var state: Node = _state()
	_entry_snapshot = RoomSnapshot.capture(_entry_session.to_dict(), state.call("run_snapshot") as Dictionary if state != null else {})


func _apply_session() -> void:
	if hero == null or _entry_session == null:
		return
	# a room that starts inside a robot (J5 in the loader) puts her in it first, so her health is read in that body's terms
	if robot_stage != null:
		robot_stage.place_in(_form)
		if not robot_stage.form_changed.is_connected(_on_stage_form):
			robot_stage.form_changed.connect(_on_stage_form)
	hero.hp = _entry_session.health_for(hero.hp_max)
	if _entry_session.hp > 0 and _entry_session.hp_max > 0 and _entry_session.hp_max != hero.hp_max:
		# she walked in from a body of another size (Red to the loader and back): keep the fraction, not the number
		var fraction: float = clampf(float(_entry_session.hp) / float(_entry_session.hp_max), 0.0, 1.0)
		hero.hp = clampi(int(roundf(fraction * float(hero.hp_max))), 1, hero.hp_max)
	hero.dead = false
	if director != null:
		director.hp_changed.emit(hero.actor_id, hero.hp, hero.hp_max)
	if _entry_session.sword != &"":
		hero.equip_sword(_entry_session.sword)
	var battery: Object = _battery()
	if battery != null and _entry_session.has_battery():
		_set_battery(battery, _entry_session.battery_for(float(battery.call("capacity"))))
	if _form != HeroSession.FORM_RED and robot_stage == null:
		push_warning("ActionRoom %s: form '%s' asked for, but the room's entry names no `robots`" % [room_id, _form])
	form_entered.emit(_form)


## The hack battery, once the director has one (VS-8): any object with charge() and capacity().
func _battery() -> Object:
	if battery_override != null and is_instance_valid(battery_override):
		return battery_override
	if director == null or not "battery" in director:
		return null
	var battery: Object = director.get("battery") as Object
	if battery == null or not battery.has_method("charge") or not battery.has_method("capacity"):
		return null
	return battery


func _set_battery(battery: Object, charge: float) -> void:
	if battery.has_method("set_charge"):
		battery.call("set_charge", charge)
	elif charge >= float(battery.call("capacity")) and battery.has_method("reset_full"):
		battery.call("reset_full")


## What she carries right now.
func capture_session() -> HeroSession:
	var session: HeroSession = HeroSession.new()
	if hero != null:
		session.hp = 0 if hero.dead else hero.hp
		session.hp_max = hero.hp_max
		session.sword = hero.current_sword()
	var battery: Object = _battery()
	if battery != null:
		session.battery = float(battery.call("charge"))
	session.form = _form
	return session


## Writes what she carries into GameState (a door is being used, or the room is leaving). Not after a knock-out restart,
## which has already put the entrance snapshot back.
func save_session() -> void:
	_session_written = true
	if _session_locked or hero == null:
		return
	var run: Dictionary = _slice_run().duplicate(true)
	run[KEY_SESSION] = capture_session().to_dict()
	_put_slice_run(run)


func get_entry_session() -> HeroSession:
	return _entry_session


func get_form() -> StringName:
	return _form


func _record_checkpoint() -> void:
	if not is_checkpoint() or _entry_session == null:
		return
	var run: Dictionary = _slice_run().duplicate(true)
	run[KEY_CHECKPOINT] = {"room": room_id, "spawn": entry_spawn, "session": _entry_session.to_dict(),
			"snapshot": _entry_snapshot.to_dict() if _entry_snapshot != null else {}}
	_put_slice_run(run)


func _connect_router() -> void:
	var route: Node = _router()
	if route != null and route.has_signal("transition_started") and not route.is_connected("transition_started", _on_transition_started):
		route.connect("transition_started", _on_transition_started)
	if hero != null:
		hero.knocked_out.connect(_on_knocked_out)


func _on_transition_started(_next_room: String) -> void:
	save_session()



# ---- barks, the field menu, saving (VS-15, VS-16) ----

func _setup_barks() -> void:
	barks = AmbientBarks.new()
	barks.name = "AmbientBarks"
	barks.hero = hero
	barks.camera = _hero_camera
	add_child(barks)


## The field menu (Items, Sword, Config, Save) opened from the pause menu, not from the `menu` button. Red's health is
## handed to the menu's party member while it is open (so healing items work on her) and read back when it closes.
func _setup_field_menu() -> void:
	var options: Dictionary = {"listen_open_action": false, "commands": (_cfg("menu").get("commands", []) as Array)}
	field_menu = FieldMenu.install(get_tree(), hero, options)
	field_menu.opened.connect(_on_menu_opened)
	field_menu.closed.connect(_on_menu_closed)


## Opens the field menu (the HUD's pause menu calls this). In a room with enemies the world stands still meanwhile.
func open_field_menu() -> bool:
	if field_menu == null or not is_instance_valid(field_menu) or hero == null or hero.dead:
		return false
	if not field_menu.open():
		return false
	if is_combat():
		SandboxPauseGate.hold(get_tree(), field_menu)
		_menu_holds_game = true
	return true


func _on_menu_opened() -> void:
	HeroVitals.push(_state(), hero)


func _on_menu_closed() -> void:
	HeroVitals.pull(_state(), hero)
	_release_menu_hold()


func _release_menu_hold() -> void:
	if _menu_holds_game and field_menu != null and is_instance_valid(field_menu):
		SandboxPauseGate.release(get_tree(), field_menu)
	_menu_holds_game = false


## True when saving is off in this room: a robot room (the entry names robots) or any room she walks into in a robot form.
func saving_blocked() -> bool:
	if not bool(_cfg("saving").get("blocked_in_robot_rooms", true)):
		return false
	return not str(entry.get("robots", "")).is_empty() or _form != HeroSession.FORM_RED


func _setup_saving() -> void:
	var state: Node = _state()
	if state != null:
		state.set("live_flush", _flush_to_state)
		if not state.is_connected("party_rested", _on_party_rested):
			state.connect("party_rested", _on_party_rested)
	var manager: Node = get_node_or_null("/root/SaveManager")
	if manager != null and saving_blocked():
		manager.set("saving_allowed", false)
		_saving_blocked_by_us = true
		for lamp: Node in get_tree().get_nodes_in_group(SaveLamp.GROUP_LAMP):
			if is_ancestor_of(lamp) and lamp is Interactable:
				(lamp as Interactable).enabled = false


func _teardown_saving() -> void:
	var state: Node = _state()
	if state != null:
		var flush: Callable = state.get("live_flush") as Callable
		if flush.is_valid() and flush.get_object() == self:
			state.set("live_flush", Callable())
		if state.is_connected("party_rested", _on_party_rested):
			state.disconnect("party_rested", _on_party_rested)
	var manager: Node = get_node_or_null("/root/SaveManager")
	if manager != null and _saving_blocked_by_us:
		manager.set("saving_allowed", true)
	_saving_blocked_by_us = false


## GameState is about to write a save: put Red's live health and sword into the run first.
func _flush_to_state() -> void:
	if hero == null or not is_instance_valid(hero) or _session_locked:
		return
	var run: Dictionary = _slice_run().duplicate(true)
	run[KEY_SESSION] = capture_session().to_dict()
	_put_slice_run(run)


## A terminal or inn rested the party: Red is fully healed and the battery is full.
func _on_party_rested() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	hero.hp = hero.hp_max
	hero.dead = false
	if director != null:
		director.hp_changed.emit(hero.actor_id, hero.hp, hero.hp_max)
	var battery: Object = _battery()
	if battery != null and battery.has_method("reset_full"):
		battery.call("reset_full")

# ---- knock-out and retry (Decision 2) ----

## The rule in force: "room_entrance" (A, default), "last_save" (B), "none" (she gets up, as in the sandbox).
func retry_rule() -> String:
	return str(_cfg("retry").get("rule", RULE_ROOM))


func _on_knocked_out() -> void:
	knocked_out_rule.emit(retry_rule())
	var wait: float = float(_cfg("retry").get("auto_continue_s", 0.0))
	if wait > 0.0:
		_ko_timer = wait


## Where a restart goes: the room and spawn she last entered through a checkpoint room (this room, if it is one), and
## the session to restore. With no checkpoint at all, this room's own entrance.
func continue_target() -> Dictionary:
	if not phase_checkpoint.is_empty():
		return phase_checkpoint
	var run: Dictionary = _slice_run()
	var checkpoint: Dictionary = run.get(KEY_CHECKPOINT, {}) as Dictionary
	if checkpoint.is_empty() or is_checkpoint():
		return {"room": room_id, "spawn": entry_spawn, "session": _entry_session.to_dict() if _entry_session != null else {},
				"snapshot": _entry_snapshot.to_dict() if _entry_snapshot != null else {}}
	return checkpoint


## A boss fight's per-phase retry point (the BossFight calls it when a phase begins): a knock-out now reloads this room at
## `spawn` with Red in `form`. `full_health` true (phase 2: "restarts already docked at full colossus health") records full health
## and a full battery; false keeps the health and battery she walked in with. Flags, items and credits are as they are now.
## `clear_phase_checkpoint()` goes back to the room's entrance.
func set_phase_checkpoint(spawn: String, form: StringName, full_health: bool = true) -> void:
	var session: HeroSession = (_entry_session.duplicate_session() if _entry_session != null and not full_health else HeroSession.new())
	if full_health:
		session.hp = 0
		session.battery = HeroSession.FULL
	session.form = form
	var state: Node = _state()
	var snapshot: RoomSnapshot = RoomSnapshot.capture(session.to_dict(), state.call("run_snapshot") as Dictionary if state != null else {})
	phase_checkpoint = {"room": room_id, "spawn": spawn, "session": session.to_dict(), "snapshot": snapshot.to_dict()}


func clear_phase_checkpoint() -> void:
	phase_checkpoint = {}


## Restarts after a knock-out: health, battery, sword and form go back to what she walked in with, credits are docked by
## `retry.credit_cost`, and the room is loaded again at the entrance she used. Rule "last_save" asks Main to load the
## newest save instead. Returns false when there was nothing to do (Red is up, or a restart is already running).
func continue_after_knockout() -> bool:
	if _restarting or hero == null or not hero.is_knocked_out():
		return false
	_restarting = true
	_ko_timer = -1.0
	var retry: Dictionary = _cfg("retry")
	var cost: int = int(retry.get("credit_cost", 0))
	var state: Node = _state()
	if retry_rule() == RULE_SAVE:
		if cost > 0 and state != null:
			state.call("add_credits", -mini(cost, int(state.call("get_credits"))))
		var main: Node = get_tree().get_first_node_in_group(&"main_flow")
		continue_started.emit("", "")
		return main != null and main.has_method("continue_game") and bool(main.call("continue_game"))
	var target: Dictionary = continue_target()
	var snapshot_data: Dictionary = target.get("snapshot", {}) as Dictionary
	if state != null:
		if snapshot_data.is_empty():
			if cost > 0:
				state.call("add_credits", -mini(cost, int(state.call("get_credits"))))
		else:
			# Items, credits, flags and opened ids go back to the entrance, except the sticky puzzle ids; the cost comes off.
			var snap: RoomSnapshot = RoomSnapshot.from_dict(snapshot_data)
			state.call("restore_run_snapshot", snap.restored(state.call("run_snapshot") as Dictionary, sticky_ids(), cost))
	var run: Dictionary = _slice_run().duplicate(true)
	run[KEY_SESSION] = (target.get("session", {}) as Dictionary).duplicate(true)
	_put_slice_run(run)
	_session_locked = true
	var to_room: String = str(target.get("room", room_id))
	var to_spawn: String = str(target.get("spawn", entry_spawn))
	continue_started.emit(to_room, to_spawn)
	var route: Node = _router()
	if route != null and route.has_method("start_at"):
		route.call("start_at", to_room, to_spawn)
	return true


## Flag ids and opened ids that a knock-out restart must NOT rewind: placements marked `"sticky": true` (an opened fuse-box
## door stays open). The ids come from the entry's `flag`, `opened_id` and `target_id` keys, plus `door_<id>` for a door.
func sticky_ids() -> Array:
	var ids: Array = []
	for section_name: String in Placements.section_names():
		var block: Dictionary = Placements.section(section_name)
		for placement_id: String in block:
			if not block[placement_id] is Dictionary:          # an "_about" note
				continue
			var info: Dictionary = block[placement_id] as Dictionary
			if not bool(info.get("sticky", false)):
				continue
			for key: String in ["flag", "opened_id", "target_id"]:
				if info.has(key):
					ids.append(str(info[key]))
			for raw_job: Variant in info.get("jobs", []) as Array:        # a crane's jobs each set their own flag
				if raw_job is Dictionary and (raw_job as Dictionary).has("flag"):
					ids.append(str((raw_job as Dictionary)["flag"]))
			if section_name == Placements.SECTION_DOORS:
				ids.append(Door.UNLOCK_PREFIX + placement_id)
	return ids


## The HUD pause menu's "reset": back to the entrance with the entrance snapshot, in place.
func reset_arena() -> void:
	if hero == null:
		return
	hero.reset_to(_spawn_xform)
	if robot_stage != null:
		robot_stage.reset()                    # tells us she is Red again, so read the entry form after it
	_form = _entry_session.form_for_room(str(entry.get("form", "red"))) if _entry_session != null else _form
	_apply_session()
	if orbit != null:
		orbit.recenter()
		orbit.snap()


# ---- the combat host (what the HUD, FX and bots bind to) ----

func get_director() -> CombatDirector:
	return director


func get_player() -> ActionPlayer:
	return hero


func get_lock_on() -> LockOn:
	return lock


## The orbit camera in dungeon and arena rooms; null in town (the diorama camera is get_camera_3d()'s).
func get_camera() -> OrbitCamera:
	return orbit


func get_camera_3d() -> Camera3D:
	return _hero_camera


func get_feel() -> FeelKnobs:
	return _feel


func get_robot_stage() -> Node:
	return robot_stage


func get_enemies() -> Array[Node3D]:
	var live: Array[Node3D] = []
	for enemy: Node3D in _enemies:
		if is_instance_valid(enemy):
			live.append(enemy)
	return live


## The sharp UI layer (the PSX screen's), or a layer of this room's own when there is no screen (tests).
func get_ui_parent() -> Node:
	var screen: Node = get_tree().get_first_node_in_group(GROUP_PSX_SCREEN)
	if screen != null and screen.has_method("get_ui_layer"):
		return screen.call("get_ui_layer") as Node
	var own_layer: CanvasLayer = get_node_or_null("UiLayer") as CanvasLayer
	if own_layer == null:
		own_layer = CanvasLayer.new()
		own_layer.name = "UiLayer"
		add_child(own_layer)
	return own_layer


func _stage_size() -> Vector2:
	var raw: Variant = _sandbox_data.get("stage_size", null)
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	return DEFAULT_STAGE


## Where an actor's `point` (&"head", &"center", &"feet", &"lamp") is on the stage, in stage pixels. ZERO when unknown or
## behind the camera.
func screen_pos_of(actor_id: StringName, point: StringName = &"head") -> Vector2:
	var actor: Node3D = _find_actor(actor_id)
	if actor == null or _hero_camera == null:
		return Vector2.ZERO
	var world: Vector3 = _anchor_of(actor, point)
	if _hero_camera.is_position_behind(world):
		return Vector2.ZERO
	var pixel: Vector2 = _hero_camera.unproject_position(world)
	var size: Vector2 = _hero_camera.get_viewport().get_visible_rect().size
	var stage: Vector2 = _stage_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return pixel
	return Vector2(pixel.x * stage.x / size.x, pixel.y * stage.y / size.y)


func _find_actor(actor_id: StringName) -> Node3D:
	if director != null:
		var found: CombatActor = director.get_actor(actor_id)
		if found != null:
			return found
	if actor_id == &"red" and hero != null:
		return hero
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		if node is Npc and is_ancestor_of(node) and StringName((node as Npc).speaker_id) == actor_id:
			return node as Node3D
	return null


func _anchor_of(actor: Node3D, point: StringName) -> Vector3:
	if actor.has_method("anchor"):
		return actor.call("anchor", point) as Vector3
	var lift: float = {&"feet": 0.0, &"center": 0.45, &"head": 1.0, &"lamp": 0.6}.get(point, 0.5)
	return actor.global_position + Vector3.UP * lift


# ---- the persistent HUD ----

func _attach_hud() -> void:
	if not hud_enabled:
		return
	var existing: Node = get_tree().get_first_node_in_group(GROUP_HUD)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		_hud = existing
	else:
		var path: String = str(_cfg("hud").get("scene", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			return
		var scene: PackedScene = load(path) as PackedScene
		_hud = scene.instantiate() if scene != null else null
		if _hud == null:
			return
		_hud.add_to_group(GROUP_HUD)
		UiStage.get_or_create(get_tree()).get_stage_root().add_child(_hud)
	if _hud.has_method("bind"):
		_hud.call("bind", self)
		_hud.set_meta(META_HOST, self)
	if "auto_quit" in _hud:
		_hud.set("auto_quit", false)               # Quit goes back to the title (Main), not out of the program
	if _hud.has_signal("quit_requested") and not _hud.is_connected("quit_requested", _on_hud_quit):
		_hud.connect("quit_requested", _on_hud_quit)
	# The pause menu's "Menu" row opens the field menu (the HUD only shows the row while somebody listens).
	if _hud.has_signal("field_menu_requested") and field_menu != null and not _hud.is_connected("field_menu_requested", open_field_menu):
		_hud.connect("field_menu_requested", open_field_menu)


func _on_hud_quit() -> void:
	quit_to_title_requested.emit()


func get_hud() -> Node:
	return _hud


# ---- input ----

func _make_relay() -> void:
	if get_tree().get_first_node_in_group(GROUP_PSX_SCREEN) == null:
		return        # no PSX screen: the hero and cameras poll Input themselves
	var relay: InputRelay = InputRelay.new()
	relay.name = "ActionRoomInputRelay"
	relay.room = self
	get_ui_parent().add_child(relay)
	_relay = relay


## One input event from the relay: combat buttons (with their real press time) to Red, mouse motion to the orbit camera.
func handle_input_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _mouse_captured and orbit != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			orbit.add_mouse_motion((event as InputEventMouseMotion).relative)
		return
	if hero != null:
		hero.handle_input_event(event)


func set_mouse_captured(captured: bool) -> void:
	if captured and not mouse_capture_enabled:
		return
	_mouse_captured = captured
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return _mouse_captured


class InputRelay extends Node:
	var room: ActionRoom = null

	func _input(event: InputEvent) -> void:
		if room != null and is_instance_valid(room):
			room.handle_input_event(event)
