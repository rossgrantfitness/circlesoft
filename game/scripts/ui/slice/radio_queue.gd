class_name RadioQueue
extends RefCounted
## The radio bark box's line queue, with no drawing. Lines wait their turn; each one types out, holds for a time
## that grows with its length, then leaves. `say()` returns false when the same line is already showing or waiting
## (a bark that fires every frame can't flood the box). Timings: data/ui/slice_ui.json "radio".

var queue: Array[Dictionary] = []
var current: Dictionary = {}
## Seconds since the current line started.
var age: float = 0.0

var _gap_left: float = 0.0


## Adds a line. `speaker` is an id ("vela"); the box looks the name up. `priority` lines jump the queue.
func say(speaker: String, text: String, priority: bool = false) -> bool:
	if text.strip_edges().is_empty():
		return false
	if _same(current, speaker, text):
		return false
	for entry: Dictionary in queue:
		if _same(entry, speaker, text):
			return false
	var line: Dictionary = {"speaker": speaker, "text": text}
	if priority:
		queue.push_front(line)
	else:
		queue.append(line)
	var cap: int = SliceUiData.whole("radio.queue_max", 6)
	while queue.size() > cap:
		queue.pop_back()
	if current.is_empty() and _gap_left <= 0.0:
		_next()
	return true


func _same(entry: Dictionary, speaker: String, text: String) -> bool:
	return not entry.is_empty() and str(entry.get("speaker", "")) == speaker and str(entry.get("text", "")) == text


func is_showing() -> bool:
	return not current.is_empty()


func is_idle() -> bool:
	return current.is_empty() and queue.is_empty()


## Characters of the current line typed so far.
func chars_shown() -> int:
	if current.is_empty():
		return 0
	var slide: float = SliceUiData.num("radio.slide_s", 0.18)
	return mini(str(current["text"]).length(), maxi(0, int((age - slide) * SliceUiData.num("radio.chars_per_s", 42.0))))


func hold_s(text: String) -> float:
	return SliceUiData.num("radio.hold_base_s", 1.2) + float(text.length()) * SliceUiData.num("radio.hold_per_char_s", 0.035)


func line_life_s() -> float:
	if current.is_empty():
		return 0.0
	var text: String = str(current["text"])
	return SliceUiData.num("radio.slide_s", 0.18) + float(text.length()) / SliceUiData.num("radio.chars_per_s", 42.0) + hold_s(text) + SliceUiData.num("radio.fade_s", 0.3)


## 0..1: how much of the box is on screen (slides in, fades out).
func presence() -> float:
	if current.is_empty():
		return 0.0
	var slide: float = SliceUiData.num("radio.slide_s", 0.18)
	var fade: float = SliceUiData.num("radio.fade_s", 0.3)
	var life: float = line_life_s()
	if age < slide:
		return clampf(age / maxf(0.01, slide), 0.0, 1.0)
	if age > life - fade:
		return clampf((life - age) / maxf(0.01, fade), 0.0, 1.0)
	return 1.0


func clear() -> void:
	queue.clear()
	current = {}
	age = 0.0
	_gap_left = 0.0


func tick(delta: float) -> void:
	if current.is_empty():
		if _gap_left > 0.0:
			_gap_left -= delta
		if _gap_left <= 0.0 and not queue.is_empty():
			_next()
		return
	age += delta
	if age >= line_life_s():
		current = {}
		_gap_left = SliceUiData.num("radio.between_s", 0.15)


func _next() -> void:
	current = queue.pop_front()
	age = 0.0
