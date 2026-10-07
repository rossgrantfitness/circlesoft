# Harrow Landing: layout map (vertical slice)

> Task M3-1 · Owner: Creative Director (proposes) · Ross (approves).
> **Status: DRAFT for Ross's sign-off. Nothing here is final.** The build (M3-4) starts only after Ross signs off.
> Companion page: docs/maps/road_and_tower.md.

## For Ross (the short version)

- **What this is:** a floor plan of the town for the slice. **3 outdoor scenes** (Lamp Square, the Docks, the Signals Checkpoint) and **6 indoor rooms** (Red's home, courier office, general store, gear shop, Otis's dock office, the bar). 9 rooms in total.
- **How it plays:** Red wakes at her window lamp, takes the tower job at the courier office next door, goes down to the docks to collect the crate, and walks straight into Kasp's crew. After the dock fight Otis is in, the whole town is open, and the checkpoint lets her out to the road.
- **Pace:** about **8 to 9 minutes** in town, with about 1.5 minutes of actual walking. The rest is the opening, the dock fight, shops and talking. Every door is no more than one scene away from the square.
- **Small extras, all on the way:** two side deliveries that sit on the route you already walk (no backtracking), five hidden items, and about 16 townsfolk whose lines change after the dock fight.
- **Art:** everything here is gray boxes and reused models for now (see "What stands in for art"). Your town set (art rows 17 and 18) is these 9 rooms, and nothing more.
- **Three choices for you are at the bottom of this page:** the town's shape, who ordered Red's delivery, and whether the slice ends with a short walk home through town. The map is drawn with the studio's recommended answer to each; another pick changes only the parts named in that choice.

**Borrowed, openly, with our own surface:** the night-time opening town with a road block keeping you in is EarthBound's Onett on meteor night (their police block becomes Kasp's checkpoint). The compact hub where every shop is one scene from the square is Mario RPG's Rose Town and Kalm in FF7. The "carry this across town" side jobs are FF9's Mognet letters. Glinting pickups and crate-top secrets are FF7's. Each is one borrowed role; the names, people, jokes and look are ours, so the stacking test passes.

## Box diagram

```
                                 to THE ROAD (road_and_tower.md)
                                           ^
                                           | road gate (boom barrier)
                               +-----------+------------+
                               |  H3 SIGNALS CHECKPOINT  |
                               +-----------+------------+
                                           ^ gate arch
  +-----------+         +------------------+-------------------------------+
  | H4 RED'S  |<------->|                H1 LAMP SQUARE  (hub)              |
  |   HOME    | W wall  |  N wall: [H5 Courier] [H6 Store] (alley) [H7 Gear]|
  +-----------+  door   |  dark window (side job 1)    public lamp post     |
                        +------------------+-------------------------------+
                                           | stairs down (south edge)
                        +------------------+-------------------------------+
                        |                 H2 THE DOCKS                      |
                        |  N wall: [H8 Otis's Dock Office]      [H9 Bar]    |
                        |  crate stack (west)            pier (south-east)  |
                        +--------------------------------------------------+

  H5, H6, H7 open off the square; H8 and H9 open off the docks. Each interior has one door back to its street.
```

## The route through town (main path)

1. **H4 Red's home.** Opening scene: the lamp check at the window. The game starts here. Auto-save on new game.
2. **H1 Lamp Square → H5 Courier Office.** Take the main job (Courier Job Slip: "Pick up crate at Otis's dock office, deliver to the Old Relay Tower"). The two side deliveries are on the same board.
3. **H1 → H2 The Docks.** A dockhand at the top of the stairs lets Red down only once she has a slip. Entering the docks plays the Kasp scene: his crew shoving Otis's dockhands around. Red is already swinging before Otis finishes asking. **Dock fight** (story fight, can't run). Otis joins.
4. **H8 Otis's office.** Pick up the delivery crate (key item). Story beat changes to "Otis joined". **The whole town is now open.**
5. **Free roam (optional):** shops, the bar, side deliveries, hidden items, rest at home.
6. **H3 Checkpoint.** The grunts have been radioed up to the tower; Otis lifts the boom barrier ("Mostly structural."). Out to the road.

**Story beats used in town** (the NPC line sets):
- **B1 Night:** from the opening to the dock fight.
- **B2 Otis joined:** after the dock fight until Red leaves town.
- **B3 Home again:** only if Ross picks B or C in Decision 3 (a short walk home after Kasp).

## Rooms

Conventions for every room are in "Graybox build notes" further down. Line sets are high level; the Writer writes the words in M6-2.

### H1 Lamp Square (`harrow_square`): the hub
- **What it is:** the town square at night, every window lamp lit except one. Shopfronts on the back walls, a tall public lamp post in the middle, stairs down to the docks at the front edge, the gate arch to the checkpoint at the back right.
- **Doors:** H4 Red's home (west wall), H5 Courier Office, H6 General Store, H7 Gear Shop (north wall), gate arch to H3 (north wall, east end), stairs down to H2 (front edge).
- **NPCs (crowd, plain boxes):**
  - *The Bettor* at the lamp post. B1: odds on Kasp versus Watch Zero ("who cracks first"). B2: rewriting the board because a courier and a bear beat Kasp's crew. B3: paying out, very upset.
  - *A neighbor* by Red's door. B1: notices Red's lamp is lit, as always. B2: heard the docks got loud. B3: points up at the lit windows.
  - *Coldrunner snack seller* near the stairs (selling to both sides, per the story bible). B1: half price if you're not wearing headphones. B2: sold out to the Signals, "they stress-eat".
  - *Dock gate dockhand* at the top of the stairs. B1 without the slip: "Docks are shut, Red, Signals business. Unless you've got a pickup slip?" With the slip: steps aside. Gone in B2.
  - *Mox cameo* (B1 only, plays once, no dialogue): a dock kid in a welding mask darts out of the alley and down the dock stairs as Red first steps out of her home. Sets up the crate on the road.
- **Side delivery 1, "The dark window":** one upstairs window on the north wall (above H6) is the only dark one on the square. Red hops two crates onto the little balcony and lights it with a short lamp check (reuses her rest/save animation; no new animation). Reward pops on the sill.
- **Hidden item:** the alley alcove between H6 and H7 has a chalked shuttered lantern on the wall and a crate behind trash cans: **Smoke Bomb ×1 + 60 credits.** First sight of the Coldrunner chalk mark, which pays off in the tower's chalk stashes.
- **Examine spots (Writer fills the text):** the public lamp post, the bets chalkboard by the Bettor, the notice board of Signals "Quiet Hours" posters.

### H2 The Docks (`harrow_docks`)
- **What it is:** a long wharf at night, warehouse fronts on the back wall, a crane and container stack on the west side, water along the front edge, a short pier sticking out toward the camera.
- **Doors:** stairs up to H1 (north wall, middle), H8 Otis's Dock Office (north wall, west), H9 Bar (north wall, east).
- **Story scene + dock fight (B1, once):** Kasp and two grunts shove dockhands by the crane; Otis steps out of his office. **Encounter:** `grunt_pair`, story fight (no Run), party Red + Otis from the first turn. The cutscene covers Otis joining, so no mid-fight join is needed (that feature belongs to Vela's fight, Later). After the K.O., Kasp "circles back" and storms off toward the checkpoint.
- **NPCs:** *Otis* (B1 scene only; in the party after). *Kasp* and *2 grunts* (B1 scene only). *3 dockhands* (crowd). B1: frightened, being ticketed. B2: thanking Red; one of them, **Pell**, hands over the Appeal Form for side delivery 2. B3: reenacting the fight badly.
- **Hidden items:**
  - **Crate stack (west end), the town's jump lesson:** hop one crate, then a second; on top, **Can of Chili ×2** (glints).
  - **End of the pier:** **Canned Coffee ×2** (glints).
- **Examine spots:** the crane, a tide board, Otis's dockhand roster window.

### H3 Signals Checkpoint (`harrow_checkpoint`)
- **What it is:** the road gate out of town. A blue-gray Signals booth, a boom barrier, "Quiet Hours Are Happy Hours" posters with Kasp's face, a line of Marchfolk holding confiscated wind chimes.
- **Doors:** gate arch back to H1 (front edge), boom barrier to the road (north wall).
- **B1:** two grunts at the barrier. First entry plays a 20-second scene: a grunt writes a noise ticket for a wind chime. Barrier locked: "Road's closed. Signals business."
- **B2:** the grunts are gone (radioed up to the tower). First entry with Otis plays a 15-second scene: Otis lifts the barrier and props it open. It stays open after that.
- **Side delivery 2, "Appeal in triplicate":** drop Pell's Appeal Form in the booth's APPEALS slot. A recorded voice says the appeal is important to them. Pell's reward arrives on the spot (he's watching from the arch).
- **Hidden item:** confiscation bin behind the booth (examine, no glint): **Earplugs** (charm; guards against Noise Ticket, which the tower uses a lot).
- **NPCs:** *2 grunts* (B1). *3 Marchfolk in line* (crowd). B1: grumbling about tickets. B2: "they just left!", cheering. B3: hanging their wind chimes back up.

### H4 Red's Home (`harrow_home`)
- **What it is:** one small room. The window with the brass lamp is the heart of it.
- **The window lamp:** rest (free full heal) and save, with the lamp check. Also where the slice opens and ends.
- **Pickup:** the pantry tin: **Ration Bar ×2** (visible, a starter, not a secret).
- **Examine spots:** the window and lamp, a wall of tally marks (one per night for ten years), a photo on the shelf, Mom's old flight charts. Text from the Writer.
- **NPCs:** none. Red lives alone; that is the point of the first shot.

### H5 Courier Office (`harrow_courier`)
- **What it is:** a cramped dispatch office: parcel shelves, a counter, the job board.
- **Job board:** the main job, plus the two side deliveries. Taking a job is one press each; the board shows what's taken and done.
  - **Main:** "Crate, one, from Otis's dock office to the Old Relay Tower." (Who ordered it is Decision 2.)
  - **Side 1, "The dark window":** "Lamp oil, one can, to the dark window on Lamp Square. Tonight." The oil can is handed over when you take the job. **Reward: Lucky Bolt (charm) + 100 credits.** It turns out the window belongs to the old barfly in H9, who spent his lamp-oil money on bets.
  - **Side 2, "Appeal in triplicate":** "Collect a form from Pell at the docks; deliver to the checkpoint." **Reward: 150 credits + Appeal Form ×2** (the Noise Ticket cure, handed over right before the tower needs it).
- **NPCs:** *the Dispatcher* (proposed Key NPC A, portrait set art row 11; final pick in M6-1). B1: gives the job, fusses about the deadline. B2: "Crate picked up? Then why are you still standing here?" B3: stamps the job DONE with relish. *A sleeping courier* (crowd) who never wakes up, in any beat.

### H6 General Store (`harrow_store`)
- **What it is:** shelves of cans and bottles, a counter.
- **Shop:** the general store (healing, Juice, cures, Camp Stoves, throwables). Stock lives in data/shops (UI Programmer A, M3-7); the map only places the counter.
- **NPCs:** *shopkeeper* (crowd). B1: Watch Zero bought every thermos in the shop. B2: wants to hear about the fight. *One customer* (crowd): a nervous Signals clerk buying antacids (B1 only).

### H7 Gear Shop (`harrow_gear`)
- **What it is:** a junk-and-gear shop: scrap piles, a rack of scavenged swords, a workbench.
- **Shop:** weapons, armor and charms (data/shops, M3-7). Mox's shop weapon is on sale before Mox joins, the FF way.
- **NPCs:** *shopkeeper* (crowd, welding apron). B1: sizing up Red's sword. B2: "Heard you dented a Signals helmet. Want a better dent-maker?"
- **Examine:** a sign, "Ask about the Wicked Awesome" (flavor for the late-game ultimate sword; the Writer may cut it).

### H8 Otis's Dock Office (`harrow_dock_office`)
- **What it is:** a small office: Otis's desk, a roster board, the delivery crate by the door.
- **Story prop (locked):** the rusty ship's bridge lamp on Otis's desk. Placement and examine text are fixed by the Creative Director and Writer; don't move it or change its line.
- **Pickup:** the **Delivery Crate** (key item). Examining it before taking it shows a tiny "MOX WUZ HERE" scratch on the lid ("Kids.").
- **Examine spots:** the roster board (Otis counts his dockhands off shift by name every night), the dented tin of cough drops.
- **NPCs:** none in B2 (Otis is in the party; he chimes in: "Crate's by the door, friend.").
- **Locked in B1?** Not needed: the dock fight starts the moment Red enters the docks, so the office can't be reached before it.

### H9 The Bar (`harrow_bar`, working name "The Long Wait"; the Writer may rename)
- **What it is:** the dockside bar: counter, stools, a jukebox, the bets board on the back wall.
- **Bets board:** flavor only in the slice (the minigame is on the Later list). Its odds change by beat.
- **NPCs:** *bartender* (crowd). *3 barflies* (crowd, gossip and rumors about the call, the Zeroes, the tower). *The old barfly* whose window is dark (side delivery 1): B1: complains his lamp's out. After the job: quiet thanks, he knows it was the Kincaid kid. **The legend gag (B2):** one barfly tells the room Red flattened fifty troopers; Red does her legend correction (three fingers, then two more, then a flex). Placeholder: her gesture pop-ups in the bubble, since gesture animation clips are on hold.
- **Hidden item:** behind the jukebox: **Ginger Chews ×2.**

## Locks and what opens them

| Lock | Where | Opens when | Message while locked |
|---|---|---|---|
| Dock stairs (a dockhand blocks them) | H1 → H2 | Main job taken (`job_main_taken`) | "Docks are shut, Red. Signals business. Unless you've got a pickup slip?" |
| Boom barrier | H3 → road | Dock fight won (`otis_joined`); Otis lifts it in a scene | "Road's closed. Signals business." |
| Everything else | | Open from the start | |

No dead ends: if Red visits the docks stairs first, the dockhand points her to the courier office, which is the first door on the square.

## Walking time and pacing

| Piece | Rough time |
|---|---|
| Opening scene and lamp check (H4) | 1:00 |
| Walk home → courier office → take the job | 0:40 |
| Walk to the docks, Kasp scene, dock fight, Otis joins | 3:00 |
| Pick up the crate (H8) | 0:20 |
| Free roam: shops, bar, side deliveries, hidden items (optional) | 2:00 to 3:00 |
| Checkpoint scene and out | 0:30 |
| **Harrow total** | **about 8 to 9 minutes** (target in the design doc: 8) |

- **Actual walking** on the main path is about 70 meters, about 20 seconds at a run. With every side detour it's about 220 meters, about 1.5 minutes, plus about 15 room fades.
- **If the slice runs long,** trim free roam first (fewer barfly lines), never the side deliveries: both sit on the main route and pay for the tower.
- **Credits from town:** about 310 (two side jobs and the alley pouch) plus the dock fight. The Battle Programmer checks this against the ~1,500-by-Kasp target in M4-3.

## What stands in for art (placeholders only, no new character modeling)

| Who or what | Stand-in |
|---|---|
| Red, Otis, Mox | `red_shiba`, `chr_otis`, `chr_mox` (existing) |
| Kasp | `enm_grunt_variant` scaled about 1.2, brown tint, a flat box for his paddle tail |
| Signals grunts | `enm_signals_grunt` (existing) |
| Dockhands | capsule-and-sphere NPC fallback (`npc.gd`), orange tint, sphere hard hat |
| Marchfolk, Bettor, barflies, neighbor | capsule fallback, varied dust-color tints, one accessory sphere or box each |
| Shopkeepers, bartender | capsule fallback with an apron-colored band |
| Dispatcher (Key NPC A) | capsule fallback with a cap box; initials-head portrait until art row 11 |
| Coldrunner snack seller | capsule fallback, dark coat tint, a small amber sphere for the shuttered lantern |
| Buildings and facades | boxes and planes with flat colors and labels; window lamps are small amber emissive quads (one left dark on H1) |
| Lamp post, crane, booth, barrier, jukebox, crates | boxes and cylinders; delivery crate and supply crate use the existing crate shapes if any, else 0.9 m cubes |

## Graybox build notes (for the Gameplay Programmer, M3-4)

**Conventions for every room (Harrow, road and tower):**
- **Units:** meters. Red is 1.0 m tall. Run 5.2 m/s, jump 1.2 m (data/world/field_tuning.json), so **any step up must be 1.0 m or less**; crates are 0.9 m cubes.
- **Origin:** the floor corner where the two back walls meet. **+X runs east along the north wall; +Z runs south toward the camera along the west wall.** "N wall @ x=4" means a door centered at (4, 0); "W wall @ z=6" means (0, 6).
- **Back walls** are north and west. **Front edges** (south and east) have no wall: exits there are walk-off edges marked with a lit doormat or steps, with the door trigger just past the edge.
- **Interiors exit on the front edge** (south), so the back walls stay free for set dressing.
- **Camera:** pitch about 40 to 45 degrees down, narrow FOV per the style guide, frames about 10 × 5.6 m of floor. "Yaw 45" means the camera sits off the south-east corner looking into the north-west corner; "yaw 20" is closer to straight-on, for long streets. Camera bounds below are the box the camera's focus point may slide in; a single point means the camera is fixed.
- **Doors:** 1.2 m wide indoors, 1.4 m outdoors unless noted; trigger depth 0.5 m. Every door lists its target as `room:spawn`.
- **Wall heights:** interiors 3.0 m; street facades 4.5 m; the docks warehouses 5.0 m.

**H1 Lamp Square (`harrow_square`)**
- Floor 22 × 12 m. Yaw 30. Camera bounds X 5 to 17, Z 4 to 8.
- Doors: H5 at N wall @ x=4 → `harrow_courier:from_square`; H6 at N @ x=8.5 → `harrow_store:from_square`; H7 at N @ x=16 → `harrow_gear:from_square`; gate arch N @ x=20, 3 m wide → `harrow_checkpoint:from_square`; H4 at W wall @ z=4 → `harrow_home:from_square`; dock stairs on the S edge, x=9 to 12 → `harrow_docks:from_square`.
- Alley alcove: a notch in the N wall, x=11.5 to 13.5, 3 m deep (z = -3 to 0). Chalk decal on its back wall, stash crate at (12.5, -2.3).
- Dark window: on the N wall above H6, sill at 2.6 m, x=6 to 8. Balcony ledge 1.8 m high, 2 m wide, 0.6 m deep under it. Crates: one at (6.5, 1.2) and the ledge reached from its top (0.9 → 1.8).
- Public lamp post at (11, 6), 4 m tall (fades when Red is behind it).
- Spawns: `from_home` (1.2, 4), `from_courier` (4, 1.2), `from_store` (8.5, 1.2), `from_gear` (16, 1.2), `from_checkpoint` (20, 1.5), `from_docks` (10.5, 10.8).
- NPC markers: Bettor (12, 6.5), neighbor (2, 6), snack seller (14, 10), dock-gate dockhand (10.5, 10.2, B1 only), Mox cameo path alley (12.5, -1) → stairs (10.5, 12).

**H2 The Docks (`harrow_docks`)**
- Wharf floor 24 × 9 m; water plane in front from z=9; pier 3 × 4 m at x=20 to 23, z=9 to 13. Yaw 25. Camera bounds X 5 to 19, Z 4 to 7.
- Doors: stairs up in the N wall @ x=12, 3 m wide → `harrow_square:from_docks`; H8 at N @ x=5 → `harrow_dock_office:from_docks`; H9 at N @ x=19 → `harrow_bar:from_docks`.
- Crate stack: crate A at (3.2, 6), 0.9 m; crate B at (2, 6) on a 0.9 m base, top at 1.8 m; pickup on crate B.
- Pier-end pickup at (21.5, 12.5).
- Dock fight: scene trigger plane at z=1.5 just past the stairs (fires once). Kasp (13, 4), grunts (12, 5) and (14, 5), dockhands huddle (9, 3), Otis enters from H8's door.
- Spawns: `from_square` (12, 1.5), `from_dock_office` (5, 1.2), `from_bar` (19, 1.2).

**H3 Signals Checkpoint (`harrow_checkpoint`)**
- Floor 14 × 9 m. Yaw 30. Camera bounds X 5 to 9, Z 4 to 5.
- Doors: arch on the S edge, x=6 to 9 → `harrow_square:from_checkpoint`; boom barrier in the N wall @ x=10, 3 m wide → `road_mast_road:from_harrow` (locked until `otis_joined`).
- Booth 2 × 2 × 2.5 m at (5, 2); APPEALS slot interactable on its south face. Confiscation bin (examine) at (3, 0.8), behind the booth. Barrier arm is a 3 m box that pivots up 80 degrees.
- Spawns: `from_square` (7.5, 7.8), `from_road` (10, 1.5).
- NPC markers: grunts (9, 2) and (11, 2) (B1 only); Marchfolk line (7, 6), (8.2, 6), (9.4, 6).

**H4 Red's Home (`harrow_home`)**
- Floor 7 × 5 m. Yaw 45. Camera fixed at (3.5, 2.5).
- Door: S edge @ x=5.5 → `harrow_square:from_home`.
- Window lamp interactable (rest + save) at N wall @ x=3, sill 1.0 m. Bed against the W wall at z=1 to 3. Tally-mark wall: W wall, z=3 to 5. Pantry tin at (6.2, 0.6).
- Spawns: `start` (3, 1.2, facing the window), `from_square` (5.5, 4).

**H5 Courier Office (`harrow_courier`)**
- Floor 8 × 6 m. Yaw 45. Camera fixed at (4, 3).
- Door: S edge @ x=4 → `harrow_square:from_courier`.
- Counter along the N wall, x=2 to 6, 0.9 m from the wall; Dispatcher behind it at (4, 0.5). Job board: W wall @ z=2.5. Sleeping courier on a bench at (7, 4).
- Spawn: `from_square` (4, 5).

**H6 General Store (`harrow_store`) and H7 Gear Shop (`harrow_gear`)** (same shell, re-dressed)
- Floor 7 × 5 m. Yaw 45. Camera fixed at (3.5, 2.5).
- Door: S edge @ x=3.5 → `harrow_square:from_store` / `from_gear`.
- Counter along the N wall, x=2 to 5; shopkeeper at (3.5, 0.5); the shop opens from the counter's front face. H6 customer at (5.8, 3). H7 sword rack on the W wall.
- Spawn: `from_square` (3.5, 4).

**H8 Otis's Dock Office (`harrow_dock_office`)**
- Floor 7 × 5 m. Yaw 45. Camera fixed at (3.5, 2.5).
- Door: S edge @ x=2 → `harrow_docks:from_dock_office`.
- Desk at N wall @ x=3 (story prop: bridge lamp on its east end). Roster board W wall @ z=2.5. Delivery crate (key-item pickup) at (5.5, 3.5).
- Spawn: `from_docks` (2, 4).

**H9 The Bar (`harrow_bar`)**
- Floor 9 × 6 m. Yaw 45. Camera fixed at (4.5, 3).
- Door: S edge @ x=7 → `harrow_docks:from_bar`.
- Bar counter along the W wall, z=1 to 4; bartender at (0.6, 2.5). Bets board on the N wall @ x=4.5. Jukebox at (8.3, 0.6); pickup behind it at (8.6, 0.3). Barflies at (2, 2), (3, 4), (5.5, 2); old barfly at (6.5, 4).
- Spawn: `from_docks` (7, 5).

**Data hooks (names are suggestions; GP-A and GP-B own the files):** story beats `b1_night`, `b2_otis_joined`, `b3_home_again` (only if Decision 3 is B or C). Flags `job_main_taken`, `job_dark_window_done`, `job_appeal_done`, `otis_joined`, `checkpoint_open`, `mox_cameo_seen`, `dock_fight_won`. Pickups go in data/world/placements.json; contents above are suggestions, and the Battle Programmer finalizes them (Equipment & items is Level 2).

---

## Choices for Ross

DECISION NEEDED: What shape should the town be? (This sets your environment set list for Harrow.)
Option A: **A hub square plus the docks and the checkpoint** (3 outdoor scenes, as drawn above), in the spirit of Mario RPG's Rose Town and FF7's Kalm — pros: every shop is one scene from the square; least walking (about 1.5 minutes); 3 outdoor sets for you; the square later works as the curfew set and as Biscuit's stomp arena / cons: the square is busy (five doors and a gate across two walls), so it needs clear signs.
Option B: **One long main street** with every door along it and the checkpoint at the far end (2 outdoor scenes: the street and the docks), like Onett's main drag in EarthBound — pros: a strong pull toward the road out; one repeating facade to model / cons: the camera slides a lot and shops are 8 to 10 seconds apart; "the square" moment for the lockdown later is lost.
Option C: **Two tiers:** an upper town and the docks below, joined by a big cargo lift, plus a back-alley scene (4 outdoor scenes), like FF7's Junon — pros: the most character and height; sets up Biscuit stepping down the tiers in Act 1 / cons: one more outdoor set for you and about 40 seconds more walking in the slice.
Recommendation: A. It's the tightest pace and the least art, and it still gives the lockdown and the Biscuit stomp a stage later.

DECISION NEEDED: Who ordered the crate Red is delivering to the tower? (A story detail that sets up the road and the tower.)
Option A: **Watch Zero ordered it:** supplies for the sit-in (thermoses and cushions) — pros: the road scene has a reason; the Zeroes owe Red, so showing her the back way is a thank-you; the thermos the old Zero heals you with before the boss is the one Red carried up / cons: the checkpoint needs another reason to open (Otis lifts the barrier, a 15-second scene).
Option B: **The Signals Corps ordered it:** Kasp's catering — pros: the funniest; the slip doubles as a pass through the checkpoint; Mox stowed away in Kasp's lunch / cons: Red is working for Kasp while picking a fight with him, which muddies the hero beat; the back way needs its own reason.
Option C: **An anonymous Coldrunner crate** ("no questions", a chalk lantern on the lid) — pros: introduces the Coldrunners ahead of Tilly in Act 1 and teaches the chalk mark / cons: leaves a loose thread in the slice (nobody receives it).
Recommendation: A. Every piece of it pays off inside the slice: the delivery, the back way and the thermos are one chain.

DECISION NEEDED: After Kasp, does the slice cut straight to Red's window, or walk her home first?
Option A: **Cut straight to the window** (as the approved outline reads) — pros: the tightest ending; no extra lines / cons: the town's bets, the dark window and the barflies never get a payoff.
Option B: **A short playable walk home** through the square, the docks and the bar, with a third set of lines for everyone in town (bets paid out, the legend gag in the bar, lamps lit) — pros: the biggest payoff, and Harrow feels alive / cons: about 2 extra minutes (the slice runs about 32) and a third line set for about 16 townsfolk.
Option C: **A 30-second walk across Lamp Square only:** the crowd cheers, the Bettor pays out, one barfly tells the fifty-troopers tale and Red does her legend correction, then home to the window — pros: the payoff at a quarter of the cost (about 5 extra line sets) / cons: still a little longer than A.
Recommendation: C. It pays off the town in half a minute, gives Red's best gag a stage, and keeps the slice at about 31 minutes (26 skipping optional fights).

*Studio calls made inside this map (overturnable, logged on approval):* the dock stairs need the job slip; the dock fight puts Otis in from turn 1 rather than a mid-fight join; side deliveries sit on the route; pickup contents are suggestions for the Battle Programmer; room ids and spawn names are suggestions for GP-A.
