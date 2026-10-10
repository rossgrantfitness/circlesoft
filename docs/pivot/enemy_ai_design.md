# Enemy AI design (Combat Sandbox)

> **For Ross:** this is how the enemies think. Ross asked (2026-10-08) for enemies that attack, react to being hit, dodge, block, telegraph, reposition, run away and try to flank when hurt. All of it is numbers and enemy behaviour; **nothing changes what Red's buttons do.** Every number is a starting guess in `game/data/combat/enemies.json` (the `behaviour` block of each enemy) and `moves.json`; eleven difficulty sliders in the feel panel (group "Enemies") let you tune it by playing.
> **Numbers moved on 2026-10-09:** the tables below are the first design values. The shipped numbers were retuned toward Kingdom Hearts (about half the dodging and blocking, slower wind-ups, softer enemy hits, milder flee and flank). See `docs/pivot/tuning_log.md` for what each one is now.
> Owner: Combat Designer. Builder: Combat Programmer. Contract: `combat_api.md` 3, 4.2, 4.3, 4.6. Status: design for the sandbox, not yet built.

## 1. The shape of a fight

- Enemies **circle** at a distance and take turns attacking (attack tokens, max 2 at once).
- Every attack **telegraphs** and can be parried. Nothing is a surprise hit.
- Enemies **defend** only against a swing that would actually hit them, never every swing, and each defence has a **price** (a recovery you can punish, or a guard you can break).
- A tight Light string **locks them in** (they can't defend while in hit-stun). Defence only matters when Red opens with a slow move (Heavy, Launcher) or leaves a gap. That makes Light = safe pressure, Heavy and Launcher = a read.
- Wounded enemies change plan (Cyberwolf: flee or flank; Brute: enrage), so the end of a fight isn't the same as the start.

## 2. States and transitions

Existing states stay: idle, notice, approach, circle, attack, recover, react, dead. New ones are marked **new**. Times are the enemy's own combat time (they slow in a Lamp Flare).

| State | Enters when | Leaves when |
|---|---|---|
| idle, notice, approach | as today | as today. Notice time shortens to 150 ms if an ally nearby was hit or died (section 7) |
| circle | as today. Strafes around Red in the ring, flips direction every 1.5 to 3.2 s | wants a token (attack interval), a defence roll succeeds, a swing hits it, low health |
| **defend: dodge** (new) | Red's swing threatens it and the defence roll picks dodge | move ends, then back to circle (or a counter, below) |
| **defend: block** (new) | the roll picks block | guard drops, guard breaks, or max hold time |
| attack | has a token (as today) | move finished (to recover) or it gets hit (to react) |
| recover | as today. Grunt may then **retreat** (hit and fade) | 450 ms (Grunt) or 700 ms (Brute) |
| **reposition** (new) | crowded, Red mid-combo, keep-away, retreat after attack | back in the ring |
| react | hit, launched, parried, staggered (hit reactions, section 7) | body is free plus 250 ms |
| **flee / flank / enrage** (new) | health under the threshold (section 5) | see section 5 |
| dead | hp 0 | respawn as today |

### 2.1 The defence roll (one per Red swing)

When Red starts a swing, each enemy **inside that swing's threat zone** (the same zone test the Lamp Flare uses: the attack's hitboxes grown by `threat_margin_m`) rolls **once**, after its reaction time. Enemies outside the zone don't roll.

1. **Can it defend?** No if any of these is true: it is mid-attack (wind-up locked in, so a parry still wins the trade), in hit-stun, staggered, launched, down or getting up, in its own dodge recovery or block cooldown, **or a Lamp Flare is running** (caught in the glare).
2. **Chance** = (`dodge_chance` + `block_chance`) x `read_weight` of Red's move x (1 - fatigue) x the feel-panel scale. One random number picks dodge, block or nothing.
3. **Fatigue:** each successful defence adds 0.4 fatigue (Grunt) or 0.35 (Brute); it fades over 4 s or 5 s. Two defences in a row leave roughly half the chance, so no one defends everything.
4. **Cooldowns:** Grunt dodge 2.5 s, Grunt block 1.8 s, Brute block 1.5 s (counted from the end of the defence).
5. **Reaction time:** the roll's result starts after `reaction_ms` (Grunt 80 to 150, Brute 160 to 260). Red's Light 1 lands at 90 ms, so **the first Light always connects**; a Heavy (impact 200 ms) is always dodged when the roll succeeds; the Launcher (160 ms) about half the time.

Red's move class (`read_weight`): Light, Heavy, Launcher, Air = Grunt 0.6 / 1.0 / 0.8 / 0.4, Brute 1.0 / 0.5 / 0.4 / 0.6. The Grunt reads the slow moves; the Brute guards against fast ones and doesn't bother with moves he knows break guard.

**Effective numbers at the start (no fatigue):**

| Red's move | Grunt dodges | Grunt blocks | Brute blocks |
|---|---|---|---|
| Light | 18% | 5% | 45% |
| Heavy | 30% | 8% | 23% |
| Launcher | 24% | 6% | 18% |
| Air hit | 12% | 3% | 27% |

**Combo escape (Grunt):** if Red has hit it 3 times within 2.5 s and the hit-stun has ended (she left a gap), it has a 50% chance to dodge out. Keep the string tight and it can't leave.

**Dodge counter (Grunt):** after a dodge, 25% of the time it takes the next attack token at once and swipes (full wind-up, so you can parry it). The other 75% it returns to circling.

## 3. The two enemy types

| | **Grunt (Cyberwolf Sentinel)** | **Brute** |
|---|---|---|
| Feel | Agile, annoying, goes down fast | Heavy, patient, big |
| Dodge | 30% base. Side-step (70%) or back-roll (30%, if Red is closer than 1.6 m). 2.4 m, **invulnerable for 220 ms**, 300 ms recovery | none |
| Block | 8% base, tiny guard | 45% base, big guard |
| Spacing | Ring 3.2 to 5 m, retreats after attacking (50%), keeps away from a charging Red (35%), backs off when 2 or more enemies crowd Red or Red is 2 hits into a string | Ring 4.5 to 6.5 m, **stands his ground** (never backs off, never retreats) |
| Reacts to a hit | Flinches (any hit interrupts its wind-up). 15% chance to hit back right after a flinch. 25% chance to **roll away** when getting up from a knockdown | Armored: no flinch. 35% chance to answer with a slam if Red is within 2.6 m of him |
| Low health | Under **40%** hp: **flee or flank** | Under **35%** hp: **enrage**. **Never flees** |
| Attacks | `swipe` (560 ms wind-up), `swipe_flank` (710 ms) | `slam` (900 ms wind-up, super armor) |

## 4. Telegraph rules (every attack is parryable)

1. **Three signals on the same frame:** a clear wind-up **pose** (the Grunt rears back with the blade high; the Brute lifts both fists), the **`combat_enemy_telegraph` sound**, and a **wind-up flash** in the enemy's colour (Grunt red, Brute orange) pulsing at 8 times a second, growing brighter toward impact. The flash and sound start at the move's `telegraph_ms` (0, the start of the wind-up).
2. **Minimum wind-up: 500 ms** from telegraph to impact for any attack (Grunt 560, Brute 900 today). **Attacks from behind Red get 650 ms or more** (the Grunt's `swipe_flank` is 710), because she can't see them coming. The feel slider "Attack wind-up length" can only make them longer than the data, never shorter than these floors.
3. **Aim locks at least 150 ms before impact** (Grunt locks at 380 ms of 560, Brute at 600 of 900), so a sidestep or dash works.
4. **Defending is not telegraphed with sound**, but a Grunt dodge shows a 40 ms cyan blink in its edge light first. A sharp player can read it, so baiting a dodge is a real skill: swing a Heavy, see the blink, cancel into a dash behind it. (Red's cancels already exist; this adds no new button.)
5. **A defence never cancels a wind-up.** Once an attack's telegraph has played, the enemy is committed. Parry or dodge always has a fair answer.
6. Test the data: every enemy attack must have `impact_ms - telegraph_ms >= min_windup_ms` (values in `enemies.json` `telegraph_rules`).

## 5. Tokens, flanking and fleeing

Tokens are unchanged (max 2 attackers, longest-waiting first). New rules in `enemies.json` `token_rules`:

- **Defending and fleeing enemies hold no token.** A fleeing enemy gives its token and queue place back at once.
- **Impacts at least 450 ms apart.** If two enemies would both hit within 450 ms of each other, the later one waits. Red can always parry both.
- **Only one enemy may attack from Red's rear arc** (the 120 degrees behind her) at a time (`max_rear_attackers` 1).
- **A flanker queues with a bonus** (it counts as waiting 1.5 s longer), so the plan pays off, but it still uses one of the 2 tokens. The other token is a front attacker, so you get the pincer (one in front, one behind) but never three on you.
- **Flank flow:** run round to Red's back (arc 135 to 225 degrees behind her, radius 3.6 m, 1.3 x speed, in a low stalking crouch so you can see it) -> **hold 600 ms in position** (the warning: a pause and a face-turn, enough time to spin and hit it first) -> ask for a token -> `swipe_flank` (710 ms wind-up with the usual sound and flash). Gives up after 3.5 s. Only 1 flanker at a time.
- **Flee flow:** under 40% hp (Grunt), roll once: **alone 70% flee / 30% flank; with 2 or more allies within 8 m, 30% flee / 70% flank.** Each ally that died in the last 6 s adds 8% to the hp threshold (up to +16%). Fleeing: runs away at 4.6 m/s (Red runs at 6.0 and dashes 4 m, so Red can always catch it) until 9 m away or 3.5 s. Max 2 flees per life. After a flee it comes back "bold": no more fleeing for 6 s. **Cornered** for 0.6 s (a wall behind it), it turns and swipes (full wind-up).
- **Brute enrage flow:** under 35% hp, once: a 1.2 s roar (super armor, no damage, a poise break stops it), then for the rest of the fight: 1.25 x speed, waits 35% less between attacks, guards 60% less, slam damage x1.15, no poise regeneration, 50% chance to chain a second slam (full 900 ms wind-up each time, only the recovery between is shortened to 350 ms). The edge light goes hot orange-red.
- Wounded enemies still obey the min wind-up rules. Fleeing and flanking never add attackers, only change where they stand.

## 6. Guard and guard break

A raised guard covers the **front 150 degrees (Grunt) or 140 degrees (Brute)**. A hit from the side or behind ignores it, so dashing round is a real counter.

- **Block:** damage x0.25 (Grunt) or x0.15 (Brute), at least 1; no hit-stun; pushback x0.35 / x0.15; hit-stop halved. A blocked hit does **not** interrupt Red's string. New hit outcome name: `blocked` (spark `guard`, sound `combat_hit_light`).
- **Guard meter:** each blocked hit drains its poise damage (Light 1 and 2: 8, Light 3: 14, Heavy: 30, Launcher: 20). Grunt meter 24 (3 Lights break it), Brute 60 (about 7 Lights). It refills 12/s (Grunt) or 18/s (Brute) after 0.8 s or 1 s without being hit.
- **Guard break (opens the enemy up):** a hit breaks the guard **at once** if it is a Launcher or has poise damage of 20 (Grunt) or 30 (Brute) or more, which means Heavy always, and Launcher always. An empty meter breaks it too. Result: `block_break` stagger of 1.1 s (Grunt) or 1.3 s (Brute), armor off until it ends. **The route against a Brute is Light, Light, Heavy.**
- **Limits:** hold 350 to 550 ms (Grunt) or 600 to 1200 ms (Brute); guard drops 300 ms after the last threat; max 2 (Grunt) or 3 (Brute) blocks in a row, then the guard drops with a 160 ms (Grunt) or 220 ms (Brute) recovery. Brute: 45% chance after a successful block to counter with a slam (needs a token, full wind-up).

## 7. Hit reactions and noticing

Pick the reaction from the hit's data, strongest first:

| The hit | Reaction | Time | Clip |
|---|---|---|---|
| Kills | death | 700 ms | Death |
| `knockdown` (air 3 slam, Brute slam on Red) | knockdown, then get up | 900 ms down, 600 ms up | Knockback, then get-up |
| Launch speed above 0 | launched (juggle) | as juggle rules | Knockback, held in the air |
| Broke poise or a parry | stagger | 1100 ms (Grunt), 1300 ms (Brute) | Chest hit, slowed, held |
| Hit-stun above 400 ms (Light 3, Heavy) | heavy flinch, pushed back by the move's knockback | the hit's stun | Chest hit |
| Otherwise (Lights) | light flinch, turns to face Red in 120 ms | the hit's stun | Chest hit or Head hit, picked at random |
| Brute while armored | none (spark and edge light pulse only) | | |

Extra reactions: a Grunt knocked down has 25% to **roll away** instead of standing up (250 ms of invulnerability on every get-up so there's no infinite lock). Retaliation: after a flinch, Grunt 15% (Red within 2.1 m) / Brute 35% (Red within 2.6 m) take the next token and attack with the normal wind-up; once per 3.5 s.

**Nearby enemies notice and re-target:**
- When an enemy is hit or dies, every idle or waiting ally within **9 m (Grunt) or 10 m (Brute)** notices after 150 ms (350 ms for the Brute) instead of 450 ms.
- Allies turn to the new fight: when Red moves on from one enemy, the nearest unengaged enemy takes over as attacker candidate (token goes to the one waiting longest, flankers first).
- An ally dying near a Grunt raises its low-health threshold (section 5).
- Red is the only target; "re-targeting" means which enemy steps up next.

## 8. Repositioning

- **Ring and spacing:** waiting enemies hold 3.2 to 5 m (Grunt) or 4.5 to 6.5 m (Brute) from Red; they keep 1.6 m (Grunt) or 2.4 m (Brute) between each other, and spread over at least 70 degrees round Red (90 for Brutes), so enemies take the open side instead of stacking.
- **Back off when crowded:** if 2 enemies (Grunt) are already within 2.6 m of Red, an extra one without a token steps 1.2 m further out.
- **Back off when Red is mid-combo:** an enemy that isn't the target of a Red string 2 or more hits long stays 1.2 m outside the ring, out of the sword's way. This keeps Red's combo free of surprise hits and makes the enemy near her the focus.
- **Hit and fade:** after its own attack the Grunt retreats 2.0 m with 50% (backpedal, faces Red) instead of circling at once.
- **Keep away:** a Grunt without a token whose path Red is dashing along steps away 35% of the time, once per 3 s.
- The Brute does none of these. He walks forward and takes space.

## 9. What gives Red an opening

| Opening | How long | How Red uses it |
|---|---|---|
| **Guard break** | 1.1 s Grunt, 1.3 s Brute | A free Heavy or a Launcher. Reward for Light, Light, Heavy |
| **Dodge recovery** | 300 ms after a Grunt dodge, 2.4 m from where it stood | Dash then Light connects (Dash cancels into attack after 110 ms) |
| **Guard drop** | 160 to 220 ms after the Brute lowers his guard | Quick Light or a dash round to his flank |
| **Out of the guard arc** | always | Dash behind a blocker; the guard doesn't cover his back |
| **Fleeing enemy** | up to 3.5 s | Red out-runs it (6.0 vs 4.6 m/s). A hit while it flees is always a **knockdown** |
| **Flanker's 600 ms hold** | 600 ms | Turn and strike it first |
| **Enemy attack recovery** | 560 ms Grunt, 850 ms Brute (as today) | Parry or dodge, then punish |
| **Defence fatigue** | 4 to 5 s after two defences | The enemy mostly can't defend, so go for a Launcher |
| **Brute roar** | 1.2 s once | Super armor protects him, but a poise break cancels it |

Suggestion for the Style meter (Noise) owner: small bonuses for punishing a dodge recovery, breaking a guard and running down a fleeing enemy (`punish`, `guard_break`, `run_down`). Numbers are theirs.

## 10. Difficulty knobs (feel panel, group "Enemies")

| Knob | Default | Range | What it does |
|---|---|---|---|
| Enemy aggression | 1.0 | 0.25 to 2.0 | Divides the pause between attacks |
| Enemies attacking at once | 2 | 1 to 4 | The token cap |
| Enemy reaction time | 1.0 | 0.5 to 2.0 | Multiplies `reaction_ms` (higher = slower to read Red) |
| Attack wind-up length | 1.0 | 0.8 to 2.0 | Multiplies wind-ups, floored at the 500/650 ms minimum |
| Enemy dodging | 1.0 | 0 to 2.0 | Multiplies dodge chance. 0 = off |
| Enemy blocking | 1.0 | 0 to 2.0 | Multiplies block chance. 0 = off |
| Enemy spacing | 1.0 | 0.6 to 1.6 | Ring radius and separation |
| Enemy health | 1.0 | 0.5 to 3.0 | Multiplies every enemy's hp |
| Wounded enemies flee | On | | Off removes fleeing |
| Wounded enemies flank | On | | Off removes flanking |
| Brute enrage | On | | Off removes enrage |

`enemies_attack` (Arena group, already there) still turns all attacking off. The data numbers (chances, cooldowns) stay in `enemies.json`; the sliders scale them.

## 11. Animation names

Wolf clip names are the roles the Animator makes; each is mapped to a free Quaternius clip (README in `game/art/placeholder/animations/quaternius_ual/`; UAL1 = `UAL1_Standard.glb`, UAL2 = `UAL2_Standard.glb`). They are also written per enemy in `enemies.json` `behaviour.clips`. Timing always comes from `moves.json`, never from the clip.

| Behaviour | Wolf clip | Quaternius clip | Note |
|---|---|---|---|
| Idle | `idle` | Idle_Loop (UAL1) | Brute: Zombie_Idle_Loop |
| Notice | `notice` | Sword_Idle (UAL1) | Brute: first half of Zombie_Scratch |
| Walk, strafe | `walk` | Walk_Loop (UAL1) | Brute: Zombie_Walk_Fwd_Loop, 0.8 x |
| Approach | `run` | Jog_Fwd_Loop (UAL1) | Brute: Zombie_Walk_Fwd_Loop, 1.3 x |
| Retreat | `retreat` | Jog_Fwd_Loop, played in reverse | Brute: Zombie_Walk_Fwd_Loop reversed |
| Flee | `flee` | Sprint_Loop (UAL1) | Grunt only |
| Flank | `stalk` | Crouch_Fwd_Loop (UAL1), 1.4 x | Grunt only; low and sneaky so it reads |
| Dodge, side | `dodge_side` | Sword_Dash (UAL2) | |
| Dodge, back and get-up roll | `dodge_back` | Roll (UAL1) | |
| Block start | `block_start` | Sword_Block (UAL2), first 0.3 s | |
| Block hold | `block_hold` | Idle_Shield_Loop (UAL2) | |
| Block impact | `block_impact` | Shield_OneShot (UAL2) | A small shudder on a blocked hit |
| Guard break | `block_break` | Idle_Shield_Break (UAL2) | |
| Light flinch | `hurt` and `hurt_head` | Hit_Chest and Hit_Head (UAL1) | Random pick |
| Heavy stagger | `stagger` | Hit_Chest slowed to 0.6 x (0.5 x Brute), held at the end | |
| Launched, knockdown | `launched`, `knockdown` | Hit_Knockback (UAL2); hold the airborne pose then play the landing half | |
| Get up | `getup` | LayToIdle (UAL2) | Brute at 0.8 x |
| Death | `death` | Death01 (UAL1) | |
| Brute wind-up | `slam` | Sword_Heavy_Combo (UAL2), first swing, held at the top | |
| Brute enrage | `enrage` | Zombie_Scratch (UAL2), arms thrashing | |
| Grunt attacks | `attack_windup`, `attack_swing` | the existing wolf clips | Unchanged |

## 12. Files and what the Combat Programmer needs to build

Data (done, this pass): `game/data/combat/enemies.json` (`behaviour` per enemy, `token_rules`, `telegraph_rules`), `moves.json` (Grunt: `dodge`, `getup_roll`, `block_start`, `block_hold`, `block_break`, `strafe`, `retreat`, `flee`, `swipe_flank`; Brute: `block_start`, `block_hold`, `block_break`, `strafe`, `retreat`, `enrage`), `feel.json` (11 knobs).

New data fields the code must learn (none read today, so the game plays exactly as before until they are built): `behaviour.*`; move fields `iframes`, `guard`, `punish`, `tell`, `kind` (reaction or locomotion), `loop`, `hold_max_ms`, `speed_mps`, `reverse`, `motion.travel_m` and `motion.direction` (the brain picks side or back).

New `view` fields for the brain: `player_move_class` (light, heavy, launcher, air), `player_swing_threat` (this enemy is in the threat zone), `player_combo_len`, `hp_frac`, `allies_near` and `crowd_count`, `player_facing_dot`, `player_dashing_toward`. New `HitResolver` outcome: `blocked`, with `guard_break`. Everything lives in the existing `EnemyBrain` (pure) and `ActionEnemy`; no change to Red.

Note for QA: the real `moves.json` has no test that every move has the fields the new states use; suggest adding one (windup minimum, iframes inside the move, `guard` inside the move).
