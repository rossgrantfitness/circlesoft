class_name MenuPage
extends RefCounted
## One page of the field menu (Items, Skills, Equip, ...). The FieldMenu owns the windows, the
## main list, the info window and the input; a page builds its widgets inside `root` (the side
## window's page area), reacts to menu commands and says what the info window should show.
##
## Pages never read input themselves: FieldMenu forwards each MenuInput command to command(), and
## mouse events to mouse(). The default does what a plain list page needs: UP / DOWN / CONFIRM go to
## the list, CANCEL goes back to the main page.

var menu: FieldMenu = null
var root: Control = null


func _init(p_menu: FieldMenu, p_root: Control) -> void:
	menu = p_menu
	root = p_root


## Create the widgets. Called once when the page opens.
func build() -> void:
	pass


## One menu command (UP / DOWN / LEFT / RIGHT / CONFIRM / CANCEL). MENU is handled by FieldMenu.
func command(cmd: MenuInput.Cmd) -> void:
	if cmd == MenuInput.Cmd.CANCEL:
		menu.back_to_main()
		return
	var list: MenuList = primary_list()
	if list != null:
		list.handle_command(cmd)


## A mouse event in stage pixels. True when the page used it.
func mouse(event: InputEvent) -> bool:
	var list: MenuList = primary_list()
	return list != null and list.handle_mouse(event)


## A raw input event before it is turned into a menu command (a page that listens for presses the
## commands do not carry, like the Config screen's button capture). True when the page used it.
func raw_event(_event: InputEvent) -> bool:
	return false


## The list that tests and the default input drive.
func primary_list() -> MenuList:
	return null


## What the info window shows: {"text": String, "warn": bool}. `warn` colors it as a reason.
func info() -> Dictionary:
	return {"text": "", "warn": false}


## Time passing (animations, previews).
func tick(_delta: float) -> void:
	pass


## The page is being left (back to the main list, or the menu closing).
func leave() -> void:
	pass


static func info_of(text: String, warn: bool = false) -> Dictionary:
	return {"text": text, "warn": warn}
