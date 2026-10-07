class_name DialogueSpeakers
extends RefCounted
## Who is speaking and how they are shown, read from the "speakers" block of data/ui/dialogue_ui.json.
## Shared by the dialogue runner and the speech bubble so both agree.
##
## Three kinds of speaker:
##   named cast   listed under "speakers" (Otis, Mox...). Speech bubble over their head, and a
##                portrait slot when the entry has a "portrait" key (see data/ui/portraits.json).
##   narrator / signs   listed with "style": "box": the plain box at the bottom of the screen.
##   crowd NPCs   not listed. Any id that starts with a prefix in "crowd.prefixes" ("crowd_baker")
##                is a crowd NPC: plain box, no portrait, and the name tag is the rest of the id
##                ("Baker"). A listed speaker with "crowd": true counts too. A line may also carry
##                its own "name" (shown on the tag) and "style" ("box" or "bubble").

const STYLE_BUBBLE: String = "bubble"
const STYLE_BOX: String = "box"


## The speaker's merged data (the default speaker, then the crowd defaults or the listed entry).
static func entry(ui: Dictionary, speaker_id: String) -> Dictionary:
	var merged: Dictionary = (ui["default_speaker"] as Dictionary).duplicate()
	var known: Dictionary = ui.get("speakers", {})
	if known.has(speaker_id):
		merged.merge(known[speaker_id], true)
	elif is_crowd(ui, speaker_id):
		merged.merge(ui.get("crowd_speaker", {}), true)
		merged["name"] = crowd_name(ui, speaker_id)
	elif not speaker_id.is_empty():
		merged["name"] = speaker_id.capitalize()
	return merged


## True for crowd NPCs (listed with "crowd": true, or an unlisted id with a crowd prefix).
static func is_crowd(ui: Dictionary, speaker_id: String) -> bool:
	var known: Dictionary = ui.get("speakers", {})
	if known.has(speaker_id):
		return bool((known[speaker_id] as Dictionary).get("crowd", false))
	return not _prefix_of(ui, speaker_id).is_empty()


## "crowd_dock_hand" -> "Dock Hand".
static func crowd_name(ui: Dictionary, speaker_id: String) -> String:
	var prefix: String = _prefix_of(ui, speaker_id)
	return speaker_id.trim_prefix(prefix).replace("_", " ").capitalize()


## "bubble" or "box" for a line. The line's own "style" wins, then the speaker's listed style, then
## crowd NPCs get the box, then anyone with no body in the room gets the box; everyone else a bubble.
static func style_for(ui: Dictionary, speaker_id: String, has_body: bool, line_style: String = "") -> String:
	if line_style == STYLE_BOX or line_style == STYLE_BUBBLE:
		return line_style
	var data: Dictionary = entry(ui, speaker_id)
	if str(data.get("style", STYLE_BUBBLE)) == STYLE_BOX:
		return STYLE_BOX
	if is_crowd(ui, speaker_id) or not has_body:
		return STYLE_BOX
	return STYLE_BUBBLE


## The portrait key for a speaker ("" = no portrait). Crowd NPCs never have one.
static func portrait_key(ui: Dictionary, speaker_id: String) -> String:
	if is_crowd(ui, speaker_id):
		return ""
	return str(entry(ui, speaker_id).get("portrait", ""))


static func _prefix_of(ui: Dictionary, speaker_id: String) -> String:
	for prefix: Variant in (ui.get("crowd", {}) as Dictionary).get("prefixes", []):
		if not str(prefix).is_empty() and speaker_id.begins_with(str(prefix)):
			return str(prefix)
	return ""
