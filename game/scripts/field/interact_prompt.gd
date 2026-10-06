class_name InteractPrompt
extends Control
## The little pixel icon that pops over Red's head when something nearby can be used: a speech
## bubble (talk), a "?" (examine) or a hand (take). Lives on the UiStage root (384x216 pixels).
## Icon art and colors come from data/ui/interact_icons.json and data/ui/ui_theme.json;
## sizes and timing from data/world/interaction.json.

const ICONS_ID: String = "ui/interact_icons"
const THEME_ID: String = "ui/ui_theme"
const EMPTY: String = "."

## "talk", "examine" or "take" while shown, "" while hidden.
var current_icon: String = ""
## The 3D thing the icon floats over (Red) and the camera that projects it.
var follow: Node3D = null
var camera: Camera3D = null
var tuning: InteractionTuning = InteractionTuning.new()

var _rows: Dictionary = {}
var _colors: Dictionary[String, Color] = {}
var _outline: Color = Color.BLACK
var _age: float = 0.0
var _anchor: Vector2 = Vector2.ZERO


func _init() -> void:
	name = "InteractPrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	size = Vector2(UiStage.STAGE_SIZE)
	z_index = 5


func _ready() -> void:
	var icons: Dictionary = DataDB.get_dict(ICONS_ID)
	var palette: Dictionary = DataDB.get_value(THEME_ID, "palette", {})
	for letter: String in icons["palette"]:
		_colors[letter] = Color.html(str(palette[str(icons["palette"][letter])]))
	_outline = Color.html(str(palette[str(icons["outline"])]))
	_rows = icons["icons"]
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	tick(delta)


func is_showing() -> bool:
	return visible and not current_icon.is_empty()


## Shows `icon_id` (or hides when empty). The icon pops in when it first appears or changes.
func show_icon(icon_id: String) -> void:
	if icon_id == current_icon:
		return
	current_icon = icon_id
	visible = not icon_id.is_empty()
	_age = 0.0
	queue_redraw()


func hide_icon() -> void:
	show_icon("")


## Moves the icon with Red and advances the pop and bob. Public so tests can drive it.
func tick(delta: float) -> void:
	if current_icon.is_empty():
		return
	_age += delta
	if follow != null and camera != null and is_instance_valid(follow):
		var head: Vector3 = follow.global_position + Vector3.UP * tuning.prompt_head_height
		_anchor = BubblePlacement.project_to_stage(camera, head, Vector2(UiStage.STAGE_SIZE))
	queue_redraw()


## Where the icon's bottom-center sits right now, in stage pixels.
func get_anchor_point() -> Vector2:
	return _anchor


func get_icon_size(icon_id: String) -> Vector2i:
	var rows: Array = _rows.get(icon_id, [])
	if rows.is_empty():
		return Vector2i.ZERO
	return Vector2i(str(rows[0]).length(), rows.size())


func _pop_scale() -> float:
	var steps: Array[float] = tuning.prompt_pop_scales
	if steps.is_empty() or tuning.prompt_pop_step_s <= 0.0:
		return 1.0
	var index: int = int(_age / tuning.prompt_pop_step_s)
	return steps[mini(index, steps.size() - 1)]


func _draw() -> void:
	if current_icon.is_empty() or not _rows.has(current_icon):
		return
	var rows: Array = _rows[current_icon]
	var width: int = str(rows[0]).length()
	var height: int = rows.size()
	var scale: float = _pop_scale()
	var bob: float = 0.0
	if tuning.prompt_bob_period_s > 0.0 and _age > tuning.prompt_pop_step_s * tuning.prompt_pop_scales.size():
		bob = -round(tuning.prompt_bob_px * (0.5 + 0.5 * sin(_age * TAU / tuning.prompt_bob_period_s)))
	var origin: Vector2 = _anchor + Vector2(-width * scale * 0.5, -(height + 1) * scale - tuning.prompt_gap_px + bob)
	origin = origin.round()
	var cell: float = scale
	for y: int in range(-1, height + 1):
		for x: int in range(-1, width + 1):
			var letter: String = _letter_at(rows, x, y)
			var color: Color
			if letter != EMPTY:
				color = _colors.get(letter, Color.MAGENTA)
			elif _touches_filled(rows, x, y):
				color = _outline
			else:
				continue
			draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), color)


func _letter_at(rows: Array, x: int, y: int) -> String:
	if y < 0 or y >= rows.size():
		return EMPTY
	var row: String = str(rows[y])
	if x < 0 or x >= row.length():
		return EMPTY
	return row[x]


func _touches_filled(rows: Array, x: int, y: int) -> bool:
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _letter_at(rows, x + offset.x, y + offset.y) != EMPTY:
			return true
	return false
