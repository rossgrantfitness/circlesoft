class_name PageSword
extends MenuPage
## Sword: the slice's Equip page. Red alone, so no party: a list of the swords in data/combat/swords.json (in rack order) and
## the one in her hand is marked. Pick one to put it in her hand (ActionPlayer.equip_sword). A sword may name an
## `unlock_flag` in swords.json; until that story flag is set it is greyed out (no flag = always there, like the sandbox's racks).
## The choice is also written to the slice run (HeroSession) so it survives the next door. Words: data/text/field_menu.json "sword".

var _list: MenuList = null
var _message: String = ""


func build() -> void:
	_list = menu.make_list(root, menu.layout["items_page"]["list"])
	_list.activated.connect(_on_activated)
	_list.cursor_moved.connect(func(_index: int) -> void:
		_message = ""
		menu.refresh_info())
	_load_rows()
	var wanted: int = _index_of(_current())
	_list.set_index(maxi(wanted, 0), false)
	menu.refresh_info()


func primary_list() -> MenuList:
	return _list


func info() -> Dictionary:
	var strings: Dictionary = menu.text.get("sword", {}) as Dictionary
	if not _message.is_empty():
		return MenuPage.info_of(_message, false)
	var id: String = _list.get_item_id(_list.get_cursor_index())
	if id.is_empty():
		return MenuPage.info_of(str(strings.get("empty", "")), true)
	if not _unlocked(id):
		return MenuPage.info_of(str(strings.get("locked", "Not found yet.")), true)
	if id == _current():
		return MenuPage.info_of(str(strings.get("in_hand", "In her hand.")), false)
	return MenuPage.info_of(str(strings.get("hint", "Put it in her hand.")), false)


func _swords() -> Dictionary:
	return DataDB.get_dict("combat/swords").get("swords", {}) as Dictionary


func _order() -> Array[String]:
	var ids: Array[String] = []
	for id: Variant in DataDB.get_dict("combat/swords").get("rack", []) as Array:
		if _swords().has(str(id)):
			ids.append(str(id))
	for id: Variant in _swords().keys():
		if not ids.has(str(id)):
			ids.append(str(id))
	return ids


func _unlocked(id: String) -> bool:
	var flag: String = str((_swords().get(id, {}) as Dictionary).get("unlock_flag", ""))
	if flag.is_empty():
		return true
	var state: Node = menu.state_node()
	return state != null and bool(state.call("get_flag", flag))


func _current() -> String:
	var hero: Node = menu.player
	if hero != null and is_instance_valid(hero) and hero.has_method("current_sword"):
		var held: String = str(hero.call("current_sword"))
		if not held.is_empty():
			return held
	var state: Node = menu.state_node()
	if state != null:
		var run: Dictionary = state.get("slice_run") as Dictionary
		return str((run.get("session", {}) as Dictionary).get("sword", ""))
	return ""


func _load_rows() -> void:
	var strings: Dictionary = menu.text.get("sword", {}) as Dictionary
	var rows: Array[Dictionary] = []
	for id: String in _order():
		var entry: Dictionary = _swords()[id]
		var row: Dictionary = {"id": id, "label": str(entry.get("name", id)), "enabled": _unlocked(id)}
		if id == _current():
			row["value"] = str(strings.get("marker", "In hand"))
		rows.append(row)
	_list.set_items(rows, true)


func _index_of(id: String) -> int:
	for i: int in _list.get_count():
		if _list.get_item_id(i) == id:
			return i
	return -1


func _on_activated(index: int) -> void:
	var id: String = _list.get_item_id(index)
	if id.is_empty() or not _unlocked(id):
		menu.audio.sfx("back")
		return
	var strings: Dictionary = menu.text.get("sword", {}) as Dictionary
	var hero: Node = menu.player
	if hero != null and is_instance_valid(hero) and hero.has_method("equip_sword"):
		hero.call("equip_sword", StringName(id))
	_remember(id)
	_message = str(strings.get("equipped", "{name} is in her hand.")).replace("{name}", str((_swords()[id] as Dictionary).get("name", id)))
	menu.audio.sfx("confirm")
	_load_rows()
	menu.refresh_info()


## Writes the pick into the slice run so a hero-less menu (and the next room) agree.
func _remember(id: String) -> void:
	var state: Node = menu.state_node()
	if state == null:
		return
	var run: Dictionary = (state.get("slice_run") as Dictionary).duplicate(true)
	var session: Dictionary = (run.get("session", {}) as Dictionary).duplicate()
	session["sword"] = id
	run["session"] = session
	state.set("slice_run", run)
