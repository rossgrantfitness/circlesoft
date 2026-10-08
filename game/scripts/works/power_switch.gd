class_name PowerSwitch
extends RoomProp
## The power lever in the Power Room, inside the wire cage. Throw it and the old generator coughs on, the
## plant's lights come up and the freight lift wakes (flag `lift_powered`, data/world/works.json "lever").
## Placeholder look: a box lever on a hinge that falls over when thrown.

signal thrown

var _arm: Node3D = null
var _lamp: MeshInstance3D = null


func _ready() -> void:
	make_interactable(Interactable.Kind.OPEN, float(WorksData.section("lever").get("reach", 1.2)), use)
	_build()
	if is_thrown():
		_show_thrown()


func flag_id() -> String:
	return str(WorksData.section("lever").get("flag", "lift_powered"))


func is_thrown() -> bool:
	return WorldProgress.has_flag(flag_id(), game_state)


func use(_player: PlayerController, interactor: PlayerInteractor) -> bool:
	var lever: Dictionary = WorksData.section("lever")
	if is_thrown():
		var again: Array[String] = [str(lever.get("already", ""))]
		say(again, interactor)
		return true
	WorldProgress.set_flag(flag_id(), game_state)
	_show_thrown()
	var lines: Array[String] = []
	for line: Variant in lever.get("thrown", []):
		lines.append(str(line))
	say(lines, interactor)
	thrown.emit()
	return true


func _show_thrown() -> void:
	if _arm != null:
		_arm.rotation.x = deg_to_rad(70.0)
	if _lamp != null:
		_lamp.material_override = PropLook.glow(Color(0.35, 1.0, 0.45), 1.6)


func _build() -> void:
	var base: MeshInstance3D = PropLook.box(Vector3(0.5, 0.5, 0.4), PropLook.lit(Color(0.4, 0.42, 0.48)), "Base")
	base.position.y = 0.25
	add_child(base)
	_arm = Node3D.new()
	_arm.name = "Arm"
	_arm.position = Vector3(0.0, 0.55, 0.0)
	_arm.rotation.x = deg_to_rad(-70.0)
	var rod: MeshInstance3D = PropLook.box(Vector3(0.08, 0.7, 0.08), PropLook.lit(Color(0.85, 0.64, 0.25)), "Rod")
	rod.position.y = 0.35
	_arm.add_child(rod)
	var grip: MeshInstance3D = PropLook.box(Vector3(0.2, 0.12, 0.12), PropLook.lit(Color(0.7, 0.2, 0.18)), "Grip")
	grip.position.y = 0.72
	_arm.add_child(grip)
	add_child(_arm)
	_lamp = PropLook.box(Vector3(0.1, 0.1, 0.05), PropLook.glow(Color(1.0, 0.25, 0.2), 1.6), "Lamp")
	_lamp.position = Vector3(0.0, 0.4, 0.22)
	add_child(_lamp)
	add_child(PropLook.solid_box(Vector3(0.5, 0.5, 0.4), Vector3(0.0, 0.25, 0.0), "Solid"))
