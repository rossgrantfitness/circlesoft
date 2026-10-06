class_name BattlePartyPanel
extends Control
## The party panel along the bottom: one column per fighter with name, status chips, an HP bar and
## a Juice bar, each with its numbers (color is never the only clue). A downed fighter is greyed and
## reads "Down for the Count". The fighter whose turn it is gets an amber name and an arrow.
## Bars ease toward the real value (a stepped drain / fill); the numbers are always exact.
## Placeholder look: bars and chips are drawn from code until the final icons arrive.

var roster: BattleRoster = BattleRoster.new()

var _window: UiWindow = null
var _drawing: Control = null
var _active: String = ""
var _shown: Dictionary[String, Dictionary] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	var rect: Rect2 = BattleUiData.ui_rect("layout.party_panel")
	_window = UiWindow.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.position = rect.position
	_window.size = rect.size
	add_child(_window)
	_drawing = Control.new()
	_drawing.name = "Columns"
	_drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawing.position = rect.position
	_drawing.size = rect.size
	_drawing.draw.connect(_draw_columns)
	add_child(_drawing)


## Highlights whose turn it is ("" for nobody).
func set_active(id: String) -> void:
	_active = id
	_drawing.queue_redraw()


func get_active() -> String:
	return _active


## Jumps the bars to the real values (battle start, tests).
func snap_bars() -> void:
	_shown.clear()
	for id: String in roster.ids(BattleRoster.SIDE_PARTY):
		var member: Dictionary = roster.get_member(id)
		_shown[id] = {"hp": float(member.get("hp", 0)), "juice": float(member.get("juice", 0))}
	if _drawing != null:
		_drawing.queue_redraw()


## The bar fill the player sees right now: {hp, juice} as floats (tests).
func get_shown(id: String) -> Dictionary:
	return _shown.get(id, {})


func refresh() -> void:
	if _drawing != null:
		_drawing.queue_redraw()


## Eases the bars toward the real numbers.
func tick(delta: float) -> void:
	var speed: float = BattleUiData.ui_float("timing.bar_fill_per_s", 0.9)
	var moved: bool = false
	for id: String in roster.ids(BattleRoster.SIDE_PARTY):
		var member: Dictionary = roster.get_member(id)
		if not _shown.has(id):
			_shown[id] = {"hp": float(member.get("hp", 0)), "juice": float(member.get("juice", 0))}
		var shown: Dictionary = _shown[id]
		for key: String in ["hp", "juice"]:
			var goal: float = float(member.get(key, 0))
			var maximum: float = float(maxi(1, int(member.get("%s_max" % key, 1))))
			var now: float = float(shown[key])
			if not is_equal_approx(now, goal):
				shown[key] = move_toward(now, goal, speed * maximum * delta)
				moved = true
	if moved:
		_drawing.queue_redraw()


func _draw_columns() -> void:
	var cfg: Dictionary = BattleUiData.ui("layout.party_panel", {})
	var col_w: int = int(cfg.get("col_w", 120))
	var party: Array[String] = roster.ids(BattleRoster.SIDE_PARTY)
	for i: int in party.size():
		_draw_column(party[i], int(cfg.get("col_x", 14)) + i * col_w, cfg)
		if i > 0:
			_drawing.draw_rect(Rect2(float(int(cfg.get("col_x", 14)) + i * col_w - 7), 8.0, 1.0, _drawing.size.y - 16.0), BattleUiData.palette("dusk"))


func _draw_column(id: String, x: int, cfg: Dictionary) -> void:
	var member: Dictionary = roster.get_member(id)
	var down: bool = roster.is_down(id)
	var active: bool = id == _active and not down
	var color: Color = BattleUiData.palette("text")
	if down:
		color = BattleUiData.palette("text_dim")
	elif active:
		color = BattleUiData.palette("text_highlight")
	var name_y: int = int(cfg.get("name_y", 16))
	var col_w: int = int(cfg.get("col_w", 120))
	UiText.draw(_drawing, "menu", Vector2(x, name_y), roster.name_of(id), color)
	if active:
		_draw_active_arrow(Vector2(float(x - 8), float(name_y - 9)))
	if not down:
		_draw_chips(id, Vector2(x + int(cfg.get("name_w", 54)), name_y - 11), cfg)
	var hp: int = int(member.get("hp", 0))
	var hp_max: int = int(member.get("hp_max", 1))
	var juice: int = int(member.get("juice", 0))
	var juice_max: int = int(member.get("juice_max", 0))
	var shown: Dictionary = _shown.get(id, {"hp": float(hp), "juice": float(juice)})
	var bar_x: int = x + int(cfg.get("bar_x", 28))
	var number_edge: float = float(col_w - 8)
	var dim: Color = BattleUiData.palette("text_dim")
	# HP row (or the Down for the Count label).
	var hp_y: int = int(cfg.get("hp_y", 31))
	if down:
		UiText.draw(_drawing, "tag", Vector2(x, hp_y), BattleUiData.text("down_label"), BattleUiData.ui_color("bars.low_hp_text"))
	else:
		UiText.draw(_drawing, "tag", Vector2(x, hp_y), BattleUiData.text("labels.hp"), dim)
		_draw_bar(Vector2(bar_x, hp_y - 4), int(cfg.get("hp_bar_w", 46)), int(cfg.get("hp_bar_h", 6)), float(shown.get("hp", hp)), hp_max, BattleUiData.ui_color("bars.hp"))
		var low: bool = hp * 100 <= int(BattleUiData.ui("bars.low_hp_pct", 25)) * hp_max
		var number_color: Color = BattleUiData.ui_color("bars.low_hp_text") if low else BattleUiData.palette("text")
		UiText.draw(_drawing, "tag", Vector2(x, hp_y), "%d/%d" % [hp, hp_max], number_color, HORIZONTAL_ALIGNMENT_RIGHT, number_edge)
	# Juice row.
	var juice_y: int = int(cfg.get("juice_y", 43))
	var juice_color: Color = BattleUiData.ui_color("bars.juice")
	if down:
		juice_color = dim
	UiText.draw(_drawing, "tag", Vector2(x, juice_y), BattleUiData.text("labels.juice"), dim)
	_draw_bar(Vector2(bar_x, juice_y - 4), int(cfg.get("juice_bar_w", 46)), int(cfg.get("juice_bar_h", 3)), float(shown.get("juice", juice)), juice_max, juice_color)
	UiText.draw(_drawing, "tag", Vector2(x, juice_y), "%d/%d" % [juice, juice_max], dim if down else BattleUiData.palette("text"), HORIZONTAL_ALIGNMENT_RIGHT, number_edge)


func _draw_bar(at: Vector2, width: int, thickness: int, value: float, maximum: int, color: Color) -> void:
	var y: float = at.y + (6.0 - float(thickness)) / 2.0
	_drawing.draw_rect(Rect2(at.x - 1.0, y - 1.0, float(width) + 2.0, float(thickness) + 2.0), BattleUiData.palette("ink"))
	_drawing.draw_rect(Rect2(at.x, y, float(width), float(thickness)), BattleUiData.ui_color("bars.empty"))
	var fill: int = int(round(float(width) * clampf(value / float(maxi(1, maximum)), 0.0, 1.0)))
	_drawing.draw_rect(Rect2(at.x, y, float(fill), float(thickness)), color)


func _draw_chips(id: String, at: Vector2, cfg: Dictionary) -> void:
	var chip_w: int = int(cfg.get("chip_w", 11))
	var chip_h: int = int(cfg.get("chip_h", 12))
	var gap: int = int(cfg.get("chip_gap", 1))
	var x: float = at.x
	for status_id: String in roster.statuses_of(id):
		var style: Dictionary = BattleUiData.ui("statuses.%s" % status_id, BattleUiData.ui("statuses.default", {}))
		var rect: Rect2 = Rect2(x, at.y, float(chip_w), float(chip_h))
		_drawing.draw_rect(rect.grow(1), BattleUiData.palette("ink"))
		_drawing.draw_rect(rect, Color.html(str(style.get("color", "#8D97A5"))))
		var font: Font = UiFonts.get_font("tag")
		_drawing.draw_string(font, Vector2(x, at.y + float(chip_h) - 2.0), str(style.get("letter", "?")), HORIZONTAL_ALIGNMENT_CENTER, float(chip_w), UiFonts.get_size("tag"), BattleUiData.palette("ink"))
		x += float(chip_w + gap + 1)


func _draw_active_arrow(at: Vector2) -> void:
	var ink: Color = BattleUiData.palette("ink")
	var amber: Color = BattleUiData.palette("lamp_amber")
	for row: int in 5:
		var span: int = 5 - absi(row - 2) * 2
		_drawing.draw_rect(Rect2(at.x - 1.0, at.y + float(row) - 1.0 + 2.0, float(span) + 2.0, 1.0), ink)
	for row: int in 5:
		var span: int = 5 - absi(row - 2) * 2
		_drawing.draw_rect(Rect2(at.x, at.y + float(row) + 2.0, float(span), 1.0), amber)
