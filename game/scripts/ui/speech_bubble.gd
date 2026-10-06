class_name SpeechBubble
extends Control
## One comic-style speech bubble (our own look, FF9-inspired): a chalk bubble with a chunky ink
## outline and a tail that points at the speaker's head. Text types out letter by letter, a
## blinking arrow shows when the page is done, confirm skips the typing or turns the page.
## Red (silent) gets a gesture icon instead of text. Choices (yes / no) are listed inside the
## bubble. Speakers who have no body in the room (narrator, signs) get a plain window-style box
## at the bottom of the screen instead (style "box"), with the same typing and choice behavior.
##
## Lives on the UiStage root (384x216 coordinates). Sizes, colors, speeds and speakers come from
## data/ui/dialogue_ui.json and data/ui/ui_theme.json; the typing speed comes from Config.
##
## Placement: each frame the speaker's head point is projected through the world camera into stage
## pixels (BubblePlacement), the bubble is put above it, clamped to the screen, and flipped below
## with the tail pointing up when there is no room above.
##
## Driving it: call setup_text() / setup_gesture() once, after adding it to the stage. It runs
## itself in _process and reads input when `active`; tests set `manual_ticks` and call tick().

signal opened
signal char_typed(speaker_id: String, character: String)
signal page_typed
signal advanced
signal choice_made(index: int)
signal closed

enum Kind { TEXT, GESTURE }
enum State { IDLE, OPENING, TYPING, WAITING, CHOOSING, HOLDING, CLOSING, CLOSED }

const THEME_ID: String = "ui/ui_theme"
const UI_ID: String = "ui/dialogue_ui"
const STYLE_BUBBLE: String = "bubble"
const STYLE_BOX: String = "box"
const CONFIG_PATH: NodePath = ^"/root/Config"

## Only the active bubble reads input (the runner switches this).
var active: bool = true
## Off: the bubble never reads input (the runner or a test calls confirm() itself).
var listen_input: bool = true
## On: the bubble does not run itself; the owner calls tick(delta). Used by tests.
var manual_ticks: bool = false
## Overrides Config's typing speed (characters per second) when above zero.
var chars_per_second_override: float = 0.0
## Audio hook (tests replace its target).
var audio: UiAudio = UiAudio.new()
## The world camera used to project the speaker's head. Falls back to the target's current camera.
var camera: Camera3D = null

var speaker_id: String = ""
var _kind: Kind = Kind.TEXT
var _style: String = STYLE_BUBBLE
var _state: State = State.IDLE
var _target: Node3D = null
var _head_height: float = 1.0
var _anchor_point: Vector2 = Vector2.ZERO
var _has_anchor_point: bool = false

var _ui: Dictionary = {}
var _cfg: Dictionary = {}
var _palette: Dictionary[String, Color] = {}
var _font_key: String = "dialogue"
var _font_body: Font = null
var _font_body_size: int = 12
var _font_tag: Font = null
var _font_tag_size: int = 8
var _step_s: float = 0.0833
var _speaker: Dictionary = {}
var _accent: Color = Color.WHITE
var _name_text: String = ""
var _show_tag: bool = false

var _pages: PackedStringArray = PackedStringArray()
var _page_index: int = 0
var _typer: TypeWriter = TypeWriter.new()
var _text_size: Vector2i = Vector2i.ZERO
var _rows: int = 1
var _choices: Array[Dictionary] = []
var _choice_index: int = 0
var _gesture_id: String = ""
var _gesture_frames: Array[ImageTexture] = []
var _gesture_hold_left: float = 0.0

var _body_size: Vector2i = Vector2i(40, 24)
var _placement: BubblePlacement.Result = null
var _body_local: Rect2i = Rect2i()
var _tail_local_x: int = 0
var _flipped: bool = false
var _pop_steps: Array[float] = []
var _pop_index: int = 0
var _pop_scale: float = 1.0
var _step_clock: float = 0.0
var _anim_clock: float = 0.0
var _created_frame: int = -1
var _input_map: MenuInput = MenuInput.new()

var _label: Label = null
var _overlay: Control = null
var _window: UiWindow = null


func _ready() -> void:
	_created_frame = Engine.get_process_frames()
	_ui = DataDB.get_dict(UI_ID)
	var theme_data: Dictionary = DataDB.get_dict(THEME_ID)
	var palette: Dictionary = theme_data["palette"]
	for key: String in palette:
		_palette[key] = Color.html(str(palette[key]))
	_step_s = float(theme_data["timing"]["ui_step_s"])
	_font_key = str(_ui["bubble"]["font"])
	_font_body = UiFonts.get_font(_font_key)
	_font_body_size = UiFonts.get_size(_font_key)
	_font_tag = UiFonts.get_font("tag")
	_font_tag_size = UiFonts.get_size("tag")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "Text"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiText.style_label(_label, _font_key, _palette["ink"], true)
	_label.visible = false
	add_child(_label)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	set_process(not manual_ticks)


# ---- setup ----

## Follow a 3D node. `head_height` is how far above its origin the head point is (-1 = use the
## speaker's value from data, or the node's own get_head_point() if it has one).
func set_target(node: Node3D, head_height: float = -1.0) -> void:
	_target = node
	if head_height >= 0.0:
		_head_height = head_height


func set_camera(cam: Camera3D) -> void:
	camera = cam


## Point at a fixed spot in stage pixels instead of a 3D node (debug scenes, tests).
func set_anchor_point(point: Vector2) -> void:
	_anchor_point = point
	_has_anchor_point = true


## A text bubble. `choices` are option labels; a label like "Thumbs-up: Grand tour" shows Red's
## gesture icon in front of "Grand tour".
func setup_text(speaker: String, text: String, choices: Array = [], style: String = "") -> void:
	_begin(speaker, Kind.TEXT, style)
	_choices.clear()
	for entry: Variant in choices:
		var parts: Dictionary = GestureIcons.split_choice(str(entry))
		var option: Dictionary = {"label": str(parts["label"]), "gesture": str(parts["gesture"]), "text": str(entry)}
		_choices.append(option)
	_layout_text(text)
	_start_open()


## Red's gesture pop-up (or any speaker's). Holds for gesture.hold_s, then reports `advanced`.
func setup_gesture(speaker: String, gesture: String) -> void:
	_begin(speaker, Kind.GESTURE, STYLE_BUBBLE)
	_gesture_id = GestureIcons.resolve_or_fallback(gesture)
	_gesture_frames = GestureIcons.get_frames(_gesture_id)
	_cfg = _ui["gesture"]
	_body_size = Vector2i(int(_cfg["bubble_w"]), int(_cfg["bubble_h"]))
	_gesture_hold_left = float(_cfg["hold_s"])
	_show_tag = false
	_start_open()


func _begin(speaker: String, kind: Kind, style: String) -> void:
	speaker_id = speaker
	_kind = kind
	_speaker = _speaker_data(speaker)
	_style = style if not style.is_empty() else str(_speaker.get("style", STYLE_BUBBLE))
	_cfg = _ui["bubble"] if _style == STYLE_BUBBLE else _ui["box"]
	_accent = _color(str(_speaker.get("accent", "chalk")))
	_name_text = str(_speaker.get("name", speaker.capitalize()))
	_show_tag = not _name_text.is_empty() and (bool(_ui["bubble"]["show_name_tag"]) or _style == STYLE_BOX)
	if _head_height == 1.0 or _head_height < 0.0:
		_head_height = float(_speaker.get("head_height", 1.0))
	if _window != null:
		_window.queue_free()
		_window = null
	_pop_steps.clear()
	if _style == STYLE_BOX and _kind == Kind.TEXT:
		var steps: int = int(DataDB.get_value(THEME_ID, "window.open_steps", 4))
		for i: int in steps:
			_pop_steps.append(float(i + 1) / float(steps))
	else:
		for scale: Variant in _ui["bubble"]["pop_scales"]:
			_pop_steps.append(float(scale))


func _speaker_data(id: String) -> Dictionary:
	var merged: Dictionary = (_ui["default_speaker"] as Dictionary).duplicate()
	var known: Dictionary = _ui["speakers"]
	if known.has(id):
		merged.merge(known[id], true)
	elif not id.is_empty():
		merged["name"] = id.capitalize()
	return merged


func _color(value: String) -> Color:
	if value.begins_with("#"):
		return Color.html(value)
	return _palette.get(value, Color.WHITE)


# ---- layout ----

func _layout_text(text: String) -> void:
	var is_box: bool = _style == STYLE_BOX
	var max_width: int = int(_ui["bubble"]["max_text_width"])
	var max_lines: int = int(_cfg["max_lines"])
	if is_box:
		max_width = int(_cfg["w"]) - int(_cfg["text_x"]) * 2
	var lines: PackedStringArray = TextWrap.wrap(_font_body, _font_body_size, text, max_width)
	_pages = TextWrap.paginate(lines, max_lines)
	_page_index = 0
	var widest: int = 0
	_rows = 1
	for page: String in _pages:
		var page_lines: PackedStringArray = page.split("\n")
		_rows = maxi(_rows, page_lines.size())
		for line: String in page_lines:
			widest = maxi(widest, TextWrap.text_width(_font_body, _font_body_size, line))
	_text_size = Vector2i(maxi(widest, int(_ui["bubble"]["min_text_width"])), _rows * int(_cfg["line_height"]))
	_compute_body(false)
	_label.text = ""
	_label.add_theme_color_override("font_color", _color(str(_ui["bubble"]["colors"]["text"])) if not is_box else _palette["text"])
	UiText.apply_shadow(_label, not is_box)
	_label.add_theme_constant_override("line_spacing", int(_cfg["line_height"]) - int(_font_body.get_height(_font_body_size)))


## Works out the body size from the text, the choices (when shown) and the name tag.
func _compute_body(with_choices: bool) -> void:
	var bub: Dictionary = _ui["bubble"]
	if _style == STYLE_BOX:
		var height: int = int(_cfg["h"])
		if with_choices:
			height += _choices.size() * int(_cfg["choice_row_height"])
		_body_size = Vector2i(int(_cfg["w"]), height)
		return
	var pad_x: int = int(bub["pad_x"])
	var width: int = _text_size.x
	var height: int = int(bub["pad_top"]) + _text_size.y + int(bub["pad_bottom"])
	if with_choices and not _choices.is_empty():
		for option: Dictionary in _choices:
			width = maxi(width, _choice_width(option))
		height += int(bub["choice_gap"]) + _choices.size() * int(bub["choice_row_height"]) - int(bub["pad_bottom"]) + 4
	var min_width: int = _text_size.x + pad_x * 2
	if _show_tag:
		var tag_width: int = _tag_width()
		min_width = maxi(min_width, int(bub["tag_x"]) + tag_width + int(bub["tag_x"]))
	_body_size = Vector2i(maxi(width + pad_x * 2, min_width), height)


func _choice_width(option: Dictionary) -> int:
	var bub: Dictionary = _ui["bubble"]
	var width: int = TextWrap.text_width(_font_body, _font_body_size, str(option["label"])) + int(bub["choice_indent"]) + 6
	if not str(option["gesture"]).is_empty():
		width += GestureIcons.get_icon_size() + 2
	return width


func _tag_width() -> int:
	var bub: Dictionary = _ui["bubble"]
	return int(_font_tag.get_string_size(_name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_tag_size).x) + int(bub["tag_pad_x"]) * 2


# ---- states ----

func _start_open() -> void:
	_state = State.OPENING
	_pop_index = 0
	_step_clock = 0.0
	_anim_clock = 0.0
	_apply_pop()
	_update_placement()
	_label.visible = false
	add_to_group(UiStage.MODAL_GROUP)
	audio.sfx_id(str(_ui["sfx"]["open"]))


func _apply_pop() -> void:
	_pop_scale = _pop_steps[mini(_pop_index, _pop_steps.size() - 1)] if not _pop_steps.is_empty() else 1.0
	if _window != null:
		_window.open_amount = _pop_scale
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()


func _finish_opening() -> void:
	_pop_index = _pop_steps.size()
	_pop_scale = 1.0
	if _window != null:
		_window.open_amount = 1.0
	if _kind == Kind.GESTURE:
		_state = State.HOLDING
		var sfx: String = GestureIcons.sfx_for(_gesture_id)
		audio.sfx_id(sfx)
	else:
		_state = State.TYPING
		_start_page()
	opened.emit()
	queue_redraw()
	_overlay.queue_redraw()


func _start_page() -> void:
	_state = State.TYPING
	_label.visible = true
	_label.text = ""
	_typer.start(_pages[_page_index], _typing_speed(), _ui["typing"]["pauses"])
	_position_text()


func _typing_speed() -> float:
	if chars_per_second_override > 0.0:
		return chars_per_second_override
	var config: Node = get_node_or_null(CONFIG_PATH)
	if config != null and config.has_method("get_text_cps"):
		return float(config.call("get_text_cps"))
	var typing: Dictionary = _ui["typing"]
	return float(typing["speeds"][typing["default_speed"]])


func _on_page_typed() -> void:
	page_typed.emit()
	if _page_index + 1 < _pages.size():
		_state = State.WAITING
	elif not _choices.is_empty():
		_enter_choosing()
	else:
		_state = State.WAITING
	_overlay.queue_redraw()


func _enter_choosing() -> void:
	_state = State.CHOOSING
	_choice_index = clampi(_choice_index, 0, _choices.size() - 1)
	_compute_body(true)
	_update_placement()
	queue_redraw()
	_overlay.queue_redraw()


## Starts the pop-out; the node frees itself afterwards and emits `closed`.
func close() -> void:
	if _state == State.CLOSING or _state == State.CLOSED:
		return
	_state = State.CLOSING
	_label.visible = false
	_pop_scale = float(_ui["bubble"]["close_scales"][0]) if _style == STYLE_BUBBLE else 0.5
	_step_clock = 0.0
	if _window != null:
		_window.open_amount = _pop_scale
	queue_redraw()
	_overlay.queue_redraw()


func _finish_close() -> void:
	_state = State.CLOSED
	remove_from_group(UiStage.MODAL_GROUP)
	closed.emit()
	queue_free()


# ---- time ----

func _process(delta: float) -> void:
	tick(delta)


## Advances animation, typing and placement by `delta` seconds.
func tick(delta: float) -> void:
	if _state == State.IDLE or _state == State.CLOSED:
		return
	_anim_clock += delta
	match _state:
		State.OPENING:
			_step_clock += delta
			while _step_clock >= _step_s and _state == State.OPENING:
				_step_clock -= _step_s
				_pop_index += 1
				if _pop_index >= _pop_steps.size():
					_finish_opening()
				else:
					_apply_pop()
		State.TYPING:
			var revealed: String = _typer.advance(delta)
			if not revealed.is_empty():
				_label.text = _typer.get_visible_text()
				for character: String in revealed:
					if character != "\n":
						char_typed.emit(speaker_id, character)
			if _typer.is_done():
				_on_page_typed()
		State.HOLDING:
			_gesture_hold_left -= delta
			if _gesture_hold_left <= 0.0:
				_gesture_hold_left = INF
				advanced.emit()
		State.CLOSING:
			_step_clock += delta
			if _step_clock >= _step_s:
				_finish_close()
				return
	_update_placement()
	if _overlay != null and (_state == State.WAITING or _state == State.CHOOSING or _kind == Kind.GESTURE):
		_overlay.queue_redraw()
	if _kind == Kind.GESTURE:
		queue_redraw()


# ---- input ----

func _input(event: InputEvent) -> void:
	if not (listen_input and active) or _state == State.IDLE or _state == State.CLOSING or _state == State.CLOSED:
		return
	if Engine.get_process_frames() == _created_frame:
		return
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			var hit: int = _choice_at(_to_local(click.position))
			if _state == State.CHOOSING and hit >= 0:
				_set_choice(hit, false)
				choose(hit)
			else:
				confirm()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		if _state == State.CHOOSING:
			var hover: int = _choice_at(_to_local((event as InputEventMouseMotion).position))
			if hover >= 0:
				_set_choice(hover)
		return
	var command: MenuInput.Cmd = _input_map.classify(event)
	match command:
		MenuInput.Cmd.CONFIRM:
			confirm()
			get_viewport().set_input_as_handled()
		MenuInput.Cmd.UP, MenuInput.Cmd.LEFT:
			if _state == State.CHOOSING:
				move_choice(-1)
				get_viewport().set_input_as_handled()
		MenuInput.Cmd.DOWN, MenuInput.Cmd.RIGHT:
			if _state == State.CHOOSING:
				move_choice(1)
				get_viewport().set_input_as_handled()


func _to_local(stage_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * stage_point


## The confirm button: skip the typing, turn the page, pick the highlighted choice, or end a gesture.
func confirm() -> void:
	match _state:
		State.OPENING:
			_finish_opening()
		State.TYPING:
			skip_typing()
		State.WAITING:
			if _page_index + 1 < _pages.size():
				_page_index += 1
				audio.sfx_id(str(_ui["sfx"]["next"]))
				_start_page()
			else:
				audio.sfx_id(str(_ui["sfx"]["next"]))
				advanced.emit()
		State.CHOOSING:
			choose(_choice_index)
		State.HOLDING:
			_gesture_hold_left = INF
			advanced.emit()


## Shows the rest of the page right now (no voice for the skipped letters).
func skip_typing() -> void:
	if _state != State.TYPING:
		return
	_typer.finish()
	_label.text = _typer.get_visible_text()
	_on_page_typed()


func move_choice(direction: int) -> void:
	if _choices.is_empty():
		return
	_set_choice(posmod(_choice_index + direction, _choices.size()))


func _set_choice(index: int, with_sound: bool = true) -> void:
	if index == _choice_index or index < 0 or index >= _choices.size():
		return
	_choice_index = index
	if with_sound:
		audio.sfx_id(str(_ui["sfx"]["choice"]))
	_overlay.queue_redraw()


## Picks a choice (the same thing confirm does on the highlighted one).
func choose(index: int) -> void:
	if _state != State.CHOOSING or index < 0 or index >= _choices.size():
		return
	_choice_index = index
	audio.sfx_id(str(_ui["sfx"]["pick"]))
	choice_made.emit(index)


func _choice_at(local: Vector2) -> int:
	if _state != State.CHOOSING:
		return -1
	for i: int in _choices.size():
		if Rect2(_choice_row(i)).has_point(local):
			return i
	return -1


# ---- placement ----

func _anchor_on_stage() -> Vector2:
	var stage_size: Vector2 = Vector2(UiStage.STAGE_SIZE)
	if _target != null and is_instance_valid(_target) and _target.is_inside_tree():
		var cam: Camera3D = camera if camera != null else _target.get_viewport().get_camera_3d()
		if cam != null:
			var head: Vector3 = _target.global_position + Vector3.UP * _head_height
			if _target.has_method("get_head_point"):
				head = _target.call("get_head_point")
			if not BubblePlacement.is_behind(cam, head):
				return BubblePlacement.project_to_stage(cam, head, stage_size)
	if _has_anchor_point:
		return _anchor_point
	return Vector2(stage_size.x / 2.0, stage_size.y * 0.55)


func _update_placement() -> void:
	if _style == STYLE_BOX and _kind == Kind.TEXT:
		_place_box()
		return
	var bub: Dictionary = _ui["bubble"]
	var margin: float = float(bub["screen_margin"])
	var bounds: Rect2 = Rect2(Vector2(margin, margin), Vector2(UiStage.STAGE_SIZE) - Vector2(margin, margin) * 2.0)
	if _show_tag:
		bounds.position.y += float(bub["tag_overhang"])
		bounds.size.y -= float(bub["tag_overhang"])
	var corner_border: float = float(bub["tail_inset"])
	var result: BubblePlacement.Result = BubblePlacement.place(
		_anchor_on_stage(), Vector2(_body_size), bounds,
		float(bub["tail_height"]), float(bub["tail_gap"]), float(bub["flip_gap"]), corner_border)
	var previous_tail: int = _tail_local_x
	var previous_flip: bool = _flipped
	_placement = result
	_flipped = result.flipped
	var tail_h: int = int(bub["tail_height"])
	position = Vector2(result.rect.position.x, result.rect.position.y - (tail_h if _flipped else 0))
	size = Vector2(_body_size.x + 1, _body_size.y + tail_h + 1)
	_body_local = Rect2i(0, tail_h if _flipped else 0, _body_size.x, _body_size.y)
	_tail_local_x = int(round(result.tail_x - result.rect.position.x))
	if _tail_local_x != previous_tail or _flipped != previous_flip:
		queue_redraw()
		if _overlay != null:
			_overlay.queue_redraw()
	_position_text()


func _place_box() -> void:
	_placement = null
	_flipped = false
	var base_h: int = int(_cfg["h"])
	var top: int = int(_cfg["y"]) - (_body_size.y - base_h)
	position = Vector2(int(_cfg["x"]), top)
	size = Vector2(_body_size)
	_body_local = Rect2i(0, 0, _body_size.x, _body_size.y)
	if _window == null and _kind == Kind.TEXT:
		_window = UiWindow.new()
		_window.name = "Window"
		_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_window)
		move_child(_window, 0)
		_window.open_amount = _pop_scale
	if _window != null:
		_window.size = Vector2(_body_size)
	_position_text()


func _position_text() -> void:
	if _label == null:
		return
	if _style == STYLE_BOX:
		_label.position = Vector2(int(_cfg["text_x"]), int(_cfg["text_y"]))
	else:
		_label.position = Vector2(int(_ui["bubble"]["pad_x"]), _body_local.position.y + int(_ui["bubble"]["pad_top"]))
	_label.size = Vector2(_text_size.x + 4, _text_size.y)


# ---- drawing ----

func _draw() -> void:
	if _state == State.IDLE or _style == STYLE_BOX and _kind == Kind.TEXT:
		return
	var bub: Dictionary = _ui["bubble"]
	var colors: Dictionary = bub["colors"]
	var c_fill: Color = _color(str(colors["fill"]))
	var c_outline: Color = _color(str(colors["outline"]))
	var c_shadow: Color = _color(str(colors["shadow"]))
	var outline: int = int(bub["outline"])
	var corner: int = int(bub["corner"]) if _kind == Kind.TEXT else int(_ui["gesture"]["corner"])
	var tail_h: int = int(bub["tail_height"])
	# During the pop, the body scales around the tail tip so the bubble grows out of the speaker.
	var body: Rect2i = _body_local
	var tail_x: int = _tail_local_x
	if not is_equal_approx(_pop_scale, 1.0):
		var w: int = maxi(8, int(round(float(body.size.x) * _pop_scale)))
		var h: int = maxi(8, int(round(float(body.size.y) * _pop_scale)))
		var x: int = tail_x - int(round(float(tail_x - body.position.x) * _pop_scale))
		var y: int = body.position.y if _flipped else body.end.y - h
		if _flipped:
			y = body.position.y
		body = Rect2i(x, y, w, h)
	# Shadow pass (the whole shape pushed one pixel), then the outline, then the fill.
	_draw_shape(body.position + Vector2i(1, 1), body.size, corner, tail_x + 1, tail_h, c_shadow, c_shadow, 0, true)
	_draw_shape(body.position, body.size, corner, tail_x, tail_h, c_outline, c_fill, outline, false)
	if _kind == Kind.GESTURE and _state != State.OPENING:
		_draw_gesture(body)


func _draw_shape(origin: Vector2i, body_size: Vector2i, corner: int, tail_x: int, tail_h: int, c_outline: Color, c_fill: Color, outline: int, shadow_only: bool) -> void:
	var rect: Rect2i = Rect2i(origin, body_size)
	var half: int = int(_ui["bubble"]["tail_half_width"])
	var dir: int = -1 if _flipped else 1
	var base: int = rect.position.y if _flipped else rect.end.y
	if shadow_only:
		PixelShape.fill(self, rect, corner, c_outline)
		_draw_tail(tail_x, base, dir, tail_h, half, 2, c_outline)
		return
	# Outline pass: body, then the tail's outline.
	PixelShape.fill(self, rect, corner, c_outline)
	_draw_tail(tail_x, base, dir, tail_h, half, outline, c_outline)
	# Fill pass: body inside the outline, then the tail fill that also covers the body's border
	# where the tail joins it.
	PixelShape.fill(self, rect.grow(-outline), maxi(1, corner - outline), c_fill)
	_draw_tail(tail_x, base, dir, tail_h, half, 0, c_fill, outline)


## Draws the tail as stepped rows. `grow` widens each row (the outline), `cover` extra rows reach
## back into the body so the join has no border line.
func _draw_tail(tail_x: int, base: int, dir: int, tail_h: int, half: int, grow: int, color: Color, cover: int = 0) -> void:
	for r: int in range(-cover, tail_h + (1 if grow > 0 else 0)):
		var row_half: int = half if r < 0 else maxi(1, half - (r * half) / tail_h)
		if r >= tail_h:
			row_half = 0
		var y: int = base + r if dir > 0 else base - 1 - r
		var width: int = (row_half + grow) * 2
		if width <= 0:
			continue
		draw_rect(Rect2(tail_x - row_half - grow, y, width, 1), color)


func _draw_gesture(body: Rect2i) -> void:
	if _gesture_frames.is_empty():
		return
	var frame_s: float = float(_ui["gesture"]["frame_s"])
	var frame: int = int(_anim_clock / frame_s) % _gesture_frames.size()
	var icon: int = GestureIcons.get_icon_size()
	var at: Vector2 = Vector2(body.position.x + (body.size.x - icon) / 2, body.position.y + (body.size.y - icon) / 2)
	draw_texture(_gesture_frames[frame], at)


func _draw_overlay() -> void:
	if _state == State.IDLE or _state == State.OPENING or _state == State.CLOSING or _state == State.CLOSED:
		return
	if _style == STYLE_BOX and _kind == Kind.TEXT:
		_draw_tag(Vector2i(int(_cfg["text_x"]) - 2, int(_cfg["tag_y"])))
		_draw_arrow(Vector2i(_body_local.end.x - 20, _body_local.end.y - 14 - _choices_height_box()))
		_draw_choices(_box_choice_top(), _body_local.position.x + 8, _body_local.size.x - 16)
		return
	if _kind == Kind.GESTURE:
		return
	if _show_tag:
		var bub: Dictionary = _ui["bubble"]
		var tag_x: int = int(bub["tag_x"])
		var tag_w: int = _tag_width()
		if _flipped and _tail_local_x - int(bub["tail_half_width"]) < tag_x + tag_w:
			tag_x = _body_local.size.x - int(bub["tag_x"]) - tag_w
		_draw_tag(Vector2i(tag_x, _body_local.position.y - int(bub["tag_overhang"])))
	if _state == State.WAITING:
		var bub: Dictionary = _ui["bubble"]
		var arrow_w: int = int(bub["arrow_w"])
		_draw_arrow(Vector2i(_body_local.end.x - int(bub["pad_x"]) - arrow_w, _body_local.end.y - int(bub["pad_bottom"]) - 1))
	if _state == State.CHOOSING:
		var bub: Dictionary = _ui["bubble"]
		var top: int = _body_local.position.y + int(bub["pad_top"]) + _text_size.y + int(bub["choice_gap"])
		_draw_choices(top, _body_local.position.x + int(bub["pad_x"]) - 3, _body_local.size.x - (int(bub["pad_x"]) - 3) * 2)


func _draw_tag(origin: Vector2i) -> void:
	if not _show_tag:
		return
	var bub: Dictionary = _ui["bubble"]
	var tag_h: int = int(bub["tag_height"])
	var rect: Rect2i = Rect2i(origin, Vector2i(_tag_width(), tag_h))
	var ink: Color = _palette["ink"]
	_overlay.draw_rect(Rect2(rect.position + Vector2i(1, 1), rect.size), ink)
	_overlay.draw_rect(Rect2(rect), ink)
	_overlay.draw_rect(Rect2(rect.grow(-1)), _accent)
	var luminance: float = _accent.get_luminance()
	var text_color: Color = ink if luminance > 0.33 else _palette["chalk"]
	var baseline: float = float(rect.position.y + 1) + float((tag_h - 2 - _font_tag_size) / 2) + float(_font_tag_size)
	var tag_at: Vector2 = Vector2(rect.position.x + int(bub["tag_pad_x"]), baseline)
	if luminance > 0.33:
		_overlay.draw_string(_font_tag, tag_at, _name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_tag_size, text_color)
	else:
		UiText.draw(_overlay, "tag", tag_at, _name_text, text_color)


func _draw_arrow(origin: Vector2i) -> void:
	if _state != State.WAITING or not active:
		return
	var blink: float = float(_ui["bubble"]["arrow_blink_s"])
	if int(_anim_clock / blink) % 2 != 0:
		return
	var arrow_w: int = int(_ui["bubble"]["arrow_w"])
	var arrow_h: int = int(_ui["bubble"]["arrow_h"])
	var color: Color = _color(str(_ui["bubble"]["colors"]["arrow"])) if _style == STYLE_BUBBLE else _palette["lamp_amber"]
	for row: int in arrow_h:
		var width: int = arrow_w - row * 2
		if width <= 0:
			break
		_overlay.draw_rect(Rect2(origin.x + row, origin.y + row, width, 1), color)


func _choice_row_height() -> int:
	return int(_ui["bubble"]["choice_row_height"]) if _style == STYLE_BUBBLE else int(_cfg["choice_row_height"])


func _box_choice_top() -> int:
	return int(_cfg["text_y"]) + _text_size.y + 2


func _choices_height_box() -> int:
	return _choices.size() * int(_cfg["choice_row_height"]) if _state == State.CHOOSING else 0


## The row rectangle of choice `index` in this node's local coordinates.
func _choice_row(index: int) -> Rect2i:
	var row_h: int = _choice_row_height()
	if _style == STYLE_BOX:
		return Rect2i(8, _box_choice_top() + index * row_h, _body_local.size.x - 16, row_h)
	var bub: Dictionary = _ui["bubble"]
	var top: int = _body_local.position.y + int(bub["pad_top"]) + _text_size.y + int(bub["choice_gap"]) + index * row_h
	var left: int = int(bub["pad_x"]) - 3
	return Rect2i(left, top, _body_local.size.x - left * 2, row_h)


func _draw_choices(_top: int, _left: int, _width: int) -> void:
	if _state != State.CHOOSING:
		return
	var bub: Dictionary = _ui["bubble"]
	var colors: Dictionary = bub["colors"]
	var plain: Color = _color(str(colors["text"])) if _style == STYLE_BUBBLE else _palette["text"]
	var select_fill: Color = _color(str(colors["select_fill"])) if _style == STYLE_BUBBLE else _palette["dusk"]
	var select_text: Color = _color(str(colors["select_text"]))
	var icon: int = GestureIcons.get_icon_size()
	var indent: int = int(bub["choice_indent"])
	for i: int in _choices.size():
		var row: Rect2i = _choice_row(i)
		var selected: bool = i == _choice_index
		if selected:
			PixelShape.fill(_overlay, row, 3, select_fill)
		var option: Dictionary = _choices[i]
		var x: int = row.position.x + indent
		var gesture: String = str(option["gesture"])
		if not gesture.is_empty():
			var frames: Array[ImageTexture] = GestureIcons.get_frames(gesture)
			if not frames.is_empty():
				var frame: int = int(_anim_clock / float(_ui["gesture"]["frame_s"])) % frames.size() if selected else 0
				_overlay.draw_texture(frames[frame], Vector2(x - 2, row.position.y + (row.size.y - icon) / 2))
			x += icon + 2
		var baseline: float = float(row.position.y) + (row.size.y + _font_body_size) / 2.0 - 2.0
		var on_light: bool = _style == STYLE_BUBBLE and not selected
		UiText.draw(_overlay, _font_key, Vector2(x, baseline), str(option["label"]), select_text if selected else plain, HORIZONTAL_ALIGNMENT_LEFT, -1.0, on_light)
		if selected:
			_draw_choice_pointer(row)


## A small triangle pointer at the left of the selected row (flickers like the menu cursor).
func _draw_choice_pointer(row: Rect2i) -> void:
	var color: Color = _palette["lamp_amber"]
	var y: int = row.position.y + row.size.y / 2 - 3 + (int(_anim_clock / 0.4) % 2)
	for i: int in 4:
		_overlay.draw_rect(Rect2(row.position.x + 2 + i, y + i, 1, 7 - i * 2), color)


# ---- queries (tests and the runner) ----

func get_state() -> State:
	return _state


func get_kind() -> Kind:
	return _kind


func get_style() -> String:
	return _style


func get_visible_text() -> String:
	return _typer.get_visible_text()


func get_pages() -> PackedStringArray:
	return _pages


func get_page_index() -> int:
	return _page_index


func get_choices() -> Array[Dictionary]:
	return _choices


func get_choice_index() -> int:
	return _choice_index


func get_gesture_id() -> String:
	return _gesture_id


func get_placement() -> BubblePlacement.Result:
	return _placement


func is_flipped() -> bool:
	return _flipped


func get_body_size() -> Vector2i:
	return _body_size


## The body rectangle (without the tail) in stage pixels.
func get_body_rect() -> Rect2:
	return Rect2(position + Vector2(_body_local.position), Vector2(_body_local.size))


func get_name_text() -> String:
	return _name_text


func has_name_tag() -> bool:
	return _show_tag


func is_finished() -> bool:
	return _state == State.WAITING and _page_index + 1 >= _pages.size() and _choices.is_empty()
