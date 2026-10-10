class_name TypeWriter
extends RefCounted
## Reveals text one character at a time. Pure logic with no nodes and no clock: feed it time with
## advance(delta). Each character costs 1 / chars_per_second seconds; a punctuation mark that ends
## a word adds a pause (data/ui/dialogue_ui.json, typing.pauses). Line breaks reveal together with
## the character before them, so they never cost time.

var _text: String = ""
var _count: int = 0
var _cps: float = 30.0
var _pauses: Dictionary = {}
var _clock: float = 0.0
var _wait: float = 0.0


func start(text: String, chars_per_second: float, pauses: Dictionary = {}) -> void:
	_text = text
	_count = 0
	_cps = maxf(chars_per_second, 0.001)
	_pauses = pauses
	_clock = 0.0
	_wait = 0.0


## Gives it `delta` seconds. Returns the characters revealed during this call (often empty).
func advance(delta: float) -> String:
	var revealed: String = ""
	if is_done():
		return revealed
	_clock += delta
	while _count < _text.length() and _clock >= _wait:
		_clock -= _wait
		var character: String = _text[_count]
		_count += 1
		revealed += character
		while _count < _text.length() and _text[_count] == "\n":
			revealed += "\n"
			_count += 1
		_wait = 1.0 / _cps + _pause_after(character, _count)
	return revealed


## Reveals everything left at once. Returns the characters that were still hidden.
func finish() -> String:
	var rest: String = _text.substr(_count)
	_count = _text.length()
	return rest


func is_done() -> bool:
	return _count >= _text.length()


func get_visible_text() -> String:
	return _text.substr(0, _count)


func get_visible_count() -> int:
	return _count


func get_text() -> String:
	return _text


func _pause_after(character: String, next_index: int) -> float:
	if not _pauses.has(character):
		return 0.0
	# Only pause where the punctuation ends a word, so "..." and "?!" pause once, at the end.
	if next_index < _text.length() and not _text[next_index] in [" ", "\n"]:
		return 0.0
	return float(_pauses[character])
