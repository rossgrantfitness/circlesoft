class_name PageParty
extends MenuPage
## Party: the order the crew fights in. The leader (Red) stays first; pick a fighter, then pick who
## to swap places with. With three fighters that is the whole job; the bench, Lane Chart and Swap
## come later. The order is stored through GameState.set_party_order (the save keeps it).

enum Mode { PICK, SWAP }

var _spec: Dictionary = {}
var _mode: Mode = Mode.PICK
var _column: MemberColumn = null
var _canvas: Control = null
var _moving: String = ""
var _message: String = ""
var _message_warn: bool = false


func build() -> void:
	_spec = menu.layout["party_page"]
	_canvas = menu.make_drawing(root, Vector2.ZERO, FieldMenu.PAGE_AREA.size, _draw_labels)
	var column_at: Dictionary = _spec["column"]
	_column = menu.make_member_column(root, MemberColumn.Style.COLUMN, Vector2(float(column_at["x"]), float(column_at["y"])))
	_column.picked.connect(_on_picked)
	_column.cursor_moved.connect(func(_id: String) -> void:
		_message = ""
		menu.refresh_info())
	_apply_locks()
	var ids: Array[String] = menu.backend.party_ids()
	if ids.size() > 1:
		_column.select(ids[1])


func primary_list() -> MenuList:
	return _column.list


func get_column() -> MemberColumn:
	return _column


func get_mode() -> Mode:
	return _mode


## The leader is locked in first place; with no way to write the order everyone is locked.
func _apply_locks() -> void:
	var locked: Array[String] = []
	var ids: Array[String] = menu.backend.party_ids()
	if not menu.backend.can_reorder_party():
		locked.assign(ids)
	elif not ids.is_empty():
		locked.append(ids[0])
	if _mode == Mode.SWAP and not _moving.is_empty() and not locked.has(_moving):
		locked.append(_moving)
	_column.set_dimmed(locked)


func _on_picked(member_id: String) -> void:
	if _mode == Mode.PICK:
		_moving = member_id
		_mode = Mode.SWAP
		_message = ""
		_column.hold = true
		_apply_locks()
		var ids: Array[String] = menu.backend.party_ids()
		for id: String in ids:
			if id != _moving and id != ids[0]:
				_column.select(id)
				break
		menu.refresh_info()
		return
	_swap_with(member_id)


func _swap_with(other: String) -> void:
	var ids: Array[String] = menu.backend.party_ids()
	var a: int = ids.find(_moving)
	var b: int = ids.find(other)
	if a < 0 or b < 0:
		return
	ids[a] = other
	ids[b] = _moving
	var written: bool = menu.backend.set_party_order(ids)
	_mode = Mode.PICK
	_column.hold = false
	_column.set_members(menu.backend.party())
	_apply_locks()
	_column.select(_moving)
	if not written:
		_message = str(menu.text["party"]["fixed"])
		_message_warn = true
		menu.audio.sfx("back")
	else:
		var names: PackedStringArray = PackedStringArray()
		for id: String in menu.backend.party_ids():
			names.append(menu.backend.member_name(id))
		_message = str(menu.text["party"]["swapped"]).replace("{names}", ", ".join(names))
		_message_warn = false
	_canvas.queue_redraw()
	menu.refresh_info()


func command(cmd: MenuInput.Cmd) -> void:
	if cmd == MenuInput.Cmd.CANCEL:
		if _mode == Mode.SWAP:
			menu.audio.sfx("back")
			_mode = Mode.PICK
			_column.hold = false
			_apply_locks()
			menu.refresh_info()
		else:
			menu.back_to_main()
		return
	_column.list.handle_command(cmd)


func mouse(event: InputEvent) -> bool:
	return _column.list.handle_mouse(event)


func refresh() -> void:
	_column.set_members(menu.backend.party())
	_apply_locks()
	_canvas.queue_redraw()


func _draw_labels(canvas: Control) -> void:
	var strings: Dictionary = menu.text["party"]
	var slots: Array = strings["slots"]
	var step: int = int(menu.layout["member_column"]["row_h"])
	var top: float = float(_spec["column"]["y"])
	var x: float = float(_spec["label_x"])
	for i: int in menu.backend.party_ids().size():
		var label: String = str(slots[mini(i, slots.size() - 1)])
		if i == 0:
			label += "  " + str(strings["leader"])
		UiText.draw(canvas, "menu", Vector2(x, top + float(i * step) + float(_spec["label_dy"])), label,
				MenuDraw.color("text_highlight") if i == 0 else MenuDraw.color("text"))
	var later: Array = strings["later"]
	for i: int in later.size():
		UiText.draw(canvas, "tag", Vector2(x, FieldMenu.PAGE_AREA.size.y - 22.0 + float(i) * 11.0), str(later[i]), MenuDraw.color("text_dim"))


func info() -> Dictionary:
	if not _message.is_empty():
		return MenuPage.info_of(_message, _message_warn)
	if not menu.backend.can_reorder_party():
		return MenuPage.info_of(str(menu.text["party"]["fixed"]), true)
	if _mode == Mode.SWAP:
		return MenuPage.info_of(str(menu.text["party"]["swap"]).replace("{name}", menu.backend.member_name(_moving)))
	var id: String = _column.selected_id()
	var ids: Array[String] = menu.backend.party_ids()
	if not ids.is_empty() and id == ids[0]:
		return MenuPage.info_of(str(menu.text["party"]["red_leads"]).replace("{name}", menu.backend.member_name(id)), true)
	return MenuPage.info_of(str(menu.text["party"]["pick"]))
