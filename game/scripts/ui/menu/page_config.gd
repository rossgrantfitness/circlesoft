class_name PageConfig
extends MenuPage
## Config: text speed, voice volume, Auto-Timing, Wide Windows and the timing offset, stored in the
## Config autoload (written to disk when the page is left). Left / right change a value, confirm
## steps it (and toggles). A typed preview line shows the text speed. This page is the stand-in for
## UI Programmer B's shared Config screen; see docs/m3_plan.md "Changes".

const UI_ID: String = "ui/dialogue_ui"
const ROWS: PackedStringArray = ["text_speed", "voice_volume", "auto_timing", "wide_windows", "timing_offset"]

var _spec: Dictionary = {}
var _list: MenuList = null
var _preview_label: Label = null
var _preview: TypeWriter = TypeWriter.new()
var _preview_clock: float = 0.0


func build() -> void:
	_spec = menu.layout["config_page"]
	_list = menu.make_list(root, {"x": 0, "y": 0, "w": FieldMenu.PAGE_AREA.size.x, "h": FieldMenu.PAGE_AREA.size.y,
			"first_y": int(_spec["first_y"]), "step": int(_spec["row_step"]), "rows": ROWS.size()})
	_list.set_items(_rows())
	_list.set_index(int(menu.memory.get("config.row", 0)), false)
	_list.activated.connect(func(_i: int) -> void: _change(1, true))
	_list.cursor_moved.connect(func(i: int) -> void:
		menu.memory["config.row"] = i
		menu.refresh_info())
	_preview_label = menu.make_label(root, "body", "lamp_amber", Vector2(14, float(_spec["preview_y"])))
	_preview_label.size = Vector2(FieldMenu.PAGE_AREA.size.x - 28.0, 16.0)
	_restart_preview()


func primary_list() -> MenuList:
	return _list


func get_preview_text() -> String:
	return _preview_label.text if _preview_label != null else ""


func command(cmd: MenuInput.Cmd) -> void:
	match cmd:
		MenuInput.Cmd.CANCEL:
			leave()
			menu.back_to_main()
		MenuInput.Cmd.LEFT:
			_change(-1)
		MenuInput.Cmd.RIGHT:
			_change(1)
		_:
			_list.handle_command(cmd)


func leave() -> void:
	var cfg: Node = menu.config_node()
	if cfg != null and cfg.has_method("save_file"):
		cfg.call("save_file")


func info() -> Dictionary:
	var row: String = _list.get_item_id(_list.get_cursor_index())
	return MenuPage.info_of(str(menu.text["config"]["hints"].get(row, "")))


func _rows() -> Array[Dictionary]:
	var cfg: Node = menu.config_node()
	var strings: Dictionary = menu.text["config"]
	var rows: Array[Dictionary] = []
	if cfg == null:
		return rows
	var speed_names: Dictionary = strings["speed_names"]
	rows.append({"id": "text_speed", "label": str(strings["text_speed"]),
			"value": "< %s >" % str(speed_names.get(str(cfg.get("text_speed")), str(cfg.get("text_speed"))))})
	rows.append({"id": "voice_volume", "label": str(strings["voice_volume"]),
			"value": "< %d%% >" % int(round(float(cfg.get("voice_volume")) * 100.0))})
	rows.append({"id": "auto_timing", "label": str(strings["auto_timing"]),
			"value": "< %s >" % str(strings["on"] if bool(cfg.get("auto_timing")) else strings["off"])})
	rows.append({"id": "wide_windows", "label": str(strings["wide_windows"]),
			"value": "< %s >" % str(strings["on"] if bool(cfg.get("wide_windows")) else strings["off"])})
	rows.append({"id": "timing_offset", "label": str(strings["timing_offset"]),
			"value": "< %s >" % str(strings["ms_format"]).replace("{ms}", "%+d" % int(cfg.get("timing_offset_ms")))})
	return rows


## Changes the highlighted setting one step. `wrap` lets a confirm press cycle past the end.
func _change(direction: int, wrap: bool = false) -> void:
	var cfg: Node = menu.config_node()
	if cfg == null:
		return
	var row: String = _list.get_item_id(_list.get_cursor_index())
	var changed: bool = false
	match row:
		"text_speed":
			var ids: Array[String] = []
			ids.assign(cfg.call("get_text_speed_ids"))
			var current: int = ids.find(str(cfg.get("text_speed")))
			var target: int = posmod(current + direction, ids.size()) if wrap else clampi(current + direction, 0, ids.size() - 1)
			if target != current:
				cfg.call("set_text_speed", ids[target])
				changed = true
		"voice_volume":
			var steps: int = int(menu.layout["volume_steps"])
			var current_step: int = int(round(float(cfg.get("voice_volume")) * float(steps)))
			var target_step: int = posmod(current_step + direction, steps + 1) if wrap else clampi(current_step + direction, 0, steps)
			if target_step != current_step:
				cfg.call("set_voice_volume", float(target_step) / float(steps))
				changed = true
				menu.audio.voice(str(menu.text["config"]["preview_speaker"]), "a")
		"auto_timing":
			cfg.call("set_auto_timing", not bool(cfg.get("auto_timing")))
			changed = true
		"wide_windows":
			cfg.call("set_wide_windows", not bool(cfg.get("wide_windows")))
			changed = true
		"timing_offset":
			var before_ms: int = int(cfg.get("timing_offset_ms"))
			var moved: bool = bool(cfg.call("step_timing_offset", direction))
			if not moved and wrap:
				# A confirm press at the end of the range jumps back to the other end.
				cfg.call("set_timing_offset_ms", int(cfg.call("get_timing_offset_min_ms")) if direction > 0 else int(cfg.call("get_timing_offset_max_ms")))
			changed = int(cfg.get("timing_offset_ms")) != before_ms
	if changed:
		menu.audio.sfx("tick")
		_list.set_items(_rows(), true)
		_restart_preview()


func _restart_preview() -> void:
	var cfg: Node = menu.config_node()
	var cps: float = float(cfg.call("get_text_cps")) if cfg != null else 36.0
	_preview.start(str(menu.text["config"]["preview"]), cps, DataDB.get_value(UI_ID, "typing.pauses", {}))
	_preview_label.text = ""
	_preview_clock = 0.0


func tick(delta: float) -> void:
	if _preview.is_done():
		# Loop the line after a short rest so the speed can be judged again.
		_preview_clock += delta
		if _preview_clock > 1.5:
			_restart_preview()
		return
	var typed: String = _preview.advance(delta)
	if not typed.is_empty():
		_preview_label.text = _preview.get_visible_text()
		var speaker: String = str(menu.text["config"]["preview_speaker"])
		for character: String in typed:
			menu.audio.voice(speaker, character)
