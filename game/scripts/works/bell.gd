class_name Bell
extends RoomProp
## One of the Bell Gallery's brass bells. Press the button beside it to ring it; its BellRack parent keeps
## the tune. Sizes (big, middle, little, tiny) and every message are in data/world/works.json "bells".
## Without the Bell Tune Napkin a wrong note gets a hint from Mox (a second line in the box).
## Placeholder look: a brass cylinder on a short chain, sized by `bell_id`.

@export_enum("big", "middle", "little", "tiny") var bell_id: String = "big"

var _body: MeshInstance3D = null
var _swing: float = 0.0
var _rack: BellRack = null


func _ready() -> void:
	make_interactable(Interactable.Kind.OPEN, float(WorksData.section("bells").get("reach", 1.2)), use)
	_build()


func _process(delta: float) -> void:
	if _swing > 0.0 and _body != null:
		_swing = maxf(_swing - delta, 0.0)
		_body.rotation.z = sin(_swing * 18.0) * _swing * 0.5


func rack() -> BellRack:
	if _rack == null or not is_instance_valid(_rack):
		var node: Node = get_parent()
		while node != null and not node is BellRack:
			node = node.get_parent()
		_rack = node as BellRack
	return _rack


func use(_player: PlayerController, interactor: PlayerInteractor) -> bool:
	var bells: Dictionary = WorksData.section("bells")
	var keeper: BellRack = rack()
	if keeper == null:
		return false
	keeper.game_state = game_state
	var outcome: String = keeper.ring(bell_id)
	_swing = 0.8
	var audio: UiAudio = UiAudio.new()
	audio.sfx("back" if outcome == BellRack.OUTCOME_WRONG else "confirm")
	var lines: Array[String] = []
	match outcome:
		BellRack.OUTCOME_WRONG:
			lines.append(str(bells.get("sour", "")))
			if not bool(state().call("has_item", str(bells.get("napkin_item", "")))):
				lines.append("Mox: " + str(bells.get("mox_hint", "")))
		BellRack.OUTCOME_SOLVED:
			for line: Variant in bells.get("solved", []):
				lines.append(str(line))
		BellRack.OUTCOME_DONE:
			lines.append(str(bells.get("after", "")))
		_:
			lines.append(str(bells.get("ring", {}).get(bell_id, "")))
	say(lines, interactor)
	return true


func _build() -> void:
	var size: float = float(WorksData.section("bells").get("sizes", {}).get(bell_id, 0.6))
	var bell: MeshInstance3D = PropLook.box(Vector3(size * 0.6, size, size * 0.6), PropLook.lit(Color(0.85, 0.64, 0.25)), "Bell")
	bell.position = Vector3(0.0, 1.5 - size * 0.5, 0.0)
	_body = bell
	add_child(bell)
	var chain: MeshInstance3D = PropLook.box(Vector3(0.04, 1.4 - size, 0.04), PropLook.lit(Color(0.4, 0.4, 0.42)), "Chain")
	chain.position = Vector3(0.0, 1.5 - size + (1.4 - size) * 0.5, 0.0)
	add_child(chain)
	add_child(PropLook.solid_box(Vector3(0.3, 1.0, 0.3), Vector3(0.0, 0.5, 0.0), "Post"))
