class_name BellRack
extends Node3D
## The Bell Gallery's four brass bells and their tune. Each Bell child reports a ring here. Ring them in
## the order of the tune on the napkin (data/world/works.json "bells": bell ids in order): a wrong bell is
## a sour clang and the tune starts over (no penalty, no fail state); the right five open the hatch in the
## floor (flag `bells_solved`, which shows the hatch chest). Once solved the bells just ring.

signal rang(bell_id: String, outcome: String)
signal solved

const OUTCOME_NEXT: String = "next"
const OUTCOME_WRONG: String = "wrong"
const OUTCOME_SOLVED: String = "solved"
const OUTCOME_DONE: String = "done"

## GameState to use. Null means the autoload.
var game_state: Node = null
var progress: int = 0


func tune() -> Array[String]:
	var found: Array[String] = []
	for bell_id: Variant in WorksData.section("bells").get("tune", []):
		found.append(str(bell_id))
	return found


func flag_id() -> String:
	return str(WorksData.section("bells").get("flag", "bells_solved"))


func is_solved() -> bool:
	return WorldProgress.has_flag(flag_id(), game_state)


## One bell was rung. Returns "next" (right so far), "wrong" (back to the start), "solved" (the last note)
## or "done" (already solved; they just ring).
func ring(bell_id: String) -> String:
	var outcome: String = step_tune(tune(), progress, bell_id, is_solved())
	match outcome:
		OUTCOME_NEXT:
			progress += 1
		OUTCOME_WRONG:
			progress = 0
		OUTCOME_SOLVED:
			progress = 0
			WorldProgress.set_flag(flag_id(), game_state)
			_reveal_hatch()
			solved.emit()
	rang.emit(bell_id, outcome)
	return outcome


## The puzzle's rule on its own, so a test can check it without a room. `progress` is how many right notes
## have been rung so far.
static func step_tune(tune_order: Array[String], progress_now: int, bell_id: String, already_solved: bool) -> String:
	if already_solved:
		return OUTCOME_DONE
	if progress_now < tune_order.size() and tune_order[progress_now] == bell_id:
		return OUTCOME_SOLVED if progress_now + 1 >= tune_order.size() else OUTCOME_NEXT
	return OUTCOME_WRONG


## The hatch chest (a Crate named HatchChest next to the rack) appears.
func _reveal_hatch() -> void:
	var chest: Crate = get_parent().get_node_or_null("HatchChest") as Crate if get_parent() != null else null
	if chest != null:
		chest.reveal()
