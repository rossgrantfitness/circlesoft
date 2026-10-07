class_name PageEquip
extends MenuPage
## Equip: pick a fighter, pick a slot (weapon, armor, charm), then pick from the spare gear in the
## bag. The seven stats sit underneath; while a piece is highlighted every stat that would change
## shows its new value with an up (green) or down (coral) arrow. Gear the fighter can't wear stays
## in the list, greyed, with the reason ("Only Otis can use this.", "Heavy armor: Otis only.").
## Rules come from Equipment; the owner lock lives there, not here.

enum Mode { MEMBER, SLOT, ITEM }

const REMOVE_ID: String = "__remove__"

var _spec: Dictionary = {}
var _mode: Mode = Mode.MEMBER
var _column: MemberColumn = null
var _list: MenuList = null
var _canvas: Control = null
var _member: String = ""
var _slot: String = ""
var _message: String = ""
var _message_warn: bool = false
var _preview: Dictionary = {}
var _slot_memory: int = 0


func build() -> void:
	_spec = menu.layout["equip_page"]
	_canvas = menu.make_drawing(root, Vector2.ZERO, FieldMenu.PAGE_AREA.size, _draw_canvas)
	var column_at: Dictionary = _spec["column"]
	_column = menu.make_member_column(root, MemberColumn.Style.COMPACT, Vector2(float(column_at["x"]), float(column_at["y"])))
	_column.cursor_moved.connect(_on_member_moved)
	_column.picked.connect(_on_member_picked)
	_list = menu.make_list(root, _spec["slots"])
	_list.active = false
	_list.activated.connect(_on_row_activated)
	_list.cursor_moved.connect(_on_row_moved)
	_column.select(str(menu.memory.get("equip.member", _column.selected_id())))
	_member = _column.selected_id()
	_load_slots()


func primary_list() -> MenuList:
	return _list


func get_column() -> MemberColumn:
	return _column


func get_mode() -> Mode:
	return _mode


func get_member() -> String:
	return _member


func get_slot() -> String:
	return _slot


## The stat preview for the highlighted gear: {stat: new value}, empty when nothing is compared.
func get_preview() -> Dictionary:
	return _preview


func _is_removable(slot: String) -> bool:
	return (_spec["removable_slots"] as Array).has(slot)


# ---- rows ----

func _slot_names() -> Dictionary:
	return menu.text["equip"]["slots"]


func _load_slots() -> void:
	var worn: Dictionary = menu.backend.equipped(_member)
	var rows: Array[Dictionary] = []
	for slot: String in GearBridge.SLOTS:
		var item_id: String = str(worn[slot])
		rows.append({"id": slot, "label": menu.backend.item_name(item_id) if not item_id.is_empty() else str(menu.text["equip"]["none"]),
				"enabled": true, "item": item_id})
	_list.visible_rows = rows.size()
	_list.text_x = int(_spec["slots"]["text_x"])
	_list.set_items(rows, true)
	_preview = {}
	_canvas.queue_redraw()
	menu.refresh_info()


func _load_candidates() -> void:
	var rows: Array[Dictionary] = []
	var worn: Dictionary = menu.backend.equipped(_member)
	for id: String in menu.backend.spare_gear(_slot):
		var why: String = menu.backend.equip_reason(_member, _slot, id)
		var row: Dictionary = {"id": id, "label": menu.backend.item_name(id), "enabled": why.is_empty(), "reason": why}
		if menu.backend.owned(id) > 1:
			row["value"] = str(menu.text["equip"]["spare"]).replace("{n}", str(menu.backend.owned(id)))
		rows.append(row)
	if _is_removable(_slot) and not str(worn[_slot]).is_empty():
		rows.append({"id": REMOVE_ID, "label": str(menu.text["equip"]["remove"]), "enabled": true})
	_list.visible_rows = int(_spec["slots"]["rows"])
	_list.text_x = int(_spec["slots"]["text_x_items"])
	_list.set_items(rows)
	_update_preview()
	menu.refresh_info()


func _update_preview() -> void:
	_preview = {}
	if _mode == Mode.ITEM and _list.get_count() > 0:
		var row: Dictionary = _list.get_items()[_list.get_cursor_index()]
		if bool(row.get("enabled", true)):
			var item_id: String = "" if str(row["id"]) == REMOVE_ID else str(row["id"])
			_preview = menu.backend.stats_preview(_member, _slot, item_id)
	_canvas.queue_redraw()


# ---- drawing ----

func _draw_canvas(canvas: Control) -> void:
	var slots: Dictionary = _spec["slots"]
	if _mode != Mode.ITEM:
		var names: Dictionary = _slot_names()
		for i: int in GearBridge.SLOTS.size():
			var y: float = float(slots["y"]) + float(slots["first_y"]) + float(i) * float(slots["step"]) + 11.0
			UiText.draw(canvas, "tag", Vector2(float(slots["x"]) + float(_spec["tag_x"]), y), str(names[GearBridge.SLOTS[i]]), MenuDraw.color("text_dim"))
	_draw_stats(canvas)


func _draw_stats(canvas: Control) -> void:
	var spec: Dictionary = _spec["stats"]
	var x0: float = float(spec["x"])
	var y0: float = float(spec["y"])
	var step: float = float(spec["step"])
	canvas.draw_rect(Rect2(x0 + 8.0, y0 - 4.0, float(_spec["slots"]["w"]) - 16.0, 1), MenuDraw.color("dusk"))
	var now: Dictionary = menu.backend.stats(_member)
	var names: Dictionary = menu.text["equip"]["stat_names"]
	var row: int = 0
	for key: String in BattleData.STAT_KEYS:
		var y: float = y0 + step * float(row + 1)
		UiText.draw(canvas, "menu", Vector2(x0 + float(spec["label_x"]), y), str(names[key]), MenuDraw.color("text_dim"))
		var current: int = int(now.get(key, 0))
		UiText.draw(canvas, "menu", Vector2(0, y), str(current), MenuDraw.color("text"), HORIZONTAL_ALIGNMENT_RIGHT, x0 + float(spec["now_right"]))
		if _preview.has(key):
			var next: int = int(_preview[key])
			var direction: int = MenuDraw.direction_of(next, current)
			if direction != MenuDraw.ARROW_SAME:
				MenuDraw.arrow(canvas, Vector2i(int(x0 + float(spec["arrow_x"])), int(y) - 10), direction)
				var tint: Color = MenuDraw.color("up") if direction > 0 else MenuDraw.color("down")
				UiText.draw(canvas, "menu", Vector2(0, y), str(next), tint, HORIZONTAL_ALIGNMENT_RIGHT, x0 + float(spec["next_right"]))
		row += 1


# ---- flow ----

func _on_member_moved(member_id: String) -> void:
	if _mode != Mode.MEMBER:
		return
	menu.memory["equip.member"] = member_id
	_member = member_id
	_load_slots()


func _on_member_picked(member_id: String) -> void:
	_member = member_id
	_mode = Mode.SLOT
	_message = ""
	_column.set_active(false)
	_column.hold = true
	_list.active = true
	_load_slots()
	_list.set_index(_slot_memory, false)
	menu.refresh_info()


func _on_row_activated(index: int) -> void:
	var id: String = _list.get_item_id(index)
	if _mode == Mode.SLOT:
		_slot = id
		_slot_memory = index
		_mode = Mode.ITEM
		_message = ""
		_canvas.queue_redraw()
		_load_candidates()
		if _list.get_count() == 0:
			_message = str(menu.text["equip"]["no_spares"]).replace("{slot}", str(_slot_names()[_slot]).to_lower())
			_message_warn = false
			_back_to_slots()
			menu.audio.sfx("back")
		return
	if _mode == Mode.ITEM:
		_equip_row(id)


func _equip_row(row_id: String) -> void:
	var item_id: String = "" if row_id == REMOVE_ID else row_id
	var who: String = menu.backend.member_name(_member)
	var ok: bool = menu.backend.equip(_member, _slot, item_id)
	if not ok:
		_message = menu.backend.equip_reason(_member, _slot, item_id)
		_message_warn = true
		menu.audio.sfx("back")
		menu.refresh_info()
		return
	if item_id.is_empty():
		_message = str(menu.text["equip"]["removed"]).replace("{name}", who).replace("{slot}", str(_slot_names()[_slot]).to_lower())
	else:
		_message = str(menu.text["equip"]["equipped"]).replace("{name}", who).replace("{item}", menu.backend.item_name(item_id))
	_message_warn = false
	_column.set_members(menu.backend.party())
	_back_to_slots()


func _back_to_slots() -> void:
	var keep: String = _message
	_mode = Mode.SLOT
	_list.set_items([] as Array[Dictionary])
	_load_slots()
	_list.set_index(_slot_memory, false)
	_message = keep
	menu.refresh_info()


func _back_to_members() -> void:
	_mode = Mode.MEMBER
	_message = ""
	_list.active = false
	_column.hold = false
	_column.set_active(true)
	_load_slots()


func _on_row_moved(_index: int) -> void:
	_message = ""
	if _mode == Mode.ITEM:
		_update_preview()
	menu.refresh_info()


func command(cmd: MenuInput.Cmd) -> void:
	match _mode:
		Mode.MEMBER:
			if cmd == MenuInput.Cmd.CANCEL:
				menu.back_to_main()
			else:
				_column.list.handle_command(cmd)
		Mode.SLOT:
			if cmd == MenuInput.Cmd.CANCEL:
				menu.audio.sfx("back")
				_back_to_members()
			else:
				_list.handle_command(cmd)
		Mode.ITEM:
			if cmd == MenuInput.Cmd.CANCEL:
				menu.audio.sfx("back")
				_back_to_slots()
			else:
				_list.handle_command(cmd)


func mouse(event: InputEvent) -> bool:
	if _mode == Mode.MEMBER:
		return _column.list.handle_mouse(event)
	return _list.handle_mouse(event)


func refresh() -> void:
	_column.set_members(menu.backend.party())
	if _mode == Mode.ITEM:
		_load_candidates()
	else:
		_load_slots()


func info() -> Dictionary:
	if not _message.is_empty():
		return MenuPage.info_of(_message, _message_warn)
	match _mode:
		Mode.MEMBER:
			return MenuPage.info_of(str(menu.text["commands"]["equip"]["hint"]))
		Mode.SLOT:
			if _list.get_count() == 0:
				return MenuPage.info_of("")
			var worn_id: String = str(_list.get_items()[_list.get_cursor_index()].get("item", ""))
			if worn_id.is_empty():
				return MenuPage.info_of(str(menu.text["equip"]["pick_slot"]))
			return MenuPage.info_of(menu.backend.item_desc(worn_id))
	if _list.get_count() == 0:
		return MenuPage.info_of("")
	var row: Dictionary = _list.get_items()[_list.get_cursor_index()]
	if not bool(row.get("enabled", true)):
		return MenuPage.info_of(str(row.get("reason", "")), true)
	if str(row["id"]) == REMOVE_ID:
		return MenuPage.info_of(str(menu.text["equip"]["pick_gear"]))
	return MenuPage.info_of(menu.backend.item_desc(str(row["id"])))
