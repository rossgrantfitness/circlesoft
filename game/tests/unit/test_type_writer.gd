extends TestCase
## TypeWriter: characters appear at the set speed, punctuation pauses, line breaks cost nothing,
## and finish() reveals the rest.

const PAUSES: Dictionary = {",": 0.5, ".": 1.0}


func test_first_character_appears_immediately() -> void:
	var writer: TypeWriter = TypeWriter.new()
	writer.start("abc", 10.0)
	assert_eq(writer.advance(0.0), "a")
	assert_eq(writer.get_visible_text(), "a")


func test_speed_sets_how_many_characters_per_second() -> void:
	var writer: TypeWriter = TypeWriter.new()
	writer.start("abcdefghij", 10.0)
	writer.advance(0.0)
	var typed: String = writer.advance(0.35)
	assert_eq(typed, "bcd", "0.1 s per character: three more in 0.35 s")
	assert_eq(writer.get_visible_count(), 4)
	assert_false(writer.is_done())


func test_a_long_frame_reveals_several_characters_in_order() -> void:
	var writer: TypeWriter = TypeWriter.new()
	writer.start("hello", 10.0)
	assert_eq(writer.advance(5.0), "hello")
	assert_true(writer.is_done())
	assert_eq(writer.advance(1.0), "", "nothing more once done")


func test_punctuation_that_ends_a_word_pauses() -> void:
	var writer: TypeWriter = TypeWriter.new()
	writer.start("a, b", 10.0, PAUSES)
	writer.advance(0.0)      # a
	writer.advance(0.1)      # ,
	assert_eq(writer.get_visible_text(), "a,")
	writer.advance(0.5)      # still inside the 0.1 + 0.5 pause
	assert_eq(writer.get_visible_text(), "a,", "paused after the comma")
	writer.advance(0.2)
	assert_eq(writer.get_visible_text(), "a, ", "the space follows once the pause is over")


func test_a_run_of_punctuation_pauses_once_at_the_end() -> void:
	var writer: TypeWriter = TypeWriter.new()
	writer.start("a... b", 10.0, PAUSES)
	var typed: String = writer.advance(0.35)
	assert_eq(typed, "a...", "no pause between the dots")


func test_line_breaks_are_free_and_travel_with_the_previous_character() -> void:
	var writer: TypeWriter = TypeWriter.new()
	writer.start("ab\ncd", 10.0)
	assert_eq(writer.advance(0.0), "a")
	assert_eq(writer.advance(0.1), "b\n")
	assert_eq(writer.advance(0.1), "c")


func test_finish_reveals_the_rest() -> void:
	var writer: TypeWriter = TypeWriter.new()
	writer.start("hello world", 5.0)
	writer.advance(0.0)
	assert_eq(writer.finish(), "ello world")
	assert_true(writer.is_done())
	assert_eq(writer.get_visible_text(), "hello world")
