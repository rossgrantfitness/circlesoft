class_name CommandDeckModel
extends RefCounted
## The command deck's state, with no drawing: three rows (Attack, Hack, Item), which one has the focus, whether the
## hack list is open, and a short note ("Items: coming later"). The picked hack itself is not kept here: it lives in
## HackPanelModel (which mirrors the host's HackSelector), so the deck and the hack button can never disagree.

const ATTACK: String = "attack"
const HACK: String = "hack"
const ITEM: String = "item"
const ROWS: Array[String] = [ATTACK, HACK, ITEM]
const ACTION_NONE: String = ""

var row: int = 1
var submenu_open: bool = false

var _note: String = ""
var _note_left_s: float = 0.0


func row_id() -> String:
	return ROWS[row]


## Moves the focus one row (wraps). Closes the list.
func scroll(direction: int) -> void:
	row = posmod(row + direction, ROWS.size())
	submenu_open = false


func focus(id: String) -> void:
	var index: int = ROWS.find(id)
	if index >= 0:
		row = index
		if id != HACK:
			submenu_open = false


## "Choose" on the focused row. Returns what happened: "opened" / "closed" (the hack list), or "note" (a stub row said something).
## `auto` is true when the hack button picks for itself (the list has nothing to pick).
func choose(auto: bool = false) -> String:
	match ROWS[row]:
		HACK:
			if auto:
				say(SliceUiData.text("deck.auto_note"))
				return "note"
			submenu_open = not submenu_open
			return "opened" if submenu_open else "closed"
		ITEM:
			say(SliceUiData.text("deck.item_note"))
			return "note"
		_:
			say(SliceUiData.text("deck.attack_note"))
			return "note"


func close_submenu() -> bool:
	var was: bool = submenu_open
	submenu_open = false
	return was


func say(text: String) -> void:
	_note = text
	_note_left_s = SliceUiData.num("deck.note_s", 1.6)


func note() -> String:
	return _note if _note_left_s > 0.0 else ""


func tick(delta: float) -> void:
	_note_left_s = maxf(0.0, _note_left_s - delta)
