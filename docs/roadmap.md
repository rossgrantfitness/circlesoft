# Roadmap and Project Checklist

> For Ross, 2026-10-09. Proposed by the studio; nothing past the vertical slice is final until Ross approves it.
> The day-to-day task list stays in docs/task_board.md; this page is the big picture: where the game is, where it goes next, and the gates where Ross decides.

**Where we are today:** the combat feels good ("totally bad ass"; hits and dashes "feel good"). We are in the middle of the **vertical slice**: one town, one dungeon, one boss, built to the quality of the finished game. About half of the slice's graybox (blocks, no final art) is built.

---

## The big picture

| # | Phase | What it means | Ross's gate at the end |
|---|---|---|---|
| 0 | **Foundations** ✅ | Studio set up, first prototypes, the turn-based version (shelved), the combat sandbox | Done: "totally bad ass" |
| 1 | **Slice graybox** ⏳ *(now)* | The whole slice playable in blocks: town → junkyard → loader → boss → robot round | Ross plays it: feel, layout, pacing |
| 2 | **Slice content and look** | Script, final words, cutscenes, the market and junkyard looks, music direction, Ross's art goes in | Ross signs off the script, the look and the art |
| 3 | **Slice finished** | QA, playtest, fixes, final slice build | **The big one:** is this the game? Go / no-go to full production |
| 4 | **Pre-production** | Plan the whole game: story for the bunny hacker, how many areas, the loop, progression, the title | Ross approves the full-game plan |
| 5 | **Production** | Build the game area by area (town, dungeon, boss, robot battle) using the slice as the template | Ross plays each area as it lands |
| 6 | **Alpha** | Every area playable start to finish; placeholders allowed | Ross plays the whole game |
| 7 | **Beta** | All final art, music and words in; only fixing and tuning | Ross signs off content |
| 8 | **Launch** | Release builds, store page, trailer | Ross says ship it |

**What sets the pace:** Ross's art (we build on blocks and swap his models in as they arrive) and the monthly spend limit, more than the code.

---

## Phase 0: Foundations ✅

- [x] Studio, roles and rules set up; Godot installed; builds for Windows and Mac
- [x] Turn-based prototype with town, battles and saves (shelved, not deleted)
- [x] Pivot to a third-person action RPG: the hacker bunny with a sword
- [x] Combat sandbox: Kingdom Hearts one-button combo, dash, jump, guard, lock-on, enemy AI (attack, block, dodge, flank, flee), Red and the Cyberwolf rigged, six swords
- [x] Giant robot test: loader robot → colossus, docking, sense of scale
- [x] PS2 look: sharp, native resolution, no grain or blur
- [x] Hacks as magic: Zap Drone, EMP, Overclock, Reboot, picked from a KH / FF command menu
- [x] Chunky hits (freeze, white flash, punchy sound) and dash on 5 charges

## Phase 1: Slice graybox ⏳ (now)

Built:
- [x] Slice plan, game modes, one shared room system, feature switches
- [x] Hack system in the world (battery, targets, hijacking, fuse doors, crane, terminals)
- [x] Health, saves and Continue after a knock-out
- [x] Night market graybox (9 rooms, shops, job board, save terminal, townsfolk)
- [x] Junkyard on foot, J1 to J4 (fights, hack targets, midpoint save)
- [x] Enemy roster: Signals cops, flying drone, wall turret, the heavy
- [x] Robots inside levels (boarding, robot rooms)
- [x] Boss system; phase 1, the Hushmaster, playable and tested
- [x] Kasp's arena, the on-foot-to-robot transition, placeholder words and sounds

Still to do:
- [ ] Loader run J5: finish and wire it in (built; tests and hookups left)
- [ ] Phase 2, the Heap robot round (in progress; 5 tests still red)
- [ ] Gameplay hookups: saves in robot rooms, one-way door, smashable walls, encounter and radio runners, music and sound wiring
- [ ] Graybox QA: automated run from title to the end of the boss
- [ ] Feel pass by the Playtester
- [ ] **Build for Ross: title to the end of the boss (Windows and Mac)**

## Phase 2: Slice content and look

- [ ] Slice script: hideout start, the job, the loader waking, Kasp's intro, the escape into the Heap, the ending *(Ross signs off)*
- [ ] Final words: market people, job board, radio, items *(Ross signs off)*
- [ ] Cutscenes from the script
- [ ] Market look (warm neon night) and junkyard look *(Ross signs off from screenshots)*
- [ ] Effects: hacks, Quiet Hours, parts breaking off, the scale switch
- [ ] Town life: people walking routines, crowds, chatter
- [ ] Shop stock and items
- [ ] Music direction brief *(Ross signs off)*, then music and sound hooks
- [ ] HUD polish: hack icons, portraits
- [ ] Tuning from Ross's graybox notes
- [ ] **Ross's art goes in**, in this order (docs/slice/meshy_art_list.md): Kasp, the Hushmaster, the Heap, the heavy, the drone, the turret, the loader, the colossus, town people, market and junkyard pieces, the Zap Drone, icons and portraits

## Phase 3: Slice finished

- [ ] Full QA: all automated tests, bot playthroughs, smooth frame rate on a real machine
- [ ] Playtest report: 30 to 45 minutes to the boss kill, difficulty, can you read the hacks and the robot round
- [ ] Fix pass
- [ ] **Final slice build. Ross plays it and decides: go to full production, or rework**

## Phase 4: Pre-production (planning the whole game)

These are the big open questions. Each comes to Ross as a decision when it's needed; none of them blocks the slice.

- [ ] **Story for the hacker bunny.** The current story bible was written for the old "Lights On" game. Keep what still fits (Red, Mox, Otis, Vela, Kasp, the Signals, the empire) and rewrite the rest, including the twist
- [ ] **Game size:** how many areas (town + dungeon + boss each), and how long (for example 8 to 12 hours)
- [ ] **The loop:** stay Mega Man Legends, or add roguelike runs in some dungeons (still "under discussion")
- [ ] **Progression:** how Red grows: new hacks, sword upgrades, swords with random affixes found in the world (Binding of Isaac style), Mox's workshop, gear you can see on her
- [ ] **The scale climb:** on foot → loader → colossus → bigger (spaceship? god-sized finale?), and which bosses go on foot first, then robots
- [ ] **Title** (with a name and trademark check)
- [ ] **Art at full-game scale:** the Meshy → rig → game pipeline, how many models per area, the swappable faces, Ross's motion capture
- [ ] **Music and sound:** final composer plan or tools
- [ ] **Where it sells:** Steam (Windows / Mac), consoles later?, price, demo
- [ ] Full-game task board and art list, area by area

## Phase 5: Production (area by area)

Each area is built the same way the slice was. **The checklist for every area:**
- [ ] Area pitch and map *(Ross signs off the layout)*
- [ ] Graybox: town or hub rooms, dungeon rooms, enemies, hack targets, saves
- [ ] New enemy types and new hacks or gadgets (if any)
- [ ] Boss on foot; robot battle at the end (where it fits)
- [ ] Script and words *(Ross signs off)*
- [ ] Look pass *(Ross signs off)*
- [ ] Ross's art for the area goes in
- [ ] Music and sound
- [ ] QA, playtest, fixes
- [ ] Build to Ross

## Phase 6: Alpha
- [ ] Every area playable start to finish (placeholders allowed)
- [ ] Save and load across the whole game
- [ ] Difficulty curve and length checked end to end
- [ ] Settings: controls remapping, controller support, audio, display
- [ ] Ross plays the whole game

## Phase 7: Beta
- [ ] All final art, animation, music and words in
- [ ] Title screen, logo, credits
- [ ] Bug fixing and tuning only; no new features
- [ ] Outside playtesters
- [ ] Performance on low-end machines

## Phase 8: Launch
- [ ] Store page, screenshots, trailer
- [ ] Release builds (Windows, Mac)
- [ ] Day-one fixes plan
- [ ] Ross says ship it

---

## Later list (ideas kept, not scheduled)

From Ross and the studio, parked until a phase picks them up:
- Swords found in the world with random affixes and upgrades (Phase 4 decides)
- Swappable faces for Red (eyes, mouths, special faces for big moments)
- Ross's own motion capture for signature moves
- Planted feet on slopes and stairs (the ik01 idea; R57)
- More robot fights at the ends of later levels; a whole boss fought at robot scale
- Hacks while piloting robots
- Double jump, gadget arm, goggles on/off
- Materials, crafting and the workshop; gear beyond swords
- Seamless rooms instead of fades
- Removing the old Lights On code (only when Ross says)

*Studio proposal. Ross decides.*
