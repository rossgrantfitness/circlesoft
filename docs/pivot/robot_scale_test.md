# Robot scale test: handoff to the Gameplay Programmer (CS-21)

**From:** Technical Artist · **Date:** 2026-10-09 · **Status:** placeholder blockouts delivered; Ross makes the final art.
**Ross:** "I want to board myself a lagaan sized giant robo THEN a gurren lagann sized giant robo, we can use the exact same character controller, but I want to feel a sense of scaling up." Then: "use robots docking into each other" (the small robot docks into the huge one).
**Not touched:** ActionPlayer, the camera scripts, combat_sandbox.gd, moves.json, feel.json. Everything below is yours to wire; the numbers are suggestions only.

Pictures: `docs/screenshots/robots_scale_lineup.png` (Red, small robot, huge robot, props), `robots_dock_bay.png` (bay open, small robot inside), `robots_small_poses.png` and `robots_huge_poses.png` (the retargeted clips on each).

## 1. The models

Load the `_ual` files (they carry the clips). The plain `.glb` beside each is the rig without clips.

| | Small robot | Huge robot |
|---|---|---|
| Model | `res://art/placeholder/robots/robot_small_ual.glb` | `res://art/placeholder/robots/robot_huge_ual.glb` |
| Height (feet to antenna tip) | 3.5 m (3.68 x Red) | 50.0 m (52.6 x Red, 14.3 x the small robot) |
| Width, depth (rest pose, A-pose arms) | 2.6 m wide, 1.3 m deep | 39 m wide, 21 m deep |
| Hips height (rest) | 1.38 m | 19.8 m |
| Triangles | about 1,700 | about 3,300 |
| Origin, facing | between the feet on the floor, faces +Z (same as Red) | same |
| Suggested body collider | radius 1.0 m, height 3.2 m | radius 11 m, height 46 m |
| Look | oxblood plating, brass hatch rim, amber lamps | ironstone plating, hazard stripes, amber bay lamps |

Materials are placeholders (Ross's city tiles for the plating plus flat colours); they take the PS2 look and the edge light like any model (`Ps2Look.upgrade_model`, `LookProfiles.dress_model`). The "placeholders" texture group is crisp (nearest) in the `grim_ps2` profile.

## 2. Bones (same names and hierarchy as Red)

Every bone of `red_ross_v1_rigged_ual.glb` is on both robots with the same parent, scaled uniformly: `root, hips, spine, chest, neck, head, ear_l, ear_l_2, ear_r, ear_r_2, head_gear, shoulder_l/r, upper_arm_l/r, forearm_l/r, hand_l/r, prop_socket, weapon_socket, back, lamp_socket, tail, thigh_l/r, shin_l/r, foot_l/r`. `weapon_socket` hangs from `hand_r` exactly as on Red (blade axis +Y). The robots carry no sword mesh; equip one on `weapon_socket` as for Red (a katana on a 3.5 m robot is Red-sized, so scale the sword by the same factor: 3.68 and 52.6).

Extra bones (all world-aligned at rest, so a rotation about X, Y or Z in the bone's pose is a rotation about the world axis; positions are rest-pose metres in the model's own space):

**Small robot**

| Bone | Parent | Rest position | What it is |
|---|---|---|---|
| `cockpit_hatch` | `chest` | (0, 1.77, -0.47) | The back hatch door, hinged at its bottom edge. Rotate about X (about -100 deg) to fold it down into a ramp. |
| `cockpit_seat` | `chest` | (0, 1.84, -0.07) | Where Red sits. Put her root here; hide her model, or sit her in the chest. |
| `boarding_point` | `root` | (0, 0, -1.1) | On the floor 1.1 m behind the robot. Red walks here, then climbs: ladder rungs and a step plate are modelled on the back. |
| `dock_anchor` | `root` | (0, 0, 0) | Floor point between the feet. Lines up with the huge robot's `dock_point`. |

**Huge robot**

| Bone | Parent | Rest position | What it is |
|---|---|---|---|
| `dock_point` | `chest` | (0, 26.55, 4.05) | The centre of the chest bay's floor. The small robot's `dock_anchor` goes here. |
| `dock_door_l`, `dock_door_r` | `chest` | (+3.02, 28.92, 5.78) and (-3.02, 28.92, 5.78) | The two bay doors, hinged on their outer edges. Rotate `dock_door_l` about +Y by about +100 deg and `dock_door_r` by about -100 deg and they swing open to the front like a clamshell. |
| `dock_lift` | `hand_l` | (16.0, 19.2, 0) | The left palm. Optional: a stage for the small robot to stand on while the huge robot raises its hand to the chest. |
| `dock_approach` | `root` | (0, 0, 15.8) | On the floor, 15.8 m in front. Where the small robot walks to and stops. |

The bay is 6.0 m wide, about 5 m tall and 3.5 m deep (a test checks that the small robot fits with a metre to spare). Inside: hazard-striped floor, louvred back wall, two docking clamps with amber lamps, a ceiling lamp. Three amber status lamps sit above the doors. Moving a door bone is the only animation the doors need; none is baked.

**Original design, kept clear of the Gurren Lagann look:** the huge robot has no face (its head is a furnace hood with a vertical vent grille), nothing on the chest but a clamshell bay, no drill, no sunglasses; riveted plates, hazard stripes, smokestacks on the back. The small robot is a squat loader frame with a hatch in its back. The two do not combine into one robot and nothing in the design is a face: the small one is carried in a bay and stays itself. Ross asked for docking, so this is the one borrowed beat; the surface is ours.

## 3. Docking sequence (a short snap, lock, then power-up)

Suggested staging, about 4.5 s. Times are seconds from the start; every pose is a bone rotation or a node move, no new animation clips are needed.

1. **Approach (0.0 to about 1.0).** The small robot (player controlled until now) reaches `dock_approach`; input is taken from there on. The huge robot is standing, idle.
2. **Doors (1.0 to 1.6).** `dock_door_l` and `dock_door_r` swing open (+100 / -100 deg about Y, ease-out). Bay lamps on. Small shake `step_small`, heavy servo sound.
3. **Lift or hop (1.6 to 2.8).** Either (a) the small robot hops: a parabolic jump from `dock_approach` to the bay floor, about 26 m up (a staged move, not the controller's jump); or (b) the huge robot lifts its left hand to the chest with the small robot on `dock_lift` (rotate `upper_arm_l` / `forearm_l`). Camera pulls back and tilts up.
4. **Snap (2.8 to 3.0).** Small robot's `dock_anchor` is placed on `dock_point` with a quick ease-in (0.15 s); hit stop about 80 ms; metal-clank sound; `land_small` shake; a spark burst at the clamps.
5. **Lock (3.0 to 3.6).** Both clamps close (the clamp lamps go from amber to white); doors swing shut; the bay lamps go dark. Low thunk, `step_huge` shake.
6. **Power-up (3.6 to 4.5).** The huge robot's head vent lamps (three amber slots) and the chest lamps flash on, one after another left to right; a rising hum, pitch from 0.3 to 0.4; the camera eases to the huge-scale distance and FOV (section 5); control passes to the huge robot (same controller, huge scale profile).

Undocking is the same in reverse. The small robot is inside the bay with its own colliders off while docked, so keep it parented to `dock_point` (use a BoneAttachment3D on the huge robot's skeleton for `dock_point`).

## 4. Clips (the same ones Red has)

Both robots carry Red's whole clip list, baked from the Quaternius clips by `scripts/tools/retarget_ual.py robot_small` and `robot_huge` (settings: `data/animation/retarget_robot_small.json`, `retarget_robot_huge.json`; key data: `data/animation/robot_small_clip_keys.json`, `robot_huge_clip_keys.json`, same format as `red_clip_keys.json`, so contact frames for strikes match Red's). Clip names: `idle, walk, run, jump_up, fall, land, dash, light_1, light_2, light_3, heavy, launcher, parry, hurt, knockdown, getup` plus `air_1, air_2, air_3, parry_success`. Red's four hand-posed stand-ins do not exist on the robots, so the robots get baked stand-ins instead: `air_1/2/3` are the three light swings and `parry_success` is the block, held (`ground: free` for the air ones).

**Natural speeds** (the ground speed the foot does not slide at, playback 1.0), from the key data:

| Clip | Red | Small | Huge |
|---|---|---|---|
| walk | 0.57 m/s | 2.1 m/s | 31.5 m/s |
| run | 3.77 m/s | 13.9 m/s | 200.9 m/s |

To avoid foot slide, set the playback speed to `move_speed / natural_speed`. For the huge robot that rules out the run clip at any believable speed (a 50 m robot sprinting at 200 m/s is wrong): use the **walk clip for both walking and running** on the huge robot (see the table). Foot-plant times in the walk and run clips (seconds at playback 1.0, left foot then right foot) are in `fx.json` `scale_sets`: walk 0.333 and 1.0, run 0.033 and 0.367. Divide by the playback speed.

Known blockout limits: the stocky bodies clip arm-through-torso on wide swings (the retarget `--report` numbers are in the tool output; Red's chibi frame does the same); no hand-made animation anywhere.

## 5. Suggested scale profile (numbers only)

Red's current numbers for reference: run 6.0 m/s, walk 2.4 m/s, turn 1200 deg/s, camera 4.5 m at FOV 62 (data/combat/camera.json), jump 1.6 m.

| Number | Red (now) | Small robot | Huge robot |
|---|---|---|---|
| Camera distance | 4.5 m | 14 m | 75 m |
| Camera minimum distance | 0.8 m | 5 m | 30 m |
| Camera target height (above the feet) | about 0.6 m | 1.9 m | 26 m |
| Camera FOV (vertical) | 62 | 60 | 56 |
| Camera pitch | as now | as now | about 8 deg shallower, camera low (looking up makes it taller) |
| Walk speed | 2.4 m/s | 2.4 m/s | 14 m/s |
| Run speed | 6.0 m/s | 9.0 m/s | 22 m/s |
| Dash distance, time | 4.0 m, 180 ms | 8.0 m, 260 ms | 40 m, 520 ms |
| Turn rate | 1200 deg/s | 480 deg/s | 70 deg/s |
| Acceleration (ground) | 95 m/s2 | 40 m/s2 | 10 m/s2 |
| Jump height and gravity scale | 1.6 m, 1.0 | 3.0 m, 0.8 | 12 m, 0.35 |
| Locomotion playback speed (walk clip) | as now | 1.15 | 0.44 |
| Locomotion playback speed (run clip) | as now | 0.65 | use the walk clip at 0.70 |
| Attack and parry playback speed | 1.0 | 0.85 | 0.45 |
| Hit stop (heavy hits) | as now | 1.3 x | 2 x |
| Sound pitch (footsteps, swings, voice) | 1.0 | 0.75 | 0.40, with a low-pass and a long reverb tail |
| Footstep shake and dust | none | `step_small` | `step_huge` |
| Landing shake and dust | `slam` | `land_small` | `land_huge` |
| Fog near, far (the light haze) | 30 m, 150 m | 60 m, 300 m | 300 m, 1,500 m |

Why these (so you can retune): speed is kept to a few body lengths per second at small scale and a fraction of a body length per second at huge scale, which is what makes it feel heavy; the playback speeds follow from the speeds above and the natural speeds in section 4, so a step comes down about every 0.5 s on the small robot at a run and every 1.0 to 1.5 s on the huge one; the huge camera frames the whole robot at about 60% of the screen height, so a person (and the 10 to 30 m buildings) read as tiny.

**Fog warning (a finding, not a number):** the `grim_ps2` haze (30 m to 150 m) hides the huge robot from the huge camera distance, so it comes out almost black. The lineup shot uses 200 m to 1,200 m. Fog is set by `PsxLook.set_fog(color, near, far)`; scale it with the robot.

## 6. Effects (all numbers in `data/combat/fx.json`)

- **Shakes** (`shake.step_small`, `shake.land_small`, `shake.step_huge`, `shake.land_huge`; `land_*` is the heavy landing slam). They use the same fields as every other shake (`amplitude_m`, `duration_s`, `frequency_hz`), so `OrbitCamera.shake(&"step_huge", mult)` works as is. Extra fields: `for_camera_m` (the camera distance the number was tuned for) and `suggested_mult` (what to pass as `mult` so a far camera still shakes). **Two limits to know:** `CameraShake.MAX_AMPLITUDE_M` is 0.25 m and caps `amplitude_m x mult`, and the existing data test keeps every shake under 0.2 m and 0.6 s. At 75 m a 0.25 m offset is a fraction of a degree, so the huge shake will read weak until that cap is made per profile or scaled with the camera distance. That is a camera-script change, so I left it.
- **Dust** (`dust.step_small`, `dust.land_small`, `dust.step_huge`, `dust.land_huge`): bigger and slower at large scale (the huge puffs are 5 to 12 m wide, last 2.6 s and spread from a 6 m ring; the small ones are 0.3 to 0.8 m and last 0.7 s). `land_*` adds an expanding shock ring on the floor. Play one with `ScaleDust.spawn(world_node, foot_position, &"step_huge")` (`scripts/combat/fx/scale_dust.gd`, a self-freeing Node3D of billboard puffs; it reads `fx.json` through `DataDB`). It is not wired to any event: call it on each foot plant (times in section 4).
- **Which set each scale uses:** `fx.json` `scale_sets.small` and `scale_sets.huge` name the shake, dust and foot-plant times.

## 7. Scale props (so size reads)

`res://art/placeholder/robots/props/`: `prop_crate_small` (0.8 m), `prop_crate_large` (2 m), `prop_cargo_container` (6 m), `prop_car_block` (4.4 m long), `prop_lamp_post` (7 m), `prop_building_10m`, `prop_building_20m`, `prop_building_30m` (bodies 10, 20 and 30 m, with a roof tank and mast on top). Origin on the floor at the middle of the footprint; the front (door side) faces +Z. Static meshes, no colliders: add boxes. Plating uses Ross's rust and steel city tiles, dirty and lit windows are flat colours.

## 8. Rebuild

```
python3 game/scripts/tools/make_robots.py                 # models + retarget settings (numpy only, no Blender)
godot --headless --path game --import                     # once, so the .glb.import files exist
python3 game/scripts/tools/retarget_ual.py robot_small    # then robot_huge
xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
    -s res://tests/visual/capture_robot_scale.gd -- --shot=lineup --out=docs/screenshots
```
Tests: `game/tests/integration/test_robot_scale_blockouts.gd` (bone names and parents, heights, floor contact, bay fit, hatch and boarding nodes, clips and loops, triangle budgets, props, shake and dust data).
