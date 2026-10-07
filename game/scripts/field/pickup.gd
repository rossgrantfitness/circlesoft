class_name Pickup
extends RoomProp
## A glinting item on the floor. Red takes it with the one button (the hand icon): the item and/or
## credits from data/world/placements.json go into GameState, "Got X!" shows in a box, and the id is
## remembered as opened so it never comes back (also after a save and load). If the bag is full of
## that item it stays.
##
## Look: a small spinning, bobbing gem plus a blinking spark (placeholder boxes).

signal taken

var _clock: float = 0.0
var _gem: MeshInstance3D = null
var _spark: MeshInstance3D = null
var _gone: bool = false


func _ready() -> void:
	if pickup_data().is_empty():
		push_error("Pickup %s: no pickup '%s' in data/world/placements.json" % [name, placement_id])
	make_interactable(Interactable.Kind.TAKE, tuning.pickup_reach, use)
	if WorldProgress.is_opened(placement_id, game_state):
		_vanish()
		return
	if not has_custom_model():
		_build_glint()
	_clock = float(placement_id.hash() % 1000) * 0.01
	# A pickup with "show_if" appears when its condition comes true (the dark window's reward).
	if pickup_data().has("show_if"):
		var gs: Node = state()
		if gs != null and gs.has_signal("flag_changed") and not gs.is_connected("flag_changed", _on_flag_changed):
			gs.connect("flag_changed", _on_flag_changed)
		_apply_show_if()


func _on_flag_changed(_flag_id: String, _value: bool) -> void:
	_apply_show_if()


func _apply_show_if() -> void:
	if _gone:
		return
	var on: bool = Conditions.met(pickup_data().get("show_if", {}), game_state)
	visible = on
	set_usable(on)


func _process(delta: float) -> void:
	step(delta)


## One animation step (bob, spin, sparkle). Public so tests can drive it.
func step(delta: float) -> void:
	_clock += delta
	if _gem == null:
		return
	var period: float = maxf(tuning.pickup_bob_period_s, 0.01)
	_gem.position.y = tuning.pickup_lift + tuning.pickup_bob_height * sin(_clock * TAU / period)
	_gem.rotation.y = deg_to_rad(tuning.pickup_spin_deg_per_s) * _clock
	_spark.visible = fmod(_clock, maxf(tuning.pickup_sparkle_period_s, 0.01)) < tuning.pickup_sparkle_period_s * 0.25
	_spark.position = _gem.position + Vector3(0.12, 0.16, 0.0)


func pickup_data() -> Dictionary:
	return Placements.pickup(placement_id)


func is_taken() -> bool:
	return _gone


## Red takes it. Returns true when she did something (took it, or was told the bag is full).
func use(_player: PlayerController, interactor: PlayerInteractor) -> bool:
	if _gone:
		return false
	var result: Dictionary = WorldProgress.grant(pickup_data(), game_state)
	var lines: Array[String] = []
	lines.assign(result["lines"])
	if bool(result["ok"]) and pickup_data().has("message_extra"):
		lines.append(str(pickup_data()["message_extra"]))
	say(lines, interactor)
	if not bool(result["ok"]):
		return true
	WorldProgress.mark_opened(placement_id, game_state)
	_sfx()
	_vanish()
	taken.emit()
	return true


func _vanish() -> void:
	_gone = true
	set_usable(false)
	if _gem != null:
		_gem.visible = false
		_spark.visible = false
	set_process(false)


func _sfx() -> void:
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", &"item_get")


func _build_glint() -> void:
	var size: float = tuning.pickup_size
	_gem = PropLook.box(Vector3(size, size, size), PropLook.glow(Color(1.0, 0.85, 0.3), 1.4), "Glint")
	_gem.position.y = tuning.pickup_lift
	_gem.rotation = Vector3(deg_to_rad(35.0), 0.0, deg_to_rad(35.0))
	add_child(_gem)
	_spark = PropLook.box(Vector3(size * 0.45, size * 0.45, size * 0.45), PropLook.glow(Color(1.0, 1.0, 0.85), 2.0), "Spark")
	add_child(_spark)
