class_name AttackTokens
extends RefCounted
## Only a few enemies may attack at once (`max_attackers` in enemies.json, start 2). An enemy asks for a
## token, attacks while it holds one and gives it back when its move ends. Enemies that asked and were
## refused queue up, so the one waiting longest gets the next free token (nobody starves).

var max_attackers: int = 2
var _holders: Array[StringName] = []
var _queue: Array[StringName] = []


static func create(max_count: int = 2) -> AttackTokens:
	var tokens: AttackTokens = AttackTokens.new()
	tokens.max_attackers = maxi(max_count, 0)
	return tokens


static func from_data(enemies_doc: Dictionary) -> AttackTokens:
	return create(int(enemies_doc.get("max_attackers", 2)))


func request(enemy_id: StringName) -> bool:
	if _holders.has(enemy_id):
		return true
	if not _queue.has(enemy_id):
		_queue.append(enemy_id)
	var free: int = max_attackers - _holders.size()
	if _queue.find(enemy_id) < free:
		_queue.erase(enemy_id)
		_holders.append(enemy_id)
		return true
	return false


func release(enemy_id: StringName) -> void:
	_holders.erase(enemy_id)
	_queue.erase(enemy_id)


func has_token(enemy_id: StringName) -> bool:
	return _holders.has(enemy_id)


func holders() -> Array[StringName]:
	return _holders.duplicate()


func waiting() -> Array[StringName]:
	return _queue.duplicate()


func clear() -> void:
	_holders.clear()
	_queue.clear()
