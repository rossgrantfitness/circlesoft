class_name HitResolver
extends RefCounted
## Decides what one hit does (contract 4.2). Pure: attack data, two snapshots and a context in, a result out.
## The first matching row wins:
##   1 same team, or target dead          -> ignored
##   2 target invulnerable (i-frames)     -> evaded
##   3 target is Red and a parry rating   -> perfect_parry / parried / guarded
##   3b target has its guard up and the hit comes from the front arc -> blocked / guard_broken
##   4 target armored, poise survives     -> armored
##   5 otherwise                          -> hit (or stagger if this hit broke poise)
##
## attack   = the move's `hit` block + {move_id, launcher, swing_id, parryable}
## attacker, target = CombatActor.snapshot() (+ position, forward, weight)
##          An enemy with its guard up adds `guard` = {up, arc_deg, meter, break_poise, break_by_launcher, chip_scale,
##          min_chip, knockback_scale, hit_stop_scale, break_ms, spark, sfx}; one that is running away adds `flee_knockdown`.
## ctx      = {parry: {rating}, lights_on: {active, damage_mult, super_armor}, feel: FeelKnobs, hit_feel: Dictionary}

const OUTCOME_IGNORED: StringName = &"ignored"
const OUTCOME_EVADED: StringName = &"evaded"
const OUTCOME_PERFECT_PARRY: StringName = &"perfect_parry"
const OUTCOME_PARRIED: StringName = &"parried"
const OUTCOME_GUARDED: StringName = &"guarded"
const OUTCOME_BLOCKED: StringName = &"blocked"
const OUTCOME_GUARD_BROKEN: StringName = &"guard_broken"
const OUTCOME_ARMORED: StringName = &"armored"
const OUTCOME_HIT: StringName = &"hit"
const OUTCOME_STAGGER: StringName = &"stagger"
const TEAM_PLAYER: StringName = &"player"
const FREEZE_KNOB: String = "hit_freeze_s"


static func resolve(attack: Dictionary, attacker: Dictionary, target: Dictionary, ctx: Dictionary) -> Dictionary:
	var feel: FeelKnobs = ctx.get("feel", null)
	var hit_feel: Dictionary = ctx.get("hit_feel", {})
	if hit_feel.is_empty():
		hit_feel = CombatData.hit_feel()
	var result: Dictionary = _blank(attack, attacker, target)

	# 1: nothing to do
	if attacker.get("team", &"") == target.get("team", &"") or int(target.get("hp", 1)) <= 0:
		result["outcome"] = OUTCOME_IGNORED
		return result
	# 2: i-frames
	if bool(target.get("invulnerable", false)):
		result["outcome"] = OUTCOME_EVADED
		return result

	var hit_stop_scale: float = (feel.get_f("hit_stop_scale") if feel != null and feel.has("hit_stop_scale") else 1.0) \
			* freeze_scale(feel, hit_feel)
	var launch_scale: float = feel.get_f("launch_height_scale") if feel != null and feel.has("launch_height_scale") else 1.0
	var base_damage: float = float(attack.get("damage", 0))
	var lights: Dictionary = ctx.get("lights_on", {})
	if attacker.get("team", &"") == TEAM_PLAYER and bool(lights.get("active", false)):
		base_damage *= float(lights.get("damage_mult", 1.0))
	if target.get("team", &"") == TEAM_PLAYER and feel != null and feel.has("enemy_damage_scale"):
		base_damage *= feel.get_f("enemy_damage_scale")

	# 3: Red's parry
	var rating: String = str((ctx.get("parry", {}) as Dictionary).get("rating", ClutchJudge.RATING_MISS))
	result["parry_rating"] = rating
	if target.get("team", &"") == TEAM_PLAYER and bool(attack.get("parryable", true)) and rating != ClutchJudge.RATING_MISS:
		var parry_cfg: Dictionary = hit_feel.get("parry", {})
		match rating:
			ClutchJudge.RATING_TOTALLY_RAD:
				result["outcome"] = OUTCOME_PERFECT_PARRY
				result["hit_stop_ms"] = float(parry_cfg.get("perfect_hit_stop_ms", 140.0)) * hit_stop_scale
				result["staggered_attacker"] = true
				return result
			ClutchJudge.RATING_RAD:
				result["outcome"] = OUTCOME_PARRIED
				result["hit_stop_ms"] = float(parry_cfg.get("parried_hit_stop_ms", 90.0)) * hit_stop_scale
				return result
			_:
				var reduction: float = _block_reduction(ctx, ClutchJudge.RATING_NICE)
				var guard: Dictionary = hit_feel.get("guard", {})
				result["outcome"] = OUTCOME_GUARDED
				result["damage"] = _damage(base_damage * (1.0 - reduction), base_damage > 0.0 and reduction < 1.0)
				result["hitstun_ms"] = float(attack.get("hitstun_ms", 0.0)) * float(guard.get("hitstun_scale", 0.4))
				result["knockback"] = _push(attack, attacker, target, hit_feel) * float(guard.get("knockback_scale", 0.5))
				result["hit_stop_ms"] = float(attack.get("hit_stop_ms", 0.0)) * hit_stop_scale
				result["poise_after"] = float(target.get("poise", 0.0))
				result["juggle_count"] = 0
				return result

	# 3b: an enemy's raised guard (the front arc only; a hit from the side or behind ignores it)
	var guard: Dictionary = target.get("guard", {})
	if not guard.is_empty() and bool(guard.get("up", false)) and not bool(attack.get("unblockable", false)) \
			and EnemyRules.in_front_arc(Vector3(target.get("position", Vector3.ZERO)), Vector3(target.get("forward", Vector3.BACK)),
					Vector3(attacker.get("position", Vector3.ZERO)), float(guard.get("arc_deg", 150.0))):
		return _resolve_guard(result, attack, attacker, target, guard, base_damage, hit_stop_scale, hit_feel)

	var damage: int = _damage(base_damage, base_damage > 0.0)
	var poise_max: float = float(target.get("poise_max", 0.0))
	var poise_now: float = float(target.get("poise", poise_max))
	var poise_after: float = maxf(poise_now - float(attack.get("poise_damage", 0.0)), 0.0)
	var poise_survives: bool = poise_max <= 0.0 or poise_after > 0.0
	var armored: bool = bool(target.get("armored", false)) or (target.get("team", &"") == TEAM_PLAYER and bool(lights.get("super_armor", false)) and bool(lights.get("active", false)))

	# 4: armor soaks the hit
	if armored and poise_survives:
		result["outcome"] = OUTCOME_ARMORED
		result["damage"] = damage
		result["hit_stop_ms"] = float(attack.get("hit_stop_ms", 0.0)) * hit_stop_scale * float((hit_feel.get("armored", {}) as Dictionary).get("hit_stop_scale", 0.5))
		result["poise_after"] = poise_after if poise_max > 0.0 else 0.0
		result["style_points"] = float(attack.get("style_points", 0.0))
		result["armored"] = true
		result["juggle_count"] = 0
		return result

	# 5: a real hit
	var broke: bool = poise_max > 0.0 and poise_after <= 0.0
	result["outcome"] = OUTCOME_STAGGER if broke else OUTCOME_HIT
	result["staggered_target"] = broke
	result["damage"] = damage
	result["poise_after"] = poise_max if broke else poise_after
	result["style_points"] = float(attack.get("style_points", 0.0))
	result["hit_stop_ms"] = float(attack.get("hit_stop_ms", 0.0)) * hit_stop_scale
	var hitstun: float = float(attack.get("hitstun_ms", 0.0))
	if broke:
		hitstun = maxf(hitstun, float(hit_feel.get("stagger_ms", 1100.0)))
	result["hitstun_ms"] = hitstun
	result["knockback"] = _push(attack, attacker, target, hit_feel)

	var airborne: bool = bool(target.get("airborne", false))
	var count: int = int(target.get("juggle_count", 0))
	var launchable: bool = bool(target.get("launchable", true))
	var launch: float = 0.0
	var knockdown: bool = bool(attack.get("knockdown", false)) and (launchable or broke)
	if bool(target.get("flee_knockdown", false)):
		knockdown = true        # a hit on an enemy that is running away always knocks it down
	if launchable:
		var launch_mps: float = float(attack.get("launch_mps", 0.0))
		if JuggleRules.can_juggle(count):
			if launch_mps > 0.0:
				launch = JuggleRules.lift_for(launch_mps, count)
			elif airborne:
				launch = JuggleRules.air_lift_for(count)
		elif airborne:
			knockdown = true       # juggle cap reached: the next hit drops them
		launch *= launch_scale
		if knockdown and airborne:
			launch = 0.0        # a slam drops them instead of lifting them
	result["launch_mps"] = launch
	result["launched"] = launch > 0.0
	result["knockdown"] = knockdown
	result["air_hit"] = airborne
	if launch > 0.0 or airborne:
		result["juggle_count"] = count + 1
	else:
		result["juggle_count"] = 0
	result["lethal"] = int(target.get("hp", 0)) - damage <= 0
	return result


## A raised guard takes the hit: chip damage, no hit-stun, little push. A Launcher, a hit with `break_poise` or more
## poise damage, or an emptied guard meter breaks the guard at once (outcome guard_broken, a long stagger).
static func _resolve_guard(result: Dictionary, attack: Dictionary, attacker: Dictionary, target: Dictionary, guard: Dictionary,
		base_damage: float, hit_stop_scale: float, hit_feel: Dictionary) -> Dictionary:
	var drain: float = float(attack.get("poise_damage", 0.0))
	var breaks: bool = (bool(attack.get("launcher", false)) and bool(guard.get("break_by_launcher", true))) \
			or drain >= float(guard.get("break_poise", 999.0)) \
			or float(guard.get("meter", 0.0)) - drain <= 0.0 \
			or bool(attack.get("guard_break", false))          # EMP: a pulse breaks a raised guard whatever the poise
	var chip: int = _damage(base_damage * float(guard.get("chip_scale", 0.25)), false)
	if base_damage > 0.0:
		chip = maxi(chip, int(guard.get("min_chip", 1)))
	result["outcome"] = OUTCOME_GUARD_BROKEN if breaks else OUTCOME_BLOCKED
	result["damage"] = chip
	result["guard_drain"] = drain
	result["hitstun_ms"] = float(guard.get("break_ms", hit_feel.get("stagger_ms", 1100.0))) if breaks else 0.0
	result["knockback"] = _push(attack, attacker, target, hit_feel) * float(guard.get("knockback_scale", 0.35))
	result["hit_stop_ms"] = float(attack.get("hit_stop_ms", 0.0)) * hit_stop_scale * float(guard.get("hit_stop_scale", 0.5))
	result["poise_after"] = float(target.get("poise", 0.0))
	result["staggered_target"] = breaks
	result["juggle_count"] = 0
	result["lethal"] = int(target.get("hp", 0)) - chip <= 0
	result["style_points"] = 0.0
	result["feedback"] = {"spark": str(guard.get("spark", "guard")), "sfx": str(guard.get("sfx", "combat_hit_light"))}
	if breaks:      # Tuning v1.3: a broken guard freezes like a heavy hit, whatever the blow that broke it
		var broke_ms: float = float((hit_feel.get("hit_freeze", {}) as Dictionary).get("guard_break_hit_stop_ms", 0.0))
		result["hit_stop_ms"] = maxf(float(result["hit_stop_ms"]), broke_ms * hit_stop_scale)
	return result


## The F12 knob "Hit freeze length" (seconds, the freeze of the heaviest hits) as a multiplier on every hit-stop in the data:
## knob / hit_feel.hit_freeze.reference_s. 1.0 with no knob (a bare test), or at the studio default.
static func freeze_scale(feel: FeelKnobs, hit_feel: Dictionary) -> float:
	if feel == null or not feel.has(FREEZE_KNOB):
		return 1.0
	var reference: float = float((hit_feel.get("hit_freeze", {}) as Dictionary).get("reference_s", 0.25))
	return feel.get_f(FREEZE_KNOB) / reference if reference > 0.0 else 1.0


## One swing hits each target once, unless the move has `rehit_ms`. `ledger` maps "swing:target" to the
## local time (ms) of the last hit; it is updated when the hit is allowed.
static func may_hit(ledger: Dictionary, swing_id: int, target_id: StringName, now_ms: float, rehit_ms: float = 0.0) -> bool:
	var key: String = "%d:%s" % [swing_id, String(target_id)]
	if ledger.has(key):
		if rehit_ms <= 0.0 or now_ms - float(ledger[key]) < rehit_ms:
			return false
	ledger[key] = now_ms
	return true


static func _blank(attack: Dictionary, attacker: Dictionary, target: Dictionary) -> Dictionary:
	return {
		"outcome": OUTCOME_IGNORED, "damage": 0, "hitstun_ms": 0.0, "knockback": Vector3.ZERO, "launch_mps": 0.0,
		"knockdown": false, "hit_stop_ms": 0.0, "poise_after": float(target.get("poise", 0.0)), "style_points": 0.0,
		"juggle_count": int(target.get("juggle_count", 0)),
		"attacker": attacker.get("id", &""), "target": target.get("id", &""),
		"move_id": attack.get("move_id", &""), "swing_id": int(attack.get("swing_id", 0)),
		"parry_rating": ClutchJudge.RATING_MISS, "launched": false, "staggered_target": false,
		"staggered_attacker": false, "armored": false, "air_hit": false, "lethal": false, "guard_drain": 0.0,
		"source": str(attack.get("source", "sword")),          # "sword", "hack" or "hijacked": BossPart and the HUD read it
	}


static func _damage(amount: float, at_least_one: bool) -> int:
	var rounded: int = int(roundf(amount))
	if at_least_one and rounded < 1:
		return 1
	return maxi(rounded, 0)


## How much a guard of this rating soaks. The action game's own table is `parry.block_reduction` in
## timing_windows.json (Nice 0.6, Rad and up 1.0); the older top-level table belongs to the turn-based game
## and is only a fallback. A test or tool can hand its own table in `ctx.parry.block_reduction`.
static func _block_reduction(ctx: Dictionary, rating: String) -> float:
	var table: Dictionary = (ctx.get("parry", {}) as Dictionary).get("block_reduction", {})
	if table.is_empty():
		table = CombatData.parry_block_reduction()
	return clampf(float(table.get(rating, 0.0)), 0.0, 1.0)


## World push for a hit: away from the attacker along the floor, knockback_m divided by the target's weight.
static func _push(attack: Dictionary, attacker: Dictionary, target: Dictionary, hit_feel: Dictionary) -> Vector3:
	var distance: float = float(attack.get("knockback_m", 0.0))
	if distance <= 0.0:
		return Vector3.ZERO
	var weight: float = maxf(float(target.get("weight", 1.0)), float(hit_feel.get("knockback_min_weight", 0.25)))
	var away: Vector3 = Vector3(target.get("position", Vector3.ZERO)) - Vector3(attacker.get("position", Vector3.ZERO))
	away.y = 0.0
	if away.length() < 0.001:
		away = Vector3(attacker.get("forward", Vector3.BACK))
		away.y = 0.0
	if away.length() < 0.001:
		away = Vector3.BACK
	return away.normalized() * (distance / weight)
