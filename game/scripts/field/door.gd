class_name Door
extends RoomProp
## A door in a wall. Red goes through by walking into it or by pressing the one button (the "open"
## icon); the SceneRouter fades and loads the other room at the named spawn. Where it leads, and
## what it needs, comes from data/world/placements.json ("doors"):
##   to_room, to_spawn      the target room and spawn marker (rooms.json)
##   requires {item, count, consume, flag}   a key item (how many: `count`, default 1; Kasp's cards are counted, not
##                          used up) and/or a story flag; consume takes the item once
##   locked_message         what Red reads when it will not open (so a locked door says what it wants);
##                          {have} and {need} are filled in with the item count held and wanted
##   unlocked_message       shown the first time the key works
##   width                  a wider doorway than the default (stairs, arches)
##   style                  "panel" (a slab in a wall, the default), "mat" (a lit doormat on an open
##                          front edge, no slab) or "arch" (nothing drawn: a gate whose look the room scene supplies)
##   label                  a small sign over it
## Once a locked door has been opened it stays open (remembered through GameState).
##
## Orientation: the door's local +Z side is the room side, the side Red stands on. Placeholder look: a
## slab in the wall with a small reader light (red locked, green open); a child "Model" replaces it.

signal went_through(to_room: String, to_spawn: String)
signal bumped_locked

const UNLOCK_PREFIX: String = "door_"
const PANEL_TINT: Color = Color(0.45, 0.32, 0.22)
const READER_LOCKED: Color = Color(1.0, 0.25, 0.2)
const READER_OPEN: Color = Color(0.35, 1.0, 0.45)
const FLOOR_BAND: float = 1.0

## SceneRouter to use. Null means the autoload.
var router: Node = null

var _armed: bool = false
var _reader: MeshInstance3D = null
var _reader_open: bool = false
var _look_known: bool = false


func _ready() -> void:
	if door_data().is_empty():
		push_error("Door %s: no door '%s' in data/world/placements.json" % [name, placement_id])
	make_interactable(Interactable.Kind.OPEN, tuning.door_reach, use)
	if not has_custom_model():
		_build()
	_refresh_look()


func _physics_process(_delta: float) -> void:
	_refresh_look()
	_check_walk_in()


func door_data() -> Dictionary:
	return Placements.door(placement_id)


func get_target_room() -> String:
	return str(door_data().get("to_room", ""))


func get_target_spawn() -> String:
	return str(door_data().get("to_spawn", ""))


func requirements() -> Dictionary:
	return door_data().get("requires", {})


func is_locked_by_data() -> bool:
	return not requirements().is_empty()


func unlock_id() -> String:
	return UNLOCK_PREFIX + placement_id


## True when Red can go through right now: nothing required, already unlocked, or she has the key.
func is_unlocked() -> bool:
	var needs: Dictionary = requirements()
	if needs.is_empty() or WorldProgress.is_opened(unlock_id(), game_state):
		return true
	return _requirements_met(needs)


## The message Red reads when it will not open.
func locked_message() -> String:
	var custom: String = str(door_data().get("locked_message", ""))
	if not custom.is_empty():
		var needs: Dictionary = requirements()
		var item_id: String = str(needs.get("item", ""))
		var have: int = int(state().call("item_count", item_id)) if not item_id.is_empty() else 0
		return custom.replace("{have}", str(have)).replace("{need}", str(int(needs.get("count", 1))))
	return Placements.text("locked_default")


## Red uses the door. Returns true when she did something (went through or read the lock).
func use(_player: CharacterBody3D, interactor: PlayerInteractor) -> bool:
	var route: Node = _router()
	if route != null and bool(route.call("is_busy")):
		return false
	if not is_unlocked():
		bumped_locked.emit()
		var refusal: Array[String] = [locked_message()]
		say(refusal, interactor)
		return true
	var needs: Dictionary = requirements()
	if not needs.is_empty() and not WorldProgress.is_opened(unlock_id(), game_state):
		var item_id: String = str(needs.get("item", ""))
		if not item_id.is_empty() and bool(needs.get("consume", false)):
			state().call("remove_item", item_id, 1)
		WorldProgress.mark_opened(unlock_id(), game_state)
		var message: String = str(door_data().get("unlocked_message", ""))
		var welcome: Array[String] = [message]
		if not message.is_empty() and interactor != null and say(welcome, interactor):
			interactor.runner.conversation_finished.connect(_go_after_message, CONNECT_ONE_SHOT)
			return true
	_go()
	return true


## Goes through, with no checks (the lock was already handled).
func _go() -> void:
	var route: Node = _router()
	if route == null:
		push_warning("Door %s: no SceneRouter" % name)
		return
	went_through.emit(get_target_room(), get_target_spawn())
	route.call("go_to", get_target_room(), get_target_spawn())


func _go_after_message(_conversation_id: String) -> void:
	if is_inside_tree():
		_go()


func _router() -> Node:
	if router != null:
		return router
	return get_node_or_null("/root/SceneRouter")


func _requirements_met(needs: Dictionary) -> bool:
	var item_id: String = str(needs.get("item", ""))
	if not item_id.is_empty() and int(state().call("item_count", item_id)) < maxi(int(needs.get("count", 1)), 1):
		return false
	return WorldProgress.has_flag(str(needs.get("flag", "")), game_state) or str(needs.get("flag", "")).is_empty()


## Walking into the door counts as using it, but only after Red has been out of its zone since the
## room loaded or since the last bump (so arriving in front of a door never sends her back).
func half_width() -> float:
	var wide: float = float(door_data().get("width", 0.0))
	return wide * 0.5 if wide > 0.0 else tuning.door_trigger_half_width


func _check_walk_in() -> void:
	var player: CharacterBody3D = get_player()
	if player == null:
		return
	var local: Vector3 = to_local(player.global_position)
	var inside: bool = absf(local.x) <= half_width() and local.z > -0.4 \
			and local.z <= tuning.door_trigger_depth and absf(local.y) < FLOOR_BAND
	if not inside:
		_armed = true
		return
	if not _armed or HeroLink.is_frozen(player) or HeroLink.is_scripted(player):
		return
	var interactor: PlayerInteractor = get_interactor()
	if interactor != null and not interactor.can_interact():
		return
	var into: Vector3 = -global_basis.z
	into.y = 0.0
	var push: float = HeroLink.get_move_direction(player).dot(into.normalized()) * HeroLink.get_stick(player).length()
	if push < tuning.door_min_push_speed:
		return
	_armed = false
	use(player, interactor)


func _refresh_look() -> void:
	var open_now: bool = is_unlocked()
	if _reader == null or (_look_known and open_now == _reader_open):
		return
	_look_known = true
	_reader_open = open_now
	_reader.material_override = PropLook.glow(READER_OPEN if open_now else READER_LOCKED, 1.6)


func _build() -> void:
	var size: Vector3 = tuning.door_panel
	var wide: float = float(door_data().get("width", 0.0))
	if wide > 0.0:
		size.x = wide
	var door_style: String = str(door_data().get("style", "panel"))
	if door_style == "mat":
		var mat: MeshInstance3D = PropLook.box(Vector3(size.x, 0.03, 0.8), PropLook.glow(Color(1.0, 0.8, 0.35), 0.9), "Mat")
		mat.position = Vector3(0.0, 0.02, 0.35)
		add_child(mat)
	elif door_style == "panel":
		var panel: MeshInstance3D = PropLook.box(size, PropLook.lit(PANEL_TINT), "Panel")
		panel.position.y = size.y * 0.5
		add_child(panel)
		_reader = PropLook.box(Vector3(0.12, 0.12, 0.06), PropLook.glow(READER_LOCKED, 1.6), "Reader")
		_reader.position = Vector3(size.x * 0.5 + 0.14, 1.1, size.z * 0.5)
		add_child(_reader)
		add_child(PropLook.solid_box(size, Vector3(0.0, size.y * 0.5, 0.0), "Solid"))
	var text: String = str(door_data().get("label", ""))
	if not text.is_empty():
		var label: Label3D = Label3D.new()
		label.name = "Label"
		label.text = text
		label.pixel_size = 0.012
		label.font_size = 28
		label.outline_size = 10
		label.modulate = Color(1.0, 0.95, 0.8)
		label.outline_modulate = Color(0.05, 0.05, 0.1)
		label.no_depth_test = true
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		label.position = Vector3(0.0, size.y + 0.45 if door_style == "panel" else 1.0, 0.1)
		add_child(label)
