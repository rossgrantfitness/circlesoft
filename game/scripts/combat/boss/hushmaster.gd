class_name Hushmaster
extends CombatActor
## Kasp's walker, phase 1 of the fight (docs/slice/boss_design.md, data/combat/bosses/hushmaster.json phase `rig`, moves.json
## set `hushmaster`). A CombatActor that walks toward Red on its eight legs, runs the data's four patterns one at a time
## (the BossBrain picks), and is taken apart with hacks:
##   * four relay BossParts, one per leg pair; breaking one folds its pair, the body sags and leans, and the next attack waits;
##   * the dish BossPart on the roof (Quiet Hours; it comes down within reach while the dish works);
##   * all four pairs down: the rig topples, drones switch off, and after 2.6 s the hack button offers "Jack in";
##   * Jack in: a big hit (60 percent of its health) and the phase is over (`defeated`).
## The sword does 30 percent damage while any pair stands (it still fills the battery: that is its job in this fight).
## Moves, hit shapes (ring, beam) and timings are all data; this class only runs them on the boss's own combat clock.
##
## Everything per frame is in tick(delta) so a test can step it by hand.

signal pattern_started(pattern_id: StringName)
signal pattern_finished(pattern_id: StringName)
signal pair_dropped(pair: StringName, pairs_lost: int)
signal quiet_hours_started
signal quiet_hours_cut(by: String)             ## "before_lock" or "during_lock"
signal dish_broke
signal toppled
signal jack_in_ready
signal jack_in_started
signal defeated(reason: StringName)             ## the phase is over: "jack_in"
signal bark(event_id: StringName)                ## a bark id from the data's `events` (the Writer's words)

enum State { FREE, PATTERN, CHAIN_WAIT, REACT, TOPPLING, TOPPLED, JACKING, DONE }

const MODEL_PATH: String = "res://art/placeholder/bosses/hushmaster.glb"
const DRONE_SCENE: String = "res://scenes/actors/enemies/signals_drone.tscn"
const PAIRS: Array[StringName] = [&"fl", &"fr", &"bl", &"br"]
## Where each leg's foot lands, in the body's own space (from the blockout's hip and foot numbers, make_bosses.py).
const FOOT_X: float = 5.6
const FOOT_Z: Dictionary = {1: 3.35, 2: 1.1}
const PAIR_SIGN: Dictionary = {&"fl": Vector2(1, 1), &"fr": Vector2(-1, 1), &"bl": Vector2(1, -1), &"br": Vector2(-1, -1)}
const DISH_BASE_LOCAL: Vector3 = Vector3(0.0, 0.0, -1.3)
const FOLD_RAD: float = 1.05

var rules: Dictionary = {}
var phase: Dictionary = {}
var body: Dictionary = {}
var brain: BossBrain = null
var runner: MoveRunner = null
var state: State = State.FREE
var rng_seed: int = 1
## Where the drone hatches are (world positions), set by the BossFight from the arena's markers.
var hatches: Array[Vector3] = []
var drone_scene_path: String = DRONE_SCENE

var _data_tags: PackedStringArray = PackedStringArray()
var _moves: MoveSet = null
var _parts: Dictionary = {}                  # part id -> BossPart
var _pairs_down: Dictionary = {}             # pair -> true
var _model: Node3D = null
var _fx_root: Node3D = null
var _age_ms: float = 0.0
var _walking: bool = false
var _pattern: Dictionary = {}                # the pick being run
var _repeat_left: int = 0
var _chain_wait_ms: float = 0.0
var _react_ms: float = 0.0
var _move_start_usec: int = 0
var _stomp_leg: Vector2 = Vector2.ZERO       # which leg (pair sign, number) is up: for the visual
var _stomp_pair: StringName = &""
var _stomp_legs_used: Array[String] = []
var _marker: Vector3 = Vector3.ZERO
var _marker_locked: bool = false
var _fan_start: float = 0.0
var _fan_dir: float = 1.0
var _fan_deg: float = 80.0
var _hatch_used: Vector3 = Vector3.ZERO
var _drones_spawned: bool = false
var _drones: Array[ActionEnemy] = []
var _quiet_active: bool = false              # the dish is humming (before the lock lands)
var _quiet_hits: int = 0
var _quiet_locked: bool = false              # our lock is running
var _quiet_lock_applied: bool = false
var _sword_mult: float = 0.3
var _finish_when_toppled: bool = false
var _topple_ms: float = 0.0
var _dish_raised_y: float = 3.4
var _dish_lowered_y: float = 2.2
var _dish_lowered: bool = false
var _sag: float = 0.0
var _sag_target: float = 0.0
var _lean: Vector2 = Vector2.ZERO
var _lean_target: Vector2 = Vector2.ZERO
var _fx_marker: MeshInstance3D = null
var _fx_hatch: MeshInstance3D = null
var _fx_ring: MeshInstance3D = null
var _fx_edges: Array[MeshInstance3D] = []
var _ring_index: int = -1
var _first_relay_seen: bool = false


## Builds one from the boss file: `phase` is the `rig` entry of `phases`, `rules` the file's `rules`.
static func create(boss_rules: Dictionary, rig_phase: Dictionary, seed_value: int = 1) -> Hushmaster:
	var out: Hushmaster = Hushmaster.new()
	out.rules = boss_rules
	out.phase = rig_phase
	out.rng_seed = seed_value
	out.name = "Hushmaster"
	return out


func _ready() -> void:
	body = phase.get("body", {}) as Dictionary
	actor_id = &"hushmaster"
	team = &"enemy"
	move_set_id = StringName(str(body.get("move_set", "hushmaster")))
	hp_max = int(body.get("hp", 500))
	hp = hp_max
	height_m = float(body.get("height_m", 3.5))
	radius_m = float(body.get("radius_m", 1.5))
	weight = 100.0
	launchable = false
	for tag: Variant in body.get("tags", []) as Array:
		_data_tags.append(str(tag))
	_sword_mult = float((body.get("sword_damage_mult", {}) as Dictionary).get("upright", 0.3))
	_moves = MoveSet.load_default()
	runner = MoveRunner.create(_moves, move_set_id)
	brain = BossBrain.from_data(phase, rules, rng_seed)
	super._ready()
	get_hitbox().origin_resolver = Callable(self, "origin_of")
	_build_body_shape()
	_build_model()
	_build_parts()
	_build_fx()
	set_physics_process(true)
	var director: CombatDirector = find_director()
	if director != null:
		brain.start(clock.now_ms())
	var dish_spec: Dictionary = (phase.get("parts", {}) as Dictionary).get("dish", {}) as Dictionary
	_dish_raised_y = float(dish_spec.get("height_m", 3.4))
	_dish_lowered_y = float(dish_spec.get("lowered_height_m", 2.2))
	_place_dish()


func _physics_process(delta: float) -> void:
	tick(delta)


# ---- what others ask ----

func tags() -> PackedStringArray:
	return _data_tags


func pairs_lost() -> int:
	return _pairs_down.size()


func pairs_standing() -> int:
	return PAIRS.size() - _pairs_down.size()


func pair_is_down(pair: StringName) -> bool:
	return _pairs_down.has(pair)


func part(id: StringName) -> BossPart:
	return _parts.get(id, null)


func parts() -> Array[BossPart]:
	var out: Array[BossPart] = []
	for item: Variant in _parts.values():
		out.append(item as BossPart)
	return out


func relay_of(pair: StringName) -> BossPart:
	return _parts.get(StringName("relay_%s" % pair), null)


func current_pattern() -> StringName:
	return StringName(str(_pattern.get("pattern", ""))) if state == State.PATTERN or state == State.CHAIN_WAIT else &""


func is_upright() -> bool:
	return state != State.TOPPLING and state != State.TOPPLED and state != State.JACKING and state != State.DONE


func drones_alive() -> int:
	var count: int = 0
	for drone: ActionEnemy in _drones:
		if is_instance_valid(drone) and not drone.dead:
			count += 1
	return count


func drones() -> Array[ActionEnemy]:
	var out: Array[ActionEnemy] = []
	for drone: ActionEnemy in _drones:
		if is_instance_valid(drone) and not drone.dead:
			out.append(drone)
	return out


## Where Red plugs in (the dish's service port), world space.
func jack_in_point() -> Vector3:
	var port: Node3D = _model.find_child("dish_port", true, false) as Node3D if _model != null else null
	return port.global_position if port != null else global_position


## The marker position the stomp is aimed at right now (flat), and whether it has locked.
func stomp_marker() -> Vector3:
	return _marker


func stomp_locked() -> bool:
	return _marker_locked


func fan_yaws() -> Vector2:
	return Vector2(_fan_start, _fan_start + _fan_dir * deg_to_rad(_fan_deg))


func quiet_locked() -> bool:
	return _quiet_locked


func is_quiet_humming() -> bool:
	return _quiet_active


## Hitbox origin names from moves.json: where a hitbox hangs.
func origin_of(origin_name: StringName) -> Variant:
	var floor_y: float = global_position.y
	match origin_name:
		&"leg_foot":
			return Transform3D(Basis.IDENTITY, Vector3(_marker.x, floor_y, _marker.z))
		&"dish":
			var at: Vector3 = global_transform * DISH_BASE_LOCAL
			return Transform3D(Basis.IDENTITY, Vector3(at.x, floor_y, at.z))
	return null


# ---- the frame ----

func tick(delta: float) -> void:
	var director: CombatDirector = find_director()
	if director == null:
		clock.step(int(roundf(delta * 1000000.0)), 1.0)
	var dt: float = local_delta(delta)
	if dt <= 0.0:
		return
	_age_ms += dt * 1000.0
	for item: BossPart in parts():
		item.tick(dt)
	match state:
		State.FREE:
			_tick_free(dt, director)
		State.PATTERN:
			_tick_pattern(dt)
		State.CHAIN_WAIT:
			_chain_wait_ms -= dt * 1000.0
			if _chain_wait_ms <= 0.0:
				_begin_stomp_repeat()
		State.REACT:
			_react_ms -= dt * 1000.0
			if _react_ms <= 0.0:
				state = State.FREE
		State.TOPPLING, State.JACKING:
			_tick_scripted(dt)
		State.TOPPLED:
			pass
	_tick_quiet()
	get_hitbox().tick(dt)
	_update_visuals(dt)
	velocity.y = -1.0
	slide_scaled(dt / delta if delta > 0.0 else 1.0)


func _tick_free(dt: float, director: CombatDirector) -> void:
	var red: CombatActor = director.player() if director != null else null
	if red != null:
		var to_red: Vector3 = red.global_position - global_position
		to_red.y = 0.0
		var dist: float = to_red.length()
		var walk: Dictionary = body.get("walk", {}) as Dictionary
		if dist > float(walk.get("walk_when_farther_than_m", 8.0)):
			_walking = true
		elif dist <= float(walk.get("toward_red_until_m", 6.0)):
			_walking = false
		if dist > 0.1:
			_turn_toward(to_red / dist, dt)
		var speed: float = float(body.get("move_speed_mps", 2.4)) if _walking else 0.0
		var forward_flat: Vector3 = forward()
		velocity.x = forward_flat.x * speed
		velocity.z = forward_flat.z * speed
	var pick: Dictionary = brain.step(clock.now_ms(), _view(red))
	if not pick.is_empty():
		_start_pattern(pick)


func _turn_toward(direction: Vector3, dt: float) -> void:
	var wanted: float = atan2(direction.x, direction.z)
	rotation.y = rotate_toward(rotation.y, wanted, deg_to_rad(float(body.get("turn_rate_deg_per_s", 90.0))) * dt)


func _view(red: CombatActor) -> Dictionary:
	var director: CombatDirector = find_director()
	var dist: float = INF
	if red != null:
		dist = Vector2(red.global_position.x - global_position.x, red.global_position.z - global_position.z).length()
	var alive: Dictionary = {}
	for key: Variant in _parts.keys():
		alive[String(key)] = not (_parts[key] as BossPart).dead
	return {"dist_m": dist, "pairs_lost": pairs_lost(), "pairs_standing": pairs_standing(),
			"parts_alive": alive, "drones_alive": drones_alive(), "since_start_s": _age_ms / 1000.0,
			"hacks_locked": director != null and director.hacks_locked()}


# ---- patterns ----

## Starts a pattern right now, skipping the brain's choice (bots and tests: "give me the Dish Sweep"). False if the boss is busy
## or has no such pattern.
func force_pattern(pattern_id: StringName) -> bool:
	if state != State.FREE and state != State.REACT:
		return false
	var director: CombatDirector = find_director()
	var pick: Dictionary = brain.make_pick(pattern_id, _view(director.player() if director != null else null))
	if pick.is_empty():
		return false
	state = State.FREE
	_start_pattern(pick)
	return true


func _start_pattern(pick: Dictionary) -> void:
	_pattern = pick
	_repeat_left = int(pick.get("repeat", 1)) - 1
	_stomp_legs_used.clear()
	brain.begin(StringName(str(pick["pattern"])), clock.now_ms())
	state = State.PATTERN
	velocity = Vector3.ZERO
	pattern_started.emit(StringName(str(pick["pattern"])))
	_begin_move(StringName(str(pick["move"])))


func _begin_move(move_id: StringName) -> void:
	if not runner.start(move_id, clock.now_usec()):
		push_warning("Hushmaster: unknown move %s" % move_id)
		_end_pattern()
		return
	_move_start_usec = clock.now_usec()
	_drones_spawned = false
	_marker_locked = false
	match str(_pattern.get("pattern", "")):
		"leg_stomp":
			_setup_stomp()
		"dish_sweep":
			_setup_sweep()
		"drone_drop":
			_setup_drop()
		"quiet_hours":
			_setup_quiet()
	_handle_events(runner.step(_move_start_usec))


func _tick_pattern(dt: float) -> void:
	if not runner.is_busy():
		_end_pattern()
		return
	var ms: float = runner.elapsed_ms()
	match str(_pattern.get("pattern", "")):
		"leg_stomp":
			_tick_stomp(ms)
		"drone_drop":
			_tick_drop(ms)
		"quiet_hours":
			pass
		"dish_sweep":
			_tick_sweep(ms)
	_handle_events(runner.step(clock.now_usec()))
	if runner.is_busy():
		return
	_end_pattern()


func _handle_events(events: Array[Dictionary]) -> void:
	var director: CombatDirector = find_director()
	for event: Dictionary in events:
		match String(event["type"]):
			"telegraph":
				if director != null:
					director.telegraph(self, runner.current_move(), _move_start_usec + int(float(runner.data().get("impact_ms", 0.0)) * 1000.0),
							StringName(str(runner.data().get("telegraph_kind", ""))))
			"swing":
				if director != null:
					director.notify_move_started(self, runner.current_move(), event.get("swing", {}))
			"hitbox_on":
				_activate_box(event)
			"hitbox_off":
				get_hitbox().deactivate(int(event["index"]))
				if int(event["index"]) == _ring_index:
					_ring_index = -1
			"interrupted":
				get_hitbox().clear()
			"done":
				get_hitbox().clear()
				_ring_index = -1


func _activate_box(event: Dictionary) -> void:
	var box: Dictionary = (event["box"] as Dictionary).duplicate()
	box["index"] = int(event["index"])
	var attack: Dictionary = runner.attack_data()
	if str(box.get("shape", "")) == "beam":
		box["sweep_deg"] = _fan_deg
	get_hitbox().activate(box, attack, runner.swing_id())
	if str(box.get("shape", "")) == "beam":
		get_hitbox().set_box_param(int(event["index"]), "aim_yaw", _fan_start)
		get_hitbox().set_box_param(int(event["index"]), "sweep_dir", _fan_dir)
	elif str(box.get("shape", "")) == "ring":
		_ring_index = int(event["index"])


func _end_pattern() -> void:
	get_hitbox().clear()
	_hide_pattern_fx()
	if _repeat_left > 0 and str(_pattern.get("pattern", "")) == "leg_stomp" and pairs_standing() > 0:
		_repeat_left -= 1
		_chain_wait_ms = float(_pattern.get("repeat_gap_ms", 900.0))
		state = State.CHAIN_WAIT
		return
	_finish_pattern()


func _begin_stomp_repeat() -> void:
	state = State.PATTERN
	_begin_move(StringName(str(_pattern["move"])))


func _finish_pattern() -> void:
	var id: StringName = StringName(str(_pattern.get("pattern", "")))
	_pattern = {}
	state = State.FREE
	brain.finish(clock.now_ms(), pairs_lost())
	pattern_finished.emit(id)


## Cuts the running pattern short (a leg dropped under it, the rig toppled).
func _abort_pattern() -> void:
	if state != State.PATTERN and state != State.CHAIN_WAIT:
		return
	for event: Dictionary in runner.interrupt():
		if str(event["type"]) == "hitbox_off":
			get_hitbox().deactivate(int(event["index"]))
	get_hitbox().clear()
	_hide_pattern_fx()
	_repeat_left = 0
	_finish_pattern()


# ---- Leg Stomp ----

func _setup_stomp() -> void:
	var director: CombatDirector = find_director()
	var red: CombatActor = director.player() if director != null else null
	var target: Vector3 = red.global_position if red != null else global_position
	_marker = Vector3(target.x, global_position.y, target.z)
	var leg: Dictionary = _nearest_standing_leg(target)
	_stomp_pair = leg.get("pair", &"")
	_stomp_leg = leg.get("leg", Vector2.ZERO)
	if not leg.is_empty():
		_stomp_legs_used.append("%s_%d" % [String(_stomp_pair), int(_stomp_leg.y)])
	if _fx_marker != null:
		_fx_marker.visible = true


## The standing leg (not one already used in this chain) whose foot is nearest to `world_point`: {pair, leg: (sign, number)}.
func _nearest_standing_leg(world_point: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dist: float = INF
	for pair: StringName in PAIRS:
		if _pairs_down.has(pair):
			continue
		for number: int in [1, 2]:
			if _stomp_legs_used.has("%s_%d" % [String(pair), number]) and pairs_standing() * 2 > _stomp_legs_used.size():
				continue
			var gap: float = leg_foot_world(pair, number).distance_to(world_point)
			if gap < best_dist:
				best_dist = gap
				best = {"pair": pair, "leg": Vector2(0.0, float(number))}
	return best


## A leg's foot on the floor, in the world.
func leg_foot_world(pair: StringName, number: int) -> Vector3:
	var sign_v: Vector2 = PAIR_SIGN[pair]
	return global_transform * Vector3(sign_v.x * FOOT_X, 0.0, sign_v.y * float(FOOT_Z[number]))


func _tick_stomp(ms: float) -> void:
	var spec: Dictionary = _pattern.get("spec", {}) as Dictionary
	var lock_at: float = float(runner.data().get("impact_ms", 1100.0)) - float((runner.data().get("ground_marker", {}) as Dictionary).get("lock_before_impact_ms", 420.0))
	if not _marker_locked:
		if ms >= lock_at:
			_marker_locked = true
		else:
			var director: CombatDirector = find_director()
			var red: CombatActor = director.player() if director != null else null
			if red != null:
				_marker = Vector3(red.global_position.x, global_position.y, red.global_position.z)
	if _fx_marker != null:
		_fx_marker.global_position = Vector3(_marker.x, global_position.y + 0.03, _marker.z)
		var material: StandardMaterial3D = _fx_marker.material_override as StandardMaterial3D
		material.albedo_color = Color(1.0, 0.45, 0.1, 0.55) if _marker_locked else Color(1.0, 0.7, 0.2, 0.35)
	if spec.is_empty() and ms < 0.0:
		return


# ---- Dish Sweep ----

func _setup_sweep() -> void:
	var director: CombatDirector = find_director()
	var red: CombatActor = director.player() if director != null else null
	var origin: Variant = origin_of(&"dish")
	var at: Vector3 = (origin as Transform3D).origin
	var toward: Vector3 = (red.global_position - at) if red != null else forward()
	var around: float = atan2(toward.x, toward.z)
	var spec: Dictionary = _pattern.get("spec", {}) as Dictionary
	_fan_deg = float(spec.get("arc_deg", 80.0))
	var by_pairs: Dictionary = spec.get("arc_deg_by_pairs_lost", {}) as Dictionary
	for key: Variant in by_pairs.keys():
		if pairs_lost() >= int(str(key)):
			_fan_deg = maxf(_fan_deg, float(by_pairs[key]))
	# the fan is centred on Red: it starts half a fan to one (random) side and swings across her
	_fan_dir = 1.0 if _rng_bool() else -1.0
	_fan_start = around - _fan_dir * deg_to_rad(_fan_deg) * 0.5
	_lower_dish(false)
	_show_fan(true)


func _tick_sweep(ms: float) -> void:
	var move: Dictionary = runner.data()
	var recovery_from: float = float(move.get("startup_ms", 0.0)) + float(move.get("active_ms", 0.0))
	var lines: Dictionary = move.get("floor_line", {}) as Dictionary
	if ms >= float(lines.get("stays_until_ms", 99999.0)):
		_show_fan(false)
	# the dish comes down within jump-and-sword reach while it recovers
	if ms >= recovery_from:
		_lower_dish(true)


func _rng_bool() -> bool:
	return (hash("%d_%d" % [rng_seed, int(_age_ms)]) & 1) == 0


# ---- Drone Drop ----

func _setup_drop() -> void:
	var director: CombatDirector = find_director()
	var red: CombatActor = director.player() if director != null else null
	var red_pos: Vector3 = red.global_position if red != null else global_position
	var best: Vector3 = Vector3.INF
	var best_dist: float = INF
	for spot: Vector3 in hatches:
		var gap: float = Vector2(spot.x - red_pos.x, spot.z - red_pos.z).length()
		if gap > 5.0 and gap < best_dist:
			best_dist = gap
			best = spot
	if best == Vector3.INF and not hatches.is_empty():
		best = hatches[0]
	if best == Vector3.INF:
		best = global_position + forward() * 6.0
	_hatch_used = best
	if _fx_hatch != null:
		_fx_hatch.global_position = Vector3(best.x, best.y + 0.04, best.z)
		_fx_hatch.visible = true


func _tick_drop(ms: float) -> void:
	var spec: Dictionary = (_pattern.get("spec", {}) as Dictionary).get("spawn", {}) as Dictionary
	if not _drones_spawned and ms >= float(spec.get("at_ms", 1000.0)):
		_drones_spawned = true
		var count: int = int(spec.get("count", 3))
		var by_pairs: Dictionary = spec.get("count_by_pairs_lost", {}) as Dictionary
		for key: Variant in by_pairs.keys():
			if pairs_lost() >= int(str(key)):
				count = maxi(count, int(by_pairs[key]))
		_spawn_drones(count)
		if _fx_hatch != null:
			_fx_hatch.visible = false


func _spawn_drones(count: int) -> void:
	if not ResourceLoader.exists(drone_scene_path):
		return
	var scene: PackedScene = load(drone_scene_path) as PackedScene
	for i: int in range(count):
		var drone: ActionEnemy = scene.instantiate() as ActionEnemy
		if drone == null:
			continue
		var angle: float = TAU * float(i) / float(maxi(count, 1))
		drone.position = _hatch_used + Vector3(cos(angle), 0.0, sin(angle)) * 0.9 - Vector3.UP * 0.0
		get_parent().add_child(drone)
		_drones.append(drone)


# ---- Quiet Hours ----

func _setup_quiet() -> void:
	_quiet_active = true
	_quiet_hits = 0
	_quiet_lock_applied = false
	_lower_dish(true)
	quiet_hours_started.emit()
	bark.emit(&"kasp_rig_quiet_hours")


## Runs every frame: applies the lock when the hum ends, and cuts it short when the dish has been hit enough.
func _tick_quiet() -> void:
	var director: CombatDirector = find_director()
	if director == null:
		return
	if _quiet_active and not _quiet_lock_applied and state == State.PATTERN and str(_pattern.get("pattern", "")) == "quiet_hours":
		var spec: Dictionary = _pattern.get("spec", {}) as Dictionary
		if runner.is_busy() and runner.elapsed_ms() >= float(spec.get("lock_at_ms", 1400.0)):
			_quiet_lock_applied = true
			_quiet_locked = true
			director.lock_hacks(float(spec.get("lock_hacks_ms", 5000.0)))
	if _quiet_locked and not director.hacks_locked():
		_quiet_locked = false
		_quiet_active = false
		_lower_dish(false)
	if _quiet_active and state != State.PATTERN and not _quiet_locked:
		_quiet_active = false


func _on_dish_hit(_part_id: StringName, _source: String, move_id: StringName, _damage: int) -> void:
	if not _quiet_active:
		return
	var spec: Dictionary = brain.pattern(&"quiet_hours").get("cut_short", {}) as Dictionary
	var counts: int = int(spec.get("zap_counts_as", 3)) if move_id == &"hack_zap" else 1
	_quiet_hits += counts
	if _quiet_hits < int(spec.get("hits", 3)):
		return
	var director: CombatDirector = find_director()
	if _quiet_locked and director != null:
		director.unlock_hacks()
		_quiet_cut("during_lock")
	elif not _quiet_lock_applied:
		_quiet_cut("before_lock")


func _quiet_cut(by: String) -> void:
	_quiet_active = false
	_quiet_locked = false
	_quiet_lock_applied = true
	quiet_hours_cut.emit(by)
	if state == State.PATTERN and str(_pattern.get("pattern", "")) == "quiet_hours":
		_abort_pattern()
	_lower_dish(false)
	_react(1600.0)


func _lower_dish(lowered: bool) -> void:
	_dish_lowered = lowered
	_place_dish()


func _place_dish() -> void:
	var dish: BossPart = part(&"dish")
	if dish == null:
		return
	var y: float = _dish_lowered_y if _dish_lowered else _dish_raised_y
	dish.position = Vector3(0.0, y - dish.height_m * 0.5, DISH_BASE_LOCAL.z)


# ---- relays, legs, the dish breaking ----

func _on_relay_broken(part_id: StringName) -> void:
	var spec: Dictionary = (phase.get("parts", {}) as Dictionary).get(String(part_id), {}) as Dictionary
	var pair: StringName = StringName(str(spec.get("pair", "")))
	if pair == &"" or _pairs_down.has(pair):
		return
	_pairs_down[pair] = true
	var lost: int = pairs_lost()
	_fold_pair(pair)
	pair_dropped.emit(pair, lost)
	if not _first_relay_seen:
		_first_relay_seen = true
		bark.emit(&"kasp_rig_relay_1")
	if lost == 2:
		bark.emit(&"kasp_rig_pairs_2")
	elif lost == 3:
		bark.emit(&"kasp_rig_pairs_3")
	brain.hold_until(clock.now_ms() + 1400.0)
	if pairs_standing() == 0:
		_begin_topple()
		return
	if state == State.PATTERN or state == State.CHAIN_WAIT:
		if str(_pattern.get("pattern", "")) == "leg_stomp" and _stomp_pair == pair and runner.is_busy() \
				and runner.elapsed_ms() < float(runner.data().get("impact_ms", 0.0)):
			_abort_pattern()
		elif str(_pattern.get("pattern", "")) == "leg_stomp" and state == State.CHAIN_WAIT:
			_abort_pattern()
	if state == State.FREE:
		_react(1400.0)


func _fold_pair(pair: StringName) -> void:
	var sign_v: Vector2 = PAIR_SIGN[pair]
	_sag_target += 0.35
	var lean: float = deg_to_rad(float((phase.get("legs", {}) as Dictionary).get("lean_toward_missing_deg", 6.0)))
	_lean_target += Vector2(sign_v.y * lean, -sign_v.x * lean)       # tilt toward the missing corner (x: pitch, y: roll)
	if _model != null:
		for number: int in [1, 2]:
			var leg: Node3D = _model.find_child("leg_%s_%d" % [String(pair), number], true, false) as Node3D
			if leg != null:
				leg.rotation.z = -sign_v.x * FOLD_RAD
		var lamp: Node3D = _model.find_child("lamp_%s" % String(pair), true, false) as Node3D
		if lamp != null:
			lamp.visible = false


func _on_dish_broken(_part_id: StringName) -> void:
	var spec: Dictionary = ((phase.get("parts", {}) as Dictionary).get("dish", {}) as Dictionary).get("on_break", {}) as Dictionary
	for id: Variant in spec.get("disables_patterns", []) as Array:
		brain.disable(StringName(str(id)))
	if _quiet_active or _quiet_locked:
		var director: CombatDirector = find_director()
		if director != null and _quiet_locked:
			director.unlock_hacks()
		_quiet_cut("dish_broken")
	elif state == State.PATTERN and str(_pattern.get("pattern", "")) == "dish_sweep":
		_abort_pattern()
		_react(1600.0)
	_show_fan(false)
	if state == State.FREE:
		_react(1600.0)
	dish_broke.emit()
	bark.emit(&"kasp_rig_dish_broken")


func _react(ms: float) -> void:
	if state == State.FREE:
		state = State.REACT
		_react_ms = ms
	elif state == State.REACT:
		_react_ms = maxf(_react_ms, ms)
	brain.hold_until(clock.now_ms() + ms)


# ---- topple and jack-in ----

func _begin_topple() -> void:
	if state == State.TOPPLING or state == State.TOPPLED or state == State.JACKING or state == State.DONE:
		return
	_abort_pattern()
	_hide_pattern_fx()
	get_hitbox().clear()
	state = State.TOPPLING
	_quiet_active = false
	var director: CombatDirector = find_director()
	if director != null and _quiet_locked:
		director.unlock_hacks()
	_quiet_locked = false
	_sword_mult = float((body.get("sword_damage_mult", {}) as Dictionary).get("toppled", 1.0))
	var topple: Dictionary = phase.get("topple", {}) as Dictionary
	runner.start(StringName(str(topple.get("move", "topple"))), clock.now_usec())
	_topple_ms = float(runner.data().get("total_ms", 2600.0))
	if bool(topple.get("drones_power_off", true)):
		for drone: ActionEnemy in drones():
			drone.apply_stun(600000.0)
	_sag_target = 2.4
	_lean_target = Vector2.ZERO
	bark.emit(&"kasp_rig_topple")


func _tick_scripted(dt: float) -> void:
	_topple_ms -= dt * 1000.0
	if state == State.TOPPLING:
		if runner.is_busy():
			runner.step(clock.now_usec())
		if _topple_ms <= 0.0:
			state = State.TOPPLED
			toppled.emit()
			if _finish_when_toppled or dead:
				_start_jack_in(false)
			else:
				var director: CombatDirector = find_director()
				if director != null:
					var prompt: Dictionary = (phase.get("topple", {}) as Dictionary).get("prompt", {}) as Dictionary
					director.set_hack_prompt({"id": "jack_in", "text_key": str(prompt.get("text_key", "boss_jack_in")), "button": str(prompt.get("button", "hack"))})
					if not director.hack_prompt_used.is_connected(_on_prompt_used):
						director.hack_prompt_used.connect(_on_prompt_used)
				jack_in_ready.emit()
	elif state == State.JACKING:
		if runner.is_busy():
			runner.step(clock.now_usec())
		if _topple_ms <= 0.0:
			state = State.DONE
			defeated.emit(&"jack_in")


func _on_prompt_used(id: StringName) -> void:
	if id == &"jack_in" and state == State.TOPPLED:
		_start_jack_in(true)


## Red plugs into the dish. `from_prompt` false: the body was already beaten to zero, so there is no prompt to answer.
func _start_jack_in(_from_prompt: bool) -> void:
	var director: CombatDirector = find_director()
	if director != null:
		director.clear_hack_prompt()
	var jack: Dictionary = phase.get("jack_in", {}) as Dictionary
	var hit: int = int(roundf(float(hp_max) * float(jack.get("damage_frac_of_max", 0.6))))
	hp = maxi(hp - hit, 0)
	if director != null:
		director.hp_changed.emit(actor_id, hp, hp_max)
	state = State.JACKING
	runner.start(StringName(str(jack.get("move", "jack_in_hit"))), clock.now_usec())
	_topple_ms = float(runner.data().get("total_ms", 2400.0))
	jack_in_started.emit()
	bark.emit(&"kasp_rig_jack_in")


## The sword does 30 percent while any pair stands, full once it is down.
func apply_hit(result: Dictionary) -> void:
	if str(result.get("source", "sword")) == "sword" and not is_equal_approx(_sword_mult, 1.0) and int(result.get("damage", 0)) > 0:
		result["damage"] = maxi(int(roundf(float(result["damage"]) * _sword_mult)), 1)
	result["knockback"] = Vector3.ZERO
	result["launch_mps"] = 0.0
	result["launched"] = false
	result["knockdown"] = false
	result["hitstun_ms"] = 0.0
	super.apply_hit(result)


func _on_death(_result: Dictionary) -> void:
	# beaten to zero: topple (if still upright) and finish with the jack-in beat, no prompt
	if state == State.TOPPLED:
		_start_jack_in(false)
	elif state != State.TOPPLING and state != State.JACKING and state != State.DONE:
		_finish_when_toppled = true
		_begin_topple()
	else:
		_finish_when_toppled = true


func is_invulnerable() -> bool:
	return state == State.JACKING or state == State.DONE


# ---- building ----

func _build_body_shape() -> void:
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius_m
	capsule.height = maxf(height_m, radius_m * 2.0)
	shape_node.shape = capsule
	shape_node.position = Vector3(0.0, capsule.height * 0.5, 0.0)
	add_child(shape_node)
	floor_snap_length = 0.3


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	if ResourceLoader.exists(MODEL_PATH):
		var scene: PackedScene = load(MODEL_PATH) as PackedScene
		var node: Node3D = scene.instantiate() as Node3D if scene != null else null
		if node != null:
			_model.add_child(node)
			return
	var box: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(4.0, 1.0, 3.0)
	box.mesh = mesh
	box.position = Vector3(0.0, 4.0, 0.0)
	_model.add_child(box)


func _build_parts() -> void:
	var specs: Dictionary = phase.get("parts", {}) as Dictionary
	for key: Variant in specs.keys():
		var spec: Dictionary = specs[key] as Dictionary
		var made: BossPart = BossPart.new()
		made.name = String(key)
		made.setup(StringName(str(key)), spec, self)
		add_child(made)
		var node: Node3D = _model.find_child("relay_%s" % str(spec.get("pair", "")), true, false) as Node3D if spec.has("pair") else null
		if node != null:
			made.global_position = node.global_position - Vector3.UP * made.height_m * 0.5
		elif str(key) == "dish":
			made.position = Vector3(0.0, 0.0, DISH_BASE_LOCAL.z)
		_parts[StringName(str(key))] = made
		if made.kind == &"relay":
			made.broken.connect(_on_relay_broken)
		elif made.kind == &"dish":
			made.broken.connect(_on_dish_broken)
			made.hit_taken.connect(_on_dish_hit)


func _build_fx() -> void:
	_fx_root = Node3D.new()
	_fx_root.name = "Fx"
	_fx_root.top_level = true
	add_child(_fx_root)
	_fx_marker = _flat_disc(1.4, Color(1.0, 0.7, 0.2, 0.35))
	_fx_hatch = _flat_disc(1.3, Color(1.0, 0.6, 0.1, 0.5))
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	_fx_ring = MeshInstance3D.new()
	_fx_ring.mesh = torus
	_fx_ring.material_override = _fx_material(Color(1.0, 0.35, 0.15, 0.7))
	_fx_ring.top_level = true
	_fx_ring.visible = false
	_fx_root.add_child(_fx_ring)
	for i: int in range(2):
		var line: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.5, 0.04, 38.0)
		line.mesh = mesh
		line.material_override = _fx_material(Color(1.0, 0.23, 0.23, 0.8))
		line.top_level = true
		line.visible = false
		_fx_root.add_child(line)
		_fx_edges.append(line)


func _flat_disc(radius: float, colour: Color) -> MeshInstance3D:
	var disc: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.03
	disc.mesh = mesh
	disc.material_override = _fx_material(colour)
	disc.top_level = true
	disc.visible = false
	_fx_root.add_child(disc)
	return disc


func _fx_material(colour: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _show_fan(on: bool) -> void:
	if _fx_edges.size() < 2:
		return
	var origin: Variant = origin_of(&"dish")
	var at: Vector3 = (origin as Transform3D).origin
	var yaws: Vector2 = fan_yaws()
	for i: int in range(2):
		var yaw: float = yaws.x if i == 0 else yaws.y
		var line: MeshInstance3D = _fx_edges[i]
		line.visible = on
		if on:
			line.global_position = at + Vector3(sin(yaw), 0.04, cos(yaw)) * 19.0
			line.global_rotation = Vector3(0.0, yaw, 0.0)


func _hide_pattern_fx() -> void:
	if _fx_marker != null:
		_fx_marker.visible = false
	if _fx_hatch != null and _drones_spawned:
		_fx_hatch.visible = false
	if _fx_ring != null:
		_fx_ring.visible = false
	_show_fan(false)


func _update_visuals(dt: float) -> void:
	_sag = move_toward(_sag, _sag_target, dt * 3.0)
	_lean = _lean.move_toward(_lean_target, dt * 0.5)
	if _model != null:
		_model.position.y = -_sag
		_model.rotation = Vector3(_lean.x, 0.0, _lean.y)
	if _ring_index >= 0 and _fx_ring != null:
		var radius: float = get_hitbox().ring_radius_of(_ring_index)
		if radius > 0.0:
			_fx_ring.visible = true
			_fx_ring.global_position = Vector3(_marker.x, global_position.y + 0.3, _marker.z)
			_fx_ring.scale = Vector3(radius, 0.6, radius)
	elif _fx_ring != null:
		_fx_ring.visible = false
