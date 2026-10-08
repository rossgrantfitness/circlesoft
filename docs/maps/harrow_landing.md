# Harrow Landing: layout map (vertical slice)

> Task M3-1 · Owner: Creative Director (proposes) · Ross (approves).
> **Status: ✅ APPROVED by Ross, 2026-10-07** (all six recommended picks; built as the M3-4 graybox). **Updated 2026-10-08 with Ross's approvals:** structure pass D1 A (New Game starts on the ore train; home is stop 2), tone pass D2 B (about half of Lamp Square's windows dark, a few relit on the walk home), and the grim slum look. Layout, doors, rooms, shops, side jobs and pickups are unchanged.
> Companion pages: docs/maps/ore_train.md (the opening, before town), docs/maps/road_and_tower.md (the Spillway and the jammer works, after town).

## For Ross (the short version)

- **Same 9 rooms, same doors, re-dressed as slums:** taller stacked shacks above the walls, cable nests, neon and grime. Nothing you can walk on moves.
- **The game now starts on the train.** Red jumps off, runs home through the Quiet Hours siren and lights her lamp (first save), then picks up a **claim slip**: her ditched crate washed up at Otis's dock.
- **About half of Lamp Square's windows are dark.** The side job is now "the dark window above the store". On the 30-second walk home after Kasp, a few dark windows light up again.
- **Pace:** about **8 minutes** in town, as before.

**Borrowed, openly, with our own surface:** the night-time opening town with a road block keeping you in is EarthBound's Onett on meteor night (their police block becomes Kasp's checkpoint). The compact hub where every shop is one scene from the square is Mario RPG's Rose Town and Kalm in FF7. The slum look is FF7's Sector 7 and Blade Runner's streets (tone guide). The "carry this across town" side jobs are FF9's Mognet letters. Glinting pickups and crate-top secrets are FF7's. Each is one borrowed role; the names, people, jokes and look are ours.

## Box diagram

```
                       to THE SPILLWAY (road_and_tower.md, room id road_mast_road)
                                           ^
                                           | boom barrier -> service stair down
                               +-----------+------------+
                               |  H3 SIGNALS CHECKPOINT  |
                               +-----------+------------+
                                           ^ gate arch
  +-----------+         +------------------+-------------------------------+
  | H4 RED'S  |<------->|                H1 LAMP SQUARE  (hub)              |
  |   HOME    | W wall  |  N wall: [H5 Courier] [H6 Store] (alley) [H7 Gear]|
  +-----------+  door   |  ~half the windows dark; the one above H6 = job 1 |
        ^               +------------------+-------------------------------+
        |                                  | stairs down (south edge)
  from THE ORE TRAIN    +------------------+-------------------------------+
  (ore_train.md: the    |                 H2 THE DOCKS                      |
   jump, then Red runs  |  N wall: [H8 Otis's Dock Office]      [H9 Bar]    |
   home; scene cut)     |  crate stack (west)   washed-up crate  pier (SE)  |
                        +--------------------------------------------------+

  H5, H6, H7 open off the square; H8 and H9 open off the docks. Each interior has one door back to its street.
```

## The route through town (main path)

0. **The ore train** (docs/maps/ore_train.md). New Game starts there, not here. The train map ends with the jump and a short scene cut to Red running into her home.
1. **H4 Red's home.** Red bursts in from the square with the Quiet Hours siren wailing outside and lights the window lamp anyway: the lamp check (first save offered; auto-save on entering Harrow). This is why she ran: she has never missed a night.
2. **H1 Lamp Square → H5 Courier Office.** The Dispatcher already knows: the crate washed up at Otis's dock and the Signals are all over it. Here's a **Claim Slip** (key item, same id as the old Courier Job Slip): "Claim your crate at Otis's dock, then finish the delivery to the Old Relay Tower." The two side deliveries are on the same board.
3. **H1 → H2 The Docks.** A dockhand at the top of the stairs lets Red down only once she has the claim slip. Entering the docks plays the Kasp scene: his crew ticketing Red's dripping crate ("Ticket for the crate!") and shoving Otis's dockhands around. Red is already swinging before Otis finishes asking. **Dock fight** (story fight, can't run). Otis joins.
4. **H8 Otis's office.** The dockhands have hauled the crate in. Pick it up (Delivery Crate, key item; still wet, a Signals ticket stapled to the lid, and a tiny "MOX WUZ HERE" scratch). Story beat changes to "Otis joined". **The whole town is now open.**
5. **Free roam (optional):** shops, the bar, side deliveries, hidden items, rest at home.
6. **H3 Checkpoint.** The grunts have been radioed up to the Works; Otis lifts the boom barrier ("Mostly structural.") onto the service stair down. Out to the Spillway.

**Story beats used in town** (the NPC line sets):
- **B1 Night:** from the run home to the dock fight. Quiet, short, tired lines (tone guide).
- **B2 Otis joined:** after the dock fight until Red leaves town. Louder: a door opening.
- **B3 Home again:** the 30-second walk across Lamp Square after Kasp (Decision 3, C, approved): the Bettor pays out, the legend gag, and a few dark windows relight.

## Rooms

Conventions for every room are in "Graybox build notes" further down. Line sets are high level; the Writer writes the words in M6-2 (and re-tones the built lines per docs/tone_guide.md).

**Slum re-dress, every outdoor room (scenery only, no layout change):** stacked shacks and lean-tos rise above the street facades, cable nests run between them along the back walls, neon and holo signs over the shopfronts, Signals propaganda posters half peeled over older Marchfolk paint with chalk lamps scrawled back on top, puddles, steam vents, grime. All from the grim dressing kit (art row 56). Same camera.

### H1 Lamp Square (`harrow_square`): the hub
- **What it is:** the town square at night under stacked shacks and cable nests, **about half the window lamps dark** (Ross, 2026-10-08). Shopfronts on the back walls, a tall public lamp post in the middle, stairs down to the docks at the front edge, the gate arch to the checkpoint at the back right. A propaganda screen over the gate arch loops Vane's broadcast.
- **Doors:** H4 Red's home (west wall), H5 Courier Office, H6 General Store, H7 Gear Shop (north wall), gate arch to H3 (north wall, east end), stairs down to H2 (front edge).
- **The windows:** 12 window lamps around the square, each its own light switch in data. **B1 and B2: 6 lit, 6 dark** (Red's own window lit). **B3 (the walk home):** 3 more relight one by one as Red crosses the square, plus the window above the store if side job 1 is done. Nobody comments; the Bettor looks up.
- **NPCs (crowd, plain boxes):**
  - *The Bettor* at the lamp post. B1: rations on whether the Zeroes crack by morning. B2: rewriting the board because a courier and a bear beat Kasp's crew. B3: paying out, very upset.
  - *A neighbor* by Red's door. B1: Red's lamp is lit again; hers went out in the spring. B2: heard the docks got loud. B3: looking up at a window that's lit again.
  - *Coldrunner snack seller* near the stairs (black-market rations, sells to both sides). B1: half price if you're not wearing headphones; don't ask whose truck. B2: sold out to the Signals, "they stress-eat".
  - *Dock gate dockhand* at the top of the stairs. B1 without the slip: "Docks are shut, Red. Signals business. Unless you've got a claim slip?" With the slip: steps aside. Gone in B2.
  - *Mox cameo* (B1 only, plays once, no dialogue): a dock kid in a welding mask darts out of the alley and down the dock stairs as Red first steps out of her home, heading for the washed-up crate. Sets up the crate in the Spillway.
- **Side delivery 1, "The dark window above the store":** the upstairs window on the north wall above H6, one of the dark ones. Red hops two crates onto the little balcony and lights it with a short lamp check (reuses her rest/save animation; no new animation). Reward pops on the sill. Lighting a window after Quiet Hours is a fine; she does it anyway.
- **Hidden item:** the alley alcove between H6 and H7 has a chalked shuttered lantern on the wall and a crate behind trash cans: **Smoke Bomb ×1 + 60 credits.** First sight of the Coldrunner chalk mark, which pays off in the Spillway and the Works' chalk stashes.
- **Examine spots (Writer fills the text):** the public lamp post, the bets chalkboard by the Bettor, the notice board of Signals "Quiet Hours" posters and Kasp's daily memo, the propaganda screen.

### H2 The Docks (`harrow_docks`)
- **What it is:** a long wharf at night under floodlights, warehouse fronts on the back wall, a crane and container stack on the west side, oily water along the front edge, a short pier sticking out toward the camera. Red's crate sits dripping at the water's edge where it washed up.
- **Doors:** stairs up to H1 (north wall, middle), H8 Otis's Dock Office (north wall, west), H9 Bar (north wall, east).
- **Story scene + dock fight (B1, once):** Kasp and two grunts are ticketing the washed-up crate and shoving dockhands by the crane; Otis steps out of his office. **Encounter:** `grunt_pair`, story fight (no Run), party Red + Otis from the first turn. The cutscene covers Otis joining. After the K.O., Kasp "circles back" and storms off toward the checkpoint; two dockhands carry the crate into Otis's office.
- **NPCs:** *Otis* (B1 scene only; in the party after). *Kasp* and *2 grunts* (B1 scene only). *3 dockhands* (crowd). B1: frightened, being ticketed. B2: "You hit a Sergeant. ...I forgot that was allowed."; one of them, **Pell**, hands over the Appeal Form for side delivery 2. B3: reenacting the fight badly.
- **Hidden items:**
  - **Crate stack (west end), the town's jump lesson:** hop one crate, then a second; on top, **Can of Chili ×2** (glints).
  - **End of the pier:** **Canned Coffee ×2** (glints).
- **Examine spots:** the crane, a tide board, Otis's dockhand roster window.

### H3 Signals Checkpoint (`harrow_checkpoint`)
- **What it is:** the Signals gate out of town, over the service stair down to the Spillway. A blue-gray Signals booth, a boom barrier, a slow searchlight, "QUIET HOURS SAVE LIVES" posters of Kasp's face with a chalk lamp scrawled over it, a line of Marchfolk holding confiscated wind chimes.
- **Doors:** gate arch back to H1 (front edge), boom barrier to the service stair and the Spillway (north wall).
- **B1:** two grunts at the barrier. First entry plays a 20-second scene: a grunt writes a noise ticket for a wind chime, forty credits off the ration card. Barrier locked: "Stair's closed. Signals business."
- **B2:** the grunts are gone (radioed up to the Works). First entry with Otis plays a 15-second scene: Otis lifts the barrier and props it open. It stays open after that.
- **Side delivery 2, "Appeal in triplicate":** drop Pell's Appeal Form in the booth's APPEALS slot. A recorded voice says the appeal is important to them. Pell's reward arrives on the spot (he's watching from the arch).
- **Hidden item:** confiscation bin behind the booth (examine, no glint): **Earplugs** (charm; guards against Noise Ticket, which the Works uses a lot).
- **NPCs:** *2 grunts* (B1). *3 Marchfolk in line* (crowd). B1: tired, short lines about tickets. B2: "they just left!", cheering. B3: hanging their wind chimes back up.

### H4 Red's Home (`harrow_home`)
- **What it is:** one small room. The window with the brass lamp is the heart of it.
- **Arrival (B1, once):** Red runs in from the square (spawn `from_square`) with the siren wailing; the scene walks her to the window and plays the lamp check, then offers the first save. About 1 minute. Siren audio stops when the lamp is lit.
- **The window lamp:** rest (free full heal) and save, with the lamp check. Also where the slice ends.
- **Pickup:** the pantry tin: **Ration Bar ×2** (visible, a starter, not a secret).
- **Examine spots:** the window and lamp, a wall of tally marks (one per night for ten years), a photo on the shelf, Mom's old flight charts, this month's lamp-oil ration slip. Text from the Writer.
- **NPCs:** none. Red lives alone.

### H5 Courier Office (`harrow_courier`)
- **What it is:** a cramped dispatch office: parcel shelves, a counter, the job board.
- **Job board:** the main job, plus the two side deliveries. Taking a job is one press each; the board shows what's taken and done.
  - **Main (the claim slip):** "Crate, one, washed up at Otis's dock. Claim it, deliver it to Watch Zero at the Old Relay Tower." The Dispatcher hands over the **Claim Slip** (key item).
  - **Side 1, "The dark window above the store":** "Lamp oil, one can, to the dark window above the store on Lamp Square. Tonight." The oil can is handed over when you take the job. **Reward: Lucky Bolt (charm) + 100 credits.** The window belongs to the old barfly in H9, who spent his lamp-oil ration on bets.
  - **Side 2, "Appeal in triplicate":** "Collect a form from Pell at the docks; deliver to the checkpoint." **Reward: 150 credits + Appeal Form ×2** (the Noise Ticket cure, handed over right before the Works needs it).
- **NPCs:** *the Dispatcher* (proposed Key NPC A, portrait set art row 11; final pick in M6-1). B1: hands over the claim slip, fusses about the Signals and the deadline. B2: "Crate claimed? Then why are you still standing here?" B3: stamps the job DONE with relish. *A sleeping courier* (crowd) who never wakes up, in any beat.

### H6 General Store (`harrow_store`)
- **What it is:** half-empty shelves of cans and bottles, a counter, a ration-card reader.
- **Shop:** the general store (healing, Juice, cures, Camp Stoves, throwables). Stock lives in data/shops; the map only places the counter.
- **NPCs:** *shopkeeper* (crowd). B1: Watch Zero bought every thermos in the shop. B2: wants to hear about the fight. *One customer* (crowd): a nervous Signals clerk buying antacids (B1 only).

### H7 Gear Shop (`harrow_gear`)
- **What it is:** a junk-and-gear shop: scrap piles, a rack of scavenged swords, a workbench.
- **Shop:** weapons, armor and charms (data/shops). Mox's shop weapon is on sale before Mox joins, the FF way.
- **NPCs:** *shopkeeper* (crowd, welding apron). B1: sizing up Red's sword. B2: "Heard you dented a Signals helmet. Want a better dent-maker?"
- **Examine:** a sign, "Ask about the Wicked Awesome" (flavor for the late-game ultimate sword; the Writer may cut it).

### H8 Otis's Dock Office (`harrow_dock_office`)
- **What it is:** a small office: Otis's desk, a roster board, the delivery crate by the door (carried in after the dock fight).
- **Story prop (locked):** the rusty ship's bridge lamp on Otis's desk. Placement and examine text are fixed by the Creative Director and Writer; don't move it or change its line.
- **Pickup:** the **Delivery Crate** (key item). Examining it before taking it shows the water stains, the stapled Signals ticket and a tiny "MOX WUZ HERE" scratch on the lid ("Kids.").
- **Examine spots:** the roster board (Otis counts his dockhands off shift by name every night), the dented tin of cough drops.
- **NPCs:** none in B2 (Otis is in the party; he chimes in: "Crate's by the door, friend.").
- **Locked in B1?** Not needed: the dock fight starts the moment Red enters the docks, so the office can't be reached before it.

### H9 The Bar (`harrow_bar`, working name "The Long Wait"; the Writer may rename)
- **What it is:** the dockside bar, the one warm room on the waterfront: counter, stools, a jukebox (unplugged after Quiet Hours), the bets board on the back wall.
- **Bets board:** flavor only in the slice (the minigame is on the Later list). Its odds change by beat.
- **NPCs:** *bartender* (crowd). *3 barflies* (crowd, gossip and rumors about the call, the Zeroes, the Works). *The old barfly* whose window is dark (side delivery 1): B1: his lamp's out and he's stopped caring. After the job: quiet thanks, he knows it was the Kincaid kid. **The legend gag (B2):** one barfly tells the room Red flattened fifty troopers; Red does her legend correction (three fingers, then two more, then a flex), and the bar laughs for the first time in the game. Placeholder: her gesture pop-ups in the bubble.
- **Hidden item:** behind the jukebox: **Ginger Chews ×2.**

## Locks and what opens them

| Lock | Where | Opens when | Message while locked |
|---|---|---|---|
| Dock stairs (a dockhand blocks them) | H1 → H2 | Claim slip taken (`job_main_taken`, same flag as before) | "Docks are shut, Red. Signals business. Unless you've got a claim slip?" |
| Boom barrier | H3 → service stair → the Spillway | Dock fight won (`otis_joined`); Otis lifts it in a scene | "Stair's closed. Signals business." |
| Everything else | | Open from the start | |

No dead ends: if Red visits the dock stairs first, the dockhand points her to the courier office, which is the first door on the square.

## Walking time and pacing

| Piece | Rough time |
|---|---|
| Run home and lamp check (H4) | 1:00 |
| Out to the courier office, claim slip | 1:00 |
| Walk to the docks, Kasp scene, dock fight, Otis joins | 3:00 |
| Pick up the crate (H8) | 0:20 |
| Free roam: shops, bar, side deliveries, hidden items (optional) | about 2:00 |
| Checkpoint scene and out | 0:30 |
| **Harrow total** | **about 8 minutes** (the structure pass gives back about a minute of free roam to pay for the train) |

- **Actual walking** on the main path is about 70 meters, about 20 seconds at a run. With every side detour it's about 220 meters, about 1.5 minutes, plus about 15 room fades.
- **If the slice runs long,** trim free roam first (fewer barfly lines), never the side deliveries: both sit on the main route and pay for the Works.
- **Credits from town:** about 310 (two side jobs and the alley pouch) plus the dock fight.

## What stands in for art (placeholders only, no new character modeling)

| Who or what | Stand-in |
|---|---|
| Red, Otis, Mox | `red_shiba_grim` (the grim look profile maps `red_shiba` to it), `chr_otis`, `chr_mox` (existing, grim texture treatment) |
| Kasp | `enm_grunt_variant` scaled about 1.2, brown tint, a flat box for his paddle tail |
| Signals grunts | `enm_signals_grunt` (existing) |
| Dockhands | capsule-and-sphere NPC fallback (`npc.gd`), faded rust tint, sphere hard hat |
| Marchfolk, Bettor, barflies, neighbor | capsule fallback, varied dull dust-color tints, one accessory sphere or box each |
| Shopkeepers, bartender | capsule fallback with an apron-colored band |
| Dispatcher (Key NPC A) | capsule fallback with a cap box; initials-head portrait until art row 11 |
| Coldrunner snack seller | capsule fallback, dark coat tint, a small amber sphere for the shuttered lantern |
| Buildings and facades | boxes and planes with the grim look profile's code-painted grime; window lamps are small amber emissive quads, each with an on/off switch (6 of 12 off on H1 at start) |
| Stacked shacks, cable nests, neon, posters, screens, floodlights, puddles, steam | the grim look test's existing code-painted placeholders (`scripts/core/grime_paint.gd` and the grim dressing); final art is row 56 |
| Lamp post, crane, booth, barrier, jukebox, crates | boxes and cylinders; delivery crate and supply crate use the existing crate shapes |

## Graybox build notes (for the Gameplay Programmer)

**Conventions for every room (Harrow, the train, the Spillway and the Works):**
- **Units:** meters. Red is 1.0 m tall (the grim Red is about 1.1 m to the top of the head; collision and step rules stay as below). Run 5.2 m/s, jump 1.2 m (data/world/field_tuning.json), so **any step up must be 1.0 m or less**; crates are 0.9 m cubes.
- **Origin:** the floor corner where the two back walls meet. **+X runs east along the north wall; +Z runs south toward the camera along the west wall.** "N wall @ x=4" means a door centered at (4, 0); "W wall @ z=6" means (0, 6).
- **Back walls** are north and west. **Front edges** (south and east) have no wall: exits there are walk-off edges marked with a lit doormat or steps, with the door trigger just past the edge.
- **Interiors exit on the front edge** (south), so the back walls stay free for set dressing.
- **Camera:** pitch about 40 to 45 degrees down, narrow FOV per the style guide, frames about 10 × 5.6 m of floor. "Yaw 45" means the camera sits off the south-east corner looking into the north-west corner; "yaw 20" is closer to straight-on, for long streets. Camera bounds below are the box the camera's focus point may slide in; a single point means the camera is fixed.
- **Doors:** 1.2 m wide indoors, 1.4 m outdoors unless noted; trigger depth 0.5 m. Every door lists its target as `room:spawn`.
- **Wall heights:** interiors 3.0 m; street facades 4.5 m; the docks warehouses 5.0 m.
- **Slum stacking (outdoor rooms, scenery only):** above each back wall, up to two tiers of shacks, each tier 2.5 to 3 m tall and set back 0.6 to 1.0 m from the one below (so the top reaches about 9 to 10 m). No collision. Cable runs hang between tiers along the back walls and over the alley at 5 m or higher, **never across the front half of the floor**, so nothing hangs between the camera and Red. Neon signs sit on the facade at 3 to 4.2 m.

**H1 Lamp Square (`harrow_square`)**
- Floor 22 × 12 m. Yaw 30. Camera bounds X 5 to 17, Z 4 to 8.
- Doors: H5 at N wall @ x=4 → `harrow_courier:from_square`; H6 at N @ x=8.5 → `harrow_store:from_square`; H7 at N @ x=16 → `harrow_gear:from_square`; gate arch N @ x=20, 3 m wide → `harrow_checkpoint:from_square`; H4 at W wall @ z=4 → `harrow_home:from_square`; dock stairs on the S edge, x=9 to 12 → `harrow_docks:from_square`.
- Alley alcove: a notch in the N wall, x=11.5 to 13.5, 3 m deep (z = -3 to 0). Chalk decal on its back wall, stash crate at (12.5, -2.3).
- **Window lamps (12, sill 2.6 m unless noted; L = lit at start, D = dark at start, R = relights in B3):** N wall: `win_01` x=2 (L), `win_02` x=5.5 (D, R), `win_03` x=6 to 8 above H6 (D; the side-job window, lit when `job_dark_window_done`), `win_04` x=10 (L), `win_05` x=14.5 (D), `win_06` x=17.5 (L), `win_07` x=18.8 (D, R), `win_08` x=21 (L). W wall: `win_09` z=2 (D), `win_10` z=5.5 above Red's door (L, Red's own; always lit), `win_11` z=8 (D, R), `win_12` z=10.5 (L). Each is an amber emissive quad plus a small point light, toggled by data (`data/world/` window states per beat); "dark" is the quad swapped to an unlit gray frame, light off.
- B3 relight: `win_02`, `win_07`, `win_11` switch on one at a time, 3 to 4 seconds apart, as Red passes x=8, 14 and 18 (trigger planes), with a soft lamp-light sound each.
- Dark window balcony: under `win_03`, ledge 1.8 m high, 2 m wide, 0.6 m deep. Crates: one at (6.5, 1.2) and the ledge reached from its top (0.9 → 1.8).
- Public lamp post at (11, 6), 4 m tall (fades when Red is behind it). Propaganda screen above the gate arch at (20, 0), 3.4 m up, 1.6 × 1 m.
- Spawns: `from_home` (1.2, 4), `from_courier` (4, 1.2), `from_store` (8.5, 1.2), `from_gear` (16, 1.2), `from_checkpoint` (20, 1.5), `from_docks` (10.5, 10.8).
- NPC markers: Bettor (12, 6.5), neighbor (2, 6), snack seller (14, 10), dock-gate dockhand (10.5, 10.2, B1 only), Mox cameo path alley (12.5, -1) → stairs (10.5, 12).

**H2 The Docks (`harrow_docks`)**
- Wharf floor 24 × 9 m; water plane in front from z=9; pier 3 × 4 m at x=20 to 23, z=9 to 13. Yaw 25. Camera bounds X 5 to 19, Z 4 to 7.
- Doors: stairs up in the N wall @ x=12, 3 m wide → `harrow_square:from_docks`; H8 at N @ x=5 → `harrow_dock_office:from_docks`; H9 at N @ x=19 → `harrow_bar:from_docks`.
- Crate stack: crate A at (3.2, 6), 0.9 m; crate B at (2, 6) on a 0.9 m base, top at 1.8 m; pickup on crate B.
- Pier-end pickup at (21.5, 12.5).
- Washed-up delivery crate (scene prop, B1 only) at (15, 8.2), a wet-dark tint and a puddle decal; removed after the dock fight (it appears in H8).
- Dock fight: scene trigger plane at z=1.5 just past the stairs (fires once). Kasp (14, 7) facing the crate, grunts (12, 5) and (16, 6), dockhands huddle (9, 3), Otis enters from H8's door.
- Floodlights: two on the warehouse fronts at x=8 and x=17, 4.5 m up, cold white, aimed down-south.
- Spawns: `from_square` (12, 1.5), `from_dock_office` (5, 1.2), `from_bar` (19, 1.2).

**H3 Signals Checkpoint (`harrow_checkpoint`)**
- Floor 14 × 9 m. Yaw 30. Camera bounds X 5 to 9, Z 4 to 5.
- Doors: arch on the S edge, x=6 to 9 → `harrow_square:from_checkpoint`; boom barrier in the N wall @ x=10, 3 m wide → `road_mast_road:from_harrow` (the Spillway; id kept; locked until `otis_joined`). Behind the barrier the floor shows the top of a service stair going down (scenery; the door trigger is at the barrier).
- Booth 2 × 2 × 2.5 m at (5, 2); APPEALS slot interactable on its south face. Confiscation bin (examine) at (3, 0.8), behind the booth. Barrier arm is a 3 m box that pivots up 80 degrees. Searchlight on the booth roof sweeping ±40 degrees, 6 seconds per sweep (cosmetic, not a detection cone).
- Spawns: `from_square` (7.5, 7.8), `from_road` (10, 1.5).
- NPC markers: grunts (9, 2) and (11, 2) (B1 only); Marchfolk line (7, 6), (8.2, 6), (9.4, 6).

**H4 Red's Home (`harrow_home`)**
- Floor 7 × 5 m. Yaw 45. Camera fixed at (3.5, 2.5).
- Door: S edge @ x=5.5 → `harrow_square:from_home`.
- Window lamp interactable (rest + save) at N wall @ x=3, sill 1.0 m. Bed against the W wall at z=1 to 3. Tally-mark wall: W wall, z=3 to 5. Pantry tin at (6.2, 0.6).
- Spawns: `start` (3, 1.2, facing the window; **no longer the New Game start**, kept for the debug warp), `from_square` (5.5, 4; also where the train's scene cut lands, with flag `home_run_in` unset so the arrival scene plays).

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
- Desk at N wall @ x=3 (story prop: bridge lamp on its east end). Roster board W wall @ z=2.5. Delivery crate (key-item pickup) at (5.5, 3.5), wet-dark tint.
- Spawn: `from_docks` (2, 4).

**H9 The Bar (`harrow_bar`)**
- Floor 9 × 6 m. Yaw 45. Camera fixed at (4.5, 3).
- Door: S edge @ x=7 → `harrow_docks:from_bar`.
- Bar counter along the W wall, z=1 to 4; bartender at (0.6, 2.5). Bets board on the N wall @ x=4.5. Jukebox at (8.3, 0.6); pickup behind it at (8.6, 0.3). Barflies at (2, 2), (3, 4), (5.5, 2); old barfly at (6.5, 4).
- Spawn: `from_docks` (7, 5).

**Data hooks (names are suggestions; the Gameplay Programmers own the files):** story beats `b0_train` (the ore train, see ore_train.md), `b1_night`, `b2_otis_joined`, `b3_home_again`. Flags `train_done`, `home_run_in`, `job_main_taken` (now set by the claim slip), `job_dark_window_done`, `job_appeal_done`, `otis_joined`, `checkpoint_open`, `mox_cameo_seen`, `dock_fight_won`. Window states `win_01` to `win_12` per beat (B1/B2 and B3 lists above). Key item `courier_job_slip` keeps its id; display name "Claim Slip". Pickups go in data/world/placements.json; the Battle Programmer finalizes contents (Equipment & items is Level 2).

**Tests that change (for QA and the Gameplay Programmers):** New Game now starts at `train_flatcar:start` (docs/maps/ore_train.md), not `harrow_home:start`. The Harrow walkthrough and story tests and the M3 end-to-end QA run get the new start point (or start from the `train_done` state). The dock-stairs line now says "claim slip". The dock scene gains the crate line.

---

## Choices for Ross (answered 2026-10-07: A, A, C; kept as the record)

DECISION NEEDED: What shape should the town be? (This sets your environment set list for Harrow.)
Option A: **A hub square plus the docks and the checkpoint** (3 outdoor scenes, as drawn above), in the spirit of Mario RPG's Rose Town and FF7's Kalm — pros: every shop is one scene from the square; least walking (about 1.5 minutes); 3 outdoor sets for you; the square later works as the curfew set and as Biscuit's stomp arena / cons: the square is busy (five doors and a gate across two walls), so it needs clear signs.
Option B: **One long main street** with every door along it and the checkpoint at the far end (2 outdoor scenes: the street and the docks), like Onett's main drag in EarthBound — pros: a strong pull toward the road out; one repeating facade to model / cons: the camera slides a lot and shops are 8 to 10 seconds apart; "the square" moment for the lockdown later is lost.
Option C: **Two tiers:** an upper town and the docks below, joined by a big cargo lift, plus a back-alley scene (4 outdoor scenes), like FF7's Junon — pros: the most character and height; sets up Biscuit stepping down the tiers in Act 1 / cons: one more outdoor set for you and about 40 seconds more walking in the slice.
Recommendation: A. **Approved 2026-10-07.**

DECISION NEEDED: Who ordered the crate Red is delivering? (A story detail that sets up the Spillway and the Works.)
Option A: **Watch Zero ordered it:** supplies for the sit-in (thermoses and cushions) — pros: the Spillway scene has a reason; the Zeroes owe Red, so showing her the back way is a thank-you; the thermos the old Zero heals you with before the boss is the one Red carried up / cons: the checkpoint needs another reason to open (Otis lifts the barrier, a 15-second scene).
Option B: **The Signals Corps ordered it:** Kasp's catering.
Option C: **An anonymous Coldrunner crate.**
Recommendation: A. **Approved 2026-10-07.** Since 2026-10-08 the crate is also contraband (it carries the sleeve bells the Signals keep confiscating), which is why Red runs it in on the ore train and why Kasp's crew tickets it.

DECISION NEEDED: After Kasp, does the slice cut straight to Red's window, or walk her home first?
Option A: **Cut straight to the window.**
Option B: **A short playable walk home** through the square, the docks and the bar.
Option C: **A 30-second walk across Lamp Square only:** the crowd cheers, the Bettor pays out, one barfly tells the fifty-troopers tale and Red does her legend correction, then home to the window.
Recommendation: C. **Approved 2026-10-07.** Since 2026-10-08 (tone pass D2 B), three dark windows relight on this walk.

*Studio calls made inside this map (overturnable):* the dock stairs need the claim slip; the dock fight puts Otis in from turn 1 rather than a mid-fight join; side deliveries sit on the route; pickup contents are suggestions for the Battle Programmer; room ids and spawn names are suggestions; which 6 windows start dark and which 3 relight are the studio's picks; the key item's display name "Claim Slip".
