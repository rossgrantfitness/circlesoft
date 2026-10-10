# The ore train: layout map (vertical slice opening)

> Owner: Creative Director (proposes) · Ross (approves).
> **Status:** the opening itself is ✅ APPROVED by Ross, 2026-10-08 (structure pass D1 A: "a playable ore-train run of about 4 minutes"). This page is the builders' blueprint for it. The room layout and the studio calls at the bottom follow the approved outline; **one small open call for Ross is at the bottom** (what happens when an inspector spots Red), and the map is drawn with the studio's recommendation.
> Companion pages: docs/maps/harrow_landing.md (room conventions and graybox rules are defined there and apply here too), docs/maps/road_and_tower.md.

## For Ross (the short version)

- **New Game starts here:** night on the Harrow ore line. Red rides a freight car with Watch Zero's contraband crate. Signals inspectors board and sweep the train with hand scanners.
- **3 car rooms:** a flatcar (learn to move, run and hop), an ore hopper (sneak between ore heaps, then one short must-win fight that teaches Clutch), and a boxcar (the scanners close in; she shoves the crate into the harbor and jumps for the platform).
- **About 3.5 to 4 minutes.** No timer: the tension comes from the inspectors' visible scanner cones.
- **All built from one train-car kit plus props you already have** (crates, the grunt model, the existing patrol and chase). The kit comes back later for Tilly's dead ore line.

**Borrowed, openly, with our own surface:** arriving in the city on a night train in the middle of the action is FF7's opening; the car-by-car ID sweep is FF7's train run; the feel of being hunted (guards you can see, cones you avoid, hiding behind cover) is MGS1's. **Stacking check:** Red is alone, a courier on a smuggling run (not a hired gun on a sabotage job); it's an ore freight, not a passenger train; she's racing home to light a lamp; and she loses the cargo, which starts the story. One borrowed role per beat; the people, plot and look are ours.

## Box diagram

```
  rear of the train (inspectors boarding; locked: "Inspectors back there.")
        |
  +-----v------------------------------------+
  | C1 THE FLATCAR                            |  opening scene; walk, run, hop
  | lashed cargo row (hop), container stacks  |  1 inspector follows in (cone)
  +--------------------------------------+---+
                                         | east coupling
  +--------------------------------------v---+
  | C2 THE HOPPER                             |  ore heaps = cover
  | patrol inspector (cone)    brake hut  ->  |  must-win tutorial fight at the hut
  +--------------------------------------+---+
                                         | east coupling
  +--------------------------------------v---+
  | C3 THE BOXCAR                             |  2 inspectors close in from the west
  | freight stacks = cover   open side door ->|  ditch the crate, then THE JUMP
  +-------------------------------------------+
                       |
                       v  scene: lands on the freight platform, runs home
               HARROW: H4 Red's home (harrow_landing.md, spawn from_square)
```

The train never stops. Each coupling is one way (east only): once Red moves up, the car behind is full of inspectors.

## The route (main path)

1. **C1 The Flatcar.** Opening scene (about 20 seconds): the ore line along the harbor at night, Harrow's slum lights ahead, Red sitting on her crate (the Coldrunner lantern chalked on the lid). The train slows through a junction gantry; flashlights and a loudspeaker ("SIGNALS INSPECTION. REMAIN WHERE YOU ARE.") at the rear. Red is already up and running. Control returns: walk, run, a row of lashed crates to hop. One inspector climbs onto the car from the rear about 10 seconds later and walks east with his scanner cone: the first look at the cone, with plenty of room to stay ahead.
2. **C2 The Hopper.** An open ore car with heaps of ore taller than Red. One inspector walks a loop down the middle, scanner sweeping. Red slips heap to heap behind his back. At the east end, a second inspector steps out of the brake hut in front of the coupling: "Scanner says you're contraband." **Must-win tutorial fight** (`grunt_solo`, story fight, no Run): the game's first battle, and the Clutch lesson. He waves the white flag.
3. **C3 The Boxcar.** A dark boxcar full of freight stacks, its side door open on the harbor. Short scene: two inspectors come through the west door behind her and sweep east, cones closing in. Red works between the stacks to the open door. **Ditch the crate:** a short scene; the scanners beep on the crate; Red looks at it, at the cones, and shoves it out into the harbor (splash). The freight platform's lights slide into view. **The jump:** an on-screen prompt; one press of Jump and she leaps for the platform as the train pulls in. Nothing to miss: if the player waits, the prompt waits.
4. **To Harrow.** Scene cut (about 10 seconds): Red lands rolling on the freight platform, the Quiet Hours siren starts up over the Landing (the first eight notes of Vane's fanfare), and she runs. Cut to H4 Red's home, spawn `from_square`, where the arrival scene and her first lamp check play (harrow_landing.md).

**Story beat used here:** `b0_train`. The Delivery Crate key item is in the bag from New Game and is removed by the ditch scene; Red gets it back in H8 Otis's office.

## Rooms

### C1 The Flatcar (`train_flatcar`)
- **What it is:** an open flatcar loaded with lashed cargo: a row of low crates across the deck, two tall container stacks along the far side. Beyond the deck: the rail bed rushing by, the harbor's black water, the stacked slums of Harrow Landing glowing ahead on the horizon. Wind, wheel clatter.
- **Ways in and out:** none behind (rear coupling locked: "Inspectors back there."); east coupling → C2.
- **Controls lesson (no text tutorial, just the layout):** open deck to walk and run; a full-width row of 0.9 m lashed crates that must be hopped; a gap between container stacks to slip through.
- **Inspector (optional to engage):** enters from the west end 10 seconds after control returns, walks east at a slow pace with his cone. If he spots Red: see Decision 1.
- **Pickups:** none. Red's only item here is the crate.
- **Examine:** the crate's chalked lantern ("Watch Zero's order. Thermoses, cushions, sleeve bells. The bells are the problem."), the slum lights ahead.

### C2 The Hopper (`train_hopper`)
- **What it is:** an ore hopper car: a steel-walled bin with four heaps of ore rising above Red's head, a narrow catwalk along the north wall, a brake hut at the east end. Dust blowing off the heaps.
- **Ways in and out:** from C1 (west end, one way); east coupling → C3 (blocked by the tutorial fight until it's won).
- **Patrol inspector (optional to engage):** loops down the middle of the car, scanner sweeping. The heaps block his cone. Timing his back is the lesson.
- **Tutorial fight (must-win, story):** a trigger near the brake hut; the second inspector steps out in front of the coupling. `grunt_solo`, tutorial tier, Red alone, no Run. The Clutch tutorial prompts that the dock fight used move here (it is now the first fight of the game). He takes the white flag and leaves; no respawn.
- **Pickup:** a crew locker on the catwalk with a chalked lantern on its door: **Ration Bar ×2** (suggestion; the Battle Programmer finalizes).
- **Examine:** the ore (Harrow's quota, heading off-moon), a quota stencil on the bin wall.

### C3 The Boxcar (`train_boxcar`)
- **What it is:** the inside of a boxcar: the west end wall with its door, the north side wall, freight stacks as cover, and the big side door on the south side rolled open on the harbor (the front edge, toward the camera). The Landing's freight platform lights grow in the doorway as the scene goes on.
- **Ways in and out:** from C2 (west door, one way); the open side door (the ditch and the jump; the only way out).
- **Entry scene (about 10 seconds):** Red slides the door shut behind her; a beat; it opens again and two inspectors step through with scanners up.
- **Two inspectors (optional to engage):** walk east side by side down the car, slower than Red, cones sweeping. Freight stacks block cones.
- **Ditch and jump:** a marked spot at the open side door. Interact: the ditch scene (about 15 seconds). Then the Jump prompt; press Jump: the leap scene. The inspectors freeze in place during both scenes (no catch during cutscenes).
- **Pickups:** none (keep the last car clean and fast).

## Fights at a glance

| Room | Encounter (data id) | Must-win? | Respawns? | Suggested level |
|---|---|---|---|---|
| C1 | `grunt_solo` (only if the patrol inspector catches Red) | No | No (the train is one way) | 1 |
| C2 | `grunt_solo` (only if the patrol inspector catches Red) | No | No | 1 |
| C2 | `grunt_solo`, the brake-hut inspector (tutorial, story) | Yes | No | 1 |
| C3 | `grunt_solo` per inspector who catches Red | No | No | 1 to 2 |

**Battle Programmer check:** every train fight is Red alone at level 1 (the dock fight was the first fight before, with Otis). Confirm `grunt_solo` lands in the tutorial feel band with one fighter; if not, give the train encounters an `enemy_scale` below 1 in data rather than changing the grunt.

## Walking time and pacing

| Piece | Walking | Everything else | Rough total |
|---|---|---|---|
| C1 Flatcar | 0:15 | opening scene 0:20, hop and dodge 0:15 | about 0:50 |
| C2 Hopper | 0:20 | sneaking 0:25, tutorial fight 0:45 to 1:15 | about 1:30 to 2:00 |
| C3 Boxcar | 0:10 | entry scene 0:10, sneaking 0:15, ditch and jump 0:25 | about 1:00 |
| To Harrow | | scene cut 0:10 | 0:10 |
| **Train total** | | | **about 3.5 to 4 minutes** (approved: about 4) |

Each optional caught-fight adds about a minute. **If playtests run long:** first shorten the opening scene, then switch Decision 1 to option B (caught = restart the car, no extra fights). The tutorial fight stays.

## Scanner sweep (the one new enemy behavior)

A Signals inspector is the existing roaming map enemy (patrol, chase, touch-to-fight, first-strike rules) with a visible scanner cone added:
- **The cone:** a flat, dithered wedge drawn on the floor in cold white (Hegemony light), 5 m long, 25 degrees each side of where he faces, sweeping 20 degrees left and right about once every 2 seconds. It is the only detection: no hearing, no radius behind him.
- **Cover:** anything tagged `cover` that is taller than 1.2 m blocks the cone (a ray from the scanner at 1.0 m height to Red's chest). Ore heaps, container stacks and freight stacks are cover; the 0.9 m lashed crates are not.
- **Spotted:** Red inside the cone and unblocked for 0.4 s. The scanner beeps, the cone turns Signals red, and a "?" pops over the inspector's head (never "!", which belongs to battle). Then Decision 1 applies.
- **All numbers in data** (cone length, angle, sweep speed, spot time, chase speed) so they can be tuned without code. Headless tests: inside the cone and unblocked spots after 0.4 s; behind cover never spots; outside the angle never spots; a cutscene pauses detection.

## What stands in for art (placeholders only, no new character modeling)

| Who or what | Stand-in |
|---|---|
| Red | `red_shiba_grim`, with a 0.5 m tan box on her back for the crate (no animation; hidden after the ditch scene) |
| Signals inspectors | `enm_signals_grunt` plus a small box "hand scanner" in the right hand (held prop named `enm_signals_grunt_prop_scanner`) |
| Scanner cone | a flat wedge mesh with a dithered cold-white material; recolors red when spotted |
| Train cars | the train-car kit placeholder: one 3 m wide deck module and wall panels as gray-brown boxes with code-painted grime and rust; flatcar = deck only, hopper = deck plus 2.5 m bin walls, boxcar = deck plus 3 m walls and a roof edge strip |
| Cargo and cover | 0.9 m crate cubes (lashed row), 2.4 m container boxes, ore heaps as low 8-sided cones 1.5 m tall, freight stacks as 1.8 m box piles |
| Brake hut, crew locker | boxes; the locker gets the chalk-lantern decal |
| Moving world | two scrolling texture planes (rail bed and harbor water) below the front edge, and a far backdrop of slum lights on a slow scroll; no moving geometry |

## Graybox build notes (for the Gameplay Programmer)

Same conventions as docs/maps/harrow_landing.md: meters, origin at the north-west floor corner, +X east, +Z south toward the camera, steps up of 1.0 m or less, crates 0.9 m. **The train runs east.**

**Train-wide rules:**
- Deck height is the floor (y=0). The front edge (south) and the far edge of open cars have **invisible barriers**: you can't fall off the train. The only walk-off is each car's east coupling, and in C3 the jump scene.
- Couplings are 1.4 m wide doors at the east edge, z centered on the car; the west coupling of each car is a locked one-way door with the line "Inspectors back there."
- **Motion feel:** the scrolling planes and the wind particles sell the speed. No camera sway or shake while the player has control (the Retro effects wobble is enough); a small stepped shake is fine in scenes.
- Lighting: cold blue-gray ambient, sodium-orange spill from the slum lights on the horizon, one amber lamp: Red's own, riding with her (the grim look profile already gives her one).
- Auto-save fires on entering C1 (the start of New Game), so Continue works from the first second.

**C1 The Flatcar (`train_flatcar`)**
- Floor 20 × 6 m. Back walls: west = the rear car's end wall, 3 m (scenery; locked coupling at W wall @ z=3); north = two container stacks 2.4 m tall at x=3 to 8 and x=12 to 17 along z=0 to 1.2, with a 4 m gap between them (the far side beyond is barrier). Yaw 20. Camera bounds X 5 to 15, Z 3 to 3.
- Doors: E edge @ z=3, 1.4 m wide → `train_hopper:from_flatcar`.
- Red's crate (scene prop) at (2, 3.8). Lashed crate row: 0.9 m cubes across the full width at x=9, z=1.2 to 6 (must be hopped).
- Inspector: enters at (0.8, 3) 10 s after control returns; waypoints (0.8, 3) → (19, 3), walking 1.4 m/s, then stops at the coupling and turns back. The container gap at x=8 to 12 is a cover pocket.
- Opening scene: Red starts seated on the crate; control returns standing at `start`.
- Spawns: `start` (3, 3.8, facing east) = **New Game start**; `from_debug` same point.

**C2 The Hopper (`train_hopper`)**
- Floor 22 × 7 m. Back walls: west end wall 2.5 m (one-way door W wall @ z=3.5); north bin wall 2.5 m. Catwalk along the north wall, 1.2 m wide, at floor height (z=0 to 1.2). Yaw 20. Camera bounds X 5 to 17, Z 3.5 to 4.
- Doors: from C1 at W wall @ z=3.5 (spawn `from_flatcar`); E edge @ z=3.5 → `train_boxcar:from_hopper` (blocked until `train_tutorial_won`).
- Ore heaps (cover, 1.5 m tall, not climbable): (4.5, 5) 3 × 2 m; (9, 2.5) 3 × 2 m; (13.5, 5) 3 × 2 m; (17, 2.5) 2.5 × 2 m.
- Patrol inspector: loop (3, 3.8) → (16, 3.8) → (16, 4.2) → (3, 4.2), walking 1.4 m/s, pausing 1.5 s at each end.
- Brake hut 2 × 2 × 2.4 m at x=19.5 to 21.5, z=0 to 2. Tutorial trigger plane at x=18.5; hut inspector steps out to (20.5, 3.5), facing west. Encounter `grunt_solo` with the tutorial flag (prompts on), `can_run: false`.
- Crew locker (pickup) on the catwalk at (11, 0.4).
- Spawns: `from_flatcar` (1.2, 3.5), `after_fight` (19, 3.5).

**C3 The Boxcar (`train_boxcar`)**
- Floor 16 × 6 m, interior. Back walls: west end wall 3 m with the one-way door at W wall @ z=3; north side wall 3 m. South side: the open side door, x=9 to 14 on the front edge (z=6), with a 1.0 m rail on the rest of the front edge. Yaw 30. Camera bounds X 5 to 11, Z 3 to 3.5.
- Doors: from C2 at W wall @ z=3 (spawn `from_hopper`). No other exits; the side door is the ditch-and-jump spot.
- Freight stacks (cover, 1.8 m): (3.5, 1) 2 × 1.5 m; (6, 4) 2 × 1.5 m; (9, 1) 2 × 1.5 m; (12.5, 3.5) 1.5 × 1.5 m.
- Entry scene: Red at `from_hopper`, the door shuts and reopens; inspectors appear at (0.8, 2) and (0.8, 4.5). After the scene: both walk east at 1.0 m/s along z=2 and z=4.5, cones sweeping, and stop at x=13.
- Ditch marker: interactable at (11.5, 5.4), 1.4 m wide zone along the open door. Interact → `ditch_crate` scene (crate removed from the bag, splash, flag `crate_ditched`) → Jump prompt; Jump press → `train_jump` scene → set `train_done`, beat `b1_night` → load `harrow_home:from_square`.
- Spawns: `from_hopper` (1.5, 3).

**Data hooks (suggestions; the Gameplay Programmers own the files):** beat `b0_train`. Flags `train_tutorial_won`, `crate_ditched`, `train_done`. Rooms `train_flatcar`, `train_hopper`, `train_boxcar` in data/world/rooms.json, all with the grim look profile. New Game start = `train_flatcar:start` (was `harrow_home:start`). Scanner settings in a new data block (for example `data/world/scanner.json`). Encounters reuse `grunt_solo`; the tutorial one may need its own id (for example `train_tutorial`) only for the tutorial flag and `can_run: false`.

---

## Choice for Ross

DECISION NEEDED: What happens when an inspector's scanner spots Red on the train?
Option A: **He chases her and it's a fight if he catches her** (the same visible-enemy rule as everywhere else: touch him from behind and she gets the first turn; run or win and he's gone) — pros: no new rules to learn and no fail state in the first minute of the game; a player who gets caught just gets a bit more battle practice / cons: being spotted carries little sting, so the sneaking matters less.
Option B: **Caught means a short "busted" sting and a restart at the start of that car** (the MGS-lite version; the only fight is the tutorial one) — pros: the sneaking really matters and the run stays at about 3.5 minutes / cons: a fail-and-retry loop in the opening minutes, and one more small rule that only exists on the train.
Option C: **Caught means a noise ticket, not a fight:** the inspector fines her credits and she keeps going — pros: on-theme (tickets out of your ration card) and never stops the run / cons: Red starts the game with almost no credits, so the fine means nothing, and it teaches that the cones don't matter.
Recommendation: A. It reuses rules players already have from Harrow onward and keeps the first minutes forgiving; if playtests show nobody bothers to sneak, switch to B (it's the structure pass's fallback anyway).

*Studio calls made inside this map (overturnable):* three car rooms in the order flatcar, hopper, boxcar; one-way couplings; no timer; the jump is one prompted press that can't be missed; the tutorial fight sits at the hopper's brake hut and takes over the Clutch tutorial prompts from the dock fight; the cone numbers; the crate rides as a key item and a box on Red's back; pickup contents are suggestions for the Battle Programmer; room ids and spawn names are suggestions.
