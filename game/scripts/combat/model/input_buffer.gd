class_name InputBuffer
extends RefCounted
## Remembers button presses for a moment so a press made a little early still counts. It runs on RED'S
## clock (the timestamps you push and the `now` you take with are that clock's microseconds), so while
## Red is frozen in hit-stop the clock stands still and nothing in the buffer expires.
## The length is the feel knob `input_buffer_ms`, read at take() time so the panel works live.

const KNOB_ID: String = "input_buffer_ms"
const DEFAULT_MS: float = 150.0
const MAX_TOKENS: int = 16

var buffer_ms: float = DEFAULT_MS      ## used when no knobs are attached
var _feel: FeelKnobs = null
var _tokens: Array[Dictionary] = []    # {token, t}


static func create(feel: FeelKnobs = null) -> InputBuffer:
	var buffer: InputBuffer = InputBuffer.new()
	buffer._feel = feel
	return buffer


func window_ms() -> float:
	if _feel != null and _feel.has(KNOB_ID):
		return _feel.get_f(KNOB_ID)
	return buffer_ms


func push(token: StringName, t_usec: int) -> void:
	_tokens.append({"token": token, "t": t_usec})
	while _tokens.size() > MAX_TOKENS:
		_tokens.pop_front()


## The oldest token still inside the buffer that `accept` (token: StringName -> bool) allows. It is
## removed. Tokens that are too old are dropped; tokens `accept` refuses stay for later.
func take(now_usec: int, accept: Callable) -> StringName:
	_drop_expired(now_usec)
	for i: int in range(_tokens.size()):
		var token: StringName = _tokens[i]["token"]
		if bool(accept.call(token)):
			_tokens.remove_at(i)
			return token
	return &""


## Like take() but leaves the buffer alone.
func peek(now_usec: int, accept: Callable) -> StringName:
	_drop_expired(now_usec)
	for entry: Dictionary in _tokens:
		var token: StringName = entry["token"]
		if bool(accept.call(token)):
			return token
	return &""


## Keeps one waiting press of `token` alive: the newest one is stamped `now_usec` again and older copies are dropped.
## For a press made during a move that has no cancel window yet (the launcher, air 3): it waits for the move to end
## instead of timing out. Returns true if there was a press to keep.
func hold_latest(token: StringName, now_usec: int) -> bool:
	var found: int = -1
	for i: int in range(_tokens.size()):
		if _tokens[i]["token"] == token:
			found = i
	if found < 0:
		return false
	var kept: Array[Dictionary] = []
	for i: int in range(_tokens.size()):
		if _tokens[i]["token"] != token or i == found:
			kept.append(_tokens[i])
	_tokens = kept
	for entry: Dictionary in _tokens:
		if entry["token"] == token:
			entry["t"] = now_usec
	return true


func has_token(token: StringName, now_usec: int) -> bool:
	_drop_expired(now_usec)
	for entry: Dictionary in _tokens:
		if entry["token"] == token:
			return true
	return false


func size() -> int:
	return _tokens.size()


func clear() -> void:
	_tokens.clear()


func _drop_expired(now_usec: int) -> void:
	var limit_usec: int = int(window_ms() * 1000.0)
	var kept: Array[Dictionary] = []
	for entry: Dictionary in _tokens:
		if now_usec - int(entry["t"]) <= limit_usec:
			kept.append(entry)
	_tokens = kept
