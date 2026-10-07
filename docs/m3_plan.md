# Milestone 3 plan: Harrow Landing (town systems)

> Ross, 2026-10-07: "proceed with the next phase of development and don't spend too much time modeling characters. Right now everything is just placeholder graphics until we can get better graphics API implementation."
> Source of truth for what to build: docs/task_board.md rows M3-1 to M3-10 and the approved design doc sections (Exploration, Towns, Interaction, Equipment & items, Economy, Menus, Save system). Architecture: docs/tech_plan.md "Core systems". M3-11 (Ross's art) is skipped: placeholders only.

## Placeholder art rule for M3 (all agents)
- **No new character modeling.** Townsfolk reuse existing models (`red_shiba`, `chr_otis`, `chr_mox`, `npc_old_zero`, enemy blockouts) with a tint/accessory swap through materials, or the simple capsule-and-sphere NPC fallback in `npc.gd`. At most an hour-cheap prop here and there.
- Sets are graybox: boxes, planes and a few reused props in the PSX look, readable from the diorama camera. Labels/colors may stand in for buildings.
- Everything loads by path and is data-driven so better art drops in later without code changes (see the style guide's Model contract).

## Order
1. **Now, in parallel:** M3-1 map draft (Creative Director, goes to Ross for sign-off) · M3-2 + M3-5 (Gameplay Programmer A) · M3-9 (Gameplay Programmer B) · M3-6 (Battle Programmer) · M3-7 + M3-8 (UI Programmer A) · M3-3 + M3-10 (UI Programmer B).
2. **After Ross signs off M3-1:** M3-4, build Harrow Landing with placeholders (Gameplay Programmer A).
3. Integration, QA, playtest, Windows/Mac build for Ross.

## Who owns what (don't edit another owner's files; ask through the integrator)
| Owner | Task | Files |
|---|---|---|
| Creative Director | M3-1 | `docs/maps/harrow_landing.md` (+ the road and tower pages), simple ASCII/box diagrams |
| Gameplay Programmer A | M3-2, M3-5 (then M3-4) | `scripts/field/*` (except what UI owns), `scripts/encounter/*`, new `scripts/core/scene_router.gd`, `data/world/rooms.json`, `data/world/placements.json`, `scenes/rooms/*`, `scenes/props/*`, room/door/pickup/follow/field-enemy tests |
| Gameplay Programmer B | M3-9 | `scripts/core/save_manager.gd` (new autoload), **`scripts/core/game_state.gd` (sole editor during M3)**, save tests and fixtures, game over → Retry wiring in `main.gd` only where save is involved |
| Battle Programmer | M3-6 | `data/items/*` (items.json, equipment.json), `scripts/inventory/*` (Bag helpers, Equipment, StatCalc, ShopLogic), battle data that reads gear, item/gear tests |
| UI Programmer A | M3-7, M3-8 | `scripts/ui/field_menu*.gd` + new menu pages, `scripts/ui/shop/*`, `data/ui/field_menu.json`, `data/text/field_menu.json`, `data/shops/*`, `data/ui/shop_ui.json` |
| UI Programmer B | M3-3, M3-10 | dialogue presentation (`scripts/ui/speech_bubble.gd`, text box, portraits), `scripts/dialogue/*`, `scripts/ui/title_screen.gd`, new `scripts/ui/config_screen.gd`, `data/ui/dialogue_ui.json`, `data/text/title.json` |
| Integrator (main session) | | `main.gd` flow, `project.godot`, docs/decisions.md, docs/studio_log.md |

## Shared interfaces (agree here; add to "Changes" at the bottom, never silently rename)
- **GameState** (Gameplay Programmer B is the only editor): needs `play_time_s`, `location {room, spawn}`, `story_beat`, `opened` (crate/pickup ids), `equipment` per member (`{weapon, armor, charm}` ids), `credits`, `flags`, `bag`, party member states. `to_dict()`/`from_dict()` include all of it with a `save_version`. Others call public methods; if you need a new one, ask GP-B (or add a clearly additive method and tell the integrator).
- **SaveManager** (GP-B): `save_slot(n)`, `load_slot(n)`, `auto_save()`, `has_any_save()`, `newest_slot()`, `slot_summary(n) -> {place, play_time_s, party:[{id, level}], saved_at}`, signal `saved(slot)`. Save lamps call `SaveManager.open_lamp_menu()` (or the field menu's Save page calls `save_slot`).
- **Inventory / gear** (Battle Programmer): `Equipment.equip(member_id, slot, item_id) -> bool` (owner lock, heavy armor for Otis), `Equipment.get(member_id) -> Dictionary`, `StatCalc.stats(member_id) -> Dictionary` (base + growth + gear), `ShopLogic.buy(item_id, qty) / sell(item_id, qty)` with half-price sell, 99 cap, key items unsellable. Battles read gear through StatCalc.
- **SceneRouter** (GP-A): `go_to(room_id, spawn_id)` with fade, rooms from `rooms.json`; emits `room_entered(room_id)` (SaveManager auto-saves on it); keeps the battle detach/attach working through Main.
- **Config screen** (UI-B) is one component used by both the title and the field menu's Config page (UI-A embeds it instead of its own rows).
- **Dialogue**: speech bubbles stay the main field dialogue (Ross, 2026-10-06). M3-3 adds what's missing: mid-line expression tags, fast-forward, auto-advance, a small portrait slot for named cast (placeholder initials heads until portraits), plain bottom box for crowd/signs.

## Changes
