class_name JobBoard
extends RoomProp
## The courier office's job board: one press opens the list, you pick a job, and the board takes it
## (gives the job's key item and sets its flag) or shows where it stands. Jobs, texts and rewards
## are data (data/world/jobs.json); the board only knows the rules:
##   not taken -> shows the description, then takes it (give_items + set_flags from the job's "take")
##   taken     -> reminds you what to do ("taken_text")
##   done      -> the DONE stamp ("done_text")
## A job is taken when its taken_flag is set and done when its done_flag is. The list is made fresh
## each time, so it always shows the current state in the labels.

const MENU_ID: String = "__job_board_menu"
const PICK_PREFIX: String = "__job_board_"
const SPEAKER: String = "narrator"

signal job_taken(job_id: String)


func _ready() -> void:
	make_interactable(Interactable.Kind.EXAMINE, float(Placements.entry("spots", placement_id).get("reach", 1.5)), use)


## "available", "taken" or "done".
func job_state(job_id: String) -> String:
	var job: Dictionary = Placements.job(job_id)
	if WorldProgress.has_flag(str(job.get("done_flag", "")), game_state):
		return "done"
	if WorldProgress.has_flag(str(job.get("taken_flag", "")), game_state):
		return "taken"
	return "available"


func job_ids() -> Array[String]:
	var ids: Array[String] = []
	var jobs: Dictionary = DataDB.get_dict(Placements.JOBS_ID).get("jobs", {})
	var ordered: Array = jobs.keys()
	ordered.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(jobs[a].get("order", 0)) < int(jobs[b].get("order", 0)))
	for id: Variant in ordered:
		if str(jobs[id].get("board", "")) == placement_id:
			ids.append(str(id))
	return ids


func use(_player: CharacterBody3D, interactor: PlayerInteractor) -> bool:
	var runner: DialogueRunner = interactor.runner
	if runner == null:
		return false
	var text: Dictionary = DataDB.get_dict(Placements.JOBS_ID).get("text", {})
	var labels: Array = []
	var nexts: Array = []
	var conversations: Dictionary = {}
	for job_id: String in job_ids():
		var job: Dictionary = Placements.job(job_id)
		var state: String = job_state(job_id)
		labels.append("%s %s" % [str(job.get("title", job_id)), str(text.get("tag_" + state, ""))])
		var pick_id: String = PICK_PREFIX + job_id + "_" + state
		nexts.append(pick_id)
		conversations[pick_id] = _lines_for(job_id, job, state)
	conversations[MENU_ID] = [{"speaker": SPEAKER, "text": str(text.get("menu", "JOB BOARD")), "choice": labels, "next": nexts}]
	runner.get_conversation_ids()  # index the data first: add_conversations marks the runner as indexed
	runner.add_conversations(conversations)
	return interactor.start_conversation(MENU_ID, interactable)


func _lines_for(job_id: String, job: Dictionary, state: String) -> Array:
	var lines: Array = []
	match state:
		"done":
			for line: Variant in job.get("done_text", []):
				lines.append({"speaker": SPEAKER, "text": str(line)})
		"taken":
			for line: Variant in job.get("taken_text", []):
				lines.append({"speaker": SPEAKER, "text": str(line)})
		_:
			for line: Variant in job.get("description", []):
				lines.append({"speaker": SPEAKER, "text": str(line)})
			var take: Dictionary = job.get("take", {})
			var last: Dictionary = {"speaker": SPEAKER, "text": str(take.get("text", "Job taken."))}
			var give: Array = []
			for entry: Variant in take.get("give_items", []):
				give.append(str((entry as Dictionary).get("item", "")))
			if not give.is_empty():
				last["give_item"] = give
			last["set_flag"] = take.get("set_flags", [])
			lines.append(last)
			_connect_taken(job_id)
	if lines.is_empty():
		lines.append({"speaker": SPEAKER, "text": "..."})
	return lines


func _connect_taken(job_id: String) -> void:
	var runner: DialogueRunner = get_interactor().runner if get_interactor() != null else null
	if runner == null:
		return
	var once: Callable = func(_conversation_id: String) -> void:
		if job_state(job_id) != "available":
			job_taken.emit(job_id)
	if not runner.conversation_finished.is_connected(once):
		runner.conversation_finished.connect(once, CONNECT_ONE_SHOT)
