class_name HackRules
extends RefCounted
## What a hack costs and whether Red may cast it now (docs/slice/hacks_design.md, data/combat/hacks.json). Pure: the
## battery, the clock and the situation come in as numbers; a verdict comes out. HackCaster does the casting.
##
## `check(id, ctx)` answers {ok, reason, cost}. The first rule that stops a cast names the reason, in this order:
##   unknown       no such hack
##   locked        Kasp's Quiet Hours has the hacks jammed
##   air           the hack is ground only (`air_ok` false) and Red is in the air
##   cooldown      this hack was cast too recently
##   global        some hack was cast less than `global_cooldown_ms` ago
##   overclock     a hijack is already running (`max_active`, `recast: refuse`)
##   no_signal     the hack needs a target and there is none (`no_target: refuse`): no cast, nothing spent
##   not_full      Reboot needs a full battery
##   battery       the battery cannot pay
## ctx keys: charge, capacity, now_ms, locked, airborne, has_target, hijack_active, knobs (see `knobs_from`).
## Cooldowns are kept here, on the clock you pass in (Red's combat time in ms).

const OK: StringName = &""
const R_UNKNOWN: StringName = &"unknown"
const R_LOCKED: StringName = &"locked"
const R_AIR: StringName = &"air"
const R_COOLDOWN: StringName = &"cooldown"
const R_GLOBAL: StringName = &"global"
const R_OVERCLOCK: StringName = &"overclock"
const R_NO_SIGNAL: StringName = &"no_signal"
const R_NOT_FULL: StringName = &"not_full"
const R_BATTERY: StringName = &"battery"
const COST_ALL: String = "all"

var _hacks: Dictionary = {}
var _order: Array[StringName] = []
var _global_cooldown_ms: float = 0.0
var _ready_at: Dictionary = {}           # hack id -> ms when it may be cast again
var _global_ready_at: float = -1.0e9


static func from_data(doc: Dictionary) -> HackRules:
	var out: HackRules = HackRules.new()
	out._hacks = (doc.get("hacks", {}) as Dictionary).duplicate(true)
	out._global_cooldown_ms = float((doc.get("battery", {}) as Dictionary).get("global_cooldown_ms", 0.0))
	for raw: Variant in (doc.get("selection", {}) as Dictionary).get("order", []) as Array:
		if out._hacks.has(str(raw)):
			out._order.append(StringName(str(raw)))
	if out._order.is_empty():
		for id: Variant in out._hacks.keys():
			out._order.append(StringName(str(id)))
	return out


static func load_default() -> HackRules:
	return from_data(CombatData.hacks())


## The feel knobs the rules care about, as a plain dictionary (so the rules stay pure). Missing knobs read as the
## designer's defaults. `feel` may be null.
static func knobs_from(feel: FeelKnobs) -> Dictionary:
	var out: Dictionary = {"pick_mode": "pick_then_fire", "gain_scale": 1.0, "cost_scale": 1.0, "cooldown_scale": 1.0,
			"damage_scale": 1.0, "zap_pierce": 0, "emp_radius_m": 0.0, "emp_knockback_m": -1.0, "emp_stun_scale": 1.0,
			"overclock_s": 0.0, "reboot_heal_pct": 0.0, "reboot_needs_full": true, "auto_hold_ms": 0.0, "auto_crowd": 0,
			"free_cast": false}
	if feel == null:
		return out
	var map: Dictionary = {"pick_mode": "hack_pick_mode", "gain_scale": "hack_gain_scale", "cost_scale": "hack_cost_scale",
			"cooldown_scale": "hack_cooldown_scale", "damage_scale": "hack_damage_scale", "zap_pierce": "zap_pierce",
			"emp_radius_m": "emp_radius_m", "emp_knockback_m": "emp_knockback_m", "emp_stun_scale": "emp_stun_scale",
			"overclock_s": "overclock_duration_s", "reboot_heal_pct": "reboot_heal_pct", "reboot_needs_full": "reboot_needs_full",
			"auto_hold_ms": "hack_auto_reboot_hold_ms", "auto_crowd": "hack_auto_crowd_count", "free_cast": "hack_free_cast"}
	for key: String in map.keys():
		var knob_id: String = str(map[key])
		if not feel.has(knob_id):
			continue
		match typeof(out[key]):
			TYPE_BOOL:
				out[key] = feel.get_b(knob_id)
			TYPE_STRING:
				out[key] = feel.get_s(knob_id)
			TYPE_INT:
				out[key] = int(roundf(feel.get_f(knob_id)))
			_:
				out[key] = feel.get_f(knob_id)
	return out


# ---- the data ----

func order() -> Array[StringName]:
	return _order.duplicate()


func has_hack(id: StringName) -> bool:
	return _hacks.has(String(id))


func hack(id: StringName) -> Dictionary:
	return _hacks.get(String(id), {})


func display_name(id: StringName) -> String:
	return str(hack(id).get("name", String(id)))


func cast_move(id: StringName) -> StringName:
	return StringName(str(hack(id).get("cast_move", "")))


func effect(id: StringName) -> Dictionary:
	return hack(id).get("effect", {}) as Dictionary


func target_kind(id: StringName) -> StringName:
	return StringName(str((hack(id).get("target", {}) as Dictionary).get("kind", "self")))


## Does the hack refuse when it has no target (Overclock), as opposed to firing forward (Zap)?
func refuses_without_target(id: StringName) -> bool:
	return str((hack(id).get("target", {}) as Dictionary).get("no_target", "")) == "refuse"


func air_ok(id: StringName) -> bool:
	return bool(hack(id).get("air_ok", true))


# ---- cost, cooldown, the verdict ----

## What the cast takes from the battery now. Reboot ("all") takes whatever is in it. Free casting costs nothing.
func cost(id: StringName, charge: float, knobs: Dictionary = {}) -> float:
	if bool(knobs.get("free_cast", false)):
		return 0.0
	var raw: Variant = hack(id).get("cost", 0.0)
	if raw is String and str(raw) == COST_ALL:
		return charge
	return float(raw) * float(knobs.get("cost_scale", 1.0))


func cooldown_ms(id: StringName, knobs: Dictionary = {}) -> float:
	return float(hack(id).get("cooldown_ms", 0.0)) * maxf(float(knobs.get("cooldown_scale", 1.0)), 0.0)


## Does this hack need a full battery right now? (Reboot's `requires_full`, switched by the "needs full" knob.)
func needs_full(id: StringName, knobs: Dictionary = {}) -> bool:
	if not bool(hack(id).get("requires_full", false)):
		return false
	return bool(knobs.get("reboot_needs_full", true))


## The smallest fraction of the battery a hack that does not need a full one still wants (Reboot's `min_frac_if_not_full`).
func min_fraction(id: StringName) -> float:
	return float(hack(id).get("min_frac_if_not_full", 0.0))


func check(id: StringName, ctx: Dictionary) -> Dictionary:
	if not has_hack(id):
		return _verdict(R_UNKNOWN, 0.0)
	var knobs: Dictionary = ctx.get("knobs", {}) as Dictionary
	var charge: float = float(ctx.get("charge", 0.0))
	var capacity: float = float(ctx.get("capacity", 100.0))
	var now_ms: float = float(ctx.get("now_ms", 0.0))
	var price: float = cost(id, charge, knobs)
	if bool(ctx.get("locked", false)):
		return _verdict(R_LOCKED, price)
	if bool(ctx.get("airborne", false)) and not air_ok(id):
		return _verdict(R_AIR, price)
	if cooldown_left_ms(id, now_ms) > 0.0:
		return _verdict(R_COOLDOWN, price)
	if now_ms < _global_ready_at:
		return _verdict(R_GLOBAL, price)
	if bool(ctx.get("hijack_active", false)) and str(effect(id).get("type", "")) == "hijack":
		return _verdict(R_OVERCLOCK, price)
	if refuses_without_target(id) and not bool(ctx.get("has_target", false)):
		return _verdict(R_NO_SIGNAL, price)
	var short: StringName = _battery_reason(id, charge, capacity, knobs)
	if short != OK:
		return _verdict(short, price)
	return _verdict(OK, price)


## Can the battery pay for it, ignoring everything else? (The automatic picker asks this.)
func affordable(id: StringName, charge: float, capacity: float, knobs: Dictionary = {}) -> bool:
	return _battery_reason(id, charge, capacity, knobs) == OK


func cooldown_left_ms(id: StringName, now_ms: float) -> float:
	return maxf(float(_ready_at.get(String(id), -1.0e9)) - now_ms, 0.0)


## 0..1 of the cooldown still to wait (1 = just cast), for the HUD sweep.
func cooldown_fraction(id: StringName, now_ms: float, knobs: Dictionary = {}) -> float:
	var total: float = cooldown_ms(id, knobs)
	return clampf(cooldown_left_ms(id, now_ms) / total, 0.0, 1.0) if total > 0.0 else 0.0


## A cast began at `now_ms`: this hack and the global cooldown start.
func start_cooldown(id: StringName, now_ms: float, knobs: Dictionary = {}) -> void:
	_ready_at[String(id)] = now_ms + cooldown_ms(id, knobs)
	_global_ready_at = now_ms + _global_cooldown_ms


## A cast fizzled and was refunded: it leaves no cooldown behind.
func clear_cooldown(id: StringName) -> void:
	_ready_at.erase(String(id))
	_global_ready_at = -1.0e9


func reset_cooldowns() -> void:
	_ready_at.clear()
	_global_ready_at = -1.0e9


# ---- what a hack does to a target's tags ----

## Damage multiplier for an enemy with these tags: the biggest `tag_mult` entry of the hack that matches (1.0 if none).
func tag_mult(id: StringName, tags: Array) -> float:
	var table: Dictionary = ((effect(id).get("hit", {}) as Dictionary).get("tag_mult", {}) as Dictionary)
	var best: float = 0.0
	for tag: Variant in tags:
		best = maxf(best, float(table.get(str(tag), 0.0)))
	return best if best > 0.0 else 1.0


## How long EMP knocks out an enemy with these tags, in ms (0 if its tags are not on the list). `scale` is the stun knob.
func stun_ms(id: StringName, tags: Array, scale: float = 1.0) -> float:
	var table: Dictionary = (effect(id).get("stun_ms", {}) as Dictionary)
	var best: float = 0.0
	for tag: Variant in tags:
		best = maxf(best, float(table.get(str(tag), 0.0)))
	return best * maxf(scale, 0.0)


## Reboot: health restored. `charge_frac` is the battery's fill when she cast it; with `scale_with_charge` a half battery heals half as much.
func heal_amount(id: StringName, hp_max: int, charge_frac: float, knobs: Dictionary = {}) -> int:
	var spec: Dictionary = effect(id)
	var frac: float = float(spec.get("heal_frac", 0.5))
	var pct: float = float(knobs.get("reboot_heal_pct", 0.0))
	if pct > 0.0:
		frac = pct / 100.0
	if bool(spec.get("scale_with_charge", false)) and not needs_full(id, knobs):
		frac *= clampf(charge_frac, 0.0, 1.0)
	return int(roundf(float(hp_max) * frac))


## OK, or why the battery alone says no (not_full, battery).
func _battery_reason(id: StringName, charge: float, capacity: float, knobs: Dictionary) -> StringName:
	if bool(knobs.get("free_cast", false)):
		return OK
	if needs_full(id, knobs) and charge < capacity - 0.0001:
		return R_NOT_FULL
	if str(hack(id).get("cost", 0.0)) == COST_ALL:
		# Reboot from a part-full battery (the knob is off): it still wants its minimum.
		if charge <= 0.0 or charge < capacity * min_fraction(id) - 0.0001:
			return R_BATTERY
		return OK
	if charge < cost(id, charge, knobs) - 0.0001:
		return R_BATTERY
	return OK


static func _verdict(reason: StringName, price: float) -> Dictionary:
	return {"ok": reason == OK, "reason": reason, "cost": price}
