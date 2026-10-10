# Slice graybox build (build 4): how to get it and play it

> For Ross, 2026-10-10. The whole vertical slice in grey blocks: town → junkyard → loader → boss → robot round. Placeholder everything (shapes, words, sounds); you're judging **feel, layout and pacing**.

## Getting it onto your Mac (6 parts)

1. Download all six parts into your **Downloads** folder: `Slice4-Mac.zip.part0` to `Slice4-Mac.zip.part5`.
2. Open **Terminal** (⌘ + Space, type *Terminal*, Return).
3. Paste this whole line and press Return:

   ```
   cd ~/Downloads && cat Slice4-Mac.zip.part0 Slice4-Mac.zip.part1 Slice4-Mac.zip.part2 Slice4-Mac.zip.part3 Slice4-Mac.zip.part4 Slice4-Mac.zip.part5 > Slice4-Mac.zip && open Slice4-Mac.zip
   ```

4. That unzips **Circlesoft Slice** into Downloads. Double-click it. The first time, macOS blocks it: go to System Settings → Privacy & Security → **Open Anyway**.

(Opening the project in the Godot editor works too: Play now starts the slice.)

## Controls

| | Keyboard / mouse | Controller |
|---|---|---|
| Move / camera | WASD, mouse | Left stick, right stick |
| Attack (and talk) | J / left click | X / Square |
| Hack | K / right click | Y / Triangle |
| Dash (5 charges) | Left Shift | B / Circle |
| Jump | Space | A / Cross |
| Lock on | Tab / middle click | RB / R1 |
| Pause (items, healing) | Esc | Start |
| Feel knobs | F12 | Back / Share |

## The route (about 30 to 40 minutes)

1. **Hideout:** wake up, Vela says hi, save.
2. **Night market:** take the Yard 9 job at the job board, walk out through Gate 4.
3. **Junkyard J1 to J4:** fights, hacks (Zap the relays, Overclock turrets, EMP drones), the crane puzzle, the Stand.
4. **Loader wake (J4):** wake the loader, climb in.
5. **J5 Smash Run:** flatten the yard, smash the Foreman's gate.
6. **Kasp's arena, phase 1:** the Hushmaster. Zap the leg relays (watch the LEGS pips), hit the dish when it starts JAMMING, Jack in when it topples.
7. **Phase 2:** Kasp escapes into the Heap; dock into the colossus and break its plates, then the core.

## What we'd love to hear
- Does the fight feel good across all three sizes (Red, loader, colossus)? Does each step up feel bigger?
- Anything boring, too long, too hard, or confusing?
- The colossus is now heavier and slower (17 m/s). Better, or do you want it zippier? (F12 → movement)

## Known and expected
- Everything is grey blocks with placeholder words and sounds. Your art, the real script and music come in Phase 2.
- The "Lights" meter top-left is the old Lights On system, still switched on (see the decision in the report).
- Healing is in the pause menu (Items) plus Ration Bars on the ground.
