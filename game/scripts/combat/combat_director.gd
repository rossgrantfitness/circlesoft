class_name CombatDirector
extends Node
## The referee of a fight (contract 4.2, 4.3, 4.4, 4.6). One per arena, in group `combat_director`, stepping
## before every fighter (process_physics_priority -100). It owns the rules of time (CombatTime), Noise
## (StyleMeter), Lights On, the attack tokens and the feel knobs, keeps the list of fighters, and turns a
## hitbox touching a hurtbox into a result: judge the parry, resolve, apply, freeze both sides, feed Noise,
## start a Lamp Flare, and announce it all through the signals below (HUD, FX and audio listen to these).

# ---- signals (contract 4.6) ----
signal actor_registered(actor_id: StringName, team: StringName)
signal actor_died(actor_id: StringName)
signal hp_changed(actor_id: StringName, hp: int, hp_max: int)
signal move_started(info: Dictionary)          ## {actor, move_id, swing_sfx, trail}
signal hit_landed(info: Dictionary)            ## {attacker, target, move_id, outcome, damage, launch, knockdown, airborne, hit_stop_ms, shake, spark, sfx, position}
signal launched(info: Dictionary)              ## {attacker, target, launch_mps}
signal telegraphed(info: Dictionary)           ## {attacker, move_id, impact_in_ms, parryable}
signal parry_judged(info: Dictionary)          ## {attacker, rating, outcome, delta_ms, position}
signal perfect_dodge(info: Dictionary)         ## {attacker, move_id, position}
signal flare_started(info: Dictionary)         ## {source, duration_s, enemy_scale}
signal flare_ended()
signal stagger(info: Dictionary)               ## {target, by}
signal noise_changed(points: float, fill: float, rank_id: StringName, rank_name: String)
signal noise_rank_changed(rank_id: StringName, rank_name: String, went_up: bool)
signal lights_on_changed(active: bool, duration_s: float)

const GROUP: StringName = &"combat_director"
const PRIORITY: int = -100
const PLAYER_TEAM: StringName = &"player"
const ENEMY_TEAM: StringName = &"enemy"
const THREAT_GRACE_MS: float = 250.0
const PRESS_KEEP_USEC: int = 3000000

var time: CombatTime = CombatTime.new()
var style: StyleMeter = null
var lights_on: LightsOn = null
var tokens: AttackTokens = null
var feel: FeelKnobs = null
var hit_feel: Dictionary = {}
## True in the game: the fighters' real-time axis follows the engine clock, so a press stamped by `_input`
## lines up. Headless tests that step by hand set it false and use stamp_usec().
var sync_to_wall_clock: bool = true

var _actors: Array[CombatActor] = []
var _by_id: Dictionary = {}
var _parry_presses: Array[int] = []        # real usec
var _last_dash_real: int = -1
var _threats: Array[Dictionary] = []
var _flared: Dictionary = {}               # attack key -> true
var _flare_cooldown_s: float = 0.0
var _fake_real_usec: int = 0
var _last_noise_points: float = -1.0
var _last_rank_index: int = 0
var _lights_was_active: bool = false


func _init() -> void:
	process_physics_priority = PRIORITY


func _ready() -> void:
	add_to_group(GROUP)
	process_physics_priority = PRIORITY
	if feel == null:
		feel = FeelKnobs.load_defaults()
		feel.load_user()
	if hit_feel.is_empty():
		hit_feel = CombatData.hit_feel()
	if style == null:
		style = StyleMeter.from_data(CombatData.style())
	if lights_on == null:
		lights_on = LightsOn.from_data(CombatData.style(), style)
	if tokens == null:
		tokens = AttackTokens.from_data(CombatData.enemies())
	_fake_real_usec = Time.get_ticks_usec()
	for node: Node in get_tree().get_nodes_in_group(CombatActor.GROUP):
		var actor: CombatActor = node as CombatActor
		if actor != null:
			register(actor)


func _physics_process(delta: float) -> void:
	tick(delta)


# ---- registry ----

func register(actor: CombatActor) -> void:
	if actor == null or _actors.has(actor):
		return
	_ensure_parts()
	_actors.append(actor)
	_by_id[actor.actor_id] = actor
	actor._set_director(self)
	actor.clock.anchor_real(stamp_usec())
	if actor.team == PLAYER_TEAM:
		time.player_id = actor.actor_id
	if not actor.died.is_connected(_on_actor_died):
		actor.died.connect(_on_actor_died)
	actor_registered.emit(actor.actor_id, actor.team)
	hp_changed.emit(actor.actor_id, actor.hp, actor.hp_max)


func unregister(actor: CombatActor) -> void:
	if not _actors.has(actor):
		return
	_actors.erase(actor)
	if _by_id.get(actor.actor_id, null) == actor:
		_by_id.erase(actor.actor_id)
	if tokens != null:
		tokens.release(actor.actor_id)
	if actor.died.is_connected(_on_actor_died):
		actor.died.disconnect(_on_actor_died)


func actors(team: StringName = &"") -> Array[CombatActor]:
	var out: Array[CombatActor] = []
	for actor: CombatActor in _actors:
		if is_instance_valid(actor) and (team == &"" or actor.team == team):
			out.append(actor)
	return out


func get_actor(actor_id: StringName) -> CombatActor:
	return _by_id.get(actor_id, null)


## Red (the first registered fighter on the player team), or null.
func player() -> CombatActor:
	for actor: CombatActor in _actors:
		if is_instance_valid(actor) and actor.team == PLAYER_TEAM:
			return actor
	return null


## Enemies that are still on their feet.
func living_enemies() -> Array[CombatActor]:
	var out: Array[CombatActor] = []
	for actor: CombatActor in actors(ENEMY_TEAM):
		if not actor.dead:
			out.append(actor)
	return out


# ---- time ----

## "Real now" on the clock axis the fighters use: the engine clock in the game, a counter in tests.
func stamp_usec() -> int:
	return Time.get_ticks_usec() if sync_to_wall_clock else _fake_real_usec


func delta_for(actor: CombatActor, real_delta: float) -> float:
	return time.delta_for(actor.actor_id, real_delta)


## One director step (the physics process calls this; tests call it by hand).
func tick(delta: float) -> void:
	_ensure_parts()
	time.step(delta)
	var delta_usec: int = int(roundf(delta * 1000000.0))
	_fake_real_usec += delta_usec
	for actor: CombatActor in _actors:
		if not is_instance_valid(actor):
			continue
		actor.clock.step(delta_usec, time.step_scale_for(actor.actor_id, delta))
		if sync_to_wall_clock:
			actor.clock.sync_real(Time.get_ticks_usec())
	if not time.is_flaring():
		_flare_cooldown_s = maxf(_flare_cooldown_s - delta, 0.0)
	var red: CombatActor = player()
	if red != null:
		var now_ms: float = red.clock.now_ms()
		style.step(now_ms)
		if lights_on.is_active():
			if lights_on.step(now_ms):
				lights_on_changed.emit(false, 0.0)
		elif feel.get_s("lights_on_trigger") == "auto" and lights_on.can_start(style):
			_start_lights_on(now_ms)
		_sync_noise()
	_prune_threats()
	_prune_presses()


## Chord mode (`lights_on_trigger` = chord): the player pressed light and heavy together.
func request_lights_on() -> bool:
	var red: CombatActor = player()
	if red == null or not lights_on.can_start(style):
		return false
	_start_lights_on(red.clock.now_ms())
	_sync_noise()
	return true


func _start_lights_on(now_ms: float) -> void:
	lights_on.start(now_ms)
	lights_on_changed.emit(true, lights_on.duration_s())


# ---- announcements from the fighters ----

## A fighter's swing began (sound, trail). `swing` is the move's `swing` block.
func notify_move_started(actor: CombatActor, move_id: StringName, swing: Dictionary) -> void:
	move_started.emit({"actor": actor.actor_id, "move_id": move_id,
			"swing_sfx": str(swing.get("sfx", "")), "trail": bool(swing.get("trail", false))})


## Red pressed parry and the brace started. `real_usec` is the `_input` timestamp.
func report_parry_press(real_usec: int) -> void:
	_parry_presses.append(real_usec)


## Red started a dash. Opens the perfect-dodge check against every attack that is winding up.
func report_dash(real_usec: int) -> void:
	_last_dash_real = real_usec
	var red: CombatActor = player()
	if red == null:
		return
	var window_ms: float = feel.get_f("perfect_dodge_window_ms")
	var margin: float = float(hit_feel.get("threat_margin_m", 0.35))
	for threat: Dictionary in _threats:
		var attacker: CombatActor = get_actor(threat["attacker"])
		if attacker == null or bool(threat["flared"]) or not bool(threat["dodge_flare"]):
			continue
		var dash_local: int = attacker.clock.local_at_real(real_usec)
		var in_zone: bool = PerfectDodge.point_in_zone(red.anchor(&"center"), attacker.global_transform, threat["boxes"], margin)
		if PerfectDodge.is_perfect(dash_local, int(threat["impact_usec"]), window_ms, in_zone):
			_do_perfect_dodge(attacker, StringName(threat["move_id"]), threat, red)


## An enemy move reached its telegraph: remember it as a threat, and tell the HUD and FX.
func telegraph(attacker: CombatActor, move_id: StringName, impact_local_usec: int) -> void:
	var move: Dictionary = MoveSet.load_default().get_move(StringName(attacker.get("move_set_id")) if attacker.get("move_set_id") != null else &"", move_id)
	var boxes: Array = move.get("hitboxes", [])
	var key: String = "%s:%s:%d" % [attacker.actor_id, move_id, attacker.current_swing_id()]
	_threats.append({"attacker": attacker.actor_id, "move_id": move_id, "impact_usec": impact_local_usec, "boxes": boxes,
			"flared": false, "dodge_flare": bool(move.get("dodge_flare", true)), "key": key})
	var in_ms: float = float(impact_local_usec - attacker.clock.now_usec()) / 1000.0
	telegraphed.emit({"attacker": attacker.actor_id, "move_id": move_id, "impact_in_ms": in_ms,
			"parryable": bool(move.get("parryable", true))})


# ---- contact ----

func report_contact(hitbox: Hitbox, hurtbox: Hurtbox) -> void:
	_ensure_parts()
	var attacker: CombatActor = hitbox.owner_actor()
	var target: CombatActor = hurtbox.owner_actor()
	if attacker == null or target == null:
		return
	var attack: Dictionary = hitbox.attack_data()
	var parry: Dictionary = _judge_parry(attacker, target, attack)
	var ctx: Dictionary = {"parry": parry, "lights_on": _lights_ctx(), "feel": feel, "hit_feel": hit_feel}
	var result: Dictionary = HitResolver.resolve(attack, attacker.snapshot(), target.snapshot(), ctx)
	var outcome: StringName = result["outcome"]
	if outcome == HitResolver.OUTCOME_IGNORED:
		return
	var position: Vector3 = hitbox.contact_point
	result["position"] = position
	var red_now_ms: float = _red_now_ms()
	match outcome:
		HitResolver.OUTCOME_EVADED:
			_on_evaded(attacker, target, attack)
		HitResolver.OUTCOME_PERFECT_PARRY, HitResolver.OUTCOME_PARRIED:
			_on_parry(attacker, target, attack, result, parry, position, red_now_ms)
		_:
			_on_damage(attacker, target, attack, result, position, red_now_ms)
	_sync_noise()


func _judge_parry(attacker: CombatActor, target: CombatActor, attack: Dictionary) -> Dictionary:
	var out: Dictionary = {"rating": ClutchJudge.RATING_MISS, "delta_ms": 0.0, "pressed": false}
	if target.team != PLAYER_TEAM or attacker.team == target.team or not bool(attack.get("parryable", true)):
		return out
	var presses: Array[int] = []
	for real: int in _parry_presses:
		presses.append(attacker.clock.local_at_real(real))
	var modifiers: Dictionary = CombatData.timing_windows().get("modifiers", {})
	var config: Node = _config()
	var wide: bool = bool(config.get("wide_windows")) if config != null else false
	var offset: int = int(config.get("timing_offset_ms")) if config != null else 0
	var mult: float = ParryJudge.window_mult(modifiers, wide, feel.get_f("parry_window_scale"))
	out = ParryJudge.judge(presses, attacker.clock.now_usec(), CombatData.parry_window(), mult, offset, CombatData.parry_listen_ms())
	_parry_presses.clear()       # one press, one judgment
	return out


func _on_evaded(attacker: CombatActor, target: CombatActor, attack: Dictionary) -> void:
	if target.team != PLAYER_TEAM or not bool(attack.get("dodge_flare", true)) or _last_dash_real < 0:
		return
	var key: String = "%s:%s:%d" % [attacker.actor_id, attack.get("move_id", &""), int(attack.get("swing_id", 0))]
	if _flared.has(key):
		return
	var dash_local: int = attacker.clock.local_at_real(_last_dash_real)
	if PerfectDodge.is_perfect(dash_local, attacker.clock.now_usec(), feel.get_f("perfect_dodge_window_ms"), true):
		_do_perfect_dodge(attacker, StringName(attack.get("move_id", &"")), {"key": key}, target)


func _do_perfect_dodge(attacker: CombatActor, move_id: StringName, threat: Dictionary, red: CombatActor) -> void:
	threat["flared"] = true
	_flared[str(threat.get("key", ""))] = true
	style.add_bonus(&"perfect_dodge", red.clock.now_ms())
	perfect_dodge.emit({"attacker": attacker.actor_id, "move_id": move_id, "position": red.anchor(&"head")})
	_start_flare("dodge", red)


func _on_parry(attacker: CombatActor, target: CombatActor, attack: Dictionary, result: Dictionary, parry: Dictionary,
		position: Vector3, red_now_ms: float) -> void:
	var rating: String = str(parry.get("rating", ClutchJudge.RATING_MISS))
	target.apply_hit(result)
	attacker.on_parried(result)
	time.add_hit_stop([attacker.actor_id, target.actor_id] as Array[StringName], float(result["hit_stop_ms"]))
	var perfect: bool = rating == ClutchJudge.RATING_TOTALLY_RAD
	style.add_bonus(&"perfect_parry" if perfect else &"parry", red_now_ms)
	parry_judged.emit({"attacker": attacker.actor_id, "rating": rating, "outcome": result["outcome"],
			"delta_ms": float(parry.get("delta_ms", 0.0)), "position": position})
	if perfect:
		stagger.emit({"target": attacker.actor_id, "by": "parry"})
	var mode: String = feel.get_s("flare_on_parry")
	if (mode == "rad_and_up" and rating != ClutchJudge.RATING_NICE) or (mode == "perfect_only" and perfect):
		_start_flare("parry", target)
	hp_changed.emit(target.actor_id, target.hp, target.hp_max)


func _on_damage(attacker: CombatActor, target: CombatActor, attack: Dictionary, result: Dictionary, position: Vector3,
		red_now_ms: float) -> void:
	var outcome: StringName = result["outcome"]
	if outcome == HitResolver.OUTCOME_GUARDED:
		var guard_rating: String = ClutchJudge.RATING_NICE
		parry_judged.emit({"attacker": attacker.actor_id, "rating": guard_rating, "outcome": outcome,
				"delta_ms": 0.0, "position": position})
	target.apply_hit(result)
	attacker.on_hit_landed(result)
	time.add_hit_stop([attacker.actor_id, target.actor_id] as Array[StringName], float(result["hit_stop_ms"]))
	if attacker.team == PLAYER_TEAM and outcome != HitResolver.OUTCOME_GUARDED:
		style.add_hit(StringName(attack.get("move_id", &"")), float(result["style_points"]), red_now_ms)
		if bool(result["launched"]) and float(attack.get("launch_mps", 0.0)) > 0.0:
			style.add_bonus(&"launch", red_now_ms)
		elif bool(result["air_hit"]):
			style.add_bonus(&"air_hit", red_now_ms)
	elif target.team == PLAYER_TEAM and int(result["damage"]) > 0 and not lights_on.is_active():
		style.took_damage(red_now_ms)
	hp_changed.emit(target.actor_id, target.hp, target.hp_max)
	hit_landed.emit({"attacker": attacker.actor_id, "target": target.actor_id, "move_id": result["move_id"],
			"outcome": outcome, "damage": int(result["damage"]), "launch": float(result["launch_mps"]),
			"knockdown": bool(result["knockdown"]), "airborne": bool(result["air_hit"]),
			"hit_stop_ms": float(result["hit_stop_ms"]), "shake": str(attack.get("shake", "")),
			"spark": str(attack.get("spark", "")), "sfx": str(attack.get("sfx", "")), "position": position})
	if bool(result["launched"]):
		launched.emit({"attacker": attacker.actor_id, "target": target.actor_id, "launch_mps": float(result["launch_mps"])})
	if bool(result["staggered_target"]):
		stagger.emit({"target": target.actor_id, "by": "poise"})


# ---- the Lamp Flare ----

func _start_flare(source: String, red: CombatActor) -> void:
	if time.is_flaring() or _flare_cooldown_s > 0.0:
		return
	var radius: float = feel.get_f("flare_glare_radius_m")
	var ids: Array[StringName] = []
	for enemy: CombatActor in actors(ENEMY_TEAM):
		if not enemy.dead and enemy.global_position.distance_to(red.global_position) <= radius:
			ids.append(enemy.actor_id)
	var duration: float = feel.get_f("flare_duration_s")
	var speed: float = feel.get_f("flare_enemy_speed")
	time.start_flare(duration, speed, ids)
	_flare_cooldown_s = feel.get_f("flare_cooldown_s")
	flare_started.emit({"source": source, "duration_s": duration, "enemy_scale": speed})


func _on_flare_ended() -> void:
	flare_ended.emit()


# ---- helpers ----

func _ensure_parts() -> void:
	if feel == null:
		feel = FeelKnobs.load_defaults()
	if hit_feel.is_empty():
		hit_feel = CombatData.hit_feel()
	if style == null:
		style = StyleMeter.from_data(CombatData.style())
	if lights_on == null:
		lights_on = LightsOn.from_data(CombatData.style(), style)
	if tokens == null:
		tokens = AttackTokens.from_data(CombatData.enemies())
	if not time.flare_ended.is_connected(_on_flare_ended):
		time.flare_ended.connect(_on_flare_ended)


func _lights_ctx() -> Dictionary:
	var buffs: Dictionary = lights_on.buffs()
	return {"active": lights_on.is_active(), "damage_mult": buffs["damage_mult"], "super_armor": buffs["super_armor"]}


func _red_now_ms() -> float:
	var red: CombatActor = player()
	return red.clock.now_ms() if red != null else 0.0


func _config() -> Node:
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	return tree.root.get_node_or_null("Config") if tree != null else null


func _on_actor_died(actor_id: StringName) -> void:
	actor_died.emit(actor_id)
	if tokens != null:
		tokens.release(actor_id)


func _sync_noise() -> void:
	var points: float = style.points()
	if absf(points - _last_noise_points) > 0.01:
		_last_noise_points = points
		var rank: Dictionary = style.rank()
		noise_changed.emit(points, style.fill(), rank["id"], str(rank["name"]))
		var index: int = int(rank["index"])
		if index != _last_rank_index:
			noise_rank_changed.emit(rank["id"], str(rank["name"]), index > _last_rank_index)
			_last_rank_index = index


func _prune_threats() -> void:
	var kept: Array[Dictionary] = []
	for threat: Dictionary in _threats:
		var attacker: CombatActor = get_actor(threat["attacker"])
		if attacker != null and not attacker.dead and float(attacker.clock.now_usec() - int(threat["impact_usec"])) / 1000.0 <= THREAT_GRACE_MS:
			kept.append(threat)
	_threats = kept


func _prune_presses() -> void:
	var limit: int = stamp_usec() - PRESS_KEEP_USEC
	var kept: Array[int] = []
	for real: int in _parry_presses:
		if real >= limit:
			kept.append(real)
	_parry_presses = kept
