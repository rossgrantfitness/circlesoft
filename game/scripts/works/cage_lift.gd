class_name CageLift
extends RoomProp
## The freight lift in the mast's old cage: at the Sump (T0), the Power Room (T3) and the Drone Line (T4).
## Dead until the lever in the Power Room is thrown (flag `lift_powered`): "No power." After that, press the
## button at the cage door and pick a stop from a little menu; the SceneRouter does the fade and puts Red on
## that floor's `from_lift` spot. It is the shortcut back down to the first save lamp, and it cannot strand
## anyone: the Sump stop only works once the lift is powered, and the lever is on the way up.
## Data: data/world/works.json "lift" (stops, labels, messages). `stop` defaults to the room's own id.
## Placeholder look: a 2 x 2 m wire box on the shaft, a lamp that goes from red to green when powered.

signal ride_started(to_room: String)

@export var stop: String = ""

## SceneRouter to ride with. Null means the autoload.
var router: Node = null
var prompt: LiftPrompt = null
var _lamp: MeshInstance3D = null
var _lit: bool = false


func _ready() -> void:
	make_interactable(Interactable.Kind.OPEN, float(WorksData.section("lift").get("reach", 1.4)), use)
	_build()
	_refresh_lamp()


func _physics_process(_delta: float) -> void:
	_refresh_lamp()


func stop_id() -> String:
	if not stop.is_empty():
		return stop
	var room: FieldRoom = get_room()
	return room.room_id if room != null else ""


func is_powered() -> bool:
	return WorldProgress.has_flag(str(WorksData.section("lift").get("flag", "lift_powered")), game_state)


## The stops Red can ride to from here: [{id, label}], in floor order, not counting this one.
func destinations() -> Array[Dictionary]:
	var lift: Dictionary = WorksData.section("lift")
	var found: Array[Dictionary] = []
	for room_id: Variant in lift.get("stops", []):
		if str(room_id) != stop_id():
			found.append({"id": str(room_id), "label": str(lift.get("labels", {}).get(str(room_id), str(room_id)))})
	return found


func use(_player: PlayerController, interactor: PlayerInteractor) -> bool:
	if prompt != null and is_instance_valid(prompt):
		return false
	if not is_powered():
		var dead: Dictionary = WorksData.section("lift").get("no_power", {})
		var lines: Array[String] = [str(dead.get(stop_id(), dead.get("default", "No power.")))]
		say(lines, interactor)
		return true
	prompt = LiftPrompt.open(get_tree(), destinations(), get_player())
	prompt.chosen.connect(ride_to)
	return true


## Rides to a stop (the router fades). Returns false when the lift is dead, the stop is unknown or the router is busy.
func ride_to(room_id: String) -> bool:
	if not is_powered() or room_id == stop_id():
		return false
	var known: bool = false
	for entry: Dictionary in destinations():
		known = known or str(entry["id"]) == room_id
	var route: Node = router if router != null else get_node_or_null("/root/SceneRouter")
	if not known or route == null or bool(route.call("is_busy")):
		return false
	ride_started.emit(room_id)
	route.call("go_to", room_id, str(WorksData.section("lift").get("spawn", "from_lift")))
	return true


func _refresh_lamp() -> void:
	var on: bool = is_powered()
	if _lamp == null or on == _lit:
		return
	_lit = on
	_lamp.material_override = PropLook.glow(Color(0.35, 1.0, 0.45) if on else Color(1.0, 0.25, 0.2), 1.6)


func _build() -> void:
	var bars: MeshInstance3D = PropLook.box(Vector3(2.0, 2.4, 0.08), PropLook.lit(Color(0.42, 0.46, 0.56)), "CageFront")
	bars.position = Vector3(0.0, 1.2, 0.0)
	add_child(bars)
	_lamp = PropLook.box(Vector3(0.14, 0.14, 0.06), PropLook.glow(Color(1.0, 0.25, 0.2), 1.6), "Lamp")
	_lamp.position = Vector3(0.0, 2.6, 0.05)
	add_child(_lamp)
