# The road and the Old Relay Tower: layout map (vertical slice)

> Task M3-1 · Owner: Creative Director (proposes) · Ross (approves).
> **Status: DRAFT for Ross's sign-off. Nothing here is final.** The build (M4-1, M4-2) starts only after Ross signs off.
> Companion page: docs/maps/harrow_landing.md (room conventions and graybox rules are defined there and apply here too).

## For Ross (the short version)

- **The road:** 2 outdoor scenes. A short night road where Mox pops out of the delivery crate, then the foot of the mast, where Watch Zero's bell-ringing sit-in is driving the Signals crazy. The old-timers open a drain tunnel: the back way in. About **4 minutes**.
- **The tower:** 7 rooms stacked up the old mast: the half-buried bottom floor, four floors, a small landing before the top, and the roof. About **12 minutes** to climb, then **7 to 9 minutes** on the roof for Kasp and the ending.
- **What you do inside:** 3 must-win fights (each grunt drops one of Kasp's access cards, which open the Signals doors), up to 3 more fights you can take or dodge, one crate to push, one power switch that wakes the old cage lift, one jump to a hidden crate, and the optional bells for the bonus sword. A quiet floor with no enemies sits in the middle as a breather.
- **Save lamps:** one right inside the back way, one on the landing before the roof, with the old Zero and her thermos (one free full heal). The cage lift also runs back down to the first lamp as a shortcut.
- **Whole slice:** Harrow about 8.5 + road about 4 + tower about 11 + roof about 7.5 = **about 31 minutes** with the optional fights; about 26 if you skip them all.
- **Art:** gray boxes and reused models for now. The tower is one kit (floor, two walls, the mast column, the lift cage) re-dressed per floor, so it stays one set on your list (art row 20).
- **Three choices for you are at the bottom of this page:** the tower's shape, how long the road is, and whether the card fights can be skipped. The map is drawn with the studio's recommended answers.

**Borrowed, openly, with our own surface:** a floor-by-floor climb to a show-off boss on the roof is Mario RPG's Booster Tower and FF7's Shinra building. Keycards that open one Signals door after another are FF7's Shinra keycards (ours are all the same laminated photo of Kasp). The lift that wakes up and drops you back by the first save point is Dark Souls' elevator shortcut back to the bonfire. Ringing bells in the order of a tune you were taught is FF9's Gizamaluke's Grotto bells plus Mario RPG's tune-playing puzzle. The pre-boss healer is the classic JRPG "last rest before the boss". One borrowed role each; names, people, jokes and look are ours.

## Box diagram

```
  from HARROW (checkpoint barrier)
        |
  +-----v--------------------------------------+
  | R1 MAST ROAD   (Mox pops out of the crate)  |   patrol: grunt pair (dodgeable)
  +---------------------------------------+----+
                                          | east edge
  +---------------------------------------v----+
  | R2 MAST FOOT   (Watch Zero sit-in)          |   front gate: locked for good
  +----+---------------------------------------+
       | drain tunnel (opens in the sit-in scene)
  =====|===================== THE OLD RELAY TOWER ==================================
       v
  +---------------------+                       ,----- cage lift (after the switch) -----.
  | T0 THE SUMP         |  SAVE LAMP 1          |                                         |
  | bottom floor        |  card grunt #1 (must) |<---- lift stop T0 (shortcut down) ------|
  +----------+----------+                       |                                         |
             | stairs                           |                                         |
  +----------v----------+                       |                                         |
  | T1 CABLE HALL       |  drones (optional)    |                                         |
  | crate push -> ledge |  CARD DOOR 1 (1 card) |                                         |
  +----------+----------+                       |                                         |
             | stairs                           |                                         |
  +----------v----------+                       |                                         |
  | T2 BELL GALLERY     |  card grunts #2 (must)|                                         |
  | 4 bells (optional)  |                       |                                         |
  +----------+----------+                       |                                         |
             | stairs                           |                                         |
  +----------v----------+                       |                                         |
  | T3 GENERATOR DECK   |  no enemies           |                                         |
  | CARD DOOR 2 -> lever|  stairs up collapsed  |<---- lift stop T3 ----------------------|
  | jump -> girder crate|                       |                                         |
  +---------------------+                       |                                         |
                                                |                                         |
  +---------------------+                       |                                         |
  | T4 JAMMER DECK      |  squad #3 (must)      |<---- lift stop T4 ----------------------'
  | Quota Ambush (opt.) |  CARD DOOR 3 (3 cards)
  +----------+----------+
             | card door 3
  +----------v----------+
  | T4b LAST LANDING    |  SAVE LAMP 2 + the old Zero's thermos (one full heal)
  +----------+----------+
             | stairs
  +----------v----------+
  | T5 THE ROOF         |  BOSS: Sgt. Kasp in the Hushmaster -> the beacon part -> home
  +---------------------+
```

## The route (main path)

1. **R1 Mast Road.** Halfway along, the delivery crate starts bragging: Mox pops out, gets sent home, and stomps back toward town. One grunt patrol further on (take it or dodge it). Party: Red, Otis.
2. **R2 Mast Foot.** The sit-in scene: Red hands over the crate, Watch Zero sounds off, Kasp threatens over a loudspeaker, a Signals supply crate by the gate starts bragging (Mox again, so he's in), and the old Zero opens the drain tunnel. Talk to her again for the bell tune (optional). Party: Red, Otis, Mox.
3. **T0 The Sump.** Save lamp 1. A grunt eating lunch with his back turned: sneak up for a free first turn. He drops card #1.
4. **T1 Cable Hall.** Card door 1 opens with 1 card. Optional: push the crate to the ledge for a chalk stash; fight or dodge the drones.
5. **T2 Bell Gallery.** Card grunts #2 patrol the floor (must-win, card #2). Optional: the bells.
6. **T3 Generator Deck.** The stairs up are torn out for jammer cable. Card door 2 opens the switch cage; throw the lever: the tower's lights come on and the old cage lift wakes. Optional: hop to the girder crate. Ride the lift up.
7. **T4 Jammer Deck.** The full Signals squad patrols the jammer (must-win, card #3). Optional: the Quota Ambush guarding a crate. Card door 3 opens with 3 cards.
8. **T4b Last Landing.** Save lamp 2; the old Zero (she came up the back way after you) pours one round from the thermos: full heal, once.
9. **T5 The Roof.** Kasp in the Hushmaster. In the wreck: the beacon part. Then home to the window (see Harrow Decision 3).

**The call gets louder every floor:** each room has an audio level for the call layer, from 1 (R2) to 6 (the landing); it peaks on the roof. Audio needs go in docs/audio_requests.md with M4.

**Story beats used here:** `b2_road` (leaving town until Mox joins), `b3_tower` (inside), `b4_kasp_beaten` (after the boss). Party chime-ins and examine text come from the Writer (M6-2).

## Rooms

### R1 Mast Road (`road_mast_road`)
- **What it is:** a dusty road at night, a rock cut and a sagging fence along the back, the mast's silhouette ahead against the stars, Harrow's lamps behind.
- **Ways in and out:** from the checkpoint barrier (west wall); on to R2 (east edge).
- **Story scene (once):** the bragging crate, about one third of the way along. About 1 minute. Mox is sent home.
- **Enemy patrol:** `grunt_pair` walking a slow loop on the far half of the road. A clear lane along the front edge lets Red slip past. Regular enemy: respawns when you come back.
- **Hidden item:** a broken-down hauler by the fence with a chalked lantern on its tailgate. Hop onto its bed: **Hot Sauce Bomb ×2.**
- **Examine:** a mile marker (Harrow one way, the Old Relay the other).
- **NPCs:** none outside the scene.

### R2 Mast Foot (`road_mast_foot`)
- **What it is:** the half-buried base of the mast fills the back wall: rust, the Watch Zero mast-and-three-rings symbol painted huge, Signals cable and the jammer dish far above. A blue-gray Signals blast door at its foot. A row of Zeroes sitting on cushions in front of it, ringing their sleeve bells.
- **Ways in and out:** from R1 (front edge); the drain tunnel into the tower (west wall, opens in the scene); the front gate (locked for good: "Signals access only. And the Signals don't like you.").
- **Story scene (once, about 1.5 minutes):** delivery handed over; "Watch Zero, sound off!" and every bell rings at once; Kasp on the loudspeaker; the old Zero's story line about the call (locked wording, from the Writer; don't cut it); Mox bursts out of a Signals crate by the gate and joins; the Zeroes pry open the tunnel grate.
- **NPCs:** *the old Zero* (proposed Key NPC B, portrait set art row 12; final pick in M6-1). After the scene, talk to her again: she hums the tune and writes it down: **Bell Tune Napkin** (key item, optional). *7 more Zeroes* (crowd): one line each, mostly shouting at the gate. *2 gate grunts* (not fights) in earmuffs, begging for quiet.
- **Hidden item:** a gray Hegemony supply crate behind the Signals generator: **Smelling Salts ×1.** (First gray crate: teaches that the ring-and-bar stencil means loot.)

### T0 The Sump (`tower_sump`): the half-buried bottom floor
- **What it is:** sand drifting in through the tunnel, the old mast's base column rising through the ceiling, a worn plaque and a big faded mural on the back wall. Old and sacred, before the Signals junk starts.
- **Save lamp 1:** in a wall niche right beside the tunnel.
- **Story props (locked):** the plaque ("Raised so we can hear them") and the faded mural beside it (a crew of five waving from a ship heading down the last lane, every window behind them lit). Exact text and look are fixed by the Creative Director and Writer; don't move or reword them.
- **Enemy, must-win:** card grunt #1 (`grunt_solo`), sitting on a cable spool eating lunch, back to the room. He only turns if Red walks in front of him, so the game teaches "hit them from behind for a free turn". **Drops Kasp's Access Card #1.** Doesn't respawn once beaten.
- **The cage lift (stop T0):** a dead cage against the back wall, gate chained: "No power." It wakes after the T3 switch and becomes the shortcut back here.
- **Pickup:** gray supply crate: **Ration Bar ×2.**
- **Stairs up** to T1 (open).

### T1 Cable Hall (`tower_cable_hall`)
- **What it is:** the first Signals floor: cable bundles snaking everywhere, a quota chart on the wall, the mast column in the middle. A raised side ledge (too high to jump) runs along the west wall.
- **Card door 1:** needs 1 card. Leads to the stairs up. Locked message: "SIGNALS ACCESS ONLY. Cards: 0 of 1."
- **Puzzle, crate push:** a gray supply crate sits in the open. Push it west until it bumps the ledge (it snaps into place), hop onto it, then up onto the ledge. On the ledge, a chalked lantern stash: **Camp Stove ×1 + Canned Coffee ×1.**
- **Enemy, optional:** `drone_flock` (two Signals drones and a Whistle Blower) circling the mast. Dodge by hugging the front edge, or fight.
- **Examine:** the quota chart (target 400, achieved 1,203, Kasp's note: "NOT ENOUGH"), a cable spool labeled "PROPERTY OF SGT. KASP. DO NOT TOUCH. THIS MEANS YOU."

### T2 Bell Gallery (`tower_bell_gallery`)
- **What it is:** the Zeroes' old shrine floor: four brass bells of different sizes hanging from a beam along the west wall, prayer ribbons, a slit window looking back at Harrow's lamps. The Signals have taped "QUIET" signs on everything.
- **Enemy, must-win:** card grunts #2: a grunt and a Whistle Blower (suggested new encounter `card_pair`; the Battle Programmer may reuse `grunt_pair` instead) patrolling a loop around the mast. **Drops Access Card #2.** No respawn once beaten.
- **Optional puzzle, the bells:** ring the four bells (big, middle, little, tiny) in the order on the napkin. The tune has 5 notes; the Audio and Writer pick it, and the napkin draws it as bell sizes so nobody needs to read music. Wrong order: a sour clang, Mox comments, it resets. No penalty, no fail state. Right order: a hatch in the floor opens on a Zero chest: **Bread Knife, Extremely Large** (Red's bonus sword).
  - Without the napkin, Mox says there must be a tune for these; the old Zero is still at the mast foot (T0 → tunnel → R2 is about 20 seconds).
- **Stairs up** to T3 (open).

### T3 Generator Deck (`tower_generator`): the breather floor
- **What it is:** old mast machinery, a big dead generator, girders overhead. The stairs up have been ripped out to run jammer cable ("The stairs are gone. Cable everywhere. Very Kasp."). **No enemies here:** a beat to breathe while the call gets loud.
- **Card door 2:** the gate of a wire cage around the old power lever. Needs 2 cards.
- **Puzzle, power switch:** throw the lever: the generator coughs on, lights come on up the whole tower (an audio swell of the call), and the cage lift hums. Flag `lift_powered`.
- **The cage lift (stop T3):** rides up to T4, or down to T0 (the shortcut back to save lamp 1).
- **Hidden item, jump:** hop a crate onto a girder catwalk; at its far end, a gray supply crate: **Protein Shake** (the slice's one booster).
- **Examine:** the generator's maker's plate, older than any record.

### T4 Jammer Deck (`tower_jammer_deck`)
- **What it is:** the busiest Signals floor: the jammer's control console, cable running up through the ceiling to the dish, a coffee station. The biggest tower room; the camera slides.
- **Arrive by:** the cage lift (stop T4).
- **Enemy, must-win:** card squad #3 (`squad_four`) patrolling around the console. **Drops Access Card #3.** No respawn once beaten.
- **Enemy, optional, the Quota Ambush:** `ambush_no_exit` (can't run), three tough enemies "on break" around a gray supply crate in a corner pen. They don't patrol or chase; touch one to fight. Crate: **Sore Loser Patch (charm) + 200 credits.** The pen's sign says "QUOTA ENFORCEMENT. DO NOT DISTURB." Respawns as a regular enemy, the crate doesn't.
- **Card door 3:** needs 3 cards. Leads to the Last Landing.
- **Examine:** the console (Kasp's spec sheet for the Hushmaster, which he wrote himself), the coffee station (decaf only, by order).

### T4b Last Landing (`tower_landing`)
- **What it is:** a small stairwell landing under the roof. The call is very loud here.
- **Save lamp 2:** in a wall niche.
- **The old Zero with the thermos:** she climbed the back way after you ("Somebody had to"). Talk to her once: the party gets full HP and Juice. After that she just wishes you luck. She uses the thermos Red delivered (if Harrow Decision 2 is A).
- **Examine:** Kasp's coat rack with a spare lanyard of about forty laminated cards, every one his photo.
- **Stairs up** to the roof. The boss starts when you step out.

### T5 The Roof (`tower_roof`): the boss arena
- **What it is:** the top of the mast at night: the three rings of the old mast overhead, the Signals jammer dish bolted on, open sky, Harrow's lamps far below past the railing.
- **Boss:** Kasp boards the Hushmaster (scene, title card), then the fight. Not a regular enemy: no Run, never respawns.
- **After the fight (cutscene):** Red finds the beacon part in the wreck and the call plays clearly. Look and text per the Creative Director (art row 32). Then the ending at Red's window.
- **Camera:** pulled back a little compared with the floors below, so the Hushmaster fits on screen.

## Locks and what opens them

| Lock | Where | Opens when | Message while locked |
|---|---|---|---|
| Tower front gate | R2 | Never in the slice (story) | "Signals access only. And the Signals don't like you." |
| Drain tunnel grate | R2 → T0 | Sit-in scene done (`zeroes_back_way`) | The Zeroes are still arguing about whose turn it is to lift it. |
| Card door 1 | T1 → T2 | Hold 1 or more cards | "SIGNALS ACCESS ONLY. Cards: X of 1." |
| Card door 2 (switch cage) | T3 | Hold 2 or more cards | "SIGNALS ACCESS ONLY. Cards: X of 2." |
| Card door 3 | T4 → T4b | Hold 3 cards | "SIGNALS ACCESS ONLY. Cards: X of 3." |
| Cage lift (all stops) | T0, T3, T4 | Lever thrown in T3 (`lift_powered`) | "No power." |
| Bell chest hatch | T2 | Bells rung in order (`bells_solved`) | (hidden until solved) |
| Collapsed stairs | T3 | Never (the lift replaces them) | "The stairs are gone. Cable everywhere." |

- **Cards are counted, not used up.** Every door just checks how many of Kasp's cards you hold. They're all the same card anyway.
- **No dead ends:** a card grunt you run from stays put until you beat him; the bells have no fail state; the lift can't strand you because the T0 stop only works after it's powered from T3.

## Fights at a glance

| Room | Encounter (data id) | Must-win? | Respawns? | Suggested level |
|---|---|---|---|---|
| R1 | `grunt_pair` | No | Yes | 2 |
| T0 | `grunt_solo` (card #1) | Yes | No | 2 to 3 |
| T1 | `drone_flock` | No | Yes | 3 |
| T2 | `card_pair` (new; or `grunt_pair`) (card #2) | Yes | No | 3 to 4 |
| T4 | `squad_four` (card #3) | Yes | No | 4 to 5 |
| T4 | `ambush_no_exit` | No (no Run once started) | Yes (crate doesn't) | 5 |
| T5 | Kasp in the Hushmaster | Yes (boss) | No | 6 |

With the dock fight in Harrow, that's 8 fights for a player who takes everything, 5 for one who dodges every optional fight. The Battle Programmer checks the level 6 and 1,500-credit targets with the simulator (M4-3). **If the numbers come up short, raise the rewards on the existing fights before adding new ones** (no filler).

## Walking time and pacing

| Piece | Walking | Everything else | Rough total |
|---|---|---|---|
| R1 Mast Road | 0:10 | crate scene 1:00, optional patrol fight 1:30 | 1:10 to 2:40 |
| R2 Mast Foot | 0:15 | sit-in scene 1:30 | about 1:45 |
| **Road total** | | | **about 3 to 4.5 minutes** (design doc target: 4) |
| T0 to T4b, main path | about 1:00 (about 160 m, 7 fades) | must-win fights 4:30; switch, lift and crate push 1:00; scenes and saves 1:15 | about 8 |
| Optional in the tower | about 0:30 | drones or ambush 1:30 to 3:30; bells 1:00; girder 0:20 | up to 5 more |
| **Tower total** | | | **about 8 to 13 minutes; about 11 for a typical player** (target: 12) |
| T5 Roof | 0:05 | Kasp intro 1:00, boss 5 to 8, beacon part 1:00, window ending 0:45 | **about 7.5 to 10.5 minutes** (target: 6) |

**The whole slice:** Harrow about 8.5 + road about 4 + tower about 11 + roof about 7.5 = **about 31 minutes**. The roof is where it runs over: the approved boss length (5 to 8 minutes) is longer than the roof's 6-minute slot. If playtests run long, trim the optional fights' length first, then the Kasp intro; don't cut the breather floor (T3), it costs only seconds.

## What stands in for art (placeholders only, no new character modeling)

| Who or what | Stand-in |
|---|---|
| Red, Otis, Mox | `red_shiba`, `chr_otis`, `chr_mox` |
| Signals grunt, Whistle Blower, drone, Buzzkill | `enm_signals_grunt`, `enm_grunt_variant`, `enm_signals_drone`, `enm_drone_variant` (all existing) |
| Card grunts | the same grunt models, plus a small bright yellow box on the chest (the card lanyard) so players can spot who carries one |
| The old Zero and the 7 sit-in Zeroes | `npc_old_zero`, recolored per Zero |
| Kasp | `enm_grunt_variant` scaled about 1.2, brown tint, a flat box for his paddle tail |
| The Hushmaster | the M5 blockout when it exists; until then a 2 × 1.5 × 2 m box body, eight thin cylinder legs and a flat disc dish, about 3.5 m tall |
| Delivery crate, supply crates, chalk mark | 0.9 m cubes (tan for the delivery crate, gray with a white ring-and-bar decal), a white chalk decal quad |
| Tower kit | flat-colored boxes and planes: rust-brown walls, the mast column as a 3 m wide 12-sided cylinder, blue-gray boxes for Signals doors and gear |
| Bells, lever, lift cage, save-lamp niche | cylinders sized 0.9 / 0.7 / 0.5 / 0.35 m; a box lever on a hinge; a 2 × 2 m wire box with bars; a box niche with an amber light |

## Graybox build notes (for the Gameplay Programmer, M4-1 and M4-2)

Same conventions as docs/maps/harrow_landing.md: meters, origin at the north-west floor corner, +X east along the north wall, +Z south toward the camera, steps up of 1.0 m or less, crates 0.9 m.

**Tower-wide rules, so every floor reads the same:**
- Floors T0 to T3 are 16 × 10 m with 4 m walls. **The mast column** (3 m wide) stands half sunk into the north wall at x=6.5 to 9.5 on every floor. **The lift shaft** is a 2 × 2 m column at x=14 to 16, z=0 to 2 on every floor; it has doors only at T0, T3 and T4 (meshed cage on T1 and T2).
- **Wayfinding:** you arrive at the front-left (stairhead around (2, 8)) and the way up is at the back-right (north wall, x=12). Same on every floor.
- Yaw 35 on every floor. Camera bounds X 5 to 11, Z 4 to 6 unless noted.
- The debug warp (M4-1's jump-to-floor cheat) uses each room's arrival spawn: `from_below`, or `from_tunnel` (T0) and `from_lift` (T4).

**R1 Mast Road (`road_mast_road`)**
- Floor 34 × 8 m; rock cut on the N wall 3 m; fence line on the W wall. Yaw 20. Camera bounds X 5 to 29, Z 4 to 4.
- Doors: from Harrow at W wall @ z=4 → back to `harrow_checkpoint:from_road`; E edge, z=2 to 6 → `road_mast_foot:from_road`.
- Crate scene trigger: plane at x=11 (fires once, flag `mox_crate_scene`).
- Patrol `grunt_pair`: waypoints (19, 2) → (28, 2) → (28, 5) → (19, 5), walking speed. Dodge lane z=6 to 8 stays clear. Hauler wreck 4 × 2 m at (23, 1), bed top 0.9 m; chalk stash on the bed at (24, 1).
- Spawns: `from_harrow` (1.2, 4), `from_mast_foot` (32.8, 4).

**R2 Mast Foot (`road_mast_foot`)**
- Floor 18 × 12 m; the mast base on the N wall, 8 m tall, curved; rocky slope on the W wall. Yaw 30. Camera bounds X 5 to 13, Z 5 to 7.
- Doors: S edge @ x=3 → `road_mast_road:from_mast_foot`; drain tunnel grate W wall @ z=8, 1.6 m wide → `tower_sump:from_tunnel` (locked until `zeroes_back_way`); front gate N wall @ x=11, 3 m wide (never opens).
- Sit-in row: Zeroes at z=5, x=6 to 14, 1.1 m apart, facing north. Old Zero at (4.5, 7). Gate grunts at (9.5, 1.5) and (12.5, 1.5). Mox's Signals crate at (14.5, 2.5). Generator box 2 × 1.5 m at (16, 8); supply crate behind it at (17.3, 9).
- Scene trigger: on first entry (whole room).
- Spawns: `from_road` (3, 11), `from_tunnel` (1.2, 8).

**T0 The Sump (`tower_sump`)**
- Floor 16 × 10 m (floor ramps down 0.5 m over z=6 to 9 from the tunnel). Camera bounds X 5 to 11, Z 4 to 6.
- Doors: tunnel W wall @ z=8 → `road_mast_foot:from_tunnel`; stairs up N wall @ x=12 → `tower_cable_hall:from_below`; lift door N side of the shaft (15, 2.1) (active once `lift_powered`; a menu offers T3 or T4).
- Save lamp niche W wall @ z=5. Plaque N wall @ x=1.5; mural N wall x=2 to 6, 2.5 m tall. Card grunt #1 seated at (10, 4), facing north (notice cone 2 m in front only). Supply crate (12.5, 7).
- Spawns: `from_tunnel` (1.2, 8) (also the debug warp spot for this floor), `from_lift` (15, 3), `from_above` (12, 1.2).

**T1 Cable Hall (`tower_cable_hall`)**
- Floor 16 × 10 m. Camera bounds X 5 to 11, Z 4 to 6.
- Doors: stairhead (2, 8) back down → `tower_sump:from_above`; card door 1 N wall @ x=12 → `tower_bell_gallery:from_below` (requires 1 card).
- Ledge: x=0 to 3, z=0 to 4, 1.8 m high; chalk stash on it at (1, 1). Push crate starts at (7, 3) and moves along z=3 only; it snaps at (3.45, 3) against the ledge's east face (grid push, 1 m per push, no diagonal). Reset if the room reloads before it's placed; once placed, it stays (flag `t1_crate_placed`).
- Patrol `drone_flock`: circle around (8, 5), radius 3, hovering. Dodge lane z=8.5 to 10.
- Spawns: `from_below` (2, 8), `from_above` (12, 1.2).

**T2 Bell Gallery (`tower_bell_gallery`)**
- Floor 16 × 10 m. Camera bounds X 5 to 11, Z 4 to 6.
- Doors: stairhead (3.5, 8.5) → `tower_cable_hall:from_above`; stairs up N wall @ x=12 → `tower_generator:from_below`.
- Bells on a beam along the W wall, ring points 0.8 m out: big (0.8, 2), middle (0.8, 4), little (0.8, 6), tiny (0.8, 8). The stairhead on this floor sits at (3.5, 8.5) instead of (2, 8), so the tiny bell isn't on the arrival spot. Hatch chest at (4, 5), hidden until `bells_solved`. Slit window N wall @ x=3.
- Patrol `card_pair`: waypoints (5, 3) → (12, 3) → (12, 7) → (5, 7).
- Spawns: `from_below` (3.5, 8.5), `from_above` (12, 1.2).

**T3 Generator Deck (`tower_generator`)**
- Floor 16 × 10 m. Camera bounds X 5 to 11, Z 4 to 6.
- Doors: stairhead (2, 8) → `tower_bell_gallery:from_above`; rubble pile at N wall @ x=12 (examine only); lift door (15, 2.1) (active once `lift_powered`).
- Switch cage 3 × 3 m at x=0.5 to 3.5, z=0.5 to 3.5; card door 2 on its east side at (3.5, 2) (requires 2 cards); lever at (1.5, 1.5).
- Catwalk 1.8 m high, 1.2 m wide, x=9 to 13.5 at z=4 to 5.2; step crate at (9.5, 6), 0.9 m; supply crate on the catwalk at (13, 4.6).
- Generator box 3 × 2 m at (6, 6).
- Spawns: `from_below` (2, 8), `from_lift` (15, 3).

**T4 Jammer Deck (`tower_jammer_deck`)**
- Floor 18 × 12 m, 4 m walls (the lift shaft and the mast column stay at the same x). Camera bounds X 5 to 13, Z 4 to 8.
- Doors: lift door (15, 2.1); card door 3 N wall @ x=3.5 → `tower_landing:from_below` (requires 3 cards).
- Console 3 × 1.5 m at (9, 6). Patrol `squad_four`: loop (5, 4) → (13, 4) → (13, 8.5) → (5, 8.5). Quota pen: x=0 to 4, z=8 to 12, fence 1.1 m with a 1.4 m gap at (4, 10); ambush enemies at (1.5, 9), (2.5, 11), (3, 9.5) (stationary); crate at (1, 11.2).
- Spawns: `from_lift` (15, 3), `from_above` (3.5, 1.2).

**T4b Last Landing (`tower_landing`)**
- Floor 8 × 6 m, 3 m walls. Yaw 45. Camera fixed at (4, 3).
- Doors: S edge @ x=4 → `tower_jammer_deck:from_above`; stairs up N wall @ x=6 → `tower_roof:from_below`.
- Save lamp niche W wall @ z=2. Old Zero at (5, 2.5) with the thermos (heal once, flag `thermos_used`). Coat rack (2, 0.5).
- Spawns: `from_below` (4, 5), `from_above` (6, 1.2).

**T5 The Roof (`tower_roof`)**
- Floor 20 × 14 m; the mast top and its three rings rise from the N wall at x=8 to 12; railings on the S and E edges (no walk-off). Yaw 30, pitch a little higher and camera further back than the floors (about 1.3 × the usual frame). Camera bounds X 8 to 12, Z 6 to 8.
- Doors: stairhead at (3, 12) → `tower_landing:from_above` (blocked by the boss scene until Kasp is beaten).
- Boss trigger: plane at z=10. Arena: clear floor x=4 to 18, z=3 to 11 for the Hushmaster (assumed about 3.5 m tall with a 5 m leg span; confirm with the M5 blockout). Wreck and beacon-part spot at (11, 6) after the fight.
- Spawns: `from_below` (3, 12).

**Data hooks (suggestions; GP-A and GP-B own the files):** beats `b2_road`, `b3_tower`, `b4_kasp_beaten`. Flags `mox_crate_scene`, `mox_joined`, `zeroes_back_way`, `has_bell_napkin`, `t1_crate_placed`, `bells_solved`, `lift_powered`, `thermos_used`, `kasp_beaten`, `card_grunt_1_beaten` / `_2_` / `_3_`. Card count read from the Kasp's Access Cards key item quantity. Auto-save fires on entering R1 (the road) and T0 (the tower). Pickup contents are suggestions; the Battle Programmer finalizes them in placements.json (Equipment & items is Level 2).

---

## Choices for Ross

DECISION NEEDED: What shape should the tower be?
Option A: **A stack, one room per floor** (as drawn: bottom floor, four floors, a landing, the roof; 7 rooms), with the cage lift covering the one broken flight and doubling as a shortcut back down to the first save lamp (the Dark Souls elevator trick) — pros: easy to read, about 11 minutes, one kit you re-dress per floor / cons: each floor is one scene, so "climbing around the mast" is told more by the mast in every room than by the path itself.
Option B: **A spiral:** each floor split into two half-rooms that wrap around the mast (about 12 rooms) — pros: the strongest feeling of winding up the mast; more nooks for treasure / cons: nearly twice the rooms to build and dress, about 4 minutes longer, and it starts to feel like padding.
Option C: **A central lift shaft as the hub,** with each floor branching off it (FF7's Shinra elevator, Mega Man Legends' ruins) — pros: impossible to get lost; one big memorable set / cons: you keep coming back to the same room, the lift ride starts to feel like a loading screen, and the climb loses its sense of going up.
Recommendation: A. It hits the 12-minute target with the least art and keeps the climb moving.

DECISION NEEDED: How long is the road between town and the tower?
Option A: **Two scenes:** the road (Mox's crate scene and one dodgeable patrol) and the mast foot (the sit-in) — pros: each story beat gets its own stage; about 4 minutes, right on target / cons: one more set for you than option B.
Option B: **One long scene:** the road runs straight into the mast foot — pros: the tightest (about 3 minutes); one set / cons: two story scenes back to back in one room, and the camera slides about 40 meters.
Option C: **Three scenes,** adding a wreck field with a second patrol and a chalk stash — pros: more to find / cons: about 6 minutes; this is the kind of stretch the "keep pacing tight" rule is meant to stop.
Recommendation: A. It's the approved 4 minutes and gives Mox and the Zeroes their own moments.

DECISION NEEDED: Can the player skip the fights that drop Kasp's access cards?
Option A: **No: three card fights must be won** (one per card door); every other enemy can be dodged — pros: guarantees players learn Clutch, blocks and skills before Kasp, and keeps levels on track for about level 6 / cons: three fights in the tower you can't avoid.
Option B: **Yes: every card has a second source** (a crate, or a sleeping grunt you can sneak up on), so every fight is optional — pros: the "see every fight coming and choose" promise holds completely / cons: a sneaky player can reach Kasp under-leveled, and it adds placements and tuning.
Option C: **One card opens everything** (all of Kasp's cards are the same card): one must-win fight in the tower — pros: simplest / cons: loses the card-count joke and the steady rhythm of fights that teach the battle system.
Recommendation: A. Three must-win fights in 12 minutes is the classic JRPG dungeon rhythm, and they double as the battle tutorial.

*Studio calls made inside this map (overturnable, logged on approval):* cards are counted, not spent; T3 has no enemies (breather); the old Zero heals once; card grunts carry a visible lanyard marker; the roof camera pulls back; pickup contents and encounter ids are suggestions for the Battle Programmer; room ids and spawn names are suggestions for GP-A.
