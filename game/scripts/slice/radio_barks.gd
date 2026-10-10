class_name RadioBarks
extends Node
## Vela and Kasp in Red's ear (docs/slice/slice_tech_plan.md 3, "radio_bark"): the Writer's lines in data/dialogue/slice_barks.json,
## played through the HUD's radio box. Each conversation id in that file IS a bark id.
##
##   * Triggers: the room's `Barks/bark_*` markers (metadata `radius_m`). The first time Red walks within a marker's radius the
##     bark with the marker's name plays, once per run (the heard flag `bark_heard_<id>` is a normal story flag, so a knock-out
##     restart that rewinds flags lets the hint play again).
##   * `say(bark_id)` plays one by hand: the encounter runner's wave warnings, the boss and the loader use it. A bark with several
##     lines (Kasp's spec recitals) queues them back to back; ids listed in the file's `bark_variants` cycle through their
##     alternatives (the first time the first, then the next ...).
##   * Delivery: `hud.radio_say(speaker, text, priority)`; the HUD queues and times the lines. The `radio_said` signal also fires
##     for every line (tests, subtitles, the director's own listeners).
## A missing HUD or unknown id plays nothing and never errors.

signal radio_said(speaker: String, text: String)
signal bark_played(bark_id: String)

const DATA_ID: String = "dialogue/slice_barks"
const FLAG_PREFIX: String = "bark_heard_"

var room: Node3D = null
var hero: Node3D = null
## Off in tests that call tick() by hand.
var manual_ticks: bool = false
## Where the lines go. Null means the room's HUD (room.get_hud()).
var hud_override: Node = null

var _markers: Array[Dictionary] = []
var _doc: Dictionary = {}
var _turn: Dictionary[String, int] = {}


## Reads the room's `Barks/` markers. Returns how many there are.
func setup(for_room: Node3D) -> int:
	room = for_room
	hero = room.get("hero") as Node3D
	_doc = DataDB.get_dict(DATA_ID)
	_markers.clear()
	var level: Variant = room.get("level")
	var base: Node = level as Node if level != null else room
	var holder: Node = base.get_node_or_null("Barks")
	if holder != null:
		for child: Node in holder.get_children():
			if child is Node3D:
				_markers.append({"id": str(child.name), "node": child, "radius_m": float(child.get_meta("radius_m", 6.0))})
	set_physics_process(not manual_ticks)
	return _markers.size()


func marker_ids() -> Array[String]:
	var ids: Array[String] = []
	for marker: Dictionary in _markers:
		ids.append(str(marker["id"]))
	return ids


func _physics_process(_delta: float) -> void:
	tick()


## Checks the markers against Red. Returns the ids that played this step.
func tick() -> Array[String]:
	var played: Array[String] = []
	if hero == null or not is_instance_valid(hero):
		hero = room.get("hero") as Node3D if room != null else null
		if hero == null:
			return played
	for marker: Dictionary in _markers:
		var node: Node3D = marker["node"] as Node3D
		if not is_instance_valid(node) or _heard(str(marker["id"])):
			continue
		var flat: Vector3 = node.global_position - hero.global_position
		flat.y = 0.0
		if flat.length() <= float(marker["radius_m"]):
			_mark_heard(str(marker["id"]))
			if say(str(marker["id"])):
				played.append(str(marker["id"]))
	return played


## Plays a bark now. False for an id with no lines.
func say(bark_id: String, priority: bool = false) -> bool:
	var id: String = _resolve(bark_id)
	var lines: Array = (_doc.get("conversations", {}) as Dictionary).get(id, []) as Array
	if lines.is_empty():
		return false
	for raw: Variant in lines:
		var line: Dictionary = raw as Dictionary
		var speaker: String = str(line.get("speaker", ""))
		var text: String = str(line.get("text", ""))
		if text.is_empty():
			continue
		radio_said.emit(speaker, text)
		var hud: Node = _hud()
		if hud != null and hud.has_method("radio_say"):
			hud.call("radio_say", speaker, text, priority)
	bark_played.emit(id)
	return true


## An id that has variants plays the next alternative each time; any other id is itself.
func _resolve(bark_id: String) -> String:
	var variants: Dictionary = _doc.get("bark_variants", {}) as Dictionary
	if not variants.has(bark_id):
		return bark_id
	var list: Array = variants[bark_id] as Array
	if list.is_empty():
		return bark_id
	var at: int = int(_turn.get(bark_id, 0))
	_turn[bark_id] = at + 1
	return str(list[at % list.size()])


func _hud() -> Node:
	if hud_override != null and is_instance_valid(hud_override):
		return hud_override
	if room != null and room.has_method("get_hud"):
		return room.call("get_hud") as Node
	return null


func _state() -> Node:
	var state: Variant = room.get("game_state") if room != null else null
	if state is Node and is_instance_valid(state):
		return state as Node
	return get_node_or_null("/root/GameState")


func _heard(bark_id: String) -> bool:
	var state: Node = _state()
	return state != null and bool(state.call("get_flag", FLAG_PREFIX + bark_id))


func _mark_heard(bark_id: String) -> void:
	var state: Node = _state()
	if state != null:
		state.call("set_flag", FLAG_PREFIX + bark_id, true)
