class_name TitleScreen
extends Control
## The title screen: night view of Harrow with a lamp in a window, the LIGHTS LEFT ON logo, a
## blinking PRESS START, then the menu: New Game / Continue / Config / Battle Test / Quit.
##   New Game     asks for the hero's name (NameEntry, "Red" by default), fades out and emits
##                `new_game_requested(hero_name)`.
##   Continue     greyed out until the SaveManager reports a save. Otherwise it fades out and emits
##                `continue_slot_requested(slot)` then `continue_requested`; Main then loads the newest
##                save (SaveManager.continue_game()) and routes to the saved place.
##   Config       the shared ConfigScreen (same component as the field menu's Config page).
##   Battle Test  a dev entry (data/text/title.json "dev_items") that opens an encounter picker
##                (BattleTestPicker); picking one fades out and emits `battle_test_requested(id)`.
##
## Self-contained: it draws into its own 384x216 SubViewport and shows that scaled up by whole
## numbers with nearest-neighbor filtering (the same rule as psx_screen), so it works standalone
## or inside any scene tree without the PSX screen. All strings come from data/text/title.json
## and all colors, fonts and timings from data/ui/ui_theme.json.
##
## Input (controller first): confirm / start opens the menu; move_up / move_down move the cursor;
## confirm / start picks; cancel backs out. Mouse: click anywhere to open the menu, hover moves
## the cursor, click picks, right-click backs out.
##
## The leave signals fire AFTER the fade to black has finished, so whoever listens can swap scenes
## right away on a black screen.

## New Game was picked and named. Main should connect this one.
signal new_game_requested(hero_name: String)
## Continue was picked. Main loads the newest save (SaveManager.continue_game()).
signal continue_requested
## Same moment as continue_requested, for listeners that want to know which slot is the newest
## (SaveManager.newest_slot()); emitted just before it.
signal continue_slot_requested(slot: int)
## Old name for New Game, still emitted right after new_game_requested so a Main that has not been
## updated yet keeps working. Connect new_game_requested instead and ignore this one.
signal start_demo_requested
## An encounter was picked in the Battle Test window. Fires after the fade to black, like start_demo_requested.
signal battle_test_requested(encounter_id: String)
signal menu_opened
signal menu_closed

enum State { PRESS_START, MENU, PICKER, LEAVING, NAME_ENTRY, CONFIG }

const TEXT_ID: String = "text/title"
const THEME_ID: String = "ui/ui_theme"
const ITEM_NEW_GAME: String = "new_game"
const ITEM_CONTINUE: String = "continue"
const ITEM_CONFIG: String = "config"
const ITEM_BATTLE_TEST: String = "battle_test"
const ITEM_QUIT: String = "quit"
const SAVE_MANAGER_PATH: NodePath = ^"/root/SaveManager"
const LEAVE_NEW_GAME: String = "new_game"
const LEAVE_CONTINUE: String = "continue"
const LEAVE_BATTLE: String = "battle_test"
const STICK_AXIS_VERTICAL: int = JOY_AXIS_LEFT_Y
const STICK_PRESS: float = 0.6
const STICK_RELEASE: float = 0.3
const AUDIO_NODE_PATH: NodePath = ^"/root/AudioManager"
const AUDIO_METHOD: StringName = &"play_sfx"
const LIT_BRIGHT_LEVEL: int = 2

## Replace to intercept Quit (tests do this); by default Quit calls get_tree().quit().
var quit_handler: Callable = Callable()
## Where saves are asked about (has_any_save / newest_slot). Null means the SaveManager autoload.
var save_manager: Node = null
## Settings for the embedded Config screen. Null means the Config autoload.
var config: Node = null

var _c: Dictionary[String, Color] = {}
var _theme_data: Dictionary = {}
var _layout: Dictionary = {}
var _timing: Dictionary = {}
var _sfx: Dictionary = {}
var _fonts: Dictionary[String, Font] = {}
var _font_sizes: Dictionary[String, int] = {}
var _items: Array[Dictionary] = []
var _item_labels: Array[Label] = []
var _state: State = State.PRESS_START
var _cursor_index: int = 0
var _clock: float = 0.0
var _step_clock: float = 0.0
var _step_s: float = 0.0833
var _fade_target: int = 0
var _window_target: float = 0.0
var _window_step: float = 0.25
var _stick_held: int = 0
var _scale: float = 1.0
var _stage_size: Vector2 = Vector2(384, 216)
var _min_fill: float = 0.8
var _leave_emitted: bool = false
var _glow_level: int = -1
var _cursor_placed: bool = false
var _pending_battle: String = ""
var _pending_kind: String = LEAVE_NEW_GAME
var _pending_name: String = ""
var _pending_slot: int = -1
var _picker: BattleTestPicker = null
var _picker_input: MenuInput = MenuInput.new()
var _name_entry: NameEntry = null
var _config_screen: ConfigScreen = null

@onready var _viewport: SubViewport = $PixelViewport
@onready var _display: TextureRect = $Display
@onready var _stage: Control = $PixelViewport/Stage
@onready var _backdrop: TitleBackdrop = $PixelViewport/Stage/Backdrop
@onready var _title_prefix: Label = $PixelViewport/Stage/TitlePrefix
@onready var _title_lit: Label = $PixelViewport/Stage/TitleLit
@onready var _demo_tag: ColorRect = $PixelViewport/Stage/DemoTag
@onready var _demo_label: Label = $PixelViewport/Stage/DemoTag/DemoLabel
@onready var _press_start: Label = $PixelViewport/Stage/PressStart
@onready var _credit: Label = $PixelViewport/Stage/Credit
@onready var _version: Label = $PixelViewport/Stage/Version
@onready var _window: UiWindow = $PixelViewport/Stage/MenuWindow
@onready var _cursor: MenuCursor = $PixelViewport/Stage/MenuWindow/Cursor
@onready var _fade: DitherFade = $PixelViewport/Stage/Fade


func _ready() -> void:
	_load_data()
	_apply_fonts_and_text()
	_build_menu()
	_build_picker()
	_build_name_entry()
	_build_config()
	_fade.step_count = int(_timing["fade_steps"])
	_fade.step = _fade.step_count
	_fade_target = 0
	_window.visible = false
	_window.open_amount = 0.0
	_display.texture = _viewport.get_texture()
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_apply_layout)
	_apply_layout()


func _process(delta: float) -> void:
	_clock += delta
	_step_clock += delta
	_press_start.visible = _state == State.PRESS_START and _blink_on()
	_update_title_glow()
	if _state == State.NAME_ENTRY:
		_name_entry.tick(delta)
	while _step_clock >= _step_s:
		_step_clock -= _step_s
		_advance_step()


# ---- queries (used by tests and by whoever hosts the screen) ----

func get_state() -> State:
	return _state


func is_menu_visible() -> bool:
	return _window.visible


## True once the window has finished growing open (the item names are showing).
func is_menu_ready() -> bool:
	return _state == State.MENU and _window.open_amount >= 1.0


## The Battle Test encounter picker (hidden until Battle Test is chosen).
func get_picker() -> BattleTestPicker:
	return _picker


func get_cursor_index() -> int:
	return _cursor_index


## The name entry window (hidden until New Game is chosen).
func get_name_entry() -> NameEntry:
	return _name_entry


## The embedded Config screen (hidden until Config is chosen).
func get_config_screen() -> ConfigScreen:
	return _config_screen


## True when the menu item can be picked (Continue is not while there is no save).
func is_item_enabled(item_id: String) -> bool:
	if item_id == ITEM_CONTINUE:
		return _has_save()
	return true


## The slot Continue would load (the newest save), or -1 when there is no save.
func get_continue_slot() -> int:
	if not _has_save():
		return -1
	var manager: Node = _save_node()
	if manager != null and manager.has_method("newest_slot"):
		return int(manager.call("newest_slot"))
	return -1


func get_item_enabled_flags() -> Array[bool]:
	var flags: Array[bool] = []
	for item: Dictionary in _items:
		flags.append(is_item_enabled(str(item["id"])))
	return flags


func get_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for item: Dictionary in _items:
		ids.append(str(item["id"]))
	return ids


func get_item_label_texts() -> Array[String]:
	var texts: Array[String] = []
	for label: Label in _item_labels:
		texts.append(label.text)
	return texts


func get_title_text() -> String:
	return _title_prefix.text + _title_lit.text


func get_demo_tag_text() -> String:
	return _demo_label.text


func get_press_start_text() -> String:
	return _press_start.text


func get_credit_text() -> String:
	return _credit.text


func get_version_text() -> String:
	return _version.text


func get_fade_step() -> int:
	return _fade.step


func get_fade_step_count() -> int:
	return _fade.step_count


func get_backdrop() -> TitleBackdrop:
	return _backdrop


## Pixels per internal pixel at the current window size (whole numbers when they fit).
func get_display_scale() -> float:
	return _scale


func get_display_rect() -> Rect2:
	return Rect2(_display.position, _display.size)


# ---- setup ----

func _load_data() -> void:
	_theme_data = DataDB.get_dict(THEME_ID)
	var palette: Dictionary = _theme_data["palette"]
	for key: String in palette:
		_c[key] = Color.html(str(palette[key]))
	_layout = _theme_data["title_screen"]
	_timing = _theme_data["timing"]
	_sfx = _theme_data["sfx"]
	_step_s = float(_timing["ui_step_s"])
	_window_step = 1.0 / float(int(_theme_data["window"]["open_steps"]))
	var screen: Dictionary = _theme_data["screen"]
	_stage_size = Vector2(float(screen["width"]), float(screen["height"]))
	_min_fill = float(screen["integer_scaling_min_fill"])
	var fonts: Dictionary = _theme_data["fonts"]
	for key: String in fonts:
		if fonts[key] is Dictionary:
			_fonts[key] = UiFonts.get_font(key)
			_font_sizes[key] = UiFonts.get_size(key)
	var show_dev: bool = bool(DataDB.get_dict(TEXT_ID).get("dev_items", false))
	for entry: Dictionary in DataDB.get_dict(TEXT_ID)["menu"]:
		if bool(entry.get("dev", false)) and not show_dev:
			continue
		_items.append(entry)


func _style(label: Label, font_key: String, color_key: String) -> void:
	UiText.style_label(label, font_key, _c[color_key])


func _outline(label: Label, outline_size: int, shadow_offset: int) -> void:
	label.add_theme_color_override("font_outline_color", _c["ink"])
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_shadow_color", _c["dusk"])
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", shadow_offset)
	label.add_theme_constant_override("shadow_outline_size", outline_size)


func _text_width(font_key: String, text: String) -> int:
	var font: Font = _fonts[font_key]
	return int(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_sizes[font_key]).x)


func _apply_fonts_and_text() -> void:
	var text: Dictionary = DataDB.get_dict(TEXT_ID)
	var margin: int = int(_layout["margin"])
	var stage_w: int = int(_stage_size.x)
	var stage_h: int = int(_stage_size.y)
	# Title: "LIGHTS LEFT " in chalk and the lit word ("ON") in lamp light, centered as one line.
	var full_title: String = str(text["title"])
	var lit_word: String = str(text["title_lit_word"])
	var prefix: String = full_title.trim_suffix(lit_word)
	_title_prefix.text = prefix
	_title_lit.text = lit_word
	_style(_title_prefix, "title", "chalk")
	_style(_title_lit, "title", "lamp_glow")
	var shadow: int = int(_layout["title_shadow_offset"])
	var outline: int = int(_layout["title_outline"])
	_outline(_title_prefix, outline, shadow)
	_outline(_title_lit, outline, shadow)
	var prefix_w: int = _text_width("title", prefix)
	var lit_w: int = _text_width("title", lit_word)
	var title_x: int = (stage_w - prefix_w - lit_w) / 2
	var title_y: int = int(_layout["title_y"])
	_title_prefix.position = Vector2(title_x, title_y)
	_title_lit.position = Vector2(title_x + prefix_w, title_y)
	var title_h: int = _font_sizes["title"]
	# DEMO tag under the right end of the title.
	_demo_label.text = str(text["demo_tag"])
	_style(_demo_label, "menu", "ink")
	var pad_x: int = int(_layout["demo_tag_pad_x"])
	var pad_y: int = int(_layout["demo_tag_pad_y"])
	var tag_w: int = _text_width("menu", _demo_label.text) + pad_x * 2
	var tag_h: int = _font_sizes["menu"] + pad_y * 2
	_demo_tag.color = _c["lamp_amber"]
	_demo_tag.size = Vector2(tag_w, tag_h)
	_demo_tag.position = Vector2(title_x + prefix_w + lit_w - tag_w, title_y + title_h + int(_layout["demo_tag_gap"]))
	_demo_label.position = Vector2(pad_x, pad_y)
	# Press start.
	_press_start.text = str(text["press_start"])
	_style(_press_start, "menu", "chalk")
	_press_start.position = Vector2((stage_w - _text_width("menu", _press_start.text)) / 2, int(_layout["press_start_y"]))
	# Studio credit (centered) and version (right), bottom of the screen.
	_credit.text = str(text["credit"])
	_style(_credit, "body", "slate_light")
	_credit.position = Vector2((stage_w - _text_width("body", _credit.text)) / 2, int(_layout["credit_y"]))
	_version.text = str(text["version"])
	_style(_version, "body", "text_dim")
	_version.position = Vector2(stage_w - margin - _text_width("body", _version.text), stage_h - margin - _font_sizes["body"])
	_credit.position.y = _version.position.y


func _build_menu() -> void:
	var rect: Dictionary = _layout["menu_window"]
	_window.position = Vector2(float(rect["x"]), float(rect["y"]))
	_window.size = Vector2(float(rect["w"]), float(rect["h"]))
	for i: int in _items.size():
		var label: Label = Label.new()
		label.text = str(_items[i]["label"])
		_style(label, "menu", "text")
		label.position = Vector2(float(_layout["menu_item_x"]), _item_y(i))
		_window.add_child(label)
		_item_labels.append(label)
	_cursor.position = _cursor_position(0)
	_update_item_colors()


func _build_picker() -> void:
	_picker = BattleTestPicker.new()
	_picker.name = "BattlePicker"
	_picker.picked.connect(_on_battle_picked)
	_picker.cancelled.connect(_close_picker)
	_stage.add_child(_picker)
	_stage.move_child(_picker, _fade.get_index())


func _build_name_entry() -> void:
	_name_entry = NameEntry.new()
	_name_entry.name = "NameEntry"
	_name_entry.submitted.connect(_on_name_submitted)
	_name_entry.cancelled.connect(_close_name_entry)
	_stage.add_child(_name_entry)
	_stage.move_child(_name_entry, _fade.get_index())


func _build_config() -> void:
	var rect: Dictionary = _layout["config_window"]
	_config_screen = ConfigScreen.new()
	_config_screen.name = "ConfigScreen"
	_config_screen.config = config
	_config_screen.position = Vector2(float(rect["x"]), float(rect["y"]))
	_config_screen.size = Vector2(float(rect["w"]), float(rect["h"]))
	_config_screen.closed.connect(_close_config)
	_stage.add_child(_config_screen)
	_stage.move_child(_config_screen, _fade.get_index())


func _item_y(index: int) -> float:
	return float(_layout["menu_item_first_y"]) + float(index) * float(_layout["menu_item_step"])


func _cursor_position(index: int) -> Vector2:
	var label_mid: float = _item_y(index) + float(_font_sizes["menu"]) / 2.0 + 3.0
	return Vector2(float(_layout["cursor_x"]), label_mid - _cursor.size.y / 2.0)


## The clickable rectangle of an item in stage (384x216) coordinates.
func _item_rect(index: int) -> Rect2:
	var margin: float = float(_layout["margin"])
	var top: float = _item_y(index) - (float(_layout["menu_item_step"]) - float(_font_sizes["menu"])) / 2.0
	return Rect2(_window.position + Vector2(margin, top), Vector2(_window.size.x - margin * 2.0, float(_layout["menu_item_step"])))


func _apply_layout() -> void:
	var fit: float = minf(size.x / _stage_size.x, size.y / _stage_size.y)
	var whole: float = floorf(fit)
	_scale = fit
	if whole >= 1.0 and whole / fit >= _min_fill:
		_scale = whole
	_display.size = (_stage_size * _scale).round()
	_display.position = ((size - _display.size) / 2.0).round()


# ---- animation ----

func _blink_on() -> bool:
	return int(_clock / float(_timing["press_start_blink_s"])) % 2 == 0


## The lit word follows the lamp: bright and golden when the lamp is up, warmer and dimmer when it dips.
func _update_title_glow() -> void:
	var level: int = _backdrop.lamp_level
	if level == _glow_level:
		return
	_glow_level = level
	var bright: bool = level >= LIT_BRIGHT_LEVEL
	_title_lit.add_theme_color_override("font_color", _c["lamp_glow"] if bright else _c["lamp_amber"])


func _advance_step() -> void:
	if _fade.step < _fade_target:
		_fade.step += 1
	elif _fade.step > _fade_target:
		_fade.step -= 1
	if _state == State.LEAVING and _fade.step >= _fade.step_count and not _leave_emitted:
		_leave_emitted = true
		match _pending_kind:
			LEAVE_BATTLE:
				battle_test_requested.emit(_pending_battle)
			LEAVE_CONTINUE:
				continue_slot_requested.emit(_pending_slot)
				continue_requested.emit()
			_:
				new_game_requested.emit(_pending_name)
				start_demo_requested.emit()
	if _window.open_amount < _window_target:
		_window.open_amount = minf(_window_target, _window.open_amount + _window_step)
	elif _window.open_amount > _window_target:
		_window.open_amount = maxf(_window_target, _window.open_amount - _window_step)
		if _window.open_amount <= 0.0:
			_window.visible = false
	var ready_for_text: bool = _window.open_amount >= 1.0
	for label: Label in _item_labels:
		label.visible = ready_for_text
	_cursor.visible = ready_for_text


# ---- input ----

func _input(event: InputEvent) -> void:
	if _state == State.LEAVING:
		return
	if _state == State.PICKER:
		_input_picker(event)
		return
	if _state == State.NAME_ENTRY or _state == State.CONFIG:
		_input_sub_page(event)
		return
	if event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventJoypadMotion:
		_on_joy_motion(event as InputEventJoypadMotion)
	elif _state == State.PRESS_START:
		if _is_pressed(event, &"confirm") or _is_pressed(event, &"start"):
			_consume()
			open_menu()
	elif _state == State.MENU:
		if _is_pressed(event, &"move_up", true):
			_consume()
			move_cursor(-1)
		elif _is_pressed(event, &"move_down", true):
			_consume()
			move_cursor(1)
		elif _is_pressed(event, &"confirm") or _is_pressed(event, &"start"):
			_consume()
			choose(_cursor_index)
		elif _is_pressed(event, &"cancel"):
			_consume()
			close_menu()


func _input_picker(event: InputEvent) -> void:
	if event is InputEventMouse:
		var copy: InputEvent = event.duplicate() as InputEvent
		(copy as InputEventMouse).position = _stage_position((event as InputEventMouse).position)
		if _picker.handle_mouse(copy):
			_consume()
		return
	var command: MenuInput.Cmd = _picker_input.classify(event)
	if command != MenuInput.Cmd.NONE:
		_consume()
		_picker.handle_command(command)


## The name entry and the Config screen take every event; mouse positions go in as stage pixels.
func _input_sub_page(event: InputEvent) -> void:
	var forwarded: InputEvent = event
	if event is InputEventMouse:
		forwarded = event.duplicate() as InputEvent
		(forwarded as InputEventMouse).position = _stage_position((event as InputEventMouse).position)
	var used: bool = false
	if _state == State.NAME_ENTRY:
		used = _name_entry.handle_event(forwarded)
	else:
		used = _config_screen.handle_event(forwarded)
	if used:
		_consume()


func _is_pressed(event: InputEvent, action: StringName, allow_echo: bool = false) -> bool:
	return event.is_action_pressed(action, allow_echo)


func _consume() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _on_joy_motion(event: InputEventJoypadMotion) -> void:
	if event.axis != STICK_AXIS_VERTICAL or _state != State.MENU:
		return
	var value: float = event.axis_value
	if absf(value) < STICK_RELEASE:
		_stick_held = 0
		return
	var direction: int = int(signf(value)) if absf(value) >= STICK_PRESS else 0
	if direction != 0 and direction != _stick_held:
		_stick_held = direction
		move_cursor(direction)


func _stage_position(window_position: Vector2) -> Vector2:
	var local: Vector2 = get_global_transform().affine_inverse() * window_position
	return (local - _display.position) / _scale


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if _state != State.MENU:
		return
	var hit: int = _item_at(_stage_position(event.position))
	if hit >= 0 and hit != _cursor_index:
		set_cursor(hit)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if _state == State.PRESS_START:
			_consume()
			open_menu()
		elif _state == State.MENU:
			var hit: int = _item_at(_stage_position(event.position))
			if hit >= 0 and is_menu_ready():
				_consume()
				set_cursor(hit, false)
				choose(hit)
	elif event.button_index == MOUSE_BUTTON_RIGHT and _state == State.MENU:
		_consume()
		close_menu()


func _item_at(stage_point: Vector2) -> int:
	if not is_menu_ready():
		return -1
	for i: int in _items.size():
		if _item_rect(i).has_point(stage_point):
			return i
	return -1


# ---- actions ----

func open_menu() -> void:
	if _state != State.PRESS_START:
		return
	_state = State.MENU
	_window.visible = true
	_window_target = 1.0
	_press_start.visible = false
	if not _cursor_placed:
		_cursor_placed = true
		set_cursor(_default_cursor_index(), false)
	_refresh_item_states()
	_cursor.restart()
	_play_sfx("confirm")
	menu_opened.emit()


## The row the cursor starts on: Continue when there is a save to continue, else New Game.
func _default_cursor_index() -> int:
	if _has_save():
		for i: int in _items.size():
			if str(_items[i]["id"]) == ITEM_CONTINUE:
				return i
	return 0


func close_menu() -> void:
	if _state != State.MENU:
		return
	_state = State.PRESS_START
	_window_target = 0.0
	for label: Label in _item_labels:
		label.visible = false
	_cursor.visible = false
	_play_sfx("back")
	menu_closed.emit()


## Moves the cursor up or down one row, wrapping around the ends.
func move_cursor(direction: int) -> void:
	if _items.is_empty():
		return
	set_cursor(posmod(_cursor_index + direction, _items.size()))


func set_cursor(index: int, with_sound: bool = true) -> void:
	if index < 0 or index >= _items.size():
		return
	var changed: bool = index != _cursor_index
	_cursor_index = index
	_cursor.position = _cursor_position(index)
	_cursor.restart()
	_update_item_colors()
	if changed and with_sound:
		_play_sfx("tick")


func _update_item_colors() -> void:
	for i: int in _item_labels.size():
		var key: String = "text_highlight" if i == _cursor_index else "text"
		if not is_item_enabled(str(_items[i]["id"])):
			key = "text_dim"
		_item_labels[i].add_theme_color_override("font_color", _c[key])


## Picks a menu item by index (the same thing a confirm press or a click does).
func choose(index: int) -> void:
	if _state != State.MENU or index < 0 or index >= _items.size():
		return
	var id: String = str(_items[index]["id"])
	if not is_item_enabled(id):
		_play_sfx("back")
		return
	_play_sfx("confirm")
	match id:
		ITEM_NEW_GAME:
			_open_name_entry()
		ITEM_CONTINUE:
			_pending_kind = LEAVE_CONTINUE
			_pending_slot = get_continue_slot()
			_start_leaving()
		ITEM_CONFIG:
			_open_config()
		ITEM_BATTLE_TEST:
			_open_picker()
		ITEM_QUIT:
			if quit_handler.is_valid():
				quit_handler.call()
			else:
				get_tree().quit()


func _start_leaving() -> void:
	_state = State.LEAVING
	_fade_target = _fade.step_count


func _hide_menu() -> void:
	_window_target = 0.0
	for label: Label in _item_labels:
		label.visible = false
	_cursor.visible = false


func _show_menu() -> void:
	_state = State.MENU
	_window.visible = true
	_window_target = 1.0
	_cursor.restart()
	_refresh_item_states()


func _open_name_entry() -> void:
	_state = State.NAME_ENTRY
	_hide_menu()
	_name_entry.open()


func _close_name_entry() -> void:
	if _state != State.NAME_ENTRY:
		return
	_name_entry.close()
	_show_menu()


func _on_name_submitted(hero_name: String) -> void:
	if _state != State.NAME_ENTRY:
		return
	_name_entry.close()
	_pending_kind = LEAVE_NEW_GAME
	_pending_name = hero_name
	_start_leaving()


func _open_config() -> void:
	_state = State.CONFIG
	_hide_menu()
	_config_screen.open()


func _close_config() -> void:
	if _state != State.CONFIG:
		return
	_show_menu()


## Re-reads whether a save exists (Continue's grey) and repaints the labels.
func _refresh_item_states() -> void:
	_update_item_colors()


func _save_node() -> Node:
	if save_manager != null and is_instance_valid(save_manager):
		return save_manager
	return get_node_or_null(SAVE_MANAGER_PATH)


func _has_save() -> bool:
	var manager: Node = _save_node()
	return manager != null and manager.has_method("has_any_save") and bool(manager.call("has_any_save"))


func _open_picker() -> void:
	_state = State.PICKER
	_window_target = 0.0
	for label: Label in _item_labels:
		label.visible = false
	_cursor.visible = false
	_picker.open()


func _close_picker() -> void:
	if _state != State.PICKER:
		return
	_picker.close()
	_state = State.MENU
	_window.visible = true
	_window_target = 1.0
	_cursor.restart()
	_play_sfx("back")


func _on_battle_picked(encounter_id: String) -> void:
	if _state != State.PICKER:
		return
	_pending_battle = encounter_id
	_pending_kind = LEAVE_BATTLE
	_start_leaving()


## Menu tick hook. AudioManager is still a stub, so this only calls it when it can answer.
func _play_sfx(key: String) -> void:
	var audio: Node = get_node_or_null(AUDIO_NODE_PATH)
	if audio != null and audio.has_method(AUDIO_METHOD):
		audio.call(AUDIO_METHOD, StringName(str(_sfx[key])))
