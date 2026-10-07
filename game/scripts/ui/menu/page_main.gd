class_name PageMain
extends MenuPage
## The main page's right side: the crew's portraits, HP and Juice, then credits and play time.
## There is nothing to pick here; the main list on the left has the cursor.

var _column: MemberColumn = null
var _footer: Control = null


func build() -> void:
	var spec: Dictionary = menu.layout["main_panel"]
	_column = menu.make_member_column(root, MemberColumn.Style.PANEL, Vector2(float(spec["x"]), float(spec["y"])))
	_column.set_active(false)
	_footer = menu.make_drawing(root, Vector2.ZERO, FieldMenu.PAGE_AREA.size, _draw_footer)


## The numbers under the crew: {credits: "1,240", time: "1:23:00"}.
func footer_text() -> Dictionary:
	return {"credits": MenuDraw.format_number(menu.backend.credits()), "time": MenuDraw.format_time(menu.backend.play_time_s())}


func _draw_footer(canvas: Control) -> void:
	var spec: Dictionary = menu.layout["main_panel"]
	var y: int = int(spec["footer_y"])
	var strings: Dictionary = menu.text["side"]
	canvas.draw_rect(Rect2(10, y - 12, canvas.size.x - 20, 1), MenuDraw.color("dusk"))
	UiText.draw(canvas, "menu", Vector2(12, y + 2), str(strings["credits"]), MenuDraw.color("text_dim"))
	UiText.draw(canvas, "menu", Vector2(0, y + 2), str(footer_text()["credits"]), MenuDraw.color("text"),
			HORIZONTAL_ALIGNMENT_RIGHT, 118.0)
	UiText.draw(canvas, "menu", Vector2(146, y + 2), str(strings["time"]), MenuDraw.color("text_dim"))
	UiText.draw(canvas, "menu", Vector2(0, y + 2), str(footer_text()["time"]), MenuDraw.color("text"),
			HORIZONTAL_ALIGNMENT_RIGHT, canvas.size.x - 12.0)


func get_column() -> MemberColumn:
	return _column
