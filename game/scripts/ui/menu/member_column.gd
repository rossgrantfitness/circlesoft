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
## PANEL style only: leave room for the pick cursor and frame the fighter under it.
var interactive: bool = false
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
	list.cursor_x = int(column["cursor_x"])
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
				_draw_panel_row(member, top, is_dim, framed)
			Style.COLUMN:
				_draw_column_row(member, top, is_dim, framed)
			Style.COMPACT:
				_draw_compact_row(member, top, is_dim, framed)


func _frame(top: int, step: int) -> void:
	var rect: Rect2 = Rect2(14, top + 1, size.x - 16, step - 2)
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
	MenuDraw.portrait(self, member, Vector2i(px, top + 4), tile, int(_layout["portrait_initial_size"]), is_dim)
	var tx: int = int(column["text_x"])
	var right: float = size.x - 4.0
	var dim_text: Color = MenuDraw.color("text_dim")
	var white: Color = dim_text if is_dim else MenuDraw.color("text")
	UiText.draw(self, "menu", Vector2(tx, top + 15), str(member.get("name", "")), _name_color(is_dim, framed))
	var level: String = str(_text["status"]["level"]).replace("{level}", str(int(member.get("level", 1))))
	UiText.draw(self, "menu", Vector2(0, top + 15), level, dim_text, HORIZONTAL_ALIGNMENT_RIGHT, right)
	var hp_color: Color = MenuDraw.color("down") if int(member.get("hp", 0)) <= 0 else white
	UiText.draw(self, "menu", Vector2(tx, top + 29), str(_text["status"]["hp"]), dim_text)
	UiText.draw(self, "menu", Vector2(0, top + 29), "%d/%d" % [int(member.get("hp", 0)), int(member.get("hp_max", 0))], hp_color, HORIZONTAL_ALIGNMENT_RIGHT, right)
	UiText.draw(self, "menu", Vector2(tx, top + 42), str(_text["status"]["juice"]), dim_text)
	UiText.draw(self, "menu", Vector2(0, top + 42), "%d/%d" % [int(member.get("juice", 0)), int(member.get("juice_max", 0))], white, HORIZONTAL_ALIGNMENT_RIGHT, right)


func _draw_compact_row(member: Dictionary, top: int, is_dim: bool, framed: bool) -> void:
	var column: Dictionary = _layout["member_column"]
	var step: int = _row_height()
	if framed:
		_frame(top, step)
	var tile: int = int(column["portrait"])
	var px: int = int(column["compact_portrait_x"])
	MenuDraw.portrait(self, member, Vector2i(px, top + 4), tile, int(_layout["portrait_initial_size"]), is_dim)
	UiText.draw(self, "menu", Vector2(px - 2, top + 4 + tile + 12), str(member.get("name", "")), _name_color(is_dim, framed),
			HORIZONTAL_ALIGNMENT_CENTER, float(tile + 4))


func _draw_panel_row(member: Dictionary, top: int, is_dim: bool, framed: bool) -> void:
	var column: Dictionary = _layout["member_column"]
	var inset: int = int(column["panel_pick_inset"]) if interactive else int(column["panel_inset"])
	var inner_w: int = int(size.x)
	var tile: int = int(_layout["portrait_size"])
	var step: int = _row_height()
	if framed:
		draw_rect(Rect2(inset - 4, top + 1, inner_w - inset + 2, step - 2), MenuDraw.color("lamp_amber") if list.active or frame_all else MenuDraw.color("slate_light"), false, 1.0)
	var dim_text: Color = MenuDraw.color("text_dim")
	MenuDraw.portrait(self, member, Vector2i(inset, top + 6), tile, int(_layout["portrait_initial_size"]), is_dim)
	var text_x: int = inset + tile + 8
	UiText.draw(self, "menu", Vector2(text_x, top + 15), str(member.get("name", "")), _name_color(is_dim, framed))
	var level: String = str(_text["status"]["level"]).replace("{level}", str(int(member.get("level", 1))))
	UiText.draw(self, "menu", Vector2(0, top + 15), level, dim_text, HORIZONTAL_ALIGNMENT_RIGHT, inner_w - 8.0)
	var width: int = inner_w - text_x - 8
	MenuDraw.bar_row(self, Vector2i(text_x, top + 28), str(_text["status"]["hp"]), int(member.get("hp", 0)), int(member.get("hp_max", 0)),
			MenuDraw.color("hp"), int(_layout["hp_bar_h"]), width, false, int(_layout["bar_label_w"]), is_dim)
	MenuDraw.bar_row(self, Vector2i(text_x, top + 40), str(_text["status"]["juice"]), int(member.get("juice", 0)), int(member.get("juice_max", 0)),
			MenuDraw.color("juice"), int(_layout["juice_bar_h"]), width, false, int(_layout["bar_label_w"]), is_dim)
