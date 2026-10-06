class_name BattleUiData
extends RefCounted
## Reads the battle HUD's numbers (data/ui/battle_ui.json), strings (data/text/battle.json) and
## the shared palette (data/ui/ui_theme.json). Nothing about the HUD's look is hard-coded in the
## scripts; this is the one place that knows the file names.

const UI_ID: String = "ui/battle_ui"
const TEXT_ID: String = "text/battle"
const THEME_ID: String = "ui/ui_theme"


## A value in battle_ui.json by dotted path.
static func ui(path: String, fallback: Variant = null) -> Variant:
	return DataDB.get_value(UI_ID, path, fallback)


static func ui_int(path: String, fallback: int = 0) -> int:
	return int(DataDB.get_value(UI_ID, path, fallback))


static func ui_float(path: String, fallback: float = 0.0) -> float:
	return float(DataDB.get_value(UI_ID, path, fallback))


static func ui_color(path: String, fallback: String = "#FF00FF") -> Color:
	return Color.html(str(DataDB.get_value(UI_ID, path, fallback)))


## {x, y, w, h} entry as a Rect2.
static func ui_rect(path: String) -> Rect2:
	var d: Dictionary = DataDB.get_value(UI_ID, path, {})
	return Rect2(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("w", 0)), float(d.get("h", 0)))


## [x, y] entry as a Vector2.
static func ui_vec(path: String) -> Vector2:
	var a: Array = DataDB.get_value(UI_ID, path, [0, 0])
	return Vector2(float(a[0]), float(a[1]))


## A string in battle.json by dotted path (empty when missing).
static func text(path: String) -> String:
	return str(DataDB.get_value(TEXT_ID, path, ""))


## Fills {name} style placeholders from `vars`. {A} (the confirm button) is always filled in.
static func fmt(template: String, vars: Dictionary = {}) -> String:
	var out: String = template.replace("{A}", text("buttons.A"))
	for key: Variant in vars:
		out = out.replace("{%s}" % str(key), str(vars[key]))
	return out


## A color from the shared theme palette (ui_theme.json "palette"), by key.
static func palette(key: String) -> Color:
	return Color.html(str(DataDB.get_value(THEME_ID, "palette.%s" % key, "#FF00FF")))


## "ration_bar" -> "Ration Bar" (used only when no real name is known).
static func prettify(id: String) -> String:
	var words: PackedStringArray = id.split("_", false)
	for i: int in words.size():
		words[i] = words[i].capitalize()
	return " ".join(words)


static var _name_cache: Dictionary[String, String] = {}


## The display name of a skill or item id: from the battle data when it is there, else prettified.
static func name_of(id: String) -> String:
	if _name_cache.has(id):
		return _name_cache[id]
	var found: String = ""
	for table_id: String in ["battle/skills:skills", "battle/battle_items:items"]:
		var parts: PackedStringArray = table_id.split(":")
		var list: Variant = DataDB.get_value(parts[0], parts[1], [])
		if list is Array:
			for entry: Variant in list:
				if entry is Dictionary and str((entry as Dictionary).get("id", "")) == id:
					found = str((entry as Dictionary).get("name", ""))
					break
		if not found.is_empty():
			break
	if found.is_empty():
		found = prettify(id)
	_name_cache[id] = found
	return found
