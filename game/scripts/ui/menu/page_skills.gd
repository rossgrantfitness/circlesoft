class_name PageSkills
extends MenuPage
## Skills: pick a fighter, see what they know and what it costs in Juice. Heals work out here
## too (Cough Drop, Duct Tape): pick the skill, then who gets it. Attack skills are greyed with
## "Battle only." Learned skills come from the level (Progression), costs and text from the skill data.

enum Mode { MEMBER, LIST, TARGET }

var _spec: Dictionary = {}
var _mode: Mode = Mode.MEMBER
var _column: MemberColumn = null
var _list: MenuList = null
var _header: Control = null
var _empty_label: Label = null
var _caster: String = ""
var _skill: String = ""
var _message: String = ""
var _message_warn: bool = false


func build() -> void:
	_spec = menu.layout["skills_page"]
	_header = menu.make_drawing(root, Vector2.ZERO, FieldMenu.PAGE_AREA.size, _draw_header)
	var column_at: Dictionary = _spec["column"]
	_column = menu.make_member_column(root, MemberColumn.Style.COLUMN, Vector2(float(column_at["x"]), float(column_at["y"])))
	_column.cursor_moved.connect(_on_member_moved)
	_column.picked.connect(_on_member_picked)
	_list = menu.make_list(root, _spec["list"])
	_list.active = false
	_list.activated.connect(_on_skill_activated)
	_list.cursor_moved.connect(func(_i: int) -> void:
		_message = ""
		menu.refresh_info())
	_empty_label = menu.make_label(root, "body", "text_dim", Vector2(float(_spec["list"]["x"]) + 12.0, 44.0))
	_empty_label.text = str(menu.text["skills"]["none"])
	_column.select(str(menu.memory.get("skills.member", _column.selected_id())))
	_caster = _column.selected_id()
	_load_skills()


func primary_list() -> MenuList:
	return _list


func get_column() -> MemberColumn:
	return _column


func get_mode() -> Mode:
	return _mode


func _draw_header(canvas: Control) -> void:
	var list_rect: Dictionary = _spec["list"]
	var y: int = int(_spec["header_y"])
	var x: float = float(list_rect["x"])
	UiText.draw(canvas, "menu", Vector2(x + 20.0, y), str(menu.text["skills"]["head_skill"]), MenuDraw.color("text_dim"))
	UiText.draw(canvas, "menu", Vector2(0, y), str(menu.text["skills"]["head_cost"]), MenuDraw.color("text_dim"),
			HORIZONTAL_ALIGNMENT_RIGHT, x + float(list_rect["w"]) - 10.0)
	canvas.draw_rect(Rect2(x + 8.0, y + 4, float(list_rect["w"]) - 16.0, 1), MenuDraw.color("dusk"))


func _load_skills() -> void:
	var rows: Array[Dictionary] = []
	for skill: Dictionary in menu.backend.skills_of(_caster):
		rows.append({"id": str(skill["id"]), "label": str(skill["name"]), "value": str(skill["cost"]),
				"enabled": bool(skill["usable"]), "reason": str(skill["reason"]), "desc": str(skill["desc"])})
	_list.set_items(rows, true)
	_empty_label.visible = rows.is_empty()
	menu.refresh_info()


func _on_member_moved(member_id: String) -> void:
	if _mode != Mode.MEMBER:
		menu.refresh_info()
		return
	menu.memory["skills.member"] = member_id
	_caster = member_id
	_message = ""
	_list.set_items([] as Array[Dictionary])
	_load_skills()


func _on_member_picked(member_id: String) -> void:
	if _mode == Mode.TARGET:
		_cast_on(member_id)
		return
	_caster = member_id
	if _list.get_count() == 0:
		menu.audio.sfx("back")
		return
	_mode = Mode.LIST
	_column.set_active(false)
	_column.hold = true
	_list.active = true
	_list.set_index(0, false)
	menu.refresh_info()


func _on_skill_activated(index: int) -> void:
	_skill = _list.get_item_id(index)
	var skill: Dictionary = BattleData.shared().skill(_skill)
	if str(skill.get("target", "")) == "one_ally":
		_start_target()
	else:
		_cast_on(_caster)


func _start_target() -> void:
	_mode = Mode.TARGET
	_message = ""
	_list.active = false
	var targets: Array[String] = menu.backend.skill_targets(_skill)
	var dimmed: Array[String] = []
	for id: String in menu.backend.party_ids():
		if not targets.has(id):
			dimmed.append(id)
	_column.hold = false
	_column.set_dimmed(dimmed)
	_column.set_active(true)
	if not targets.is_empty():
		_column.select(targets[0])
	menu.refresh_info()


func _cast_on(member_id: String) -> void:
	var result: Dictionary = menu.backend.use_skill(_caster, _skill, member_id)
	if not bool(result["ok"]):
		_message = str(result["reason"])
		_message_warn = true
		menu.audio.sfx("back")
		_to_list()
		return
	var healed: Dictionary = result["healed"]
	var who: String = menu.backend.member_name(member_id)
	if healed.has(member_id):
		_message = str(menu.text["skills"]["cast"]).replace("{name}", who).replace("{hp}", str(int(healed[member_id])))
	else:
		_message = str(menu.text["skills"]["cast_juice"]).replace("{name}", who)
	_message_warn = false
	_to_list()


func _to_list() -> void:
	_mode = Mode.LIST
	_column.set_dimmed([] as Array[String])
	_column.set_members(menu.backend.party())
	_column.set_active(false)
	_column.hold = true
	_list.active = true
	_load_skills()


func _to_members() -> void:
	_mode = Mode.MEMBER
	_message = ""
	_list.active = false
	_column.hold = false
	_column.set_dimmed([] as Array[String])
	_column.set_active(true)
	menu.refresh_info()


func command(cmd: MenuInput.Cmd) -> void:
	match _mode:
		Mode.MEMBER:
			if cmd == MenuInput.Cmd.CANCEL:
				menu.back_to_main()
			else:
				_column.list.handle_command(cmd)
		Mode.LIST:
			if cmd == MenuInput.Cmd.CANCEL:
				menu.audio.sfx("back")
				_to_members()
			else:
				_list.handle_command(cmd)
		Mode.TARGET:
			if cmd == MenuInput.Cmd.CANCEL:
				menu.audio.sfx("back")
				_to_list()
			else:
				_column.list.handle_command(cmd)


func mouse(event: InputEvent) -> bool:
	if _mode == Mode.LIST:
		return _list.handle_mouse(event)
	return _column.list.handle_mouse(event)


func info() -> Dictionary:
	if not _message.is_empty():
		return MenuPage.info_of(_message, _message_warn)
	match _mode:
		Mode.MEMBER:
			return MenuPage.info_of(str(menu.text["commands"]["skills"]["hint"]))
		Mode.TARGET:
			var id: String = _column.selected_id()
			if _column.dimmed.has(id):
				return MenuPage.info_of(menu.backend.reason_text("nobody_needs"), true)
			return MenuPage.info_of(str(menu.text["skills"]["who"]))
	var index: int = _list.get_cursor_index()
	if _list.get_count() == 0:
		return MenuPage.info_of("")
	var row: Dictionary = _list.get_items()[index]
	if not bool(row.get("enabled", true)):
		return MenuPage.info_of(str(row.get("reason", "")), true)
	return MenuPage.info_of(str(row.get("desc", "")))
