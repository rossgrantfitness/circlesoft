class_name PageStatus
extends MenuPage
## Status: pick a fighter on the left (up / down) and see portrait-tile, level, XP to the next level,
## HP and Juice, the stats, what they are wearing, the skills they know and their condition.
## Stats come from StatCalc (growth table plus boosters plus gear), so they match what a battle uses.

var _spec: Dictionary = {}
var _column: MemberColumn = null
var _canvas: Control = null


func build() -> void:
	_spec = menu.layout["status_page"]
	_canvas = menu.make_drawing(root, Vector2.ZERO, FieldMenu.PAGE_AREA.size, _draw_detail)
	var column_at: Dictionary = _spec["column"]
	_column = menu.make_member_column(root, MemberColumn.Style.COMPACT, Vector2(float(column_at["x"]), float(column_at["y"])))
	_column.select(str(menu.memory.get("status.member", _column.selected_id())))
	_column.cursor_moved.connect(func(id: String) -> void:
		menu.memory["status.member"] = id
		_canvas.queue_redraw()
		menu.refresh_info())
	_column.picked.connect(func(_id: String) -> void: menu.audio.sfx("tick"))


func primary_list() -> MenuList:
	return _column.list


func get_column() -> MemberColumn:
	return _column


func get_member() -> String:
	return _column.selected_id()


func command(cmd: MenuInput.Cmd) -> void:
	if cmd == MenuInput.Cmd.CANCEL:
		menu.back_to_main()
	else:
		_column.list.handle_command(cmd)


func mouse(event: InputEvent) -> bool:
	return _column.list.handle_mouse(event)


func refresh() -> void:
	_column.set_members(menu.backend.party())
	_canvas.queue_redraw()


func info() -> Dictionary:
	return MenuPage.info_of(str(menu.text["status"]["hint"]))


## The lines the detail panel will show for a fighter (also what the tests read):
## {name, level, xp_line, stats: {stat: value}, gear: {slot: name}, skills: [names], condition}.
func describe(member_id: String) -> Dictionary:
	var who: Dictionary = menu.backend.member(member_id)
	var strings: Dictionary = menu.text["status"]
	var to_next: int = menu.backend.xp_to_next(member_id)
	var worn: Dictionary = menu.backend.equipped(member_id)
	var gear: Dictionary = {}
	for slot: String in GearBridge.SLOTS:
		var item_id: String = str(worn[slot])
		gear[slot] = menu.backend.item_name(item_id) if not item_id.is_empty() else str(menu.text["equip"]["none"])
	var skills: Array[String] = []
	for skill: Dictionary in menu.backend.skills_of(member_id):
		skills.append(str(skill["name"]))
	return {
		"name": str(who.get("name", "")),
		"level": int(who.get("level", 1)),
		"xp_line": str(strings["xp_next"]).replace("{n}", str(to_next)) if to_next > 0 else str(strings["xp_max"]),
		"stats": menu.backend.stats(member_id),
		"gear": gear,
		"skills": skills,
		"condition": str(strings["down"]) if int(who.get("hp", 0)) <= 0 else str(strings["fine"]),
	}


func _draw_detail(canvas: Control) -> void:
	var id: String = _column.selected_id()
	if id.is_empty():
		return
	var who: Dictionary = menu.backend.member(id)
	var info_now: Dictionary = describe(id)
	var strings: Dictionary = menu.text["status"]
	var x0: float = float(_spec["x"])
	var width: float = float(_spec["w"])
	var y: int = int(_spec["name_y"])
	var white: Color = MenuDraw.color("text")
	var dim: Color = MenuDraw.color("text_dim")
	UiText.draw(canvas, "menu", Vector2(x0 + 4.0, y), str(info_now["name"]), MenuDraw.color("text_highlight"))
	var name_w: int = UiFonts.text_width("menu", str(info_now["name"]))
	UiText.draw(canvas, "menu", Vector2(x0 + 12.0 + float(name_w), y), str(strings["level"]).replace("{level}", str(info_now["level"])), dim)
	UiText.draw(canvas, "menu", Vector2(0, y), str(info_now["xp_line"]), white, HORIZONTAL_ALIGNMENT_RIGHT, x0 + width)
	var bar_w: int = int(width) - 8
	MenuDraw.bar_row(canvas, Vector2i(int(x0) + 4, int(_spec["bar_hp_y"])), str(strings["hp"]), int(who.get("hp", 0)), int(who.get("hp_max", 0)),
			MenuDraw.color("hp"), int(menu.layout["hp_bar_h"]), bar_w)
	MenuDraw.bar_row(canvas, Vector2i(int(x0) + 4, int(_spec["bar_juice_y"])), str(strings["juice"]), int(who.get("juice", 0)), int(who.get("juice_max", 0)),
			MenuDraw.color("juice"), int(menu.layout["juice_bar_h"]), bar_w)
	var stat_keys: Array[String] = ["attack", "defense", "heart", "speed", "luck"]
	var cols: Array = _spec["stat_cols"]
	var rows: Array = _spec["stat_y"]
	var stats: Dictionary = info_now["stats"]
	var names: Dictionary = strings["stat_names"]
	for i: int in stat_keys.size():
		var cx: float = x0 + float(cols[i % cols.size()])
		var cy: float = float(rows[i / cols.size()])
		UiText.draw(canvas, "tag", Vector2(cx, cy), str(names[stat_keys[i]]), dim)
		UiText.draw(canvas, "menu", Vector2(0, cy), str(int(stats.get(stat_keys[i], 0))), white, HORIZONTAL_ALIGNMENT_RIGHT, cx + float(_spec["stat_value_w"]))
	var tag_x: float = x0 + float(_spec["tag_x"])
	var value_x: float = x0 + float(_spec["value_x"])
	var gear_rows: Array = _spec["gear_y"]
	for i: int in GearBridge.SLOTS.size():
		UiText.draw(canvas, "tag", Vector2(tag_x, float(gear_rows[i])), str(strings["gear"][GearBridge.SLOTS[i]]), dim)
		UiText.draw(canvas, "menu", Vector2(value_x, float(gear_rows[i])), str((info_now["gear"] as Dictionary)[GearBridge.SLOTS[i]]), white)
	var skills_rows: Array = _spec["skills_y"]
	UiText.draw(canvas, "tag", Vector2(tag_x, float(skills_rows[0])), str(strings["skills"]), dim)
	var lines: PackedStringArray = _wrap_names(info_now["skills"], int(width - (value_x - x0)) - 4)
	for i: int in mini(lines.size(), skills_rows.size()):
		UiText.draw(canvas, "menu", Vector2(value_x, float(skills_rows[i])), lines[i], white)
	var last_row: float = float(skills_rows[skills_rows.size() - 1]) + 13.0
	UiText.draw(canvas, "tag", Vector2(tag_x, last_row), str(strings["condition"]), dim)
	var down: bool = int(who.get("hp", 0)) <= 0
	UiText.draw(canvas, "menu", Vector2(value_x, last_row), str(info_now["condition"]), MenuDraw.color("down") if down else MenuDraw.color("good"))


## Skill names joined with commas and wrapped to a pixel width.
func _wrap_names(names: Array, max_width: int) -> PackedStringArray:
	if names.is_empty():
		return PackedStringArray([str(menu.text["status"]["no_skills"])])
	var lines: PackedStringArray = PackedStringArray()
	var current: String = ""
	for i: int in names.size():
		var piece: String = str(names[i]) + (", " if i < names.size() - 1 else "")
		if not current.is_empty() and UiFonts.text_width("menu", current + piece) > max_width:
			lines.append(current.strip_edges())
			current = ""
		current += piece
	lines.append(current.strip_edges())
	return lines
