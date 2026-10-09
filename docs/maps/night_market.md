# The Night Market: layout map (vertical slice, task VS-12)

> Owner: Level Designer (proposes) · Ross (approves). Status: **proposed 2026-10-09, not approved.** The Taste Keeper logs a prediction before Ross decides.
> This is the 9-room Harrow Landing town (docs/maps/harrow_landing.md, approved 2026-10-07) re-dressed as a cosy neon night market, as Ross picked on 2026-10-09 (Town A). **Every wall, door and floor size is the approved Harrow layout.** Only names, what each room is for, the people and the dressing are new. Read this page first; the coordinates for the builder are at the bottom.
> Sources: slice_pitch.md, slice_tech_plan.md (sections 2.2, 3), harrow_landing.md, the story bible's world, factions and Kasp sections, the Playbook Principles. Nothing from the twist section.

## Decisions for Ross

DECISION NEEDED: How loud is the market?
Option A: **A whisper market.** The Quiet Hours noise curfew is real (it is in the approved world), so the cosiness is murmured: stall-keepers chat low, music leaks out of headphones and sock-stuffed speakers, wind chimes are taped. On the hour a Signals patrol sweeps through and the whole market goes silent and polite until they pass. When Kasp falls, the market gets loud again: radios, arcade beeps, chimes back on the poles. — Pros: keeps "cute people, grim skyline" honest; gives the ending walk home a payoff you can hear; costs only audio and a patrol routine. / Cons: a hushed town can feel less festive for the first five minutes.
Option B: **A loud, cheerful market** with the patrol as the only hush (they pass, everyone ducks, they leave). — Pros: instantly warm and busy. / Cons: it contradicts the approved Quiet Hours curfew, and the ending has nothing new to give.
Recommendation: **A.** The hush is what makes the market feel like a pocket people are protecting, and the loud ending is free.

DECISION NEEDED: Where does the repair shop under Red's hideout go?
Option A: **Reuse Otis's Dock Office room** (the small room off the wharf). The hideout is upstairs on the square side and the repair shop is the same building's lower floor on the wharf side (the town is built on a slope, the square sits above the wharf), joined by a ladder hatch inside. Mox runs the shop. Otis moves into the Gear Shop, which becomes his forge. No new room: still 9. — Pros: no new geometry; the old dock office has no job now that the dock fight is gone (no fighting in town); the hatch gives a cosy shortcut. / Cons: Otis's office and its story prop (the ship's bridge lamp, locked) move to the forge counter; the Creative Director must be told.
Option B: **Add a tenth tiny room** on the square next to the hideout door, keep Otis's office as is. — Pros: nothing moves. / Cons: one more room to build and test; the office has nothing to do; the wharf gets quieter.
Recommendation: **A.**

## For Ross (the short version)

- **Nine rooms, same doors, same size.** The old lamp names are gone ("Lamp Square" is now **Tarp Square**). No window lamps, no relighting windows; the neon and string lights are dressing only.
- **Red starts the game in her hideout**, a back room over Mox's repair shop. You wake up, a crackle from Vela in your ear, save at the deck on the desk, and go out.
- **Two shops:** the Corner Shop (items) and the Forge (swords and gear, Otis). **One job board** at the Dispatch Counter: the main job ("Yard 9") hands Red a Courier Pass and opens the junkyard gate. Two optional side jobs.
- **Things to see:** noodle carts, a bootleg arcade, Grandma Ume charging phones from her window, kids racing scrap drones on the wharf, propaganda screens, a Signals patrol that sweeps the square on the hour, a checkpoint line holding taped-up wind chimes.
- **No fighting here.** The town is the warm pocket. Hacks and the sword are off; Red can run, jump and talk.
- **Time:** about 5 minutes on the main path, up to 9 with every side thing.
- **Borrowed, openly:** the compact hub where every shop is one scene from the square is the approved Harrow plan (Mario RPG's Rose Town, Kalm); the "town as home base between dungeons, a repair shop under the hero's room" is Mega Man Legends' Flutter and Roll's garage. Each is one borrowed role; the people, jokes and look are ours.

## What changed from Harrow

| Harrow (approved) | Night market | Why |
|---|---|---|
| H1 Lamp Square (`harrow_square`) | **Tarp Square** (`market_square`), the hub | Lamp name cut. Tarps and string lights over the stalls. |
| H2 The Docks (`harrow_docks`) | **The Wharf** (`market_wharf`) | Drone-race track and a noodle cart; the dock fight is gone. |
| H3 Signals Checkpoint (`harrow_checkpoint`) | **Gate 4** (`market_gate`) | Same booth and barrier; the barrier now leads to the junkyard road. |
| H4 Red's Home (`harrow_home`) | **Red's Hideout** (`market_hideout`) | Back room over the repair shop; the window lamp is now a hacker deck (save and rest). |
| H5 Courier Office (`harrow_courier`) | **Dispatch Counter** (`market_dispatch`) | Job board. |
| H6 General Store (`harrow_store`) | **Corner Shop** (`market_corner`), shop 1 | Items. |
| H7 Gear Shop (`harrow_gear`) | **The Forge** (`market_forge`), shop 2 | Swords and gear; Otis works here. |
| H8 Otis's Dock Office (`harrow_dock_office`) | **Tuesday's Repair** (`market_repair`) | Mox's workshop (Decision 2, Option A). |
| H9 The Bar (`harrow_bar`) | **Bootleg Arcade** (`market_arcade`) | The one warm room on the waterfront stays warm. |

The old Harrow scenes in scenes/rooms/harrow/ are not touched; the shelved game keeps them.

## Box diagram

```
                       to THE JUNKYARD (junkyard.md, room junk_j1)
                                          ^
                                          | boom barrier (lifts for the Courier Pass)
                              +-----------+------------+
                              |  M3 GATE 4 (checkpoint) |
                              +-----------+------------+
                                          ^ gate arch
  +-------------+        +-----------------+-----------------------------------+
  | M4 RED'S    |<------>|                 M1 TARP SQUARE (hub)                |
  |   HIDEOUT   | W wall |  N wall: [M5 Dispatch] [M6 Corner] (alley) [M7 Forge]|
  | start, save | door   |  Grandma Ume's window over M6, noodle carts, screens |
  +------+------+        +-----------------+-----------------------------------+
         | ladder hatch                    | stairs down (south edge)
         |                +----------------+-----------------------------------+
         |                |                M2 THE WHARF                         |
         +----------------+  N wall: [M8 Tuesday's Repair]        [M9 Arcade]   |
           (same building)|  crate stack (west)  drone-race track  pier (SE)    |
                          +----------------------------------------------------+

  M5, M6, M7 open off the square; M8 and M9 open off the wharf. Each interior has one door back to its street.
  The hideout (square level) sits over the repair shop (wharf level): same building, joined by the hatch.
```

## The route through town (main path)

1. **M4 Red's Hideout, game start.** Red wakes on the bunk. Vela's voice in her ear (a non-blocking radio bark; the Writer writes it) says the Signals are tightening the screws and Dispatch has a job. Walk to the deck, save (the first save), and optionally drop through the hatch to say hi to Mox. About 1:00.
2. **M1 Tarp Square → M5 Dispatch Counter.** The Dispatcher offers the **main job, "Yard 9"**: the Signals scrapyard behind the ore line, where the Corps dumps every confiscated receiver, bell and radio, and where Sergeant Kasp keeps his rigs. (Who is asking, what they want back and the exact words are the Writer's; this is the structure.) Taking it sets `job_main_taken` and hands over the **Courier Pass** (key item). About 0:45.
3. **Free roam (optional).** Corner Shop and Forge to stock up; the two side jobs; secrets; the arcade; noodle carts.
4. **M3 Gate 4.** Show the pass: a 15-second scene, the grunt stamps it, mutters about the paperwork, and lifts the barrier onto the junkyard road. About 0:30. This is the only lock in town.
5. **Ending (after the boss, from docs/slice/slice_tech_plan.md section 0):** Red walks back through Gate 4 into the square. The 30-second walk across Tarp Square is the payoff: the market is loud again (Decision 1, A), the Odds Man pays out, a kid tells the "fifty troopers" tale and Red does her legend correction (three fingers, two more, a flex), and she goes home to the hideout. Staging only here; the words are the Writer's.

## Rooms

Conventions (units, origin, camera, doors) are the Harrow ones: meters; origin at the floor corner where the two back walls meet; +X east along the north wall; +Z south toward the camera; the diorama camera; Red steps up 1.0 m or less; crates 0.9 m. Walls, doors and camera bounds are unchanged from harrow_landing.md. **Cables and string lights hang at 5 m or higher and never across the front half of the floor** (nothing between the camera and Red). The prop fader (the old lamp post fade) works on the tarp pole, the carts' canopies and anything else tall in front of Red.

### M1 Tarp Square (`market_square`): the hub, 22 × 12 m
- **What it is:** the heart of the market at night: stacked shacks and cable nests overhead as before, but now tarps and string lights over the stalls (the warm part), neon signs in Ross's Japanese signage on the facades, and over the gate arch a propaganda screen looping the Admiral's broadcast with a Kasp memo scrolling under it (the grim part). The skyline above the roofs is the Signals tower and its dish.
- **Doors:** Red's Hideout (west wall), Dispatch, Corner Shop and Forge (north wall), gate arch to Gate 4 (north wall, east end), stairs down to the Wharf (south edge). Same positions as Harrow.
- **Stalls (all walkable around, 3 m lanes kept clear on the door lines):**
  - *Noodle cart A* ("Pop's"): the cook, three stools, steam, a chalked lantern under the counter (the Coldrunner mark: they sell to everyone). A bowl is a small heal (Combat Designer decides, Level 2).
  - *Dumpling cart B* on the west side, a sleepy cook.
  - *Cable and tape stall* on the east side: a keeper selling bundles of scrap wire and tape (flavour, bark only).
  - *Grandma Ume's window* above the Corner Shop: she leans out and charges the whole market's phones from a rack on a washing line, cords swinging down the facade, a price chalked on a plank. **Side job 1** sits here (the old balcony hop: two crates, then the ledge).
  - *The Odds Man* at the tarp pole: a chalkboard of bets on silly things ("Will the screen glitch before ten?").
- **The patrol:** two Signals wolves in navy coats walk a slow loop (waypoints in the build notes) on the hour. They are scenery, not enemies (no combat in town). Within 8 m of them every NPC drops to a whisper and the stall music ducks; after they pass it comes back. They never block a door. A patrol bump is a glare and a shoulder-check bark, never a fine or a fight.
- **NPCs:** see the NPC list. About 9 here.
- **Hidden item:** the alley alcove between Corner Shop and Forge (a notch in the north wall) has a chalked lantern on the wall and a stash crate behind trash cans (the same secret as Harrow; contents are the Combat Designer's).
- **Examine spots:** the propaganda screen, Kasp's daily memo board, the bets chalkboard, the phone rack, the tarp pole's tangle of string lights.

### M2 The Wharf (`market_wharf`): 24 × 9 m plus water and a pier
- **What it is:** the lower market on the waterfront: warehouse fronts under strings of paper-lantern-style bulbs (dressing), oily water at the front edge, a crane silhouette at the west end. The middle of the floor is the **scrap-drone derby track**, an oval marked with tyres and chalk where kids race hand-built drones, and a judge on a crate shouts the results. A third noodle cart steams at the pier root. A propaganda screen is bolted to the warehouse front.
- **Doors:** stairs up to the square (north wall, middle), Tuesday's Repair (north wall, west), Bootleg Arcade (north wall, east).
- **The races are scenery in the slice.** The drones loop the track on a path; kids "fly" them with pad props. A race minigame is on the Later list, not in the build.
- **NPCs:** about 7 here.
- **Hidden items:** the crate stack on the west end (hop one crate, then a second; the town's jump lesson, Red's jump is 1.6 m so the two 0.9 m crates are a gentle hop) and the end of the pier.
- **Examine spots:** the crane, a tide board, the race results chalkboard, a screen showing the Admiral's face with a sticker moustache.

### M3 Gate 4 (`market_gate`): the Signals checkpoint, 14 × 9 m
- **What it is:** the grim edge of the warm pocket. A blue-gray booth, a boom barrier over a ramp down to the junkyard road, a slow searchlight, Kasp's face on "QUIET HOURS SAVE LIVES" posters with chalked moustaches, and a short line of Marchfolk waiting with their confiscated wind chimes taped up in socks.
- **Doors:** gate arch back to the square (south edge), the boom barrier to `junk_j1` (north wall, locked until the job is taken).
- **Before the job:** two grunts at the barrier: "Road's closed. Papers?" and a little scene where one writes a noise ticket for a wind chime. After: the pass scene (route step 4).
- **Side job 2, "Appeal in triplicate":** drop Pell's form in the booth's APPEALS slot; a recorded voice says the appeal is important to them.
- **Hidden item:** confiscation bin behind the booth.
- **NPCs:** the two grunts (scenery) and three people in line.

### M4 Red's Hideout (`market_hideout`): 7 × 5 m, **game start and save**
- **What it is:** a back room over the repair shop: a bunk, a hacker deck on a desk under a window onto the neon, a clothesline of spare jackets, a shelf with a photo and Mom's old flight charts, a wall of delivery stickers (one per run), a pantry tin. It hums faintly with the shop's grinder below. Cosy, cramped, hers.
- **The deck (save terminal and rest):** at the north wall. Press to save (the lamp check is re-dressed as the deck check: a knuckle tap on the screen and a thumbs-up at the neon sky) and rest (free full heal). Auto-save on entering.
- **The hatch:** a ladder hatch in the floor to Tuesday's Repair (Decision 2, Option A). Mox's voice and sounds drift up through it.
- **Pickup:** the pantry tin, a visible starter item.
- **Examine:** the photo, the flight charts, the deck, the sticker wall, a parcel marked "MOX WUZ HERE". Text from the Writer.
- **NPCs:** none. Red lives alone. (Vela is a voice, not a body.)

### M5 Dispatch Counter (`market_dispatch`): 8 × 6 m, **the job board**
- **What it is:** a cramped parcel office: shelves, a stamped counter, a job board of curling slips. A sleepy courier snoozes on the bench in every state of the game.
- **Job board:** Main job and two side jobs (below). One press to take each; the board shows taken and done.
- **NPCs:** the Dispatcher and the sleeping courier.

### M6 Corner Shop (`market_corner`): 7 × 5 m, **shop 1: items**
- **What it is:** a 24-hour corner shop of canned noodles, bottled tea, gear charms and batteries under a buzzing sign; a ration-card reader; a nervous Signals clerk buying antacids (the one Corps person who is clearly just a guy).
- **Shop:** healing and utility items. Stock is the Combat Designer's (`data/shops/market_*.json`, Level 2); the map only places the counter.
- **NPCs:** the shopkeeper and the clerk. The window above (Grandma Ume's) is outside.

### M7 The Forge (`market_forge`): 7 × 5 m, **shop 2: swords and gear**
- **What it is:** Otis's forge: scrap piles, a glowing forge mouth, an anvil, a workbench, and on the west wall a rack of swords (Ross's six sword models on show, the "super cool new sword" shelf). Otis hums over the anvil and calls everyone "friend". Sword tinkering and upgrades live here (what is sold and what an upgrade is are the Combat Designer's calls).
- **Story prop (locked by the Creative Director and Writer):** the rusty ship's bridge lamp, previously on Otis's desk in the dock office. It moves with Otis to the east end of the forge counter. Whether it stays now the lamp theme is cut is the Creative Director's call; if it goes, nothing else changes.
- **Shop:** weapons, hack upgrades, charms. Stock is the Combat Designer's.
- **NPCs:** Otis (the shopkeeper).

### M8 Tuesday's Repair (`market_repair`): 7 × 5 m
- **What it is:** Mox's repair shop, named after his drone (built on a Tuesday, patched with tape, one teal running light). Sparks, a ceiling-high pegboard of tools, half-built gadgets, a conveyor of someone's broken radios. Mox brags about projects forty percent finished. **The ladder hatch** up to Red's hideout stands in the east corner.
- **Purpose:** the workshop of the hack story. Mox is where Red's hack deck comes from; a short scene here (placed by the Writer's story_scenes data) hands over the starter hacks before the junkyard. It is not a shop.
- **Pickup:** none required. The "MOX WUZ HERE" scratch is on the counter.
- **NPCs:** Mox and Tuesday (the drone hovers; a cosmetic, not an enemy).

### M9 Bootleg Arcade (`market_arcade`): 9 × 6 m
- **What it is:** a back-of-the-wharf arcade: six mismatched cabinets in neon, a prize claw, a snack counter, a high-score board. Every speaker is stuffed with a sock to stay under Quiet Hours, so the game sounds are tiny beeps. The one room where kids are loud, quietly. A small lit room in the grim, the warmest set in the slice.
- **Cabinets:** examine only in the slice (each a one-line joke). Playable minigames are on the Later list, not the build.
- **Hidden item:** behind the prize claw machine.
- **NPCs:** about 5 here.

## NPC list (about 28, working names; the Writer renames and writes the lines)

Final models: Ross makes Otis, Mox and Vela (portrait only here) plus **3 or 4 residents** (suggested: Grandma Ume, Pop the noodle cook, the Dispatcher, and Juno the drone kid). Everyone else is a colour swap of the NPC blockout.

| # | Who (working name) | Where | Role and cute hook |
|---|---|---|---|
| 1 | **Mox** | M8 | The workshop. Brags, panics for four seconds, fixes everything. His drone **Tuesday** hovers over his shoulder. |
| 2 | **Otis** | M7 | The forge and the swords. Hums, calls you "friend", apologises to anvils. |
| 3 | **Vela** (voice only) | Radio | Red's voice in her ear on runs: prim, careful, ex-Signals. Portrait in the radio box. |
| 4 | **The Dispatcher** (Ross model, suggested) | M5 | Gives the jobs, fusses over the deadline. |
| 5 | Sleeping courier | M5 | Never wakes. |
| 6 | Corner Shop keeper | M6 | Tired, sells everything, knows everyone's order. |
| 7 | Nervous Signals clerk | M6 | Buys antacids, hides his badge. The one Corps person who is just a guy. |
| 8 | **Grandma Ume** (Ross model, suggested) | M1 window | Charges the market's phones from her window; rents out chargers; scolds anyone who touches the cords. |
| 9 | **Pop** (Ross model, suggested) | M1 | Noodle cook. A chalked lantern under his counter. Serves everyone. |
| 10 | Dumpling cook | M1 | Sleepy, offers a sample. |
| 11 | Cable-and-tape keeper | M1 | Sells scrap wire by the foot. |
| 12 | The Odds Man | M1 | Bets on trivia. Mostly right, always upset. |
| 13 | Neighbour by Red's door | M1 | Complains about Red's hours, bakes at 3am. |
| 14 | Four shoppers (colour swaps) | M1 | Murmur barks as Red passes. |
| 15, 16 | Two Signals patrol wolves | M1 | Scenery. The grim in the cosy. |
| 17 | **Juno** (Ross model, suggested) and two drone kids | M2 | Race scrap drones; one drone always crashes. |
| 18 | The race judge | M2 | A kid on a crate with a megaphone he has to whisper into. |
| 19 | Pell | M2 | Dockhand. Hands over the Appeal Form for side job 2. |
| 20 | Late noodle cook | M2 | Pop's cousin, same menu. |
| 21 | Fisher at the pier | M2 | Fishing in oily water with great hope. |
| 22, 23 | Two grunts | M3 | Tired, ticketing a wind chime. |
| 24 | Three people in the checkpoint line | M3 | Carry taped-up wind chimes. |
| 25 | Arcade owner | M9 | Runs the snack counter and the sock rule. |
| 26 | Arcade kids (three) | M9 | Rival high scores. |
| 27 | Zed | M9 | The high-score rival who is always one point behind. |

(Counts include groups; about 28 individuals with the line-up and queue.) Ambient one-liners (`bark_radius_m`) use the shoppers, the kids and the queue. Speech bubbles and gibberish voices are the existing system.

## Shops and the job board

| | Where | Purpose | Stock/jobs |
|---|---|---|---|
| Shop 1 | M6 Corner Shop | Items: healing, utility, battery-style pickups | Combat Designer, `data/shops/market_corner.json` |
| Shop 2 | M7 The Forge | Swords, hack upgrades, charms, sword tinkering | Combat Designer, `data/shops/market_forge.json` |
| Job board | M5 Dispatch | Main job opens the junkyard | `data/slice/jobs.json` (structure mine, words the Writer's) |

**Jobs.**
- **Main, "Yard 9":** go to the Signals scrapyard behind the ore line. Taking it sets `job_main_taken` and gives the **Courier Pass** (key item). Done when the slice boss is beaten (`kasp_beaten`).
- **Side 1, "Charge-up delivery":** a battery brick to Grandma Ume's window (the old dark-window hop: two crates, then the ledge). Reward: a charm and 100 credits (as Harrow's Lucky Bolt job; the Combat Designer may change the item).
- **Side 2, "Appeal in triplicate":** Pell's form to the APPEALS slot at Gate 4. Reward: credits and a useful item (Combat Designer decides; the old Noise Ticket cure no longer applies).
- Side jobs are optional, on the way, and pay for the junkyard's supplies.

## Locks and what opens them

| Lock | Where | Opens when | Message while locked |
|---|---|---|---|
| Boom barrier to the junkyard | M3 → `junk_j1` | `job_main_taken` and the Courier Pass in the bag | "Road's closed, courier. Papers?" |
| Everything else | | Open from the start | |

No dead ends: a grunt who turns Red away points at Dispatch, the first door beside her hideout.

## Walking time and pacing

| Piece | Rough time |
|---|---|
| Hideout: wake, Vela, save | 1:00 |
| Out to Dispatch, take the main job | 0:45 |
| Free roam: shops, noodle bowl, hatch to Mox, side jobs, secrets, arcade (optional) | up to 4:00 |
| Gate 4, the pass scene | 0:30 |
| Walk (about 70 m main path at 6 m/s plus 6 fades) | 0:30 |
| **Town total** | **about 3 minutes to 7 minutes**, about 5 for a typical player |
| Ending walk home (after the boss) | 1:00 |

With every detour the walk is about 220 m. **If the slice runs long,** trim free roam first, never the pass scene.

## What stands in for art (placeholders only)

| What | Stand-in |
|---|---|
| Red | the sandbox Red |
| Otis, Mox, Vela, townsfolk | the NPC blockout (capsule-and-sphere fallback from `npc.gd`), colour swaps, one accessory per person (hard hat, welding mask, headphones, apron band) |
| Signals wolves | the existing Cyberwolf Sentinel model (scenery) |
| Stalls, carts, tarps | boxes, cylinders and planes in warm tints; carts are 2.4 × 1.2 m boxes with a cylinder pot and a steam puff |
| String lights, neon, signs | small emissive quads on thin wires at 5 m or higher; sign slots with a flat label until Ross's signage arrives |
| Propaganda screens | a 1.6 × 1 m emissive quad looping a placeholder broadcast |
| Drone-race track | a ring of tyre cylinders, a chalk oval decal, three small box drones on a path |
| Arcade cabinets, prize claw | 0.7 × 0.8 × 1.7 m boxes with a lit screen quad |
| Look | the `market_ps2` profile: warm neon night, string-light glow, light haze, long draw distance (the Technical Artist's, VS-39) |

## Art the market needs (for docs/art_requests.md; Ross makes the final art)

| Name | For | Size | Budget | Palette | Format | Goes in |
|---|---|---|---|---|---|---|
| Market neon sign set | Facades, stalls, arcade, Corner Shop, Forge | 6 to 10 signs, 512 × 128 px each, emissive | 2D | Hot pink, teal, amber on dark; Ross's Japanese signage | PNG | `game/art/final/world/market/signs/` |
| Stall and cart kit | Noodle carts, dumpling cart, tape stall | 3 kinds, about 2.4 m wide | 400 to 800 tris each | Warm faded tarps, rust, steam white | GLB | `game/art/final/world/market/stalls/` |
| String-light strand | Over the square and the wharf | 1 repeating segment, 2 m | 100 tris | Warm amber bulbs | GLB | same |
| Propaganda screen frames and posters | Square, wharf, gate | 3 screens, 4 posters (the Admiral; Kasp's memos) | 150 tris | Slate, sick green, white | GLB and PNG | same |
| Arcade cabinet set | Bootleg arcade | 3 variants about 0.7 × 0.8 × 1.7 m | 400 tris | Mismatched pastels, lit screens | GLB | same |
| Drone-race props | The wharf track | 3 small scrap drones, a track kit | 300 tris | Scrap colours, teal running lights | GLB | same |
| Grandma Ume's window kit | Square, over Corner Shop | A window, a clothesline, a phone rack | 300 tris | Warm window glow, cable orange | GLB | same |
| Residents (suggested) | Ume, Pop, the Dispatcher, Juno | 4 character models | per the style guide | Per Ross | GLB | `game/art/final/characters/` |
| Hideout set | M4 | Bunk, deck, clothesline | 600 tris | Cosy, her jacket oxblood | GLB | `game/art/final/world/market/hideout/` |

## Graybox build notes (for the builder, VS-14)

**Generator:** `make_market_rooms.py` starts as a copy of `make_harrow_rooms.py`; scenes in `scenes/slice/market/`; rows in `data/slice/rooms.json`; placements in `data/slice/placements.json`. Room entries are `kind: town`, `camera: diorama`, `combat: false`, `look_profile: market_ps2`, `form: red`. Autosave on `market_hideout`. Save terminal: the deck in the hideout.

**Geometry:** every size, door and camera setting is the one in harrow_landing.md. These notes list only the changes.

**M1 `market_square`** (22 × 12; yaw 30)
- Doors: Dispatch N @ x=4; Corner Shop N @ 8.5; Forge N @ 16; gate arch N @ 20 (3 m wide); Hideout W @ z=4; stairs S edge x=9 to 12. Targets use `market_*` ids: `market_dispatch:from_square`, and so on.
- Alley alcove: notch in the N wall x=11.5 to 13.5, 3 m deep; stash crate (12.5, -2.3).
- Grandma Ume's window: x=6 to 8, sill 2.6 m, ledge 1.8 m × 2 m × 0.6 m under it, step crate (6.5, 1.2), phone rack on a clothesline at (6.5, 0.4). Ume's head anchor 3.1 m up.
- Tarp pole at (11, 6), 4 m, fades when Red is behind it. The Odds Man at (12, 6.5).
- Noodle cart A at (15, 8.5) (stools (14, 9.6), (15.2, 9.6), (16.4, 9.6)); dumpling cart B at (4, 8.5); tape stall (18.5, 6.5); neighbour (2, 6). Cables and string lights at 5 m or higher on the back half only.
- Propaganda screen above the arch at (20, 0), 3.4 m up, 1.6 × 1 m.
- Patrol (cosmetic): loop (20, 2.5) → (20, 10.5) → (6, 10.5) → (6, 2.5) → (20, 2.5) at 1.2 m/s, on the hour; flag `patrol_hush` for 15 s while they are within 8 m of an NPC.
- Spawns: `from_hideout` (1.2, 4), `from_dispatch` (4, 1.2), `from_corner` (8.5, 1.2), `from_forge` (16, 1.2), `from_gate` (20, 1.5), `from_wharf` (10.5, 10.8).

**M2 `market_wharf`** (24 × 9; pier x=20 to 23, z=9 to 13; yaw 25)
- Doors: stairs N @ x=12 (3 m) → `market_square:from_wharf`; Repair N @ 5 → `market_repair:from_wharf`; Arcade N @ 19 → `market_arcade:from_wharf`.
- Crate stack: crate A (3.2, 6); crate B (2, 6) on a 0.9 m base, top 1.8 m, pickup on it. Pier-end pickup (21.5, 12.5).
- Drone track: oval centre (16, 5.5), x=12 to 20, z=3.5 to 7.5, keeps the z=1 to 2.5 lane along the N wall clear. Judge crate (11, 6). Kids at (12.5, 8.2), (19.5, 8.2), (16, 2.8). Late noodle cart (21.5, 7). Pell (9, 3). Fisher at the pier tip. Propaganda screen on the warehouse front at x=14, 3 m up.
- Spawns: `from_square` (12, 1.5), `from_repair` (5, 1.2), `from_arcade` (19, 1.2).

**M3 `market_gate`** (14 × 9; yaw 30)
- Doors: arch S edge x=6 to 9 → `market_square:from_gate`; boom barrier N @ x=10, 3 m wide → `junk_j1:from_market` (locked until `job_main_taken`). Booth (5, 2); APPEALS slot on its south face; bin (3, 0.8).
- Spawns: `from_square` (7.5, 7.8), `from_junk` (10, 1.5). Grunts (9, 2), (11, 2). Line (7, 6), (8.2, 6), (9.4, 6).

**M4 `market_hideout`** (7 × 5; yaw 45; camera fixed (3.5, 2.5))
- Door: S edge @ x=5.5 → `market_square:from_hideout`. Hatch 1 × 1 m at (2.2, 4.2) → `market_repair:from_hideout`.
- Deck (save and rest) at the N wall @ x=3, sill 1.0 m. Bunk W wall z=1 to 3. Sticker wall W wall z=3 to 5. Pantry tin (6.2, 0.6).
- Spawns: `start` (3, 1.2, facing the deck; **the New Game start**), `from_square` (5.5, 4), `from_repair` (2.2, 3.4).

**M5 `market_dispatch`** (8 × 6; yaw 45): door S @ x=4 → `market_square:from_dispatch`; counter N wall x=2 to 6; Dispatcher (4, 0.5); job board W wall z=2.5; sleeper (7, 4). Spawn `from_square` (4, 5).

**M6 `market_corner`, M7 `market_forge`** (7 × 5; yaw 45): door S @ x=3.5; counter N wall x=2 to 5, keeper at (3.5, 0.5); M6 clerk (5.8, 3); M7 sword rack W wall; bridge lamp on the counter's east end (4.6, 0.5). Spawn `from_square` (3.5, 4).

**M8 `market_repair`** (7 × 5; yaw 45): door S @ x=2 → `market_wharf:from_repair`; workbench N wall x=2 to 5, Mox (3.5, 1.2); pegboard W wall z=2.5; ladder hatch east corner (5.8, 1.2) → `market_hideout:from_repair`. Spawns `from_wharf` (2, 4), `from_hideout` (5.8, 2).

**M9 `market_arcade`** (9 × 6; yaw 45; camera fixed (4.5, 3)): door S @ x=7 → `market_wharf:from_arcade`; four cabinets on the N wall (x=1.5, 3.2, 4.9, 6.6), two on the E wall; snack counter W wall z=1 to 4, owner (0.6, 2.5); high-score board N wall @ x=4.5; prize claw at (8.3, 0.6) with the pickup behind it at (8.6, 0.3). Kids (2, 2), (3, 4), (5.5, 2); Zed (6.5, 4). Spawn `from_wharf` (7, 5).

**Flags (suggestions; the Gameplay Programmers own the files):** `job_main_taken`, `courier_pass` (key item), `job_charge_done`, `job_appeal_done`, `patrol_hush`, `kasp_beaten`, `market_loud` (set after the boss; turns the audio from whisper to loud).

## Test and screenshots

- **Headless test (`integration/test_slice_rooms.gd`, Level Designer):** every `market_*` scene loads; every door's target room and spawn exist; the `start` spawn is on the floor and reachable to every door and placement by a walk check (steps 1.0 m or less, the two-crate hops within Red's 1.6 m jump); the barrier door is locked until `job_main_taken`; the hatch pair `market_hideout:from_repair` / `market_repair:from_hideout` connects both ways; every placement id matches a node.
- **Screenshots for Ross (`docs/screenshots/slice_market_*.png`, taken by the Technical Artist's capture script):** the square at night with the patrol, the wharf drone track, the arcade, the hideout, the gate. Placeholders only until Ross's art arrives.
