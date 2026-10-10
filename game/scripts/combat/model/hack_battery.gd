class_name HackBattery
extends RefCounted
## The hack battery (docs/slice/slice_tech_plan.md 4.2, docs/slice/hacks_design.md). Pure: it never reads a clock, you
## hand it `now_ms` (Red's combat time), so hit-stop pauses it and tests can step it by hand.
##
## Sword hits fill it, hacks drain it, and hack hits never refill it (no free loop). One hit is worth what its outcome says
## (`hit`, `blocked`, `armored`, `guard_broken`), plus a bonus for a string finisher and for a hit in the air. A cap per
## second (`gain_cap_per_s`) stops one big multi-hit from filling the bar in a frame. Kasp's Quiet Hours locks it
## (`lock`): casting is refused while the lock runs, the charge itself is kept.
##
## The director owns one, feeds it from `hit_landed` when the attacker is Red's sword, and announces changes
## (`battery_changed`, `hack_locked`). Data: data/combat/hacks.json `battery`.

const SOURCE_SWORD: StringName = &"sword"
const WINDOW_MS: float = 1000.0

var _capacity: float = 100.0
var _start: float = 50.0
var _gain: Dictionary = {}
var _cap_per_s: float = 30.0
var _hack_hits_refill: bool = false
var _charge: float = 50.0
var _gains: Array[Vector2] = []          # (time ms, amount) inside the last second, for the per-second cap
var _lock_end_ms: float = -1.0


## `doc` is the whole hacks.json (its `battery` block is read) or the battery block itself.
static func from_data(doc: Dictionary) -> HackBattery:
	var block: Dictionary = (doc.get("battery", doc) as Dictionary) if doc.has("battery") or doc.has("capacity") else {}
	var out: HackBattery = HackBattery.new()
	out._capacity = maxf(float(block.get("capacity", 100.0)), 1.0)
	out._start = clampf(float(block.get("start", out._capacity)), 0.0, out._capacity)
	out._gain = (block.get("gain", {}) as Dictionary).duplicate(true)
	out._cap_per_s = float(block.get("gain_cap_per_s", 30.0))
	out._hack_hits_refill = bool(block.get("hack_hits_refill", false))
	out._charge = out._start
	return out


static func load_default() -> HackBattery:
	return from_data(CombatData.hacks())


# ---- how full ----

func capacity() -> float:
	return _capacity


func charge() -> float:
	return _charge


## 0..1.
func fill() -> float:
	return _charge / _capacity


func is_full() -> bool:
	return _charge >= _capacity - 0.0001


func start_charge() -> float:
	return _start


## Sets the charge directly (a door carrying it over, a save, a test). Clamped to 0..capacity.
func set_charge(value: float) -> void:
	_charge = clampf(value, 0.0, _capacity)


func reset_full() -> void:
	_charge = _capacity
	_gains.clear()


## Back to the new-game charge, unlocked, with no recent gains.
func reset_start() -> void:
	_charge = _start
	_gains.clear()
	_lock_end_ms = -1.0


# ---- filling ----

## What one hit is worth before the cap and any scale: the outcome's number, +finisher_bonus, +air_bonus.
## `outcome` is the director's: hit / stagger count as `hit`; blocked, armored, guard_broken have their own numbers;
## anything else (evaded, parried, ignored) is worth nothing.
func gain_for(outcome: StringName, airborne: bool = false, finisher: bool = false) -> float:
	var key: String = _gain_key(outcome)
	if key.is_empty():
		return 0.0
	var amount: float = float(_gain.get(key, 0.0))
	if finisher:
		amount += float(_gain.get("finisher_bonus", 0.0))
	if airborne:
		amount += float(_gain.get("air_bonus", 0.0))
	return amount


## A sword hit landed. Returns what was actually added (after `scale` and the per-second cap).
## `source` other than the sword adds nothing unless the data says hack hits refill.
func add_from_hit(outcome: StringName, _move_id: StringName, airborne: bool, finisher: bool, now_ms: float,
		scale: float = 1.0, source: StringName = SOURCE_SWORD) -> float:
	if source != SOURCE_SWORD and not _hack_hits_refill:
		return 0.0
	var wanted: float = gain_for(outcome, airborne, finisher) * maxf(scale, 0.0)
	if wanted <= 0.0 or _charge >= _capacity:
		return 0.0
	_forget_old_gains(now_ms)
	var used: float = 0.0
	for entry: Vector2 in _gains:
		used += entry.y
	var room: float = maxf(_cap_per_s - used, 0.0) if _cap_per_s > 0.0 else wanted
	var added: float = minf(minf(wanted, room), _capacity - _charge)
	if added <= 0.0:
		return 0.0
	_gains.append(Vector2(now_ms, added))
	_charge += added
	return added


# ---- spending ----

func can_spend(cost: float) -> bool:
	return cost <= _charge + 0.0001


## Takes `cost` out. False (and nothing taken) if there is not enough.
func spend(cost: float) -> bool:
	if not can_spend(cost):
		return false
	_charge = maxf(_charge - maxf(cost, 0.0), 0.0)
	return true


## Takes everything (Reboot). Returns what it took.
func spend_all() -> float:
	var taken: float = _charge
	_charge = 0.0
	return taken


## Gives back a cost (a cast that fizzled). Clamped to capacity.
func refund(amount: float) -> void:
	_charge = minf(_charge + maxf(amount, 0.0), _capacity)


# ---- Quiet Hours ----

## Casting is refused for `ms` from `now_ms`. A longer lock already running is kept.
func lock(ms: float, now_ms: float) -> void:
	_lock_end_ms = maxf(_lock_end_ms, now_ms + maxf(ms, 0.0))


func unlock() -> void:
	_lock_end_ms = -1.0


func is_locked(now_ms: float) -> bool:
	return _lock_end_ms > now_ms


func lock_left_ms(now_ms: float) -> float:
	return maxf(_lock_end_ms - now_ms, 0.0)


# ---- internals ----

static func _gain_key(outcome: StringName) -> String:
	match outcome:
		&"hit", &"stagger":
			return "hit"
		&"blocked":
			return "blocked"
		&"armored":
			return "armored"
		&"guard_broken":
			return "guard_broken"
	return ""


func _forget_old_gains(now_ms: float) -> void:
	var kept: Array[Vector2] = []
	for entry: Vector2 in _gains:
		if now_ms - entry.x < WINDOW_MS and entry.x <= now_ms + 0.001:
			kept.append(entry)
	_gains = kept
