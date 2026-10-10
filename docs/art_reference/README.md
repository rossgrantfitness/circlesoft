# Art reference sheets (A-pose)

Made for Ross on 2026-10-08 so the final art can be drawn or modeled over the current placeholders.
Everything here is generated from the placeholder models as they are now; the models were not changed.

All renders: pure white background (#FFFFFF), flat unlit color (the real texture colors), nearest-neighbor
so the low-res textures stay sharp, no shadows, no PSX jitter, dither, fog or post grade. Orthographic
views, all at one scale per sheet. Ruler on the left is in game units (1 unit = 1 m, Red is the unit).

## The sheets

Each sheet shows six views: front, 3/4 front, side (left side, faces left), 3/4 back, back and side (right
side, faces right; extra, because every character holds its main prop in the right hand). Bottom of each
sheet: character name, model file, triangle count, bones, texture sizes, height, and a strip of the
texture colors with hex codes (body texture, then face sheet).

| File | What | Size (px) | Tris | Height (units) |
|---|---|---|---|---|
| `red_apose_sheet.png` | Red, current grim version (`red_shiba_grim.glb`) | 3930 x 1343 | 884 (840 + sword 44) | 1.18 with ears |
| `red_classic_apose_sheet.png` | Red, old (classic) (`red_shiba.glb`), secondary | 3930 x 1214 | 884 (840 + sword 44) | 1.10 with ears |
| `otis_apose_sheet.png` | Otis (`chr_otis.glb`), door + hammer | 5400 x 1310 | 786 (678 + door 72 + hammer 36) | 1.37 with ears |
| `mox_apose_sheet.png` | Mox (`chr_mox.glb`), wrench + drone | 3930 x 1400 | 852 (648 + drone 108 + wrench 96) | 1.27 with ears |
| `old_zero_apose_sheet.png` | Old Zero (`npc_old_zero.glb`), species still open | 3930 x 1391 | 482 (460 + thermos 22) | 1.06 with ears |
| `signals_grunt_apose_sheet.png` | Signals Grunt (`enm_signals_grunt.glb`), clipboard | 3930 x 1382 | 556 (500 + clipboard 36 + flag 20) | 1.27 with antenna |
| `whistle_blower_apose_sheet.png` | Whistle Blower (`enm_grunt_variant.glb`), megaphone | 3930 x 1387 | 588 (528 + megaphone 40 + flag 20) | 1.31 with antenna |
| `signals_drone_apose_sheet.png` | Signals Drone (`enm_signals_drone.glb`), hover pose | 3930 x 1379 | 206 | 1.25 (hovers; origin is on the floor under it) |
| `buzzkill_apose_sheet.png` | Buzzkill (`enm_drone_variant.glb`), hover pose | 3930 x 1331 | 250 | 1.11 (hovers) |
| `lineup_apose.png` | Everyone side by side, front view, true relative scale (Red grim, Otis, Mox, Old Zero, Signals Grunt, Whistle Blower, Signals Drone, Buzzkill) | 4774 x 1008 | | |

Notes on the poses:
- A-pose: arms straight, 45 degrees off the body; legs a few degrees out with a small gap between the boots
  (boots kept flat); neutral face (the first cell of the face sheet); props follow the hand but keep the way
  they are held in the model's own rest pose (door upright, sword blade up, hammer and wrench upright).
- Old Zero's arms are 50 degrees, not 45: his coat is so wide that at 45 degrees the mitts sank into it.
- The white surrender flag on both grunts is a prop that only shows when they give up (and its pole hangs
  below the floor), so it is left out of those sheets. It is still counted in the triangle numbers.
- Whistle Blower's megaphone is nearly white (#F4F6F9) so it is faint against the white page.
- Because the rig is rigid (each vertex follows one bone), a hand cannot bend: the lamp mitt, the thermos
  and so on turn with the forearm.

## Textures (`textures/`)

Plain PNG copies of each model's own textures (pulled out of the .glb, so they match the model exactly),
scaled 4x with nearest-neighbor. Nothing added. 128 px sheets become 512 px, the face sheet 128x64 becomes
512x256, drone 64x64 becomes 256x256.

| Character | Body | Face sheet |
|---|---|---|
| Red (grim) | `textures/red_body_4x.png` | `textures/red_face_4x.png` |
| Red (classic) | `textures/red_classic_body_4x.png` | `textures/red_classic_face_4x.png` |
| Otis | `textures/otis_body_4x.png` | `textures/otis_face_4x.png` |
| Mox | `textures/mox_body_4x.png` | `textures/mox_face_4x.png` |
| Old Zero | `textures/old_zero_body_4x.png` | `textures/old_zero_face_4x.png` |
| Signals Grunt | `textures/signals_grunt_body_4x.png` | `textures/signals_grunt_face_4x.png` |
| Whistle Blower | `textures/whistle_blower_body_4x.png` | `textures/whistle_blower_face_4x.png` |
| Signals Drone | `textures/signals_drone_body_4x.png` | none |
| Buzzkill | `textures/buzzkill_body_4x.png` | none |

Face sheet: two 64x64 expressions side by side (neutral on the left, the second on the right). The sheets
above are rendered with the neutral one.

## Model contract basics (from `docs/style_guide.md`, so your assets drop in)

- **Format:** .glb (glTF 2.0), skeleton, skin weights and animation clips all inside the file. Materials are
  base color only, named `mat_<model>`. Textures are 8-bit .png beside the .glb with the same base name,
  no color profile, 1-bit alpha at most.
- **Facing:** the model faces **+Z in Godot**, which is **-Y in Blender** with the default glTF export.
- **Scale:** 1 unit = 1 meter. **Red is the unit: 1.0 tall to the top of her head** (ears add about 0.1, so
  these sheets read 1.10 to 1.18 for her). Other characters are scaled against her (style guide: Otis 1.25,
  Mox 1.15, Kasp 1.1). Apply scale and rotation before export so it imports at 1.0.
- **Origin:** at the feet, on the floor, at the center of the body. Flyers keep their hover height inside
  the geometry, with the origin on the floor under them.
- **Triangle budgets (target / hard cap):** party member body 850 / 900; held prop or weapon 100 / 150;
  crowd NPC (Old Zero) 350 / 500; humanoid enemy 450 / 600; small enemy (drone) 300 / 450; boss rigs later.
- **Textures:** party and grunts 128x128 body + 128x64 face sheet (up to 256x256 only if Ross approves);
  drones and small enemies 64x64; nearest-neighbor, no mipmaps, 64 to 256 px per side.
- **Skeleton:** the shared 17 bones: `root`, `hips`, `spine`, `head`, `ear_l`, `ear_r`, `tail`,
  `upper_arm_l`, `upper_arm_r`, `forearm_l`, `forearm_r`, `thigh_l`, `thigh_r`, `shin_l`, `shin_r`,
  `weapon_socket` (right hand) and `prop_socket` (left hand). Rigid skinning, each vertex follows one bone.
  Drones use 4: `root`, `body`, `rotor_l`, `rotor_r`.
- **Clips (exact names, lowercase, 15 fps stepped):** `idle` (loop, about 1.5 s), `walk` (loop, 0.8 s),
  `run` (loop, 0.6 s), `jump` (once, holds), `fall` (loop), `land` (once). Party members should have all
  six. A battle enemy needs only `idle`. The placeholders for Otis, Mox, Old Zero and the enemies
  currently carry just `idle`; Red has all six.
- **Held props:** their own mesh named `<model>_prop_<thing>` (Red's sword is `..._sword`), skinned to the
  socket bone. Grunts that can surrender carry a `_prop_flag` mesh hanging down from the right hand.

## Regenerating

`game/scripts/tools/render_apose_sheets.py` makes all of this. Setup and usage are in its header
(`pip install bpy==5.0.1 pillow numpy` in a scratch venv, then run it; `--only red otis` rebuilds just those).
