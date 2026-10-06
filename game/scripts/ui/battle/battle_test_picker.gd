class_name BattleTestPicker
extends Control
## The "Battle Test" encounter picker on the title screen: a small window listing every encounter
## in data/battle/encounters.json with its friendly name, the enemies in it and a tier tag
## (tutorial / regular / tough). Shared house style: UiWindow and MenuList (flame cursor, ticks,
## controller / keyboard / mouse). Cancel emits `cancelled` (the title goes back to its menu);
## picking a row emits `picked(encounter_id)`.
##
## Lives on a 384x216 stage; the owner forwards input (handle_command / handle_mouse with
## stage-pixel positions). Layout is in data/ui/battle_ui.json ("layout.encounter_picker", "tiers");
## strings are in data/text/title.json ("battle_test").

signal picked(encounter_id: String)
signal cancelled

const ENCOUNTERS_ID: String = "battle/encounters"
const ENEMIES_ID: String = "battle/enemies"
const TEXT_ID: String = "text/title"
const TIER_DEFAULT: String = "regular"

var audio: UiAudio = UiAudio.new()

var _window: UiWindow = null
var _list: MenuList = null
var _marks: Control = null
var _header: Label = null
var _hint: Label = null
var _rows: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	var rect: Rect2 = BattleUiData.ui_rect("layout.encounter_picker")
	var cfg: Dictionary = BattleUiData.ui("layout.encounter_picker", {})
	_window = UiWindow.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.position = rect.position
	_window.size = rect.size
	add_child(_window)
	_header = Label.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiText.style_label(_header, "menu", BattleUiData.palette("lamp_amber"))
	_header.position = Vector2(14, 4)
	_header.text = str(DataDB.get_value(TEXT_ID, "battle_test.title", "Battle Test"))
	_window.add_child(_header)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiText.style_label(_hint, "tag", BattleUiData.palette("text_dim"))
	_hint.text = str(DataDB.get_value(TEXT_ID, "battle_test.hint", ""))
	_hint.position = Vector2(rect.size.x - 14.0 - float(UiFonts.text_width("tag", _hint.text)), 8)
	_window.add_child(_hint)
	_list = MenuList.new()
	_list.audio = audio
	_list.size = rect.size
	_list.row_height = int(cfg.get("row_h", 24))
	_list.first_row_y = int(cfg.get("first_y", 22))
	_list.text_x = int(cfg.get("text_x", 20))
	_list.cursor_x = int(cfg.get("cursor_x", 6))
	_list.visible_rows = int(cfg.get("rows", 5))
	_window.add_child(_list)
	_list.activated.connect(_on_activated)
	_list.cursor_moved.connect(func(_i: int) -> void: _marks.queue_redraw())
	_marks = Control.new()
	_marks.name = "Marks"
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.size = rect.size
	_marks.draw.connect(_draw_marks)
	_window.add_child(_marks)
	_rebuild()
	visible = false


## Every encounter in the data, in file order: {id, name, tier, enemies (summary text)}.
func get_rows() -> Array[Dictionary]:
	return _rows


func get_encounter_ids() -> Array[String]:
	var ids: Array[String] = []
	for row: Dictionary in _rows:
		ids.append(str(row["id"]))
	return ids


func get_list() -> MenuList:
	return _list


func is_open() -> bool:
	return visible


## Shows the picker (the cursor is back on the first encounter).
func open() -> void:
	_rebuild()
	visible = true
	_list.active = true
	_marks.queue_redraw()


func close() -> void:
	visible = false
	_list.active = false


func _rebuild() -> void:
	_rows.clear()
	var items: Array[Dictionary] = []
	var encounters: Variant = DataDB.get_value(ENCOUNTERS_ID, "encounters", [])
	if encounters is Array:
		for entry: Variant in encounters:
			var enc: Dictionary = entry
			var id: String = str(enc.get("id", ""))
			if id.is_empty():
				continue
			var row: Dictionary = {
				"id": id,
				"name": str(enc.get("name", BattleUiData.prettify(id))),
				"tier": str(enc.get("tier", TIER_DEFAULT)),
				"enemies": _enemy_summary(enc.get("enemies", [])),
			}
			_rows.append(row)
			items.append({"id": id, "label": str(row["name"])})
	_list.set_items(items)


## "Signals Grunt x2, Signals Drone" from the encounter's enemy ids, in order of first appearance.
func _enemy_summary(enemy_ids: Array) -> String:
	var order: Array[String] = []
	var counts: Dictionary[String, int] = {}
	for raw: Variant in enemy_ids:
		var id: String = str(raw)
		if not counts.has(id):
			counts[id] = 0
			order.append(id)
		counts[id] += 1
	var parts: PackedStringArray = PackedStringArray()
	for id: String in order:
		var enemy_name: String = _enemy_name(id)
		parts.append(enemy_name if counts[id] == 1 else "%s x%d" % [enemy_name, counts[id]])
	return ", ".join(parts)


func _enemy_name(id: String) -> String:
	var list: Variant = DataDB.get_value(ENEMIES_ID, "enemies", [])
	if list is Array:
		for entry: Variant in list:
			if entry is Dictionary and str((entry as Dictionary).get("id", "")) == id:
				return str((entry as Dictionary).get("name", BattleUiData.prettify(id)))
	return BattleUiData.prettify(id)


## The tier's tag text ("Tutorial", "Regular", "Tough").
func tier_text(tier: String) -> String:
	return str(DataDB.get_value(TEXT_ID, "battle_test.tiers.%s" % tier, tier.capitalize()))


func _on_activated(index: int) -> void:
	if index >= 0 and index < _rows.size():
		picked.emit(str(_rows[index]["id"]))


# ---- input (the owner forwards) ----

func handle_command(command: MenuInput.Cmd) -> void:
	if not visible:
		return
	if command == MenuInput.Cmd.CANCEL:
		audio.sfx("back")
		cancelled.emit()
		return
	_list.handle_command(command)


## Mouse in stage pixels: hover moves, left click picks, right click cancels. True when used.
func handle_mouse(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		audio.sfx("back")
		cancelled.emit()
		return true
	return _list.handle_mouse(event)


# ---- drawing: the enemies line and the tier tag on every visible row ----

func _draw_marks() -> void:
	var tiers: Dictionary = BattleUiData.ui("tiers", {})
	var rect: Rect2 = BattleUiData.ui_rect("layout.encounter_picker")
	var font: Font = UiFonts.get_font("tag")
	var font_size: int = UiFonts.get_size("tag")
	for row: int in _list.visible_rows:
		var index: int = _list.get_top() + row
		if index >= _rows.size():
			break
		var data: Dictionary = _rows[index]
		var row_rect: Rect2 = _list.get_row_rect(index)
		var baseline: float = float(_list.first_row_y + row * _list.row_height + UiFonts.get_size("menu"))
		var highlighted: bool = index == _list.get_cursor_index()
		var enemy_color: Color = BattleUiData.palette("text") if highlighted else BattleUiData.palette("text_dim")
		UiText.draw(_marks, "tag", Vector2(float(_list.text_x), baseline + 11.0), str(data["enemies"]), enemy_color)
		var tag: String = tier_text(str(data["tier"]))
		var width: float = float(UiFonts.text_width("tag", tag)) + 8.0
		var tag_rect: Rect2 = Rect2(rect.size.x - 14.0 - width, row_rect.position.y + (row_rect.size.y - 13.0) / 2.0 + 1.0, width, 13.0)
		var fill: Color = Color.html(str(tiers.get(str(data["tier"]), "#8D97A5")))
		_marks.draw_rect(Rect2(tag_rect.position + Vector2(1, 1), tag_rect.size), BattleUiData.palette("ink"))
		_marks.draw_rect(tag_rect, fill)
		_marks.draw_string(font, Vector2(tag_rect.position.x, tag_rect.end.y - 3.0), tag, HORIZONTAL_ALIGNMENT_CENTER, tag_rect.size.x, font_size, BattleUiData.palette("ink"))
