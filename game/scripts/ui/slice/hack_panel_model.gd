class_name HackPanelModel
extends RefCounted
## What the hack panel shows, with no drawing: the battery, the hack list, which one is picked (pick mode)
## or was used last (automatic mode), per-hack cooldown sweeps, the Quiet Hours lockout and the hijack timers.
## Fed by the HUD from the director's signals (`battery_changed`, `hack_locked`, and the optional
## `hack_selected`, `hack_cast`, `hack_denied`). Costs and names come from data/combat/hacks.json.

const HACKS_ID: String = "combat/hacks"
const MODE_PICK: String = "pick"
const MODE_AUTO: String = "auto"
const COST_ALL: String = "all"

var order: Array[String] = []
var defs: Dictionary = {}
var charge: float = 0.0
var capacity: float = 100.0
var mode: String = MODE_PICK
var selected: String = ""
var last_used: String = ""
## Multiplies every cost (the feel panel's "hack_cost_scale"); Reboot still takes the whole battery.
var cost_scale: float = 1.0
## Multiplies every cooldown (the feel panel's "hack_cooldown_scale").
var cooldown_scale: float = 1.0
var free_cast: bool = false
var wrap: bool = true

var _lock_left_ms: float = 0.0
var _lock_total_ms: float = 0.0
var _cooldown_left_ms: Dictionary = {}
var _cooldown_total_ms: Dictionary = {}
var _denied_left_s: float = 0.0
var _denied_id: String = ""
## actor id -> {left, total}
var _hijacks: Dictionary = {}


static func load_default() -> HackPanelModel:
	var model: HackPanelModel = HackPanelModel.new()
	model.from_data(DataDB.get_dict(HACKS_ID))
	return model


func from_data(doc: Dictionary) -> void:
	defs = (doc.get("hacks", {}) as Dictionary).duplicate(true)
	var selection: Dictionary = doc.get("selection", {})
	order.clear()
	for id: Variant in selection.get("order", defs.keys()):
		if defs.has(str(id)):
			order.append(str(id))
	wrap = bool(selection.get("wrap", true))
	var battery: Dictionary = doc.get("battery", {})
	capacity = maxf(1.0, float(battery.get("capacity", 100)))
	charge = clampf(float(battery.get("start", capacity)), 0.0, capacity)
	set_mode_from_data(str(selection.get("mode", MODE_PICK)))
	selected = str(selection.get("start_selected", order[0] if not order.is_empty() else ""))
	if not order.has(selected) and not order.is_empty():
		selected = order[0]


## "pick" / "pick_then_fire" -> pick; "auto" / "automatic" -> auto.
func set_mode_from_data(value: String) -> void:
	mode = MODE_AUTO if value.begins_with("auto") else MODE_PICK


func is_auto() -> bool:
	return mode == MODE_AUTO


# ---- battery ----

func set_battery(new_charge: float, new_capacity: float) -> void:
	capacity = maxf(1.0, new_capacity)
	charge = clampf(new_charge, 0.0, capacity)


func fill() -> float:
	return charge / capacity


## What a cast costs right now.
func cost_of(id: String) -> int:
	if free_cast:
		return 0
	var raw: Variant = (defs.get(id, {}) as Dictionary).get("cost", 0)
	if raw is String and str(raw) == COST_ALL:
		return roundi(capacity)
	return roundi(float(raw) * cost_scale)


func takes_all(id: String) -> bool:
	return str((defs.get(id, {}) as Dictionary).get("cost", "")) == COST_ALL


func needs_full(id: String) -> bool:
	return bool((defs.get(id, {}) as Dictionary).get("requires_full", false))


## Enough charge (Reboot also wants a full bar when its data says so).
func can_afford(id: String) -> bool:
	if not defs.has(id):
		return false
	if free_cast:
		return true
	if needs_full(id) and charge < capacity - 0.01:
		return false
	return charge + 0.01 >= float(cost_of(id))


## Affordable, off cooldown and not jammed: the hack could be cast this instant.
func is_ready(id: String) -> bool:
	return can_afford(id) and not is_locked() and cooldown_left_ms(id) <= 0.0


func display_name(id: String) -> String:
	return str((defs.get(id, {}) as Dictionary).get("name", id))


func icon_of(id: String) -> String:
	return str((defs.get(id, {}) as Dictionary).get("icon", ""))


## Tick marks on the bar: the fraction of the bar at each fixed cost (Reboot, which takes it all, sits at the end).
func cost_ticks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in order:
		var cost: int = cost_of(id)
		if cost <= 0:
			continue
		out.append({"id": id, "frac": clampf(float(cost) / capacity, 0.0, 1.0), "all": takes_all(id)})
	return out


# ---- which hack ----

## The row the panel lights: the picked hack in pick mode, the last one used in automatic mode.
func highlight_id() -> String:
	return last_used if is_auto() else selected


func select(id: String) -> void:
	if order.has(id):
		selected = id


## Moves the pick (+1 / -1), wrapping when the data says so.
func step(direction: int) -> void:
	if order.is_empty():
		return
	var index: int = maxi(0, order.find(selected)) + direction
	if wrap:
		index = posmod(index, order.size())
	else:
		index = clampi(index, 0, order.size() - 1)
	selected = order[index]


## The cooldown a cast of `id` starts, in ms.
func cooldown_ms_of(id: String) -> float:
	return float((defs.get(id, {}) as Dictionary).get("cooldown_ms", 0.0)) * cooldown_scale


func note_cast(id: String, cooldown_ms: float) -> void:
	last_used = id
	if cooldown_ms > 0.0:
		_cooldown_left_ms[id] = cooldown_ms
		_cooldown_total_ms[id] = cooldown_ms


func cooldown_left_ms(id: String) -> float:
	return float(_cooldown_left_ms.get(id, 0.0))


## 0 = ready, 1 = just cast (the sweep).
func cooldown_frac(id: String) -> float:
	var total: float = float(_cooldown_total_ms.get(id, 0.0))
	return clampf(cooldown_left_ms(id) / total, 0.0, 1.0) if total > 0.0 else 0.0


# ---- Quiet Hours ----

func set_lock(active: bool, ms: float) -> void:
	_lock_left_ms = maxf(0.0, ms) if active else 0.0
	_lock_total_ms = _lock_left_ms if active else 0.0


func is_locked() -> bool:
	return _lock_left_ms > 0.0


func lock_left_s() -> float:
	return _lock_left_ms / 1000.0


func lock_frac() -> float:
	return clampf(_lock_left_ms / _lock_total_ms, 0.0, 1.0) if _lock_total_ms > 0.0 else 0.0


# ---- a refused cast ----

func note_denied(id: String) -> void:
	_denied_id = id
	_denied_left_s = SliceUiData.num("hack_panel.denied_s", 0.3)


func denied_id() -> String:
	return _denied_id if _denied_left_s > 0.0 else ""


func denied_frac() -> float:
	var total: float = SliceUiData.num("hack_panel.denied_s", 0.3)
	return clampf(_denied_left_s / total, 0.0, 1.0) if total > 0.0 else 0.0


# ---- hijack links ----

func set_hijack(actor_id: String, left_s: float, total_s: float) -> void:
	if left_s <= 0.0:
		_hijacks.erase(actor_id)
		return
	_hijacks[actor_id] = {"left": left_s, "total": maxf(total_s, left_s)}


func clear_hijack(actor_id: String) -> void:
	_hijacks.erase(actor_id)


func clear_hijacks() -> void:
	_hijacks.clear()


func hijack_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _hijacks:
		out.append(id)
	return out


func hijack_left_s(actor_id: String) -> float:
	return float((_hijacks.get(actor_id, {}) as Dictionary).get("left", 0.0))


func hijack_frac(actor_id: String) -> float:
	var entry: Dictionary = _hijacks.get(actor_id, {})
	return clampf(float(entry.get("left", 0.0)) / float(entry.get("total", 1.0)), 0.0, 1.0) if not entry.is_empty() else 0.0


## The link with the most time left (the panel shows one timer), or "".
func longest_hijack() -> String:
	var best: String = ""
	var best_left: float = 0.0
	for id: String in _hijacks:
		var left: float = float(_hijacks[id]["left"])
		if left > best_left:
			best_left = left
			best = id
	return best


# ---- time ----

## Real seconds. Counts down cooldowns, the lockout, the refusal shake and the hijack timers.
func tick(delta: float) -> void:
	for id: String in _cooldown_left_ms.keys():
		_cooldown_left_ms[id] = maxf(0.0, float(_cooldown_left_ms[id]) - delta * 1000.0)
	_lock_left_ms = maxf(0.0, _lock_left_ms - delta * 1000.0)
	_denied_left_s = maxf(0.0, _denied_left_s - delta)
	for id: String in _hijacks.keys():
		_hijacks[id]["left"] = float(_hijacks[id]["left"]) - delta
		if float(_hijacks[id]["left"]) <= 0.0:
			_hijacks.erase(id)
