class_name VirtualClock
extends BattleClock
## A clock that jumps: waiting just moves time forward. Used by the simulator and the tests.

const NEVER_POLL_USEC: int = 1 << 40

var _now_usec: int = 0


func _init(start_usec: int = 0) -> void:
	_now_usec = start_usec


func now_usec() -> int:
	return _now_usec


func advance_usec(delta_usec: int) -> void:
	_now_usec += maxi(delta_usec, 0)


func poll_usec() -> int:
	return NEVER_POLL_USEC


func _prepare_wait(t_usec: int) -> Signal:
	if t_usec > _now_usec:
		_now_usec = t_usec
	return Signal()
