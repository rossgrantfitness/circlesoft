class_name RoomSnapshot
extends RefCounted
## What a knock-out restart puts back (docs/slice/slice_tech_plan.md 2.4): when Red walks into a room, the room records
## her health and battery (a HeroSession), the sword in her hand, her items and credits, and the flags and opened ids set
## so far. After a knock-out the room is loaded again from this, so she has exactly what she walked in with.
##
## **Sticky** ids survive the rewind: a puzzle flag or an opened door that is marked `sticky` in the placements (an opened
## fuse-box door stays open) keeps its current value, even if it was set after the snapshot was taken. Pure data, no nodes.

var session: Dictionary = {}
var bag: Dictionary = {}
var flags: Dictionary = {}
var opened: Array = []
var credits: int = 0


## Takes a snapshot from a hero session (HeroSession.to_dict()) and GameState.run_snapshot().
static func capture(hero_session: Dictionary, run: Dictionary) -> RoomSnapshot:
	var snap: RoomSnapshot = RoomSnapshot.new()
	snap.session = hero_session.duplicate(true)
	snap.bag = (run.get("bag", {}) as Dictionary).duplicate(true)
	snap.flags = (run.get("flags", {}) as Dictionary).duplicate(true)
	snap.opened = (run.get("opened", []) as Array).duplicate()
	snap.credits = int(run.get("credits", 0))
	return snap


static func from_dict(data: Dictionary) -> RoomSnapshot:
	return capture(data.get("session", {}) as Dictionary, data)


func to_dict() -> Dictionary:
	return {"session": session.duplicate(true), "bag": bag.duplicate(true), "flags": flags.duplicate(true),
			"opened": opened.duplicate(), "credits": credits}


## The run state to restore: the snapshot, with every sticky id that is set in `current` kept set. `sticky` lists flag ids
## and opened ids. `credit_cost` is taken off the snapshot's credits (never below 0).
func restored(current: Dictionary, sticky: Array, credit_cost: int = 0) -> Dictionary:
	var out_flags: Dictionary = flags.duplicate()
	var out_opened: Array = opened.duplicate()
	var now_flags: Dictionary = current.get("flags", {}) as Dictionary
	var now_opened: Array = current.get("opened", []) as Array
	for raw: Variant in sticky:
		var id: String = str(raw)
		if now_flags.has(id) and bool(now_flags[id]):
			out_flags[id] = true
		if now_opened.has(id) and not out_opened.has(id):
			out_opened.append(id)
	return {"bag": bag.duplicate(), "flags": out_flags, "opened": out_opened, "credits": maxi(credits - maxi(credit_cost, 0), 0)}
