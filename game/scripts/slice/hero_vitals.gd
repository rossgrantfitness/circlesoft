class_name HeroVitals
extends RefCounted
## Red's health lives on the live ActionPlayer, but the field menu's Items page heals the party member "red" in GameState.
## While the menu is open the two are kept in step: push() copies the live health into the member (and her maximum), pull()
## copies the member's health back to the hero when the menu closes, so a healing item works on the action Red.

const HERO_MEMBER: String = "red"


static func push(state: Node, hero: Node) -> void:
	if state == null or hero == null or not is_instance_valid(hero) or not state.has_method("update_member"):
		return
	state.call("update_member", HERO_MEMBER, {"hp": int(hero.get("hp")), "hp_max": int(hero.get("hp_max"))})


## Reads the member's health back. Returns the change in health (0 when nothing happened).
static func pull(state: Node, hero: Node) -> int:
	if state == null or hero == null or not is_instance_valid(hero) or not state.has_method("get_member"):
		return 0
	var member: Dictionary = state.call("get_member", HERO_MEMBER)
	if member.is_empty() or not member.has("hp"):
		return 0
	var before: int = int(hero.get("hp"))
	var wanted: int = clampi(int(member["hp"]), 1 if before > 0 else 0, maxi(int(hero.get("hp_max")), 1))
	if wanted == before:
		return 0
	hero.set("hp", wanted)
	return wanted - before
