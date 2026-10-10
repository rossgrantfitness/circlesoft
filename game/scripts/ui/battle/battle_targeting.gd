class_name BattleTargeting
extends RefCounted
## Who a move can hit, and the pointer that picks among them. Pure logic: it works from a
## BattleRoster and a position lookup (the stage's screen_pos_of), so it is tested without nodes.
##
## Target kinds (the `target` field of skills and items; documented in docs/battle_api.md):
##   one_enemy, all_enemies, one_ally (standing), one_down_ally (Down for the Count), all_allies,
##   self. Anything unknown is treated as one_enemy.

const KIND_ONE_ENEMY: String = "one_enemy"
const KIND_ALL_ENEMIES: String = "all_enemies"
const KIND_ONE_ALLY: String = "one_ally"
const KIND_ONE_DOWN_ALLY: String = "one_down_ally"
const KIND_ALL_ALLIES: String = "all_allies"
const KIND_SELF: String = "self"

## One pointer that hops between candidates, or the whole group lit up.
var is_all: bool = false
var candidates: Array[String] = []
var kind: String = KIND_ONE_ENEMY

var _index: int = 0
var _positions: Dictionary[String, Vector2] = {}


## Normalizes unknown target strings.
static func normalize(target_kind: String) -> String:
	match target_kind:
		KIND_ONE_ENEMY, KIND_ALL_ENEMIES, KIND_ONE_ALLY, KIND_ONE_DOWN_ALLY, KIND_ALL_ALLIES, KIND_SELF:
			return target_kind
	return KIND_ONE_ENEMY


## True when the move needs no choice (it always hits the user).
static func needs_no_pick(target_kind: String) -> bool:
	return normalize(target_kind) == KIND_SELF


static func is_all_kind(target_kind: String) -> bool:
	var k: String = normalize(target_kind)
	return k == KIND_ALL_ENEMIES or k == KIND_ALL_ALLIES


## The ids a move of this kind can be aimed at right now.
static func candidates_for(target_kind: String, roster: BattleRoster, actor_id: String) -> Array[String]:
	match normalize(target_kind):
		KIND_ALL_ENEMIES, KIND_ONE_ENEMY:
			return roster.live_ids(BattleRoster.SIDE_ENEMY)
		KIND_ALL_ALLIES, KIND_ONE_ALLY:
			return roster.live_ids(BattleRoster.SIDE_PARTY)
		KIND_ONE_DOWN_ALLY:
			return roster.down_ids(BattleRoster.SIDE_PARTY)
		KIND_SELF:
			var me: Array[String] = []
			me.append(actor_id)
			return me
	return []


## Starts a pick. `pos_of` maps an id to its screen position. `remembered` is the last target this
## fighter picked (used when still valid). Returns false when there is nobody to aim at.
func start(target_kind: String, roster: BattleRoster, actor_id: String, pos_of: Callable, remembered: String = "") -> bool:
	kind = normalize(target_kind)
	is_all = is_all_kind(kind)
	candidates = candidates_for(kind, roster, actor_id)
	_positions.clear()
	for id: String in candidates:
		_positions[id] = pos_of.call(id)
	_index = maxi(0, candidates.find(remembered))
	return not candidates.is_empty()


func get_selected() -> String:
	if candidates.is_empty():
		return ""
	return candidates[_index]


## Where the pointer is now: the ids that will be hit if the player confirms.
func selected_ids() -> Array[String]:
	if is_all:
		return candidates.duplicate()
	var one: Array[String] = []
	if not candidates.is_empty():
		one.append(candidates[_index])
	return one


func position_of(id: String) -> Vector2:
	return _positions.get(id, Vector2.ZERO)


func set_selected(id: String) -> bool:
	var found: int = candidates.find(id)
	if found < 0:
		return false
	_index = found
	return true


## Hops the pointer toward `direction` (UP/DOWN/LEFT/RIGHT as a unit Vector2i). Prefers the nearest
## candidate in that direction on screen; at the edge it wraps around the list. Returns true when
## it moved. All-target picks never move.
func move(direction: Vector2i) -> bool:
	if is_all or candidates.size() < 2:
		return false
	var aim: Vector2 = Vector2(direction)
	var here: Vector2 = _positions[candidates[_index]]
	var side: Vector2 = Vector2(-aim.y, aim.x)
	var best: int = -1
	var best_score: float = INF
	for i: int in candidates.size():
		if i == _index:
			continue
		var delta: Vector2 = _positions[candidates[i]] - here
		var along: float = delta.dot(aim)
		if along < 1.0:
			continue
		var score: float = along + 2.0 * absf(delta.dot(side))
		if score < best_score:
			best_score = score
			best = i
	if best < 0:
		# Nothing further that way: wrap around the list (up/left = previous, down/right = next).
		var step: int = -1 if (direction.x < 0 or direction.y < 0) else 1
		best = posmod(_index + step, candidates.size())
	_index = best
	return true


## The candidate under a screen point (within `radius`), or "".
func pick_at(point: Vector2, radius: float) -> String:
	var best: String = ""
	var best_distance: float = radius
	for id: String in candidates:
		var distance: float = _positions[id].distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best = id
	return best
