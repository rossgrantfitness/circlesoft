class_name PageItems
extends MenuPage
## Items: three tabs (Items, Gear, Key Items), the bag with counts, and using things. Pick a usable
## item, then pick who gets it (or confirm for the whole crew). Items that can't be used right now
## are greyed and the info window says why ("Use it at a save lamp.", "Battle only.", "Nobody needs
## that right now."). Spare gear and key items are listed for looking at only.

enum Mode { LIST, TARGET }

const TABS: Array[String] = ["items", "gear", "key"]

var _spec: Dictionary = {}
var _tab: int = 0
var _mode: Mode = Mode.LIST
var _list: MenuList = null
var _column: MemberColumn = null
var _tabs_draw: Control = null
var _empty_label: Label = null
var _target_item: String = ""
var _all_targets: bool = false
var _message: String = ""
var _message_warn: bool = false
var _memory: Dictionary[int, int] = {}


func build() -> void:
	_spec = menu.layout["items_page"]
	_tabs_draw = menu.make_drawing(root, Vector2.ZERO, FieldMenu.PAGE_AREA.size, _draw_tabs)
	_list = menu.make_list(root, _spec["list"])
	_list.activated.connect(_on_activated)
	_list.cursor_moved.connect(_on_row_moved)
	var column_at: Dictionary = _spec["column"]
	_column = menu.make_member_column(root, MemberColumn.Style.COLUMN, Vector2(float(column_at["x"]), float(column_at["y"])))
	_column.set_active(false)
	_column.picked.connect(_on_target_picked)
	_column.cursor_moved.connect(func(_id: String) -> void: menu.refresh_info())
	_empty_label = menu.make_label(root, "body", "text_dim", Vector2(20, 40))
	_load_tab(0)


func primary_list() -> MenuList:
	return _list


func get_column() -> MemberColumn:
	return _column


func get_tab() -> String:
	return TABS[_tab]


func is_picking_target() -> bool:
	return _mode == Mode.TARGET


func _draw_tabs(canvas: Control) -> void:
	var names: Dictionary = menu.text["items"]["tabs"]
	var xs: Array = _spec["tab_x"]
	var y: int = int(_spec["tabs_y"])
	for i: int in TABS.size():
		var chosen: bool = i == _tab
		var label: String = str(names[TABS[i]])
		var color: Color = MenuDraw.color("text_highlight") if chosen else MenuDraw.color("text_dim")
		UiText.draw(canvas, "menu", Vector2(float(xs[i]), y), label, color)
		if chosen:
			canvas.draw_rect(Rect2(float(xs[i]), y + 3, UiFonts.text_width("menu", label), 1), MenuDraw.color("lamp_amber"))


# ---- the list ----

func _load_tab(index: int) -> void:
	_memory[_tab] = _list.get_cursor_index()
	_tab = posmod(index, TABS.size())
	_message = ""
	_list.set_items(_rows())
	_list.set_index(int(_memory.get(_tab, 0)), false)
	_empty_label.text = str(menu.text["items"]["empty"][TABS[_tab]])
	_empty_label.visible = _list.get_count() == 0
	_tabs_draw.queue_redraw()
	menu.refresh_info()


func _rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var context: String = menu.item_context()
	var count_format: String = str(menu.text["items"]["count"])
	for id: String in menu.backend.tab_ids(TABS[_tab]):
		var row: Dictionary = {"id": id, "label": menu.backend.item_name(id),
				"value": count_format.replace("{n}", str(menu.backend.owned(id)))}
		if TABS[_tab] == "items":
			var reason: String = menu.backend.item_reason(id, context)
			row["enabled"] = reason.is_empty()
			row["reason"] = reason
		rows.append(row)
	return rows


func _reload_rows_keeping_cursor() -> void:
	_list.set_items(_rows(), true)
	_empty_label.visible = _list.get_count() == 0


func _on_row_moved(_index: int) -> void:
	_message = ""
	menu.refresh_info()


func _on_activated(index: int) -> void:
	var id: String = _list.get_item_id(index)
	if id.is_empty():
		return
	_memory[_tab] = index
	if TABS[_tab] != "items":
		_message = str(menu.text["items"]["gear_hint"]) if TABS[_tab] == "gear" else menu.backend.reason_text("key_item")
		_message_warn = false
		menu.refresh_info()
		return
	_start_target(id)


# ---- picking who ----

func _start_target(item_id: String) -> void:
	_target_item = item_id
	_mode = Mode.TARGET
	_message = ""
	_all_targets = menu.backend.target_kind(item_id) == GearBridge.TARGET_PARTY
	_list.active = false
	_column.set_members(menu.backend.party())
	_column.frame_all = _all_targets
	if _all_targets:
		_column.set_dimmed([] as Array[String])
		_column.set_active(false)
		_column.visible = true
	else:
		var targets: Array[String] = menu.backend.item_targets(item_id)
		var dimmed: Array[String] = []
		for id: String in menu.backend.party_ids():
			if not targets.has(id):
				dimmed.append(id)
		_column.set_dimmed(dimmed)
		_column.set_active(true)
		if not targets.is_empty():
			_column.select(targets[0])
	menu.refresh_info()


func _end_target() -> void:
	_mode = Mode.LIST
	_column.frame_all = false
	_column.set_active(false)
	_list.active = true
	_reload_rows_keeping_cursor()
	menu.refresh_info()


func _on_target_picked(member_id: String) -> void:
	_use_on(member_id)


func _use_on(member_id: String) -> void:
	var result: Dictionary = menu.backend.use_item(_target_item, member_id, menu.item_context())
	if not bool(result["ok"]):
		_message = _failure_text(str(result["reason"]))
		_message_warn = true
		menu.audio.sfx("back")
		menu.refresh_info()
		return
	_message = _result_text(_target_item, member_id, result)
	_message_warn = false
	_column.set_members(menu.backend.party())
	var remaining: int = menu.backend.owned(_target_item)
	var targets: Array[String] = menu.backend.item_targets(_target_item) if remaining > 0 else ([] as Array[String])
	if _all_targets or targets.is_empty():
		_end_target()
		return
	var dimmed: Array[String] = []
	for id: String in menu.backend.party_ids():
		if not targets.has(id):
			dimmed.append(id)
	_column.set_dimmed(dimmed)
	if dimmed.has(_column.selected_id()):
		_column.select(targets[0])
	_reload_rows_keeping_cursor()
	menu.refresh_info()


func _failure_text(reason_id: String) -> String:
	match reason_id:
		Bag.WHY_WRONG_PLACE:
			return menu.backend.item_reason(_target_item, menu.item_context())
		Bag.WHY_NO_EFFECT, Bag.WHY_NO_TARGET:
			return menu.backend.reason_text("nobody_needs")
		Bag.WHY_NOT_OWNED:
			return menu.backend.reason_text("not_owned")
	return menu.backend.reason_text("cant_use")


func _result_text(item_id: String, member_id: String, result: Dictionary) -> String:
	var strings: Dictionary = menu.text["items"]
	var effect: Dictionary = ItemData.shared().item(item_id).get("effect", {})
	var who: String = menu.backend.member_name(member_id)
	if bool(effect.get("rest", false)):
		return str(strings["rested"])
	var hp: int = int(result.get("healed_hp", 0))
	var juice: int = int(result.get("restored_juice", 0))
	if effect.has("revive_hp_pct"):
		return str(strings["revived"]).replace("{name}", who).replace("{hp}", str(hp))
	if effect.has("boost"):
		var boost: Dictionary = effect["boost"]
		var stat: String = str(boost.keys()[0])
		return str(strings["boosted"]).replace("{name}", who).replace("{n}", str(int(boost[stat]))) \
				.replace("{stat}", str(menu.text["equip"]["stat_names"].get(stat, stat)))
	if hp > 0 and juice > 0:
		return str(strings["recovered_both"]).replace("{name}", who).replace("{hp}", str(hp)).replace("{juice}", str(juice))
	if hp > 0:
		return str(strings["recovered"]).replace("{name}", who).replace("{hp}", str(hp))
	return str(strings["juiced"]).replace("{name}", who).replace("{juice}", str(juice))


# ---- input ----

func command(cmd: MenuInput.Cmd) -> void:
	if _mode == Mode.TARGET:
		match cmd:
			MenuInput.Cmd.CANCEL:
				menu.audio.sfx("back")
				_end_target()
			MenuInput.Cmd.CONFIRM:
				if _all_targets:
					menu.audio.sfx("confirm")
					_use_on(menu.backend.party_ids()[0])
				else:
					_column.list.handle_command(cmd)
			MenuInput.Cmd.UP, MenuInput.Cmd.DOWN:
				_column.list.handle_command(cmd)
		return
	match cmd:
		MenuInput.Cmd.LEFT:
			menu.audio.sfx("tick")
			_load_tab(_tab - 1)
		MenuInput.Cmd.RIGHT:
			menu.audio.sfx("tick")
			_load_tab(_tab + 1)
		_:
			super.command(cmd)


func mouse(event: InputEvent) -> bool:
	if _mode == Mode.TARGET:
		return not _all_targets and _column.list.handle_mouse(event)
	return _list.handle_mouse(event)


func refresh() -> void:
	_column.set_members(menu.backend.party())
	_reload_rows_keeping_cursor()


func info() -> Dictionary:
	if _mode == Mode.TARGET:
		if not _message.is_empty():
			return MenuPage.info_of(_message, _message_warn)
		if _all_targets:
			return MenuPage.info_of(str(menu.text["items"]["who_all"]))
		var id: String = _column.selected_id()
		if _column.dimmed.has(id):
			return MenuPage.info_of(menu.backend.member_reason(_target_item, id), true)
		return MenuPage.info_of(str(menu.text["items"]["who"]))
	if not _message.is_empty():
		return MenuPage.info_of(_message, _message_warn)
	var index: int = _list.get_cursor_index()
	var id_now: String = _list.get_item_id(index)
	if id_now.is_empty():
		return MenuPage.info_of("")
	var row: Dictionary = _list.get_items()[index]
	if not bool(row.get("enabled", true)):
		return MenuPage.info_of(str(row.get("reason", "")), true)
	return MenuPage.info_of(menu.backend.item_desc(id_now))
