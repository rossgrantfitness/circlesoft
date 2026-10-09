class_name HackIcons
extends RefCounted
## Placeholder hack icons: tiny pixel pictures drawn from rows of text in data/ui/slice_ui.json "icons"
## (X = ink). Ross's final icons (art request VS-A7.2) replace them: when a PNG exists at
## art/final/ui/icons/hacks/ico_<icon id>.png it is drawn instead, so the swap needs no code change.

const FINAL_DIR: String = "res://art/final/ui/icons/hacks/"
const FINAL_PREFIX: String = "ico_"

static var _textures: Dictionary = {}


static func has_icon(icon_id: String) -> bool:
	return not (SliceUiData.ui("icons.%s" % icon_id, []) as Array).is_empty() or final_texture(icon_id) != null


## The final art for an icon id ("hack_zap" -> ico_hack_zap.png), or null while it is still the placeholder.
static func final_texture(icon_id: String) -> Texture2D:
	if _textures.has(icon_id):
		return _textures[icon_id] as Texture2D
	var path: String = "%s%s%s.png" % [FINAL_DIR, FINAL_PREFIX, icon_id]
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_textures[icon_id] = tex
	return tex


## Draws the icon with its top-left at `at`, `size` pixels square (the placeholder is 9 px and centered in the box).
static func draw(canvas: CanvasItem, at: Vector2, icon_id: String, tint: Color, size: float = 9.0) -> void:
	var tex: Texture2D = final_texture(icon_id)
	if tex != null:
		canvas.draw_texture_rect(tex, Rect2(at, Vector2(size, size)), false, tint)
		return
	var rows: Array = SliceUiData.ui("icons.%s" % icon_id, [])
	if rows.is_empty():
		return
	var shadow: Color = SandboxStyle.color("shadow")
	shadow.a = tint.a
	var origin: Vector2 = at + Vector2(floorf((size - 9.0) / 2.0), floorf((size - 9.0) / 2.0))
	for pass_index: int in 2:
		var offset: Vector2 = Vector2.ONE if pass_index == 0 else Vector2.ZERO
		var paint: Color = shadow if pass_index == 0 else tint
		for y: int in rows.size():
			var row: String = str(rows[y])
			for x: int in row.length():
				if row[x] == "X":
					canvas.draw_rect(Rect2(origin + Vector2(float(x), float(y)) + offset, Vector2.ONE), paint)
