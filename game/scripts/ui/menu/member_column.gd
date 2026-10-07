class_name MemberColumn
extends Control
## The party shown as a column of rows (placeholder initial portrait, name, level, HP and Juice)
## with an optional pick cursor. One widget for every "choose a fighter" moment in the field menu
## (items, skills, equip, status, party) and for the main page's side panel.
##
## It owns a MenuList with blank labels purely for cursor movement, wrap, memory and mouse; this
## class draws the rows itself, framing the picked fighter in amber while the list is active and
## greying fighters that can't be picked.
##
## Styles: PANEL (wide main-page panel with bars), COLUMN (portrait, name, level, HP and Juice
## numbers) and COMPACT (portrait and name only).

signal picked(member_id: String)
signal cursor_moved(member_id: String)

enum Style { PANEL, COLUMN, COMPACT }

const LAYOUT_ID: String = "ui/field_menu"

var style: Style = Style.COLUMN
var list: MenuList = null
var audio: UiAudio = UiAudio.new()
## Fighters shown greyed and not pickable: member id -> true.
var dimmed: Dictionary[String, bool] = {}
## Draw the amber frame around the cursor row (off while the column is only showing information).
var show_frame: bool = true
## Keep a dim "last position" frame on the cursor row while the column is not the active list.
var hold: bool = false
## Frame every fighter in amber at once (an item that hits the whole crew).
var frame_all: bool = false
var members: Array[Dictionary] = []

var _layout: Dictionary = {}
var _text: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layout = DataDB.get_dict(LAYOUT_ID)
	_text = DataDB.get_dict("text/field_menu")
	var column: Dictionary = _layout["member_column"]
	list = MenuList.new()
	list.name = "Pick"
	list.audio = audio
	list.size = size
	list.first_row_y = 0
	list.text_x = 0
	list.cursor_x = int(column["cursor_x"]) if style != Style.PANEL else 0
	list.row_height = _row_height()
	list.visible_rows = 3
	list.activated.connect(func(index: int) -> void: picked.emit(list.get_item_id(index)))
	list.cursor_moved.connect(func(index: int) -> void:
		queue_redraw()
		cursor_moved.emit(list.get_item_id(index)))
	add_child(list)
	_sync_list()


func _row_height() -> int:
	var key: String = "panel_row_h" if style == Style.PANEL else ("compact_row_h" if style == Style.COMPACT else "row_h")
	return int((_layout["member_column"] as Dictionary)[key])


## Replaces the fighters shown (as GameState.get_party() gives them).
func set_members(party: Array[Dictionary]) -> void:
	members = party
	_sync_list()
	queue_redraw()


func _sync_list() -> void:
	if list == null:
		return
	list.row_height = _row_height()
	var rows: Array[Dictionary] = []
	for member: Dictionary in members:
		var id: String = str(member.get("id", ""))
		rows.append({"id": id, "label": "", "enabled": not dimmed.has(id)})
	list.set_items(rows, true)


## Greys the fighters in `ids` (and makes them unpickable).
func set_dimmed(ids: Array[String]) -> void:
	dimmed.clear()
	for id: String in ids:
		dimmed[id] = true
	_sync_list()
	queue_redraw()


## The list shows its cursor (and takes commands) only while `on`.
func set_active(on: bool) -> void:
	if list != null:
		list.active = on
		list.visible = on
	queue_redraw()


func selected_id() -> String:
	return list.get_item_id(list.get_cursor_index()) if list != null else ""


func select(member_id: String) -> void:
	for i: int in members.size():
		if str(members[i].get("id", "")) == member_id:
			list.set_index(i, false)
			queue_redraw()
			return


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var step: int = _row_height()
	for i: int in members.size():
		var member: Dictionary = members[i]
		var id: String = str(member.get("id", ""))
		var top: int = i * step
		var is_dim: bool = dimmed.has(id)
		var live: bool = list != null and list.active
		var framed: bool = frame_all or (show_frame and list != null and (live or hold) and i == list.get_cursor_index())
		match style:
			Style.PANEL:
				_draw_panel_row(member, top)
			Style.COLUMN:
				_draw_column_row(member, top, is_dim, framed)
			Style.COMPACT:
				_draw_compact_row(member, top, is_dim, framed)


func _frame(top: int, step: int) -> void:
	var rect: Rect2 = Rect2(13, top + 1, size.x - 15, step - 2)
	var live: bool = frame_all or (list != null and list.active)
	draw_rect(rect, MenuDraw.color("lamp_amber") if live else MenuDraw.color("slate_light"), false, 1.0)


func _name_color(is_dim: bool, framed: bool) -> Color:
	if is_dim:
		return MenuDraw.color("text_dim")
	return MenuDraw.color("text_highlight") if framed else MenuDraw.color("text")


func _draw_column_row(member: Dictionary, top: int, is_dim: bool, framed: bool) -> void:
	var column: Dictionary = _layout["member_column"]
	var step: int = _row_height()
	if framed:
		_frame(top, step)
	var tile: int = int(column["portrait"])
	var px: int = int(column["portrait_x"])
	MenuDraw.portrait(self, member, Vector2i(px, top + 3), tile, int(_layout["portrait_initial_size"]), is_dim)
	var tx: int = px + tile + 6
	var base: Color = _name_color(is_dim, framed)
	UiText.draw(self, "menu", Vector2(tx, top + 14), str(member.get("name", "")), base)
	var level: String = str(_text["status"]["level"]).replace("{level}", str(int(member.get("level", 1))))
	UiText.draw(self, "menu", Vector2(tx, top + 27), level, MenuDraw.color("text_dim"))
	var dim_text: Color = MenuDraw.color("text_dim")
	var white: Color = dim_text if is_dim else MenuDraw.color("text")
	var hp: String = "%d/%d" % [int(member.get("hp", 0)), int(member.get("hp_max", 0))]
	var jc: String = "%d/%d" % [int(member.get("juice", 0)), int(member.get("juice_max", 0))]
	var hp_color: Color = white
	if int(member.get("hp", 0)) <= 0:
		hp_color = MenuDraw.color("down")
	UiText.draw(self, "menu", Vector2(px, top + 42), str(_text["status"]["hp"]), dim_text)
	UiText.draw(self, "menu", Vector2(0, top + 42), hp, hp_color, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6)
	if step >= int(column["juice_min_row_h"]):
		UiText.draw(self, "menu", Vector2(px, top + 53), str(_text["status"]["juice"]), dim_text)
		UiText.draw(self, "menu", Vector2(0, top + 53), jc, white, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6)


func _draw_compact_row(member: Dictionary, top: int, is_dim: bool, framed: bool) -> void:
	var column: Dictionary = _layout["member_column"]
	var step: int = _row_height()
	if framed:
		_frame(top, step)
	var tile: int = int(column["portrait"])
	var px: int = int((size.x - 12.0 - float(tile)) / 2.0) + 12
	MenuDraw.portrait(self, member, Vector2i(px, top + 5), tile, int(_layout["portrait_initial_size"]), is_dim)
	UiText.draw(self, "menu", Vector2(12, top + 5 + tile + 14), str(member.get("name", "")), _name_color(is_dim, framed),
			HORIZONTAL_ALIGNMENT_CENTER, size.x - 12.0)


func _draw_panel_row(member: Dictionary, top: int) -> void:
	var inner_w: int = int(size.x)
	var tile: int = int(_layout["portrait_size"])
	MenuDraw.portrait(self, member, Vector2i(10, top + 4), tile, int(_layout["portrait_initial_size"]))
	UiText.draw(self, "menu", Vector2(46, top + 14), str(member.get("name", "")), MenuDraw.color("text"))
	var level: String = str(_text["status"]["level"]).replace("{level}", str(int(member.get("level", 1))))
	UiText.draw(self, "menu", Vector2(0, top + 14), level, MenuDraw.color("text_dim"), HORIZONTAL_ALIGNMENT_RIGHT, inner_w - 12)
	MenuDraw.bar_row(self, Vector2i(46, top + 28), str(_text["status"]["hp"]), int(member.get("hp", 0)), int(member.get("hp_max", 0)),
			MenuDraw.color("hp"), int(_layout["hp_bar_h"]), inner_w - 46 - 12, false, int(_layout["bar_label_w"]))
	MenuDraw.bar_row(self, Vector2i(46, top + 41), str(_text["status"]["juice"]), int(member.get("juice", 0)), int(member.get("juice_max", 0)),
			MenuDraw.color("juice"), int(_layout["juice_bar_h"]), inner_w - 46 - 12, false, int(_layout["bar_label_w"]))
