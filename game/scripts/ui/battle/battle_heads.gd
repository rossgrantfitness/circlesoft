class_name BattleHeads
extends RefCounted
## Placeholder heads for the turn-order row: a small tile in the fighter's accent color with
## their initial (enemies of the same kind also get a number badge), like the field menu's
## placeholder portraits. The real 32x32 heads are docs/art_requests.md row 36.


## The tile color for a combatant.
static func accent_for(id: String, roster: BattleRoster) -> Color:
	var heads: Dictionary = BattleUiData.ui("heads", {})
	var kind: String = roster.kind_of(id)
	if heads.has(id) and (heads[id] as Dictionary).has("accent"):
		return Color.html(str((heads[id] as Dictionary)["accent"]))
	if heads.has(kind) and (heads[kind] as Dictionary).has("accent"):
		return Color.html(str((heads[kind] as Dictionary)["accent"]))
	if roster.side_of(id) == BattleRoster.SIDE_ENEMY:
		var by_kind: Dictionary = heads.get("enemy_by_kind", {})
		if by_kind.has(kind):
			return Color.html(str(by_kind[kind]))
		return Color.html(str((heads.get("enemy_default", {}) as Dictionary).get("accent", "#5B6573")))
	return Color.html(str((heads.get("party_default", {}) as Dictionary).get("accent", "#FFB347")))


## The letter on the tile (party: first letter of the name; enemies: first letter of the last word).
static func initial_for(id: String, roster: BattleRoster) -> String:
	var heads: Dictionary = BattleUiData.ui("heads", {})
	if heads.has(id) and (heads[id] as Dictionary).has("initial"):
		return str((heads[id] as Dictionary)["initial"])
	var name: String = roster.name_of(id)
	if roster.side_of(id) == BattleRoster.SIDE_ENEMY:
		# "Signals Grunt" and "Signals Drone" tell apart by the last word.
		var words: PackedStringArray = name.split(" ", false)
		if not words.is_empty():
			name = words[words.size() - 1]
	return name.substr(0, 1).to_upper() if not name.is_empty() else "?"


## 1-based number among enemies of the same kind when there is more than one, else 0.
static func ordinal_for(id: String, roster: BattleRoster) -> int:
	if roster.side_of(id) != BattleRoster.SIDE_ENEMY:
		return 0
	var kind: String = roster.kind_of(id)
	var same: Array[String] = []
	for other: String in roster.ids(BattleRoster.SIDE_ENEMY):
		if roster.kind_of(other) == kind:
			same.append(other)
	return same.find(id) + 1 if same.size() > 1 else 0


## Draws one head tile into `rect`. `highlight` frames it in amber (the fighter who is up now).
static func draw_head(canvas: CanvasItem, rect: Rect2, id: String, roster: BattleRoster, alpha: float, highlight: bool) -> void:
	var ink: Color = BattleUiData.palette("ink")
	var chalk: Color = BattleUiData.palette("chalk")
	var amber: Color = BattleUiData.palette("lamp_amber")
	var fade: Color = Color(1, 1, 1, alpha)
	canvas.draw_rect(Rect2(rect.position + Vector2(1, 1), rect.size), ink * fade)
	canvas.draw_rect(rect.grow(1), (amber if highlight else chalk) * fade)
	if highlight:
		canvas.draw_rect(rect.grow(2), amber * fade, false, 1.0)
	canvas.draw_rect(rect, accent_for(id, roster) * fade)
	var font: Font = UiFonts.get_font("title")
	var font_size: int = 14
	var baseline: float = rect.position.y + (rect.size.y + float(font_size)) / 2.0 - 3.0
	canvas.draw_string(font, Vector2(rect.position.x, baseline), initial_for(id, roster), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, ink * fade)
	var ordinal: int = ordinal_for(id, roster)
	if ordinal > 0:
		var badge: Rect2 = Rect2(rect.end.x - 7.0, rect.end.y - 9.0, 7.0, 9.0)
		canvas.draw_rect(badge, chalk * fade)
		canvas.draw_string(font, Vector2(badge.position.x, badge.end.y - 1.0), str(ordinal), HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 9, ink * fade)
