# Combat sandbox: feel pass (CS-19)

> By the Playtester, 2026-10-09. Not played by a human: the numbers come from the data files, a read of the code, the headless bot sim (`sim/test_enemy_ai_bots.gd`, 5 of 5 pass) and two scripted runs of a naive Red. **Ross still has to play it for feel.** Every knob value below is a starting guess to try in the F12 panel. Items marked DATA are moves.json or player_action.json edits, not panel knobs.

## Top 5

1. **Parry is judged on the wrong time (fix before send).** The parry is rated on when the parry *starts*, not when the button was pressed. A parry pressed during a light attack waits for the cancel window (up to 150 ms) and is stamped late. The 70 to 130 ms windows are the whole game, so this matters. Code: `action_player.gd` `_on_move_began` (`report_parry_press(clock.real_now_usec())`). Owner: Gameplay and Battle.
2. **Juggles float too high.** A plain launcher lifts a Grunt about 6 m for 1.5 s at `juggle_float` 1.0 (from the constants; the game's own 2.3 m apex is only without float). Try `juggle_float` **0.5** and `launch_height_scale` **0.7**: launch about 2.7 m, a six-hit juggle about 3.8 m.
3. **The perfect dodge is almost any dodge.** A dash covers the telegraph for 150 ms before impact, and the perfect window is 120 ms of that, so about 80% of good dodges count as perfect. Try `perfect_dodge_window_ms` **70**. Keep `dash_iframes_ms` at 150 or more, or a perfect dodge can get hit.
4. **Parry recovery is long and an early press is a trap.** A parry press locks Red for 480 ms (cancel only at 260 ms). The first press in the 400 ms listen window is judged even when it is outside the 220 ms nice window, so a press 300 ms early is a miss and the real press later is ignored. DATA: `moves.json` red `parry.recovery_ms` 280 to 150, and check the early-press feel by hand.
5. **Sprint foot-slide: yes, raise the clamp.** Run clip stride is 2.52 m. At 6.0 m/s it needs 2.38x, but it is capped at 2.0x, so the feet move 5.0 m/s and slide about 16% (Ross saw about 20%). DATA: `player_action.json` `anim.playback_scale_max` **2.4** closes it at full speed. Legs cycle about 20% faster when sprinting.

## Other findings

- **Brute, unclear.** A naive Red (one button at a time, no parry or dodge) killed him in 28 s and took 5 slams. The guard rose on only 9 of 65 light hits, against the design's 45%. The bot stood at ring range, probably outside the threat zone, so this may be a bot artifact. Check in melee range. If he never guards, try `enemy_block_scale` **1.5**. If he dies in under 30 s in hands, consider Brute HP 220 to 300 (DATA).
- **Dash exit snaps.** The dash slows from about 16 m/s to 3.6 m/s in one frame (default `end_speed_mult` 0.6, not in the data). Try 1.0 (DATA, add to `player_action.json` dash block) and see if it still reads as a stop.
- **Dodge tell is too short.** The Grunt's cyan dodge flash is 40 ms, about 2 frames at 60 fps. DATA: `moves.json` grunt `dodge.tell.to_ms` **100**.
- **Air string floats.** air_1 and air_2 hang 300 ms each. DATA: `hang_ms` **150**.
- **Heavy is not more damage.** From the data, the light string does about 35 damage per second and the heavy about 33. Heavy reads heavier through knockback (1.6 m vs 0.5), hit-stun (480 vs 320 ms) and shake. If it should feel like power, DATA: heavy damage 22 to **28**.
- **Wolves.** Light dodge rate (18%) is fine. On heavies, 1 dodge in 12 in the bot run (design about 30%): slightly passive, probably a small sample. Try `enemy_dodge_scale` **1.3** only if Ross wants them to read heavies.
- **Five enemies.** Bot-run hits from different enemies never came closer than 482 ms (the rule is 450). Token spacing is fair. A naive Red took about 530 damage in 120 s (about four deaths). Slams made up 280 of that. For the first run, `enemy_damage_scale` **0.8** if Ross wants to get to the fight.
- **Fleeing and flanking** are not cheap. A fleeing wolf takes a knockdown, and a flank swing has a 710 ms wind-up and is parryable.
- **Walk clip** slides about 30% between 0.76 and 1.1 m/s (the walk clip is capped at 2.0x). Minor.

## Blockers

- **Only #1 blocks the send.** It is a logic error, not a number. The rest can go out as they are.
- Uncommitted change in `game/scripts/combat/fx/combat_fx.gd` in the working tree (not mine). Check it is in the build.

Not verified: all timing numbers, the juggle heights, the parry feel, the Brute and pack numbers. Those need a human at 60 fps. Probe scripts are in the scratchpad (not in the repo).
