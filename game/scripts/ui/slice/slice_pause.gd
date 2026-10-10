class_name SlicePause
extends SandboxPause
## The slice's pause menu: the sandbox pause menu's look and behaviour with the slice's rows: Resume, Menu
## (items and gear; only shown once something is listening for `field_menu_requested`, which the town systems
## do), Controls, Tuning (the F12 feel panel) and Quit to title. No "Reset arena" here: a slice room has
## no reset. It says what was picked and the HUD acts, like its parent. Words: data/text/slice_ui.json "pause";
## layout: data/ui/slice_ui.json "pause".

## "Menu" was chosen (items, gear, the field menu). The menu has already closed.
signal field_menu_requested
## "Tuning" was chosen (open the feel panel). The menu has already closed.
signal feel_requested

const SLICE_ITEM_IDS: Array[String] = ["resume", "menu", "controls", "feel", "quit"]

## Show the Menu row. The HUD sets it from whether anyone listens for `field_menu_requested`.
var menu_enabled: bool = true
## Show the Tuning row (the feel panel is on F12 in the slice build).
var feel_enabled: bool = true


func item_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in SLICE_ITEM_IDS:
		if id == "menu" and not menu_enabled:
			continue
		if id == "feel" and not feel_enabled:
			continue
		out.append(id)
	return out


func _load_layout() -> Dictionary:
	return SliceUiData.ui("pause", {})


func _word(path: String) -> String:
	return SliceUiData.text("pause.%s" % path)


func _activate_item(id: String) -> void:
	match id:
		"menu":
			resume()
			field_menu_requested.emit()
		"feel":
			resume()
			feel_requested.emit()
		_:
			super(id)
