extends TestCase
## TextWrap: word wrap with the real dialogue font, explicit line breaks, long words, paging.


func _font() -> Font:
	return UiFonts.get_font("dialogue")


func _size() -> int:
	return UiFonts.get_size("dialogue")


func test_short_text_stays_on_one_line() -> void:
	var lines: PackedStringArray = TextWrap.wrap(_font(), _size(), "Hello there", 200)
	assert_eq(lines, PackedStringArray(["Hello there"]))


func test_explicit_line_breaks_are_kept() -> void:
	var lines: PackedStringArray = TextWrap.wrap(_font(), _size(), "TEST ROOM\nPLEASE DO NOT", 300)
	assert_eq(lines, PackedStringArray(["TEST ROOM", "PLEASE DO NOT"]))


func test_long_text_wraps_and_every_line_fits() -> void:
	var text: String = "The quick brown pup jumps over the lazy lamp while the whole crew watches in silence"
	var width: int = 120
	var lines: PackedStringArray = TextWrap.wrap(_font(), _size(), text, width)
	assert_gt(lines.size(), 2)
	for line: String in lines:
		assert_le(TextWrap.text_width(_font(), _size(), line), width, line)
	assert_eq(" ".join(lines), text, "no words lost or reordered")


func test_a_word_wider_than_the_limit_is_split() -> void:
	var lines: PackedStringArray = TextWrap.wrap(_font(), _size(), "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 60)
	assert_gt(lines.size(), 1)
	for line: String in lines:
		assert_le(TextWrap.text_width(_font(), _size(), line), 60)
	assert_eq("".join(lines), "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")


func test_paginate_groups_lines() -> void:
	var pages: PackedStringArray = TextWrap.paginate(PackedStringArray(["a", "b", "c", "d", "e"]), 3)
	assert_eq(pages, PackedStringArray(["a\nb\nc", "d\ne"]))


func test_paginate_empty_text_gives_one_empty_page() -> void:
	assert_eq(TextWrap.paginate(PackedStringArray(), 3), PackedStringArray([""]))
