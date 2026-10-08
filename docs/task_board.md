# Task Board

> Owner: Producer. Current milestone: **VERTICAL SLICE**. Anything beyond the slice goes in Later.

**Status (2026-10-08)**
- **Decisions needed from Ross:** none right now.
- **Done:** battle system (M2-1 to M2-9), Harrow systems and graybox (M3-1 to M3-10), the dynamic battle camera, the grim look test. Ross approved the grim package (look, tone, structure).
- **In progress:** A-pose reference sheets for Ross (G-0); art and audio request lists (G-2, Creative Director).
- **Next:** edge light and grim look everywhere, Harrow slum re-dress, re-toned lines, stencil rating lettering, structure docs made official; then the train opening and M4 (the Spillway and the jammer factory).
- **Waiting on Ross:** his art for the party (M2-10, art rows 1–6; best next, using the A-pose sheets) and Harrow (M3-11, rows 7–18). Later sign-offs: dialogue (M6-2) and every art drop.

## To Do

> Slice tasks follow the approved build order (docs/design_doc.md, "Vertical slice scope"; docs/decisions.md, 2026-10-06). Each task is sized for one agent in one go.
> **Ross sign-off** follows the Playbook autonomy ledger: style guide and the look (Art direction, Level 0), area layouts (Game design & battle, Level 1: whole areas are bigger than small calls), dialogue and story text (Dialogue & writing, Level 0), music direction (Audio direction, Level 0), every art drop he delivers, and the final build. Gear, menus and saves are Level 2 (show Ross after, no sign-off). Small design calls (tuning numbers, enemy stats) are Level 1: the studio decides and logs each one in docs/decisions.md. Any new mechanic that turns up during the build goes to Ross as its own decision.
> Before every Ross sign-off, the Taste Keeper records a prediction. Placeholders (game/art/placeholder/ only) until each art drop.
> Every gameplay task includes its headless tests in game/tests/ and keeps its numbers and text in game/data/. Builds target **Windows and Mac**.

> Milestones 0 and 1 are Done (see Done).

### Milestone 2: Battle system and battle simulator
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M2-10 | Art in: import Ross's party models (Red, Otis, Mox) and the 3 weapon props; asset check | Technical Artist + Asset Checker | M1-5, Ross's delivery (art rows 1–6) | **Yes** (Ross's art) | **Waiting on Ross.** M2-1 to M2-9 are Done. Reference for the party is now the grim look (taller, leaner, matte and scuffed) and the A-pose sheets (G-0). |

### Milestone 3: Harrow Landing
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M3-11 | Art in: Harrow sets and interiors, townsfolk, portraits; asset check | Technical Artist + Asset Checker | M3-4, G-5, Ross's delivery (art rows 7–18) | **Yes** (Ross's art) | **Waiting on Ross** (skipped for now per Ross, 2026-10-07). M3-1 to M3-10 are Done. Harrow's sets now follow the cyberpunk-slum re-dress (G-5) and docs/tone_guide.md. |

### Next phase: the grim package and the train opening (approved 2026-10-08)
> From docs/decisions.md 2026-10-08 and docs/structure_pass_2026-10-08.md. Grim look, edge light, tone D1 A / D2 B / D3 B, structure D1 A / D2 A / D3 A. UI windows and menus stay as they are. Slice is now about 33 minutes (about 28 skipping optional fights).

| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| G-1 | Make the tone pass and structure pass official: story bible (Act 1 beats 1 and 7, Act 2 beat 2), design doc (10-hour structure, slice paragraph and list), maps (new docs/maps/train.md for the 3 car rooms + the jump; docs/maps/road_and_tower.md recast as the Spillway, the Works gate and the jammer works; Harrow map's New Game start), style guide environment table | Creative Director | | No (approved 2026-10-08) | Same room ids, flags, encounters and approved map choices. Twist section stays Creative Director + Writer only. |
| G-2 | Update docs/art_requests.md and docs/audio_requests.md: row 19 becomes the Spillway and the Works gate, the tower kit becomes the Works kit around the mast, new row 42 train-car kit (one car module re-dressed as flatcar, hopper, boxcar), row 37 rating lettering becomes spray-paint stencil, grim palette notes on character and set rows; audio: train and undercity ambience | Creative Director | G-1 | No | Already underway. Slice art list goes from 41 to 42. Also update the locked budgets from M1-5 if they aren't in yet. |
| G-3 | Edge-light readability pass: characters and enemies a bit brighter than the grim background, "not too bright", with an edge light (Look A); field and battle | Technical Artist | Grim look test (Done) | No (direction approved; show Ross screenshots in docs/screenshots/) | Clutch cues and ratings must still read at a glance. |
| G-4 | Grim look everywhere: make the grim look profile the default in every room and the battle stage (classic stays switchable in the F1 overlay for comparison) | Technical Artist | G-3 | No | Applies the 2026-10-08 visual direction (desaturate, darken, grime). UI unchanged. |
| G-5 | Harrow slum re-dress across all 9 rooms: taller stacked facades and cable nests above the walkable floor, neon over grime, propaganda; scenery only, no layout, door, shop or spawn changes | Technical Artist | G-4 | No | Placeholders in game/art/placeholder/ only. Same camera. |
| G-6 | Half-dark windows (tone D2 B): about half of Lamp Square's windows dark; a few relight on the walk home after Kasp, driven by the post-Kasp story flag; which windows relight lives in game/data/ | Technical Artist | G-5 | No | Test with the debug cheat that sets the post-Kasp flag. Headless test for the relight. |
| G-7 | Re-tone placeholder lines per docs/tone_guide.md (D1 A chilling-funny): story_scenes.json, harrow_town.json, battle and menu text; plus the structure changes (courier job becomes "claim your crate at Otis's dock", the dock-stairs lock reads "claim slip", one new dock line about the crate, train opening lines and Clutch tutorial prompts) | Writer | G-1 | No (placeholder text) | Ross signs off the final text in M6-2. Text Checker checks in M6-6. |
| G-8 | Spray-paint stencil rating lettering (tone D3 B, still loud): Nice!, Rad!, TOTALLY RAD!, Blocked!, Perfect Block!, Payback!, K.O.!, "!" and boss "!!" | UI Programmer | | No (placeholder) | Placeholder until Ross's art row 37 (lands in M7-1). Same timing and pop-ups; only the lettering changes. |
| G-9 | Train opening, rooms: 3 car rooms + the jump from one car module (flatcar, hopper, boxcar) with placeholders; walk, run, jump, crate hops, hiding behind ore; Red shoves the crate into the harbor and jumps for Harrow's freight platform, then runs home | Gameplay Programmer | G-1 (train map), G-4 | No | Target about 3.5–4 min. Add a jump-to-car cheat. |
| G-10 | Train opening, inspectors: scanner-sweep enemy (a patrol with a vision cone, MGS1-style hunted feel, no timer), built on the roaming enemies from M3-5 | Gameplay Programmer | G-9 | No | What happens when spotted follows the train map. Behavior numbers in game/data/. |
| G-11 | Train opening, flow: one must-win tutorial fight on the train (reuse `grunt_solo`) that teaches Clutch; **New Game starts on the train**; Red's home becomes stop 2 (first save); update the tests that assume New Game starts at home (Harrow walkthrough and story tests, the M3 end-to-end run) | Gameplay Programmer | G-9, G-10 | No | If playtests run long: make the train a pure chase with no fight (caught = restart the car). |
| G-12 | Art in: train-car kit; asset check | Technical Artist + Asset Checker | G-9, Ross's delivery (art row 42) | **Yes** (Ross's art) | Also reused later for the dead ore line (Act 1, Later). |

### Milestone 4: The Spillway and the jammer factory
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M4-1 | Build the Spillway (two scenes; keep the `road_mast_road` id, new display name), the Works gate (Watch Zero's sit-in, Kasp on the loudspeaker, the drain grate) and the jammer works around the ancient mast, one room per floor: T0 the Sump (save lamp, plaque and mural), T1 Cable Mill, T2 Bell Gallery, T3 Power Room, T4 Drone Line, T4b last landing (the old Zero with the thermos, second save lamp), T5 the roof; placeholders | Gameplay Programmer | G-1, G-4, M3-4 | No | Add the jump-to-floor cheat. Grim look and slum neon from the start. |
| M4-2 | Works puzzles: Kasp's access-card doors (with count), power switch and freight lift (the approved cage-lift shortcut), crate push on the Cable Mill, optional bell chest in the Bell Gallery (tune order), treasure crates and chalk stashes (one on a sunken tram car in the Spillway) | Gameplay Programmer | M4-1 | No | |
| M4-3 | Fill game/data/ for the Spillway and the works: enemy placements (one dodgeable Spillway patrol, the three must-win card fights, the Quota Ambush on the Drone Line), crate contents, drops; check pacing with the simulator including the train fight (about level 6 and about 1,500 credits by Kasp) | Battle Programmer | M4-1, M2-9 | No (Level 1/2) | Log tuning calls in docs/decisions.md. |
| M4-4 | Art in: enemies, the Works kit around the mast, the Spillway and the Works gate, props; asset check | Technical Artist + Asset Checker | M4-1, Ross's delivery (art rows 19–32) | **Yes** (Ross's art) | Rows 19 and the tower kit are renamed in G-2. |

### Milestone 5: Kasp and the Hushmaster
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M5-1 | Kasp boss logic: Quiet Hours jam pulse (cues scramble, real window never moves), 8 legs breaking in 4 pairs weakening the pulse, topple, then Kasp on foot; boss "!!" telegraphs; simulator check for a 5–8 minute fight | Battle Programmer | M2-9 | No | Approved gimmick (story bible Villains + Technical Director's review). |
| M5-2 | Boss staging with placeholders: Hushmaster rig blockout, leg-pair breaks, toppled state, camera push-ins, Kasp's title card, the long boss transition | Technical Artist | M5-1, M2-8 | No | |
| M5-3 | Art in: Kasp and the Hushmaster; asset check | Technical Artist + Asset Checker | M5-2, Ross's delivery (art rows 33–34) | **Yes** (Ross's art) | |

### Milestone 6: Story, cutscenes, dialogue, audio
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M6-1 | Script the slice's ~6 cutscenes, with the twist-clue check | Writer + Creative Director | M3-1 | **Yes** | Creative Director checks clues and the beacon part text. |
| M6-2 | Field text: NPC lines per story beat, examine lines, party chime-ins, side-job text, item / gear / enemy / key item descriptions, menu text | Writer | M3-1, G-7 | **Yes** (Ross signs off the dialogue) | Builds on the re-toned lines (G-7) and covers the train, the Spillway and the works. Item descriptions are Level 2 (show after). |
| M6-3 | In-engine cutscene system: camera moves, close-ups, push-ins, freeze-frames, portrait dialogue, hold Start to skip; scripted from game/data/ | Gameplay Programmer | M3-3 | No | |
| M6-4 | Build the ~6 cutscenes from the approved script | Gameplay Programmer | M6-1, M6-3 | No | Ross sees them in the M7-5 build. |
| M6-5 | Audio: music direction brief for Ross (8 tracks and jingles), then the audio system (music loops, SFX hooks, per-speaker blips, volume settings) with placeholder tones for every row in docs/audio_requests.md | Audio Designer | M2-3, M3-3 | **Yes** (music direction) | Placeholder tones need no sign-off. The ding must land with the flash. Includes the train and undercity ambience (G-2). |
| M6-6 | Text check: typos, names and terms, text-box fit | Text Checker | M6-1, M6-2 | No | |

### Milestone 7: Polish, QA, playtest, builds for Windows and Mac
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M7-1 | Art in: UI art (icons, turn-order heads, rating lettering, pop-ups and gestures, Kasp's title card, title screen and logo, menu window and cursor); asset check | UI Programmer + Asset Checker | Ross's delivery (art rows 35–41) | **Yes** (Ross's art) | Rating lettering (row 37) is spray-paint stencil, replacing the G-8 placeholder. |
| M7-2 | Full QA pass: all headless tests, title-to-window-lamp run with no dead ends, bug log | QA Tester | M6-4, M6-5 | No | Done = no crash or major bugs open. |
| M7-3 | Playtest report: pacing (~30 min, no filler), difficulty, Feel targets, Clutch readability | Playtester | M6-4 | No | |
| M7-4 | Fix pass on QA and playtest findings | Owners per bug (Gameplay / Battle / UI Programmer) | M7-2, M7-3 | No | New ideas go to Later, not into the fix pass. |
| M7-5 | Windows and Mac release builds; Ross plays the slice on his own computer and signs off | Gameplay Programmer + Producer | M7-1, M7-4 | **Yes** | Placeholders left in only with Ross's OK. |

### Other (not slice-blocking)
| Task | Assigned to | Depends on | Notes |
|---|---|---|---|
| Name Ruo's brother | Creative Director proposes | | Small; whenever convenient. |
| Steam/trademark check on the title "Lights Left On" | Producer | | Working title until checked. |

## In Progress
| Task | Assigned to | Started | Notes |
|---|---|---|---|
| G-0 A-pose reference sheets for Ross: the current characters in an A-pose on a white background, so he can create art assets | Technical Artist | 2026-10-08 | Ross's request with the grim package approval. Feeds M2-10 (party, art rows 1–6) and his other character rows. |

## Done
| Task | Done by | Finished | Notes |
|---|---|---|---|
| Grim look test: switchable look profile (classic / grim), grim Harrow square, checkpoint and battle stage, cyberpunk-slum dressing, leaner scuffed grim Red, matte scuffed Otis, Mox and grunts | Technical Artist | 2026-10-08 | Ross approved the setting 2026-10-08 with one change: brighter characters and enemies with an edge light (G-3). Shots: docs/screenshots/grim_*.png. |
| Dynamic battle camera from Ross's 12-panel storyboard (unplanned Ross request): intro shots, boss low-angle intro, idle drift, action shots, Clutch lock, Config "Battle Camera: Dynamic / Calm" | Technical Artist | 2026-10-07 | 1449 tests; playthrough 28/28. Studio calls in docs/decisions.md 2026-10-07. |
| M3-10 Title screen (New Game with name entry, Continue, Config) and the full Config screen | UI Programmer | 2026-10-07 | In v0.3.0. |
| M3-9 Save system: 3 slots + auto-save, save lamps, Continue, game over with Retry | Gameplay Programmer | 2026-10-07 | In v0.3.0. |
| M3-8 Shops: general store and gear shop | UI Programmer | 2026-10-07 | In v0.3.0. |
| M3-7 Field menu | UI Programmer | 2026-10-07 | In v0.3.0. |
| M3-6 Gear and items (7 weapons, 5 armor, 4 charms, 13 items, 6 key items) | Battle Programmer | 2026-10-07 | Enemy HP retuned x1.3; calls in docs/decisions.md. |
| M3-5 Visible map enemies (patrols, chasing, first-strike rules) | Gameplay Programmer | 2026-10-07 | In v0.3.0. |
| M3-4 Harrow Landing graybox: 9 rooms, ~25 townsfolk, both shops, job board + 2 side deliveries, 5 hidden items, dock fight, story scenes | Gameplay Programmer | 2026-10-07 | 1421 tests; delivered to Ross as v0.3.0. Kept as built; slum re-dress in G-5. |
| M3-3 Dialogue system polish | UI Programmer | 2026-10-07 | In v0.3.0. |
| M3-2 Exploration core (crew follows Red, doors and locked doors, pickups, climb and hop, SceneRouter) | Gameplay Programmer | 2026-10-07 | In v0.3.0. |
| M3-1 Layout maps for Harrow Landing, the road and the Old Relay Tower | Creative Director | 2026-10-07 | Ross approved all six picks. Road and tower recast as the Spillway and the jammer works in G-1 (same choices). |
| M2-9 Battle simulator and first tuning pass | Battle Programmer | 2026-10-06 | Results in docs/battle_sim_report.md. |
| M2-8 Battle stage, enemy blockouts, radio-static transition, TOTALLY RAD shake | Technical Artist | 2026-10-06 | In v0.2.0. |
| M2-7 Battle HUD and victory / game over screens | UI Programmer | 2026-10-06 | In v0.2.0. |
| M2-6 Rewards and progression | Battle Programmer | 2026-10-06 | In v0.2.0. |
| M2-5 Enemy AI and tells (4 enemy types) | Battle Programmer | 2026-10-06 | In v0.2.0. |
| M2-4 Skills and status effects | Battle Programmer | 2026-10-06 | In v0.2.0. |
| M2-3 Clutch engine | Battle Programmer | 2026-10-06 | In v0.2.0. |
| M2-2 Battle core | Battle Programmer | 2026-10-06 | In v0.2.0. |
| M2-1 Slice battle data | Battle Programmer | 2026-10-06 | 889 tests at v0.2.0 delivery. |
| M1-5 Pipeline test: placeholder Red through to the test room; budgets and export checklist in the style guide | Technical Artist | 2026-10-06 | Budgets per the approved style guide (~700 tris target, 900 cap). |
| M1-4 Windows and Mac export of the test room | Gameplay Programmer | 2026-10-06 | First playable build delivered to Ross (162 tests). Mac build unsigned. |
| M1-3b Demo start screen | UI Programmer | 2026-10-06 | Screenshot: docs/screenshots/m1_title_screen.png. |
| M1-3 Diorama camera test room | Gameplay Programmer | 2026-10-06 | Playable; screenshot docs/screenshots/m1_room_playable.png. |
| M1-2 PSX shader set and low-res screen | Technical Artist | 2026-10-06 | Screenshot: docs/screenshots/m1_test_room.png. |
| M0-1 Full style guide presented to Ross | Technical Artist + Creative Director | 2026-10-06 | Approved: 384×216, 96×96 portraits, one model per character. |
| Style guide (full draft) | Technical Artist (with Creative Director) | 2026-10-06 | Went to Ross as M0-1; approved. |
| Technical plan (docs/tech_plan.md) | Technical Director | 2026-10-06 | Approved; Compatibility renderer. |
| Red style prototypes A–E | Technical Artist ×2 | 2026-10-06 | Ross picked a mix; Red locked as the polished shiba (prototype F). |
| Set up the lights-left-on repository | Ross, then studio floor | Not in studio log | Started 2026-10-05; the studio log has no finish date. |
| M1-1 Project skeleton (tech plan steps 1-3): project settings, autoload stubs, DataDB, headless test runner | Gameplay Programmer | 2026-10-06 | 28 headless tests pass (`godot --headless --path game -s res://tests/run_all.gd`). Awaiting Technical Director review and the studio-floor commit. |
| Slice task board, art requests (41 assets) and audio requests drawn up | Producer | 2026-10-06 | Includes the weapon-model art requests (Red sword, Otis hammer, Mox wrench-mace); Vela's and Ruo's weapons are Later. |
| Studio setup (Phases 0–4) | Studio floor | 2026-10-05 | Waiting on Ross to merge pull request #1. |
| Pitch meeting (3 rounds) | Creative Director, Technical Director, Producer | 2026-10-05 | Ross chose Lights Left On. |
| Story bible: Logline, World & history, Factions | Creative Director | 2026-10-05 | Approved by Ross after tone pass. |
| Story bible: Main cast | Creative Director | 2026-10-05 | Approved: Red, Otis, Mox, Vela (bunny), Ruo. |
| Story bible: Villains | Creative Director | 2026-10-05 | Approved: the ladder, the Overture, Vane, Kasp, Tilly; species per Ross. |
| Taste Keeper hired, Ross's Playbook adopted | Studio floor | 2026-10-05 | All areas at autonomy Level 0. |
| Story bible: Act 1 / 2 / 3 outlines | Creative Director | 2026-10-05 | Approved as drafted. |
| Story bible: THE TWIST + clues | Creative Director | 2026-10-05 | Approved as revised: the Keeper, beatdown finale, mom = Eurydice "Dee" Kincaid. |
| Naming pass + Glossary: **story bible complete** | Creative Director | 2026-10-06 | Approved. |
| Design doc: Core pitch, Pillars, Battle system (Clutch + Juice); Relay removed everywhere | Creative Director, Technical Director | 2026-10-06 | Approved. |
| Design doc: Exploration (fixed diorama camera), Party & progression | Creative Director, Technical Director | 2026-10-06 | Approved. |
| Design doc: Equipment & items | Creative Director | 2026-10-06 | Finalized by studio under Level 2; shown to Ross. |
| Design doc: Economy | Creative Director | 2026-10-06 | Approved. |
| Design doc: Menus + Save system | Creative Director | 2026-10-06 | Finalized by studio (Level 2). |
| Design doc: The 10-hour structure | Creative Director | 2026-10-06 | Approved (two re-dressed moons; keep pacing tight). |
| Design doc: Vertical slice scope: **design doc complete** | Producer, Technical Director | 2026-10-06 | Approved. Builds for Windows and Mac. |
| Decide how to keep games separate | Technical Director, Ross | 2026-10-05 | Separate repository per game. |

## Later
_Ideas beyond the vertical slice. Not to be built until Ross approves the slice._
- EarthBound-fast instant wins against much weaker grunts (approved 2026-10-06).
- Swap/bench, Vela and Ruo's signature moves; Tangled, Butterfingers, Fired Up; robot/titan/ship/god-scale fights; other bosses' gimmicks (from the Battle system section).
- Act 1 from the lockdown on (beats 5–11), then Acts 2 and 3. Act 1 now runs across ten settings (docs/structure_pass_2026-10-08.md); the dead ore line reuses the slice's train-car kit.
- Act 2 places **Pit Nine** (company mining moon) and **Breaker's Ring** (junk-ring city), working names, approved 2026-10-08. They replace the two re-dressed moons and are built from kits already planned (the slum kit, the Works kit, the Navy hull kit), so no new biome kits; their titan stages use the strip pit and the hull ring for walls and height.
- Vela and Ruo in the party, picking your three, levels past 6 and the rest of each skill list, Act 3 guest missions.
- Machine stations, the shared Hull bar, size boost, machine versions of skills, and all machine upgrades.
- The lane chart, travel between moons, the *Low Profile*; the Biscuit stomp, titan stages and the *Supper's On* home base.
- Vela's and Ruo's weapons, the Act 2 and Act 3 weapon models, ultimate weapons; the bigger item tiers, the other cures, throwables, boosters, armor and charms.
- Inns, dock shops, higher shop tiers, the Tip Jar charm.
- Lane Chart in the field menu, Swap in Party, a window color option (if the style guide allows it).
- Saving at inns and the *Supper's On* bridge; saving machine parts, Hull and guest missions.
- Dungeon maps in the menu.
- The bets board as a playable minigame.
- A theater for rewatching cutscenes.
- Pre-rendered movie scenes: probably never, maybe one or two for the very biggest moments.
- Fix Tilly's net (a miss costs a turn, which breaks "missing never hurts") before her fight is built.
