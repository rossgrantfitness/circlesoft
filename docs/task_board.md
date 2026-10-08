# Task Board

> Owner: Producer. Current milestone: **VERTICAL SLICE**. Anything beyond the slice goes in Later.

**Status (2026-10-08)**
- **Decisions needed from Ross:** none right now.
- **Done:** battle system (M2-1 to M2-9), Harrow systems and graybox (M3-1 to M3-10), the dynamic battle camera, the grim look test. Ross approved the grim package (look, tone, structure).
- **In progress:** A-pose reference sheets for Ross (G-0).
- **Next:** edge light and grim look everywhere, Harrow slum re-dress, re-toned lines, stencil rating lettering, structure docs made official; then the train opening and M4 (the Spillway and the jammer factory).
- **Waiting on Ross:** his art for the party (M2-10, art rows 1–6; best next, using the A-pose sheets) and Harrow (M3-11, rows 7–18). Later sign-offs: dialogue (M6-2) and every art drop.

## To Do

> Slice tasks follow the approved build order (docs/design_doc.md, "Vertical slice scope"; docs/decisions.md, 2026-10-06). Each task is sized for one agent in one go.
> **Ross sign-off** follows the Playbook autonomy ledger: style guide and the look (Art direction, Level 0), area layouts (Game design & battle, Level 1: whole areas are bigger than small calls), dialogue and story text (Dialogue & writing, Level 0), music direction (Audio direction, Level 0), every art drop he delivers, and the final build. Gear, menus and saves are Level 2 (show Ross after, no sign-off). Small design calls (tuning numbers, enemy stats) are Level 1: the studio decides and logs each one in docs/decisions.md. Any new mechanic that turns up during the build goes to Ross as its own decision.
> Before every Ross sign-off, the Taste Keeper records a prediction. Placeholders (game/art/placeholder/ only) until each art drop.
> Every gameplay task includes its headless tests in game/tests/ and keeps its numbers and text in game/data/. Builds target **Windows and Mac**.

### Milestone 0: Style guide (Ross's approval before final art)
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M0-1 | Present the full style guide to Ross in the sign-off format, with work-in-progress images | Technical Artist + Creative Director | Style guide draft (In Progress) | **Yes** | Ross's final art starts only after this. Poly/texture budgets get locked in M1-5. |

### Milestone 1: PSX look, diorama camera test room, pipeline test
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M1-2 | PSX shader set: low internal resolution scaled up, nearest-neighbor filtering, vertex jitter/snapping, affine texture warping, dithering | Technical Artist | M1-1; style guide rendering rules | No | Shown to Ross in M1-5. |
| M1-3 | Diorama camera test room: one placeholder room (floor + two back walls), fixed angle that slides with a placeholder Red, tall props fade, fade-to-black room change; plus a debug room with a cheat menu (jump to any room) | Gameplay Programmer | M1-1, M1-2 | No | Later tasks add their own cheats (start any fight, set level, give items, jump to floor). |
| M1-3b | Demo start screen: title logo (placeholder), "Press Start", Start Demo / Quit, leads into the test room | UI Programmer | M1-1 | No (Ross: build it, show when playable) | |
| M1-4 | Windows and Mac export of the test room, including the Mac signing step, so Ross can run it on his own computer | Gameplay Programmer | M1-3 | No | Technical Director reviews. If Mac signing needs Ross's account or a purchase, bring it to Ross as a decision. |
| M1-5 | Pipeline test: one placeholder Red (low-poly blockout, rig, idle + run, PSX shader) all the way into the test room; write proposed locked poly and texture budgets and Ross's export checklist into the style guide | Technical Artist | M1-2, M1-3, M1-4 | **Yes** | Ross sees it in the M1-4 build. After approval the Producer updates the budgets in docs/art_requests.md. |

### Milestone 2: Battle system and battle simulator
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M2-1 | Slice battle data in game/data/: Red/Otis/Mox stats and growth tables (levels 1–6), 9 skills (signature + 2 each), 4 status effects, 4 enemy types, timing windows, XP curve | Battle Programmer | M1-1 | No (Level 1) | Creative Director checks names. Log small calls in docs/decisions.md. |
| M2-2 | Battle core: turn order by Speed with the portrait-row data, Attack / Skills / Items / Defend / Run, HP, Juice, damage, Down for the Count, win/lose | Battle Programmer | M2-1 | No | |
| M2-3 | Clutch engine: clock-based press judging for tap, hold-and-let-go and string; Nice / Rad / TOTALLY RAD; Blocked / Perfect Block / Payback; Auto-Timing, Wide Windows, timing offset; cue fires flash + ding + "!" from one moment | Battle Programmer | M2-2 | No | Missing never hurts. Placeholder ding tone until M6-5. |
| M2-4 | Skills and status effects: Porch Light, Heave-Ho, Patent Pending + 2 basic skills each; Burnt Toast, Noise Ticket, Wobbly, Down for the Count | Battle Programmer | M2-3 | No | |
| M2-5 | Enemy AI and tells for the 4 slice enemy types (same wind-up every time; grunts wave a white flag and leave when nearly beaten) | Battle Programmer | M2-4 | No | |
| M2-6 | Rewards and progression: XP, credits, drops, level-ups, skill learned around level 4; bench-XP and catch-up rules built and tested | Battle Programmer | M2-2 | No | |
| M2-7 | Battle UI: command list, targeting, turn-order row, HP/Juice bar, Clutch cue and rating pop-ups, menu slides away during moves, K.O. freeze, victory screen | UI Programmer | M2-3, M2-6 | No | Placeholder lettering until UI art. |
| M2-8 | Battle stage: placeholder battle set and camera, the radio-static transition (longer boss version), screen shake on TOTALLY RAD | Technical Artist | M1-2, M2-2 | No | Battle backdrops reuse field sets later. |
| M2-9 | Battle simulator: thousands of fights as perfect / good / miss / Auto-Timing player; report win rates and fight lengths against the Feel targets; first tuning pass | Battle Programmer | M2-5, M2-6 | No (Level 1) | Regular fight 1–3 min. Runs headless. |
| M2-10 | Art in: import Ross's party models (Red, Otis, Mox) and the 3 weapon props; asset check | Technical Artist + Asset Checker | M1-5, Ross's delivery (art rows 1–6) | **Yes** | Ross checks his art in game. |

### Milestone 3: Harrow Landing
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M3-1 | One-page layout maps for Harrow Landing, the road and the Old Relay Tower (rooms, paths, enemy spots, puzzles, save lamps) | Creative Director | M0-1 | **Yes** | Ross also needs these to plan the environment sets. Keep pacing tight. |
| M3-2 | Exploration core: one-button talk / examine / take / open with pop-up icons, crew follows Red, climb and hop spots, doors and locked doors, glinting pickups | Gameplay Programmer | M1-3 | No | |
| M3-3 | Dialogue box system: portraits with mid-line expression changes, plain boxes for crowd NPCs, Red's face and gesture pop-ups, thumbs-up / head-shake yes-no, per-speaker text blips, fast-forward, text speed, auto-advance | UI Programmer | M1-1 | No | All text from game/data/. |
| M3-4 | Build Harrow Landing with placeholders: streets and docks, 6 interiors, checkpoint, hidden items, NPCs whose lines change by story beat, job board with 1–2 side deliveries | Gameplay Programmer | M3-1, M3-2, M3-3 | No | Placeholder text until M6-2. |
| M3-5 | Visible map enemies: patrols and chasing, touch to fight, first-turn rules, Run, blink after a fight, respawn on re-entry | Gameplay Programmer | M2-2, M3-2 | No | |
| M3-6 | Gear and items: 7 weapons, 5 armor, 4 charms, 13 items, 6 key items; equip rules, weapons locked to owner, charms block status, 99 cap, Camp Stove only at save lamps, key items unsellable | Battle Programmer | M2-4 | No (Level 2, show after) | |
| M3-7 | Field menu: Items, Skills, Equip, Status, Party, Config, Save; side panel with portraits, HP, Juice, credits, play time, place | UI Programmer | M2-6, M3-6 | No (Level 2, show after) | Lane Chart and Swap are Later. |
| M3-8 | Shops: general store and gear shop; buy, sell at half, quantity, owned count, up/down arrows per fighter; stock in game/data/ | UI Programmer | M3-7 | No (Level 2, show after) | |
| M3-9 | Save system: 3 slots + auto-save on area entry, versioned JSON, Continue loads newest, the lamp check (full, short, skippable), game over with Retry battle | Gameplay Programmer | M3-2, M2-6 | No (Level 2, show after) | Tests: save/load round trip, auto-save timing, Retry restores the fight's start, older saves load. |
| M3-10 | Title screen (New Game with name entry, Continue, Config) and the Config screen (Auto-Timing, Wide Windows, timing offset with tap-along test, text speed, auto-advance, skip, volumes, remap, vibration) | UI Programmer | M3-7, M3-9 | No (Level 2, show after) | Placeholder title art until UI art. |
| M3-11 | Art in: Harrow sets and interiors, townsfolk, portraits; asset check | Technical Artist + Asset Checker | M3-4, Ross's delivery (art rows 7–18) | **Yes** | |

### Milestone 4: The road and the Old Relay Tower
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M4-1 | Build the road and the tower (about 5 floors) with placeholders: Watch Zero's back way, 2 save lamps, the old Zero with the thermos before the boss | Gameplay Programmer | M3-1, M3-4 | No | Add the jump-to-floor cheat. |
| M4-2 | Tower puzzles: Kasp's access-card doors (with count), power switch and cage lift, crate push, optional bell chest (tune order), treasure crates and chalk stashes | Gameplay Programmer | M4-1 | No | |
| M4-3 | Fill game/data/ for the road and tower: enemy placements, crate contents, drops; check pacing with the simulator (about level 6 and about 1,500 credits by Kasp) | Battle Programmer | M4-1, M2-9 | No (Level 1/2) | Log tuning calls in docs/decisions.md. |
| M4-4 | Art in: enemies, tower kit and road, props; asset check | Technical Artist + Asset Checker | M4-1, Ross's delivery (art rows 19–32) | **Yes** | |

### Milestone 5: Kasp and the Hushmaster
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M5-1 | Kasp boss logic: Quiet Hours jam pulse (cues scramble, real window never moves), 8 legs breaking in 4 pairs weakening the pulse, topple, then Kasp on foot; boss "!!" telegraphs; simulator check for a 5–8 minute fight | Battle Programmer | M2-9 | No | Approved gimmick (story bible Villains + Technical Director's review). |
| M5-2 | Boss staging with placeholders: Hushmaster rig blockout, leg-pair breaks, toppled state, camera push-ins, Kasp's title card, the long boss transition | Technical Artist | M5-1, M2-8 | No | |
| M5-3 | Art in: Kasp and the Hushmaster; asset check | Technical Artist + Asset Checker | M5-2, Ross's delivery (art rows 33–34) | **Yes** | |

### Milestone 6: Story, cutscenes, dialogue, audio
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M6-1 | Script the slice's ~6 cutscenes, with the twist-clue check | Writer + Creative Director | M3-1 | **Yes** | Creative Director checks clues and the beacon part text. |
| M6-2 | Field text: NPC lines per story beat, examine lines, party chime-ins, side-job text, item / gear / enemy / key item descriptions, menu text | Writer | M3-1 | **Yes** (dialogue) | Item descriptions are Level 2 (show after). |
| M6-3 | In-engine cutscene system: camera moves, close-ups, push-ins, freeze-frames, portrait dialogue, hold Start to skip; scripted from game/data/ | Gameplay Programmer | M3-3 | No | |
| M6-4 | Build the ~6 cutscenes from the approved script | Gameplay Programmer | M6-1, M6-3 | No | Ross sees them in the M7-5 build. |
| M6-5 | Audio: music direction brief for Ross (8 tracks and jingles), then the audio system (music loops, SFX hooks, per-speaker blips, volume settings) with placeholder tones for every row in docs/audio_requests.md | Audio Designer | M2-3, M3-3 | **Yes** (music direction) | Placeholder tones need no sign-off. The ding must land with the flash. |
| M6-6 | Text check: typos, names and terms, text-box fit | Text Checker | M6-1, M6-2 | No | |

### Milestone 7: Polish, QA, playtest, builds for Windows and Mac
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M7-1 | Art in: UI art (icons, turn-order heads, rating lettering, pop-ups and gestures, Kasp's title card, title screen and logo, menu window and cursor); asset check | UI Programmer + Asset Checker | Ross's delivery (art rows 35–41) | **Yes** | |
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
| Red style prototypes A–E (static 3D, PSX turntables, in-game scale shots, contact sheet) per docs/red_style_prototypes.md | Technical Artist ×2 | 2026-10-06 | Ross's art-style gate; animation paused until he picks. |
| Style guide (full draft): visual pillars, palette, proportions, PSX rendering rules, UI windows, fonts | Technical Artist (with Creative Director) | 2026-10-06 | References: Mega Man Legends, Tail Concerto, MGS1, FF7. Goes to Ross as M0-1. Must be approved before Ross's final art. |
| Technical plan (docs/tech_plan.md) | Technical Director | 2026-10-06 | Feeds M1-1 (project skeleton) and all programming tasks. |
| Set up the lights-left-on repository | Ross (GitHub clicks), then studio floor moves game files over | 2026-10-05 | Merge PR #1 → mark circlesoft as template → create lights-left-on from it. |

## Done
| Task | Done by | Finished | Notes |
|---|---|---|---|
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
- Act 1 from the lockdown on (beats 5–11), then Acts 2 and 3.
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
