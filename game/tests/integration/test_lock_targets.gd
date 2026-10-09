extends TestCase
## Lock-on reaches hack targets (docs/slice/slice_tech_plan.md 4.3): nodes in group `lock_targets` (relays on the
## Hushmaster, turrets, fuse boxes marked `lockable`) can be locked on to. Enemies stay the first choice when both are in
## front; a flick switches between the two kinds; a dead or not-lockable one is skipped.

class Relay extends Node3D:
	var hp: int = 60
	var lockable: bool = true

var _lock: LockOn = null
var _origin: Node3D = null
var _enemies: Array[Node3D] = []


func _setup() -> void:
	_origin = Node3D.new()
	add_to_root(_origin)
	_lock = LockOn.new()
	_lock.read_engine_input = false
	add_to_root(_lock)
	_lock.origin_node = _origin
	_lock.candidate_provider = func() -> Array: return _enemies


func _relay(at: Vector3) -> Relay:
	var relay: Relay = Relay.new()
	add_to_root(relay)
	relay.add_to_group(LockOn.GROUP_LOCK_TARGETS)
	relay.global_position = at
	return relay


func _enemy(at: Vector3) -> Node3D:
	var node: Node3D = Node3D.new()
	add_to_root(node)
	node.global_position = at
	_enemies.append(node)
	return node


func test_a_lock_target_can_be_locked_when_no_enemy_is_near() -> void:
	_setup()
	var relay: Relay = _relay(Vector3(0, 0, -6))
	var picked: Node3D = _lock.toggle()
	assert_eq(picked, relay)
	assert_eq(_lock.get_target(), relay)


func test_enemies_stay_the_first_choice_even_when_a_relay_is_closer() -> void:
	_setup()
	_relay(Vector3(0, 0, -3))
	var enemy: Node3D = _enemy(Vector3(0, 0, -8))
	assert_eq(_lock.toggle(), enemy)


func test_a_flick_switches_from_an_enemy_to_a_relay_beside_it() -> void:
	_setup()
	var enemy: Node3D = _enemy(Vector3(-2, 0, -6))
	var relay: Relay = _relay(Vector3(3, 0, -6))
	_lock.toggle()
	assert_eq(_lock.get_target(), enemy)
	_lock.switch(Vector2(1, 0))
	assert_eq(_lock.get_target(), relay, "a flick to the right reaches the relay")
	_lock.switch(Vector2(-1, 0))
	assert_eq(_lock.get_target(), enemy, "and back")


func test_a_dead_relay_is_not_a_target() -> void:
	_setup()
	var relay: Relay = _relay(Vector3(0, 0, -6))
	relay.hp = 0
	assert_null(_lock.toggle())


func test_a_relay_that_is_not_lockable_is_skipped() -> void:
	_setup()
	var relay: Relay = _relay(Vector3(0, 0, -6))
	relay.lockable = false
	assert_null(_lock.toggle())


func test_a_relay_out_of_range_is_not_a_target() -> void:
	_setup()
	_relay(Vector3(0, 0, -40))
	assert_null(_lock.toggle())


func test_a_locked_relay_that_breaks_drops_the_lock() -> void:
	_setup()
	var relay: Relay = _relay(Vector3(0, 0, -6))
	_lock.toggle()
	relay.hp = 0
	_lock.tick(0.016)
	assert_null(_lock.get_target())


func test_attack_magnetism_still_ignores_relays() -> void:
	_setup()
	_relay(Vector3(0, 0, -1.5))
	assert_null(_lock.soft_target(Vector3(0, 0, -1), Vector3(0, 0, -1)), "a swing does not snap to a fuse box")
