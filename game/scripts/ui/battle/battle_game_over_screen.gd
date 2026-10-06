class_name BattleGameOverScreen
extends Control
## The game over screen: the dim, a big "Game Over", and a two-row list, Retry and Back to title.
## It only reports the choice (`choice_made("retry" / "title")`); wiring Retry to a restart is the
## integrator's job (a stub signal for now).

signal choice_made(choice: String)

const CHOICE_RETRY: String = "retry"
const CHOICE_TITLE: String = "title"

var audio: UiAudio = UiAudio.new()

var _dim: DitherFade = null
var _window: UiWindow = null
var _list: MenuList = null
var _since_shown: float = 0.0
var _showing: bool = false
var _drawing: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	_dim = DitherFade.new()
	_dim.name = "Dim"
	_dim.size = size
	add_child(_dim)
	_drawing = Control.new()
	_drawing.name = "Title"
	_drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawing.size = size
	_drawing.draw.connect(_draw_title)
	add_child(_drawing)
	var rect: Rect2 = BattleUiData.ui_rect("layout.game_over.list")
	_window = UiWindow.new()
	_window.name = "Window"
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.position = rect.position
	_window.size = rect.size
	add_child(_window)
	_list = MenuList.new()
	_list.audio = audio
	_list.size = rect.size
	_list.visible_rows = 2
	_list.first_row_y = 10
	_list.row_height = 20
	_list.text_x = 26
	_list.cursor_x = 8
	_window.add_child(_list)
	_list.activated.connect(_on_activated)
	visible = false


func show_screen() -> void:
	var rows: Array[Dictionary] = [
		{"id": CHOICE_RETRY, "label": BattleUiData.text("game_over.retry")},
		{"id": CHOICE_TITLE, "label": BattleUiData.text("game_over.title_screen")},
	]
	_list.set_items(rows)
	_dim.step_count = 8
	_dim.step = BattleUiData.ui_int("game_over.dim_step", 7)
	_since_shown = 0.0
	_showing = true
	visible = true
	_drawing.queue_redraw()


func is_showing() -> bool:
	return _showing


func get_list() -> MenuList:
	return _list


func tick(delta: float) -> void:
	if _showing:
		_since_shown += delta


func handle_command(command: MenuInput.Cmd) -> void:
	if not _showing or _since_shown < BattleUiData.ui_float("game_over.input_grace_s", 0.3):
		return
	_list.handle_command(command)


func handle_mouse(event: InputEvent) -> bool:
	if not _showing or _since_shown < BattleUiData.ui_float("game_over.input_grace_s", 0.3):
		return false
	return _list.handle_mouse(event)


func _on_activated(index: int) -> void:
	_showing = false
	visible = false
	choice_made.emit(_list.get_item_id(index))


func _draw_title() -> void:
	var font: Font = UiFonts.get_font("title")
	var size_px: int = BattleUiData.ui_int("game_over.title_size", 32)
	var title: String = BattleUiData.text("game_over.title")
	var y: float = BattleUiData.ui_float("layout.game_over.title_y", 70.0)
	_drawing.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, size_px, 6, BattleUiData.palette("ink"))
	_drawing.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, size_px, BattleUiData.palette("chalk"))
	UiText.draw(_drawing, "menu", Vector2(0, BattleUiData.ui_float("layout.game_over.sub_y", 100.0)), BattleUiData.text("game_over.sub"), BattleUiData.palette("text_dim"), HORIZONTAL_ALIGNMENT_CENTER, size.x)
