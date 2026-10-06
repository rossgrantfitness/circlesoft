class_name RealClock
extends BattleClock
## The game's clock: Time.get_ticks_usec(), the same clock the view stamps presses with.

const USEC_PER_SEC: float = 1000000.0


func now_usec() -> int:
	return Time.get_ticks_usec()


func _prepare_wait(t_usec: int) -> Signal:
	var remaining: int = t_usec - Time.get_ticks_usec()
	if remaining <= 0:
		return Signal()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return Signal()
	return tree.create_timer(float(remaining) / USEC_PER_SEC, true, false, true).timeout
