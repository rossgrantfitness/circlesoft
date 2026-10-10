class_name DialogueMarkup
extends RefCounted
## Inline tags in dialogue text, written like {face:grin}. The speaker's portrait changes to the
## "grin" expression at that point in the line, while the text types out.
##
## Parsing strips the tags out of the text (so wrapping and sizing never see them) and remembers
## where each one stood as a count of non-blank characters before it. Wrapping only changes spaces
## and line breaks, so that count survives paging: split_by_pages() hands each tag to the page it
## falls on, with its position inside that page.
##
## Only "{name:value}" (with a colon) is a tag. Button tokens such as {A} stay in the text.

const TAG_PATTERN: String = "\\{([a-z_]+):([^{}]*)\\}"
const BLANKS: String = " \n\t\r"

static var _regex: RegEx = null


## {"text": the text without tags, "tags": [{"pos": int, "name": String, "value": String}, ...]}
static func parse(raw: String) -> Dictionary:
	if _regex == null:
		_regex = RegEx.new()
		_regex.compile(TAG_PATTERN)
	var out: String = ""
	var tags: Array[Dictionary] = []
	var cursor: int = 0
	var seen: int = 0
	for found: RegExMatch in _regex.search_all(raw):
		var before: String = raw.substr(cursor, found.get_start() - cursor)
		out += before
		seen += visible_count(before)
		tags.append({"pos": seen, "name": found.get_string(1), "value": found.get_string(2).strip_edges()})
		cursor = found.get_end()
	out += raw.substr(cursor)
	return {"text": out, "tags": tags}


## How many characters are not spaces or line breaks.
static func visible_count(text: String) -> int:
	var count: int = 0
	for i: int in text.length():
		if not BLANKS.contains(text[i]):
			count += 1
	return count


## One array per page; each holds that page's tags as {"at": non-blank characters into the page,
## "name", "value"}. A tag at the very end of the text goes on the last page.
static func split_by_pages(pages: PackedStringArray, tags: Array) -> Array[Array]:
	var result: Array[Array] = []
	var start: int = 0
	for index: int in pages.size():
		var page_tags: Array[Dictionary] = []
		var end: int = start + visible_count(pages[index])
		var is_last: bool = index == pages.size() - 1
		for tag: Dictionary in tags:
			var pos: int = int(tag["pos"])
			if pos >= start and (pos < end or is_last):
				page_tags.append({"at": pos - start, "name": tag["name"], "value": tag["value"]})
		result.append(page_tags)
		start = end
	return result


## Problems with the tags in a raw line: names not in `known_names`, and (for face tags) faces not
## in `known_faces` when that list is not empty. Empty means clean.
static func problems(raw: String, known_names: Array, known_faces: Array = []) -> Array[String]:
	var list: Array[String] = []
	for tag: Dictionary in parse(raw)["tags"]:
		var name: String = str(tag["name"])
		if not known_names.has(name):
			list.append("unknown tag {%s:...}" % name)
		elif name == "face" and not known_faces.is_empty() and not known_faces.has(str(tag["value"])):
			list.append("unknown face '%s'" % str(tag["value"]))
	return list
