class_name ActionHud
extends SandboxHud
## The action HUD (VS-11, plan 2.5 and 4.6): everything the sandbox HUD shows (Red's health, the Noise meter, the Lights
## On bulb, the lock-on reticle, enemy bars, damage numbers, call-outs) plus the slice's own parts, bound to ANY combat
## host: the combat sandbox or an ActionRoom. One instance lives on the UI stage for the whole run; each room re-binds it
## (`bind(room)`; ActionRoom does this itself when it finds the node in group "slice_hud").
##
## New parts:
##   HackPanel      the battery (top-left), the Quiet Hours static, the hijack timer
##   CommandDeck    bottom-left: Attack / Hack / Item, and the hack list (Ross's pick for Decision 1)
##   BossBar        boss name, health, phase pips
##   RadioBark      Vela's voice in Red's ear
##   LocationCard   the area name on entering a new area
##   ContinueScreen on a knock-out: Continue / Quit to title
##   SlicePause     Esc / Start: Resume, Menu, Controls, Tuning, Quit to title
##
## The Lights On bulb, the Noise meter and the Lamp Flare tag follow data/slice/features.json (SandboxHud does that part,
## so the sandbox obeys the switches too).
##
## What it listens to on the host (everything optional; a host that lacks one just doesn't feed that part):
##   director.battery_changed(charge, capacity)         the Combat Programmer's VS-8 signal
##   director.hack_locked(active, ms)                   Quiet Hours
##   director.hack_selected(hack_id)                    pick mode: the pick changed; auto mode: the last one used
##   director.hack_cast(info)                           {hack, ...}: a cast began (the cooldown sweep, "last used")
##   director.hack_refused(info)                        {hack, reason, ...}: a button press that fired nothing (the bar shakes)
##   director.hijack_changed(info)                      {target, active, duration_s}: the Link timer and the ring over the target
##   director.radio_said(speaker, text)                 a bark for the radio box (not in the director yet; radio_say() works today)
##   director.feature_changed(id, on)                   (SandboxHud)
##   host.knocked_out_rule(rule)                        Red was knocked out: open the Continue screen (not for rule "none")
##   host.continue_started(room, spawn)                 the restart began: close it
##   host.get_boss_fight() -> Object with signals boss_bar_shown(info), boss_hp_changed(hp, hp_max),
##                          boss_phase_changed(index, name), boss_bar_hidden()   (or the director carrying the same)
## And it calls `host.continue_after_knockout()` when Continue is chosen.
## The feel knobs hack_pick_mode, hack_cost_scale and hack_free_cast are read live.

## Continue was chosen; the host has been asked to restart.
signal continue_requested
## "Menu" was chosen in the pause menu (the town systems open the field menu).
signal field_menu_requested

const SCENE_PATH_ACTION: String = "res://scenes/ui/slice/action_hud.tscn"
const SLICE_PAUSE_SCENE: String = "res://scenes/ui/slice/slice_pause.tscn"
const RULE_NONE: String = "none"
const ROUTER_PATH: NodePath = ^"/root/SceneRouter"
const ACTION_DECK_OPEN: StringName = &"deck_open"
const ACTION_DECK_SCROLL: StringName = &"deck_scroll"
const KNOB_SLOWMO: String = "deck_slowmo"
const KNOB_SLOWMO_SCALE: String = "deck_slowmo_scale"
const KNOB_PICK_MODE: String = "hack_pick_mode"
const KNOB_COST_SCALE: String = "hack_cost_scale"
const KNOB_FREE: String = "hack_free_cast"
const KNOB_COOLDOWN_SCALE: String = "hack_cooldown_scale"

## On: listens to the SceneRouter autoload for the location card. Tests turn it off.
var auto_router: bool = true

var _hack_panel: HackPanel = null
var _deck: CommandDeck = null
var _slowmo_active: bool = false
var _boss_bar: BossBar = null
var _radio: RadioBark = null
var _location: LocationCard = null
var _continue: ContinueScreen = null
var _slice_pause: SlicePause = null
var _router: Node = null
var _boss_source: Object = null


func _init() -> void:
	auto_quit = false


func _ready() -> void:
	super()
	if auto_router and _router == null:
		attach_router(get_node_or_null(ROUTER_PATH))


func _pause_scene_path() -> String:
	return SLICE_PAUSE_SCENE


func _build() -> void:
	super()
	_slice_pause = _pause as SlicePause
	if _slice_pause != null:
		_slice_pause.field_menu_requested.connect(_on_pause_menu_chosen)
		_slice_pause.feel_requested.connect(_on_pause_feel_chosen)
	_hack_panel = _add_part(HackPanel.new(), "HackPanel") as HackPanel
	_deck = _add_part(CommandDeck.new(), "CommandDeck") as CommandDeck
	_boss_bar = _add_part(BossBar.new(), "BossBar") as BossBar
	_radio = _add_part(RadioBark.new(), "RadioBark") as RadioBark
	_radio.audio = audio
	_location = _add_part(LocationCard.new(), "LocationCard") as LocationCard
	_continue = ContinueScreen.new()
	_continue.name = "ContinueScreen"
	_continue.audio = audio
	_continue.manual_ticks = manual_ticks
	_continue.listen_input = listen_input
	_continue.animations_enabled = animations_enabled
	_continue.continue_chosen.connect(_on_continue_chosen)
	_continue.quit_chosen.connect(_on_quit_chosen)
	add_child(_continue)
	_hack_panel.model = HackPanelModel.load_default()
	_deck.hacks = _hack_panel.model
	ensure_deck_actions()
	_place_corners()


func _add_part(part: Control, part_name: String) -> Control:
	part.name = part_name
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.size = size
	add_child(part)
	return part


func _place_corners() -> void:
	super()
	for part: Control in [_hack_panel, _deck, _boss_bar, _radio, _location]:
		if part != null:
			part.position = Vector2.ZERO
			part.size = size


# ---- the parts, for the rest of the game and the tests ----

func get_hack_panel() -> HackPanel:
	return _hack_panel


func get_deck() -> CommandDeck:
	return _deck


func get_boss_bar() -> BossBar:
	return _boss_bar


func get_radio() -> RadioBark:
	return _radio


func get_location_card() -> LocationCard:
	return _location


func get_continue_screen() -> ContinueScreen:
	return _continue


func get_slice_pause() -> SlicePause:
	return _slice_pause


func is_menu_open() -> bool:
	return super() or (_continue != null and _continue.is_open())


# ---- binding ----

func bind(target: Object) -> void:
	super(target)
	_hack_panel.model = HackPanelModel.load_default()
	_deck.hacks = _hack_panel.model
	_deck.model = CommandDeckModel.new()
	_set_slowmo(false)
	_boss_bar.model.hide_bar()
	_boss_bar.model.shown = false
	_continue.close_screen()
	if sandbox == null:
		return
	if _director != null:
		var battery: Variant = _director.get(&"battery")
		if battery is Object and (battery as Object).has_method(&"charge") and (battery as Object).has_method(&"capacity"):
			_hack_panel.model.set_battery(float((battery as Object).call(&"charge")), float((battery as Object).call(&"capacity")))
		_link(_director, &"battery_changed", _on_battery_changed)
		_link(_director, &"hack_locked", _on_hack_locked)
		_link(_director, &"hack_selected", _on_hack_selected)
		_link(_director, &"hack_cast", _on_hack_cast)
		_link(_director, &"hack_refused", _on_hack_refused)
		_link(_director, &"hijack_changed", _on_hijack_changed)
		_link(_director, &"radio_said", _on_radio_said)
	_boss_source = _call(sandbox, &"get_boss_fight") as Object
	if _boss_source == null:
		_boss_source = _director
	_link(_boss_source, &"boss_bar_shown", show_boss_bar)
	_link(_boss_source, &"boss_hp_changed", set_boss_hp)
	_link(_boss_source, &"boss_phase_changed", set_boss_phase)
	_link(_boss_source, &"boss_bar_hidden", hide_boss_bar)
	_link(sandbox, &"knocked_out_rule", _on_knocked_out)
	_link(sandbox, &"continue_started", _on_continue_started)
	if _knobs != null:
		_link(_knobs, &"changed", _on_knob_changed)
		_read_knobs()


func unbind() -> void:
	_boss_source = null
	_set_slowmo(false)
	super()


func _exit_tree() -> void:
	_set_slowmo(false)
	super()


## The pick mode and cost knobs, read into the panel's model.
func _read_knobs() -> void:
	if _knobs == null or _hack_panel == null:
		return
	var knobs: FeelKnobs = _knobs as FeelKnobs
	if knobs == null:
		return
	var model: HackPanelModel = _hack_panel.model
	if knobs.has(KNOB_PICK_MODE):
		model.set_mode_from_data(knobs.get_s(KNOB_PICK_MODE))
	if knobs.has(KNOB_COST_SCALE):
		model.cost_scale = knobs.get_f(KNOB_COST_SCALE)
	if knobs.has(KNOB_COOLDOWN_SCALE):
		model.cooldown_scale = knobs.get_f(KNOB_COOLDOWN_SCALE)
	if knobs.has(KNOB_FREE):
		model.free_cast = knobs.get_b(KNOB_FREE)


func _on_knob_changed(id: String, _value: Variant) -> void:
	if id.begins_with("hack_"):
		_read_knobs()


# ---- hack signals ----

func _on_battery_changed(charge: float, capacity: float) -> void:
	_hack_panel.model.set_battery(charge, capacity)


func _on_hack_locked(active: bool, ms: float) -> void:
	_hack_panel.model.set_lock(active, ms)


func _on_hack_selected(hack_id: StringName) -> void:
	var model: HackPanelModel = _hack_panel.model
	model.select(str(hack_id))
	if model.is_auto():
		model.last_used = str(hack_id)
	else:
		audio.sfx("tick")


## A cast began: the cooldown sweep runs for the hack's cooldown (hacks.json, scaled by the feel knob).
func _on_hack_cast(info: Dictionary) -> void:
	var model: HackPanelModel = _hack_panel.model
	var id: String = str(info.get("hack", ""))
	model.note_cast(id, model.cooldown_ms_of(id))
	_deck.model.close_submenu()


## A press that fired nothing: the bar shakes, and a couple of reasons get a call-out.
func _on_hack_refused(info: Dictionary) -> void:
	var model: HackPanelModel = _hack_panel.model
	model.note_denied(str(info.get("hack", model.highlight_id())))
	match str(info.get("reason", "")):
		"no_signal":
			_call_out(SliceUiData.text("hack.no_signal"))
		"not_full":
			_call_out(SliceUiData.text("hack.need_full"))


func _on_hijack_changed(info: Dictionary) -> void:
	var id: String = str(info.get("target", ""))
	var duration: float = float(info.get("duration_s", 0.0))
	if bool(info.get("active", false)):
		_hack_panel.model.set_hijack(id, duration, duration)
	else:
		_hack_panel.model.clear_hijack(id)


## The second button used to say "coming later"; in the slice it casts, so the old call-out stays quiet.
func _on_hack_pressed(_info: Dictionary) -> void:
	pass


func _on_radio_said(speaker: Variant, text: String) -> void:
	_radio.say(str(speaker), text)


# ---- boss bar ----

## Starts the boss bar: {name, hp, hp_max, phases: [{id, name}], phase}.
func show_boss_bar(info: Dictionary) -> void:
	_boss_bar.model.show_bar(info)


func set_boss_hp(hp: float, hp_max: float = -1.0) -> void:
	_boss_bar.model.set_hp(hp, hp_max)


func set_boss_phase(index: int, phase_name: String = "") -> void:
	_boss_bar.model.set_phase(index, phase_name)


func hide_boss_bar() -> void:
	_boss_bar.model.hide_bar()


# ---- radio ----

## Vela (or anyone) speaks in Red's ear. `speaker` is an id from data/text/slice_ui.json "radio.speakers".
func radio_say(speaker: String, text: String, priority: bool = false) -> bool:
	return _radio.say(speaker, text, priority)


# ---- location card ----

## Attaches to the SceneRouter: every `room_entered` shows the location card for that room.
func attach_router(router: Node) -> void:
	if _router != null and is_instance_valid(_router) and _router.has_signal(&"room_entered") and _router.is_connected(&"room_entered", _on_room_entered):
		_router.disconnect(&"room_entered", _on_room_entered)
	_router = router
	if _router != null and _router.has_signal(&"room_entered"):
		_router.connect(&"room_entered", _on_room_entered)


func _on_room_entered(room_id: String) -> void:
	var entry: Dictionary = {}
	if _router != null and _router.has_method(&"get_room_entry"):
		entry = _router.call(&"get_room_entry", room_id) as Dictionary
	show_location(entry)


## Shows the card for a rooms.json entry (see LocationCard.show_for_room).
func show_location(entry: Dictionary) -> bool:
	return _location.show_for_room(entry)


# ---- knock-out ----

func _on_knocked_out(rule: String) -> void:
	if rule == RULE_NONE:
		return
	var cost: int = 0
	var retry: Variant = DataDB.get_value("slice/slice", "retry", {})
	if retry is Dictionary:
		cost = int((retry as Dictionary).get("credit_cost", 0))
	_continue.open_screen(rule, _boss_bar.model.is_visible(), cost)


func _on_continue_started(_room: String, _spawn: String) -> void:
	_continue.close_screen()


func _on_continue_chosen() -> void:
	var host: Object = sandbox
	_continue.close_screen()
	continue_requested.emit()
	if host != null and host.has_method(&"continue_after_knockout"):
		host.call(&"continue_after_knockout")


func _on_quit_chosen() -> void:
	_continue.close_screen()
	quit_requested.emit()
	if auto_quit and is_inside_tree():
		get_tree().quit()


# ---- pause ----

func open_pause() -> void:
	if _slice_pause != null:
		_slice_pause.menu_enabled = not get_signal_connection_list(&"field_menu_requested").is_empty()
	super()


func _on_pause_menu_chosen() -> void:
	field_menu_requested.emit()


func _on_pause_feel_chosen() -> void:
	_panel.open_panel()


# ---- the command deck ----

## Adds the deck's two buttons if the project does not have them: R / d-pad up chooses (opens or closes the hack list),
## G / d-pad down moves the focus to the next row (Attack, Hack, Item). The pick itself is the wheel, d-pad left / right
## and keys 1 to 4 (HackCaster owns those) and the hack button fires the current hack.
static func ensure_deck_actions() -> void:
	_ensure_action(ACTION_DECK_OPEN, KEY_R, JOY_BUTTON_DPAD_UP)
	_ensure_action(ACTION_DECK_SCROLL, KEY_G, JOY_BUTTON_DPAD_DOWN)


static func _ensure_action(action: StringName, key: Key, button: JoyButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action, key_event)
	var pad_event: InputEventJoypadButton = InputEventJoypadButton.new()
	pad_event.button_index = button
	InputMap.action_add_event(action, pad_event)


func _input(event: InputEvent) -> void:
	super(event)
	if listen_input and handle_deck_event(event):
		get_viewport().set_input_as_handled()


## One input event for the deck. True when it was the deck's. (Not while a menu is open.)
func handle_deck_event(event: InputEvent) -> bool:
	if is_menu_open() or event.is_echo():
		return false
	if InputMap.has_action(ACTION_DECK_OPEN) and event.is_action_pressed(ACTION_DECK_OPEN):
		deck_choose()
		return true
	if InputMap.has_action(ACTION_DECK_SCROLL) and event.is_action_pressed(ACTION_DECK_SCROLL):
		deck_scroll(1)
		return true
	return false


## Moves the deck's focus one row.
func deck_scroll(direction: int) -> void:
	_deck.model.scroll(direction)
	audio.sfx("tick")


## "Choose" on the focused row: opens or closes the hack list, or says an unbuilt row is coming later.
func deck_choose() -> String:
	var result: String = _deck.model.choose(_hack_panel.model.is_auto())
	audio.sfx("confirm" if result == "opened" else "tick")
	return result


## The pick, for hosts that want to set it from the UI (a mouse click on the list). Calls the player's HackCaster when it
## has `select_id`; otherwise the HUD just remembers it.
func pick_hack(id: String) -> void:
	_hack_panel.model.select(id)
	var player: Object = _call(sandbox, &"get_player") as Object
	var caster: Object = _call(player, &"hack_caster") as Object
	if caster != null and caster.has_method(&"select_id"):
		caster.call(&"select_id", StringName(id))


# ---- slow time while the list is open (a tuning switch, off by default) ----

func is_slowmo_active() -> bool:
	return _slowmo_active


func _wants_slowmo() -> bool:
	if _knobs == null or not _deck.model.submenu_open or is_menu_open():
		return false
	var knobs: FeelKnobs = _knobs as FeelKnobs
	return knobs != null and knobs.has(KNOB_SLOWMO) and knobs.get_b(KNOB_SLOWMO)


func _set_slowmo(on: bool) -> void:
	if on == _slowmo_active:
		return
	_slowmo_active = on
	if on:
		var knobs: FeelKnobs = _knobs as FeelKnobs
		var scale_to: float = knobs.get_f(KNOB_SLOWMO_SCALE) if knobs != null and knobs.has(KNOB_SLOWMO_SCALE) else 0.35
		Engine.time_scale = clampf(scale_to, 0.05, 1.0)
	else:
		Engine.time_scale = 1.0


## The HUD runs on real time even while the game is slowed.
func _process(delta: float) -> void:
	tick(delta / maxf(Engine.time_scale, 0.05) if _slowmo_active else delta)


# ---- time ----

func tick(delta: float) -> void:
	super(delta)
	_hack_panel.visible = not is_menu_open()
	_deck.visible = not is_menu_open()
	_hack_panel.tick(delta)
	_deck.tick(delta)
	_set_slowmo(_wants_slowmo())
	_boss_bar.tick(delta)
	_radio.tick(delta)
	_location.tick(delta)


# ---- the ring over a hijacked machine ----

func _draw_world() -> void:
	super()
	var model: HackPanelModel = _hack_panel.model
	for id: String in model.hijack_ids():
		var at: Vector2 = position_of(id, &"head")
		if not at.is_finite():
			continue
		_draw_ring(Vector2(roundf(at.x), roundf(at.y - SliceUiData.num("hijack_ring.above_px", 6))), model.hijack_frac(id), model.hijack_left_s(id))


## A ring that drains clockwise as the link runs out, blinking in the last seconds.
func _draw_ring(center: Vector2, frac: float, left_s: float) -> void:
	var radius: float = SliceUiData.num("hijack_ring.radius", 9)
	var width: float = SliceUiData.num("hijack_ring.width", 2)
	var low: bool = left_s <= SliceUiData.num("hijack_ring.low_s", 2.0)
	if low and int(_clock / 0.12) % 2 == 1:
		return
	_world.draw_arc(center, radius + 1.0, -PI / 2.0, -PI / 2.0 + TAU, 24, SliceUiData.color("hijack_back"), width + 2.0)
	_world.draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * clampf(frac, 0.0, 1.0), 24, SliceUiData.color("hijack"), width)
