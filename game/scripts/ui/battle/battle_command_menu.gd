class_name BattleCommandMenu
extends Control
## The battle command windows: Attack / Skills / Items / Defend / Run, the Skills and Items
## submenus (Juice cost, counts, greyed rows with a reason) and the target pick. It builds the
## command dictionary the controller wants and emits `command_ready`. Cancel backs out one step.
## Cursor memory is per fighter: the main row, the skill row, the item row and the last target
## are all remembered for the whole fight.
##
## Layout comes from data/ui/battle_ui.json, strings from data/text/battle.json. Windows are the
## shared UiWindow, rows are the shared MenuList (flame cursor, tick sounds, mouse hover / click).
## The owner (BattleHud) forwards input: handle_command() for the pad / keys, handle_mouse() with
## stage-pixel positions. Tests drive it the same way.

signal command_ready(command: Dictionary)
signal state_changed(state: int)
## A disabled row was pressed; `reason_key` is a key of battle.json "reasons".
signal refused(reason_key: String)

enum State { CLOSED, MAIN, SKILLS, ITEMS, TARGET }

const ROW_ATTACK: String = "attack"
const ROW_SKILLS: String = "skills"
const ROW_ITEMS: String = "items"
const ROW_DEFEND: String = "defend"
const ROW_RUN: String = "run"
const MAIN_ROWS: PackedStringArray = ["attack", "skills", "items", "defend", "run"]
const MEMORY_MAIN: String = "main"
const MEMORY_SKILLS: String = "skills"
const MEMORY_ITEMS: String = "items"
const STATUS_NOISE_TICKET: String = "noise_ticket"

var audio: UiAudio = UiAudio.new()
## Who is on the field (set by the HUD). Needed for statuses, Juice and target lists.
var roster: BattleRoster = BattleRoster.new()
## Maps a combatant id to its screen position (the stage's screen_pos_of, or the fallback).
var pos_of: Callable = Callable()

var _state: State = State.CLOSED
var _actor: String = ""
var _options: Dictionary = {}
var _memory: Dictionary[String, Dictionary] = {}
var _targeting: BattleTargeting = BattleTargeting.new()
var _pending: Dictionary = {}
var _return_state: State = State.MAIN
var _reasons: Dictionary[String, String] = {}
var _hit_offset_y: float = 14.0
var _hit_radius: float = 20.0
var _input_map: MenuInput = MenuInput.new()

var _cmd_window: UiWindow = null
var _sub_window: UiWindow = null
var _cmd_list: MenuList = null
var _sub_list: MenuList = null
var _hint: Label = null
var _strip_h: int = 24
var _sub_full: Vector2 = Vector2.ZERO
## Keeps the command window drawn after the menu closes (while the HUD slides it away).
var ghost: bool = false:
	set(value):
		ghost = value
		_apply_visuals()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	_hit_offset_y = BattleUiData.ui_float("target.hit_offset_y", 14.0)
	_hit_radius = BattleUiData.ui_float("target.hit_radius", 20.0)
	var list_cfg: Dictionary = BattleUiData.ui("layout.list", {})
	var cmd_rect: Rect2 = BattleUiData.ui_rect("layout.command_window")
	var sub_rect: Rect2 = BattleUiData.ui_rect("layout.sub_window")
	_strip_h = BattleUiData.ui_int("layout.sub_window.strip_h", 24)
	_sub_full = sub_rect.size
	_cmd_window = _make_window("CommandWindow", cmd_rect)
	_sub_window = _make_window("SubWindow", sub_rect)
	_cmd_list = _make_list(_cmd_window, cmd_rect.size, list_cfg, MAIN_ROWS.size())
	_cmd_list.activated.connect(_on_main_activated)
	_cmd_list.cursor_moved.connect(_on_main_moved)
	_sub_list = _make_list(_sub_window, sub_rect.size, list_cfg, BattleUiData.ui_int("layout.sub_window.rows", 4))
	_sub_list.activated.connect(_on_sub_activated)
	_sub_list.cursor_moved.connect(_on_sub_moved)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiText.style_label(_hint, "tag", BattleUiData.palette("text"))
	_sub_window.add_child(_hint)
	_apply_visuals()


func _make_window(node_name: String, rect: Rect2) -> UiWindow:
	var window: UiWindow = UiWindow.new()
	window.name = node_name
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.position = rect.position
	window.size = rect.size
	add_child(window)
	return window


func _make_list(window: Control, list_size: Vector2, cfg: Dictionary, rows: int) -> MenuList:
	var list: MenuList = MenuList.new()
	list.audio = audio
	list.row_height = int(cfg.get("step", 16))
	list.first_row_y = int(cfg.get("first_y", 8))
	list.text_x = int(cfg.get("text_x", 20))
	list.cursor_x = int(cfg.get("cursor_x", 6))
	list.value_pad = int(cfg.get("value_pad", 10))
	list.visible_rows = rows
	list.size = list_size
	window.add_child(list)
	return list


# ---- opening and closing ----

## Opens the menu for `actor_id` with the options from `command_needed`.
func open(actor_id: String, options: Dictionary) -> void:
	_actor = actor_id
	_options = options
	_pending = {}
	var memory: Dictionary = _memory_for(actor_id)
	_cmd_list.set_items(_main_rows())
	_cmd_list.set_index(int(memory.get(MEMORY_MAIN, 0)), false)
	_enter(State.MAIN)


## Closes without a command (the HUD does this when a move starts).
func close() -> void:
	if _state == State.CLOSED:
		return
	_pending = {}
	_enter(State.CLOSED)


func is_open() -> bool:
	return _state != State.CLOSED


func get_state() -> State:
	return _state


func get_actor() -> String:
	return _actor


## The pointer while picking a target (State.TARGET), else an idle one.
func get_targeting() -> BattleTargeting:
	return _targeting


func get_main_list() -> MenuList:
	return _cmd_list


func get_sub_list() -> MenuList:
	return _sub_list


## The hint or reason line under the highlighted row.
func get_hint_text() -> String:
	return _hint.text


func get_remembered(actor_id: String, key: String) -> Variant:
	return _memory.get(actor_id, {}).get(key, null)


func _memory_for(actor_id: String) -> Dictionary:
	if not _memory.has(actor_id):
		_memory[actor_id] = {}
	return _memory[actor_id]


func _enter(state: State) -> void:
	_state = state
	match state:
		State.SKILLS:
			_sub_list.set_items(_skill_rows())
			_sub_list.set_index(int(_memory_for(_actor).get(MEMORY_SKILLS, 0)), false)
		State.ITEMS:
			_sub_list.set_items(_item_rows())
			_sub_list.set_index(int(_memory_for(_actor).get(MEMORY_ITEMS, 0)), false)
	_apply_visuals()
	state_changed.emit(int(state))


func _apply_visuals() -> void:
	if _cmd_window == null:
		return
	var open_now: bool = _state != State.CLOSED
	_cmd_window.visible = open_now or ghost
	_cmd_list.active = _state == State.MAIN
	var sub_open: bool = _state == State.SKILLS or _state == State.ITEMS
	_sub_list.visible = sub_open
	_sub_list.active = sub_open
	_sub_window.visible = _state == State.MAIN or sub_open
	_sub_window.size = Vector2(_sub_full.x, _sub_full.y if sub_open else float(_strip_h))
	_refresh_hint()


# ---- rows ----

func _main_rows() -> Array[Dictionary]:
	_reasons.clear()
	var rows: Array[Dictionary] = []
	var skills: Array = _options.get("skills", [])
	var items: Array = _options.get("items", [])
	var enabled: Dictionary[String, bool] = {
		ROW_ATTACK: bool(_options.get("attack", true)),
		ROW_SKILLS: not skills.is_empty(),
		ROW_ITEMS: not items.is_empty(),
		ROW_DEFEND: bool(_options.get("defend", true)),
		ROW_RUN: bool(_options.get("run", true)),
	}
	if enabled[ROW_ATTACK] == false:
		_reasons[ROW_ATTACK] = "cant_attack"
	if enabled[ROW_SKILLS] == false:
		_reasons[ROW_SKILLS] = STATUS_NOISE_TICKET if roster.has_status(_actor, STATUS_NOISE_TICKET) else "no_skills"
	if enabled[ROW_ITEMS] == false:
		_reasons[ROW_ITEMS] = "no_items"
	if enabled[ROW_RUN] == false:
		_reasons[ROW_RUN] = "cant_run"
	for id: String in MAIN_ROWS:
		rows.append({"id": id, "label": BattleUiData.text("commands.%s.label" % id), "enabled": enabled[id]})
	return rows


func _skill_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry: Variant in _options.get("skills", []):
		var skill: Dictionary = entry
		var id: String = str(skill.get("id", ""))
		var usable: bool = bool(skill.get("usable", true))
		var cost: int = int(skill.get("juice_cost", 0))
		rows.append({
			"id": id,
			"label": str(skill.get("name", BattleUiData.prettify(id))),
			"value": BattleUiData.fmt(BattleUiData.text("juice_cost"), {"cost": cost}),
			"enabled": usable,
			"target": str(skill.get("target", BattleTargeting.KIND_ONE_ENEMY)),
			"reason": "" if usable else _skill_reason(cost),
		})
	return rows


## Why a skill is greyed out: Noise Ticket beats everything, then not enough Juice.
func _skill_reason(cost: int) -> String:
	if roster.has_status(_actor, STATUS_NOISE_TICKET):
		return STATUS_NOISE_TICKET
	if int(roster.get_member(_actor).get("juice", 0)) < cost:
		return "no_juice"
	return "unusable"


func _item_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry: Variant in _options.get("items", []):
		var item: Dictionary = entry
		var id: String = str(item.get("id", ""))
		var count: int = int(item.get("count", 0))
		var usable: bool = bool(item.get("usable", true))
		rows.append({
			"id": id,
			"label": str(item.get("name", BattleUiData.prettify(id))),
			"value": BattleUiData.fmt(BattleUiData.text("item_count"), {"count": count}),
			"enabled": count > 0 and usable,
			"target": str(item.get("target", BattleTargeting.KIND_ONE_ALLY)),
			"reason": "out_of_stock" if count <= 0 else ("" if usable else "cant_run"),
		})
	return rows


func _row_data(list: MenuList) -> Dictionary:
	var items: Array[Dictionary] = list.get_items()
	var index: int = list.get_cursor_index()
	if index < 0 or index >= items.size():
		return {}
	return items[index]


func _refresh_hint() -> void:
	if _hint == null:
		return
	var text: String = ""
	var warn: bool = false
	var y: float = 5.0
	match _state:
		State.MAIN:
			var row: Dictionary = _row_data(_cmd_list)
			var id: String = str(row.get("id", ""))
			if not bool(row.get("enabled", true)) and _reasons.has(id):
				text = BattleUiData.text("reasons.%s" % _reasons[id])
				warn = true
			else:
				text = BattleUiData.text("commands.%s.hint" % id)
		State.SKILLS, State.ITEMS:
			var sub_row: Dictionary = _row_data(_sub_list)
			var reason: String = str(sub_row.get("reason", ""))
			if not reason.is_empty():
				text = BattleUiData.text("reasons.%s" % reason)
				warn = true
			y = float(BattleUiData.ui_int("layout.sub_window.reason_y", 76))
	_hint.text = text
	_hint.position = Vector2(10, y)
	_hint.add_theme_color_override("font_color", BattleUiData.palette("lamp_amber") if warn else BattleUiData.palette("text"))


func _on_main_moved(index: int) -> void:
	var items: Array[Dictionary] = _cmd_list.get_items()
	if index >= 0 and index < items.size():
		_memory_for(_actor)[MEMORY_MAIN] = index
	_refresh_hint()


func _on_sub_moved(index: int) -> void:
	var key: String = MEMORY_SKILLS if _state == State.SKILLS else MEMORY_ITEMS
	_memory_for(_actor)[key] = index
	_refresh_hint()


# ---- choosing ----

func _on_main_activated(index: int) -> void:
	var id: String = _cmd_list.get_item_id(index)
	match id:
		ROW_ATTACK:
			_begin_target({"kind": "attack"}, BattleTargeting.KIND_ONE_ENEMY, State.MAIN)
		ROW_SKILLS:
			_enter(State.SKILLS)
		ROW_ITEMS:
			_enter(State.ITEMS)
		ROW_DEFEND:
			_send({"kind": "defend"})
		ROW_RUN:
			_send({"kind": "run"})


func _on_sub_activated(index: int) -> void:
	var row: Dictionary = _sub_list.get_items()[index]
	var id: String = str(row.get("id", ""))
	var target: String = str(row.get("target", BattleTargeting.KIND_ONE_ENEMY))
	if _state == State.SKILLS:
		_begin_target({"kind": "skill", "skill_id": id}, target, State.SKILLS)
	else:
		_begin_target({"kind": "item", "item_id": id}, target, State.ITEMS)


## Starts picking targets for a half-built command. `back` is where Cancel returns to.
func _begin_target(command: Dictionary, target_kind: String, back: State) -> void:
	_pending = command
	_return_state = back
	if BattleTargeting.needs_no_pick(target_kind):
		var me: Array[String] = [_actor]
		_finish_target(me)
		return
	var remembered: String = str(_memory_for(_actor).get(_target_memory_key(target_kind), ""))
	var finder: Callable = pos_of
	if not finder.is_valid():
		finder = func(_id: String) -> Vector2: return Vector2.ZERO
	if not _targeting.start(target_kind, roster, _actor, finder, remembered):
		audio.sfx("back")
		refused.emit("no_target")
		_pending = {}
		return
	_enter(State.TARGET)


func _target_memory_key(target_kind: String) -> String:
	var k: String = BattleTargeting.normalize(target_kind)
	if k == BattleTargeting.KIND_ALL_ENEMIES or k == BattleTargeting.KIND_ONE_ENEMY:
		return "target_enemy"
	return "target_ally"


func _confirm_target() -> void:
	var picked: Array[String] = _targeting.selected_ids()
	if picked.is_empty():
		return
	audio.sfx("confirm")
	if not _targeting.is_all:
		_memory_for(_actor)[_target_memory_key(_targeting.kind)] = picked[0]
	_finish_target(picked)


func _finish_target(picked: Array[String]) -> void:
	var command: Dictionary = _pending.duplicate()
	var targets: Array = []
	for id: String in picked:
		targets.append(id)
	command["targets"] = targets
	_send(command)


func _send(command: Dictionary) -> void:
	_pending = {}
	_enter(State.CLOSED)
	command_ready.emit(command)


# ---- input (the owner forwards) ----

## One menu command: what a button press means right now.
func handle_command(command: MenuInput.Cmd) -> void:
	match _state:
		State.MAIN:
			_command_main(command)
		State.SKILLS, State.ITEMS:
			_command_sub(command)
		State.TARGET:
			_command_target(command)


func _command_main(command: MenuInput.Cmd) -> void:
	match command:
		MenuInput.Cmd.CONFIRM:
			_press_row(_cmd_list)
		_:
			_cmd_list.handle_command(command)


func _command_sub(command: MenuInput.Cmd) -> void:
	match command:
		MenuInput.Cmd.CANCEL:
			audio.sfx("back")
			_enter(State.MAIN)
		MenuInput.Cmd.CONFIRM:
			_press_row(_sub_list)
		_:
			_sub_list.handle_command(command)


func _command_target(command: MenuInput.Cmd) -> void:
	match command:
		MenuInput.Cmd.CANCEL:
			_cancel_target()
		MenuInput.Cmd.CONFIRM:
			_confirm_target()
		MenuInput.Cmd.UP:
			_hop(Vector2i(0, -1))
		MenuInput.Cmd.DOWN:
			_hop(Vector2i(0, 1))
		MenuInput.Cmd.LEFT:
			_hop(Vector2i(-1, 0))
		MenuInput.Cmd.RIGHT:
			_hop(Vector2i(1, 0))


func _hop(direction: Vector2i) -> void:
	if _targeting.move(direction):
		audio.sfx("tick")


func _cancel_target() -> void:
	audio.sfx("back")
	_pending = {}
	_enter(_return_state)


## Confirm on a row: disabled rows buzz and say why instead of acting.
func _press_row(list: MenuList) -> void:
	var row: Dictionary = _row_data(list)
	if row.is_empty():
		return
	if not bool(row.get("enabled", true)):
		audio.sfx("back")
		var reason: String = str(row.get("reason", ""))
		if reason.is_empty():
			reason = str(_reasons.get(str(row.get("id", "")), "unusable"))
		refused.emit(reason)
		return
	list.activate()


## Mouse input in stage pixels: hover moves the cursor, left click picks, right click backs out.
## Returns true when the event was used.
func handle_mouse(event: InputEvent) -> bool:
	if _state == State.CLOSED:
		return false
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			handle_command(MenuInput.Cmd.CANCEL)
			return true
	match _state:
		State.MAIN:
			return _mouse_list(_cmd_list, event)
		State.SKILLS, State.ITEMS:
			return _mouse_list(_sub_list, event)
		State.TARGET:
			return _mouse_target(event)
	return false


## A click on a disabled row says why, like the confirm button does.
func _mouse_list(list: MenuList, event: InputEvent) -> bool:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = list.get_global_transform().affine_inverse() * (event as InputEventMouseButton).position
		var hit: int = -1
		for index: int in list.get_count():
			if list.get_row_rect(index).has_point(local):
				hit = index
				break
		if hit >= 0:
			list.set_index(hit, hit != list.get_cursor_index())
			_press_row(list)
			return true
		return false
	return list.handle_mouse(event)


func _mouse_target(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		var hover: String = _target_at((event as InputEventMouseMotion).position)
		if not hover.is_empty() and not _targeting.is_all and hover != _targeting.get_selected():
			_targeting.set_selected(hover)
			audio.sfx("tick")
		return not hover.is_empty()
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var picked: String = _target_at((event as InputEventMouseButton).position)
		if picked.is_empty():
			return false
		_targeting.set_selected(picked)
		_confirm_target()
		return true
	return false


func _target_at(point: Vector2) -> String:
	return _targeting.pick_at(point - Vector2(0, _hit_offset_y), _hit_radius)
