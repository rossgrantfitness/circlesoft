class_name BattleClock
extends RefCounted
## Time source for a battle. The battle logic never reads the system clock itself: the game
## passes a RealClock, the simulator and tests pass a VirtualClock that jumps instantly.
##
## Subclasses override now_usec() and _prepare_wait(); wait_until_usec() itself is the one
## awaitable, so a clock held in any typed variable awaits the same way.

const DEFAULT_POLL_USEC: int = 8000


func now_usec() -> int:
	return 0


## Awaitable: returns once the clock has reached t_usec.
func wait_until_usec(t_usec: int) -> void:
	var gate: Signal = _prepare_wait(t_usec)
	if not gate.is_null():
		await gate


## Longest wait before the controller looks for newly arrived presses again.
func poll_usec() -> int:
	return DEFAULT_POLL_USEC


## Returns a Signal to await until t_usec, or a null Signal when time is already there.
func _prepare_wait(_t_usec: int) -> Signal:
	return Signal()
