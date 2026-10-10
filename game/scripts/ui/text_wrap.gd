class_name TextWrap
extends RefCounted
## Word wrap and paging for dialogue text, measured with the real font so a bubble can be sized
## to fit before anything is shown. Explicit "\n" in the text is always a line break; lines wider
## than the limit are wrapped at spaces (a single word wider than the limit is split).


static func text_width(font: Font, font_size: int, text: String) -> int:
	return int(ceil(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x))


## Splits `text` into display lines no wider than `max_width` pixels.
static func wrap(font: Font, font_size: int, text: String, max_width: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for paragraph: String in text.split("\n"):
		var line: String = ""
		for word: String in paragraph.split(" ", false):
			var candidate: String = word if line.is_empty() else line + " " + word
			if text_width(font, font_size, candidate) <= max_width:
				line = candidate
				continue
			if not line.is_empty():
				lines.append(line)
				line = ""
			while text_width(font, font_size, word) > max_width and word.length() > 1:
				var cut: int = _longest_fit(font, font_size, word, max_width)
				lines.append(word.substr(0, cut))
				word = word.substr(cut)
			line = word
		lines.append(line)
	return lines


## Groups lines into pages of at most `max_lines` lines. Each page is its lines joined with "\n".
static func paginate(lines: PackedStringArray, max_lines: int) -> PackedStringArray:
	var pages: PackedStringArray = PackedStringArray()
	var per_page: int = maxi(1, max_lines)
	var index: int = 0
	while index < lines.size():
		var chunk: PackedStringArray = lines.slice(index, index + per_page)
		pages.append("\n".join(chunk))
		index += per_page
	if pages.is_empty():
		pages.append("")
	return pages


static func _longest_fit(font: Font, font_size: int, word: String, max_width: int) -> int:
	var cut: int = 1
	while cut < word.length() and text_width(font, font_size, word.substr(0, cut + 1)) <= max_width:
		cut += 1
	return cut
