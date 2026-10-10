class_name LocationCard
extends Control
## The location card (VS-11): on entering an area a thin band slides across the screen with the area's name in the
## slanted face and its kind ("Town", "Dungeon") in small caps, holds, and fades. Not shown again while Red walks
## between rooms of the same area, or for rooms whose data says `"card": false`. Names come from the rooms file
## (data/slice/rooms.json: `name`, optional `area` for a shared card name, optional `subtitle`).

signal shown(title: String)

var audio: UiAudio = UiAudio.new()

var _title: String = ""
var _subtitle: String = ""
var _age: float = -1.0
var _last_area: String = ""
var _pending_delay: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Shows a card for a rooms.json entry. Returns false when no card shows (no name, `card: false`, or the same area).
func show_for_room(entry: Dictionary) -> bool:
	if entry.is_empty() or entry.get("card", true) == false:
		return false
	var title: String = str(entry.get("name", ""))
	var area: String = str(entry.get("area", title))
	if title.is_empty() or area == _last_area:
		return false
	var subtitle: String = str(entry.get("subtitle", ""))
	if subtitle.is_empty():
		subtitle = SliceUiData.text("location.kinds.%s" % str(entry.get("kind", "")))
	_last_area = area
	show_card(title, subtitle)
	return true


## Shows a card now (after a short beat so it lands as the room fades in).
func show_card(title: String, subtitle: String = "") -> void:
	_title = title
	_subtitle = subtitle
	_age = 0.0
	_pending_delay = SliceUiData.num("location_card.delay_s", 0.35)
	shown.emit(title)


## Forget the last area (a new game, or back at the title) so the next room shows its card again.
func forget_area() -> void:
	_last_area = ""


func is_showing() -> bool:
	return _age >= 0.0


func get_title() -> String:
	return _title


func get_subtitle() -> String:
	return _subtitle


func last_area() -> String:
	return _last_area


func tick(delta: float) -> void:
	if _age < 0.0:
		return
	if _pending_delay > 0.0:
		_pending_delay -= delta
	else:
		_age += delta
	if _age > _life():
		_age = -1.0
	queue_redraw()


func _life() -> float:
	return SliceUiData.num("location_card.slide_s", 0.3) + SliceUiData.num("location_card.hold_s", 2.2) + SliceUiData.num("location_card.fade_s", 0.5)


## 0..1 of the way in, and the fade.
func _amounts() -> Vector2:
	var slide_s: float = SliceUiData.num("location_card.slide_s", 0.3)
	var fade_s: float = SliceUiData.num("location_card.fade_s", 0.5)
	var slide: float = clampf(_age / maxf(0.01, slide_s), 0.0, 1.0)
	var fade: float = 1.0
	if _age > _life() - fade_s:
		fade = clampf((_life() - _age) / maxf(0.01, fade_s), 0.0, 1.0)
	return Vector2(slide, fade)


func _draw() -> void:
	if _age < 0.0 or _pending_delay > 0.0:
		return
	var amounts: Vector2 = _amounts()
	var h: float = SliceUiData.num("location_card.h", 26)
	var y: float = floorf(size.y * SliceUiData.num("location_card.y_frac", 0.36))
	var ease_out: float = 1.0 - pow(1.0 - amounts.x, 2.0)
	var fade: float = amounts.y
	# A band across the whole picture; the words slide in from the right and settle in the middle.
	var rect: Rect2 = Rect2(0.0, y, size.x, h)
	SandboxStyle.bar(self, rect, Color(SandboxStyle.color("bar_top"), 0.92 * fade), Color(SandboxStyle.color("bar_bottom"), 0.92 * fade))
	var accent: float = SliceUiData.num("location_card.accent_w", 3)
	draw_rect(Rect2(0.0, y + h, size.x * ease_out, accent), Color(SandboxStyle.color("header_top"), fade))
	var slide: float = floorf((1.0 - ease_out) * SliceUiData.num("location_card.slide_px", 24) * 3.0)
	if not _subtitle.is_empty():
		SandboxStyle.text_center(self, "label", slide, y + 8.0, _subtitle.to_upper(), Color(SandboxStyle.color("label"), fade), size.x)
	SandboxStyle.text_center(self, "body", slide, y + h - 6.0, _title, Color(SandboxStyle.color("text"), fade), size.x)
