class_name WorksWarp
extends Node
## The jump-to-floor cheat (M4-1): in a debug build, `]` jumps to the next room of the Spillway and the
## works and `[` to the previous one (the order is data/world/works.json "warp"), through the SceneRouter,
## onto the room's default arrival spawn. Every works room carries one of these nodes. Does nothing in a
## release build. Tests call warp_by(step).

## SceneRouter to use. Null means the autoload.
var router: Node = null
## Off in tests that call warp_by() by hand.
var read_engine_input: bool = true


var _next_was: bool = false
var _prev_was: bool = false


func _process(_delta: float) -> void:
	if not read_engine_input or not OS.is_debug_build():
		return
	var next_down: bool = _key_down("next_key", "bracketright")
	var prev_down: bool = _key_down("prev_key", "bracketleft")
	if next_down and not _next_was:
		warp_by(1)
	elif prev_down and not _prev_was:
		warp_by(-1)
	_next_was = next_down
	_prev_was = prev_down


func _key_down(key: String, fallback: String) -> bool:
	var code: Key = OS.find_keycode_from_string(str(WorksData.section("warp").get(key, fallback)))
	return code != KEY_NONE and Input.is_key_pressed(code)


## The room id `step` places from the current room in the works' order (wraps), or "" when this is not one.
func target_for(step: int) -> String:
	var order: Array = WorksData.section("warp").get("rooms", [])
	var room: Node = get_parent()
	var here: String = str(room.get("room_id")) if room != null else ""
	var index: int = order.find(here)
	if index < 0:
		return ""
	return str(order[posmod(index + step, order.size())])


## Jumps `step` rooms along. Returns false when there is nowhere to go or the router is busy.
func warp_by(step: int) -> bool:
	var wanted: String = target_for(step)
	var route: Node = router if router != null else get_node_or_null("/root/SceneRouter")
	if wanted.is_empty() or route == null or bool(route.call("is_busy")):
		return false
	route.call("go_to", wanted, "")
	return true
