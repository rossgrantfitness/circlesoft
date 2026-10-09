extends TestCase
var _kit: HackKit = null
func test_debug_turret() -> void:
	_kit = HackKit.new(self)
	await _kit.arena(true)
	var turret: ActionEnemy = _kit.spawn(HackKit.TURRET_SCENE, Vector3(0, 0, 10), PI)
	await _kit.settle()
	for i in range(6):
		await _kit.frames(60)
		print("DBG turret state=%s brain=%s intent=%s busy=%s tok=%s dist=%.1f" % [turret.body_state, turret.brain.state(), turret.last_intent, turret.runner.is_busy(), _kit.director.tokens.has_token(turret.actor_id), turret.global_position.distance_to(_kit.red.global_position)])
func test_debug_zap() -> void:
	_kit = HackKit.new(self)
	await _kit.arena(false)
	_kit.battery().set_charge(100.0)
	var drone: ActionEnemy = _kit.spawn(HackKit.DRONE_SCENE, Vector3(0, 0, 6))
	await _kit.settle()
	await _kit.frames(30)
	await _kit.tap_hack()
	for i in range(8):
		await _kit.frames(10)
		print("DBG drone hp=%d y=%.2f state=%s hits=%s" % [drone.hp, drone.global_position.y, drone.body_state, _kit.hits.size()])
