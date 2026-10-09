# The Junkyard: layout map (vertical slice, task VS-13, part 1 of 2)

> Owner: Level Designer (proposes) · Ross (approves). Status: **proposed 2026-10-09, not approved.** The Taste Keeper logs a prediction before Ross decides.
> The slice dungeon Ross picked on 2026-10-09 ("3B, its actually a junk yard"): a grim Signals scrapyard behind the ore line. Red climbs it on foot (J1 to J4), hacks a loader robot awake at the end of J4, smashes through a big area in it (J5), and arrives at Kasp's arena (docs/maps/kasp_arena.md, the other half of VS-13).
> Sources: slice_pitch.md, slice_tech_plan.md (sections 4, 5, 6), robot_scale_test.md, enemy_ai_design.md, road_and_tower.md (the old tower for what to reuse), the Playbook Principles, the story bible's world, Signals and Kasp sections (no twist). `docs/slice/hacks_design.md` does not exist yet; the hack numbers below come from the tech plan's `hacks.json` sketch and are the Combat Designer's to change.

## Decisions for Ross

DECISION NEEDED: After Red wakes the loader at the end of J4, can she walk back to town?
Option A: **No: one way from the loader onward.** The loader is too big for the doors behind it, so J4 to the arena is a single trip. The last save terminal on foot is at the east end of J3, right before the point of no return, with a Vela bark that says so ("Last chance to save, courier. Past this, there's no coming back this way."). — Pros: the simplest and tightest pacing; no robot-stays-or-goes states to build and test; keeps the "level end" rule clean. / Cons: you can't shop between waking the loader and the boss.
Option B: **Yes: Red can climb out in J4 and leave the loader parked, then walk back to J3 and town.** — Pros: freedom. / Cons: extra boarding and disembark states in J4 and a re-board on return; more tests; breaks the momentum Ross asked for.
Recommendation: **A,** with the J3 terminal as the clear last-save warning. The arena gate has a save terminal too, so a Continue never costs more than one room.

## For Ross (the short version)

- **Six scenes:** four on foot (J1 Yard Gate, J2 Scrap Canyon, J3 Crane Yard, J4 Wreck Row), one loader run (J5 Smash Run), then Kasp's arena.
- **What you do on foot:** fight Signals wolves and the Brute, and hack things: a fuse box that opens a door (Zap), turrets you turn on the enemy (Overclock), a crane that builds a bridge (Overclock), a drone line you stop (EMP or Zap), a terminal that opens a gate, and finally the loader robot, which you hack awake.
- **Pace:** fight, breather, discovery, every room. The room list below says which is which.
- **Landmarks that pull you on:** a faint huge head on the eastern skyline (the dormant colossus, seen over the scrap from J1), then the crane that dominates the sky, then the wrecked giant robot parts in J4 that tell you how big the real one is.
- **Giant robots are saved for the end of the level** (Ross's rule): J5 is a smash run with no robot enemies. The first robot-versus-robot is the boss.
- **Time:** about 15 minutes on foot (J1 to J4), about 3.5 in the loader (J5). Whole slice about 33 to 40 minutes.
- **Borrowed, openly:** an industrial yard climbed room by room, a crane as a puzzle, and a vehicle section before the boss are Half-Life 2 and Mega Man Legends beats; waking a dormant mech by hacking is the Titanfall and Portal-style "borrow the job, change the look" beat. Each is one borrowed role; the yard, the cast and the jokes are ours.

## Box diagram

```
  from GATE 4 (town: market_gate, boom barrier)
        |
  +-----v------------------------------+   fuse door    +----------------------+
  | J1 YARD GATE   64 x 44 m           |--------------->| J2 SCRAP CANYON      |
  | fight 1 (2 wolves), first hack     |  (Zap, sticky) | 150 m long, 3 bays   |
  | autosave                           |                | turrets, Brute (fight 2)
  +------------------------------------+                +-----------+----------+
                                                                      | terminal gate
                                  +-----------------------------------v----------+
                                  | J3 CRANE YARD   100 x 80 m  (midpoint)        |
                                  | pit + crane bridge, drone line, vault, fight 3|
                                  | SAVE TERMINAL at the east end (last on foot)   |
                                  +-----------------------------------+----------+
                                                                      | hangar door
                                  +-----------------------------------v----------+
                                  | J4 WRECK ROW   90 x 60 m                       |
                                  | vestibule, THE STAND (fight 4), loader cradle  |
                                  | Red hacks the LOADER awake, boards it           |
                                  +-----------------------------------+----------+
                                                                      | loader smashes the east wall
                                  +-----------------------------------v----------+
                                  | J5 SMASH RUN   280 x 110 m   (in the loader)   |
                                  | breaker lane, car graveyard, container canyon,  |
                                  | the Foreman's Wall                              |
                                  +-----------------------------------+----------+
                                                                      | smash the gate
                                  +-----------------------------------v----------+
                                  | KASP'S ARENA (kasp_arena.md)  save terminal     |
                                  +------------------------------------------------+
```

## The route (main path)

1. **J1 Yard Gate.** Out of Gate 4 and down the service road to the yard's gate. A Vela radio bark teaches lock-on. Fight 1 (two wolves). Then the fuse box that opens the door east: the first hack.
2. **J2 Scrap Canyon.** A long canyon in three bays: a turret chute, a pit stop with the first Brute and a turret you can take over, and a terminal gate. Overclock is taught here.
3. **J3 Crane Yard.** The biggest foot room. A pit splits it; the crane builds the bridge. A drone line and a fight in the west half. Save terminal on the far side.
4. **J4 Wreck Row.** A quiet walk past giant wrecks, then the Stand (the hardest foot fight), then the loader in its cradle: hack it awake, board, smash the east wall.
5. **J5 Smash Run.** Mow through a car graveyard and a container canyon to the Foreman's Wall, smash it, and arrive at the arena.
6. **Kasp's arena.** Disembark, save, boss.

**Return trips:** J1 to J3 can be walked back through in either direction until the loader wakes (Decision 1, A). Regular enemies respawn when you re-enter a room; the J4 Stand and any hack-door flags do not (they are `sticky`).

## Scale and camera rules used for every foot room (so the fights are readable)

Red is 0.95 m tall, runs 6 m/s, jumps 1.6 m, dashes about 5 m; the camera sits 4.5 m behind her (OrbitCamera, lock-on). Enemy rules (enemy_ai_design.md): wolves ring Red at 3.2 to 5 m, the Brute at 4.5 to 6.5 m; at most 2 attack at once; wind-ups 560 ms or more.

- **Fight spaces are open circles at least 24 m across** (Brute fights 30 m) with no walls inside the camera ring, so the free camera never hugs a cliff in a fight.
- **Travel corridors are 8 to 14 m wide** with scrap cliffs 8 to 25 m tall on both sides. No fog hides the far end; the cliffs do the framing.
- **Steps up are 1.0 m or less; jump hops 1.4 m or less.** Anything Red can reach by jump is marked with a chalk mark or a crate. Gaps of 7 m or more are not crossable without the hack (Red's dash plus jump is about 6 m).
- **Hack targets are lock-on-able and 12 m or less from where Red fights**, never behind the camera ring: lock-on reaches them as `lock_targets` and each glows when hackable.
- **Landmarks:** one at the end of every corridor. Nothing important is hidden behind a wall that fades.

## Hack targets at a glance (all graybox; final looks at VS-40)

| Target (id) | Room | Accepts | What it does |
|---|---|---|---|
| Fuse-box door (`hack_j1_door`) | J1 | Zap | Opens the J1→J2 door for good. |
| Wall turret T1 (`turret_j2_a`) | J2 bay 1 | Zap (stun), EMP (off 4 s), Overclock | Fires telegraphed bursts down the chute. |
| Wall turret T2 (`turret_j2_b`) | J2 bay 2, north ledge | Overclock (best), Zap, EMP | Hijacked, it shoots the wolves and the Brute. |
| Gate terminal (`term_j2_gate`) | J2 end | interact | Opens the J2→J3 gate. |
| Gantry crane (`crane_j3`, controls at `(44, 44)`) | J3 | Overclock | Path A: the bridge girder across the pit (required). Path B: swings a container into the vault wall (optional). |
| Drone line (`dline_j3`, node `dline_j3_node`) | J3 | EMP (stops it for a while), Zap on the node (stops it for good) | A dispenser sending drones out. |
| Vault fuse door (`hack_j3_vault`) | J3 | Zap | Opens a small cache (the second way into the secret, see J3). |
| Save terminal (`term_save_j3`) | J3 east | interact | Save. |
| Turrets T3, T4 (`turret_j4_a`, `turret_j4_b`) | J4 | Overclock, Zap, EMP | Part of the Stand; hijack to thin the Brutes. |
| The loader (`loader_j4`) | J4 | Overclock (or interact; the Combat Designer picks) | Wakes it and starts the boarding sequence. |

**Where each hack is taught.** Zap: J1's fuse box. Overclock: J2's turret (Vela bark). EMP: J3's drone line. Overclock on a machine: J3's crane. Reboot is taught anywhere by a pickup; the Combat Designer places it. Each teaching spot is a bark trigger, never a pause.

**Battery rule for pacing:** every hack puzzle sits *after* a fight, so the sword hits have filled the battery. J3's drone line keeps spawning drones until stopped, so the battery can always be topped up there (no softlock).

## Rooms

All coordinates: meters, origin at the room's north-west floor corner, +X east, +Z south (as Harrow). Free camera, so no yaw. Diagrams are not to scale; the numbers are.

### J1 Yard Gate (`junk_j1`): 64 × 44 m. Fight 1, first hack, autosave
- **Purpose:** show the junkyard, teach lock-on and Zap, give the first small fight. A short room: about 2:30.
- **What it is:** the yard's front gate: a crushed-car wall on each side (12 to 14 m high), a Signals weighbridge with a screen reading "SIGNALS YARD 9: QUIET PLEASE", Kasp's memo on a clipboard-shaped sign, and a burn-barrel clearing. On the eastern skyline a huge dark head (the dormant colossus) rises over the heaps: a faint silhouette, not explained.

```
 W edge z=22                                                                  E edge z=22
 from market_gate                                                              to J2 (fuse door)
     |        WEIGHBRIDGE LANE (18 x 12 m)                  THE POUND (32 x 28 m)         |
 +---v-----------------------------------+         +------------------------------------v--+
 |  screen, memo, crate hop (S1 stash)   |-------->|  burn barrel (36,22) · 2 wolves        |
 |  walls 12 m, no enemies               |         |  fuse box on pylon (54,12), 5 m up      |
 +---------------------------------------+         +----------------------------------------+
```
- **Arrive:** `from_market` (2, 22). Autosave on entry.
- **Fight 1:** `enc_j1_pair`, 2 wolves idling at the barrel (36, 22) in the Pound. They notice at 8 m. Regular (respawns).
- **Hack 1:** after the fight the fuse box (`hack_j1_door`) sits on a pylon at (54, 12), 5 m up, glowing. Vela bark "That fuse box. Zap it." Zap opens the door at (62, 22), 5 m wide; the door stays open (sticky).
- **Secret S1 (discovery):** a chalked lantern on a car stack at (6, 18). Hop crate A (8.5, 20, 0.9 m) onto the stack (1.8 m top). A stash: credits and a small item (contents are the Combat Designer's, Level 2).
- **Pickups:** two glints on the weighbridge (credits).
- **Radio barks:** `bark_j1_arrive` (lane end), `bark_j1_lockon` (first wolf in range), `bark_j1_zap` (fuse box in view).
- **Exits:** west back to town (`market_gate:from_junk`), east fuse door → `junk_j2:from_j1`.

### J2 Scrap Canyon (`junk_j2`): 150 m long, 3 bays. Turrets, first Brute, Overclock
- **Purpose:** the first real hack-and-fight mix. About 4:00.

```
 from J1 (W)                                                                       to J3 (E)
 +--------------+   +----------------------------------+   +-------------------------+
 | BAY 1 CHUTE  |-->| BAY 2 PIT STOP (fight 2)         |-->| BAY 3 THE GATE          |
 | 14 m wide    |   | 36 x 36 m yard                    |   | 12 m wide, ramp up 4 m  |
 | 40 m long    |   | 3 wolves + Brute, turret T2       |   | terminal gate           |
 | turret T1    |   | ledge stash S2 (scrap ramp)       |   | breather                |
 +--------------+   +----------------------------------+   +-------------------------+
 x=0..40, z=10..24     x=40..95, z=2..38 (offset 10 m S)       x=95..150
```
- **Bay 1, the Chute (x 0 to 40, 14 m wide):** a straight canyon, cliffs 14 m. Wall turret T1 on a ledge at (30, 3), 4 m up, firing slow telegraphed bursts down the lane. A container on the south side (22, 20) is cover; a crate hop at the far end. Choices: Zap T1 to stun, EMP it, or Overclock it (it then does nothing, nothing to shoot, a gag line). Breather-with-teeth.
- **Bay 2, the Pit Stop (x 40 to 95):** a 36 × 36 m yard (z 2 to 38), the first full fight. **Fight 2:** `enc_j2_pitstop`, 3 wolves and 1 Brute, plus a turret T2 on the north ledge at (62, 2), 4 m up, reached by a scrap ramp (x 46 to 62, 4 m rise over 16 m) and **hijackable: Overclock it and it shoots the wolves and the Brute for 10 s**. The wolves come first so the battery is charged; the Brute follows at a short delay so the player has time to think "turret". Regular (respawns).
- **Bay 3, the Gate (x 95 to 150, z 8 to 20):** 12 m wide, rising 4 m by a ramp, a terminal at the top (`term_j2_gate`, interact) opens the gate at (150, 14). No enemies: the breather. At the top, the crane's jib fills the sky.
- **Secret S2:** the ledge T2 stands on has a chalked stash at the east end (72, 2). Reached by the ramp; one jump onto a car roof (1.4 m).
- **Pickups:** two credits glints, one battery cell at the gate.
- **Radio barks:** `bark_j2_turret` (T1 in view), `bark_j2_overclock` (T2 in view, Brute spawning), `bark_j2_crane` (top of bay 3: the crane is the next job).
- **Exits:** west `junk_j1:from_j2`, east gate → `junk_j3:from_j2`.

### J3 Crane Yard (`junk_j3`): 100 × 80 m. The midpoint. Pit, crane, drone line, save
- **Purpose:** the biggest foot room, the best hack showcase, and the last foot save. About 5:00.

```
 N
 +-----------------------------------------------------------------------------------+
 | DRONE LINE  (8,8) node on roof (10,6)   [gantry crane spans the pit, rail x=50..66]|
 |                                         ###########                                |
 |  WEST HALF 46 x 80 m                   # PIT 9 m wide #     EAST HALF               |
 |  cover: container stacks               # x 46..55      #    bridge landing          |
 |  fight 3 (3 wolves + Brute)            # z 8..72       #    Foreman's shed (90,48)  |
 |  girder pallet (36,40)                 #               #    SAVE TERMINAL           |
 |  crane controls (44,44)                ###########        vault wall (72,20) -> cache|
 +--W edge (0,60) from J2---------------------------------------------E edge (100,40)--+
                                                                          to J4
```
- **Arrive:** `from_j2` (2, 60). Open floor of rusted plates, container stacks (6 × 2.6 × 2.6 m) as cover, spools and a wrecked tow truck.
- **The pit (x 46 to 55, z 8 to 72):** a 9 m wide coolant sump, deep (a drop is a hurt-and-return to the rim, no kill). Too wide to cross.
- **The crane** is a gantry crane straddling the pit, its rail from x=44 to 66. Its control cabinet (`crane_j3`) is a hijackable box at the foot of the west leg, `(44, 44)`. Overclock it (10 s): **Path A** picks up the bridge girder (a 12 m beam on a pallet at (36, 40), within the hook's reach), carries it east over the pit and lowers it to rest on both rims (about 8 s); the bridge is sticky. **Path B** (optional) swings a container into the vault wall at (72, 20) on the east side, which shatters; behind it is the secret cache. If the hijack ends before the girder lands, the hook returns to its start and the player can try again (the battery refills from the drone line's drones).
- **Drone line:** a dispenser in the NW corner (8, 8) sends a drone every 6 s (max 2 alive). **EMP** stops it for 8 s; **Zap its power node** (on the roof at (10, 6), 5 m up, lock-on target) stops it for good, and a maintenance hatch pops with a small cache (S3b). The line is the room's trickle for battery and a clock that pushes the player on.
- **Fight 3:** `enc_j3_yard`, 3 wolves and 1 Brute roam the west half; they spot Red at 10 m. Drones add pressure. This is the toughest foot fight so far. Regular.
- **East half (x 55 to 100):** across the bridge, a breather: a bench, a view of the arena's crane forest, **the save terminal** (`term_save_j3`) in a Foreman's shed at (90, 48), a healing pickup, and the vault wall. A radio bark warns this is the last foot save.
- **Secrets:** S3 the vault cache behind the wall (a sword chest; Ross's six sword models are the loot table, which sword is the Combat Designer's call, Level 2). S3b the drone-node cache. S3c a chalk-marked car roof at (20, 70).
- **Radio barks:** `bark_j3_pit` (arrival), `bark_j3_crane` (cabinet in range), `bark_j3_emp` (first drone), `bark_j3_lastsave` (terminal).
- **Exits:** west `junk_j2:from_j3`, east hangar door (100, 40) → `junk_j4:from_j3` (open from the start of the east half).

### J4 Wreck Row (`junk_j4`): 90 × 60 m. The Stand, the loader
- **Purpose:** the level's climax on foot: the hardest fight, then the hack that wakes the loader. About 3:30 plus the boarding.

```
 W edge (0,30)                                                                  E smash wall (90,30)
 from J3                       THE STAND (50 x 44 m, wrecks as bleachers)         loader lane
 +--------+     +---------------------------------------------------+      +------------------+
 |VESTIBULE|---->|  fight 4: 2 Brutes + 3 wolves + 2 turrets          |----->| LOADER CRADLE     |
 |12 x 20 m|     |  hulks: arm (20 m), head (15 m), leg (18 m)        |      | platform 20 x 16  |
 | quiet   |     |  shutters drop behind Red                          |      | loader (3.5 m)    |
 +--------+     +---------------------------------------------------+      +------------------+
```
- **Vestibule (x 0 to 12):** a quiet walk, no enemies. Giant robot parts lie in the yard beyond (a 20 m arm, a 15 m head, an 18 m leg): the player learns how big robots get here.
- **The Stand (x 14 to 64, z 8 to 52):** a 50 × 44 m yard ringed by wrecks as stands. **Fight 4:** `enc_j4_stand`, 2 Brutes (one enrages under 35%), 3 wolves, and two turrets (T3 (30, 10), T4 (48, 50), 3 m up and **hijackable**) that the Combat Designer can use to even the odds. Shutters drop behind Red when it starts (sticky `j4_stand_started`) and lift when the last enemy falls (`j4_stand_cleared`, sticky, no respawn). The toughest foot fight in the slice. The Brutes' ring is 4.5 to 6.5 m; the Stand is wide enough that the camera never hugs a wreck.
- **The loader cradle (x 66 to 86):** a work platform with the loader (`loader_j4`) in a gantry cradle, 3.5 m tall, lamps off. After the Stand, a Vela bark: "That's a loader. Wake it." Overclock (or interact, the Combat Designer picks) starts the boarding sequence: lamps on, the hatch drops, Red climbs the back ladder to the seat (`RobotBoarding`). Form switches to `small`.
- **The way on:** a 25 m loader lane to the east smash wall (90, 30), a scrap wall 4 m thick and 6 m high (hp about 120). The loader hits it and the wall crumbles; at the far side, J5. The first smash here is the tutorial.
- **Secret S4:** inside the giant head (the 15 m wreck) at (40, 8): a hatch on its side, 1.4 m up; a cache of credits and a battery cell.
- **Radio barks:** `bark_j4_wrecks` (vestibule), `bark_j4_stand`, `bark_j4_loader`, `bark_j4_smash`.
- **Exits:** west `junk_j3:from_j4` (blocked once the loader wakes, Decision 1 A), east smash wall → `junk_j5:from_j4`.
- **Never mid-robot saves:** the J3 terminal is the last on foot until the arena gate.

### J5 Smash Run (`junk_j5`): 280 × 110 m, in the loader (`form: small`)
- **Purpose:** the power fantasy. The loader mows through a big area; no robot enemies. About 3:30.
- **Loader numbers** (robot_scale_test.md): 3.5 m tall, run 9 m/s, jump 3 m, dash 8 m, camera 14 m behind. Hacks off in robot forms (the battery panel hides).

```
 W (0,55)                                                                                  E (280,55)
 from J4  | BREAKER'S LANE   | CAR GRAVEYARD            | CONTAINER CANYON        | FOREMAN'S WALL |
          | x 0..50          | x 50..130                | x 130..200              | x 200..280     | -> arena
          | 12 m lane, 3     | 60 x 110 m field,        | 26 m wide, S-bends,     | 3 scrap walls  |
          | scrap walls      | ~80 cars, ~10 wolves,    | stacks 3 high (7.8 m),  | + the big gate  |
          | tutorial smashes | 6 drones, 2 turrets      | 3 turrets on platforms  | (12 m, hp 400)  |
```
- **Why this size:** the loader runs 9 m/s, so 280 m is about 31 s of straight running: stretched to about 3.5 min by smashing, enemies and loot, so it rewards wandering without turning into a corridor. Walls on both sides are 30 to 40 m so the 14 m camera never sees sky edges.
- **Zones:**
  1. **Breaker's Lane (x 0 to 50):** a 12 m lane between car stacks. Three scrap walls (3 m, hp about 60 each) the loader breaks one swing each. Wolves at loader scale are small, a few appear to show the scale.
  2. **Car Graveyard (x 50 to 130):** a 60 × 110 m field of about 80 cars (4.4 m each, hp 50) in lanes, 10 or so wolves and 6 drones, 2 turrets. The loader tears through them. **Power fantasy rules:** enemies chip the loader; the Combat Designer sets the damage; a wolf takes one hit.
  3. **Container Canyon (x 130 to 200):** a winding canyon 26 m wide with container stacks 7.8 m high on both sides, S-bends, 3 turrets on 3 m platforms. The canyon makes the camera swing and the walls collapse when hit at the base (SmashProp).
  4. **The Foreman's Wall (x 200 to 280):** three layers of scrap walls, then the big gate (12 m tall, 16 m wide, hp about 400): the climax of the run. Smashing it ends J5.
- **Loot (discovery):** about 12 chalk-marked containers and crates hold credits, a battery cell, one rare item (the Combat Designer's). A hidden chalk-marked car at (110, 20) holds the best prize.
- **Radio barks:** `bark_j5_start`, `bark_j5_smash`, `bark_j5_gate`.
- **No save terminals** (robot form). A death continues from J5's entrance, already in the loader.
- **Exit:** the gate → `kasp_arena:from_j5` (the disembark sequence plays at the arena's start).

## Fights at a glance

| Room | Encounter id | Who | Respawns? | Notes |
|---|---|---|---|---|
| J1 | `enc_j1_pair` | 2 wolves | Yes | Teaches lock-on and fills the battery for the Zap |
| J2 bay 1 | (turret T1) | 1 turret | n/a | Zap, EMP or Overclock to pass |
| J2 bay 2 | `enc_j2_pitstop` | 3 wolves, 1 Brute, T2 | Yes | First Brute; T2 is the lesson |
| J3 | `enc_j3_yard` + drone line | 3 wolves, 1 Brute, drones | Yes | The toughest so far; the line is a clock |
| J4 | `enc_j4_stand` | 2 Brutes, 3 wolves, T3, T4 | **No** (sticky) | Climax on foot; shutters |
| J5 | `enc_j5_*` | small groups of wolves, drones, turrets | Yes | Power fantasy; no robot enemies |

At most two enemies attack at once (the token rule); every Brute wind-up is 900 ms; nothing here needs a new enemy behaviour. Encounter numbers and the exact enemy counts belong to the Combat Designer (`data/slice/encounters.json`, VS-17); these counts are my starting layout, sized to the spaces above.

## Pacing (fight, breather, discovery)

| Room | Fight | Breather | Discovery | Time |
|---|---|---|---|---|
| J1 | 2 wolves | the lane in | S1 stash, the skyline head | 2:30 |
| J2 | turret T1, then 3 wolves + Brute | bay 3 ramp | S2 ledge stash, the crane in the sky | 4:00 |
| J3 | the yard and the drone line | the east half, the terminal | vault sword S3, node cache | 5:00 |
| J4 | the Stand (the hardest) | the vestibule | giant-head cache S4, the wrecks | 3:30 |
| J5 | mow the field | the lane | 12 loot containers, the hidden car | 3:30 |
| **J1 to J5** | | | | **about 18 to 19 minutes** |

**Slice total:** town 5, junkyard 18 to 19, arena 10 (about 1 intro, 4 phase 1, 1 transition, 3 to 4 phase 2, 0:30 ending) = **about 33 to 35 minutes**, up to 40 with every side thing. That sits inside the pitch's 30 to 45. If it runs long, trim optional secrets before any fight, and shorten the Car Graveyard first.

## Save terminals and checkpoints

- **Save terminals:** Red's hideout (rest too), J3 east (last on foot before the loader), the arena gate. Save terminals save; whether they also heal is the Combat Designer's rule.
- **Autosave on entering:** the hideout, J1, the arena gate.
- **Checkpoint = a room entrance** (the retry rule in the tech plan, Decision 2 option A). A death in J4's Stand restarts at J4's entrance with the Stand re-lit but the earlier hack flags kept.

## What stands in for art (placeholders only)

| What | Stand-in |
|---|---|
| Junk, cars, containers, crates, lamp posts | the robot-test props (`art/placeholder/robots/props/`) at their sizes (cars 4.4 m, containers 6 m, crates 0.8 and 2 m) |
| Cliffs | stacked box walls with the `junkyard_ps2` rust tiles (Ross's city rust and steel tiles) |
| Giant wrecks (arm, head, leg) | boxes and cylinders scaled to 20, 15 and 18 m |
| Cranes | tall boxes with a hinged jib; the gantry crane is two legs and a rail |
| Turrets | the Technical Artist's wall-turret blockout |
| Fuse boxes, terminals, drone line | small boxes with a lit panel; the dispenser is a 4 × 2 × 3 m box with a roller strip |
| The loader | the CS-21 small robot blockout |
| Look | `junkyard_ps2`: the grim PS2 look, desaturated, edge light, long draw distance, light haze (VS-39 sibling, Technical Artist) |

## Art the junkyard needs (for docs/art_requests.md; Ross makes the final art)

| Name | For | Size | Budget | Palette | Format | Goes in |
|---|---|---|---|---|---|---|
| Junk pile kit | Cliffs and heaps in every room | 6 pieces (crushed car wall, container stack, scrap heap, spool, tyre stack, barrel) | 300 to 800 tris each | Rust, steel, oil black, hazard stripe | GLB | `game/art/final/world/junkyard/` |
| Gantry crane | J3 | 40 m tall, 66 m rail | 1,500 tris | Rust and hazard yellow | GLB | same |
| Wall turret | J2, J4, J5, arena | 1.2 m | 500 tris | Blue-gray Signals | GLB | same |
| Fuse box, terminal, hack glow | J1 to J4 | 0.8 m | 200 tris | Teal hack glow on grey | GLB | same |
| Drone line dispenser | J3 | 4 × 2 × 3 m | 600 tris | Signals blue, hazard | GLB | same |
| Giant wrecks | J4 | arm 20 m, head 15 m, leg 18 m | 800 tris each | Ironstone and rust (match the colossus) | GLB | same |
| Loader cradle | J4 | 20 × 16 m | 800 tris | Hazard, amber lamps | GLB | same |
| Signals yard signs and memos | J1 to J4 | 6 posters and 3 signs | 2D | Slate, white | PNG | `game/art/final/world/junkyard/signs/` |

## Graybox build notes (for the builder, VS-20)

**Generator:** `make_junkyard_rooms.py`; scenes in `scenes/slice/junkyard/`; rows in `data/slice/rooms.json`. Rooms `junk_j1` to `junk_j4`: `kind: dungeon`, `camera: orbit`, `combat: true`, `look_profile: junkyard_ps2`, `form: red`, `checkpoint: true`. `junk_j4`: `robots: junk_j4`. `junk_j5`: `form: small`, `robots: junk_j5`, `checkpoint: true`, `autosave: false`. Placements (hack targets, enemies, pickups, terminals, barks) in `data/slice/placements.json`; robot data in `data/slice/robot_rooms/junk_j4.json` and `junk_j5.json`.

**Rooms and spawns (the test reads these):**

| Room id | Display name | Size (x × z) | Spawns | Exits (door → target:spawn) |
|---|---|---|---|---|
| `junk_j1` | Yard Gate | 64 × 44 | `from_market` (2, 22), `from_j2` (60, 22) | W → `market_gate:from_junk`; E fuse door → `junk_j2:from_j1` |
| `junk_j2` | Scrap Canyon | 150 long | `from_j1` (2, 14), `from_j3` (148, 14) | E gate → `junk_j3:from_j2`; W → `junk_j1:from_j2` |
| `junk_j3` | Crane Yard | 100 × 80 | `from_j2` (2, 60), `from_j4` (98, 40) | W → `junk_j2:from_j3`; E hangar door → `junk_j4:from_j3` |
| `junk_j4` | Wreck Row | 90 × 60 | `from_j3` (2, 30), `from_j5` (88, 30) (debug only) | W → `junk_j3:from_j4` (blocks after the loader wakes); E smash wall → `junk_j5:from_j4` |
| `junk_j5` | Smash Run | 280 × 110 | `from_j4` (2, 55) (placed in the loader) | E gate → `kasp_arena:from_j5` |

**Flags (suggestions):** `hack_j1_door_open`, `hack_j3_bridge_placed`, `hack_j3_vault_open`, `dline_j3_dead`, `j4_stand_started`, `j4_stand_cleared`, `loader_awake`, `j5_gate_smashed`. Sticky flags are marked in placements.

## Test and screenshots

- **Headless test (`integration/test_slice_rooms.gd`, Level Designer):** every `junk_j*` scene loads; every door's target and spawn exist; from each arrival spawn a walk check reaches every door, terminal, hack target and pickup (J3: the east half is only reachable once `hack_j3_bridge_placed` is set, so the test sets it; J4 east: once `j4_stand_cleared`); the fuse door, gate terminal, crane bridge and Stand shutters behave sticky across a reload; no `junk_j*` placement is closer than the camera ring to a wall in a fight space; the Smash Run's loader lane reaches the exit through walls the loader can break.
- **Screenshots for Ross (`docs/screenshots/slice_junkyard_*.png`):** J1 with the skyline head, J2's chute with the turret, J3's pit with the crane, J4's wrecks and the loader in its cradle, J5's Foreman's Wall. Placeholders until Ross's art arrives.

## As built (VS-20, J1 to J4 on foot, 2026-10-09)

- **Generator and files.** `game/scripts/tools/make_junkyard_rooms.py` (with `junk_kit.py`, which builds scrap cliffs from the walkable rectangles; a room is "these rectangles" and the walls follow) writes `game/scenes/slice/junkyard/junk_j1..j4.tscn`. Rows in `data/slice/rooms.json` (`kind: dungeon`, orbit camera, combat, checkpoint; J1 autosaves; J4 names `robots: junk_j4`; `look_profile` is `grim_ps2` until the Technical Artist's `junkyard_ps2` exists). Doors, pickups, crates, signs and the hack-target settings are in `data/slice/placements.json` (`jk_*` ids; the hack targets are the Gameplay Programmer's section, extended with the two fuse-door slabs and the corrected crane paths). Words: `data/dialogue/junkyard_placeholder.json`. Sizes and doors are the map's: J1 64 x 44, J2 150 long in three bays, J3 100 x 80, J4 90 x 60.
- **What the scenes carry for the code that is landing.** Hack targets are Node3Ds with the target scripts (`hack_j1_door`, `term_j2_gate`, `crane_j3`, `dline_j3`, `hack_j3_vault`, `loader_j4`); `Encounters/<enc id>` Node3Ds at the trigger centre with one Marker3D per spawn (read from `encounters.json` by the generator, so they cannot drift); `Fixtures/<turret id>` at the mount (y = the mount height, facing the fight); `Barks/bark_*` Marker3Ds with a `radius_m`; `Shutters/shutter_w` and `shutter_e` in J4 (raised = open; the Stand drops them to y 0); `Breakables/VaultWall` (group `crane_breakable`) and `Breakables/SmashWall` (group `loader_smash`); save terminals (`term_save_j3`, the old `SaveLamp` script).
- **Differences from the sketch.** The J3 pit runs the whole depth (z 0 to 80) so the crane's bridge is the only way over; the girder's path now ends at x 50.5 so its 12 m lands on both rims. J2's T1 sits in an alcove ledge cut into the north cliff (an unreachable 4 m perch); T2's ledge is reached by a scrap ramp up the north side and the car-roof stash on it needs one jump. J4's smash wall is a plain solid for now. J5 (VS-22) is not built; `junk_j5` is listed in `rooms.json` `pending_rooms`.
- **Test.** `game/tests/integration/test_slice_yard_rooms.gd` (data, the walk check, fight spaces at least 85 percent open floor in a 24 m circle, doors both ways to the market and between rooms, the crane bridge joining the halves of J3, a real boot of each room). Screenshots: `docs/screenshots/slice_junkyard_j*_overview.png`, `slice_junkyard_j1.png`.
