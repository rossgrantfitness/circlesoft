# Action RPG Pivot: Buildability Study

> Owner: Technical Director (proposes) · Ross (approves). **Status: assessment only, 2026-10-08. Nothing here is approved and no game code has been written.**
> Read with: the Creative Director's concept pitches (in progress, same folder) and Ross's direction in docs/decisions.md (2026-10-08) and Playbook F59/F60.
> Grounded in a read of the current project (about 33,700 lines of game code, about 31,000 lines of tests, roughly 1,510 automated tests) and in render tests run in our cloud container today (section 8).

---

## Decisions for Ross

Three choices. None of them commits us to the new game; they set what we build first so you can judge it by playing.

**DECISION NEEDED: Do we build a small playable combat sandbox now, before the full design is settled?**
Option A: Build the sandbox now (section 6). One arena, Red with a sword, two kinds of practice enemies, and every move on your list. First download in about 2–4 days. — pros: you judge fun by playing it, which is how your feel calls have always been settled (run and jump, the battle camera). Any pitch the Creative Director writes needs this same core, so the work isn't wasted. / cons: it takes studio time before the story pitch is chosen, and it uses placeholder art and moves.
Option B: Wait for the concept pitches, pick one, then build a sandbox shaped around it. — pros: the sandbox matches the chosen story and world from day one. / cons: you'd be choosing a pitch on paper first, and paper approvals of feel have been overturned before (F37).
Option C: Skip the sandbox and plan the full vertical slice straight away. — pros: fastest on paper. / cons: if the combat isn't fun, we only find out after building a town, a dungeon and a boss on top of it.
Recommendation: A. Combat feel is the riskiest part of this pivot and the part you can only judge by playing, and the sandbox is the same whichever pitch wins.

**DECISION NEEDED: How should the camera work?**
Option A: A free camera everywhere. You turn it with the right stick and lock on to enemies, as in Kingdom Hearts or Devil May Cry. — pros: the most freedom and the best fit for fast action. / cons: every room, town buildings included, needs all four walls and more detail, because the camera can look anywhere. That means the most art for you and a full rebuild of the town rooms.
Option B: Mixed. Towns keep the current fixed diorama view; dungeons and fights get the free camera with lock-on. — pros: the town rooms we already built keep working, and towns stay cheap to make. Fights get the camera they need. / cons: two camera styles to tune, and the switch between them has to feel natural.
Option C: An "action diorama": a high camera that follows Red and never rotates, used for fights too, as in some top-down action games. — pros: the cheapest art, since rooms stay as dioramas. / cons: jumping, air combos and lock-on read less well from high above, and it's further from the games you named.
Recommendation: B. It gives fights the camera fast action needs without making you rebuild every town. The sandbox will have one key that flips to C so you can feel the difference yourself.

**DECISION NEEDED: How far toward the PS2 look do we go?** (Section 8 has the details.)
Option A: Early PS2. A hero of about 3,000 triangles, 256–512 pixel textures, smooth textures, real lighting and shadows, bloom, sword trails, and a 640×360 picture scaled up. — pros: it clearly reads as PS2 and is about 3–4 times the work of today's models, not 10 times. It runs on ordinary laptops and keeps our cloud screenshots. / cons: still a big jump in modeling, texturing and rigging per character.
Option B: Late PS2. A hero of about 5,000–6,000 triangles, 512 pixel textures with more painted detail, smooth-skinned faces and hands, and more effects. — pros: the richest look. / cons: roughly 5–8 times today's work per character, and every animation shows more flaws. This is where outsourcing would stop being optional.
Option C: "PS1.5". Keep today's simple models and the 17-bone rig, but replace the PSX rendering with PS2 rendering: smooth textures, no wobble, real lights and shadows, bloom, trails, a higher resolution. — pros: almost no extra art. We could show it within days on the models we already have. / cons: the models stay chunky, and up close it won't pass for PS2.
Recommendation: A, reached in two steps: switch the rendering first (that's C, cheap, and you see it on our current models), then raise model detail as your new models arrive. You get the PS2 feel quickly, and the extra modeling work is only spent once you've seen the look.

*No decision needed on the renderer:* we recommend staying on the Compatibility renderer you approved on 2026-10-06. Tests today show it can do real-time shadows, bloom and our own grade and post effects (section 8). It only becomes a question if you later want an effect that needs Forward+.

*Approved rules this pivot would change (each comes back to you once the direction is chosen, not now):* "Armor never changes the model" (style guide); the fixed diorama camera everywhere (camera decision, 2026-10-06); "PSX-era style" in CLAUDE.md's "The look" section; the 17-bone rigid rig and model budgets in the model contract.

---

## 1. For Ross

**The short version.** Most of what we built carries over. The PSX/grim look, walking and jumping, rooms and doors, saving, menus, shops, equipment, talking, NPCs, gibberish voices, dungeon puzzles and the robot tester are the frame of a Mega Man Legends-style game, and they work today. What we don't have is the action core: the camera, the sword combat, the dash, the parry and enemies that fight back in real time. That's the part that makes the game fun, and it's also the hardest part.

**In numbers.** About 70% of our existing code keeps its job (about 55% as is, about 15% reworked). About 30% retires: the turn-based battle, its menus and the battle stage. But that doesn't mean the new game is 70% done. The action core is new, and I'd put it at more than half of the remaining work to a vertical slice.

**The biggest cost is animation, not code.** A turn-based enemy needed one animation (standing idle). An action enemy needs eight to ten: walk, wind-up, attack, get hit, get launched, fall, get up, die. Red goes from 6 clips to about 25. My plan for keeping that affordable:
- Moves are timed by numbers in data files, not by the animation, so a rough animation never breaks the game.
- Attacks are 2–3 strong key poses that snap from one to the next, the way old games and anime do it, instead of fully smooth clips.
- Getting hit, being knocked flying and spinning in the air are done in code, so nobody has to animate them.
- One weapon type (the sword) for the slice. New swords are new looks on the same moves, so a "super cool new sword" costs you a model, not a new set of animations.

**The PS2 upgrade.** It's very doable in our engine, and the rendering half is cheap: smooth textures, real lights and shadows, glow, sword trails and a sharper picture can be switched on and shown on our current models within days. The expensive half is your art: PS2 models have about 3–6 times the triangles, textures with 4–16 times the pixels, and smooth bending joints that need weight painting. Today's placeholder models keep working as stand-ins until yours arrive. The cast, Red's locked design, the world, the maps, the dialogue and all the game data survive untouched.

**What I propose.** A small combat sandbox you can download in a few days. One arena; Red runs, jumps, dashes and air-dashes; a three-hit combo, a heavy hit, a launcher and air juggles; a parry; two kinds of practice enemies; hit-stop and screen shake; and a sword rack where you swap swords and see the new one in her hand. It includes a "feel knobs" panel so you can change dash distance, jump height and hit-stop strength yourself and tell us which settings felt right.

---

## 2. Reuse audit

Line counts are from today's code (game/scripts, about 33,700 lines). "As is" means it keeps working with at most small edits. "Adapt" means the idea and much of the code survive with real changes. "Drop" means it retires with the turn-based design (kept in git history, not deleted until Ross decides).

### Carries over

| What | Where | Lines | Verdict | Notes |
|---|---|---|---|---|
| PSX screen, look profiles, grim grade, grime dressing, edge light | core/psx_screen, psx_look, psx_room_look, look_profiles, grime_paint; field/grim_*; shaders/ | ~2,900 + shaders | As is → then adapt for PS2 | The pipeline (low-res world in a SubViewport, sharp UI on top, one data file per look) is exactly what a PS2 look needs; the shader contents change (section 8). |
| Movement math: camera-relative direction, run, jump, coyote time, jump buffer, release-cut, air control | field/player_motion.gd (pure), player_controller.gd | ~540 | Motion as is; controller adapt | player_motion is pure, tested and renderer-agnostic. The controller's `step(delta)` gets wrapped by an action state machine (dash, attack, hurt). Tuning stays in field_tuning.json. |
| SceneRouter, rooms, doors, pickups, crates, spawns | core/scene_router, field/door, pickup, crate, field_room | ~1,100 | As is | Dungeons are just more rooms. The battle detach/attach path in Main is no longer used. |
| Save/load (versioned, atomic, migrations, auto-save on area entry) | core/save_manager, game_state, save/* | ~1,850 | As is (+ new fields) | Party becomes a party of one; add materials, gear visuals and dungeon gates as new save fields with one migration step. |
| Menus, MenuList, config, title, name entry, UI kit | ui/* (root), ui/menu/* | ~8,000 | Mostly as is | Party page retires; Skills page becomes moves/upgrades; Equip page adapts to the new slots and gains a 3D preview of Red wearing the gear. |
| Shops, Bag, Equipment, StatCalc, ItemData | inventory/*, ui/shop/*, progression/stat_calc | ~1,800 | As is → adapt | StatCalc (base + boosters + gear) drives action stats unchanged. Equipment gets new slots (weapon, head, body, arms, charm) and a `visual` block per item. MML-style crafting from materials is a small ShopLogic extension. |
| Dialogue runner, speech bubbles, speakers, portraits, gibberish voices, NPCs, story director, conditions | dialogue/*, ui/speech_bubble, audio/*, field/npc, placed_npc, story_director | ~3,400 | As is | Towns are where this lives; nothing in it depends on turn-based combat. |
| Dungeon gadgets: bells, cage lifts, card gates, power switches, push crates, traversal spots | works/*, field/traversal_spot | ~1,000 | As is | Ready-made dungeon puzzle pieces, the MML "dig site" kind. |
| Data-driven design (DataDB, JSON/CSV, validation) | core/data_db + game/data/ | ~200 + data | As is | Every new combat number goes in data/combat/. |
| Test harness: headless runner, test_case, kits, simulator pattern, visual capture | tests/run_all, framework/*, sim/*, visual/* | ~5,600 | As is | The "logic as pure classes, clock passed in" rule is exactly what makes combat testable. |
| Field enemy patrol / chase / give-up AI, sight cone, scanner | encounter/map_enemy, scanner | ~710 | Adapt | Becomes the "not yet fighting" half of the action enemy brain. The "touch Red to start a battle" ending is removed. |
| ClutchJudge (timestamp judging, windows, first-press-only, timing offset, Wide Windows) | battle/model/clutch_judge | 190 | As is, re-used for parry | See 3.5. The anti-mash rule is exactly what a parry needs. |
| Clocks (BattleClock, RealClock, VirtualClock), PressSource family | battle/model/*clock*, *press_source* | ~250 | As is | A new CombatClock (game time that stops during hit-stop) slots into the same interface. |
| Damage formula, status rules, rewards/drops | battle/model/damage, status_rules, rewards | ~400 | Adapt | Same maths and data (formulas.json, statuses.json); the "turn" ticks become seconds. Drops feed the materials loop. |
| Weighted enemy AI with conditions | battle/model/enemy_ai | ~200 | Adapt | Picks which attack an enemy uses; new conditions: distance, player airborne, player guarding. |
| Procedural reactions: lunge, recoil, squash, flash, hurt face, knock-out fall, blink-out | battle/view/combatant_view (part) | ~350 of 748 | Adapt | Exactly the "animate it in code" kit enemies need for hit reactions. |
| Camera shake, cinematic shot director | battle/view/battle_camera (shake), battle_cam_director | ~600 | Adapt | Shake moves to the action camera; the shot director becomes boss intros and finisher cams (your storyboard, F50). |
| Rating pop-ups (Nice / Rad / TOTALLY RAD) | ui/battle/battle_popup | ~350 | Adapt | Ready-made art and motion for parry ratings and style-meter rank pop-ups. |
| XP and levels | progression/progression | ~150 | Keep or drop by design | MML had no XP; power came from gear. Cheap either way; the Creative Director's design decides. |
| Party follow | field/party_follow, party_follower | ~250 | Park | Single hero. Could later drive a companion NPC. |

### Drops

| What | Where | Lines |
|---|---|---|
| Turn-based controller, turn order, battle state/setup, boss turn logic, battle data shape | battle/model/battle_controller, turn_order, battle_state, battle_setup, battle_boss, battle_data (most) | ~2,100 |
| Battle HUD: command menu, targeting, turn row, party panel, victory and game-over screens, test picker | ui/battle/* (except popups) | ~3,000 |
| Battle stage: scene, backdrop, stage tuning, battle camera framing | battle/view/* (except the parts above) | ~2,500 |
| Encounter transitions: field encounters, first-turn rules, room fights, static transition | encounter/encounter_rules, field_encounters, field/room_fights, battle_static, screen_static.gdshader | ~700 |
| Main's battle flow (detach room, run battle, retry, re-attach) | core/main (part) | ~250 |

### The estimate

- **Code:** about **55% carries over as is, about 15% adapted, about 30% dropped** (roughly 18,500 / 5,500 / 9,700 of 33,700 lines).
- **Tests:** about 9,600 lines (about 30%) test the turn-based battle and encounters and retire with them. The harness itself, and every test of the systems we keep, stays.
- **Honest caveat:** reuse by lines overstates progress. What carries over is the RPG frame; the action core is new. Against the work to an action vertical slice, I'd put the existing code at **about 35–45% of the total**, with the remaining majority being the camera, combat, enemies and, above all, animation and art.

---

## 3. What the action game needs that we don't have

Difficulty: **S** = a day or two, **M** = a few days, **L** = a week or more of build and tuning, **XL** = ongoing (mostly art).
Rule kept from the tech plan: combat logic lives in plain `RefCounted` classes with a clock passed in, no nodes, so it can be tested headless and run thousands of times. Scenes only show it and feed it input.

### 3.1 Camera (M–L)
- **What:** a third-person orbit camera (right stick turns it, auto-recenters behind Red when she runs) plus lock-on (one button picks the best target; the camera frames Red and the target; flick the stick to switch targets).
- **Godot 4.5:** `Node3D` pivot → `SpringArm3D` (pulls the camera in when a wall gets between it and Red) → `Camera3D`. A pure `LockOnMath` class scores targets by screen-centre distance, world distance and line of sight. The existing prop fader (dithers out objects between camera and Red) keeps working, since it already casts a camera-to-Red ray.
- **Hybrid:** towns keep `DioramaCamera` unchanged. A room's data says which rig it uses (`camera: "diorama" | "action"`), and the router places the right one. Dungeon rooms are built for the free camera: four walls and ceilings, or open-topped spaces with dark fog beyond.
- **Attack magnetism:** when an attack starts, Red snaps to face the nearest enemy within a cone of the stick direction. *Why it matters for the game: this is what makes simple button presses feel like "mowing down everything", without fiddly aiming.*
- **Hard part:** camera collision in tight interiors, and lock-on framing with crowds. That's tuning, not invention.

### 3.2 Hitboxes, hurtboxes, hit-stop, knockback (M)
- **Hitboxes:** an `Area3D` with a generous shape (capsule or box) placed in front of Red, defined per move in data (offset, size, which frames it's active). It is not glued to the blade bone. Each swing keeps a "who I already hit" list, so one swing hits each enemy once. Fast swings use a few overlapping shapes along the arc so nothing slips between physics frames. *Why it matters: generous, data-defined hit zones feel fair and powerful, and they don't depend on the animation being perfect.*
- **Hurtboxes:** one `Area3D` per fighter on its own physics layer. I-frames simply switch it off.
- **Hit-stop:** both fighters freeze for 40–120 ms on impact (number per move in data). This is done with a shared CombatTime scale that every fighter multiplies into its own `delta`, not with `Engine.time_scale`, so menus, sound and the parry clock aren't disturbed. *Why it matters: the tiny freeze on contact is most of what makes a hit feel heavy.*
- **Knockback and launch:** an impulse added to the enemy's velocity, decaying over a few frames; launchers set an upward speed. Screen shake comes from the existing battle-camera shake code (stepped, PSX-chunky; smooth for the PS2 look).
- **Feedback kit:** a hit spark (billboard sprite), a hurt-face swap and flash (exist in combatant_view), and an impact sound from the existing SFX system.

### 3.3 Combo / attack state machine (L)
- **What:** light strings (L, L, L), a heavy, a launcher, air attacks, an air finisher, and cancels (dash out of an attack's recovery; jump out of the launcher).
- **How:** a move graph in `data/combat/moves.json`. Each move has: startup, active and recovery in ms; a cancel window; "next" links per button (light → light_2, heavy → finisher); hitboxes; power, launch and knockback; hit-stop; the clip name; and the procedural fallback. A pure `MoveRunner` class steps through it, with a small `InputBuffer` (about 150 ms) so a press slightly early still chains. *Why it matters: designers retune or add a combo by editing a data file, and a bot test can check "light, light, heavy launches" without a screen.*
- **Air juggles and gravity:** while an enemy is being juggled, its gravity drops (for example to 30% for 0.25 s after each hit), and each extra air hit gives a little less lift, so juggles look floaty but can't go on forever. Red's air attacks briefly zero her fall speed so she hangs with the enemy. All of these numbers live in data.
- **Launcher input:** feel-dependent (hold heavy, back+heavy, or the end of a string). The sandbox builds all three behind a toggle and Ross picks by playing.

### 3.4 Movement: dash and air-dash with i-frames (S–M)
- **What:** a ground dash (short, fast, invulnerable for its first part), one air-dash per jump, a dash that cancels attack recovery, and a short cooldown so it can't be spammed endlessly.
- **How:** a new state in the action controller on top of `PlayerMotion`. Distance, duration, i-frame window, air-dash count and cooldown live in data/combat/player_action.json. Coyote time and jump buffering are already built and tested.
- *Why it matters: the dash is the "speed" half of Ross's brief; it has to be instant and generous.*

### 3.5 Defense: parry / perfect guard (M), re-using ClutchJudge
- **What:** press Parry just before an enemy's hit lands. Landing it early or late gives a partial guard (less damage); landing it on time staggers the enemy, slows time briefly and opens a counter.
- **How:** the enemy attack's "impact moment" plays the role of the Clutch cue. `ClutchJudge.rating_for_delta(press − impact, window)` gives Nice / Rad / TOTALLY RAD, which map to partial guard / parry / perfect parry, and the windows live in timing_windows.json under a new `parry` entry. Two existing rules carry straight over: only the first press counts (so mashing parry fails), and the player's timing offset and Wide Windows options keep working. The one change is that the window is one-sided (presses after impact are too late, because the hit has already landed).
- **Clock detail:** judge on CombatClock (game time that pauses during hit-stop), not raw system time, so a hit-stop between the wind-up and the impact doesn't shift the window. Presses are still timestamped in `_input()`, as Clutch does today.
- **Telegraphs:** the Clutch system's cue flash and "!" become the enemy wind-up flash. *Why it matters: the timing judge is the most tested code we own (every boundary, the offset, anti-mash), so parry starts out fair.*

### 3.6 Enemies: AI, telegraphs and crowd/token management (L)
- **Brain (pure state machine):** idle/patrol → notice (re-use MapEnemy's sight cone and give-up) → approach → circle at a ring distance → ask for an attack token → telegraph (wind-up pose, flash) → attack (hitbox active) → recover (punish window) → react: hit, stagger, launched, juggled, down, get up, die.
- **Attack tokens:** a per-room `AttackDirector` hands out a limited number of "may attack now" tokens (for example 2), and everyone else circles and threatens. *Why it matters: Red can be surrounded by many enemies and still feel powerful rather than ganged-up on; it's the trick most character-action games use.*
- **Attack choice:** the existing weighted AI list with conditions (enemy_ai), extended with distance and "player in the air" conditions.
- **Poise:** heavies have a poise bar; until it breaks they don't flinch (super armor) and can't be launched.
- **Fodder vs. elites:** most enemies die in a few hits ("mowing down"); a few elites and the boss carry the challenge.

### 3.7 Style meter (S)
- **What:** points per hit, a bonus for variety (repeating the same move decays its value), a drop when hit, and ranks shown on screen. It can feed a currency bonus.
- **How:** a pure `StyleMeter` class with numbers in data/combat/style.json; the rank pop-ups re-use the Nice / Rad / TOTALLY RAD pop-up code and art. The rank names are a creative call.

### 3.8 Visible gear swaps (M code; the cost is art)
- **What the rig gives us:** Red's 17-bone rig already has `weapon_socket` (right hand) and `prop_socket` (left hand), and her sword is already a separate mesh on the weapon socket (2 meshes: body and sword, checked by test_red_shiba_grim). With rigid skinning, each vertex follows exactly one bone.
- **Bolt-on gear:** each piece of gear is a small separate model attached to one bone with Godot's `BoneAttachment3D`: sword → weapon_socket, shield → prop_socket, helmet → head, pauldrons → upper_arm, gauntlets → forearm, boots → shin. With the current rigid rig, armor pieces need no weight painting at all.
- **Helmet on and off, ears included:** scaling a bone to zero hides everything on it, so "helmet on" can hide the ear bones and the shiba ears don't poke through. One flag in the item data.
- **Data:** each gear entry in equipment.json gains `"visual": {"bone": "head", "model": "res://…", "hides": ["ear_l", "ear_r"]}`. A `GearVisuals` node on Red reads the equipped loadout from GameState and attaches the models. *Why it matters: a new sword or helmet is a data entry plus one small model, and it shows up everywhere Red appears.*
- **Body armor that covers bending parts** (a chest plate, a coat) needs either rigid plates or a skinned mesh swap on the same skeleton. Fine under the PS1 rig; more work under PS2 smooth skinning (section 8.3).
- **Conflict to flag:** the approved style guide says "Armor never changes the model". Ross's F60 asks for visible armor, which is newer, but the style guide line changes only once Ross approves the new direction.
- **"Customizable character":** with Red as the fixed hero, customization means gear, colors and swords, not a body or face creator (section 4, Risky).

### 3.9 Animation: the biggest cost (XL, mostly art)
**The honest count.** Turn-based needed Red's 6 movement clips plus battle clips, and enemies needed only `idle`. Action needs:
- **Red, about 25 clips:** idle, run, jump, fall, land, dash, air-dash, light 1–3, heavy, launcher, air 1–3, air finisher/slam, parry, parry success, hurt (light and heavy), knocked down, get up, death, and lock-on strafes (if lock-on strafes).
- **Each enemy type, about 8–10:** idle, move, 1–2 attacks with a wind-up, hit, launched/tumble, down, get up, death.
- **A boss:** about 15–20.
- **Every additional weapon type** (spear, hammer, guns) is a new full moveset of about 15 clips.

**Cheap approaches, in the order I'd use them:**
1. **Timing in data, animation as decoration.** Gameplay never waits on a clip. A missing clip falls back to a procedural version (the model contract already does this for jump/fall/land). Rough animations never break the game, and outside artists can deliver late.
2. **Key-pose attacks.** Each attack is 2–3 strong poses (wind-up, strike, follow-through) that snap with no in-betweens, at the style guide's 15 fps stepped. PSX-era action games were built this way, and anime "limited animation" sells it too. A sword trail and one smear frame fill in the motion. About 70 poses for Red instead of 25 full clips.
3. **Procedural layers in code:** lunges and steps are root motion in code; spins, flips and tumbles rotate the whole model; squash on land and recoil on hit (combatant_view already has these); a lean into running; Godot's `SkeletonModifier3D` for small code-driven bone tweaks such as aiming the head at the lock-on target.
4. **Enemies mostly in code.** Hit, launch, tumble, down and death are procedural (they already are, in the battle stage). Each enemy needs about 3–4 authored poses: idle, wind-up, strike, and optionally a get-up.
5. **Shared skeleton.** Humanoid enemies share Red's bones, so a clip can be copied and tweaked across characters, as the style guide already plans.
6. **Retargeting (technically possible; not a recommendation now).** Godot 4 can remap clips from another skeleton at import (`BoneMap` + `SkeletonProfile`). Realistic motion capture on chibi proportions with a rigid 17-bone rig reads floaty and wrong, so at best it's rough blocking to key over. Using bought or stock animation is also an art-pipeline question Ross parked in F46 ("keep the art in house for now"), so I'm not raising it.
7. **One weapon moveset for the slice.** New swords change the look, not the moves.

**What this means for Ross's time (rough):** with key poses and procedural reactions, Red's action set is about the size of the turn-based Wave 1 + Wave 2 list (about 17 clips) the style guide already planned. With full, smooth clips it would be roughly 3 times that. The PS2 upgrade raises the cost of each pose (more bones, smoother joints; section 8.3).

---

## 4. Buildability tiers

### Week-one prototype (low risk)
- The action controller (run, jump with coyote time, dash, air-dash, i-frames), an orbit camera with basic lock-on, a 3-hit light string with hit-stop, and one dummy that reacts and can die, in a grey arena with tests.
- Code size: about a third of the old Milestone 2 battle system. Placeholder Red with procedural attacks (no new clips).

### Vertical slice (medium risk; art is the pacing item)
- One living town (Harrow, re-using the rooms, NPCs, shops and dialogue), one dungeon built for the free camera (re-using the works puzzles), 3–4 enemy types, one boss with a phase change, gear swaps (2–3 swords, a helmet and one armor piece visible), materials and currency drops, a crafting/upgrade counter, a town beat that unlocks the next gate, save/load, and the PS2 rendering switch.
- Code: about the sandbox plus 3–5 build sessions. Calendar time is set by Ross's art and animation, and by feel rounds.

### Risky (keep on the Later list unless Ross asks)
- **DMC-depth combat:** style switching, many weapon types with mid-combo swapping, jump-cancel tech, enemy step. Each weapon type is a full moveset of animation.
- **Deep character customization:** a body or face creator conflicts with Red as the locked hero (F43); gear, colors and swords are the affordable version.
- **Large hordes** of 30 or more smart enemies on screen; physics ragdolls; giant multi-part bosses fought with a free camera.
- **Late-PS2 detail** across the whole cast while also adding action animation.
- **Free camera in every cramped interior** (camera collision trouble), and procedural dungeons.

---

## 5. Default controls for the sandbox (studio proposal, to be overturned in hand)

| Action | Pad | Keyboard |
|---|---|---|
| Move / camera | left stick / right stick | WASD / mouse |
| Jump | A (Cross) | Space |
| Light / heavy | X (Square) / Y (Triangle) | J / K (or mouse buttons) |
| Dash | B (Circle) | Shift |
| Parry | LB (L1) | L |
| Lock-on | RB (R1) | Tab / middle mouse |

Run becomes the default with the stick (analog walk), since dash covers the burst. Ross's earlier "run button" (F37) was for exploration and still applies in towns if he wants it. All bindings go through the existing input_remap.

---

## 6. Feel-prototype plan: the Combat Sandbox

**Goal:** Ross downloads one build, starts in an arena within seconds, and judges whether this plays "really fun", with speed and power, by hand. Same repository and foundation; a separate export preset boots straight into the sandbox (Godot project-setting override by custom feature tag), so the Lights Left On build stays untouched.

**Scope (exactly the brief):** free camera + lock-on; run, jump, dash, air-dash; 3-hit light string, heavy, launcher, air combo; parry; two enemy types (**Grunt**: light, launchable, slow parryable swipe, dies in about 5 hits; **Brute**: poise and super armor, a big telegraphed slam to parry or dash through); hit-stop and screen shake; a sword rack with two swords that visibly change in Red's hand. Plus three helpers: a camera toggle to the "action diorama" (Decision 2, Option C), a launcher-input toggle (3.3), and a **feel knobs** panel (F1) with live sliders for dash distance, jump height, gravity, juggle float, hit-stop length and shake, which writes the chosen values to a file Ross can send back.

### Files and owners

| Owner | Files (all new unless noted) |
|---|---|
| Technical Director | This plan; the move-data format and combat API contract (`docs/pivot/combat_api.md`, written once approved); code review of every piece. |
| Gameplay Programmer | `scripts/combat/action_player.gd` (state machine over PlayerMotion: move, jump, dash, air-dash, attack, hurt), `scripts/camera/orbit_camera.gd`, `scripts/camera/lock_on_math.gd` (pure), `scenes/actors/action_player.tscn`, `scenes/sandbox/combat_sandbox.tscn` (arena, pillars, a ledge, the sword rack), `data/combat/player_action.json`, sandbox export preset. Edits: `project.godot` input map (dash, light, heavy, parry, lock_on, camera). |
| Battle Programmer (combat) | `scripts/combat/model/`: `move_runner.gd`, `input_buffer.gd`, `juggle_rules.gd`, `parry_judge.gd` (wraps ClutchJudge), `combat_clock.gd` (extends BattleClock), `hit_resolver.gd` (uses BattleDamage formulas), `style_meter.gd`, `attack_tokens.gd`, `enemy_brain.gd`; `scripts/combat/hitbox.gd`, `hurtbox.gd`, `hit_stop.gd`, `action_enemy.gd`; `data/combat/moves.json`, `enemies.json`, `hit_feel.json`, `style.json`; a `parry` entry in `data/battle/timing_windows.json`. |
| Technical Artist | Placeholder sword #2 and the Grunt/Brute blockouts in `art/placeholder/` (re-using the Signals grunt rig); 2–3 key poses per attack on placeholder Red (scripted Blender, kept cheap per F44); `scripts/combat/fx/sword_trail.gd`, `hit_spark.gd`; `scripts/combat/gear_visuals.gd` (BoneAttachment3D sword swap); screen shake ported to the orbit camera; jitter off for the free camera. |
| UI Programmer | `scripts/ui/sandbox/sandbox_hud.gd` (HP, style rank, lock-on reticle, parry rating pop-ups re-using battle_popup), `feel_panel.gd`, the controls card. |
| Audio Designer | Placeholder swing, hit, parry, dash and launch sounds through the existing SFX index. |
| QA Tester | `tests/unit/test_move_runner.gd`, `test_input_buffer.gd`, `test_juggle_rules.gd`, `test_parry_judge.gd`, `test_style_meter.gd`, `test_attack_tokens.gd`, `test_lock_on_math.gd`, `test_combat_data.gd`; `tests/integration/test_action_player.gd` (dash distance, i-frames, one air-dash per jump), `test_hit_flow.gd` (one hit per swing, hit-stop freezes both, knockback), `test_gear_visuals.gd` (swap changes the mesh on weapon_socket), `test_sandbox_smoke.gd`; a bot run: "launcher + 4 air hits keeps a Grunt airborne", "a parried Brute slam staggers". |
| Playtester | A feel pass before Ross gets it (does every move read, is anything mushy). |
| Producer | Task board rows, download link, short how-to-play, studio log entry with a short clip or screenshots. |

### Time estimate
- **Code:** about the size of Milestone 2 (the turn-based battle system: model, stage and HUD), which the studio took from plan to playable in one long session. Feel code (camera, cancels, juggles) is fussier than menu code, so I'm planning 2–3 build sessions including tests, QA and export.
- **Calendar:** first download about **2–4 days after the go-ahead**, then feel rounds with Ross (each usually a same-day turnaround). About a week including two rounds.

### What "done" looks like
- Ross opens the download on Windows or Mac and is in the arena in under 10 seconds, with a controls card on screen.
- With a pad or keyboard he can: launch a Grunt and keep it in the air for 5 or more hits; dash through a Brute slam (i-frames) and also parry one (stagger + slow-mo + rating pop-up); see hit-stop and shake on every hit; walk to the rack, swap swords and see the new one in Red's hand; lock on and switch targets; flip the camera to the action-diorama view.
- A steady 60 fps on an ordinary laptop.
- The feel knobs save a file he can send back.
- Every combat logic class has headless tests, the whole suite is green, and nothing in the Lights Left On build changed.

---

## 7. Risks and recommendations

1. **Art and animation load (highest).** Action needs about 4 times the animation of turn-based, and the PS2 upgrade raises the cost of each asset. *Mitigation:* timing in data, key poses, procedural reactions, one sword moveset, bolt-on gear, PS2 reached in two steps (Decision 3). Placeholders stand in until Ross's art arrives.
2. **Feel is judged in the hands and overturned in the hands** (F37, F50). *Mitigation:* the sandbox, the feel knobs, and toggles for the contested calls (camera style, launcher input). Treat every feel number as provisional until Ross has played it.
3. **Camera trouble** in tight rooms and crowds. *Mitigation:* the hybrid camera (Decision 2), and dungeon rooms built for the camera.
4. **Scope creep toward DMC depth.** *Mitigation:* the Risky tier stays on the Later list; one weapon type in the slice.
5. **Approved rules in the way:** "Armor never changes the model", the diorama-everywhere camera, "PSX-era" in CLAUDE.md, and the 17-bone rigid contract. *Mitigation:* none of these change until Ross approves the new direction; then each is updated as its own item (CLAUDE.md only by Ross).
6. **Testing real-time feel.** Logic is testable headless (and will be); "is it fun" isn't. *Mitigation:* bot combos for regressions, and Ross plus the Playtester for fun.
7. **Performance with many enemies on screen.** It's fine at our resolutions for about 12 active fighters plus cheaper extras; attack tokens limit how many think hard at once. Test on a low-end laptop early.
8. **Repository question (Producer):** the Playbook says each game gets its own repository (F10). The sandbox can live in this one for now; where the new game lives is a Producer item for Ross.

**Recommendations:** Decision 1 A (build the sandbox now), Decision 2 B (hybrid camera, with a toggle to try C), Decision 3 A reached in two steps (PS2 rendering on current models first, then detail). Keep the Compatibility renderer.

---

## 8. PS1 → PS2 look upgrade

> Ross, 2026-10-08: "we can kind of keep the same characters and world but the psx look needs a upgrade to ps2"

### 8.1 Visual targets (proposed; confirmed by a look test on our own models)

| Area | Today (PSX) | Proposed PS2 target | Why it matters for the game |
|---|---|---|---|
| Internal resolution | 384×216, nearest scale-up | **640×360** (16:9, close to PS2's 640×448), scaled up 2× to 720p, 3× to 1080p, 6× to 4K. Option in Config: native resolution. | Keeps a soft retro picture and our existing pipeline, and scales cleanly on every screen. |
| Scale-up filter | nearest (chunky pixels) | Smooth (bilinear) by default; "sharp pixels" as an option | PS2 output was soft; chunky pixels read as PS1. |
| Hero triangles | 884 (body 840 + sword 44), 17 bones, rigid | **~3,000 target / 5,000 cap** (early PS2); late-PS2 option 5–6k | Enough for real hands, a shaped face and gear that reads. |
| Other models | enemies 300–600, NPCs 350–800 | fodder 1,000–1,500, elites 2,000–2,500, NPCs 1,200–2,000, bosses 8–15k, swords 300–600, gear bolt-ons 200–500 each | Crowds stay affordable; the hero and bosses get the detail. |
| Textures | 64–256 px, nearest, no mipmaps, 15-bit | **hero 512×512 body + 256×256 face; enemies and NPCs 256; environment 256–512 tiling**; smooth filtering with mipmaps | Painted detail and no shimmer on distant floors. |
| Vertex jitter / affine warp | on (1 px snap, warp on characters and props) | **Off by default.** Kept as a "Retro" Config option at low strength (the switches already exist). | A free camera plus jitter makes the whole world shimmer; PS2 had neither. |
| Color depth / dither | 15-bit + 4×4 Bayer | Full color; a faint dither only against banding in dark gradients | PS2 had full-color output. |
| Lighting | per-vertex (Gouraud), no real-time shadows, blob shadows | **Per-pixel lighting; one shadow-casting key light per area** (sun or a strong lamp) plus a few non-shadow lamps; a real shadow on Red, blob shadows on crowds; baked vertex color or lightmaps for dungeons (lightmap support in Compatibility to be verified) | Moody grim lighting with real shadows is the biggest single "this is PS2" signal. |
| Fog | stepped, 4 bands | Smooth distance fog in the grim haze colors | Hides draw distance for the free camera. |
| Glow / bloom | none (additive sprites) | **Environment glow** on lamps, neon, the call's teal, parry flashes | Sells lamps in the grim dark and makes hits pop. |
| Depth of field | none | **Our own depth-of-field post shader** for cutscenes, menus and boss intros (Godot's built-in DOF is not available in Compatibility) | Cinematic shots (your storyboards) without changing renderer. |
| Motion blur and trails | none | **Sword trails** (ribbon meshes from blade tip to base); a cheap frame-blend blur and radial blur on dashes and big hits (a PS2-era trick) | The "speed" half of the brief, made visible. |
| Grim grade | psx_post grade (desat, crush, tint, grain, vignette) from look_profiles.json | **Kept as is**, run before any final effects | Ross approved the grim look; it carries forward. |
| Edge light | banded fresnel rim in psx_lit, per character from data | **Kept**, ported to the per-pixel shader; smoother bands, still "not too bright" | Ross's readability rule (F56) carries forward. |
| Portraits | 96×96 pixel art | Later question: higher-resolution anime portraits fit PS2 better | Not urgent; flagged for when the look is set. |

### 8.2 Mapping: shaders and look profiles

| Today | Fate | PS2 version |
|---|---|---|
| `psx_common.gdshaderinc` (snap, affine, stepped fog, global switches) | Keep the file and the switches; snap and affine default to 0 | Becomes `look_common`: an optional retro wobble, smooth fog, shared rim code |
| `psx_lit.gdshader` (vertex lighting, rim) | Replace | `ps2_lit`: per-pixel diffuse, an optional soft specular for metal and wet floors, receives shadows, banded edge light kept |
| `psx_unlit.gdshader` | Keep (drop the snap) | Emissive surfaces feed the bloom |
| `psx_fade.gdshader` (dithered screen-door fade) | Keep | The same trick on the ps2_lit base; PS2 games did this too |
| `psx_post.gdshader` (grade + 15-bit + Bayer) | Split | Grade kept; 15-bit and Bayer retired (optional); add frame-blend blur, DOF (reads the depth texture), vignette and grain kept |
| `psx_cel` / `psx_outline` (Red prototype D) | Retire | Kept in history in case Ross ever wants an inked look |
| `screen_static.gdshader` | Retire with encounter transitions | Could return as a story effect |
| `PsxScreen` (SubViewport + scale-up + sharp UI) | Keep | Set to 640×360 with a smooth filter option |
| `PsxLook` + debug overlay toggles | Keep | Toggles become shadows, glow, DOF, blur, retro wobble |
| `psx_post_import.gd` (glTF import → PSX materials, nearest, loops) | Adapt | Assigns ps2 materials, smooth filtering and mipmaps; keeps the loop flags and the `_unlit` naming rule |
| Project importer defaults (lossless, no mipmaps) | Change | Mipmaps on; lossless for small textures, VRAM-compressed for big environment sheets |
| `look_profiles.json` (grade, post, lighting, fog, materials, grime, dressing, characters, models, backdrop, player_lamp) | Keep the structure | Add `shadows`, `glow`, `dof`, `motion_blur`, `texture_filter`, `retro_wobble`. Retire the "classic" profile (bright toy look, superseded) once Ross agrees. |
| Grime paint and grim dressing (64 px procedural grime, cheap kit) | Keep as blockout | Grime textures re-made at 256–512 px; the kit stays for layouts |
| Tests: test_psx_shaders, test_psx_materials, test_art_limits, test_red_shiba | Update | New budgets and shader names; same checks |

**Renderer: an honest recommendation.**
What I tested in our cloud container today (Godot 4.5.1, software OpenGL under xvfb, rendering the same small scene with each feature off and then on):

| Feature | Compatibility (our renderer) | Forward+ / Mobile |
|---|---|---|
| Real-time shadows (sun) | **Works** (seen in the test image) | Works |
| Glow / bloom | **Works** (seen in the test image) | Works |
| Tonemapping, color adjustments | **Works** | Works |
| Reading the depth buffer in our own shaders (custom DOF, fog tricks) | **Works** | Works |
| Built-in depth of field | Not available (engine warning) | Works |
| SSAO (soft contact shadows) | Not available | Forward+ only |
| Volumetric fog | Not available | Forward+ only |
| Cloud screenshots in our container | **Yes** | **No.** The container has no Vulkan driver, so Godot silently falls back to Compatibility. A software Vulkan driver (`mesa-vulkan-drivers`) is in the package list but not installed; installing it in the session setup would be a configuration change for Ross to approve, and software Vulkan is slow. |

**Recommendation: stay on Compatibility.** Everything on the PS2 list either works natively (shadows, glow, grade, tonemap) or is a custom shader we would write anyway (DOF, motion blur, trails). The things we'd lose (SSAO, volumetric fog, global illumination) are later-generation effects that PS2 games didn't have. Compatibility also keeps the wide hardware support and the cloud screenshots Ross approved it for. Switch to Forward+ only if a specific look Ross wants needs it; the switch is a project setting, and our shaders would need small edits.

### 8.3 Costs (Ross is the only artist and may outsource later)

- **Per character model:** about 3–4 times the modeling of today's placeholder at early PS2 (Option A), about 5–8 times at late PS2 (Option B). Texture painting is the biggest jump: 128×128 to 512×512 is 16 times the pixels.
- **Rig:** at 3,000 or more triangles, rigid skinning (each vertex on one bone) shows cracks at elbows, shoulders and knees. PS2-style models need **smooth skinning (weight painting)** and more bones: about 25–35, adding neck, hands (1–2 bones each for mitten hands), feet, a jaw if wanted, and sockets: `weapon_socket`, `prop_socket`, plus new `head_gear` and `back` (for a sheathed sword). Keep the 17 current names as a subset, so existing clips and tests keep working.
- **Animation:** smooth PS2 models at 30–60 fps show every rough in-between, so cheap animation is harder to hide. The way out, which also fits the anime portraits: keep **15 fps stepped "on twos" timing as a deliberate style** with key-pose attacks, rather than smooth interpolation. That's a feel call for Ross once he sees it.
- **Gear:** helmets, gauntlets, boots, pauldrons and swords stay cheap bolt-ons on one bone. Chest armor and coats on a smooth-skinned body need weight painting for each piece (or rigid plates), so visible body armor costs more under PS2 than under PS1.
- **Environments:** dungeons for a free camera need four walls and more surface detail at 256–512 px. Modular kits (wall, floor, trim, door, prop sets) are what keep that sane, the same approach as the style guide's current kits, scaled up.
- **The model contract needs a rewrite** for PS2 (bone list and weights, max 4 bone influences per vertex, sockets, gear attach rules, texture sizes, the ~25-clip action list, timings in data). It's also the document that makes outsourcing possible later if Ross ever chooses it; the studio won't raise outsourcing until he does (F46).

### 8.4 Characters and world: what survives

**Survives untouched:** the Lights Left On cast, names and world (the story bible is the Creative Director's call); Red as the playable hero, with her locked design language (bean head, short wide-set pointy shiba ears, jacket, sword, big curled tail, grim proportions); Harrow and the other locations, layout maps, rooms.json and spawns, all dialogue, NPC placements, shops and item data, palettes and the grim direction, the edge-light rule, and the gibberish voices. Ross's new A-pose reference sheets (docs/art_reference/, requested 2026-10-08) are exactly the starting point for PS2-detail models.

**Survives as stand-ins:** every current .glb (Red's 884-triangle grim shiba, the cast, NPC and enemy blockouts, their six clips) keeps working in the sandbox and the slice until final models replace them, through the same model-path seam. The town diorama rooms survive under the hybrid camera, upgraded by the new shaders (lighting, glow, smooth textures); their grime and textures get re-done at higher resolution over time.

**Doesn't survive as is:** the 17-bone rigid rig (extended, not thrown away); the PSX art budgets and texture sizes; the PSX rendering rules section of the style guide; the 64–256 px grime textures; rooms used as free-camera dungeons (the current tower/works rooms are floor-plus-two-walls dioramas and need rebuilding as full spaces); the classic look profile; the 96×96 portraits (an open later question).
