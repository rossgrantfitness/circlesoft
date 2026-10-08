class_name AttackTokens
extends RefCounted
## Only a few enemies may attack at once (`max_attackers` in enemies.json, start 2). An enemy asks for a
## token, attacks while it holds one and gives it back when its move ends. Enemies that asked and were
## refused queue up, so the one waiting longest gets the next free token (nobody starves).
##
## enemy_ai_design section 5 adds the `token_rules` block of enemies.json:
##  - A flanker queues with a bonus (`flanker_queue_bonus_ms`): it counts as having waited that much longer.
##  - Two attacks never land less than `min_impact_gap_ms` apart: before a wind-up starts the enemy asks
##    `begin_attack()` with the time to its impact; if that is too close to another enemy's impact it waits.
##  - Only `max_rear_attackers` enemy may attack from the 120 degrees behind Red at a time.
## Defending and fleeing enemies simply do not ask (they hold no token); `release()` also takes them out of the queue.
## `step()` moves the tokens' own clock (real seconds) so these rules can compare times.

var max_attackers: int = 2
var min_impact_gap_ms: float = 0.0
var max_rear_attackers: int = 99
var flanker_queue_bonus_ms: float = 0.0

var _holders: Array[StringName] = []
var _queue: Array[StringName] = []
var _queued_at: Dictionary = {}          # id -> clock ms when it joined the queue
var _flanker: Dictionary = {}            # id -> true if it asked as a flanker
var _impacts: Array[Dictionary] = []     # {id, at_ms}: planned (or very recent) impacts
var _attacking: Dictionary = {}          # id -> {rear: bool}
var _clock_ms: float = 0.0


static func create(max_count: int = 2) -> AttackTokens:
	var tokens: AttackTokens = AttackTokens.new()
	tokens.max_attackers = maxi(max_count, 0)
	return tokens


static func from_data(enemies_doc: Dictionary) -> AttackTokens:
	var tokens: AttackTokens = create(int(enemies_doc.get("max_attackers", 2)))
	tokens.apply_rules(enemies_doc.get("token_rules", {}))
	return tokens


## Read the `token_rules` block (missing keys keep the rule off).
func apply_rules(rules: Dictionary) -> void:
	min_impact_gap_ms = float(rules.get("min_impact_gap_ms", 0.0))
	max_rear_attackers = int(rules.get("max_rear_attackers", 99))
	flanker_queue_bonus_ms = float(rules.get("flanker_queue_bonus_ms", 0.0))


## Advance the tokens' clock by a real time step.
func step(delta_s: float) -> void:
	_clock_ms += maxf(delta_s, 0.0) * 1000.0
	var keep: Array[Dictionary] = []
	for impact: Dictionary in _impacts:
		if float(impact["at_ms"]) >= _clock_ms - min_impact_gap_ms:
			keep.append(impact)
	_impacts = keep


func clock_ms() -> float:
	return _clock_ms


## Ask for a token. `opts.flank` = true queues with the flanker bonus.
func request(enemy_id: StringName, opts: Dictionary = {}) -> bool:
	if _holders.has(enemy_id):
		return true
	if not _queue.has(enemy_id):
		_queue.append(enemy_id)
		_queued_at[enemy_id] = _clock_ms
	_flanker[enemy_id] = bool(opts.get("flank", false))
	var free: int = max_attackers - _holders.size()
	if _rank(enemy_id) < free:
		_queue.erase(enemy_id)
		_queued_at.erase(enemy_id)
		_flanker.erase(enemy_id)
		_holders.append(enemy_id)
		return true
	return false


## Position in the line: the number of waiting enemies that are ahead (waited longer, counting the flanker bonus).
func _rank(enemy_id: StringName) -> int:
	var mine: float = _priority(enemy_id)
	var my_index: int = _queue.find(enemy_id)
	var ahead: int = 0
	for i: int in range(_queue.size()):
		if i == my_index:
			continue
		var theirs: float = _priority(_queue[i])
		if theirs < mine or (is_equal_approx(theirs, mine) and i < my_index):
			ahead += 1
	return ahead


func _priority(enemy_id: StringName) -> float:
	var bonus: float = flanker_queue_bonus_ms if bool(_flanker.get(enemy_id, false)) else 0.0
	return float(_queued_at.get(enemy_id, _clock_ms)) - bonus


func release(enemy_id: StringName) -> void:
	_holders.erase(enemy_id)
	_queue.erase(enemy_id)
	_queued_at.erase(enemy_id)
	_flanker.erase(enemy_id)
	end_attack(enemy_id)


func has_token(enemy_id: StringName) -> bool:
	return _holders.has(enemy_id)


func holders() -> Array[StringName]:
	return _holders.duplicate()


func waiting() -> Array[StringName]:
	return _queue.duplicate()


# ---- the attack rules ----

## Would an attack whose hit lands in `impact_in_ms` break a rule? (Nothing is recorded.)
func attack_allowed(enemy_id: StringName, impact_in_ms: float, rear: bool) -> bool:
	if min_impact_gap_ms > 0.0:
		var at_ms: float = _clock_ms + impact_in_ms
		for impact: Dictionary in _impacts:
			if impact["id"] != enemy_id and absf(float(impact["at_ms"]) - at_ms) < min_impact_gap_ms:
				return false
	if rear and _rear_attackers(enemy_id) >= max_rear_attackers:
		return false
	return true


## An enemy is about to start a wind-up that lands in `impact_in_ms`. True = go ahead (and it is recorded);
## false = another hit is too close in time, or someone already attacks from behind: wait and ask again.
func begin_attack(enemy_id: StringName, impact_in_ms: float, rear: bool) -> bool:
	if not attack_allowed(enemy_id, impact_in_ms, rear):
		return false
	end_attack(enemy_id)
	_impacts.append({"id": enemy_id, "at_ms": _clock_ms + impact_in_ms})
	_attacking[enemy_id] = {"rear": rear}
	return true


## The attack is over or was cut short. A hit that has not landed yet is forgotten; one that has stays on the
## books until the gap has passed.
func end_attack(enemy_id: StringName) -> void:
	_attacking.erase(enemy_id)
	var keep: Array[Dictionary] = []
	for impact: Dictionary in _impacts:
		if impact["id"] == enemy_id and float(impact["at_ms"]) > _clock_ms:
			continue
		keep.append(impact)
	_impacts = keep


func rear_attackers() -> int:
	return _rear_attackers(&"")


func _rear_attackers(except_id: StringName) -> int:
	var count: int = 0
	for id: Variant in _attacking.keys():
		if StringName(id) != except_id and bool((_attacking[id] as Dictionary).get("rear", false)):
			count += 1
	return count


func clear() -> void:
	_holders.clear()
	_queue.clear()
	_queued_at.clear()
	_flanker.clear()
	_impacts.clear()
	_attacking.clear()
