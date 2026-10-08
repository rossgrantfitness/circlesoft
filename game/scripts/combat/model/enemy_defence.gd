class_name EnemyDefence
extends RefCounted
## One enemy's defence roll (enemy_ai_design section 2.1). Pure: numbers in, a choice out, and a seeded
## random generator so every run repeats.
##
## For each swing of Red's that threatens the enemy, the brain asks once: dodge, block or nothing?
##   chance = (dodge_chance x dodge_scale + block_chance x block_scale) x read_weight[Red's move class]
##            x (1 - fatigue)
## Each successful defence adds fatigue that fades with time, and each kind has a cooldown that starts when
## the defence ends. The numbers are the enemy's `behaviour.defend` block in enemies.json.

const KIND_DODGE: StringName = &"dodge"
const KIND_BLOCK: StringName = &"block"
const KIND_NONE: StringName = &""

var _cfg: Dictionary = {}
var _rng: RandomNumberGenerator = null
var _fatigue: float = 0.0
var _fatigue_ms: float = 0.0
var _cooldown_until: Dictionary = {}     # kind -> ms on the owner's clock


static func create(defend_cfg: Dictionary, rng: RandomNumberGenerator) -> EnemyDefence:
	var out: EnemyDefence = EnemyDefence.new()
	out._cfg = defend_cfg
	out._rng = rng
	return out


func configured() -> bool:
	return not _cfg.is_empty()


## Fatigue now, 0..1. A defence adds `fatigue_per_defence`; it fades so that one defence is gone in `fatigue_decay_s`.
func fatigue(now_ms: float) -> float:
	var per: float = float(_cfg.get("fatigue_per_defence", 0.0))
	var decay_s: float = maxf(float(_cfg.get("fatigue_decay_s", 4.0)), 0.001)
	var rate: float = per / decay_s
	return maxf(_fatigue - maxf(now_ms - _fatigue_ms, 0.0) / 1000.0 * rate, 0.0)


## How long after seeing Red's swing it starts to react, ms. `scale` is the feel knob (higher = slower).
func reaction_ms(scale: float) -> float:
	return EnemyRules.pick_range(_rng, _cfg.get("reaction_ms", [100, 150]), [100.0, 150.0]) * maxf(scale, 0.0)


func ready(kind: StringName, now_ms: float) -> bool:
	return now_ms >= float(_cooldown_until.get(String(kind), -1.0e9))


## Chance of each choice for a swing of `move_class` (cooldowns, fatigue and the sliders applied).
## Returns {dodge, block}; both are 0 for a class the enemy does not read.
func chances(move_class: StringName, now_ms: float, dodge_scale: float, block_scale: float, block_mult: float = 1.0) -> Dictionary:
	var weights: Dictionary = _cfg.get("read_weight", {})
	if move_class == EnemyRules.CLASS_NONE or not weights.has(String(move_class)):
		return {"dodge": 0.0, "block": 0.0}
	var weight: float = float(weights[String(move_class)])
	var open: float = 1.0 - clampf(fatigue(now_ms), 0.0, 1.0)
	var dodge: float = 0.0
	var block: float = 0.0
	if ready(KIND_DODGE, now_ms):
		dodge = float(_cfg.get("dodge_chance", 0.0)) * maxf(dodge_scale, 0.0) * weight * open
	if ready(KIND_BLOCK, now_ms):
		block = float(_cfg.get("block_chance", 0.0)) * maxf(block_scale, 0.0) * maxf(block_mult, 0.0) * weight * open
	var total: float = dodge + block
	if total > 1.0:
		dodge /= total
		block /= total
	return {"dodge": dodge, "block": block}


## The roll: one random number picks dodge, block or nothing. A successful pick adds fatigue.
func roll(move_class: StringName, now_ms: float, dodge_scale: float, block_scale: float, block_mult: float = 1.0) -> StringName:
	var odds: Dictionary = chances(move_class, now_ms, dodge_scale, block_scale, block_mult)
	var pick: float = _rng.randf()
	var kind: StringName = KIND_NONE
	if pick < float(odds["dodge"]):
		kind = KIND_DODGE
	elif pick < float(odds["dodge"]) + float(odds["block"]):
		kind = KIND_BLOCK
	if kind != KIND_NONE:
		add_fatigue(now_ms)
	return kind


func add_fatigue(now_ms: float) -> void:
	_fatigue = clampf(fatigue(now_ms) + float(_cfg.get("fatigue_per_defence", 0.0)), 0.0, 1.0)
	_fatigue_ms = now_ms


## The defence is over (it ended or was cut short): its cooldown starts now.
func end_defence(kind: StringName, now_ms: float) -> void:
	var key: String = "%s_cooldown_ms" % String(kind)
	_cooldown_until[String(kind)] = now_ms + float(_cfg.get(key, 0.0))


## Back or side? `back_pct` of the dodges are back-rolls, but only when Red is closer than `back_if_closer_m`.
func dodge_variant(dist_to_red: float) -> StringName:
	var dodge: Dictionary = _cfg.get("dodge", {})
	var back_pct: float = float(dodge.get("back_pct", 0.0))
	var side_pct: float = float(dodge.get("side_pct", 100.0))
	var total: float = maxf(back_pct + side_pct, 0.001)
	if dist_to_red < float(dodge.get("back_if_closer_m", 0.0)) and _rng.randf() < back_pct / total:
		return &"back"
	return &"side"


func combo_escape() -> Dictionary:
	return _cfg.get("combo_escape", {})


func dodge_cfg() -> Dictionary:
	return _cfg.get("dodge", {})


func reset() -> void:
	_fatigue = 0.0
	_fatigue_ms = 0.0
	_cooldown_until.clear()
