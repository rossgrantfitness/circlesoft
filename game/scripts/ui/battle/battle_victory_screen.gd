class_name BattleVictoryScreen
extends Control
## The victory screen: Red's thumbs-up (placeholder icon, the pose itself is the stage's job), the
## XP and credit totals counting up fast, drops, then a card per level-up with the stat gains and
## any skill learned. One press skips the counting straight to the final numbers; the screen then
## closes by itself after a short beat, or on the next press.
##
## The HUD owns the clock (tick) and forwards presses (press). `finished` fires once, when the screen
## is done. Numbers and layout come from data/ui/battle_ui.json and data/text/battle.json.

signal finished

const THUMBS_UP: String = "thumbs_up"
const BEAT_XP: String = "xp"
const BEAT_CREDITS: String = "credits"
const BEAT_DROP: String = "drop"
const BEAT_LEVEL: String = "level"

var roster: BattleRoster = BattleRoster.new()
## id -> display name for skills and items the HUD has seen (anything else is prettified).
var names: Dictionary = {}

var _report: Dictionary = {}
var _beats: Array[Dictionary] = []
var _total_s: float = 0.0
var _t: float = 0.0
var _since_shown: float = 0.0
var _hold_clock: float = 0.0
var _showing: bool = false
var _finished: bool = false
var _dim: DitherFade = null
var _window: UiWindow = null
var _drawing: Control = null
var _cfg: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	_dim = DitherFade.new()
	_dim.name = "Dim"
	_dim.size = size
	add_child(_dim)
	var rect: Rect2 = BattleUiData.ui_rect("layout.victory")
	_window = UiWindow.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.position = rect.position
	_window.size = rect.size
	add_child(_window)
	_drawing = Control.new()
	_drawing.name = "Contents"
	_drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawing.position = rect.position
	_drawing.size = rect.size
	_drawing.draw.connect(_draw_contents)
	add_child(_drawing)
	visible = false


## Shows the screen for a `battle_ended` report: {xp, credits, drops: [{item, count}], level_ups: [...]}.
func show_report(report: Dictionary) -> void:
	_report = report
	_cfg = BattleUiData.ui("victory", {})
	_build_beats()
	_t = 0.0
	_since_shown = 0.0
	_hold_clock = 0.0
	_finished = false
	_showing = true
	_dim.step_count = 8
	_dim.step = int(_cfg.get("dim_step", 4))
	visible = true
	_drawing.queue_redraw()


func is_showing() -> bool:
	return _showing and not _finished


## True while the totals are still counting up.
func is_counting() -> bool:
	return _showing and _t < _total_s


func is_complete() -> bool:
	return _showing and _t >= _total_s


func get_total_time() -> float:
	return _total_s


func get_shown_xp() -> int:
	return _shown_value(BEAT_XP, int(_report.get("xp", 0)))


func get_shown_credits() -> int:
	return _shown_value(BEAT_CREDITS, int(_report.get("credits", 0)))


func get_shown_drop_count() -> int:
	return _revealed(BEAT_DROP)


func get_shown_level_up_count() -> int:
	return _revealed(BEAT_LEVEL)


## What the screen says right now, one string per line (tests read this).
func get_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append(BattleUiData.text("victory.title"))
	lines.append("%s %d" % [BattleUiData.text("victory.xp"), get_shown_xp()])
	lines.append("%s %d" % [BattleUiData.text("victory.credits"), get_shown_credits()])
	var drops: Array = _report.get("drops", [])
	for i: int in mini(get_shown_drop_count(), drops.size()):
		lines.append(_drop_text(drops[i]))
	var ups: Array = _report.get("level_ups", [])
	for i: int in mini(get_shown_level_up_count(), ups.size()):
		lines.append(_level_title(ups[i]))
		for learned: String in _learned_lines(ups[i]):
			lines.append(learned)
	return lines


func _build_beats() -> void:
	_beats.clear()
	var at: float = 0.0
	var min_s: float = float(_cfg.get("count_min_s", 0.35))
	var max_s: float = float(_cfg.get("count_max_s", 1.0))
	var xp: int = int(_report.get("xp", 0))
	var credits: int = int(_report.get("credits", 0))
	var xp_s: float = clampf(float(xp) / float(_cfg.get("xp_rate", 400.0)), min_s, max_s)
	_beats.append({"type": BEAT_XP, "index": 0, "start": at, "dur": xp_s})
	at += xp_s
	var credits_s: float = clampf(float(credits) / float(_cfg.get("credits_rate", 400.0)), min_s, max_s)
	_beats.append({"type": BEAT_CREDITS, "index": 0, "start": at, "dur": credits_s})
	at += credits_s
	var drops: Array = _report.get("drops", [])
	for i: int in drops.size():
		_beats.append({"type": BEAT_DROP, "index": i, "start": at, "dur": float(_cfg.get("row_reveal_s", 0.18))})
		at += float(_cfg.get("row_reveal_s", 0.18))
	var ups: Array = _report.get("level_ups", [])
	for i: int in ups.size():
		_beats.append({"type": BEAT_LEVEL, "index": i, "start": at, "dur": float(_cfg.get("level_reveal_s", 0.3))})
		at += float(_cfg.get("level_reveal_s", 0.3))
	_total_s = at


func _shown_value(beat_type: String, final_value: int) -> int:
	for beat: Dictionary in _beats:
		if beat["type"] == beat_type:
			var progress: float = clampf((_t - float(beat["start"])) / maxf(0.001, float(beat["dur"])), 0.0, 1.0)
			return int(round(float(final_value) * progress))
	return final_value if _showing else 0


func _revealed(beat_type: String) -> int:
	var count: int = 0
	for beat: Dictionary in _beats:
		if beat["type"] == beat_type and _t >= float(beat["start"]):
			count += 1
	return count


# ---- time and input ----

func tick(delta: float) -> void:
	if not _showing or _finished:
		return
	_since_shown += delta
	var left: float = delta
	if _t < _total_s:
		var used: float = minf(left, _total_s - _t)
		_t += used
		left -= used
	if _t >= _total_s:
		_hold_clock += left
		if _hold_clock >= float(_cfg.get("hold_after_s", 1.4)):
			_finish()
	_drawing.queue_redraw()


## Jumps every count to its final number.
func skip() -> void:
	if _showing and _t < _total_s:
		_t = _total_s
		_drawing.queue_redraw()


## A confirm press or click. The first press skips the counting; the next one closes the screen.
## Presses in the first moments are ignored so the Clutch button from the last hit can't skip it.
## Returns true when it did something.
func press() -> bool:
	if not _showing or _finished:
		return false
	if _since_shown < float(_cfg.get("input_grace_s", 0.4)):
		return false
	if _t < _total_s:
		skip()
		return true
	_finish()
	return true


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_showing = false
	visible = false
	finished.emit()


# ---- text ----

func _display_name(id: String) -> String:
	return str(names.get(id, BattleUiData.name_of(id)))


func _drop_text(drop: Dictionary) -> String:
	var count: int = int(drop.get("count", 1))
	var label: String = _display_name(str(drop.get("item", "")))
	return label if count <= 1 else "%s x%d" % [label, count]


func _level_title(up: Dictionary) -> String:
	return BattleUiData.fmt(BattleUiData.text("victory.level_up"), {"name": roster.name_of(str(up.get("id", ""))), "to": int(up.get("to", 0))})


func _learned_lines(up: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for skill: Variant in up.get("learned", []):
		out.append(BattleUiData.fmt(BattleUiData.text("victory.learned"), {"skill": _display_name(str(skill))}))
	return out


## "HP +6" style entries for a level-up's gains, in the stat order of battle.json.
func gain_entries(up: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var gains: Dictionary = up.get("gains", {})
	var stat_names: Dictionary = DataDB.get_value(BattleUiData.TEXT_ID, "stats", {})
	var order: Array = stat_names.keys()
	for stat: Variant in gains:
		if not order.has(stat):
			order.append(stat)
	for stat: Variant in order:
		if gains.has(stat) and int(gains[stat]) != 0:
			out.append("%s %+d" % [str(stat_names.get(stat, BattleUiData.prettify(str(stat)))), int(gains[stat])])
	return out


# ---- drawing ----

func _draw_contents() -> void:
	if not _showing:
		return
	var cfg: Dictionary = BattleUiData.ui("layout.victory", {})
	_draw_icon(cfg)
	_draw_title(cfg)
	var left_w: int = int(cfg.get("left_w", 118))
	var y: int = int(cfg.get("row_y", 100))
	var step: int = int(cfg.get("row_step", 16))
	var dim: Color = BattleUiData.palette("text_dim")
	var chalk: Color = BattleUiData.palette("text")
	UiText.draw(_drawing, "menu", Vector2(12, y), BattleUiData.text("victory.xp"), dim)
	UiText.draw(_drawing, "menu", Vector2(0, y), "+%d" % get_shown_xp(), chalk, HORIZONTAL_ALIGNMENT_RIGHT, left_w - 8)
	y += step
	UiText.draw(_drawing, "menu", Vector2(12, y), BattleUiData.text("victory.credits"), dim)
	UiText.draw(_drawing, "menu", Vector2(0, y), "+%d" % get_shown_credits(), chalk, HORIZONTAL_ALIGNMENT_RIGHT, left_w - 8)
	y += step
	var drops: Array = _report.get("drops", [])
	if drops.is_empty():
		UiText.draw(_drawing, "menu", Vector2(12, y), BattleUiData.text("victory.no_drops"), dim)
	else:
		UiText.draw(_drawing, "menu", Vector2(12, y), BattleUiData.text("victory.drops"), dim)
		y += step
		for i: int in mini(get_shown_drop_count(), drops.size()):
			UiText.draw(_drawing, "tag", Vector2(18, y), _drop_text(drops[i]), BattleUiData.palette("lamp_amber"))
			y += step - 3
	_draw_cards(cfg)
	if is_complete():
		var blink: float = float(_cfg.get("prompt_blink_s", 0.5))
		if int(_since_shown / blink) % 2 == 0:
			UiText.draw(_drawing, "tag", Vector2(0, int(cfg.get("prompt_y", 182))), BattleUiData.fmt(BattleUiData.text("victory.prompt")), dim, HORIZONTAL_ALIGNMENT_RIGHT, _drawing.size.x - 12)


func _draw_icon(cfg: Dictionary) -> void:
	var scale: int = int(cfg.get("icon_scale", 2))
	var frames: Array[ImageTexture] = GestureIcons.get_frames(THUMBS_UP)
	var tile: int = GestureIcons.get_icon_size() * scale + 4
	var at: Vector2i = Vector2i(int(cfg.get("icon_x", 12)), int(cfg.get("icon_y", 12)))
	PixelShape.fill_outlined(_drawing, Rect2i(at, Vector2i(tile, tile)), 6, 1, BattleUiData.palette("ink"), BattleUiData.palette("chalk"))
	if frames.is_empty():
		return
	var frame: int = int(_since_shown / float(_cfg.get("prompt_blink_s", 0.5))) % frames.size()
	_drawing.draw_texture_rect(frames[frame], Rect2(Vector2(at) + Vector2(2, 2), Vector2(tile - 4, tile - 4)), false)


func _draw_title(cfg: Dictionary) -> void:
	var font: Font = UiFonts.get_font("title")
	var size_px: int = int(_cfg.get("title_size", 20))
	var at: Vector2 = Vector2(float(cfg.get("title_x", 12)), float(cfg.get("title_y", 78)))
	var title: String = BattleUiData.text("victory.title")
	_drawing.draw_string_outline(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 4, BattleUiData.palette("ink"))
	_drawing.draw_string(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, BattleUiData.palette("lamp_amber"))


func _draw_cards(cfg: Dictionary) -> void:
	var ups: Array = _report.get("level_ups", [])
	var x: int = int(cfg.get("cards_x", 130))
	var y: int = int(cfg.get("cards_y", 10))
	var w: int = int(cfg.get("card_w", 196))
	var line_h: int = int(cfg.get("gain_line_h", 11))
	var per_line: int = maxi(1, int(cfg.get("gains_per_line", 4)))
	for i: int in mini(get_shown_level_up_count(), ups.size()):
		var up: Dictionary = ups[i]
		var gains: Array[String] = gain_entries(up)
		var learned: Array[String] = _learned_lines(up)
		var gain_lines: int = int(ceil(float(gains.size()) / float(per_line)))
		var height: int = 14 + gain_lines * line_h + learned.size() * 12 + 6
		PixelShape.fill_outlined(_drawing, Rect2i(x, y, w, height), 4, 1, BattleUiData.palette("dusk"), BattleUiData.palette("night"))
		UiText.draw(_drawing, "menu", Vector2(x + 8, y + 13), _level_title(up), BattleUiData.palette("lamp_amber"))
		var line_y: int = y + 14 + line_h - 1
		for g: int in gain_lines:
			var chunk: PackedStringArray = PackedStringArray(gains.slice(g * per_line, (g + 1) * per_line))
			UiText.draw(_drawing, "tag", Vector2(x + 8, line_y), "  ".join(chunk), BattleUiData.palette("text"))
			line_y += line_h
		for text: String in learned:
			UiText.draw(_drawing, "tag", Vector2(x + 8, line_y + 1), text, BattleUiData.palette("lamp_glow"))
			line_y += 12
		y += height + int(cfg.get("card_gap", 4))
