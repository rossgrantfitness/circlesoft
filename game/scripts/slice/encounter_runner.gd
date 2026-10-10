class_name EncounterRunner
extends Node
## Runs the junkyard's fights (data/slice/encounters.json, the Combat Designer's mixes) in an ActionRoom, using the markers the
## Level Designer put in the scene:
##   Encounters/<id>            a Node3D at the trigger centre
##   Encounters/<id>/<wave>_<enemy>_<i>   Marker3D, metadata enemy, count, spread_m, wave, entrance: where that spawn entry stands
##   Fixtures/<fixture id>      Marker3D (y = mount height) for wall turrets
##   Shutters/*                 raised StaticBody3Ds the Stand drops behind Red
## encounters.json says WHO, HOW MANY, WHEN and with what tuning; a marker, when there is one, says WHERE (the data's `at` is the
## fallback). Spawn entries and markers are paired by wave and enemy, in order.
##
## Triggers: room_enter (at once), notice / enter_zone (Red within range_m of the centre). "regular" encounters begin again every
## time the room loads; "sticky" ones set `start_flag` when they begin and `clear_flag` when done, and a cleared one never runs
## again. While a fight is on its `max_attackers` caps the director's attack tokens. `hp_mult` scales every spawned enemy's health;
## `tune` and `state` are stored on the enemy (`encounter_tune`, `encounter_state` metadata) and given to its `apply_tune(dict)` /
## `apply_state(name)` when it has them. Turret fixtures spawn when the fight begins and may shoot from then (`online:
## "on_trigger"`) or once a named wave has spawned (`online: {"after_wave": w}`). A wave's `warning` bark goes out through
## `wave_warning(encounter, bark_id)` (the RadioBarks runner plays it).

signal started(encounter_id: String)
signal wave_spawned(encounter_id: String, wave_id: String, enemies: Array)
signal wave_warning(encounter_id: String, bark_id: String)
signal cleared(encounter_id: String)

const DATA_ID: String = "slice/encounters"
const SHUTTER_DROP_S: float = 0.5
const SPAWN_Y: float = 0.1

var room: Node3D = null
var hero: Node3D = null
## Off in tests that call tick() by hand.
var manual_ticks: bool = false

var _doc: Dictionary = {}
var _records: Array[Dictionary] = []
var _clock: float = 0.0
var _shutters: Array[Dictionary] = []
var _tokens_before: int = -1
var _active_cap: String = ""


## `defs` replaces encounters.json (tests). Returns how many encounters this room has.
func setup(for_room: Node3D, defs: Dictionary = {}) -> int:
	room = for_room
	hero = room.get("hero") as Node3D
	_doc = defs if not defs.is_empty() else DataDB.get_dict(DATA_ID).duplicate(true)
	_records.clear()
	var level: Node = _level()
	var room_id: String = str(room.get("room_id"))
	for id: String in (_doc.get("encounters", {}) as Dictionary):
		var def: Dictionary = (_doc["encounters"] as Dictionary)[id]
		if str(def.get("room", "")) != room_id:
			continue
		_records.append(_make_record(id, def, level))
	_collect_shutters(level)
	for record: Dictionary in _records:
		if _is_cleared_for_good(record):
			record["state"] = "cleared"
			_set_shutters(false, true)
	set_physics_process(not manual_ticks)
	return _records.size()


func encounter_ids() -> Array[String]:
	var ids: Array[String] = []
	for record: Dictionary in _records:
		ids.append(str(record["id"]))
	return ids


## "waiting", "running" or "cleared".
func state_of(encounter_id: String) -> String:
	var record: Dictionary = _record(encounter_id)
	return str(record.get("state", ""))


## The living enemies of one encounter (fixtures excluded).
func enemies_of(encounter_id: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var record: Dictionary = _record(encounter_id)
	for wave_id: String in (record.get("alive", {}) as Dictionary):
		for node: Node3D in (record["alive"][wave_id] as Array):
			if _is_alive(node):
				out.append(node)
	return out


func fixtures_of(encounter_id: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node: Variant in (_record(encounter_id).get("fixtures", []) as Array):
		if is_instance_valid(node):
			out.append(node as Node3D)
	return out


func shutters_down() -> bool:
	for shutter: Dictionary in _shutters:
		if bool(shutter["down"]):
			return true
	return false


func _physics_process(delta: float) -> void:
	tick(delta)


## One step of `delta` seconds.
func tick(delta: float) -> void:
	_clock += delta
	if hero == null or not is_instance_valid(hero):
		hero = room.get("hero") as Node3D if room != null else null
	for record: Dictionary in _records:
		match str(record["state"]):
			"waiting":
				if _triggered(record):
					_begin(record)
			"running":
				_run(record)


# ---- building the records ----

func _level() -> Node:
	var level: Variant = room.get("level")
	return level as Node if level != null else room


func _make_record(id: String, def: Dictionary, level: Node) -> Dictionary:
	var node: Node3D = level.get_node_or_null("Encounters/%s" % id) as Node3D
	var trigger: Dictionary = def.get("trigger", {}) as Dictionary
	var centre: Vector3 = Vector3.ZERO
	if trigger.has("centre"):
		var at: Array = trigger["centre"] as Array
		centre = Vector3(float(at[0]), 0.0, float(at[1]))
	elif node != null:
		centre = node.global_position
	return {
		"id": id, "def": def, "node": node, "centre": centre, "state": "waiting",
		"waves": EncounterWaves.from_defs(def.get("waves", []) as Array, _doc.get("rules", {}) as Dictionary),
		"alive": {}, "fixtures": [], "fixture_online": {},
		"markers": _markers(node),
	}


## The markers under an encounter node, by "<wave>/<enemy>": [{pos, count, spread_m, entrance}] in scene order.
func _markers(node: Node3D) -> Dictionary:
	var out: Dictionary = {}
	if node == null:
		return out
	for child: Node in node.get_children():
		var marker: Marker3D = child as Marker3D
		if marker == null or not marker.has_meta("enemy"):
			continue
		var key: String = "%s/%s" % [str(marker.get_meta("wave", "w1")), str(marker.get_meta("enemy"))]
		if not out.has(key):
			out[key] = []
		(out[key] as Array).append({"pos": marker.global_position, "count": int(marker.get_meta("count", 1)),
				"spread_m": float(marker.get_meta("spread_m", 0.0)), "entrance": str(marker.get_meta("entrance", ""))})
	return out


func _collect_shutters(level: Node) -> void:
	_shutters.clear()
	var holder: Node = level.get_node_or_null("Shutters")
	if holder == null:
		return
	for child: Node in holder.get_children():
		if child is Node3D:
			_shutters.append({"node": child, "home_y": (child as Node3D).position.y, "down": false})


func _record(encounter_id: String) -> Dictionary:
	for record: Dictionary in _records:
		if str(record["id"]) == encounter_id:
			return record
	return {}


# ---- triggers and flags ----

func _is_cleared_for_good(record: Dictionary) -> bool:
	var def: Dictionary = record["def"]
	return str(def.get("kind", "regular")) == "sticky" and _flag(str(def.get("clear_flag", "")))


func _flag(flag_id: String) -> bool:
	if flag_id.is_empty():
		return false
	var state: Node = _game_state()
	return state != null and bool(state.call("get_flag", flag_id))


func _set_flag(flag_id: String) -> void:
	var state: Node = _game_state()
	if state != null and not flag_id.is_empty():
		state.call("set_flag", flag_id, true)


func _game_state() -> Node:
	var state: Variant = room.get("game_state") if room != null else null
	if state is Node and is_instance_valid(state):
		return state as Node
	return get_node_or_null("/root/GameState")


func _triggered(record: Dictionary) -> bool:
	var trigger: Dictionary = (record["def"] as Dictionary).get("trigger", {}) as Dictionary
	match str(trigger.get("type", "room_enter")):
		"room_enter":
			return true
		"notice", "enter_zone":
			if hero == null or not is_instance_valid(hero):
				return false
			var flat: Vector3 = hero.global_position - (record["centre"] as Vector3)
			flat.y = 0.0
			return flat.length() <= float(trigger.get("range_m", 8.0))
	return false


# ---- running a fight ----

func _begin(record: Dictionary) -> void:
	var def: Dictionary = record["def"]
	record["state"] = "running"
	(record["waves"] as EncounterWaves).begin(_clock)
	_set_flag(str(def.get("start_flag", "")))
	var trigger: Dictionary = def.get("trigger", {}) as Dictionary
	if str(trigger.get("shutters", "")) == "drop_behind":
		_set_shutters(true)
	_cap_attackers(int(def.get("max_attackers", 0)))
	_spawn_fixtures(record)
	started.emit(str(record["id"]))
	_run(record)


func _run(record: Dictionary) -> void:
	var plan: EncounterWaves = record["waves"]
	var alive: Dictionary = _alive_counts(record)
	var red_x: float = hero.global_position.x if hero != null and is_instance_valid(hero) else 0.0
	for event: Dictionary in plan.tick(_clock, alive, red_x):
		if str(event["type"]) == "warn":
			wave_warning.emit(str(record["id"]), str(event["bark"]))
		else:
			_spawn_wave(record, str(event["wave"]))
	_update_fixtures(record)
	if plan.all_started() and _alive_total(record) == 0 and not (record["waves"] as EncounterWaves).wave_ids().is_empty():
		_finish(record)


func _finish(record: Dictionary) -> void:
	var def: Dictionary = record["def"]
	record["state"] = "cleared"
	if str(def.get("kind", "regular")) == "sticky":
		_set_flag(str(def.get("clear_flag", "")))
	_set_shutters(false)
	_cap_attackers(0)
	cleared.emit(str(record["id"]))


func _alive_counts(record: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for wave_id: String in (record["alive"] as Dictionary):
		var n: int = 0
		for node: Node3D in (record["alive"][wave_id] as Array):
			if _is_alive(node):
				n += 1
		counts[wave_id] = n
	return counts


func _alive_total(record: Dictionary) -> int:
	var total: int = 0
	for n: Variant in _alive_counts(record).values():
		total += int(n)
	return total


static func _is_alive(node: Variant) -> bool:
	return node != null and is_instance_valid(node) and not bool((node as Node).get("dead"))


func _spawn_wave(record: Dictionary, wave_id: String) -> void:
	var def: Dictionary = record["def"]
	var plan: EncounterWaves = record["waves"]
	var spawned: Array[Node3D] = []
	var used: Dictionary = {}
	for raw: Variant in plan.wave_def(wave_id).get("spawn", []) as Array:
		var entry: Dictionary = raw as Dictionary
		var kind: String = str(entry.get("enemy", ""))
		var key: String = "%s/%s" % [wave_id, kind]
		var nth: int = int(used.get(key, 0))
		used[key] = nth + 1
		var marker: Dictionary = {}
		var found: Array = (record["markers"] as Dictionary).get(key, []) as Array
		if nth < found.size():
			marker = found[nth]
		var count: int = int(entry.get("count", marker.get("count", 1)))
		var spread: float = float(entry.get("spread_m", marker.get("spread_m", 0.0)))
		var centre: Vector3 = _spawn_centre(entry, marker)
		for i: int in count:
			var enemy: Node3D = room.call("spawn_enemy", kind, _spread_point(centre, spread, i, count)) as Node3D
			if enemy == null:
				continue
			_prepare(enemy, def, entry)
			spawned.append(enemy)
	if not (record["alive"] as Dictionary).has(wave_id):
		record["alive"][wave_id] = []
	(record["alive"][wave_id] as Array).append_array(spawned)
	wave_spawned.emit(str(record["id"]), wave_id, spawned)


func _spawn_centre(entry: Dictionary, marker: Dictionary) -> Vector3:
	if marker.has("pos"):
		return marker["pos"] as Vector3
	var at: Array = entry.get("at", [0.0, 0.0]) as Array
	return Vector3(float(at[0]), SPAWN_Y, float(at[1]))


## Spreads `count` enemies round a centre on a spiral, so the same data always gives the same picture.
static func _spread_point(centre: Vector3, spread_m: float, index: int, count: int) -> Vector3:
	if count <= 1 or spread_m <= 0.0:
		return centre
	var radius: float = spread_m * sqrt((float(index) + 0.5) / float(count))
	var angle: float = float(index) * 2.399963
	return centre + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _prepare(enemy: Node3D, def: Dictionary, entry: Dictionary) -> void:
	var hp_mult: float = float(def.get("hp_mult", 1.0))
	if hp_mult != 1.0 and "hp_max" in enemy:
		enemy.set("hp_max", maxi(int(round(float(enemy.get("hp_max")) * hp_mult)), 1))
		enemy.set("hp", int(enemy.get("hp_max")))
	var tune: Dictionary = entry.get("tune", {}) as Dictionary
	if not tune.is_empty():
		enemy.set_meta("encounter_tune", tune)
		if enemy.has_method("apply_tune"):
			enemy.call("apply_tune", tune)
	var state: String = str(entry.get("state", ""))
	if not state.is_empty():
		enemy.set_meta("encounter_state", state)
		if enemy.has_method("apply_state"):
			enemy.call("apply_state", state)
	enemy.set_meta("encounter_id", str(def.get("name", "")))


# ---- fixtures: turrets ----

func _spawn_fixtures(record: Dictionary) -> void:
	var def: Dictionary = record["def"]
	var level: Node = _level()
	for raw: Variant in def.get("fixtures", []) as Array:
		var entry: Dictionary = raw as Dictionary
		if str(entry.get("kind", "")) != "" or str(entry.get("enemy", "")) != "wall_turret":
			continue                    # the drone line is a hack target the scene already carries
		var at: Vector3 = Vector3.ZERO
		var yaw: float = 0.0
		var marker: Marker3D = level.get_node_or_null("Fixtures/%s" % str(entry.get("id", ""))) as Marker3D
		if marker != null:
			at = marker.global_position
			yaw = marker.global_rotation.y
		else:
			var spot: Array = entry.get("at", [0.0, 0.0]) as Array
			at = Vector3(float(spot[0]), float(entry.get("up_m", 3.0)), float(spot[1]))
		var turret: Node3D = room.call("spawn_enemy", "wall_turret", at) as Node3D
		if turret == null:
			continue
		turret.rotation.y = yaw
		_prepare(turret, def, entry)
		var online: Variant = entry.get("online", "on_trigger")
		if "attacks_allowed" in turret:
			turret.set("attacks_allowed", online is String and str(online) == "on_trigger")
		turret.set_meta("fixture_id", str(entry.get("id", "")))
		turret.set_meta("fixture_online", online)
		(record["fixtures"] as Array).append(turret)


func _update_fixtures(record: Dictionary) -> void:
	var plan: EncounterWaves = record["waves"]
	for node: Variant in record["fixtures"] as Array:
		if not is_instance_valid(node):
			continue
		var online: Variant = (node as Node).get_meta("fixture_online", "on_trigger")
		if online is Dictionary and plan.has_started(str((online as Dictionary).get("after_wave", ""))) and "attacks_allowed" in node:
			(node as Node).set("attacks_allowed", true)


# ---- shutters and the attack cap ----

func _set_shutters(down: bool, instant: bool = false) -> void:
	for shutter: Dictionary in _shutters:
		var node: Node3D = shutter["node"] as Node3D
		if not is_instance_valid(node):
			continue
		shutter["down"] = down
		var target_y: float = 0.0 if down else float(shutter["home_y"])
		if instant or not is_inside_tree():
			node.position.y = target_y
		else:
			var tween: Tween = create_tween()
			tween.tween_property(node, "position:y", target_y, SHUTTER_DROP_S)


func _cap_attackers(cap: int) -> void:
	var director: Variant = room.get("director") if room != null else null
	if director == null or not "tokens" in director or director.get("tokens") == null:
		return
	var tokens: Object = director.get("tokens") as Object
	if cap > 0:
		if _tokens_before < 0:
			_tokens_before = int(tokens.get("max_attackers"))
		tokens.set("max_attackers", cap)
	elif _tokens_before >= 0:
		tokens.set("max_attackers", _tokens_before)
		_tokens_before = -1
