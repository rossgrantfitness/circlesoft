# Kasp's Arena: one scene, two scales (vertical slice, task VS-13, part 2 of 2)

> Owner: Level Designer (proposes) · Ross (approves). Status: **proposed 2026-10-09, not approved.** The Taste Keeper logs a prediction before Ross decides.
> The slice boss, as Ross chose on 2026-10-09 (Boss A, then "C: both phases"): phase 1 is Red on foot against Sergeant Kasp's spider-legged Hushmaster, whose four leg relays are hacked out; then Kasp escapes into a giant junk mech built from the yard, Red boards the loader, docks into the colossus, and phase 2 is robot against robot. **One scene, no loading screen.** Giant-robot battles live at level ends and in boss fights (Ross's rule), and this is the first.
> Sources: slice_tech_plan.md section 6 (boss tech, phases, retry), robot_scale_test.md (all robot numbers), enemy_ai_design.md, slice_pitch.md (Kasp's patterns), the story bible's Kasp section (no twist), junkyard.md (the J5 exit). The boss's patterns and numbers are the Combat Designer's (`docs/slice/boss_design.md`); this page is the *space* that must carry them at both scales.

## Decisions for Ross

DECISION NEEDED: Is the colossus visible during phase 1, or hidden until phase 2?
Option A: **Visible from the first frame.** The dormant colossus stands in a gantry cradle on the east side of the bowl, a dark 50 m silhouette that Red sees when she walks in and whenever the camera swings east. Nobody mentions it. — Pros: sets up the payoff (the player works out "that's mine" before the game says so); shows the scale of what's coming; the junkyard's skyline head in J1 already foreshadows it; costs nothing extra (the model exists). / Cons: spends some of the reveal's surprise.
Option B: **Hidden behind a hangar door** until Red boards the loader; the door opens and the colossus is revealed already lit. — Pros: bigger surprise. / Cons: one more big set piece to build (the hangar); the foreshadowing in J1 and J4 has nothing to land on.
Recommendation: **A.** Ross's pick of docking is the spectacle, and a Chekhov's colossus makes it land harder. B stays cheap to add later because the colossus is its own node.

## For Ross (the short version)

- **The arena is a bowl.** In the middle is a raised, clear plateau, 40 m across, with a painted bullseye of rings: that is phase 1's floor. Around it is a walled yard (the stockade, 62 m radius), then the junkyard bowl itself, 340 m across, with scrap cliffs 60 to 110 m high and three tall cranes at the north.
- **Phase 1 (on foot):** Red vs the Hushmaster on the plateau. Three wall turrets on the plateau's edge can be Overclocked onto the leg relays; three floor hatches release drones; a gantry-free sky so the camera sees the colossus looming over the stockade to the east.
- **The turn:** the Hushmaster topples. Kasp scrambles out; the three rim cranes dump the yard's scrap into a giant junk mech (40 m) in the north. Red runs back down the ramp, boards the loader parked at the gate, drives to the colossus (9 s), and docks (4.5 s). The camera and fog ease to colossus scale.
- **Phase 2 (colossus):** robot against robot across the whole bowl. The plateau becomes a knee-high bullseye, the stockade a ring of toys you smash, the scrap heaps the mech's armour plates.
- **A save terminal at the gate** and a retry point in each phase: lose in phase 1, restart at the gate; lose in phase 2, restart already docked.
- **Borrowed, openly:** a boss fought in two forms with a big mid-fight transformation is a Kingdom Hearts and Mega Man Legends pattern; the docking beat is Ross's pick (Gurren Lagann's signature, done with a loader and a colossus and a different design). Each is one borrowed role; Kasp, his memos and the junk mech are ours.

## Box diagram (plan view; the plateau is the centre, bowl not to scale)

```
                                      NORTH (-z)
          scrap heap A            JUNK MECH HEAP B             scrap heap C
          (-60,-95)  [crane A]    (0,-110)   [crane B]         (+60,-95)  [crane C]
                                                                             rim cliffs 60-110 m
   WEST                                                                                  EAST
              . . . . . . . . . . . . . . . . . . . . . . . . . .  bowl floor r = 170 m
            .      +--------------- stockade ring r = 62 m (8 m wall) ----------------+
           .       |                                                                  |
          .        |                     PLATEAU  r = 20 m, 3 m up                     |==E gate (62,0)==[ COLOSSUS ]
          .        |                     Hushmaster centre (0,0)                       |    cradle (105,0)
           .       |      turrets NW (-13,-14)   NE (13,-14)   E (18,8)                |    facing west
            .      |      drone hatches (-10,-6) (10,-6) (0,11)                        |
              .    +------------------ S gate (0,62) -----------------------------------+
                         save terminal (-9,57)   loader (8,56)
                                      SOUTH (+z): from J5
```

## Sizes at both scales (the check that the arena works for Red and for the colossus)

| | Phase 1: Red (0.95 m) | Phase 2: the colossus (50 m) |
|---|---|---|
| Playing field | The plateau, 40 m across (radius 20), flat, no props | The whole bowl floor, 340 m across (radius 170) |
| Boss | The Hushmaster: about 3.5 m tall, 5 m leg span (confirm with the blockout) | The junk mech: about 40 m, built from the north heap |
| Camera | 4.5 m behind, FOV 62, lock-on | 75 m behind, FOV 56, target 26 m up, a bit shallower pitch |
| Fog | The `arena_ps2` profile: light haze, near about 60 m, far about 400 m (so the colossus at 85 m reads as a dark silhouette, never fogged out) | The colossus numbers from robot_scale_test.md: 300 m near, 1,500 m far, scaled by `ScaleController` |
| Ground reference | Painted rings every 4 m out to 20 m, 8 spokes, so jump rings and dash beams read | The plateau bullseye is a 40 m target on the floor; the stockade ring at 62 m and heaps give scale |
| Walls | A 1.1 m rail at the plateau's edge (no walk-off) | The rim cliffs, 60 to 110 m high, sloped back about 35 degrees so the 75 m camera never hits a vertical wall |
| Props | Turret pylons 2.5 m, drone hatches (flush) | Stockade 8 m (knee-high), heaps 30 to 45 m, cranes 90 m, smashable containers and cars |
| Shake and dust | Red's | `step_huge`, `land_huge` on every step; the floor is dust |
| Telegraphs | Red floor lines and rings; sound and flash at 0.5 to 0.9 s | The same, scaled up about 12 times (decals) and with the mech's body lamps; wind-ups scaled by the Combat Designer (about 0.45 speed) |

**Why 340 m:** the colossus runs 22 m/s, so the bowl is 15 s edge to edge: room to back away, circle and approach, with the 75 m camera always having 100 m of clear ground behind it. The robot yard from the scale test was 700 × 640 m; this is smaller and sits better against the plan's "several hundred metres".

## The sequence, with positions

Coordinates: meters, origin at the plateau's centre, +X east, +Z south, +Y up. Disembark, boss and retry points are in the scene as named nodes.

1. **Arrive** (`from_j5`, at the S gate (0, 62), loader parked at (8, 56) facing north). The J5 smash ends here: the disembark sequence plays, Red climbs out, the loader goes dormant. **Autosave.** The **save terminal** (`term_save_arena`) is in a lean-to at (-9, 57). A radio bark: "Last save before the Sergeant."
2. **Intro** (camera shots, reusing the battle shot director's storyboard as `camera_shot` steps): a wide shot from behind the gate (Red small, the plateau and the folded Hushmaster beyond, the colossus a black wall to the right); a low track along the 16 m ramp (0, 36 → 0, 20); Kasp's reveal in the seat with the memo; the boss title card. About 1:00, skippable.
3. **Phase 1, the rig** (`bar: boss`): Red, the plateau, the Hushmaster (patterns: Leg Stomp rings, Dish Sweep beam, Drone Drop, Quiet Hours). Hacks work. Details below.
4. **The topple:** all four relay pairs break; the rig falls at the centre; a prompt on the hack button jacks Red into the dish for the big hit.
5. **Transition** (retry skips to the next step if she dies here, `skip_to_next`):
   - `kasp_escape`: Kasp is thrown from the seat at (4, -3) and scrambles north to (0, -19); crane B's magnet drops a cage lift; Kasp rides it up, shouting a memo. About 4 s.
   - `mech_assemble`: cranes A, B and C swing their magnets over the three heaps; scrap and plates stream onto heap B; the junk mech rises at (0, -110) to 40 m with a siren and camera shake; crane B opens the stockade E gate (62, 0) by lifting its barricade away. About 8 s. A Vela bark: "Get to the loader."
   - `board_loader`: Red runs back down the ramp to the S gate (about 7 s of playable control; the rail opens at the ramp). She boards (the existing boarding sequence). Form `small`.
   - `dock_colossus`: the colossus wakes in its cradle (lamps on, gantry releases) and steps west to (84, 0). The loader runs the inside ring road to the E gate (62, 0) and the dock approach (68.2, 0): about 9 s, scripted and skippable. Then the 4.5 s docking sequence (robot_scale_test.md section 3). `ScaleController` eases the camera, fog and draw distance to the colossus numbers. Control returns in the colossus, which stands at (84, 0) facing west.
6. **Phase 2, the junk mech** (`bar: boss`): the mech starts walking from (0, -105) to meet the colossus (about 7 s to contact). Patterns, plates and the cockpit core are the Combat Designer's. Hacks are off in robot forms (the battery panel hides).
7. **Ending:** the mech falls; a short cutscene (not a fight) of Kasp in the wreck, then `slice_done`; the walk home through the market (night_market.md route step 5).

### Retry points (slice_tech_plan.md 2.4)

| Where Red dies | She restarts at | State |
|---|---|---|
| Intro, phase 1 | `retry_phase1` at (0, 54) in front of the S gate | Hushmaster whole, intro skipped, health and battery as on entry |
| Transition | The next transition step | Skip to the next |
| Phase 2 | `retry_phase2` already docked: colossus at (84, 0), junk mech at (0, -105) at full health | No boarding sequence replayed |

## Phase 1 layout (Red scale, the plateau)

```
                         N (-z)
                 turret NW           turret NE
                (-13,-14)            (13,-14)
              [T]   hatch(-10,-6)  hatch(10,-6)  [T]
          .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
        .          ring radius 16                           .
       .       ring 12 .  .  .  .  .  .                      .
      .       .    ring 8     .  .  .  .                       .     [T]
     .       .   ring 4   (0,0)  Hushmaster start             .     turret E
      .       .                          .                    .      (18,8)
       .        .    hatch (0,11)       .                    .
        .          .  .  .  .  .  .  .  .                  .
          .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
                              ramp 8 m wide, 16 m long
                                  (0,20)->(0,36)
                                 S (+z): to the S gate
```
- **Plateau:** a clear flat disc, radius 20 m, top at +3 m, rail 1.1 m (transparent), painted rings every 4 m and 8 spokes in hazard white for reading distance. No props on it. Fight space is large enough for the Hushmaster's 5 m leg span, a 10 m stomp ring and a 40 m dish beam with room to dash through.
- **Turrets (3):** `turret_k_nw` (-13, -14), `turret_k_ne` (13, -14), `turret_k_e` (18, 8) on 2.5 m pylons, hijackable (Overclock), range at least 36 m (Combat Designer confirms). A hijacked turret fires at the nearest enemy, which in phase 1 is the Hushmaster or a drone; its bursts break relay boxes the Zap can't reach in time. Pylons carry Kasp's memos (the Writer's text).
- **Drone hatches (3):** floor hatches that lift a lid with amber light and a 1 s warning, then three drones rise. Positions (-10, -6), (10, -6), (0, 11), all inside the ring where EMP clears them.
- **Relay sight lines:** nothing on the plateau blocks the line from any turret or from Red to the leg knees. The relay boxes sit about 1.2 m up each leg pair.
- **Edges:** the S ramp is the only way up. At the transition the ramp stays open and the rail stays up.

## Phase 2 layout (colossus scale, the bowl)

```
  N (-z)   heap A (-60,-95)  JUNK MECH heap B (0,-110)  heap C (60,-95)       crane A,B,C
           (armour plates)   (the mech rises here)      (armour plates)       90 m tall
                                   |
                                   v  ~7 s to contact
        ................ bowl floor, smashable containers & cars in 8 clusters ..............
              stockade ring r=62 (knee-high, smash it)
                  plateau (40 m bullseye, 3 m = a curb)            COLOSSUS (84,0) facing W
                                                                   after docking
  S (+z)                                         rim cliffs 60-110 m high, sloped back
```
- **Where they fight:** the colossus starts at (84, 0), the mech at (0, -105): about 150 m apart. The open middle (radius about 120 m) is the combat space, with eight clusters of smashable containers and cars (6 to 10 each) as scale and loot. No cover is needed; the colossus is knee-height to everything on the floor.
- **The stockade ring and the plateau** become landmarks: floor decals for slam rings land on the bullseye; the mech's plates fly out of the heaps and land as scrap piles.
- **The three rim cranes** (A, B, C) stay as 90 m props. They are an optional hook for the Combat Designer (a magnet that re-attaches a plate), not a requirement.
- **Camera clearance:** the bowl floor extends 170 m from the centre and the rim leans back, so the 75 m camera has 100 m of clear ground behind the colossus wherever it fights. An invisible wall at radius 160 m keeps both robots in.
- **Telegraph readability from 75 m:** every mech attack shows a floor decal (a long beam line, a ring) at least 12 m wide and a body flash, per the tech plan 6.5; the floor is flat and unpainted outside the plateau so decals read.

## The room entry (rooms.json, for the builder)

```json
"kasp_arena": {
  "name": "Yard 9 Staging",
  "scene": "res://scenes/slice/arena/kasp_arena.tscn",
  "kind": "arena",
  "camera": "orbit",
  "combat": true,
  "look_profile": "arena_ps2",
  "form": "red",
  "robots": "kasp_arena",
  "checkpoint": true,
  "autosave": true,
  "music": "kasp_phase1",
  "spawns": ["from_j5", "retry_phase1", "retry_phase2"],
  "default_spawn": "from_j5"
}
```

**Named nodes the scene must have** (the test checks each): `from_j5` (0, 58) facing north; `retry_phase1` (0, 54); `retry_phase2` (the colossus's seat); `term_save_arena` (-9, 57); `loader_parked` (8, 56); `colossus_cradle` (105, 0) and `colossus_dock_pos` (84, 0); `dock_approach` (68.2, 0); `turret_k_nw`, `turret_k_ne`, `turret_k_e`; `drone_hatch_a`, `_b`, `_c`; `hushmaster_start` (0, 0); `mech_start` (0, -110); `kasp_escape_target` (0, -19); `stockade_e_gate` (62, 0); `crane_a`, `crane_b`, `crane_c`; `shot_*` camera positions (wide, ramp, reveal, title).

## What stands in for art (placeholders only)

| What | Stand-in |
|---|---|
| Plateau, ramp, stockade, heaps, cliffs | boxes and cylinders in junk rust, painted rings as decals (Ross's city rust and steel tiles) |
| Hushmaster | the Technical Artist's blockout (box body, eight cylinder legs, four relay boxes, a disc dish, a seat) |
| Kasp | the Kasp blockout (grunt variant, scaled 1.2, a flat paddle tail) |
| Junk mech | the 40 m blockout on Red's bone names |
| Colossus | the CS-21 huge robot blockout (`robot_huge_ual.glb`), dark in the cradle |
| Loader | the CS-21 small robot blockout |
| Cranes | tall boxes with hinged jibs |
| Turrets, hatches, terminal | boxes and discs; the hack glow on the turrets |
| Look | the `arena_ps2` profile (grim, long draw distance, light haze) plus the colossus fog numbers on docking (Technical Artist) |

## Art the arena needs (for docs/art_requests.md; Ross makes the final art)

| Name | For | Size | Budget | Palette | Format | Goes in |
|---|---|---|---|---|---|---|
| Hushmaster | Phase 1 boss | 3.5 m tall, 5 m span | per the Technical Director | Signals blue-gray, brass, hazard | GLB | `game/art/final/enemies/` |
| Kasp | Boss | about 1.1 m (beaver) | per the style guide | Pressed blue-gray, brown fur | GLB | `game/art/final/characters/` |
| Junk mech | Phase 2 boss | 40 m, Red's bone names | per the Technical Director | Rust and scrap, hazard, amber lamps | GLB | `game/art/final/enemies/` |
| Colossus | Docking and phase 2 | 50 m, bone names as CS-21 | per the Technical Director | Ironstone, hazard stripes, amber lamps | GLB | `game/art/final/robots/` |
| Loader | J4, J5, boarding | 3.5 m | per CS-21 | Oxblood, brass hatch | GLB | `game/art/final/robots/` |
| Rim cranes and heaps | Arena backdrop | 90 m cranes; heaps 30 to 45 m | 1,500 tris | Rust, hazard | GLB | `game/art/final/world/junkyard/` |
| Wall turret | Arena and yard | 1.2 m | 500 tris | Blue-gray Signals | GLB | `game/art/final/world/junkyard/` |

## Test and screenshots

- **Headless test (`integration/test_slice_rooms.gd`, plus Combat Programmer's `test_boss_transition.gd`):**
  - The arena loads; every named node above exists; `from_j5`, `retry_phase1` and the terminal are on the floor and reachable by a walk check to the ramp, the plateau and each turret pylon.
  - The ramp reaches the plateau (3 m up over 16 m); the plateau has no props inside radius 19.
  - Every turret has line of sight to the plateau centre and range to the far edge.
  - The scale switch: the camera's distance, FOV and fog are the Red numbers on entry and the colossus numbers after the docking step; the stockade and the plateau survive the switch.
  - At colossus scale the camera never collides with the rim: the colossus can reach every point within radius 160 m with 75 m of clear ground behind it.
  - `retry_phase2` puts Red already docked.
- **Screenshots for Ross (`docs/screenshots/slice_arena_*.png`):** the plateau from the ramp with the colossus on the right, a plan-view marked-up diagram of the bowl, and (once the transition exists) a pair of shots, the plateau at Red scale and the same view at colossus scale. Placeholders until Ross's art arrives.

## As built (VS-29, the graybox, 2026-10-09)

- **Generator and files.** `game/scripts/tools/make_kasp_arena.py` writes `game/scenes/slice/arena/kasp_arena.tscn` and `game/data/slice/robot_rooms/kasp_arena.json` (the loader parked at the south gate, the colossus standing dormant in its cradle at (105, 0) facing west, and 39 smashable containers, cars and crates in eight clusters, from a fixed seed). Row in `data/slice/rooms.json` (`kind: arena`, `robots: kasp_arena`, `look_profile: grim_ps2` until `arena_ps2` exists). Origin is the plateau's centre. Ross's answer (colossus visible in phase 1, A) is in `data/slice/market.json` `colossus_in_phase_1`.
- **Pieces.** The Technical Artist's `art/placeholder/bosses/arena/` models: 30 wall segments in the 62 m stockade (two gates with posts: south open, east shut by `stockade_e_barricade`), the plateau rail (31 segments, open at the ramp), three turret pylons, three scrap heaps (the giant one at (0, -110) for the junk mech, two smaller) and 28 piles. The plateau is a 20 m radius disc 3 m up with a bullseye of 4 m bands and four hazard spokes; the ramp is 8 m wide, 3 m over 16 m. Rim cliffs lean back 35 degrees, 36 slabs, with an invisible wall at r 161; three 90 m cranes carry magnets over the heaps.
- **Named nodes** (all in the table above; `Markers/*`, `Spawns/*`, `Shots/shot_*`, `crane_a/b/c` each with a `magnet` child, `term_save_arena`, `stockade_e_barricade`). The Combat Programmer's BossFight already finds them (the Hushmaster stands on the plateau when the room loads).
- **Test.** `game/tests/integration/test_slice_arena.gd`. Screenshots: `docs/screenshots/slice_arena_overview.png`, `slice_arena_colossus.png` (the cradle on the right), `slice_arena_gate.png`.
- **Open (for the owners):** (1) `ActionRoom` blocks saving in any room whose row names `robots`, so the arena-gate terminal cannot save yet: it should allow saving while she is on foot (Gameplay Programmer). (2) The pylon model from the Technical Artist already carries a turret head; BossFight spawns the real WallTurret at `Markers/turret_k_*` (y = the mount), so one of the two should be hidden. (3) The rim cliffs are one flat colour; the junkyard tiles come with the `arena_ps2` look.
