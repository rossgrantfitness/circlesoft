class_name BossFight
extends Node
## The boss fight in the arena room (slice tech plan 6.3; data/combat/bosses/hushmaster.json; docs/slice/boss_design.md).
## It owns the phase list (BossPhases), builds each phase's boss, reports the boss bar, sets the per-phase retry point and runs
## the transition through BossTransition (the second Gameplay Programmer's node; the hook is agreed in the plan's Changes).
##
## Phase 1, the rig: a Hushmaster at the arena's `hushmaster_start`, three powered-down wall turrets at the `turret_k_*`
## markers (they only shoot once Red Overclocks one, and then they go for the relays first), the drone hatches, the
## battery topped to at least `start.battery_floor`. The phase ends when the Hushmaster says `defeated` (the jack-in beat).
## Then `BossTransition.begin()`; on `finished` the Heap's phase starts (VS-28) with the retry point `retry_phase2`.
## A room entered at `retry_phase1` or `retry_phase2` resumes that phase with no intro and no boarding.
##
## The room hands it over with `bind(room)`: it works only in a room whose entry says `"boss": "<file>"`, or the room called
## `kasp_arena` (the Hushmaster's file). In any other room it frees itself, so it can sit in the slice's `room_parts`.

signal boss_bar_shown(info: Dictionary)
signal boss_hp_changed(hp: float, hp_max: float)
signal boss_phase_changed(index: int, phase_name: String)
signal boss_bar_hidden()
signal boss_pips_changed(standing: int, total: int)       ## relay pips for a HUD that wants them (leg pairs still standing)
signal quiet_hours_warning(ms: float)                      ## the dish hums: hacks lock in `ms` (a HUD fizzes the screen edges)
signal quiet_hours_cleared                                 ## the warning is over without the lock (the dish was hit or broke)
signal phase_started(phase_id: StringName)
signal phase_finished(phase_id: StringName)
signal fight_finished
signal boss_event(event_id: StringName)                    ## a bark or hint id from the data's `events` (the Writer's words, the radio)

const GROUP: StringName = &"boss_fight"
const DEFAULT_FILE: String = "hushmaster.json"
const TURRET_SCENE: String = "res://scenes/actors/enemies/wall_turret.tscn"
const ARENA_ROOM: String = "kasp_arena"
const MECH_FILE: String = "junk_mech.json"

var room: Node3D = null
var director: CombatDirector = null
var player: ActionPlayer = null
var doc: Dictionary = {}
var phases: BossPhases = null
var hushmaster: Hushmaster = null
var transition: BossTransition = null
var turrets: Array[WallTurret] = []
## Off in tests that step the fight by hand with tick().
var run_on_physics: bool = true
var seed_value: int = 1
var heap: JunkMech = null
var heap_doc: Dictionary = {}
var repair_cells: Array[Dictionary] = []          # {node, position, taken}

var _phase: StringName = &""
var _started: bool = false
var _age_s: float = 0.0
var _hints_given: Dictionary = {}
var _first_drop_seen_s: float = -1.0
var _bar_info: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	set_physics_process(run_on_physics)


func _physics_process(delta: float) -> void:
	tick(delta)


# ---- setup ----

## Joins a room. False (and the node frees itself) when this room has no boss fight.
func bind(for_room: Node) -> bool:
	var entry: Dictionary = for_room.get("entry") as Dictionary if "entry" in for_room else {}
	var room_name: String = str(for_room.get("room_id")) if "room_id" in for_room else ""
	var file_name: String = str(entry.get("boss", ""))
	if file_name.is_empty() and room_name == ARENA_ROOM:
		file_name = DEFAULT_FILE
	if file_name.is_empty():
		queue_free()
		return false
	if not file_name.ends_with(".json"):
		file_name += ".json"
	var found_director: CombatDirector = for_room.call("get_director") as CombatDirector if for_room.has_method("get_director") else null
	var found_player: ActionPlayer = for_room.call("get_player") as ActionPlayer if for_room.has_method("get_player") else null
	var ok: bool = setup(for_room as Node3D, found_director, found_player, file_name)
	var spawn: String = str(for_room.get("entry_spawn")) if "entry_spawn" in for_room else ""
	if ok and is_inside_tree():
		call_deferred("start_for_spawn", spawn)
	return ok


func setup(for_room: Node3D, for_director: CombatDirector, for_player: ActionPlayer, file_name: String = DEFAULT_FILE) -> bool:
	room = for_room
	director = for_director
	player = for_player
	doc = CombatData.read_json(CombatData.DIR + "bosses/" + file_name)
	phases = BossPhases.from_data(doc)
	return room != null and director != null and phases.count() > 0


# ---- phases ----

func phase_id() -> StringName:
	return _phase


func phase_index() -> int:
	return phases.index_of(_phase) if phases != null else -1


func boss_actor() -> CombatActor:
	return hushmaster


func is_started() -> bool:
	return _started


## Starts the fight for the way the room was entered: through a retry marker it resumes that phase, otherwise from the top.
func start_for_spawn(spawn: String) -> void:
	var resume: StringName = phases.phase_for_spawn(spawn)
	start(resume)


## Starts at `from_phase` (default: the first). A retry resumes without the intro.
func start(from_phase: StringName = &"") -> void:
	if phases == null or _started and from_phase == &"":
		return
	_started = true
	var retry: bool = from_phase != &""
	if not phases.start(from_phase):
		return
	_enter_phase(phases.current(), retry)


func _enter_phase(id: StringName, retry: bool) -> void:
	_phase = id
	_age_s = 0.0
	_hints_given.clear()
	phase_started.emit(id)
	if phases.is_scripted(id):
		_run_transition()
		return
	match str(phases.phase(id).get("boss", "")):
		"hushmaster":
			_start_rig(retry)
		_:
			_start_next_boss(id, retry)


# ---- phase 1: the rig ----

func _start_rig(retry: bool) -> void:
	var rig: Dictionary = phases.phase(_phase)
	var rules: Dictionary = doc.get("rules", {}) as Dictionary
	if director != null:
		director.hijack_priority_tags = ["relay"] as Array[String]
		var floor_charge: float = phases.battery_floor(_phase)
		if floor_charge > 0.0 and director.battery != null and director.battery.charge() < floor_charge:
			director.battery.set_charge(floor_charge)       # a fresh start or a retry: the first relay is a few Zaps away
			director.sync_battery()
	_set_retry_point()
	hushmaster = Hushmaster.create(rules, rig, seed_value)
	hushmaster.hatches = _hatch_points()
	var start_at: Node3D = marker(&"hushmaster_start")
	room.add_child(hushmaster)
	if start_at != null:
		hushmaster.global_transform = Transform3D(start_at.global_basis, start_at.global_position)
	hushmaster.pair_dropped.connect(_on_pair_dropped)
	hushmaster.defeated.connect(_on_rig_defeated)
	hushmaster.bark.connect(func(id: StringName) -> void: boss_event.emit(id))
	hushmaster.pattern_started.connect(_on_pattern_started)
	hushmaster.quiet_hours_started.connect(_on_quiet_started)
	hushmaster.quiet_hours_cut.connect(func(_by: String) -> void: _emit_quiet_cleared())
	hushmaster.dish_broke.connect(_emit_quiet_cleared)
	hushmaster.toppled.connect(_emit_quiet_cleared)
	director.hp_changed.connect(_on_hp_changed)
	_build_turrets(rig)
	_show_bar()
	_emit_pips(hushmaster.pairs_standing(), Hushmaster.PAIRS.size())
	var events: Dictionary = rig.get("events", {}) as Dictionary
	if not retry and events.has("on_phase_start"):
		boss_event.emit(StringName(str(events["on_phase_start"])))


## The knock-out restart point for the current phase (ActionRoom.set_phase_checkpoint).
func _set_retry_point() -> void:
	var retry: Dictionary = phases.retry_for(_phase)
	if room != null and room.has_method("set_phase_checkpoint") and not str(retry["spawn"]).is_empty():
		room.call("set_phase_checkpoint", str(retry["spawn"]), retry["form"], bool(retry["full_health"]))


func _hatch_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var arena: Dictionary = phases.phase(_phase).get("arena", {}) as Dictionary
	for name_raw: Variant in arena.get("drone_hatches", []) as Array:
		var node: Node3D = marker(StringName(str(name_raw)))
		if node != null:
			out.append(node.global_position)
	return out


func _build_turrets(rig: Dictionary) -> void:
	var arena: Dictionary = rig.get("arena", {}) as Dictionary
	if not ResourceLoader.exists(TURRET_SCENE):
		return
	var scene: PackedScene = load(TURRET_SCENE) as PackedScene
	var priority: Dictionary = rig.get("hijack_priority", {}) as Dictionary
	for name_raw: Variant in arena.get("turret_nodes", []) as Array:
		var spot: Node3D = marker(StringName(str(name_raw)))
		if spot == null:
			continue
		var turret: WallTurret = scene.instantiate() as WallTurret
		turret.actor_id = StringName(str(name_raw))
		turret.attacks_allowed = bool(priority.get("hostile_fire", false))
		room.add_child(turret)
		turret.global_transform = Transform3D(spot.global_basis, spot.global_position)
		turrets.append(turret)


func _on_pair_dropped(_pair: StringName, _lost: int) -> void:
	_emit_pips(hushmaster.pairs_standing(), Hushmaster.PAIRS.size())


func _emit_pips(standing: int, total: int) -> void:
	boss_pips_changed.emit(standing, total)
	if director != null:
		director.boss_pips_changed.emit(standing, total)


## The dish started to hum (Quiet Hours' warning). The HUD hears it from here and from the director.
func _on_quiet_started() -> void:
	var ms: float = hushmaster.quiet_warning_ms() if hushmaster != null else 1400.0
	quiet_hours_warning.emit(ms)
	if director != null:
		director.quiet_hours_warning.emit(ms)


func _emit_quiet_cleared() -> void:
	quiet_hours_cleared.emit()
	if director != null:
		director.quiet_hours_cleared.emit()


func _on_pattern_started(id: StringName) -> void:
	if id == &"drone_drop" and _first_drop_seen_s < 0.0:
		_first_drop_seen_s = _age_s


func _on_hp_changed(actor: StringName, hp: int, hp_max: int) -> void:
	if hushmaster != null and actor == hushmaster.actor_id:
		boss_hp_changed.emit(float(hp), float(hp_max))


func _on_rig_defeated(_reason: StringName) -> void:
	phase_finished.emit(_phase)
	if hushmaster != null:
		_end_rig()
	var next: StringName = phases.advance()
	if next == &"":
		_finish_fight()
		return
	_enter_phase(next, false)


func _end_rig() -> void:
	if director != null:
		director.hijack_priority_tags = [] as Array[String]
		if director.hp_changed.is_connected(_on_hp_changed):
			director.hp_changed.disconnect(_on_hp_changed)
	for turret: WallTurret in turrets:
		if is_instance_valid(turret) and turret.hijackable != null and turret.hijackable.is_hijacked():
			turret.hijackable.end_hijack()
	boss_bar_hidden.emit()
	if director != null:
		director.boss_bar_hidden.emit()


# ---- the transition and phase 2 ----

## The BossTransition node for this room's robot stage, made the first time it is needed (the stage may not exist when the fight binds).
func _ensure_transition() -> BossTransition:
	if transition != null and is_instance_valid(transition):
		return transition
	if room == null or not room.has_method("get_robot_stage") or room.call("get_robot_stage") == null:
		return null
	var made: BossTransition = BossTransition.new()
	made.name = "BossTransition"
	room.add_child(made)
	if not made.bind(room):
		made.queue_free()
		return null
	transition = made
	transition.finished.connect(_on_transition_finished)
	return transition


func _run_transition() -> void:
	_ensure_transition()
	if transition == null:
		push_warning("BossFight: no BossTransition (the room has no robot stage); skipping to the next phase")
		_on_transition_finished()
		return
	if hushmaster != null:
		transition.kasp = hushmaster.find_child("kasp_mount", true, false) as Node3D
	if not transition.begin():
		push_warning("BossFight: the transition would not start; skipping to the next phase")
		_on_transition_finished()


func _on_transition_finished() -> void:
	phase_finished.emit(_phase)
	var next: StringName = phases.advance()
	if next == &"":
		_finish_fight()
		return
	_enter_phase(next, false)


## Phase 2, the Heap: a junk mech built from the yard fights Red's colossus. It is made at `mech_start` and walks to meet her; the
## retry point is `retry_phase2` (already docked, full health). Repair cells are placed in the bowl's smashable containers.
func _start_next_boss(id: StringName, retry: bool) -> void:
	_set_retry_point()
	if retry and _ensure_transition() != null:
		transition.start_docked()
	var file_name: String = str(phases.phase(id).get("data", MECH_FILE))
	heap_doc = CombatData.read_json(CombatData.DIR + "bosses/" + file_name)
	if heap_doc.is_empty() or room == null:
		return
	heap = JunkMech.create(heap_doc, seed_value)
	room.add_child(heap)
	var start_at: Node3D = marker(&"mech_start")
	if start_at != null:
		heap.global_transform = Transform3D(start_at.global_basis, start_at.global_position)
	heap.bar_changed.connect(func(hp: float, hp_max: float) -> void: _heap_bar(hp, hp_max))
	heap.pips_changed.connect(func(standing: int, total: int) -> void: _emit_pips(standing, total))
	heap.bark.connect(func(event_id: StringName) -> void: boss_event.emit(event_id))
	heap.shot.connect(func(shot_id: StringName) -> void: boss_event.emit(shot_id))
	heap.defeated.connect(_on_heap_defeated)
	if director != null:
		director.hijack_priority_tags = [] as Array[String]
	_show_heap_bar()
	_emit_pips(heap.plates_standing(), JunkMech.PLATE_IDS.size())
	if bool((heap_doc.get("pickups", {}) as Dictionary).get("enabled", false)):
		_place_repair_cells()


func _show_heap_bar() -> void:
	var list: Array[Dictionary] = []
	for phase_id_item: StringName in phases.ids():
		if not phases.is_scripted(phase_id_item):
			list.append({"id": String(phase_id_item), "name": phases.name_of(phase_id_item)})
	var hp: float = 0.0
	var hp_max: float = 1.0
	for item: BossPart in heap.parts():
		if item.kind == &"plate":
			hp += float(item.hp)
			hp_max += float(item.hp_max)
	hp_max = maxf(hp_max - 1.0, 1.0)
	_bar_info = {"name": str(heap_doc.get("name", "the Heap")).capitalize(), "hp": hp, "hp_max": hp_max, "phases": list, "phase": list.size() - 1}
	boss_bar_shown.emit(_bar_info)
	boss_phase_changed.emit(list.size() - 1, phases.name_of(_phase))
	if director != null:
		director.boss_bar_shown.emit(_bar_info)
		director.boss_phase_changed.emit(list.size() - 1, phases.name_of(_phase))


func _heap_bar(hp: float, hp_max: float) -> void:
	boss_hp_changed.emit(hp, hp_max)
	if director != null:
		director.boss_hp_changed.emit(hp, hp_max)


func _on_heap_defeated() -> void:
	phase_finished.emit(_phase)
	boss_bar_hidden.emit()
	if director != null:
		director.boss_bar_hidden.emit()
	var ending: Dictionary = phases.ending()
	var flag: String = str(ending.get("sets_flag", ""))
	var state: Node = get_node_or_null("/root/GameState")
	if not flag.is_empty() and state != null and state.has_method("set_flag"):
		state.call("set_flag", flag)
	boss_event.emit(StringName(str(ending.get("scene", ""))))
	_finish_fight()


# ---- repair cells (Ross: "all recommended", so they are on) ----

## Two containers in each of the bowl's clusters hold a green repair cell that heals 12 percent of the colossus. The room's robot
## yard supplies the smashable props; the cells are picked evenly round the bowl so every part of it has some.
func _place_repair_cells() -> void:
	repair_cells.clear()
	var stage_node: Object = room.call("get_robot_stage") if room.has_method("get_robot_stage") else null
	var yard: Object = stage_node.get("yard") if stage_node != null and "yard" in stage_node else null
	if yard == null or not "props" in yard:
		return
	var containers: Array[SmashProp] = []
	for prop: SmashProp in (yard.get("props") as Array):
		if is_instance_valid(prop) and str(prop.kind).contains("container"):
			containers.append(prop)
	var spec: Dictionary = (heap_doc.get("pickups", {}) as Dictionary).get("repair_cell", {}) as Dictionary
	var wanted: int = int(spec.get("per_cluster", 2)) * int(spec.get("clusters", 8))
	containers.sort_custom(func(a: SmashProp, b: SmashProp) -> bool:
		return atan2(a.global_position.x, a.global_position.z) < atan2(b.global_position.x, b.global_position.z))
	var step: float = maxf(float(containers.size()) / float(maxi(wanted, 1)), 1.0)
	var index: float = 0.0
	while int(index) < containers.size() and repair_cells.size() < wanted:
		var prop: SmashProp = containers[int(index)]
		var entry: Dictionary = {"prop": prop, "position": prop.global_position, "taken": false, "released": false}
		repair_cells.append(entry)
		prop.smashed.connect(func(_smashed: SmashProp) -> void: _release_cell(entry))
		_mark_container(prop, spec)
		index += step


## A green stripe on the container, so Ross can tell which ones hold a cell.
func _mark_container(prop: SmashProp, spec: Dictionary) -> void:
	var stripe: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(prop.box_size.x * 1.02, maxf(prop.box_size.y * 0.12, 0.3), prop.box_size.z * 1.02)
	stripe.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var colour: Color = Color.html(str(spec.get("glow", "#7dffb0")))
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stripe.material_override = material
	stripe.position = prop.box_centre + Vector3.UP * prop.box_size.y * 0.3
	prop.add_child(stripe)


func _release_cell(entry: Dictionary) -> void:
	if bool(entry["released"]):
		return
	entry["released"] = true
	var spec: Dictionary = (heap_doc.get("pickups", {}) as Dictionary).get("repair_cell", {}) as Dictionary
	var glow: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 2.0
	mesh.height = 4.0
	glow.mesh = mesh
	var colour: Color = Color.html(str(spec.get("glow", "#7dffb0")))
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = material
	room.add_child(glow)
	glow.global_position = (entry["position"] as Vector3) + Vector3.UP * 3.0
	entry["node"] = glow


## Picks up any released cell the colossus is standing on: heals `heal_frac_of_colossus` of her health.
func _tick_repair_cells() -> void:
	if player == null or heap == null:
		return
	var spec: Dictionary = (heap_doc.get("pickups", {}) as Dictionary).get("repair_cell", {}) as Dictionary
	for entry: Dictionary in repair_cells:
		if not bool(entry["released"]) or bool(entry["taken"]):
			continue
		var gap: float = Vector2(player.global_position.x - (entry["position"] as Vector3).x, player.global_position.z - (entry["position"] as Vector3).z).length()
		if gap > player.radius_m + 2.5:
			continue
		entry["taken"] = true
		var heal: int = int(roundf(float(player.hp_max) * float(spec.get("heal_frac_of_colossus", 0.12))))
		player.hp = mini(player.hp + heal, player.hp_max)
		director.hp_changed.emit(player.actor_id, player.hp, player.hp_max)
		if entry.has("node") and is_instance_valid(entry["node"]):
			(entry["node"] as Node).queue_free()
		boss_event.emit(&"repair_cell_taken")


func _finish_fight() -> void:
	fight_finished.emit()


# ---- the boss bar ----

func _show_bar() -> void:
	var list: Array[Dictionary] = []
	for id: StringName in phases.ids():
		if not phases.is_scripted(id):
			list.append({"id": String(id), "name": phases.name_of(id)})
	var fighting: int = 0
	for index: int in range(list.size()):
		if StringName(str(list[index]["id"])) == _phase:
			fighting = index
	var hp: float = float(hushmaster.hp) if hushmaster != null else 1.0
	var hp_max: float = float(hushmaster.hp_max) if hushmaster != null else 1.0
	_bar_info = {"name": str(doc.get("name", "")).capitalize() if not str(doc.get("name", "")).is_empty() else "Boss",
			"hp": hp, "hp_max": hp_max, "phases": list, "phase": fighting}
	boss_bar_shown.emit(_bar_info)
	boss_phase_changed.emit(fighting, phases.name_of(_phase))
	if director != null:
		director.boss_bar_shown.emit(_bar_info)
		director.boss_phase_changed.emit(fighting, phases.name_of(_phase))


# ---- hints, the clock ----

func tick(delta: float) -> void:
	_tick_repair_cells()
	if hushmaster == null or not is_instance_valid(hushmaster) or phases == null or phases.current() != _phase:
		return
	_age_s += delta
	if director != null:
		# the director carries the bar signals too (the HUD's fallback when the host has no get_boss_fight)
		pass
	var hints: Dictionary = (phases.phase(_phase).get("events", {}) as Dictionary).get("hints", {}) as Dictionary
	for key: Variant in hints.keys():
		var id: String = str(key)
		if _hints_given.has(id):
			continue
		var rule: Dictionary = hints[key] as Dictionary
		if rule.has("after_s") and _age_s >= float(rule["after_s"]) and _hint_unless_ok(str(rule.get("unless", ""))):
			_hints_given[id] = true
			boss_event.emit(StringName(id))
		elif rule.has("on") and _hint_trigger(id, str(rule["on"])):
			_hints_given[id] = true
			boss_event.emit(StringName(id))


func _hint_unless_ok(unless: String) -> bool:
	match unless:
		"any_relay_broken":
			return hushmaster.pairs_lost() == 0
		"any_turret_hijacked":
			for turret: WallTurret in turrets:
				if is_instance_valid(turret) and turret.hijackable != null and turret.hijackable.is_hijacked():
					return false
			return true
	return true


func _hint_trigger(_id: String, on: String) -> bool:
	match on:
		"first_quiet_hours":
			return hushmaster.is_quiet_humming()
		"first_drone_drop_with_two_alive_after_6s":
			return _first_drop_seen_s >= 0.0 and _age_s - _first_drop_seen_s >= 6.0 and hushmaster.drones_alive() >= 2
	return false


# ---- helpers ----

## A scene node by name anywhere under the room (the arena's named markers).
func marker(node_name: StringName) -> Node3D:
	return room.find_child(String(node_name), true, false) as Node3D if room != null else null


## Test helper: ends the current phase as if it had been won.
func skip_phase() -> void:
	if hushmaster != null and _phase == &"rig":
		_on_rig_defeated(&"skipped")
