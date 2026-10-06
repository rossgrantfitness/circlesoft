# Style Guide

> ✅ APPROVED by Ross, 2026-10-06: internal resolution 384×216 (A); portraits 96×96 pixel-art, 32 colors (A); one model per character (A). Numbers marked *(starting)* are confirmed by the placeholder-Red pipeline test.

> The authority on the look. Read before any visual work. Owner: Technical Artist with the Creative Director (proposes) · Ross (approves). Drafted 2026-10-06 (Milestone 0).

**How to read this:** every number is picked so one artist can build it. If a rule ever fights "Ross can finish it", Ross's time wins. Numbers marked *(starting)* get checked by running one placeholder Red through the whole pipeline (model, rig, shader, in game) and are locked after that.

## Decisions for Ross
Three calls inside this guide. Everything else follows from your brief.

DECISION NEEDED: What internal render resolution do we use?
Option A: 384×216 (widescreen) — pros: fills a modern screen with no black bars, scales by exact whole numbers (5× on 1080p, 10× on 4K) so pixels stay square and sharp / cons: wider than any PSX game, so rooms need a little more width filled.
Option B: 320×240 (true PSX, 4:3) — pros: exactly the PSX look and shape / cons: black bars on every modern screen (or stretched pixels), and the fixed diorama camera has less floor to show.
Recommendation: A. It reads as PSX once the shaders are on, and the diorama rooms look better wide.

DECISION NEEDED: How big and how detailed are the dialogue portraits?
Option A: 96×96 pixels, drawn at that size, 32 colors max (pixel-art anime) — pros: same pixel size as the 3D and the menus, small canvas so 24 images are quick, looks like one game / cons: less room for fine anime detail.
Option B: Hi-res paint (about 256×256, smooth) shown over the low-res game — pros: prettier anime art, like a few PSX games did / cons: clashes with the pixel look, more work per image, and smooth edges next to nearest-neighbor pixels.
Recommendation: A, because it keeps the look unified and is the cheaper build for you as the only artist. (If you pick B, only section "Portraits" changes.)

DECISION NEEDED: One model per character for field, battle and cutscenes?
Option A: One model each (about 700 triangles), same skeleton for everybody — pros: you build each character once and can copy walk, run, hurt and KO clips between characters / cons: close-ups in cutscenes show a low-poly face (that is the PSX look, and we paint expressions on the face texture).
Option B: A small field model plus a bigger battle model (FF7 style) — pros: nicer battles / cons: doubles your modeling and animating work.
Recommendation: A. It matches "Ross is the only artist, so practicality is taste".

## Visual pillars
> **Ross's visual direction (2026-10-06):** "the visual design language we want is psx style, megaman legends tail concerto mgs1 ff7 inspired." This guide follows that brief.

**Touchstones:** PSX style, inspired by **Mega Man Legends**, **Tail Concerto**, **Metal Gear Solid (1)** and **Final Fantasy VII**. Inspired by, never copied: describe them in words only, never trace or paste images.

1. **Toy-box diorama.** Every room looks like a little set you could pick up and shake: floor, two back walls, props sitting on top.
2. **Chunky and readable.** Big simple shapes. If you fill a character in solid black at 40 pixels tall, you can still say who it is.
3. **Lamps in the dark.** Warm amber light against cold night and cold gray. Warm means "ours, home, people"; cool means "the Hegemony, the dark".
4. **Patched, not polished.** Mismatched plates, tape, rivets, charms and chalk marks. Sci-fi hardware that someone has fixed with love.
5. **Loud pixels.** Big flashes, chunky rating letters, big reactions. The goofy tone shows in the feedback, not in messy art.

## Palette
Paint in these colors. Names matter more than exact hex: if a tweak looks better on screen, tell the Technical Artist and we update this table.

**Color rules**
- **Warm = ours, cool = theirs.** Lamp light (amber) only on windows, lamps, the lamp check and people we like. Hegemony things are never amber.
- **Hegemony = slate gray + white.** Slate #5B6573 armor, Hegemony white #F2F4F7 trim. All their ships share one gray, whatever the shape. Symbol: white ring cut by one bar.
- **Signals Corps = blue-gray** #6F8BA8 uniforms, with slate gear. Status lights are cold pink-red #E8456A.
- **Coldrunners = dark + chalk.** Dark coats #2B2B3D, chalk marks #EDEAD8 (the shuttered lantern).
- **Marchfolk = warm and patched.** Terracotta, mustard and patch-green squares sewn on dusty tan.
- **Watch Zero = dust wraps and brass bells.** Tan #CBA878 wraps, brass #D9A441.
- **The call = pale teal** #5FE0C8. It only shows up where the call is: the tower, the beacon part, the Quiet.
- **No pure black and no pure white in textures.** Darkest is Ink #14121F; lightest is Chalk #EDEAD8 (or Hegemony white). Pure white is for flashes and rating outlines only.
- **Up to 32 colors per texture** (a guide, not a wall). Fewer is better. Hand-dither gradients (checkerboard), never smooth-blend them.
- **Check in grayscale.** Every character must still separate from its background with the color turned off.

**Master palette (shared by everything)**
| Name | Hex | Use |
|---|---|---|
| Ink | #14121F | outlines, darkest shadow |
| Night | #1F2540 | night sky, deep shade |
| Dusk | #3A3566 | shadows on walls, UI shade |
| Chalk | #EDEAD8 | warm white, text, chalk marks |
| Lamp amber | #FFB347 | lamp light, cursor, highlights |
| Lamp glow | #FFE08A | the hot center of a lamp |
| Brass | #D9A441 | lamps, goggles, bells |
| Call teal | #5FE0C8 | the call, the tower's glow |
| Slate | #5B6573 | Hegemony base |
| Slate light | #8D97A5 | Hegemony highlights |
| Hegemony white | #F2F4F7 | Hegemony trim only |
| Signals blue | #6F8BA8 | Signals Corps uniforms |

**Characters (slice)**
| Who | Fur / skin | Main clothes | Accent that makes them pop |
|---|---|---|---|
| Red (dog) | tawny #C98A45, cream #F4E4C1 | jacket red #C8322A | brass lamp and goggles #D9A441 |
| Otis (bear) | brown #7A5233, gray muzzle #A39A90 | coveralls orange #E0782B | dirty-ivory hard hat #D8D2BC |
| Mox (ferret) | tan #A67C52, dark mask #4A3426 | vest mustard #C9A23A | Tuesday the drone, teal #3FA7A0; welding mask silver #B9C2CC |
| Kasp (beaver) | brown #7B4A2A | Signals blue #6F8BA8 | white sergeant stripe, Hushmaster in slate |
| Hegemony grunts | (varies) | slate #5B6573, white trim | numbered helmet |
| Later: Vela, Ruo | silver-gray bunny; raccoon | Signals blue; Coldrunner dark | Vela's hand-stitched amber lamp patch; Ruo's plum scarf #8E3B6E (the one flashy thing on a dark crew) |

Each party member owns one accent hue (Red red, Otis orange, Mox teal and mustard) so the three read apart even at 40 pixels tall.

**Environments**
| Place | Colors | Mood |
|---|---|---|
| Harrow Landing at night | ground dust #4A3F46, patched sheet-metal walls #6A5B5B, rust #9C4A2E, sky Night #1F2540 to Ink; Marchfolk patches terracotta #C8643B, mustard #E0A93B, green #6E9A5A; lit windows Lamp amber | cozy and loud: dark blocks, warm pools of lamplight, sparse dim stars |
| The Old Relay Tower | ironstone #3B3F4A, verdigris #5E8C7A, brass bells #D9A441, Signals gear slate and blue, glow Call teal | half ruin, half shrine; the teal glow gets brighter on each floor up (the call getting louder) |
| Hegemony (Slipway Prime, later) | slate #5B6573 / #8D97A5, floor #3F4753, trim #F2F4F7, cold light #CFE8FF | clean, flat, even light, hard edges, no warmth |
| The Quiet (later, not in the slice) | void #0B0A14, #1A1830, #2B2A55, almost no stars (single pixels #B8C0D8), Call teal, a few Lamp-amber dots | empty and huge; the only warm things are lamps |

**UI**
| Use | Hex |
|---|---|
| Window fill | #1B1A33 with faint hatch #232246 |
| Window border (outer / inner) | Lamp amber #FFB347 / Chalk #EDEAD8 |
| Text | Chalk #EDEAD8 |
| Text dimmed (unavailable) | #7C7A8E |
| Text highlighted | Lamp amber #FFB347 |
| HP bar | coral #FF7A59 |
| Juice bar | lime #9BE35A |
| "!" cue | hot orange #FF5A36 with white outline |
| Ratings | Nice! cyan #7FE0FF · Rad! gold #FFD23F · TOTALLY RAD! cycles hot pink #FF3E9A / orange #FF9A2E / gold #FFD23F · Blocked! steel blue #8FB8FF · Perfect Block! white-gold #FFF2B0 · Payback! red-orange #FF5A36 |

## Character proportions
**One body plan for all party members (chibi, not realistic):**
- **Head-to-body:** about **2.5 heads tall** (head is about 40% of total height). Same for field, battle and cutscenes (one model, see Decisions). Mox is a little longer (about 3 heads), Otis and Vela rounder and shorter (about 2).
- **Scale:** Red is the unit: **1.0 unit tall**. Otis 1.25, Mox 1.15, Kasp 1.1, Vela later 0.85, Ruo later 1.1.
- **Species rules (party):** cute, furry, easy to build. No tusks, long necks, long legs, wings or beaks. Ears and tails are simple flat-ish shapes that each get one bone.
- **Hands and feet:** mitten hands (no separate fingers) and round boots. Thumbs-up is a mitten with a thumb bump.
- **Silhouette rules:** every character has one signature shape you can name in black (Red: one ear up, jacket, sword on shoulder; Otis: boulder with a door; Mox: mask, big wrench, drone; Kasp: box with paddle tail, riding eight legs). No two party members share the same height and width. No feature thinner than 0.1 unit (about 3 screen pixels).
- **Faces:** painted on the texture, not modeled. Big eyes, tiny mouth, 2 or 3 shades only. Each character gets a **face sheet** (see below) so expressions swap without extra geometry.
- **Armor never changes the model** (approved). Weapons are separate props held in the hand.

**Triangle budgets** *(starting)*
| Thing | Target | Hard cap | Notes |
|---|---|---|---|
| Party member (Red, Otis, Mox) | **700** | **900** | one model for field, battle and cutscenes |
| Weapon or held prop (sword, hammer, wrench-mace, door shield) | 100 | 150 | Tuesday the drone: 150 |
| Named NPC on foot (Kasp) | 600 | 800 | |
| Crowd NPC (old Zero, dockhand, Marchfolk, shopkeeper) | 350 | 500 | one base body, recolored |
| Enemy, humanoid (Signals grunt) | 450 | 600 | |
| Enemy, small (Signals drone) | 300 | 450 | |
| Boss rig (the Hushmaster: 8 legs, dish, toppled state) | 3000 | 4000 | big machines come later and get their own numbers |

**Textures**
- Party: **128×128** body texture plus a **128×64 face sheet** (8 cells of 32×32; the slice needs 5: neutral, blink, talk, hurt, happy).
- Crowd NPCs and small enemies: 64×64 (they share face-sheet cells).
- Grunts: 128×128 shared, recolored. Bosses and the Hushmaster: up to two 256×256 textures.
- Tiny props share one 256×256 prop atlas, so we never make a texture smaller than 64 on a side.

**Skeleton and animation**
- **One shared skeleton, 17 bones, rigid skinning** (each vertex follows exactly one bone, like the PSX): root, hips, spine, head, ear L, ear R, tail, upper arm L/R, forearm L/R, thigh L/R, shin L/R, weapon socket (right hand), prop socket (left hand, for shields).
- Because everyone shares it, Ross can **copy a clip from one character to another** and tweak it. Walk, run, hurt, KO, victory, climb and hop are copy-and-tweak.
- Animation is hand-keyed at **15 frames per second, stepped (no smoothing)**: a key every 2 to 4 frames is plenty.
- The drone has 4 bones (body, 2 rotors). The Hushmaster has up to 32 (8 legs of 2 bones, body, dish, seat).

**Animation list (slice, per party member)**
- **Wave 1, to get playable:** idle (loop, about 1.5 s), walk (loop, 0.8 s), run (loop, 0.6 s), battle ready (loop), attack 1, hurt, KO (ends lying down), victory pose.
- **Wave 2:** attack 2, defend (a held braced pose), block (short reaction when a Clutch block lands), skill (generic cast or use), item, climb (loop), hop (one-shot), and each character's **signature move** (Porch Light, Heave-Ho, Patent Pending).
- **Wave 3, Red only (the gestures):** thumbs-up (also ends the lamp check), head shake, shrug, goggles down ("already running"), lamp check (light lamp, two taps, thumbs-up). Her ear perk is a short ear-bone twitch layered on idle.
- **Enemies:** grunt: idle, walk, attack, hurt, KO, surrender (waves the white flag and leaves). Drone: hover idle, attack, hurt, KO. Hushmaster: idle, step, jam pulse wind-up, attack, leg breaks (4 pairs), topple.

That is about 17 clips for Otis and Mox and 22 for Red. Wave 1 first; later waves can arrive while systems get built.

## Environment style
- **Diorama rooms:** a floor, two back walls, props on top. The two front walls are not built at all. Camera: high angle (about 40 to 45 degrees down), narrow field of view so it reads like looking into a toy box, never rotates, slides in big rooms (design doc).
- **On-screen scale:** the default camera frames about **10 × 5.6 units of floor**, so Red stands about 38 pixels tall on screen. Interiors fit one screen; streets and the road slide.
- **Modular kits (build once, reuse everywhere):** floor tile **1×1 unit** (2 triangles; small enough for lamp pools of light), wall panel **2 wide × 3 tall**, door **1 × 1.8**, window, corner post, trim strip. Harrow kit: patched sheet-metal walls, shutters, awning, crates, lamp posts. Tower kit: ring catwalk, stair run, cage lift, mast section, broken wall. Moons later reuse Harrow's kit in new palettes.
- **Fantasy + sci-fi:** *Sci-fi is the hardware; fantasy is the culture* (story bible). Hardware is chunky: round-cornered boxes, fat pipes, big rivets, taped cables, dishes and antennas, all hand-patched. Fantasy sits on top, small and warm: lucky charms on bulkheads, bells, lamps in windows, chalk marks, lane-song banners, relay masts treated like shrines. Hegemony places are the opposite: clean, gray, matching and identical.
- **Prop scale (a toy-box scale, chibi-sized):** Red = 1.0. Table 0.6, chair 0.45, bar counter 0.7, crate 0.8, door 1.8, lamp post 2.2, ceiling or wall height 3.0. Doorways and ladders are chunky and oversized so they read.
- **Texel density:** about **32 texels per unit** for environments (so a 64×64 tile covers 2×2 units, and one texel is roughly one screen pixel). Characters are denser on purpose, for cutscene close-ups.
- **Budgets per room** *(starting)*:
  - Interior (visible triangles only): **2000 target, 3500 cap**.
  - Outdoor area (the Landing streets, the road): **4000 target, 6000 cap**.
  - Single prop: 30 to 150 triangles (large furniture up to 300).
  - Textures: up to 6 environment textures (64×64 to 256×128) plus the shared prop atlas.
  - Kit piece: 20 to 400 triangles.
- **Battle backdrops** reuse the room sets (design doc) with the camera moved closer.
- **Sky:** a tiny dome with a 128×64 night-sky texture, a few dim stars. Nothing else behind the back walls.

## PSX rendering rules
- **Internal render resolution: 384×216** (16:9), drawn small and scaled up by whole numbers (5× on 1080p, 10× on 4K). *Why:* modern widescreens fit it exactly, pixels stay square, and 3D, UI and text all share one pixel size. Fallback on odd screens: scale as large as fits in whole numbers and add borders, or "Fill" in Config. (Subject to Decision 1.)
- **Texture sizes: 64–256px** per side, any mix of power-of-two. (Face cells 32×32 and UI pieces are the only exceptions.)
- **Texture filtering: nearest-neighbor** everywhere, no mipmaps, no smoothing. Import settings are set by the Technical Artist.
- **Vertex jitter / snapping:** vertices snap to the **internal pixel grid (1 pixel at 384×216)**. Characters and props wobble slightly in motion; a still room is steady. (Tunable 0 to 2 pixels.)
- **Affine texture warping:** on for characters and props (textures bend slightly with the camera angle). Floors and walls are built from small 1×1 and 2×2 pieces so the warping stays gentle. (Strength is tunable per material.)
- **Retro effects option:** a Config setting **Retro effects: Full / Light / Off** (affects wobble and warping) for players who feel sick from wobble. I will pass this to the Menus owner.
- **Dithering and color depth:** the final picture is reduced to **15-bit color (32 levels per channel)** with a **4×4 ordered dither**, like the PSX. Ross paints normal PNGs; the shader does the reduction. Transparency is **1-bit cut-out** only (a pixel is there or it is not). Soft glow (lamp halos, flashes) uses additive blend sprites.
- **Lighting:** **vertex lighting only, no per-pixel lights, no real-time shadows.** Each room has an ambient color and a few warm point lights (lamps, windows) that light the corners of nearby triangles. Characters are lit the same way and get a **blob shadow** (a dithered dark circle on the floor). Painting vertex colors for corner darkening is optional, never required.
- **Fog / draw distance:** distance fog in the room's void color (Night or Ink), in **4 visible bands** (not smooth), starting at the back walls and reaching full about 8 units behind. Far clip 60 units. Fixed camera means nothing far away is ever drawn anyway.
- **Screen effects are code, not art:** flashes (2-frame white), shake, static transition, fades are all done in shaders. Ross never animates them.

## UI window style
*Late-90s JRPG feel, our own design. Everything is drawn at the internal 384×216 pixel size.*
- **Shape:** a rectangle with **chamfered (cut) corners**, like a dispatch slip or shipping label. A small **rivet dot** sits in each corner (a nod to patched hardware).
- **Border:** a 2-pixel **amber** outer line (#FFB347) and a 1-pixel **chalk** inner line, with an Ink 1-pixel drop shadow on the bottom and right. Nothing like FF7's gray-white bevel.
- **Background:** a flat dark indigo (#1B1A33) with a faint **diagonal hatch** of #232246 (like corrugated board), at about 90% opacity so the room shows through in dither, not blur. No blue gradient.
- **Build as:** one **24×24 nine-slice PNG** (8-pixel corners and edges) reused for every window. Sizes are free, so menus, shops and the dialogue box all use it.
- **Cursor:** a chunky amber **flame-shaped arrow** (about 12×12) pointing right. It flickers between 2 frames and bobs 1 pixel. It snaps instantly with a tick, never slides. A dimmed copy marks "last position" on inactive lists.
- **Transitions (all stepped at about 12 fps, no easing):**
  - Window opens by growing from a thin horizontal line to full height in 4 frames. It closes in reverse.
  - Menu pages slide 8 pixels and fade by dither in 3 frames.
  - Rooms fade to black in 8 dithered steps. Battles start with the radio-static hiss (design doc).
- **Text:** Chalk on the window. Dimmed gray for unavailable. Amber for the highlighted row. Numbers are right-aligned.
- **Bars:** HP is a thick coral bar, Juice is a thin lime bar, always with a label and number so color is never the only clue.
- **Battle "!" cue:** a bold hot-orange "!" in a round white-outlined bubble (16×16) over the head. Bosses use a bigger "!!" (24×16) with a short shake.
- **Rating lettering:** chunky, hand-lettered **sign-painter caps**, tilted slightly forward, with a 2-pixel Ink outline, a 1-pixel white inner outline and a flat fill with one highlight stripe. One image per rating, in the colors above:

  | Image | Size (px) |
  |---|---|
  | Nice! | 72×24 |
  | Rad! | 64×28 |
  | TOTALLY RAD! | 168×36 |
  | Blocked! | 80×24 |
  | Perfect Block! | 144×28 |
  | Payback! | 96×28 |
  | K.O.! | 96×48 |

  They pop in with a 3-step overshoot (60%, 120%, 100%), hold about 0.6 s, drift up 8 pixels and dither away. TOTALLY RAD! also bounces letter by letter and cycles its three colors every 2 frames (a code recolor of the same image). Ross draws each once; the motion is code.
- **Damage and heal numbers:** one chunky digit sheet (0–9, about 12×16 each, Ink outline). White for damage, lime for heals.
- **Red's gesture pop-ups:** a **32×32 puffy chalk speech bubble** with an Ink outline and a tail pointing at her head, sitting 4 pixels above her. Inside, a simple icon in her colors: **thumbs-up, head shake, shrug, ear perk** (slice set). Each is 2 or 3 frames, pops in over 3 steps, holds about 1.2 s, dithers out. The field icons for interaction (talk bubble, "?", hand) are smaller, 16×16, and never use "!" (that is reserved for battle).
- **Title screen:** the LIGHTS LEFT ON logo is chunky, beveled sign letters with a warm window-lamp glow, over the night view of Harrow. Ross designs it; spec goes to docs/art_requests.md.

## Fonts and text box limits
> **Ross, 2026-10-06:** "move away from the early nes style font and begin to employ a font that more closely resembles the font shown in the screenshot [FF9]. I still want it to look a little pixelated and gamey, I like the drop shadow as well." This replaces the earlier pixel-font pair (Pixelify Sans and Press Start 2P). We use an open-license font only and never trace or copy any game's own font.

- **One font for all UI text: Nunito** (SIL OFL 1.1, variable weight; `game/art/final/ui/fonts/Nunito-VariableFont_wght.ttf` with `Nunito-OFL.txt`). A bold, rounded, friendly sans in **mixed case**, which is the chunky console-menu feel Ross asked for. Picked from six candidates (Nunito, M PLUS Rounded 1c, Varela Round, Fredoka, Zen Maru Gothic, Baloo 2); the comparison sheets are `docs/screenshots/font_candidates.png` and `font_candidates_aa.png`. Runner-up: M PLUS Rounded 1c ExtraBold (a touch closer to the FF9 weight, but a 3.6 MB file).
- **Rendering:** drawn at whole pixels into the 384×216 UI layer with **grayscale antialiasing on, no hinting, no subpixel positions**, then scaled up with nearest-neighbor. That gives soft, slightly pixelated edges like a low-resolution console menu. (Antialiasing off was tried and gave uneven letter spacing, so it is not used.)
- **Drop shadow on every piece of text:** 1 pixel down and right, near-black Ink-dark `#0B0A14`. Dark text on the chalk speech bubble uses a soft tan shadow `#D3CDB7` instead. It is one reusable text style (`UiText` in `scripts/ui/ui_text.gd`); every value lives in `data/ui/ui_theme.json` (`fonts` and `text_shadow`).
- **Sizes and weights** (in `ui_theme.json`): menus, descriptions and dialogue **12 px at weight 800**; speaker name tags **10 px at weight 900**; the title logo **32 px at weight 900** with the heavy outline and glow treatment. Line spacing: 14 px in bubbles and the text box, 16 px per menu row.
- **Dialogue box and bubbles:**
  - Speech bubble over a speaker: up to about **44 characters per line**, **3 lines** per page (wider lines wrap; longer text turns the page).
  - Plain text box (narrator, signs; `352×58` at the bottom): **50 characters per line, 3 lines**.
  - With a portrait (later): **36 characters per line, 3 lines**. A blinking "more" arrow shows at the bottom right when there is another page.
- **Menus:**
  - Item, weapon and skill names: **28 characters max** (the longest in the game today is "Bread Knife, Extremely Large"). Battle command names: 12 max. Menu text is mixed case ("Items", "Start Demo"), not all caps.
  - Descriptions: **2 lines of about 44 characters**.
  - Character names show up to 10 characters. The player's rename for Red: **8 letters max**.
  - Pop-up lines ("The grunts surrender!"): 1 line, 32 characters.
- **Supported characters:** A–Z, a–z, 0–9, space and `. , ! ? : ; ' " - ( ) / & % + = # * @ ~`, plus the ellipsis, em dash, curly quotes, × and ♪, and Latin accents (é è ñ ü and so on) so names never break. Nunito covers all of these. English only for now. Button prompts are written as tokens like `{A}`, and the game swaps in the button icon.

## Portraits
*For dialogue and menus. Subject to Decision 2 (this section assumes Option A).*
- **Size:** **96×96 pixels**, one PNG per expression, transparent background (1-bit cut-out edges).
- **Style:** 2D **anime**: big expressive eyes, simple clean line, 2 to 3 shades per area, a dithered shadow. **32 colors max** per character set, taken from the master palette plus that character's own colors.
- **Framing:** head and shoulders, turned about a quarter toward the dialogue. Eyes sit on the same line (about 40% down) in every expression so swapping looks smooth. Leave **6 pixels above the head** for ears and hats (Red's pointy ears need it).
- **Safe face box:** keep eyes and mouth inside the middle **64×48** of the portrait. The menus and the turn-order and party panels crop that box, so nothing needs re-drawing.
- **How to draw:** one shared body and hair layer, plus one layer per face. Only the eyes, brows, mouth and ears change between expressions. Export one PNG per expression.
- **Expressions (slice):**
  - **Red (5):** grin, determined, surprised, worried, smug. She never gets a text box; her portrait shows her expression and her ears say the rest.
  - **Otis (5):** calm smile, apologetic, stern, worried, laughing.
  - **Mox (5):** boasting, panicking, focused, sheepish, proud.
  - **Kasp (3):** smug, shouting, flustered.
  - **Two key NPCs (3 each):** neutral, happy, upset. Which two NPCs is the Writer's call (likely the old Zero and one Harrow local).
  - **Total: 24 images.** Crowd NPCs get none.
- **Turn-order heads:** 24×24 hand-pixeled head icons, 8 in the slice (3 party plus the enemy types). These are separate art, not shrunken portraits.

## File formats and naming
- **3D models:** **.glb** (glTF 2.0) exported from Blender with default settings (+Y up, units in meters, model front facing -Y in Blender). Skeleton, skin weights and animation clips are all inside the .glb. Materials are base color only (no PBR), named `mat_<model>`.
- **Textures, faces, portraits, UI:** **.png**, 8-bit, no color profile, no smoothing, 1-bit alpha. Textures sit **beside the .glb** with the same base name.
- **Animation clips:** lowercase snake_case, the names used above: `idle`, `walk`, `run`, `battle_ready`, `attack_1`, `attack_2`, `defend`, `block`, `skill`, `item`, `signature`, `hurt`, `ko`, `victory`, `climb`, `hop`, and Red's `thumbs_up`, `head_shake`, `shrug`, `goggles_down`, `lamp_check`.
- **Names: `prefix_name[_variant].ext`**, all lowercase, words joined with underscores, no spaces.

  | Prefix | Means | Example |
  |---|---|---|
  | `chr_` | party member | `chr_red.glb`, `chr_red.png`, `chr_red_face.png` |
  | `npc_` | townsperson | `npc_old_zero.glb` |
  | `enm_` | enemy | `enm_signals_grunt.glb` |
  | `boss_` | boss | `boss_hushmaster.glb` |
  | `wpn_` | weapon prop | `wpn_sword_scrap.glb` |
  | `prp_` | prop | `prp_crate_delivery.glb` |
  | `env_` | environment kit or room | `env_landing_kit.glb` |
  | `ptr_` | portrait | `ptr_red_grin.png` |
  | `ui_` | UI art | `ui_window_9slice.png`, `ui_rating_rad.png` |
  | `ico_` | item and status icon | `ico_item_sword.png` |
  | `fnt_` | font | `fnt_pixelify_sans.ttf` |

- **Destination folders (final art):**
  - `game/art/final/characters/` (party, one folder per character)
  - `game/art/final/npcs/`
  - `game/art/final/enemies/` and `game/art/final/bosses/`
  - `game/art/final/weapons/` and `game/art/final/props/`
  - `game/art/final/environments/harrow_landing/`, `.../road/`, `.../old_relay_tower/` (one folder per place, kit pieces inside)
  - `game/art/final/portraits/<character>/`
  - `game/art/final/ui/` (`windows/`, `cursor/`, `ratings/`, `gestures/`, `icons/`, `digits/`)
  - `game/art/final/ui/fonts/`
- **Placeholders** go in `game/art/placeholder/` with the **same file name** as the final asset, so Ross's art is a drop-in replacement. Placeholders follow the same budgets and palette.
- **Working files** (.blend, .kra, .aseprite) stay in `game/art/source/`, or on Ross's own machine. Only exports go in `final/`.
- **Imports:** the Technical Artist sets filtering to nearest and turns off mipmaps and compression once, project-wide. Ross never touches import settings.

## Reference notes
*Describe references in words only. Never paste or copy images from existing games.*
- **Mega Man Legends:** chunky, toy-like low-poly characters and towns, bright readable colors, big friendly shapes. **We take:** big heads, simple faces drawn with a few shapes, flat bold colors with one shade step, towns that feel like play sets, and robots made of round, bolted-on parts. **We leave:** any specific character, building or robot design.
- **Tail Concerto:** a PSX world of anthropomorphic animal characters with cute proportions, mechs and airships: the closest match to our cast and our robots. **We take:** animal heads that stay simple (round ears, small snouts, mitten hands), storybook-bright towns, and small characters piloting big machines. When a look question is unclear, start here. **We leave:** its species, outfits, machines and layouts.
- **Metal Gear Solid (1):** moody, grounded military-industrial spaces, strong silhouettes, dramatic in-engine cutscene staging. **We take:** the Hegemony and tower spaces (narrow range of grays, one accent color, hard-edged blocky shapes), strong light-versus-dark contrast, and the camera language of cutscenes (close-ups on eyes, low angles on villains, slow push-ins at big moments). **We leave:** its realism and its serious mood; our version stays loud and goofy.
- **Final Fantasy VII:** chibi field models next to big moments, heavy industrial sci-fi mixed with fantasy, iconic menus and windows. **We take:** the idea of cute little models that still carry huge story moments (here by camera, lighting and title cards, since we use one model everywhere), and industrial machinery living alongside folk culture. **We leave:** its blue gradient window, its character and monster designs, and its logos.
- **How we use them:** the touchstones give us the *feel*; every design (characters, windows, machines, towns) is drawn fresh. If something looks too close to a touchstone, change it.
- When anything visual is unclear, ask Ross which game he means before guessing.
