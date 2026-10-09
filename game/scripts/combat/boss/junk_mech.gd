class_name JunkMech
extends CombatActor
## The Heap: Kasp's 40 m junk mech, phase 2 of the fight (docs/slice/boss_design.md, data/combat/bosses/junk_mech.json, moves.json
## set `junk_mech`). It fights Red's colossus. Everything is authored in final world units (metres, real milliseconds), so nothing
## here is scaled again; `scale_form` is `huge` only so the camera, lock-on and sound know how big it is.
##
## The fight, as data: four armour plates (BossPart) and the core in Kasp's cab. A plate takes 35 percent while closed and full
## damage while open; it opens during the recovery of the attack that names it (`opens`) and for 400 ms after, shown by a pale cyan
## pointer. The core is sealed until every plate is gone, then takes half damage, and 150 percent in every recovery. When the last
## plate falls the cab opens (2.6 s, untouchable); at 35 percent core health it roars (2.2 s) and chains attacks with shorter gaps;
## at 0 the Heap collapses and the phase ends.
## Four attacks, each with a floor decal at least 12 m wide, a lamp that goes orange then red, and a sting when it starts and when
## the aim locks: Scrap Swing (an arc), Wrecking Drop (a circle that follows you, then a ring), Stomp March (two rings), Scrap
## Barrage (three circles painted 0.6 s ahead). Hooks for tuning by playing: feel knobs `heap_damage_scale`, `heap_plate_hp_scale`,
## `heap_gap_scale`.

signal pattern_started(pattern_id: StringName)
signal pattern_finished(pattern_id: StringName)
signal plate_opened(part_id: StringName)
signal plate_broken(part_id: StringName)
signal stage_changed(stage: StringName)
signal shot(shot_id: StringName)                  ## a camera beat the story director plays (shot_core_reveal)
signal bark(event_id: StringName)
signal bar_changed(hp: float, hp_max: float)      ## the boss bar's main bar: the plates' total, then the core
signal pips_changed(standing: int, total: int)    ## plates still standing
signal defeated

enum State { WALK, PATTERN, CHAIN_WAIT, REACT, DEFEAT, DONE }

const MODEL_PATH: String = "res://art/placeholder/bosses/junk_mech_ual.glb"
const FALLBACK_MODEL_PATH: String = "res://art/placeholder/bosses/junk_mech.glb"
## part id -> {bone, mesh} in the blockout (make_bosses.py)
const PART_NODES: Dictionary = {
	"plate_shoulder_l": {"bone": "plate_shoulder_l_mount", "mesh": "plate_shoulder_l"},
	"plate_shoulder_r": {"bone": "plate_shoulder_r_mount", "mesh": "plate_shoulder_r"},
	"plate_chest": {"bone": "plate_chest_front_mount", "mesh": "plate_chest_front"},
	"plate_back": {"bone": "plate_back_mount", "mesh": "plate_back"},
	"core": {"bone": "cockpit_core_mount", "mesh": ""},
}
const PLATE_IDS: Array[StringName] = [&"plate_shoulder_l", &"plate_shoulder_r", &"plate_chest", &"plate_back"]
const LAMP_IDLE: Color = Color(1.0, 0.69, 0.18)
const LAMP_WINDUP: Color = Color(1.0, 0.6, 0.24)
const LAMP_RED: Color = Color(1.0, 0.16, 0.1)
const OPEN_COLOUR: Color = Color(0.75, 0.96, 1.0)
const RED_LAMP_BEFORE_IMPACT_MS: float = 400.0

var doc: Dictionary = {}
var body: Dictionary = {}
var brain: BossBrain = null
var runner: MoveRunner = null
var state: State = State.WALK
var stage: StringName = &"armored"
var rng_seed: int = 1
## Read by the camera, lock-on and sound: this body is authored at colossus scale already.
var scale_form: StringName = &"huge"

var _moves: MoveSet = null
var _parts: Dictionary = {}
var _model: Node3D = null
var _skeleton: Skeleton3D = null
var _anim: AnimationPlayer = null
var _fx_root: Node3D = null
var _floodlights: MeshInstance3D = null
var _lamp_material: StandardMaterial3D = null
var _pointers: Dictionary = {}                   # plate id -> MeshInstance3D
var _open_left_ms: Dictionary = {}
var _core_open_ms: float = 0.0
var _invuln_ms: float = 0.0
var _pattern: Dictionary = {}
var _chain_moves: Array[StringName] = []
var _chain_index: int = 0
var _chain_wait_ms: float = 0.0
var _swing_side: int = 0
var _move_id: StringName = &""
var _move_start_usec: int = 0
var _opened_this_move: bool = false
var _locks: Dictionary = {}                      # target id -> {pos, locked}
var _react_ms: float = 0.0
var _decals: Dictionary = {}
var _barrage_marks: Array[MeshInstance3D] = []
var _first_plate_open_said: bool = false
var _sting_done: bool = false
var _lock_sting_done: bool = false
var _age_ms: float = 0.0
var _hp_cache: float = -1.0


static func create(boss_doc: Dictionary, seed_value: int = 1) -> JunkMech:
	var out: JunkMech = JunkMech.new()
	out.doc = boss_doc
	out.rng_seed = seed_value
	out.name = "JunkMech"
	return out


func _ready() -> void:
	body = doc.get("body", {}) as Dictionary
	actor_id = &"junk_mech"
	team = &"enemy"
	move_set_id = StringName(str(body.get("move_set", "junk_mech")))
	height_m = float(body.get("height_m", 40.0))
	radius_m = float(body.get("radius_m", 9.0))
	hp_max = 1
	hp = 1
	weight = 1000.0
	launchable = false
	_moves = MoveSet.load_default()
	runner = MoveRunner.create(_moves, move_set_id)
	brain = BossBrain.from_heap(doc, rng_seed)
	super._ready()
	get_hurtbox().collision_layer = 0              # only the plates and the core can be hit
	get_hitbox().origin_resolver = Callable(self, "origin_of")
	_build_body_shape()
	_build_model()
	_build_parts()
	_build_fx()
	_set_stage(&"armored", false)
	set_physics_process(true)
	_emit_bar()
	pips_changed.emit(plates_standing(), PLATE_IDS.size())
	bark.emit(StringName(str((doc.get("events", {}) as Dictionary).get("on_start", "kasp_mech_intro"))))


func _physics_process(delta: float) -> void:
	tick(delta)


# ---- what others ask ----

func tags() -> PackedStringArray:
	return PackedStringArray(["boss", "robot", "signals"])


func part(id: StringName) -> BossPart:
	return _parts.get(id, null)


func parts() -> Array[BossPart]:
	var out: Array[BossPart] = []
	for item: Variant in _parts.values():
		out.append(item as BossPart)
	return out


func plates_standing() -> int:
	var count: int = 0
	for id: StringName in PLATE_IDS:
		if _parts.has(id) and not (_parts[id] as BossPart).dead:
			count += 1
	return count


func is_plate_open(id: StringName) -> bool:
	return float(_open_left_ms.get(id, 0.0)) > 0.0


func is_core_open() -> bool:
	return _core_open_ms > 0.0


func is_core_sealed() -> bool:
	return plates_standing() > 0


func is_invulnerable() -> bool:
	return _invuln_ms > 0.0 or state == State.DEFEAT or state == State.DONE


func current_pattern() -> StringName:
	return StringName(str(_pattern.get("pattern", ""))) if state == State.PATTERN or state == State.CHAIN_WAIT else &""


func current_move() -> StringName:
	return _move_id if state == State.PATTERN else &""


func lock_position(target_id: StringName) -> Vector3:
	return (_locks.get(String(target_id), {}) as Dictionary).get("pos", Vector3.ZERO)


func is_locked(target_id: StringName) -> bool:
	return bool((_locks.get(String(target_id), {}) as Dictionary).get("locked", false))


## Where a hitbox box hangs (moves.json `origin`): the aimed circles and the feet.
func origin_of(origin_name: StringName) -> Variant:
	var floor_y: float = global_position.y
	match origin_name:
		&"mech_foot_r", &"mech_foot_l":
			var bone: Vector3 = _bone_world(&"foot_r" if origin_name == &"mech_foot_r" else &"foot_l")
			return Transform3D(Basis(Vector3.UP, rotation.y), Vector3(bone.x, floor_y, bone.z))
		&"locked_target", &"target_1", &"target_2", &"target_3":
			var pos: Vector3 = lock_position(origin_name)
			return Transform3D(Basis.IDENTITY, Vector3(pos.x, floor_y, pos.z))
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
	_invuln_ms = maxf(_invuln_ms - dt * 1000.0, 0.0)
	_core_open_ms = maxf(_core_open_ms - dt * 1000.0, 0.0)
	for key: Variant in _open_left_ms.keys():
		_open_left_ms[key] = maxf(float(_open_left_ms[key]) - dt * 1000.0, 0.0)
	_follow_parts(dt)
	match state:
		State.WALK:
			_tick_walk(dt, director)
		State.PATTERN:
			_tick_pattern(dt)
		State.CHAIN_WAIT:
			_chain_wait_ms -= dt * 1000.0
			if _chain_wait_ms <= 0.0:
				state = State.PATTERN
				_begin_move(_chain_moves[_chain_index])
		State.REACT, State.DEFEAT:
			_tick_react(dt)
	_refresh_multipliers()
	get_hitbox().tick(dt)
	_update_fx()
	velocity.y = -1.0
	slide_scaled(dt / delta if delta > 0.0 else 1.0)
	_emit_bar()


func _tick_walk(dt: float, director: CombatDirector) -> void:
	var red: CombatActor = director.player() if director != null else null
	if red == null:
		return
	var to_red: Vector3 = red.global_position - global_position
	to_red.y = 0.0
	var dist: float = to_red.length()
	if dist > 0.1:
		_turn_toward(to_red / dist, dt)
	var range_m: Array = body.get("preferred_range_m", [26.0, 40.0]) as Array
	var speed: float = 0.0
	if dist > float(body.get("walk_when_farther_than_m", 60.0)):
		speed = float(body.get("approach_speed_mps", 16.0))
	elif dist > float(range_m[1]):
		speed = float(body.get("move_speed_mps", 12.0))
	elif dist < float(body.get("back_off_closer_than_m", 18.0)):
		speed = -float(body.get("circle_speed_mps", 9.0))
	var heading: Vector3 = forward()
	velocity.x = heading.x * speed
	velocity.z = heading.z * speed
	_play_loop(&"walk" if absf(speed) > 0.1 else &"idle")
	var opening_range: float = float((doc.get("opening", {}) as Dictionary).get("first_attack_when_within_m", 50.0))
	if dist > opening_range or _invuln_ms > 0.0:
		return
	var pick: Dictionary = brain.step(clock.now_ms(), _view(dist))
	if not pick.is_empty():
		_start_pattern(pick)


func _turn_toward(direction: Vector3, dt: float) -> void:
	rotation.y = rotate_toward(rotation.y, atan2(direction.x, direction.z), deg_to_rad(float(body.get("turn_rate_deg_per_s", 38.0))) * dt)


func _view(dist: float) -> Dictionary:
	var allowed: Array = []
	for entry: Variant in doc.get("stages", []) as Array:
		var stage_data: Dictionary = entry as Dictionary
		if str(stage_data.get("id", "")) == String(stage) or (stage == &"core" and str(stage_data.get("id", "")) == "core"):
			allowed = (stage_data.get("patterns", []) as Array).duplicate()
	var bias: Dictionary = {}
	var factor: float = float((_stage_data(&"armored")).get("bias_to_open_alive_plates", 1.0))
	if stage == &"armored" and factor > 1.0:
		for id: StringName in PLATE_IDS:
			if not _parts.has(id) or (_parts[id] as BossPart).dead:
				continue
			var opener: String = str(((doc.get("parts", {}) as Dictionary).get(String(id), {}) as Dictionary).get("opened_by", ""))
			for pattern_spec: Variant in doc.get("patterns", []) as Array:
				var spec: Dictionary = pattern_spec as Dictionary
				if (spec.get("moves", []) as Array).has(opener) or str(spec.get("id", "")) == opener:
					bias[str(spec.get("id", ""))] = factor
	return {"dist_m": dist, "stage": String(stage), "allowed": allowed, "bias": bias}


func _stage_data(id: StringName) -> Dictionary:
	for entry: Variant in doc.get("stages", []) as Array:
		if str((entry as Dictionary).get("id", "")) == String(id):
			return entry as Dictionary
	return {}


# ---- patterns ----

func _start_pattern(pick: Dictionary) -> void:
	_pattern = pick
	var spec: Dictionary = pick.get("spec", {}) as Dictionary
	brain.begin(StringName(str(pick["pattern"])), clock.now_ms())
	state = State.PATTERN
	velocity = Vector3.ZERO
	_chain_moves.clear()
	_chain_index = 0
	var moves: Array = pick.get("moves", []) as Array
	if spec.has("gap_ms"):
		for move: Variant in moves:
			_chain_moves.append(StringName(str(move)))
	else:
		_chain_moves.append(_choose_move(moves))
	pattern_started.emit(StringName(str(pick["pattern"])))
	_begin_move(_chain_moves[0])


## Which of a pattern's moves to play: the swing alternates sides unless only one shoulder plate is left standing.
func _choose_move(moves: Array) -> StringName:
	if moves.size() == 1:
		return StringName(str(moves[0]))
	var left_alive: bool = _parts.has(&"plate_shoulder_l") and not (_parts[&"plate_shoulder_l"] as BossPart).dead
	var right_alive: bool = _parts.has(&"plate_shoulder_r") and not (_parts[&"plate_shoulder_r"] as BossPart).dead
	var left: bool = _swing_side == 0
	if left_alive and not right_alive:
		left = true
	elif right_alive and not left_alive:
		left = false
	_swing_side = 1 - _swing_side
	return StringName(str(moves[0] if left else moves[1]))


func _begin_move(move_id: StringName) -> void:
	if not runner.start(move_id, clock.now_usec()):
		push_warning("JunkMech: unknown move %s" % move_id)
		_finish_pattern()
		return
	_move_id = move_id
	_move_start_usec = clock.now_usec()
	_opened_this_move = false
	_sting_done = false
	_lock_sting_done = false
	_locks.clear()
	var director: CombatDirector = find_director()
	var red: CombatActor = director.player() if director != null else null
	for entry: Variant in runner.data().get("targets", []) as Array:
		var spec: Dictionary = entry as Dictionary
		var at: Vector3 = red.global_position if red != null else global_position
		_locks[str(spec.get("id", ""))] = {"pos": at, "locked": false, "lock_ms": float(spec.get("lock_ms", 0.0))}
	_handle_events(runner.step(_move_start_usec))


func _tick_pattern(dt: float) -> void:
	if not runner.is_busy():
		_move_done()
		return
	var ms: float = runner.elapsed_ms()
	var director: CombatDirector = find_director()
	var red: CombatActor = director.player() if director != null else null
	var data: Dictionary = runner.data()
	if not _sting_done:
		_sting_done = true
		BossSfx.play(&"mech_sting_windup")
	# the mech keeps turning to face Red until just before the first impact
	if red != null and ms < float(data.get("impact_ms", 0.0)) - 300.0 and str(data.get("kind", "")) != "reaction":
		var to_red: Vector3 = red.global_position - global_position
		to_red.y = 0.0
		if to_red.length() > 0.1:
			_turn_toward(to_red.normalized(), dt)
	# aimed circles follow Red until their lock time
	for key: Variant in _locks.keys():
		var lock: Dictionary = _locks[key] as Dictionary
		if bool(lock["locked"]):
			continue
		if ms >= float(lock["lock_ms"]):
			lock["locked"] = true
			if not _lock_sting_done:
				_lock_sting_done = true
				BossSfx.play(&"mech_sting_lock")
		elif red != null:
			lock["pos"] = red.global_position
	# the recovery opens the plate this attack names, and the core
	if not _opened_this_move and runner.phase() == MoveRunner.PHASE_RECOVERY:
		_opened_this_move = true
		var remaining: float = float(data.get("total_ms", 0.0)) - ms
		_open_for_recovery(StringName(str(data.get("opens", ""))), remaining)
	_handle_events(runner.step(clock.now_usec()))
	if not runner.is_busy():
		_move_done()


func _open_for_recovery(plate_id: StringName, remaining_ms: float) -> void:
	var linger: float = 400.0
	if plate_id != &"" and _parts.has(plate_id) and not (_parts[plate_id] as BossPart).dead:
		linger = float(((doc.get("parts", {}) as Dictionary).get(String(plate_id), {}) as Dictionary).get("linger_ms", 400.0))
		_open_left_ms[plate_id] = remaining_ms + linger
		plate_opened.emit(plate_id)
		if not _first_plate_open_said:
			_first_plate_open_said = true
			bark.emit(StringName(str((doc.get("events", {}) as Dictionary).get("on_first_plate_open", "vela_mech_open_plate"))))
	if plates_standing() == 0:
		_core_open_ms = remaining_ms + linger


func _move_done() -> void:
	get_hitbox().clear()
	_hide_decals()
	if _chain_index + 1 < _chain_moves.size():
		_chain_index += 1
		_chain_wait_ms = float((_pattern.get("spec", {}) as Dictionary).get("gap_ms", 700.0))
		state = State.CHAIN_WAIT
		return
	_finish_pattern()


func _finish_pattern() -> void:
	var id: StringName = StringName(str(_pattern.get("pattern", "")))
	_pattern = {}
	state = State.WALK
	var gap: float = brain.stage_gap_ms(String(stage))
	var director: CombatDirector = find_director()
	if director != null and director.feel != null and director.feel.has("heap_gap_scale"):
		gap *= director.feel.get_f("heap_gap_scale")
	brain.finish(clock.now_ms(), 0, gap)
	pattern_finished.emit(id)


## Cuts the running pattern short (a stage change).
func _abort_pattern() -> void:
	if state != State.PATTERN and state != State.CHAIN_WAIT:
		return
	for event: Dictionary in runner.interrupt():
		if str(event["type"]) == "hitbox_off":
			get_hitbox().deactivate(int(event["index"]))
	get_hitbox().clear()
	_hide_decals()
	_chain_moves.clear()
	_finish_pattern()


func _handle_events(events: Array[Dictionary]) -> void:
	var director: CombatDirector = find_director()
	for event: Dictionary in events:
		match String(event["type"]):
			"telegraph":
				if director != null:
					director.telegraph(self, runner.current_move(), _move_start_usec + int(float(runner.data().get("impact_ms", 0.0)) * 1000.0),
							StringName(str(runner.data().get("telegraph_kind", ""))))
			"swing":
				BossSfx.play(_swing_sound(runner.current_move()))
				if director != null:
					director.notify_move_started(self, runner.current_move(), event.get("swing", {}))
			"hitbox_on":
				var box: Dictionary = (event["box"] as Dictionary).duplicate()
				box["index"] = int(event["index"])
				var attack: Dictionary = runner.attack_data()
				var scale: float = 1.0
				if director != null and director.feel != null and director.feel.has("heap_damage_scale"):
					scale = director.feel.get_f("heap_damage_scale")
				attack["damage"] = int(roundf(float(attack.get("damage", 0)) * scale))
				get_hitbox().activate(box, attack, runner.swing_id())
			"hitbox_off":
				get_hitbox().deactivate(int(event["index"]))
			"pose":
				_play_pose(StringName(str(event["clip"])), float(event["clip_s"]))
			"interrupted", "done":
				get_hitbox().clear()


static func _swing_sound(move_id: StringName) -> StringName:
	match String(move_id):
		"wrecking_drop", "stomp_march":
			return &"mech_slam"
		"scrap_barrage":
			return &"mech_barrage"
	return &"mech_swing"


# ---- plates, the core, the stages ----

func _on_part_broken(part_id: StringName) -> void:
	var events: Dictionary = doc.get("events", {}) as Dictionary
	if part_id == &"core":
		_begin_defeat()
		return
	BossSfx.play(&"mech_plate_break")
	var mesh: Node3D = _model.find_child(str((PART_NODES.get(String(part_id), {}) as Dictionary).get("mesh", "")), true, false) as Node3D if _model != null else null
	if mesh != null:
		mesh.visible = false
	_open_left_ms[part_id] = 0.0
	plate_broken.emit(part_id)
	pips_changed.emit(plates_standing(), PLATE_IDS.size())
	bark.emit(StringName(str(events.get("on_plate_break", "kasp_mech_plate"))))
	brain.hold_until(clock.now_ms() + 1000.0)
	if plates_standing() == 0:
		_begin_core_reveal()


func _begin_core_reveal() -> void:
	_abort_pattern()
	_set_stage(&"core", true)
	_invuln_ms = _react_move(&"core_reveal")
	BossSfx.play(&"mech_core_alarm")
	shot.emit(StringName(str(_stage_data(&"core_reveal").get("shot", "shot_core_reveal"))))
	bark.emit(StringName(str((doc.get("events", {}) as Dictionary).get("on_core_reveal", "kasp_mech_core"))))
	_emit_bar()


func _begin_last_stand() -> void:
	_abort_pattern()
	_set_stage(&"last_stand", true)
	_invuln_ms = _react_move(&"last_stand")
	BossSfx.play(&"mech_roar")
	bark.emit(StringName(str((doc.get("events", {}) as Dictionary).get("on_last_stand", "kasp_mech_last_stand"))))


func _begin_defeat() -> void:
	_abort_pattern()
	state = State.DEFEAT
	_invuln_ms = 0.0
	_react_move(&"defeat")
	BossSfx.play(&"mech_defeat")
	bark.emit(StringName(str((doc.get("events", {}) as Dictionary).get("on_defeat", "kasp_mech_defeat"))))


## Plays a reaction move (core_reveal, last_stand, defeat); returns its length in ms.
func _react_move(move_id: StringName) -> float:
	if state != State.DEFEAT:
		state = State.REACT
	if runner.start(move_id, clock.now_usec()):
		_react_ms = float(runner.data().get("total_ms", 1000.0))
		_move_start_usec = clock.now_usec()
		_handle_events(runner.step(_move_start_usec))
	else:
		_react_ms = 1000.0
	return _react_ms


func _tick_react(dt: float) -> void:
	_react_ms -= dt * 1000.0
	if runner.is_busy():
		_handle_events(runner.step(clock.now_usec()))
	if _react_ms > 0.0:
		return
	if state == State.DEFEAT:
		state = State.DONE
		defeated.emit()
	else:
		state = State.WALK
		brain.hold_until(clock.now_ms() + 600.0)


func _set_stage(id: StringName, announce: bool) -> void:
	stage = id
	if announce:
		stage_changed.emit(id)


## Plates take 35 percent while closed and full damage while open; the core nothing while sealed; nothing while the Heap is untouchable.
func _refresh_multipliers() -> void:
	var specs: Dictionary = doc.get("parts", {}) as Dictionary
	for key: Variant in _parts.keys():
		var made: BossPart = _parts[key] as BossPart
		var spec: Dictionary = specs.get(String(key), {}) as Dictionary
		if _invuln_ms > 0.0 or state == State.DEFEAT or state == State.DONE:
			made.damage_mult_now = 0.0
		elif made.kind == &"core":
			if is_core_sealed():
				made.damage_mult_now = float(spec.get("sealed_mult", 0.0))
			elif is_core_open():
				made.damage_mult_now = float(spec.get("open_mult", 1.5))
			else:
				made.damage_mult_now = float(spec.get("exposed_mult", 0.5))
		else:
			made.damage_mult_now = float(spec.get("open_mult", 1.0)) if is_plate_open(StringName(str(key))) else float(spec.get("closed_mult", 0.35))


func _on_core_hit(_part_id: StringName, _source: String, _move_id: StringName, damage: int) -> void:
	if damage > 0:
		BossSfx.play(&"mech_core_hit")
	var core: BossPart = part(&"core")
	if core != null and not core.dead and stage == &"core" and state != State.REACT \
			and float(core.hp) / float(core.hp_max) <= float(str(_stage_data(&"last_stand").get("when", "core_hp_frac_at_most_0.35")).trim_prefix("core_hp_frac_at_most_")):
		_begin_last_stand()


# ---- the boss bar ----

func _emit_bar() -> void:
	var value: float = 0.0
	var maximum: float = 1.0
	if plates_standing() > 0:
		for id: StringName in PLATE_IDS:
			var made: BossPart = part(id)
			if made != null:
				value += float(maxi(made.hp, 0))
				maximum += float(made.hp_max)
		maximum -= 1.0
	else:
		var core: BossPart = part(&"core")
		if core != null:
			value = float(maxi(core.hp, 0))
			maximum = float(core.hp_max)
	if not is_equal_approx(value, _hp_cache):
		_hp_cache = value
		bar_changed.emit(value, maximum)


# ---- building ----

func _build_body_shape() -> void:
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius_m
	capsule.height = height_m
	shape_node.shape = capsule
	shape_node.position = Vector3(0.0, height_m * 0.5, 0.0)
	add_child(shape_node)
	floor_snap_length = 1.0


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var path: String = MODEL_PATH if ResourceLoader.exists(MODEL_PATH) else FALLBACK_MODEL_PATH
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		var node: Node3D = scene.instantiate() as Node3D if scene != null else null
		if node != null:
			_model.add_child(node)
			var skeletons: Array[Node] = node.find_children("*", "Skeleton3D", true, false)
			_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
			var players: Array[Node] = node.find_children("*", "AnimationPlayer", true, false)
			_anim = players[0] as AnimationPlayer if not players.is_empty() else null
			_floodlights = node.find_child("floodlights", true, false) as MeshInstance3D
			return
	var box: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(radius_m * 2.0, height_m, radius_m * 2.0)
	box.mesh = mesh
	box.position = Vector3(0.0, height_m * 0.5, 0.0)
	_model.add_child(box)


func _build_parts() -> void:
	var specs: Dictionary = doc.get("parts", {}) as Dictionary
	var director: CombatDirector = find_director()
	var hp_scale: float = 1.0
	if director != null and director.feel != null and director.feel.has("heap_plate_hp_scale"):
		hp_scale = director.feel.get_f("heap_plate_hp_scale")
	for key: Variant in PART_NODES.keys():
		if not specs.has(key):
			continue
		var spec: Dictionary = (specs[key] as Dictionary).duplicate(true)
		var is_plate: bool = str(spec.get("kind", "")) == "plate"
		spec["height_m"] = 8.0 if is_plate else 6.0
		spec["radius_m"] = 5.0 if is_plate else 4.0
		spec["hp"] = int(roundf(float(spec.get("hp", 1000)) * (hp_scale if is_plate else 1.0)))
		spec["tags"] = ["plate" if is_plate else "core"]
		spec["damaged_by"] = ["sword", "hack", "hijacked"]
		var made: BossPart = BossPart.new()
		made.name = str(key)
		made.setup(StringName(str(key)), spec, self)
		add_child(made)
		_parts[StringName(str(key))] = made
		made.broken.connect(_on_part_broken)
		if not is_plate:
			made.hit_taken.connect(_on_core_hit)
	_follow_parts(0.0)


func _build_fx() -> void:
	_fx_root = Node3D.new()
	_fx_root.name = "Fx"
	_fx_root.top_level = true
	add_child(_fx_root)
	if _floodlights != null:
		_lamp_material = StandardMaterial3D.new()
		_lamp_material.emission_enabled = true
		_lamp_material.emission = LAMP_IDLE
		_lamp_material.albedo_color = LAMP_IDLE
		_lamp_material.emission_energy_multiplier = 2.0
		_floodlights.material_override = _lamp_material
	var disc_mesh: CylinderMesh = CylinderMesh.new()
	disc_mesh.top_radius = 1.0
	disc_mesh.bottom_radius = 1.0
	disc_mesh.height = 0.1
	_decals["circle"] = _decal(disc_mesh, Color(1.0, 0.45, 0.12, 0.4))
	var torus: TorusMesh = TorusMesh.new()
	_decals["ring"] = _decal(torus, Color(1.0, 0.3, 0.1, 0.55))
	_decals["arc"] = _decal(_sector_mesh(1.0, 110.0), Color(1.0, 0.4, 0.1, 0.35))
	_decals["preview"] = _decal(TorusMesh.new(), Color(1.0, 0.5, 0.2, 0.2))
	for i: int in range(3):
		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = 9.0
		disc.bottom_radius = 9.0
		disc.height = 0.3
		_barrage_marks.append(_decal(disc, Color(1.0, 0.45, 0.12, 0.45)))
	for id: StringName in PLATE_IDS:
		var pointer: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 1.4
		sphere.height = 2.8
		pointer.mesh = sphere
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = OPEN_COLOUR
		material.emission_enabled = true
		material.emission = OPEN_COLOUR
		material.emission_energy_multiplier = 3.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pointer.material_override = material
		pointer.top_level = true
		pointer.visible = false
		_fx_root.add_child(pointer)
		_pointers[id] = pointer


func _decal(mesh: Mesh, colour: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	node.top_level = true
	node.visible = false
	_fx_root.add_child(node)
	return node


## A flat wedge of a circle facing +Z, `arc_deg` wide, radius `radius` (scaled up to the real radius with the node's scale).
static func _sector_mesh(radius: float, arc_deg: float) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = 24
	var half: float = deg_to_rad(arc_deg) * 0.5
	for i: int in range(steps):
		var a: float = -half + 2.0 * half * float(i) / float(steps)
		var b: float = -half + 2.0 * half * float(i + 1) / float(steps)
		tool.add_vertex(Vector3.ZERO)
		tool.add_vertex(Vector3(sin(a), 0.0, cos(a)) * radius)
		tool.add_vertex(Vector3(sin(b), 0.0, cos(b)) * radius)
	return tool.commit()


# ---- following the animation ----

func _bone_world(bone: StringName) -> Vector3:
	if _skeleton == null:
		return global_position
	var index: int = _skeleton.find_bone(String(bone))
	if index < 0:
		return global_position
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(index)).origin


func _follow_parts(_dt: float) -> void:
	for key: Variant in _parts.keys():
		var made: BossPart = _parts[key] as BossPart
		var spot: Vector3 = _bone_world(StringName(str((PART_NODES[String(key)] as Dictionary)["bone"])))
		made.global_position = spot - Vector3.UP * made.height_m * 0.5
		made.tick(0.0)


func _play_pose(clip: StringName, clip_s: float) -> void:
	if _anim == null or not _anim.has_animation(String(clip)):
		return
	_anim.play(String(clip))
	_anim.seek(clip_s, true)
	_anim.pause()
	_loop_name = &""


var _loop_name: StringName = &""


func _play_loop(clip: StringName) -> void:
	if _anim == null or not _anim.has_animation(String(clip)):
		return
	if _loop_name != clip:
		_anim.play(String(clip), 0.2)
		_loop_name = clip
	_anim.speed_scale = 1.0


# ---- the readable bits: lamps, decals, pointers ----

func _update_fx() -> void:
	var floor_y: float = global_position.y + 0.1
	var lamp: Color = LAMP_IDLE
	var busy: bool = state == State.PATTERN and runner.is_busy()
	var data: Dictionary = runner.data() if busy else {}
	var ms: float = runner.elapsed_ms() if busy else 0.0
	if busy:
		lamp = LAMP_WINDUP
		var impact: float = float(data.get("impact_ms", 0.0))
		if ms >= impact - RED_LAMP_BEFORE_IMPACT_MS and ms < float(data.get("startup_ms", 0.0)) + float(data.get("active_ms", 0.0)):
			lamp = LAMP_RED
	if _lamp_material != null:
		_lamp_material.emission = lamp
		_lamp_material.albedo_color = lamp
	_hide_decals(false)
	if busy:
		_show_decals(data, ms, floor_y)
	for id: StringName in PLATE_IDS:
		var pointer: MeshInstance3D = _pointers.get(id, null)
		if pointer == null:
			continue
		var open: bool = is_plate_open(id) and not (_parts[id] as BossPart).dead
		pointer.visible = open
		if open:
			pointer.global_position = _bone_world(StringName(str((PART_NODES[String(id)] as Dictionary)["bone"]))) + Vector3.UP * 4.0


func _show_decals(data: Dictionary, ms: float, floor_y: float) -> void:
	var decal: Dictionary = data.get("floor_decal", {}) as Dictionary
	if decal.is_empty():
		return
	var shape: String = str(decal.get("shape", ""))
	var radius: float = float(decal.get("radius_m", 10.0))
	if bool(decal.get("per_target", false)):
		var shown_before: float = float(decal.get("show_before_impact_ms", 600.0))
		var targets: Array = data.get("targets", []) as Array
		var hitboxes: Array = data.get("hitboxes", []) as Array
		for i: int in range(mini(targets.size(), _barrage_marks.size())):
			var impact_ms: float = float((hitboxes[i] as Dictionary).get("from_ms", 0.0))
			var lock_pos: Vector3 = lock_position(StringName(str((targets[i] as Dictionary).get("id", ""))))
			var mark: MeshInstance3D = _barrage_marks[i]
			mark.visible = ms >= impact_ms - shown_before and ms < impact_ms + 150.0
			mark.global_position = Vector3(lock_pos.x, floor_y, lock_pos.z)
		return
	if ms < float(decal.get("from_ms", 0.0)) or ms > float(decal.get("to_ms", 99999.0)):
		return
	match shape:
		"circle":
			var node: MeshInstance3D = _decals["circle"]
			node.visible = true
			var pos: Vector3 = lock_position(&"locked_target")
			node.global_position = Vector3(pos.x, floor_y, pos.z)
			node.scale = Vector3(radius, 0.3, radius)
			var preview: float = float(decal.get("ring_preview_m", 0.0))
			if preview > 0.0:
				var ring_preview: MeshInstance3D = _decals["preview"]
				ring_preview.visible = true
				ring_preview.global_position = Vector3(pos.x, floor_y, pos.z)
				ring_preview.scale = Vector3(preview, 0.4, preview)
		"ring":
			var ring: MeshInstance3D = _decals["ring"]
			ring.visible = true
			ring.global_position = Vector3(global_position.x, floor_y, global_position.z)
			ring.scale = Vector3(radius, 0.6, radius)
		"arc":
			var arc: MeshInstance3D = _decals["arc"]
			arc.visible = true
			arc.global_position = Vector3(global_position.x, floor_y, global_position.z)
			arc.global_rotation = Vector3(0.0, rotation.y, 0.0)
			arc.scale = Vector3(radius, 1.0, radius)


func _hide_decals(clear_marks: bool = true) -> void:
	for key: Variant in _decals.keys():
		(_decals[key] as MeshInstance3D).visible = false
	if clear_marks:
		for mark: MeshInstance3D in _barrage_marks:
			mark.visible = false
	else:
		for mark: MeshInstance3D in _barrage_marks:
			mark.visible = false
