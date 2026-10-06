class_name BattleHud
extends Control
## The battle HUD (docs/battle_api.md, "The HUD"). Binds to a BattleController (or anything that emits
## the same signals), shows the turn-order row, the party panel, the command menu with targeting,
## rating / damage / cue pop-ups, battle messages, the K.O.!, the victory screen and the game over
## screen, and answers `command_needed` with `submit_command`.
##
## Lives on the UiStage root: everything is laid out in 384x216 stage pixels (the same pixels as the
## 3D picture). Positions of fighters come from `stage.screen_pos_of(id)` (a point just above the
## fighter's head, in picture pixels); without a stage it falls back to fixed slots from battle_ui.json.
##
## Layout and timing: data/ui/battle_ui.json. Strings: data/text/battle.json.
## Input: the pad / keys come through MenuInput (confirm, cancel, move_*), the mouse through
## handle_mouse (hover moves the pointer, click picks, right click backs out). The HUD only consumes
## input while a menu or end screen is waiting for it, so the Clutch button always reaches the stage.
## Tests drive it with handle_command() / handle_mouse() and tick(); set `manual_ticks`.

## The player's command, just before it goes to the controller.
signal command_submitted(command: Dictionary)
## The final enemy went down: the K.O.! is on screen. The stage can hold the world for `freeze_s`.
signal ko_started(target_id: String, freeze_s: float)
## Game over screen: Retry was chosen (the wiring is the integrator's).
signal retry_requested
## Game over screen: Back to title was chosen.
signal title_requested
## The end screens are done and the stage can leave the battle (the stage waits for this name).
## result: "win" / "lose" / "ran"; choice: "continue" (win), "retry" / "title" (lose), "" (ran).
signal finished(result: String, choice: String)

enum Mode { IDLE, COMMAND, PLAYING, KO, VICTORY, GAME_OVER, ENDED }

const SCENE_PATH: String = "res://scenes/ui/battle/battle_hud.tscn"
const STAGE_METHOD: StringName = &"screen_pos_of"
const SUBMIT_METHOD: StringName = &"submit_command"
const SNAPSHOT_METHOD: StringName = &"snapshot"
const MAX_POPUPS: int = 24
const RESULT_WIN: String = "win"
const RESULT_LOSE: String = "lose"
const RESULT_RAN: String = "ran"
const CLUTCH_ACTION: StringName = &"clutch"

## The battle scene (anything with `screen_pos_of(id) -> Vector2`). Optional. When it has the signals
## `cue_fired` and `ko_beat_started` and the methods `set_target_highlight`, the HUD uses them too.
var stage: Object = null:
	set(value):
		_disconnect_stage()
		stage = value
		_connect_stage()
var manual_ticks: bool = false
var animations_enabled: bool = true
var audio: UiAudio = UiAudio.new()
var roster: BattleRoster = BattleRoster.new()

var _controller: Object = null
var _bindings: Array[Array] = []
var _mode: Mode = Mode.IDLE
var _input_map: MenuInput = MenuInput.new()
var _actor: String = ""
var _action: Dictionary = {}
var _press_owners: Dictionary[int, String] = {}
var _names: Dictionary = {}
var _popups: Array[BattlePopup] = []
var _timers: Array[Dictionary] = []
var _ko_shown: bool = false
var _ko_time_left: float = 0.0
var _victory_pending: bool = false
var _end_report: Dictionary = {}
var _slide: float = 0.0
var _slide_goal: float = 0.0
var _step_clock: float = 0.0
var _flash_step: int = 0
var _flash_clock: float = 0.0
var _result: String = ""
var _stage_anchors: bool = false
var _stage_bindings: Array[Array] = []

var _turn_row: BattleTurnRow = null
var _party: BattlePartyPanel = null
var _menu: BattleCommandMenu = null
var _cursor: BattleTargetCursor = null
var _banner: BattleMessageBanner = null
var _popup_layer: Control = null
var _flash: ColorRect = null
var _victory: BattleVictoryScreen = null
var _game_over: BattleGameOverScreen = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	set_process(not manual_ticks)
	_build()


func _process(delta: float) -> void:
	tick(delta)


func _exit_tree() -> void:
	unbind()
	_disconnect_stage()


func _build() -> void:
	_turn_row = BattleTurnRow.new()
	_turn_row.name = "TurnRow"
	_turn_row.roster = roster
	add_child(_turn_row)
	_party = BattlePartyPanel.new()
	_party.name = "PartyPanel"
	_party.roster = roster
	add_child(_party)
	_cursor = BattleTargetCursor.new()
	_cursor.name = "TargetCursor"
	_cursor.roster = roster
	_cursor.pos_of = position_of
	add_child(_cursor)
	_menu = BattleCommandMenu.new()
	_menu.name = "CommandMenu"
	_menu.roster = roster
	_menu.pos_of = position_of
	_menu.audio = audio
	_menu.ghost = true
	_menu.command_ready.connect(_on_command_ready)
	_menu.state_changed.connect(_on_menu_state_changed)
	_menu.refused.connect(_on_menu_refused)
	add_child(_menu)
	_menu.visible = false
	_banner = BattleMessageBanner.new()
	_banner.name = "Banner"
	add_child(_banner)
	_popup_layer = Control.new()
	_popup_layer.name = "Popups"
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.size = size
	add_child(_popup_layer)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = size
	add_child(_flash)
	_victory = BattleVictoryScreen.new()
	_victory.name = "Victory"
	_victory.roster = roster
	_victory.names = _names
	_victory.finished.connect(_on_victory_finished)
	add_child(_victory)
	_game_over = BattleGameOverScreen.new()
	_game_over.name = "GameOver"
	_game_over.audio = audio
	_game_over.choice_made.connect(_on_game_over_choice)
	add_child(_game_over)


## Builds the HUD on the UI stage (making the stage if needed) and returns it.
static func install(tree: SceneTree) -> BattleHud:
	var ui_stage: UiStage = UiStage.get_or_create(tree)
	var hud: BattleHud = (load(SCENE_PATH) as PackedScene).instantiate() as BattleHud
	ui_stage.get_stage_root().add_child(hud)
	return hud


# ---- binding ----

## Connects to a controller's signals and answers `command_needed` with `submit_command`.
## `controller` is a BattleController or anything that emits the documented signals.
func bind(controller: Object) -> void:
	unbind()
	_controller = controller
	_connect_signal("battle_started", _on_battle_started)
	_connect_signal("round_started", _on_round_started)
	_connect_signal("turn_started", _on_turn_started)
	_connect_signal("command_needed", _on_command_needed)
	_connect_signal("action_started", _on_action_started)
	_connect_signal("press_judged", _on_press_judged)
	_connect_signal("hit", _on_hit)
	_connect_signal("stats_changed", _on_stats_changed)
	_connect_signal("status_changed", _on_status_changed)
	_connect_signal("combatant_down", _on_combatant_down)
	_connect_signal("combatant_revived", _on_combatant_revived)
	_connect_signal("combatant_fled", _on_combatant_fled)
	_connect_signal("action_finished", _on_action_finished)
	_connect_signal("message", _on_message)
	_connect_signal("battle_ended", _on_battle_ended)
	add_to_group(UiStage.MODAL_GROUP)
	if controller.has_method(SNAPSHOT_METHOD):
		var snap: Variant = controller.call(SNAPSHOT_METHOD)
		if snap is Dictionary and not (snap.get("combatants", []) as Array).is_empty():
			_apply_snapshot(snap)


## Disconnects from the controller.
func unbind() -> void:
	for binding: Array in _bindings:
		var source: Object = binding[0]
		if is_instance_valid(source) and source.is_connected(binding[1], binding[2]):
			source.disconnect(binding[1], binding[2])
	_bindings.clear()
	_controller = null
	if is_in_group(UiStage.MODAL_GROUP):
		remove_from_group(UiStage.MODAL_GROUP)


func is_bound() -> bool:
	return _controller != null


func _connect_signal(signal_name: String, handler: Callable) -> void:
	if _controller == null or not _controller.has_signal(signal_name):
		push_warning("BattleHud: controller has no signal '%s'" % signal_name)
		return
	_controller.connect(signal_name, handler)
	_bindings.append([_controller, signal_name, handler])


# ---- where things are on screen ----

## The stage point for a combatant (above its head), in 384x216 picture pixels.
func position_of(id: String) -> Vector2:
	return _stage_point(id, &"head")


## `anchor` is "head", "center" or "feet" when the stage supports it (the battle scene does).
func _stage_point(id: String, anchor: StringName) -> Vector2:
	if stage != null and is_instance_valid(stage) and stage.has_method(STAGE_METHOD):
		var point: Vector2 = Vector2.ZERO
		if _stage_anchors:
			point = stage.call(STAGE_METHOD, id, anchor) as Vector2
		else:
			point = stage.call(STAGE_METHOD, id) as Vector2
			if anchor != &"head":
				point += Vector2(0, float(BattleUiData.ui_int("anchors.body_height", 22)) * (0.5 if anchor == &"center" else 1.0))
		if point != Vector2.ZERO:
			return point
	var fallback: Vector2 = _fallback_position(id)
	if anchor == &"center":
		fallback += Vector2(0, float(BattleUiData.ui_int("anchors.body_height", 22)) * 0.5)
	elif anchor == &"feet":
		fallback += Vector2(0, float(BattleUiData.ui_int("anchors.body_height", 22)))
	return fallback


func _connect_stage() -> void:
	_stage_anchors = false
	if stage == null or not is_instance_valid(stage):
		return
	if stage.has_method(STAGE_METHOD):
		for info: Dictionary in stage.get_method_list():
			if str(info["name"]) == str(STAGE_METHOD):
				_stage_anchors = (info["args"] as Array).size() >= 2
	if stage.has_signal("cue_fired"):
		stage.connect("cue_fired", _on_stage_cue_fired)
		_stage_bindings.append([stage, "cue_fired", _on_stage_cue_fired])
	if stage.has_signal("ko_beat_started"):
		stage.connect("ko_beat_started", _on_stage_ko_beat)
		_stage_bindings.append([stage, "ko_beat_started", _on_stage_ko_beat])


func _disconnect_stage() -> void:
	for binding: Array in _stage_bindings:
		var source: Object = binding[0]
		if is_instance_valid(source) and source.is_connected(binding[1], binding[2]):
			source.disconnect(binding[1], binding[2])
	_stage_bindings.clear()


## The stage fired a cue. It draws its own "!" while its `cue_marker_enabled` is on; once that is off
## the HUD draws the "!" instead (so there is never a double).
func _on_stage_cue_fired(owner_id: String, _press_index: int, _stage_pos: Vector2) -> void:
	if stage != null and bool(stage.get("cue_marker_enabled")):
		return
	var big: bool = bool(roster.get_member(owner_id).get("is_boss", false))
	show_cue(owner_id, big)


func _on_stage_ko_beat(target_id: String, _stage_pos: Vector2) -> void:
	show_ko(target_id)


## Tells the stage which fighters to light up while a target is picked.
func _update_stage_highlight() -> void:
	if stage == null or not is_instance_valid(stage) or not stage.has_method("set_target_highlight"):
		return
	var ids: PackedStringArray = PackedStringArray()
	for id: String in _cursor.get_marked_ids():
		ids.append(id)
	stage.call("set_target_highlight", ids)


func _fallback_position(id: String) -> Vector2:
	var key: String = "anchors.fallback_enemy" if roster.side_of(id) == BattleRoster.SIDE_ENEMY else "anchors.fallback_party"
	var slots: Array = BattleUiData.ui(key, [[192, 100]])
	var slot: Array = slots[clampi(roster.slot_of(id), 0, slots.size() - 1)]
	return Vector2(float(slot[0]), float(slot[1]))


func _anchor_for(id: String, anchor_key: String) -> Vector2:
	return position_of(id) + BattleUiData.ui_vec("anchors.%s" % anchor_key)


## Where number pop-ups appear: the middle of the fighter when the stage says where that is.
func _body_anchor_for(id: String, anchor_key: String) -> Vector2:
	return _stage_point(id, &"center") + BattleUiData.ui_vec("anchors.%s" % anchor_key)


# ---- signal handlers ----

func _apply_snapshot(snap: Dictionary) -> void:
	roster.load_snapshot(snap)
	_party.snap_bars()
	_turn_row.refresh()
	_party.refresh()


func _on_battle_started(snap: Dictionary) -> void:
	_ko_shown = false
	_ko_time_left = 0.0
	_victory_pending = false
	_result = ""
	_mode = Mode.IDLE
	_set_overview_visible(true)
	_apply_snapshot(snap)


func _on_round_started(_round_number: int, order: Array, next_order: Array) -> void:
	_turn_row.set_round(order, next_order)


func _on_turn_started(actor_id: String) -> void:
	_actor = actor_id
	_turn_row.set_current(actor_id)
	_party.set_active(actor_id if roster.side_of(actor_id) == BattleRoster.SIDE_PARTY else "")


func _on_command_needed(actor_id: String, options: Dictionary) -> void:
	_actor = actor_id
	_remember_names(options)
	_mode = Mode.COMMAND
	_party.set_active(actor_id)
	_menu.open(actor_id, options)
	_slide_to(1.0)
	audio.sfx_id(str(BattleUiData.ui("sfx.menu_open", "")))


func _remember_names(options: Dictionary) -> void:
	for key: String in ["skills", "items"]:
		for entry: Variant in options.get(key, []):
			var row: Dictionary = entry
			if row.has("id") and row.has("name"):
				_names[str(row["id"])] = str(row["name"])


func _on_command_ready(command: Dictionary) -> void:
	_cursor.show_for(null)
	_update_stage_highlight()
	_mode = Mode.PLAYING
	_slide_to(0.0)
	command_submitted.emit(command)
	if _controller != null:
		_controller.call(SUBMIT_METHOD, command)


func _on_menu_state_changed(state: int) -> void:
	if state == BattleCommandMenu.State.TARGET:
		# The windows slide off to the left so the fighters are in plain view while one is picked.
		_cursor.show_for(_menu.get_targeting())
		_slide_to(0.0)
	else:
		_cursor.show_for(null)
		if state != BattleCommandMenu.State.CLOSED:
			_slide_to(1.0)
	_update_stage_highlight()


func _on_menu_refused(reason_key: String) -> void:
	_banner.show_message(BattleUiData.text("reasons.%s" % reason_key))


func _on_action_started(action: Dictionary) -> void:
	_action = action
	_press_owners.clear()
	var presses: Array = action.get("presses", [])
	for i: int in presses.size():
		var press: Dictionary = presses[i]
		_press_owners[int(press.get("index", i))] = str(press.get("owner_id", ""))
	if _menu.is_open():
		_menu.close()
	_cursor.show_for(null)
	_slide_to(0.0)
	if _mode != Mode.KO and _mode != Mode.VICTORY and _mode != Mode.GAME_OVER:
		_mode = Mode.PLAYING
	if bool(action.get("show_name", false)):
		show_skill_name(str(action.get("name", "")))


func _on_action_finished(_action_info: Dictionary) -> void:
	_action = {}
	_press_owners.clear()


func _on_press_judged(info: Dictionary) -> void:
	var rating: String = str(info.get("rating", ""))
	var side: String = str(info.get("side", "attack"))
	var kind: String = str(BattleUiData.ui("ratings.from_press.%s.%s" % [side, rating], ""))
	if kind.is_empty():
		return # a miss shows nothing: missing never hurts
	var owner: String = str(info.get("owner_id", ""))
	if owner.is_empty():
		owner = _press_owners.get(int(info.get("index", 0)), "")
	if owner.is_empty():
		owner = str(info.get("actor", ""))
	_show_rating(kind, owner)


func _on_hit(info: Dictionary) -> void:
	var target: String = str(info.get("target", ""))
	var amount: int = int(info.get("amount", 0))
	var is_heal: bool = str(info.get("kind", "damage")) == "heal"
	if bool(info.get("payback", false)):
		# Over the enemy being paid back, so it never sits on top of the defender's "Perfect Block!".
		_show_rating("payback", target)
	if amount > 0:
		show_number(target, amount, is_heal)


func _on_stats_changed(id: String, hp: int, hp_max: int, juice: int, juice_max: int) -> void:
	roster.set_stats(id, hp, hp_max, juice, juice_max)
	_party.refresh()


func _on_status_changed(id: String, status_id: String, added: bool) -> void:
	roster.set_status(id, status_id, added)
	_party.refresh()


func _on_combatant_down(id: String) -> void:
	roster.set_down(id, true)
	_turn_row.refresh()
	_party.refresh()
	if roster.side_of(id) == BattleRoster.SIDE_ENEMY and roster.all_out(BattleRoster.SIDE_ENEMY):
		show_ko(id)


func _on_combatant_revived(id: String) -> void:
	roster.set_down(id, false)
	_turn_row.refresh()
	_party.refresh()


func _on_combatant_fled(id: String) -> void:
	roster.set_fled(id)
	_turn_row.refresh()
	_party.refresh()


func _on_message(text: String) -> void:
	_banner.show_message(text)


func _on_battle_ended(result: String, report: Dictionary) -> void:
	_result = result
	_end_report = report
	_menu.close()
	_cursor.show_for(null)
	_slide_to(0.0)
	_party.set_active("")
	match result:
		RESULT_WIN:
			var final_target: String = str(report.get("final_ko_target", ""))
			if not _ko_shown and not final_target.is_empty():
				show_ko(final_target)
			_victory_pending = true
			_mode = Mode.KO if _ko_time_left > 0.0 else Mode.VICTORY
			if _ko_time_left <= 0.0:
				_start_victory()
		RESULT_LOSE:
			_mode = Mode.PLAYING
			_schedule(BattleUiData.ui_float("game_over.delay_s", 0.9), _start_game_over)
		_:
			if not _banner.has_message(BattleUiData.text("messages.ran")):
				_banner.show_message(BattleUiData.text("messages.ran"))  # the controller usually says it already
			_schedule(BattleUiData.ui_float("end.ran_delay_s", 1.0), _finish_ran)


# ---- pop-ups (the stage can call these too) ----

## The Clutch "!" over a fighter's head. The stage calls this at `t0_usec + cue_ms*1000` for every
## press, with the press's `owner_id`. `big` is the boss "!!".
func show_cue(owner_id: String, big: bool = false) -> BattlePopup:
	for popup: BattlePopup in _popups:
		if popup.kind == BattlePopup.Kind.CUE and popup.get_meta("owner", "") == owner_id:
			_remove_popup(popup)
			break
	var cue: BattlePopup = BattlePopup.make_cue(big)
	cue.set_meta("owner", owner_id)
	return _spawn(cue, _anchor_for(owner_id, "cue"))


func _show_rating(kind: String, owner_id: String) -> void:
	var popup: BattlePopup = BattlePopup.make_rating(kind)
	# Keep the whole lettering on screen even over a fighter at the edge.
	var half: float = popup.measure_width() / 2.0 + 4.0
	var at: Vector2 = _anchor_for(owner_id, "rating")
	at.x = clampf(at.x, half, float(UiStage.STAGE_SIZE.x) - half)
	at.y = maxf(at.y, 30.0)
	_spawn(popup, at)
	audio.sfx_id(str(BattleUiData.ui("ratings.kinds.%s.sfx" % kind, "")))


## A damage (white) or heal (lime) number on a fighter.
func show_number(target_id: String, amount: int, is_heal: bool) -> BattlePopup:
	var at: Vector2 = _body_anchor_for(target_id, "number")
	var stack: int = 0
	for popup: BattlePopup in _popups:
		if popup.kind == BattlePopup.Kind.NUMBER and popup.position.distance_to(at) < 14.0 and popup.get_age() < 0.5:
			stack += 1
	at.y -= float(stack * BattleUiData.ui_int("numbers.stack_px", 8))
	return _spawn(BattlePopup.make_number(amount, is_heal), at)


## A skill name slamming onto the screen (signature moves; nobody says it out loud).
func show_skill_name(skill_name: String) -> BattlePopup:
	if skill_name.is_empty():
		return null
	return _spawn(BattlePopup.make_slam(skill_name), Vector2(float(UiStage.STAGE_SIZE.x) / 2.0, BattleUiData.ui_float("slam.y", 70.0)))


## The big K.O.! on the final hit, with a white flash. Safe to call twice.
func show_ko(target_id: String) -> BattlePopup:
	if _ko_shown:
		return null
	_ko_shown = true
	var at: Vector2 = Vector2(float(UiStage.STAGE_SIZE.x) / 2.0, BattleUiData.ui_float("ko.y", 96.0))
	if roster.has(target_id):
		var raw: Vector2 = _anchor_for(target_id, "ko")
		at = Vector2(clampf(raw.x, 56.0, 328.0), clampf(raw.y, 40.0, 150.0))
	var step_s: float = BattleUiData.ui_float("timing.step_s", 0.0833)
	var scales: Array = BattleUiData.ui("timing.popup.ko.in_scales", [1.0])
	_ko_time_left = float(scales.size()) * step_s + BattleUiData.ui_float("ko.hold_s", 1.0)
	_flash_step = BattleUiData.ui_int("timing.ko_flash_steps", 3)
	_flash_clock = 0.0
	_update_flash()
	audio.sfx_id(str(BattleUiData.ui("sfx.ko", "")))
	if _mode != Mode.VICTORY and _mode != Mode.GAME_OVER:
		_mode = Mode.KO
	ko_started.emit(target_id, BattleUiData.ui_float("ko.freeze_s", 0.35))
	return _spawn(BattlePopup.make_ko(), at)


func _spawn(popup: BattlePopup, at: Vector2) -> BattlePopup:
	popup.position = at
	popup.finished.connect(_on_popup_finished)
	popup.tree_exited.connect(_forget_popup.bind(popup))
	_popup_layer.add_child(popup)
	_popups.append(popup)
	if _popups.size() > MAX_POPUPS:
		_remove_popup(_popups[0])
	return popup


func _on_popup_finished(popup: BattlePopup) -> void:
	_remove_popup(popup)


func _forget_popup(popup: BattlePopup) -> void:
	_popups.erase(popup)


func _remove_popup(popup: BattlePopup) -> void:
	_popups.erase(popup)
	if is_instance_valid(popup):
		popup.queue_free()


## The pop-ups on screen now (tests).
func get_popups() -> Array[BattlePopup]:
	return _popups.duplicate()


# ---- end screens ----

## The end screens own the whole picture: the row and the panel step aside.
func _set_overview_visible(shown: bool) -> void:
	_turn_row.visible = shown
	_party.visible = shown


func _start_victory() -> void:
	_victory_pending = false
	_set_overview_visible(false)
	_mode = Mode.VICTORY
	_victory.names = _names
	_victory.show_report(_end_report)
	audio.sfx_id(str(BattleUiData.ui("sfx.victory", "")))


func _start_game_over() -> void:
	_set_overview_visible(false)
	_mode = Mode.GAME_OVER
	_game_over.show_screen()
	audio.sfx_id(str(BattleUiData.ui("sfx.game_over", "")))


func _finish_ran() -> void:
	_mode = Mode.ENDED
	_leave_modal()
	finished.emit(RESULT_RAN, "")


func _on_victory_finished() -> void:
	_mode = Mode.ENDED
	_leave_modal()
	finished.emit(RESULT_WIN, "continue")


func _on_game_over_choice(choice: String) -> void:
	_mode = Mode.ENDED
	_leave_modal()
	if choice == BattleGameOverScreen.CHOICE_RETRY:
		retry_requested.emit()
	else:
		title_requested.emit()
	finished.emit(RESULT_LOSE, choice)


func _leave_modal() -> void:
	if is_in_group(UiStage.MODAL_GROUP):
		remove_from_group(UiStage.MODAL_GROUP)


# ---- time ----

## Advances every animation by `delta` seconds (the HUD does this itself unless `manual_ticks`).
func tick(delta: float) -> void:
	_party.tick(delta)
	_cursor.tick(delta)
	_banner.tick(delta)
	_victory.tick(delta)
	_game_over.tick(delta)
	for popup: BattlePopup in _popups.duplicate():
		popup.tick(delta)
	_tick_slide(delta)
	_tick_flash(delta)
	_tick_timers(delta)
	if _ko_time_left > 0.0:
		_ko_time_left = maxf(0.0, _ko_time_left - delta)
		if _ko_time_left <= 0.0 and _victory_pending:
			_start_victory()


func _schedule(seconds: float, action: Callable) -> void:
	_timers.append({"left": seconds, "do": action})


func _tick_timers(delta: float) -> void:
	for timer: Dictionary in _timers.duplicate():
		timer["left"] = float(timer["left"]) - delta
		if float(timer["left"]) <= 0.0:
			_timers.erase(timer)
			(timer["do"] as Callable).call()


## Moves the command menu on or off screen (0 = away, 1 = in place), in a few stepped jumps.
func _slide_to(goal: float) -> void:
	_slide_goal = goal
	if goal > 0.0:
		_menu.visible = true
	if not animations_enabled:
		_slide = goal
		_apply_slide()


func _tick_slide(delta: float) -> void:
	if is_equal_approx(_slide, _slide_goal):
		return
	_step_clock += delta
	var step_s: float = BattleUiData.ui_float("timing.step_s", 0.0833)
	var steps: int = maxi(1, BattleUiData.ui_int("timing.menu_slide_steps", 3))
	while _step_clock >= step_s and not is_equal_approx(_slide, _slide_goal):
		_step_clock -= step_s
		_slide = move_toward(_slide, _slide_goal, 1.0 / float(steps))
	if is_equal_approx(_slide, _slide_goal):
		_slide = _slide_goal
	_apply_slide()


func _apply_slide() -> void:
	var away: float = BattleUiData.ui_float("timing.menu_slide_px", 320.0)
	_menu.position.x = -away * (1.0 - _slide)
	if _slide <= 0.0 and not _menu.is_open():
		_menu.visible = false


func _tick_flash(delta: float) -> void:
	if _flash_step <= 0:
		return
	_flash_clock += delta
	var step_s: float = BattleUiData.ui_float("timing.step_s", 0.0833)
	while _flash_clock >= step_s and _flash_step > 0:
		_flash_clock -= step_s
		_flash_step -= 1
	_update_flash()


func _update_flash() -> void:
	var steps: int = maxi(1, BattleUiData.ui_int("timing.ko_flash_steps", 3))
	_flash.color.a = BattleUiData.ui_float("ko.flash_alpha", 0.7) * float(_flash_step) / float(steps)


# ---- input ----

func _input(event: InputEvent) -> void:
	if _mode == Mode.VICTORY and _victory.is_showing():
		if _is_press(event) and _victory.press():
			get_viewport().set_input_as_handled()
		return
	if _mode == Mode.GAME_OVER and _game_over.is_showing():
		if _route_input(event):
			get_viewport().set_input_as_handled()
		return
	if _menu.is_open():
		if _route_input(event):
			get_viewport().set_input_as_handled()


## Confirm, cancel, Clutch or a left click: "a press" for the victory screen.
func _is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey and (event as InputEventKey).echo:
		return false
	if event.is_action_pressed(MenuInput.ACTION_CONFIRM) or event.is_action_pressed(MenuInput.ACTION_CANCEL):
		return true
	return InputMap.has_action(CLUTCH_ACTION) and event.is_action_pressed(CLUTCH_ACTION)


func _route_input(event: InputEvent) -> bool:
	if event is InputEventMouse:
		return handle_mouse(event)
	var command: MenuInput.Cmd = _input_map.classify(event)
	if command == MenuInput.Cmd.NONE:
		return false
	handle_command(command)
	return true


## One menu command, routed to whatever is waiting for input (command menu or game over).
func handle_command(command: MenuInput.Cmd) -> void:
	if _mode == Mode.GAME_OVER:
		_game_over.handle_command(command)
	elif _mode == Mode.VICTORY:
		if command == MenuInput.Cmd.CONFIRM or command == MenuInput.Cmd.CANCEL:
			_victory.press()
	elif _menu.is_open():
		_menu.handle_command(command)
		_cursor.refresh()
		_update_stage_highlight()


## Mouse input in stage pixels. Returns true when it was used.
func handle_mouse(event: InputEvent) -> bool:
	if _mode == Mode.GAME_OVER:
		return _game_over.handle_mouse(event)
	if _mode == Mode.VICTORY:
		return _is_press(event) and _victory.press()
	if _menu.is_open():
		var used: bool = _menu.handle_mouse(event)
		_cursor.refresh()
		_update_stage_highlight()
		return used
	return false


# ---- queries (tests, screenshots) ----

func get_mode() -> Mode:
	return _mode


func get_menu() -> BattleCommandMenu:
	return _menu


func get_party_panel() -> BattlePartyPanel:
	return _party


func get_turn_row() -> BattleTurnRow:
	return _turn_row


func get_banner() -> BattleMessageBanner:
	return _banner


func get_target_cursor() -> BattleTargetCursor:
	return _cursor


func get_victory_screen() -> BattleVictoryScreen:
	return _victory


func get_game_over_screen() -> BattleGameOverScreen:
	return _game_over


## 0 = the command menu is slid away, 1 = fully in.
func get_menu_slide() -> float:
	return _slide


func has_shown_ko() -> bool:
	return _ko_shown


func get_known_name(id: String) -> String:
	return str(_names.get(id, BattleUiData.name_of(id)))
