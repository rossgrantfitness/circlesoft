class_name RadioBark
extends Control
## The radio bark box (VS-11): Vela's voice in Red's ear. A small dark panel with a teal edge sliding in above the
## bottom-left corner: a portrait square on the left (a placeholder with the speaker's initial and a flicker of radio
## static until the portraits arrive, VS-46), the speaker's name in small caps, and the line typed out in the slanted
## face, two lines at most. Lines queue; each holds long enough to read. RadioQueue holds the state.
## Say something with `say("vela", "Turret on the left, Red.")`; text for speaker names is in data/text/slice_ui.json.

## A line just finished typing its last letter.
signal line_finished(speaker: String, text: String)

var queue: RadioQueue = RadioQueue.new()
var audio: UiAudio = UiAudio.new()

var _clock: float = 0.0
var _last_chars: int = 0
var _announced: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func say(speaker: String, text: String, priority: bool = false) -> bool:
	return queue.say(speaker, text, priority)


func speaker_name(speaker: String) -> String:
	var named: String = SliceUiData.text("radio.speakers.%s" % speaker)
	return named if not named.is_empty() else (SliceUiData.text("radio.default_speaker") if speaker.is_empty() else speaker.capitalize())


## The line on screen now, with its speaker name and how many letters are typed.
func current_line() -> Dictionary:
	if not queue.is_showing():
		return {}
	var text: String = str(queue.current["text"])
	return {"speaker": str(queue.current["speaker"]), "name": speaker_name(str(queue.current["speaker"])), "text": text, "shown": text.substr(0, queue.chars_shown())}


func tick(delta: float) -> void:
	_clock += delta
	var before: RadioQueue = queue
	var was_showing: bool = queue.is_showing()
	var key: Dictionary = queue.current
	queue.tick(delta)
	if queue.is_showing():
		var chars: int = queue.chars_shown()
		if queue.current != key:
			_last_chars = 0
			_announced = false
		if chars > _last_chars and chars % 3 == 0:
			audio.sfx("tick")
		_last_chars = chars
		var text: String = str(queue.current["text"])
		if chars >= text.length() and not _announced:
			_announced = true
			line_finished.emit(str(queue.current["speaker"]), text)
	elif was_showing:
		_last_chars = 0
		_announced = false
	if before == queue:
		queue_redraw()


## The box's rectangle, bottom-left. It grows taller for a line that wraps to a second or third row (decided from the
## whole line, so it doesn't jump while the letters type), never shorter than the portrait.
func box_rect(ui_size: Vector2, line_count: int = 2) -> Rect2:
	var w: float = SliceUiData.num("radio.w", 240)
	var pad: float = SliceUiData.num("radio.pad", 4)
	var step: float = SliceUiData.num("radio.line_step", 14)
	var h: float = maxf(SliceUiData.num("radio.portrait", 26) + pad * 2.0, 14.0 + step * float(line_count) + pad)
	return Rect2(SliceUiData.num("radio.x_from_left", 8), ui_size.y - SliceUiData.num("radio.bottom_gap", 22) - h, w, h)


## The line wrapped to the box's text width (at most `radio.max_lines` rows).
func wrapped_lines(text: String) -> PackedStringArray:
	var wrap_w: int = int(SliceUiData.num("radio.w", 240) - SliceUiData.num("radio.text_x", 36) - SliceUiData.num("radio.pad", 4) - 2.0)
	var lines: PackedStringArray = TextWrap.wrap(SandboxStyle.font("body"), SandboxStyle.font_size("body"), text, wrap_w)
	return lines.slice(0, SliceUiData.whole("radio.max_lines", 3))


func _draw() -> void:
	if not queue.is_showing():
		return
	var presence: float = queue.presence()
	var line: Dictionary = current_line()
	var lines: PackedStringArray = wrapped_lines(str(line["text"]))
	var rect: Rect2 = box_rect(size, lines.size())
	rect.position.x -= floorf((1.0 - presence) * 30.0)
	modulate = Color(1, 1, 1, presence)
	var pad: float = SliceUiData.num("radio.pad", 4)
	SandboxStyle.list_bar(self, rect, false)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), SliceUiData.color("radio_edge"))
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - 1.0), Vector2(rect.size.x, 1.0)), SliceUiData.color("radio_edge").darkened(0.5))
	_draw_portrait(Rect2(rect.position + Vector2(pad, pad), Vector2.ONE * SliceUiData.num("radio.portrait", 26)))
	var text_x: float = rect.position.x + SliceUiData.num("radio.text_x", 36)
	SandboxStyle.label(self, Vector2(text_x, rect.position.y + 10.0), str(line["name"]), SliceUiData.color("radio_edge"))
	var tag: String = SliceUiData.text("radio.static_tag")
	SandboxStyle.text_right(self, "label", rect.end.x - pad, rect.position.y + 10.0, tag.to_upper(), SandboxStyle.color("label_dim"), 40.0)
	var shown: int = str(line["shown"]).length()
	var step: float = SliceUiData.num("radio.line_step", 14)
	var y: float = rect.position.y + 11.0 + step
	var spent: int = 0
	for i: int in lines.size():
		var piece: String = lines[i]
		var take: int = clampi(shown - spent, 0, piece.length())
		SandboxStyle.text(self, "body", Vector2(text_x, y), piece.substr(0, take), SandboxStyle.color("text"))
		spent += piece.length() + 1
		y += step


## The portrait stand-in: a dark teal tile, the speaker's first letter, and scan lines that crawl while she talks.
func _draw_portrait(rect: Rect2) -> void:
	draw_rect(rect.grow(1.0), SandboxStyle.color("shadow"))
	draw_rect(rect, SliceUiData.color("radio_portrait_back"))
	var speaker: String = str(queue.current.get("speaker", ""))
	var initial: String = speaker_name(speaker).substr(0, 1).to_upper()
	SandboxStyle.text_center(self, "title", rect.position.x, rect.position.y + rect.size.y - 6.0, initial, SliceUiData.color("radio_portrait_ink"), rect.size.x)
	var step: int = int(_clock / SliceUiData.num("radio.static_step_s", 0.0833))
	var talking: bool = queue.chars_shown() < str(queue.current["text"]).length()
	var lines: int = 3
	for i: int in lines:
		var row: float = float((step * 5 + i * 9) % int(rect.size.y))
		if talking or i == 0:
			draw_rect(Rect2(rect.position.x, rect.position.y + row, rect.size.x, 1.0), Color(1, 1, 1, 0.12))
