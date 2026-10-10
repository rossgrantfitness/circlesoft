class_name BattleTargetCursor
extends Control
## The targeting pointer: a chunky amber down-arrow bobbing over each combatant who would be hit
## (one for a single pick, every member of a side for all-target moves), plus a name tag at the top.
## Positions are read live from the stage (the owner's `pos_of`), so the arrow follows a moving fighter.

var roster: BattleRoster = BattleRoster.new()
var pos_of: Callable = Callable()

var _targeting: BattleTargeting = null
var _tag_window: UiWindow = null
var _tag_label: Label = null
var _clock: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	_tag_window = UiWindow.new()
	_tag_window.name = "TagWindow"
	_tag_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag_window)
	_tag_label = Label.new()
	_tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiText.style_label(_tag_label, "menu", BattleUiData.palette("text"))
	_tag_window.add_child(_tag_label)
	visible = false


## Starts showing the pointer for `targeting` (null hides it).
func show_for(targeting: BattleTargeting) -> void:
	_targeting = targeting
	visible = targeting != null
	_clock = 0.0
	_update_tag()
	queue_redraw()


func get_tag_text() -> String:
	return _tag_label.text if _tag_label != null else ""


## Ids that currently have an arrow over them.
func get_marked_ids() -> Array[String]:
	if _targeting == null or not visible:
		return []
	return _targeting.selected_ids()


## Re-reads the pointer (after it moved) so the name tag is current before the next tick.
func refresh() -> void:
	_update_tag()
	queue_redraw()


func tick(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_update_tag()
	queue_redraw()


func _update_tag() -> void:
	if _targeting == null or _tag_label == null:
		return
	var text: String = ""
	if _targeting.is_all:
		var key: String = "targets.all_enemies" if _targeting.kind == BattleTargeting.KIND_ALL_ENEMIES else "targets.all_allies"
		text = BattleUiData.text(key)
	else:
		text = roster.name_of(_targeting.get_selected())
	_tag_label.text = text
	var pad: float = BattleUiData.ui_float("layout.target_tag.pad_x", 14.0)
	var tag_h: float = BattleUiData.ui_float("layout.target_tag.h", 22.0)
	var width: float = float(UiFonts.text_width("menu", text)) + pad * 2.0
	_tag_window.size = Vector2(width, tag_h)
	_tag_window.position = Vector2(floorf((size.x - width) / 2.0), BattleUiData.ui_float("layout.target_tag.y", 34.0))
	_tag_label.position = Vector2(pad, (tag_h - float(UiFonts.get_size("menu"))) / 2.0 - 3.0)


func _draw() -> void:
	if _targeting == null or not pos_of.is_valid():
		return
	var offset: Vector2 = BattleUiData.ui_vec("anchors.target_arrow")
	var bob_px: int = BattleUiData.ui_int("target.bob_px", 2)
	var bob_s: float = BattleUiData.ui_float("target.bob_s", 0.4)
	var bob: float = float(int(_clock / bob_s) % 2 * bob_px)
	var flash: bool = _targeting.is_all and int(_clock / (bob_s / 2.0)) % 2 == 1
	for id: String in _targeting.selected_ids():
		var at: Vector2 = (pos_of.call(id) as Vector2) + offset
		_draw_arrow(at + Vector2(0, bob), flash)


## A stepped down-pointing arrow with an Ink outline; `at` is the tip's center.
func _draw_arrow(at: Vector2, bright: bool) -> void:
	var width: int = BattleUiData.ui_int("target.arrow_w", 11)
	var height: int = BattleUiData.ui_int("target.arrow_h", 8)
	var ink: Color = BattleUiData.palette("ink")
	var fill: Color = BattleUiData.palette("lamp_glow") if bright else BattleUiData.palette("lamp_amber")
	var top: float = at.y - float(height)
	for row: int in height:
		var span: int = width - row * 2
		if span <= 0:
			break
		var x: float = at.x - float(span) / 2.0
		draw_rect(Rect2(x - 1.0, top + float(row), float(span) + 2.0, 1.0), ink)
	draw_rect(Rect2(at.x - 1.0, at.y, 3.0, 1.0), ink)
	for row: int in height:
		var span: int = width - row * 2
		if span <= 0:
			break
		draw_rect(Rect2(at.x - float(span) / 2.0, top + float(row), float(span), 1.0), fill)
