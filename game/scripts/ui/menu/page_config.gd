class_name PageConfig
extends MenuPage
## Config: the shared ConfigScreen (UI Programmer B's component, the same one the title screen
## shows) embedded in the field menu. It takes over the side window and the info window (it draws
## its own window, title and info strip), so the main list stays on the left with its cursor dimmed.
##
## Backing out of the screen's top level, or closing the menu, saves the settings (the screen does
## that itself on close) and returns to the main list. While the screen has a sub-page up (Controls,
## a button capture, the tap-along test) it also gets the raw input events, because those pages
## listen for presses the menu commands do not carry.

var _screen: ConfigScreen = null
var _closing: bool = false


func build() -> void:
	var rect: Rect2 = menu.config_screen_rect()
	_screen = ConfigScreen.new()
	_screen.name = "ConfigScreen"
	_screen.config = menu.config
	_screen.audio = menu.audio
	_screen.manual_ticks = true
	_screen.size = rect.size
	_screen.position = rect.position
	menu.get_frame().add_child(_screen)
	menu.set_side_windows_visible(false)
	_screen.closed.connect(_on_screen_closed)
	_screen.open(true)


func primary_list() -> MenuList:
	return _screen.get_list() if _screen != null else null


func get_screen() -> ConfigScreen:
	return _screen


func command(cmd: MenuInput.Cmd) -> void:
	if _screen != null:
		_screen.handle_command(cmd)


func mouse(event: InputEvent) -> bool:
	return _screen != null and _screen.handle_event(event)


## Raw events while a sub-page of the screen is up (key capture, the tap-along test).
func raw_event(event: InputEvent) -> bool:
	if _screen != null and _screen.is_busy():
		return _screen.handle_event(event)
	return false


func tick(delta: float) -> void:
	if _screen != null:
		_screen.tick(delta)


func info() -> Dictionary:
	return MenuPage.info_of("")


func get_preview_text() -> String:
	return _screen.get_preview_text() if _screen != null else ""


func _on_screen_closed() -> void:
	if _closing:
		return
	menu.back_to_main()


## Saves, drops the screen and gives the side and info windows back.
func leave() -> void:
	if _screen == null or _closing:
		return
	_closing = true
	var cfg: Node = menu.config_node()
	if cfg != null and cfg.has_method("save_file"):
		cfg.call("save_file")
	var screen: ConfigScreen = _screen
	_screen = null
	if is_instance_valid(screen):
		if screen.get_parent() != null:
			screen.get_parent().remove_child(screen)
		screen.queue_free()
	menu.set_side_windows_visible(true)
