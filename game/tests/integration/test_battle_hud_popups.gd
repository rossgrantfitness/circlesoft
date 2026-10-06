extends TestCase
## Pop-ups: rating lettering with the style guide's colors, damage and heal numbers, the Clutch "!",
## the skill-name slam. Text comes from data/text/battle.json and colors from data/ui/battle_ui.json.

const HUD_SCENE: String = "res://scenes/ui/battle/battle_hud.tscn"
const STEP: float = 0.0833

# docs/style_guide.md, "UI" table, Ratings row (the data files must say exactly this).
const GUIDE_COLORS: Dictionary = {
	"nice": ["#7FE0FF"],
	"rad": ["#FFD23F"],
	"totally_rad": ["#FF3E9A", "#FF9A2E", "#FFD23F"],
	"blocked": ["#8FB8FF"],
	"perfect_block": ["#FFF2B0"],
	"payback": ["#FF5A36"],
}
const GUIDE_TEXT: Dictionary = {
	"nice": "Nice!", "rad": "Rad!", "totally_rad": "TOTALLY RAD!",
	"blocked": "Blocked!", "perfect_block": "Perfect Block!", "payback": "Payback!",
}
# docs/style_guide.md, "Rating lettering" sizes (width in internal pixels).
const GUIDE_WIDTH: Dictionary = {
	"nice": 72, "rad": 64, "totally_rad": 168, "blocked": 80, "perfect_block": 144, "payback": 96,
}

var _audio: FakeAudio = null
var _hud: BattleHud = null
var _stub: BattleHudStub = null


func _setup() -> void:
	_audio = FakeAudio.new()
	_hud = (load(HUD_SCENE) as PackedScene).instantiate() as BattleHud
	_hud.manual_ticks = true
	_hud.animations_enabled = false
	_hud.audio.target = _audio
	add_to_root(_hud)
	_stub = BattleHudStub.new()
	_hud.bind(_stub)
	_stub.start()


func _judged(rating: String, side: String = "attack", owner_id: String = "red", index: int = 0) -> void:
	var info: Dictionary = {"actor": owner_id, "index": index, "side": side, "rating": rating, "delta_ms": 10}
	_stub.press_judged.emit(info)


func _popups_of(kind: BattlePopup.Kind) -> Array[BattlePopup]:
	var out: Array[BattlePopup] = []
	for popup: BattlePopup in _hud.get_popups():
		if popup.kind == kind:
			out.append(popup)
	return out


# ---- data matches the style guide ----

func test_rating_colors_in_the_data_match_the_style_guide() -> void:
	for id: String in GUIDE_COLORS:
		var hexes: Array = BattleUiData.ui("ratings.kinds.%s.colors" % id, [])
		var wanted: Array = GUIDE_COLORS[id]
		assert_eq(hexes.size(), wanted.size(), id)
		for i: int in mini(hexes.size(), wanted.size()):
			assert_eq(str(hexes[i]).to_upper(), str(wanted[i]).to_upper(), "%s color %d" % [id, i])


func test_rating_words_in_the_data_match_the_design_doc() -> void:
	for id: String in GUIDE_TEXT:
		assert_eq(BattleUiData.text("ratings.%s" % id), GUIDE_TEXT[id])
	assert_eq(BattleUiData.text("ko"), "K.O.!")


func test_every_rating_popup_uses_its_text_and_color_from_data() -> void:
	for id: String in GUIDE_COLORS:
		var popup: BattlePopup = BattlePopup.make_rating(id)
		own(popup)
		assert_eq(popup.text, GUIDE_TEXT[id], id)
		assert_eq(popup.get_colors().size(), (GUIDE_COLORS[id] as Array).size(), id)
		assert_eq(popup.get_fill_color().to_html(false).to_upper(), str((GUIDE_COLORS[id] as Array)[0]).trim_prefix("#").to_upper(), id)


func test_lettering_fits_the_style_guide_sizes() -> void:
	for id: String in GUIDE_WIDTH:
		var popup: BattlePopup = BattlePopup.make_rating(id)
		own(popup)
		assert_le(popup.measure_width(), float(GUIDE_WIDTH[id]) * 1.15, "%s is %d px wide, guide says %d" % [id, int(popup.measure_width()), GUIDE_WIDTH[id]])
		assert_ge(popup.measure_width(), float(GUIDE_WIDTH[id]) * 0.6, id)


# ---- rating pop-ups from press_judged ----

func test_attack_ratings_pop_up_as_nice_rad_and_totally_rad() -> void:
	_setup()
	for pair: Array in [["nice", "Nice!"], ["rad", "Rad!"], ["totally_rad", "TOTALLY RAD!"]]:
		_judged(pair[0])
		var popups: Array[BattlePopup] = _popups_of(BattlePopup.Kind.RATING)
		assert_eq(popups.back().text, pair[1])
		assert_eq(popups.back().style_id, pair[0])


func test_block_ratings_map_to_blocked_and_perfect_block() -> void:
	_setup()
	_judged("nice", "block", "otis")
	assert_eq(_popups_of(BattlePopup.Kind.RATING).back().text, "Blocked!")
	_judged("rad", "block", "otis")
	assert_eq(_popups_of(BattlePopup.Kind.RATING).back().text, "Blocked!")
	_judged("totally_rad", "block", "otis")
	assert_eq(_popups_of(BattlePopup.Kind.RATING).back().text, "Perfect Block!")


func test_a_miss_shows_nothing() -> void:
	_setup()
	_judged("miss")
	_judged("miss", "block", "otis")
	assert_eq(_hud.get_popups().size(), 0, "missing never hurts and never nags")


func test_rating_pops_up_over_the_press_owner_from_the_action() -> void:
	_setup()
	# A block press: the action's actor is the enemy, the press owner (who gets the "!") is Otis.
	_stub.action_started.emit({"actor": "e1", "kind": "attack", "targets": ["otis"], "show_name": false,
			"presses": [{"index": 0, "type": "tap", "side": "block", "cue_ms": 400, "owner_id": "otis"}]})
	_judged("rad", "block", "e1", 0)
	var popup: BattlePopup = _popups_of(BattlePopup.Kind.RATING).back()
	assert_almost_eq(popup.position.x, clampf(_hud.position_of("otis").x, 40.0, 344.0), 40.0)
	assert_lt(absf(popup.position.y - (_hud.position_of("otis").y + BattleUiData.ui_vec("anchors.rating").y)), 1.0)


func test_ratings_stay_on_screen_at_the_edge() -> void:
	_setup()
	var stage: Node = own(Node.new()) as Node
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node\nfunc screen_pos_of(id: String) -> Vector2:\n\treturn Vector2(380, 100)\n"
	script.reload()
	stage.set_script(script)
	_hud.stage = stage
	_judged("totally_rad")
	var popup: BattlePopup = _popups_of(BattlePopup.Kind.RATING).back()
	assert_le(popup.position.x + popup.measure_width() / 2.0, 384.0)


func test_rating_plays_its_sound() -> void:
	_setup()
	_judged("totally_rad")
	assert_has(_audio.sfx_ids, "battle_rating_totally_rad")
	_judged("nice")
	assert_has(_audio.sfx_ids, "battle_rating_nice")
	_judged("rad")
	assert_has(_audio.sfx_ids, "battle_rating_rad")
	_audio.sfx_ids.clear()
	_judged("rad", "block", "otis")
	_judged("totally_rad", "block", "otis")
	assert_eq(_audio.sfx_ids, [], "block sounds belong to the stage (it plays them from the hit signal), so none here")


func test_payback_pops_up_when_a_hit_says_so() -> void:
	_setup()
	_stub.hit.emit({"source": "otis", "target": "e1", "amount": 9, "kind": "damage", "blocked": "none", "payback": true})
	var texts: Array[String] = []
	for popup: BattlePopup in _popups_of(BattlePopup.Kind.RATING):
		texts.append(popup.text)
	assert_eq(texts, ["Payback!"])
	assert_eq(_popups_of(BattlePopup.Kind.RATING)[0].get_fill_color().to_html(false).to_upper(), "FF5A36")
	assert_does_not_have(_audio.sfx_ids, "battle_payback")
	_judged("totally_rad", "block", "otis")
	var perfect: BattlePopup = _popups_of(BattlePopup.Kind.RATING).back()
	assert_gt(absf(perfect.position.x - _popups_of(BattlePopup.Kind.RATING)[0].position.x) + absf(perfect.position.y - _popups_of(BattlePopup.Kind.RATING)[0].position.y), 20.0, "Payback! (over the enemy) and Perfect Block! (over the defender) don't stack")


# ---- TOTALLY RAD! colors ----

func test_totally_rad_cycles_its_three_colors_every_two_steps() -> void:
	var popup: BattlePopup = BattlePopup.make_rating("totally_rad")
	own(popup)
	var seen: Array[String] = []
	for i: int in 6:
		popup.set_age(float(i) * 2.0 * STEP + 0.01)
		seen.append(popup.get_fill_color().to_html(false).to_upper())
	assert_eq(seen, ["FF3E9A", "FF9A2E", "FFD23F", "FF3E9A", "FF9A2E", "FFD23F"])
	popup.set_age(STEP + 0.01)
	assert_eq(popup.get_fill_color().to_html(false).to_upper(), "FF3E9A", "holds a color for two steps")


func test_single_color_ratings_never_change_color() -> void:
	var popup: BattlePopup = BattlePopup.make_rating("rad")
	own(popup)
	popup.set_age(0.1)
	var first: Color = popup.get_fill_color()
	popup.set_age(0.5)
	assert_eq(popup.get_fill_color(), first)


# ---- timing ----

func test_popup_pops_in_with_the_three_step_overshoot_then_holds_and_fades() -> void:
	var popup: BattlePopup = BattlePopup.make_rating("nice")
	own(popup)
	var scales: Array[float] = []
	for step: int in 4:
		popup.set_age(float(step) * STEP + 0.01)
		scales.append(popup.get_pop_scale())
	assert_eq(scales, [0.6, 1.2, 1.0, 1.0])
	assert_eq(popup.get_phase(), 1)
	popup.set_age(0.3 + 0.3)
	assert_eq(popup.get_phase(), 1, "holds about 0.6 s")
	assert_eq(popup.get_alpha(), 1.0)
	popup.set_age(3.0 * STEP + 0.6 + 0.01)
	assert_eq(popup.get_phase(), 2)
	assert_lt(popup.get_alpha(), 1.0)
	assert_le(popup.get_drift(), 8.0, "drifts up at most 8 px")
	popup.set_age(popup.get_duration() - 0.001)
	assert_ge(popup.get_drift(), 8.0)


func test_popups_finish_and_leave_the_hud() -> void:
	_setup()
	_judged("rad")
	assert_eq(_hud.get_popups().size(), 1)
	_hud.tick(0.3)
	assert_eq(_hud.get_popups().size(), 1)
	_hud.tick(2.0)
	assert_eq(_hud.get_popups().size(), 0)


func test_scale_is_stepped_not_smooth() -> void:
	var popup: BattlePopup = BattlePopup.make_number(12, false)
	own(popup)
	popup.set_age(0.01)
	var a: float = popup.get_pop_scale()
	popup.set_age(STEP * 0.9)
	assert_eq(popup.get_pop_scale(), a, "no easing inside a step")


# ---- numbers ----

func test_damage_numbers_are_white_and_heals_are_lime() -> void:
	_setup()
	_stub.hit.emit({"source": "red", "target": "e1", "amount": 24, "kind": "damage", "blocked": "none", "payback": false})
	_stub.hit.emit({"source": "otis", "target": "mox", "amount": 18, "kind": "heal", "blocked": "none", "payback": false})
	var numbers: Array[BattlePopup] = _popups_of(BattlePopup.Kind.NUMBER)
	assert_eq(numbers.size(), 2)
	assert_eq(numbers[0].text, "24")
	assert_eq(numbers[0].get_fill_color().to_html(false).to_upper(), "FFFFFF")
	assert_eq(numbers[1].text, "18")
	assert_eq(numbers[1].get_fill_color().to_html(false).to_upper(), "9BE35A")


func test_no_number_for_a_fully_blocked_hit() -> void:
	_setup()
	_stub.hit.emit({"source": "e1", "target": "otis", "amount": 0, "kind": "damage", "blocked": "perfect", "payback": false})
	assert_eq(_popups_of(BattlePopup.Kind.NUMBER).size(), 0)


func test_numbers_on_the_same_fighter_stack_instead_of_overlapping() -> void:
	_setup()
	_stub.hit.emit({"source": "red", "target": "e1", "amount": 10, "kind": "damage", "blocked": "none", "payback": false})
	_stub.hit.emit({"source": "red", "target": "e1", "amount": 11, "kind": "damage", "blocked": "none", "payback": false})
	var numbers: Array[BattlePopup] = _popups_of(BattlePopup.Kind.NUMBER)
	assert_lt(numbers[1].position.y, numbers[0].position.y)


# ---- the "!" cue ----

func test_show_cue_puts_a_bang_over_the_owner() -> void:
	_setup()
	var cue: BattlePopup = _hud.show_cue("red")
	assert_eq(cue.kind, BattlePopup.Kind.CUE)
	assert_eq(cue.text, "!")
	assert_eq(cue.position, _hud.position_of("red") + BattleUiData.ui_vec("anchors.cue"))


func test_a_boss_cue_is_the_bigger_double_bang() -> void:
	_setup()
	var cue: BattlePopup = _hud.show_cue("e1", true)
	assert_eq(cue.text, "!!")
	assert_eq(cue.style_id, "cue_big")


func test_a_second_cue_on_the_same_fighter_replaces_the_first() -> void:
	_setup()
	_hud.show_cue("red")
	_hud.show_cue("red")
	assert_eq(_popups_of(BattlePopup.Kind.CUE).size(), 1)
	_hud.show_cue("otis")
	assert_eq(_popups_of(BattlePopup.Kind.CUE).size(), 2)


func test_the_hud_draws_the_cue_when_the_stage_turns_its_own_marker_off() -> void:
	_setup()
	var stage: Node = own(Node.new()) as Node
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node\nsignal cue_fired(owner_id: String, press_index: int, stage_pos: Vector2)\nvar cue_marker_enabled: bool = true\nfunc screen_pos_of(id: String) -> Vector2:\n\treturn Vector2(100, 100)\n"
	script.reload()
	stage.set_script(script)
	_hud.stage = stage
	stage.emit_signal("cue_fired", "red", 0, Vector2(100, 100))
	assert_eq(_popups_of(BattlePopup.Kind.CUE).size(), 0, "the stage's own marker is on, so no double")
	stage.set("cue_marker_enabled", false)
	stage.emit_signal("cue_fired", "red", 0, Vector2(100, 100))
	assert_eq(_popups_of(BattlePopup.Kind.CUE).size(), 1)


# ---- the skill name slam ----

func test_signature_move_slams_its_name_onto_the_screen() -> void:
	_setup()
	_stub.action_started.emit({"actor": "red", "kind": "skill", "skill_id": "porch_light", "name": "Porch Light",
			"targets": ["e1"], "presses": [], "show_name": true})
	var slams: Array[BattlePopup] = _popups_of(BattlePopup.Kind.SLAM)
	assert_eq(slams.size(), 1)
	assert_eq(slams[0].text, "Porch Light")
	slams[0].set_age(0.01)
	assert_gt(slams[0].get_pop_scale(), 1.5, "starts huge and slams down")
	slams[0].set_age(0.5)
	assert_eq(slams[0].get_pop_scale(), 1.0)


func test_ordinary_moves_do_not_slam() -> void:
	_setup()
	_stub.action_started.emit({"actor": "red", "kind": "attack", "name": "Attack", "targets": ["e1"], "presses": [], "show_name": false})
	assert_eq(_popups_of(BattlePopup.Kind.SLAM).size(), 0)


func test_the_slam_has_no_speaker_label() -> void:
	_setup()
	_stub.action_started.emit({"actor": "red", "kind": "skill", "name": "Porch Light", "targets": ["e1"], "presses": [], "show_name": true})
	assert_eq(_hud.get_banner().get_current_text(), "", "Red never says it: no banner, no line of dialogue")
	assert_false(_audio.voices.size() > 0)
