class_name ComboString
extends RefCounted
## Where Red is in her current attack string (docs/pivot/kh_combo_design.md). Pure bookkeeping on her own
## combat clock: no nodes. ComboSelector reads `from_move()` and `pos()` to pick the next move.
##
## * `begin(move, restart, now)`  a move of the string started. `restart` puts the count back to 1.
## * `end(now)`                   the move finished (or was cut short); the timeout clock starts.
## * `from_move(now, busy)`       the move a press should continue from: the one still playing, or the last one
##                                if it ended less than `string_timeout_ms` ago, else `idle`.
## * `reset()`                    the string is gone (a dash, jump, parry or a hit on Red).
## Times are microseconds on Red's combat clock, so hit-stop freezes the timeout too.

const IDLE: StringName = &"idle"

var timeout_ms: float = 500.0
var _move: StringName = &""
var _pos: int = 0
var _ended_usec: int = -1       # -1 = the move is still playing (or there is no move)


static func create(string_timeout_ms: float) -> ComboString:
	var out: ComboString = ComboString.new()
	out.timeout_ms = string_timeout_ms
	return out


func begin(move_id: StringName, restart: bool) -> void:
	_pos = 1 if restart else _pos + 1
	_move = move_id
	_ended_usec = -1


func end(now_usec: int) -> void:
	if _move != &"" and _ended_usec < 0:
		_ended_usec = now_usec


func reset() -> void:
	_move = &""
	_pos = 0
	_ended_usec = -1


## How many attack hits the string has started (0 = none).
func pos() -> int:
	return _pos


func last_move() -> StringName:
	return _move


## The move a press at `now_usec` continues from. `busy` = a move is still playing.
func from_move(now_usec: int, busy: bool) -> StringName:
	if _move == &"":
		return IDLE
	if busy or _ended_usec < 0:
		return _move
	if float(now_usec - _ended_usec) / 1000.0 > timeout_ms:
		return IDLE
	return _move


## Has the string run out of time? (Lets the owner tidy up; from_move() already answers `idle`.)
func expired(now_usec: int) -> bool:
	return _move != &"" and _ended_usec >= 0 and float(now_usec - _ended_usec) / 1000.0 > timeout_ms
