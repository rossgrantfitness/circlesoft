class_name StyleMeter
extends RefCounted
## Noise: the style meter (contract 4.5). Hits fill it, varied moves fill it faster, taking damage drops a
## rank, and it drains slowly when you stop. Runs on Red's clock (so hit-stop pauses the drain).
## Ranks, points and decay numbers live in data/combat/style.json.

var _ranks: Array[Dictionary] = []     # {id, name, at} sorted by "at" (points)
var _max_points: float = 100.0
var _variety_window_ms: float = 4000.0
var _repeat_mult: float = 0.6
var _repeat_floor: float = 0.2
var _idle_ms: float = 2500.0
var _drain_per_s: float = 6.0
var _bonuses: Dictionary = {}
## False while the `noise_meter` feature switch is off: nothing scores and a hit costs no rank.
var enabled: bool = true
var _points: float = 0.0
var _last_gain_ms: float = 0.0
var _last_step_ms: float = 0.0
var _recent: Array[Dictionary] = []    # {move, t}


static func from_data(style: Dictionary) -> StyleMeter:
	var meter: StyleMeter = StyleMeter.new()
	meter._max_points = maxf(float(style.get("max_points", 100.0)), 1.0)
	var variety: Dictionary = style.get("variety", {})
	meter._variety_window_ms = float(variety.get("window_ms", 4000.0))
	meter._repeat_mult = float(variety.get("repeat_mult", 0.6))
	meter._repeat_floor = float(variety.get("min_mult", 0.2))
	var drain: Dictionary = style.get("drain", {})
	meter._idle_ms = float(drain.get("idle_ms", 2500.0))
	meter._drain_per_s = float(drain.get("per_s", 6.0))
	meter._bonuses = (style.get("bonuses", {}) as Dictionary).duplicate(true)
	for rank: Variant in style.get("ranks", []):
		var rank_dict: Dictionary = rank
		meter._ranks.append({"id": StringName(str(rank_dict.get("id", ""))), "name": str(rank_dict.get("name", "")),
				"at": float(rank_dict.get("at", 0.0))})
	meter._ranks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	if meter._ranks.is_empty():
		meter._ranks.append({"id": &"none", "name": "", "at": 0.0})
	return meter


static func load_default() -> StyleMeter:
	return from_data(CombatData.style())


## A hit's points, cut down if the same move was used recently (inside variety_window_ms): each repeat
## multiplies by repeat_mult, never below min_mult.
func add_hit(move_id: StringName, points: float, now_ms: float) -> void:
	_forget_old(now_ms)
	var repeats: int = 0
	for entry: Dictionary in _recent:
		if entry["move"] == move_id:
			repeats += 1
	var mult: float = maxf(pow(_repeat_mult, float(repeats)), _repeat_floor)
	_recent.append({"move": move_id, "t": now_ms})
	_gain(points * mult, now_ms)


## A bonus by name (parry, perfect_parry, perfect_dodge, launch, air_hit): points from style.json.
func add_bonus(kind: StringName, now_ms: float) -> void:
	_gain(float(_bonuses.get(String(kind), 0.0)), now_ms)


## Taking a hit drops you a rank: to the start of the rank below (or empty from the first rank).
func took_damage(now_ms: float) -> void:
	if not enabled:
		return
	var index: int = rank_index()
	_points = float(_ranks[index - 1]["at"]) if index >= 1 else 0.0
	_last_gain_ms = now_ms


func step(now_ms: float) -> void:
	var dt_s: float = maxf(now_ms - _last_step_ms, 0.0) / 1000.0
	_last_step_ms = now_ms
	if _points <= 0.0 or now_ms - _last_gain_ms < _idle_ms:
		return
	_points = maxf(_points - _drain_per_s * dt_s, 0.0)


func points() -> float:
	return _points


func fill() -> float:
	return clampf(_points / _max_points, 0.0, 1.0)


func is_full() -> bool:
	return _points >= _max_points - 0.0001


func max_points() -> float:
	return _max_points


func rank_index() -> int:
	var index: int = 0
	for i: int in range(_ranks.size()):
		if _points >= float(_ranks[i]["at"]):
			index = i
	return index


## {index, id, name}. Index 0 is "no rank yet".
func rank() -> Dictionary:
	var index: int = rank_index()
	return {"index": index, "id": _ranks[index]["id"], "name": _ranks[index]["name"]}


func rank_count() -> int:
	return _ranks.size()


## Lights On drives the meter directly while it runs.
func set_points(value: float) -> void:
	_points = clampf(value, 0.0, _max_points)


func reset() -> void:
	_points = 0.0
	_recent.clear()
	_last_gain_ms = _last_step_ms


func _gain(amount: float, now_ms: float) -> void:
	if amount <= 0.0 or not enabled:
		return
	_points = minf(_points + amount, _max_points)
	_last_gain_ms = now_ms


func _forget_old(now_ms: float) -> void:
	var kept: Array[Dictionary] = []
	for entry: Dictionary in _recent:
		if now_ms - float(entry["t"]) <= _variety_window_ms:
			kept.append(entry)
	_recent = kept
