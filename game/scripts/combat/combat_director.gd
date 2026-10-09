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
								## outcome is also &"blocked" / &"guard_broken" when an enemy's raised guard took the hit
signal launched(info: Dictionary)              ## {attacker, target, launch_mps}
signal telegraphed(info: Dictionary)           ## {attacker, move_id, impact_in_ms, parryable, telegraph_kind}
signal parry_judged(info: Dictionary)          ## {attacker, rating, outcome, delta_ms, position}
signal perfect_dodge(info: Dictionary)         ## {attacker, move_id, position}; the Lamp Flare dodge call-out, so only with `lamp_flare` on
signal perfect_dodge_detected(info: Dictionary)  ## the same info, always (detection stays when `lamp_flare` is off)
signal feature_changed(id: StringName, on: bool)  ## a Features switch flipped (HUD and FX hide or show their part)
signal flare_started(info: Dictionary)         ## {source, duration_s, enemy_scale}
signal flare_ended()
signal stagger(info: Dictionary)               ## {target, by: "parry" / "poise" / "guard"}
signal noise_changed(points: float, fill: float, rank_id: StringName, rank_name: String)
signal noise_rank_changed(rank_id: StringName, rank_name: String, went_up: bool)
signal lights_on_changed(active: bool, duration_s: float)
# ---- the hack battery and the hacks (slice tech plan 4; HUD, FX and audio listen to these) ----
signal battery_changed(charge: float, capacity: float)     ## the hack battery moved (a sword hit, a cast, a door, a reset)
signal hack_locked(active: bool, ms: float)                ## Kasp's Quiet Hours jams (active) or frees the hacks; ms = how long it will last
signal hack_selected(hack_id: StringName)                  ## pick mode: the selected hack changed; auto mode: the last one used
signal hack_cast(info: Dictionary)                         ## {hack, name, cost, position, target}: a cast began (its cost is spent)
signal hack_refused(info: Dictionary)                      ## {hack, name, reason, cost, charge}: the button was pressed and nothing fired (HUD fizz and words)
signal hijack_changed(info: Dictionary)                    ## {target, active, duration_s}: Overclock took something over, or let it go

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
## The hack battery (HackBattery): sword hits fill it, hacks spend it. Owned here so it survives anything Red does.
var battery: HackBattery = null
## Tags a hijacked unit goes for before the nearest enemy (the boss arena sets ["relay"] so a hijacked turret shoots the
## Hushmaster's leg relays). Empty = just the nearest.
var hijack_priority_tags: Array[String] = []
var hit_feel: Dictionary = {}
## True in the game: the fighters' real-time axis follows the engine clock, so a press stamped by `_input`
## lines up. Headless tests that step by hand set it false and use stamp_usec().
var sync_to_wall_clock: bool = true

var _moves: MoveSet = MoveSet.load_default()
var _actors: Array[CombatActor] = []
var _by_id: Dictionary = {}
var _parry_presses: Array[int] = []        # real usec
var _last_dash_real: int = -1
var _threats: Array[Dictionary] = []
var _flared: Dictionary = {}               # attack key -> true
var _flare_cooldown_s: float = 0.0
var _fake_real_usec: int = 0
var _last_noise_points: float = -1.0
var _features_seen: Dictionary = {}         # id -> on, as last applied
var _features_version: int = -1             # Features.version() last applied
var _last_rank_index: int = 0
var _lights_was_active: bool = false
var _last_battery_charge: float = -1.0
var _last_battery_locked: bool = false
var _finishers: Array = []
var _hack_swing: int = 100000000            # swing ids for hack hits start high so they never clash with a move's
## What enemies see of Red (enemy_ai_design 2.1): her current swing, how long her string of hits is, her dash.
var _read: Dictionary = {}
var _swing: Dictionary = {}                 # {id, move_id, class, zone: {enemy id: bool}, end_ms (Red's clock)}
var _combo_len: int = 0
var _stand_in_swings: int = 0
var _combo_last_ms: float = -1.0e9


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
	actor.bind_director(self)
	actor.clock.anchor_real(stamp_usec())
	if actor.team == PLAYER_TEAM:
		time.player_id = actor.actor_id
		if actor.has_signal(&"move_started") and not actor.is_connected(&"move_started", _on_player_move_started):
			actor.connect(&"move_started", _on_player_move_started)
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
	if actor.team == PLAYER_TEAM and actor.has_signal(&"move_started") and actor.is_connected(&"move_started", _on_player_move_started):
		actor.disconnect(&"move_started", _on_player_move_started)


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
		if is_instance_valid(actor) and actor.team == PLAYER_TEAM and not _is_hijacked(actor):
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
	tokens.step(delta)
	if feel.has("enemy_max_attackers"):
		tokens.max_attackers = maxi(int(roundf(feel.get_f("enemy_max_attackers"))), 0)
	_sync_features()
	var red: CombatActor = player()
	if red != null:
		var now_ms: float = red.clock.now_ms()
		if _combo_len > 0 and now_ms - _combo_last_ms > float(_player_read().get("combo_gap_ms", 1200.0)):
			_combo_len = 0
		style.step(now_ms)
		if lights_on.is_active():
			if lights_on.step(now_ms):
				lights_on_changed.emit(false, 0.0)
		elif Features.is_on(Features.LIGHTS_ON) and feel.get_s("lights_on_trigger") == "auto" and lights_on.can_start(style):
			_start_lights_on(now_ms)
		_sync_noise()
	sync_battery()
	_prune_threats()
	_prune_presses()


## Chord mode (`lights_on_trigger` = chord): the player pressed light and heavy together.
func request_lights_on() -> bool:
	_sync_features()
	var red: CombatActor = player()
	if red == null or not Features.is_on(Features.LIGHTS_ON) or not lights_on.can_start(style):
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
## `kind` picks the wind-up cue in fx.json `telegraph.kinds` (default: the move's `telegraph_kind`, else
## "parryable" / "unparryable").
func telegraph(attacker: CombatActor, move_id: StringName, impact_local_usec: int, kind: StringName = &"") -> void:
	var move: Dictionary = _moves.get_move(attacker.move_set_id, move_id)
	var boxes: Array = move.get("hitboxes", [])
	var key: String = "%s:%s:%d" % [attacker.actor_id, move_id, attacker.current_swing_id()]
	if _flared.size() > 256:
		_flared.clear()
	_threats.append({"attacker": attacker.actor_id, "move_id": move_id, "impact_usec": impact_local_usec, "boxes": boxes,
			"flared": false, "dodge_flare": bool(move.get("dodge_flare", true)), "key": key})
	var in_ms: float = float(impact_local_usec - attacker.clock.now_usec()) / 1000.0
	var parryable: bool = bool(move.get("parryable", true))
	if kind == &"":
		kind = StringName(str(move.get("telegraph_kind", "parryable" if parryable else "unparryable")))
	telegraphed.emit({"attacker": attacker.actor_id, "move_id": move_id, "impact_in_ms": in_ms,
			"parryable": parryable, "telegraph_kind": kind})


# ---- what enemies see of Red (enemy_ai_design 2.1, 7) ----

func _player_read() -> Dictionary:
	if _read.is_empty():
		_read = CombatData.enemies().get("player_read", {})
	return _read


func _on_player_move_started(move_id: StringName) -> void:
	begin_player_swing(player(), move_id)


## Red started a swing: work out which enemies stand inside its threat zone (the move's hitboxes grown by
## `threat_margin_m`, also where its lunge ends) and what class of move it is. Enemies roll their defence from this.
## ActionPlayer's `move_started` signal calls it; tests may call it by hand.
func begin_player_swing(red: CombatActor, move_id: StringName) -> void:
	if red == null:
		return
	var move: Dictionary = _moves.get_move(red.move_set_id, move_id)
	var move_class: StringName = EnemyRules.move_class(move_id, move, _player_read().get("move_class", {}))
	var zone: Dictionary = {}
	if move_class != EnemyRules.CLASS_NONE:
		var margin: float = float(hit_feel.get("threat_margin_m", 0.35)) if not hit_feel.is_empty() else 0.35
		var boxes: Array = move.get("hitboxes", [])
		var lunge: float = float((move.get("motion", {}) as Dictionary).get("forward_m", 0.0))
		var base: Transform3D = red.global_transform
		var moved: Transform3D = Transform3D(base.basis, base.origin + red.forward() * lunge)
		for enemy: CombatActor in living_enemies():
			var point: Vector3 = enemy.anchor(&"center")
			var grow: float = margin + enemy.radius_m
			zone[enemy.actor_id] = PerfectDodge.point_in_zone(point, base, boxes, grow) \
					or (lunge > 0.0 and PerfectDodge.point_in_zone(point, moved, boxes, grow))
	_swing = {"id": red.current_swing_id(), "move_id": move_id, "class": move_class, "zone": zone,
			"end_ms": red.clock.now_ms() + float(move.get("total_ms", 400.0))}
	if int(_swing["id"]) == 0:
		_stand_in_swings += 1
		_swing["id"] = -_stand_in_swings      # a stand-in for Red without a runner still gets a fresh id per swing


## What `enemy` sees of Red's current swing: {id, class, threat (it stands in the zone), active, combo_len}.
func player_swing_info(enemy: CombatActor) -> Dictionary:
	var out: Dictionary = {"id": 0, "class": EnemyRules.CLASS_NONE, "threat": false, "active": false, "combo_len": _combo_len}
	if _swing.is_empty():
		return out
	var red: CombatActor = player()
	out["id"] = int(_swing["id"])
	out["class"] = _swing["class"]
	out["threat"] = bool((_swing["zone"] as Dictionary).get(enemy.actor_id, false))
	out["active"] = red != null and red.clock.now_ms() <= float(_swing["end_ms"])
	return out


## How many hits in Red's current string (0 once she stops for `player_read.combo_gap_ms`).
func combo_len() -> int:
	return _combo_len


func _note_player_hit(red_now_ms: float) -> void:
	_combo_len += 1
	_combo_last_ms = red_now_ms


## Is Red dashing toward `enemy`? (An enemy may step away from it.)
func player_dash_toward(enemy: CombatActor) -> bool:
	var red: CombatActor = player()
	if red == null or not red.has_method(&"get_dash"):
		return false
	var dash: DashRun = red.call(&"get_dash") as DashRun
	if dash == null or dash.is_done():
		return false
	var to_enemy: Vector3 = enemy.global_position - red.global_position
	to_enemy.y = 0.0
	var read: Dictionary = _player_read()
	if to_enemy.length() > float(read.get("dash_toward_range_m", 7.0)) or to_enemy.length() < 0.01:
		return false
	return dash.direction.dot(to_enemy.normalized()) >= float(read.get("dash_toward_dot", 0.7))


## An enemy was hit or died: idle allies within their own alert radius notice sooner, and the nearest waiting
## one steps up as the next attacker (enemy_ai_design 7). `event` is &"hit" or &"died".
func alert_allies(source: CombatActor, event: StringName) -> void:
	var nearest: ActionEnemy = null
	var nearest_dist: float = INF
	for ally: CombatActor in living_enemies():
		if ally == source:
			continue
		var enemy: ActionEnemy = ally as ActionEnemy
		if enemy == null or not enemy.hear_ally(source.global_position, event):
			continue
		var dist: float = enemy.global_position.distance_to(source.global_position)
		if enemy.brain != null and enemy.brain.state() == EnemyBrain.CIRCLE and not tokens.has_token(enemy.actor_id) and dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	if nearest != null and event == &"hit":
		nearest.brain.notify(&"step_up")


# ---- contact ----

func report_contact(hitbox: Hitbox, hurtbox: Hurtbox) -> void:
	_ensure_parts()
	_sync_features()
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
	var info: Dictionary = {"attacker": attacker.actor_id, "move_id": move_id, "position": red.anchor(&"head")}
	perfect_dodge_detected.emit(info)
	if Features.is_on(Features.LAMP_FLARE):
		perfect_dodge.emit(info)
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
		red_now_ms: float, by_hack: bool = false) -> void:
	var outcome: StringName = result["outcome"]
	var guard_hit: bool = outcome == HitResolver.OUTCOME_BLOCKED or outcome == HitResolver.OUTCOME_GUARD_BROKEN
	# Red herself: not an enemy Overclock has taken over (its hits are not hers to score).
	var by_red: bool = attacker.team == PLAYER_TEAM and not _is_hijacked(attacker)
	if outcome == HitResolver.OUTCOME_GUARDED:
		var guard_rating: String = ClutchJudge.RATING_NICE
		parry_judged.emit({"attacker": attacker.actor_id, "rating": guard_rating, "outcome": outcome,
				"delta_ms": 0.0, "position": position})
	target.apply_hit(result)
	attacker.on_hit_landed(result)
	# A hack hit freezes only what it hit: the drone, not Red, made the contact.
	var frozen: Array[StringName] = [target.actor_id]
	if not by_hack:
		frozen.append(attacker.actor_id)
	time.add_hit_stop(frozen, float(result["hit_stop_ms"]))
	if by_red and not by_hack:
		_feed_battery(attacker, attack, result, red_now_ms)
	if by_red and outcome != HitResolver.OUTCOME_GUARDED and not guard_hit:
		style.add_hit(StringName(attack.get("move_id", &"")), float(result["style_points"]), red_now_ms)
		if bool(result["launched"]) and float(attack.get("launch_mps", 0.0)) > 0.0:
			style.add_bonus(&"launch", red_now_ms)
		elif bool(result["air_hit"]):
			style.add_bonus(&"air_hit", red_now_ms)
	elif by_red and outcome == HitResolver.OUTCOME_GUARD_BROKEN:
		style.add_bonus(&"guard_break", red_now_ms)      # worth points once style.json has bonuses.guard_break
	elif target.team == PLAYER_TEAM and int(result["damage"]) > 0 and not lights_on.is_active():
		style.took_damage(red_now_ms)
	if by_red and not by_hack and outcome != HitResolver.OUTCOME_IGNORED:
		_note_player_hit(red_now_ms)
	elif target.team == PLAYER_TEAM and int(result["damage"]) > 0:
		_combo_len = 0
	hp_changed.emit(target.actor_id, target.hp, target.hp_max)
	var spark: String = str(attack.get("spark", ""))
	var sfx: String = str(attack.get("sfx", ""))
	var shake: String = str(attack.get("shake", ""))
	if guard_hit:
		var feedback: Dictionary = result.get("feedback", {})
		spark = str(feedback.get("spark", "guard"))
		sfx = str(feedback.get("sfx", "combat_hit_light"))
		if outcome == HitResolver.OUTCOME_GUARD_BROKEN:
			var broke: Dictionary = _moves.get_move(target.move_set_id, &"block_break")
			spark = str(broke.get("spark", "heavy"))
			sfx = str(broke.get("sfx", "combat_hit_heavy"))
			shake = str(broke.get("shake", "medium"))
	hit_landed.emit({"attacker": attacker.actor_id, "target": target.actor_id, "move_id": result["move_id"],
			"outcome": outcome, "damage": int(result["damage"]), "launch": float(result["launch_mps"]),
			"knockdown": bool(result["knockdown"]), "airborne": bool(result["air_hit"]),
			"hit_stop_ms": float(result["hit_stop_ms"]), "shake": shake,
			"spark": spark, "sfx": sfx, "position": position, "source": str(result.get("source", "sword"))})
	if bool(result["launched"]):
		launched.emit({"attacker": attacker.actor_id, "target": target.actor_id, "launch_mps": float(result["launch_mps"])})
	if bool(result["staggered_target"]):
		stagger.emit({"target": target.actor_id, "by": "guard" if outcome == HitResolver.OUTCOME_GUARD_BROKEN else "poise"})


# ---- the hack battery (slice tech plan 4.2) ----

## A sword hit by Red landed: fill the battery by what the outcome is worth (a finisher and an air hit add a bonus).
func _feed_battery(_attacker: CombatActor, attack: Dictionary, result: Dictionary, now_ms: float) -> void:
	if battery == null:
		return
	var move_id: StringName = StringName(str(attack.get("move_id", &"")))
	if _finishers.is_empty():
		_finishers = ((CombatData.combo().get("params", {}) as Dictionary).get("finishers", []) as Array).duplicate()
	var scale: float = feel.get_f("hack_gain_scale") if feel != null and feel.has("hack_gain_scale") else 1.0
	battery.add_from_hit(result["outcome"], move_id, bool(result.get("air_hit", false)), _finishers.has(String(move_id)),
			now_ms, scale, StringName(str(attack.get("source", HackBattery.SOURCE_SWORD))))
	sync_battery()


## A hack (a Zap Drone, an EMP pulse, a hijacked turret's shot) hit `target`. Same chain as a sword hit: resolver,
## apply, hit-stop on the victim, sparks, numbers, launches and the enemy's reaction. `hit` is a moves.json style `hit`
## block (damage, hitstun_ms, knockback_m, hit_stop_ms, poise_damage, style_points, spark, shake, sfx, guard_break...).
## `info` may carry `position` (the contact point), `origin` and `direction` (where the shot came from, for knockback
## and the guard arc) and `move_id`. The attacker is `source`. Hack hits never refill the battery.
## Returns the HitResolver result (plus position and source), `outcome == ignored` when nothing happened.
func report_hack_hit(source: CombatActor, target: CombatActor, hit: Dictionary, info: Dictionary = {}) -> Dictionary:
	_ensure_parts()
	_sync_features()
	if source == null or target == null:
		return {"outcome": HitResolver.OUTCOME_IGNORED}
	var attack: Dictionary = hit.duplicate(true)
	_hack_swing += 1
	attack["move_id"] = StringName(str(info.get("move_id", hit.get("move_id", &"hack"))))
	attack["swing_id"] = _hack_swing
	attack["launcher"] = bool(hit.get("launcher", false))
	attack["parryable"] = false
	attack["dodge_flare"] = false
	attack["source"] = str(info.get("source", "hack"))
	var snap: Dictionary = source.snapshot()
	if info.has("origin"):
		snap["position"] = info["origin"]
	if info.has("direction"):
		snap["forward"] = info["direction"]
	var ctx: Dictionary = {"parry": {"rating": ClutchJudge.RATING_MISS}, "lights_on": _lights_ctx(), "feel": feel, "hit_feel": hit_feel}
	var result: Dictionary = HitResolver.resolve(attack, snap, target.snapshot(), ctx)
	result["source"] = attack["source"]
	var outcome: StringName = result["outcome"]
	if outcome == HitResolver.OUTCOME_IGNORED or outcome == HitResolver.OUTCOME_EVADED:
		return result
	var position: Vector3 = info.get("position", target.anchor(&"center"))
	result["position"] = position
	_on_damage(source, target, attack, result, position, _red_now_ms(), true)
	_sync_noise()
	return result


## The battery moved or the lock changed: tell the HUD. Cheap when nothing did. Free casting (a testing knob) keeps it full.
func sync_battery() -> void:
	_ensure_parts()
	if feel != null and feel.has("hack_free_cast") and feel.get_b("hack_free_cast") and not battery.is_full():
		battery.reset_full()
	var charge: float = battery.charge()
	if not is_equal_approx(charge, _last_battery_charge):
		_last_battery_charge = charge
		battery_changed.emit(charge, battery.capacity())
	var now_ms: float = _red_now_ms()
	var locked: bool = battery.is_locked(now_ms)
	if locked != _last_battery_locked:
		_last_battery_locked = locked
		hack_locked.emit(locked, battery.lock_left_ms(now_ms))


## Kasp's Quiet Hours: the hacks are jammed for `ms` of Red's time.
func lock_hacks(ms: float) -> void:
	_ensure_parts()
	battery.lock(ms, _red_now_ms())
	sync_battery()


## The jam ends early (the dish is hit during the hum).
func unlock_hacks() -> void:
	_ensure_parts()
	battery.unlock()
	sync_battery()


func hacks_locked() -> bool:
	_ensure_parts()
	return battery.is_locked(_red_now_ms())


## Back to a fresh run: new-game charge, no jam, no recent gains. (The arena reset calls it.)
func reset_hacks() -> void:
	_ensure_parts()
	battery.reset_start()
	sync_battery()


## Is `actor` an enemy that Overclock has taken over (it is on Red's side for now)?
static func _is_hijacked(actor: CombatActor) -> bool:
	return "hijacked_by" in actor and actor.get("hijacked_by") != null


# ---- the Lamp Flare ----

func _start_flare(source: String, red: CombatActor) -> void:
	if not Features.is_on(Features.LAMP_FLARE) or time.is_flaring() or _flare_cooldown_s > 0.0:
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
	if battery == null:
		battery = HackBattery.load_default()
	if not time.flare_ended.is_connected(_on_flare_ended):
		time.flare_ended.connect(_on_flare_ended)


func _lights_ctx() -> Dictionary:
	if not Features.is_on(Features.LIGHTS_ON):
		return {"active": false, "damage_mult": 1.0, "super_armor": false}
	var buffs: Dictionary = lights_on.buffs()
	return {"active": lights_on.is_active(), "damage_mult": buffs["damage_mult"], "super_armor": buffs["super_armor"]}


## Applies any feature switch that flipped since the last look: ends what the switch controls, tells the listeners.
## Cheap when nothing changed (one integer compare), so every entry point calls it.
func _sync_features() -> void:
	if _features_version == Features.version() and _features_seen.size() == Features.IDS.size():
		return
	_ensure_parts()
	_features_version = Features.version()
	var noise_on: bool = Features.is_on(Features.NOISE_METER)
	style.enabled = noise_on
	for id: StringName in Features.IDS:
		var on: bool = Features.is_on(id)
		var first_look: bool = not _features_seen.has(id)
		var was: bool = bool(_features_seen.get(id, true))
		_features_seen[id] = on
		if on == was and not first_look:
			continue
		if not on:
			_switch_off(id)
		if not first_look:
			feature_changed.emit(id, on)


func _switch_off(id: StringName) -> void:
	match id:
		Features.LIGHTS_ON:
			_end_lights_on()
		Features.LAMP_FLARE:
			time.end_flare()
		Features.NOISE_METER:
			_end_lights_on()            # Lights On is paid for with a full Noise meter
			style.reset()
			_sync_noise()


func _end_lights_on() -> void:
	if lights_on != null and lights_on.is_active():
		lights_on.end()
		lights_on_changed.emit(false, 0.0)


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
